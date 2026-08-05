#!/bin/bash
# sales-file.sh — deterministischer Vertriebs-Collector fuer das Dashboard (0 Tokens),
# Adapter fuer die Datei-Routine der Integrations-Leiter (Stufe 2).
#
# Schreibt data/sales.json NUR wenn modules.sales.enabled UND
# modules.sales.pipeline.source == "file". In allen anderen Faellen (airtable,
# snapshot, none, Modul aus, Config fehlt) sofort exit 0 OHNE sales.json anzufassen,
# weil die Datei dann einem anderen Schreiber gehoert (dem /aios-dashboard-Skill).
#
# Liest die NEUESTE Datei (mtime) aus drop_path (*.csv oder *.json), normalisiert
# ueber field_map + stages aus der Config in die kanonische A3-Form und berechnet
# die KPIs. Top-level try/except, damit dieser Collector nie crasht.

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="${DASH_DIR:-$HOME/.claude/dashboard}"
DATA_DIR="$DASH_DIR/data"
CONFIG_FILE="$DASH_DIR/config.json"
mkdir -p "$DATA_DIR"
OUT_FILE="$DATA_DIR/sales.json"
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')
TODAY=$(date +"%Y-%m-%d")

$PYBIN - "$GENERATED_AT" "$OUT_FILE" "$CONFIG_FILE" "$TODAY" <<'PYEOF'
import sys, json, os, re, csv, io
from datetime import datetime

generated_at, out_file, config_file, today = sys.argv[1:5]


def write_out(payload):
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def parse_amount(raw):
    if raw is None:
        return None
    s = str(raw).strip()
    if s == "":
        return None
    # Waehrungszeichen und Leerzeichen strippen
    s = re.sub(r"[€$\s]", "", s)
    # Deutsches Zahlenformat (1.234,56) vs. englisches (1,234.56) unterscheiden.
    if "," in s and "." in s:
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    elif "," in s:
        # Nur Komma: als Dezimaltrenner werten, wenn genau 2 Nachkommastellen,
        # sonst als Tausendertrenner (z.B. "1,234").
        parts = s.split(",")
        if len(parts[-1]) == 2:
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    try:
        return float(s)
    except ValueError:
        return None


def parse_date(raw):
    if not raw:
        return None
    s = str(raw).strip()
    if not s:
        return None
    for fmt in ("%Y-%m-%d", "%d.%m.%Y", "%d.%m.%y", "%m/%d/%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(s, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    # ISO-Datetime mit Uhrzeit (z.B. Airtable-Snapshot-Exporte)
    m = re.match(r"^(\d{4}-\d{2}-\d{2})", s)
    return m.group(1) if m else None


def read_records(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".json":
        with open(path, encoding="utf-8-sig") as f:
            data = json.load(f)
        if isinstance(data, list):
            return [r for r in data if isinstance(r, dict)]
        if isinstance(data, dict) and isinstance(data.get("records"), list):
            return [r for r in data["records"] if isinstance(r, dict)]
        return []
    # CSV (Default), Delimiter-Sniffing mit Komma-Fallback
    with open(path, encoding="utf-8-sig", newline="") as f:
        sample = f.read(4096)
        f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
        except csv.Error:
            dialect = csv.excel
        reader = csv.DictReader(f, dialect=dialect)
        return [dict(row) for row in reader]


try:
    cfg = {}
    if os.path.isfile(config_file):
        try:
            with open(config_file, encoding="utf-8") as f:
                cfg = json.load(f)
        except Exception:
            cfg = {}

    sales_cfg = (cfg.get("modules") or {}).get("sales") or {}
    if not sales_cfg.get("enabled"):
        # Bewusst NICHT sys.exit(0): Exit-Code 3 markiert "dieser Lauf hat
        # sales.json absichtlich nicht angefasst" fuer die Absturz-Pruefung
        # unten in der Bash-Huelle, die sonst ein fehlendes/altes sales.json
        # faelschlich als abgestuerzten Collector werten wuerde.
        sys.exit(3)

    pipeline_cfg = sales_cfg.get("pipeline") or {}
    if pipeline_cfg.get("source") != "file":
        # Datei ist nicht die aktive Quelle, sales.json gehoert einem anderen Schreiber.
        sys.exit(3)

    file_cfg = pipeline_cfg.get("file") or {}
    raw_drop_path = file_cfg.get("drop_path") or "~/.claude/dashboard/drop/sales"
    drop_path = os.path.expanduser(raw_drop_path)

    field_map = pipeline_cfg.get("field_map") or {}
    stages_cfg = pipeline_cfg.get("stages") or []
    stage_by_id = {}
    stage_lookup = {}
    for st in stages_cfg:
        sid = st.get("id")
        if not sid:
            continue
        stage_by_id[sid] = {"id": sid, "label": st.get("label", sid), "category": st.get("category", "lead"),
                             "forecast": bool(st.get("forecast", False)), "count": 0, "value_sum": 0.0}
        stage_lookup[str(sid).strip().lower()] = sid
        if st.get("label"):
            stage_lookup[str(st.get("label")).strip().lower()] = sid

    def base_sales(status, adapter="file", hint=""):
        return {
            "generated_at": generated_at,
            "sources": {
                "pipeline": {"status": status, "adapter": adapter, "updated_at": generated_at, "hint": hint},
                "leads": {"status": "not_configured"},
                "events": {"status": "not_configured", "available": False},
            },
            "stages": list(stage_by_id.values()),
            "kpis": {"expected_revenue": 0, "expected_revenue_deals": 0, "conversations": 0,
                     "won": 0, "companies_in_pipeline": 0},
            "deals": [],
            "leads": {"status": "not_configured"},
            "events": {"available": False, "items": []},
        }

    if not os.path.isdir(drop_path):
        write_out(base_sales("not_configured", hint="Export ablegen unter %s" % raw_drop_path))
        print("sales.json (drop_path fehlt) geschrieben: %s" % drop_path)
        sys.exit(0)

    candidates = []
    for name in os.listdir(drop_path):
        if not (name.lower().endswith(".csv") or name.lower().endswith(".json")):
            continue
        full = os.path.join(drop_path, name)
        if os.path.isfile(full):
            candidates.append(full)

    if not candidates:
        write_out(base_sales("not_configured", hint="Export ablegen unter %s" % raw_drop_path))
        print("sales.json (keine Datei im Drop) geschrieben")
        sys.exit(0)

    newest = max(candidates, key=os.path.getmtime)

    try:
        records = read_records(newest)
    except Exception as e:
        write_out(base_sales("error", hint="Datei %s konnte nicht gelesen werden: %s" % (os.path.basename(newest), str(e)[:150])))
        print("sales.json (Lesefehler) geschrieben: %s" % e)
        sys.exit(0)

    unassigned_id = "unzugeordnet"
    unassigned_hint = ""
    deals_all = []
    companies_lead_active = set()

    name_field = field_map.get("name")
    company_field = field_map.get("company")
    stage_field = field_map.get("stage")
    value_field = field_map.get("value")
    next_step_field = field_map.get("next_step")
    due_field = field_map.get("due")

    for row in records:
        if not isinstance(row, dict):
            continue
        raw_stage = str(row.get(stage_field, "")).strip() if stage_field else ""
        stage_id = stage_lookup.get(raw_stage.lower())
        if stage_id is None:
            if raw_stage:
                if unassigned_id not in stage_by_id:
                    stage_by_id[unassigned_id] = {"id": unassigned_id, "label": "Unzugeordnet", "category": "lead",
                                                   "forecast": False, "count": 0, "value_sum": 0.0}
                stage_id = unassigned_id
                unassigned_hint = "Unbekannte Stage-Werte in der Quelle (z.B. \"%s\") wurden als \"Unzugeordnet\" eingeordnet." % raw_stage
            else:
                continue

        stage_entry = stage_by_id[stage_id]
        value = parse_amount(row.get(value_field)) if value_field else None
        stage_entry["count"] += 1
        stage_entry["value_sum"] += value or 0.0

        company = str(row.get(company_field, "")).strip() if company_field else ""
        category = stage_entry["category"]
        if category in ("lead", "active") and company:
            companies_lead_active.add(company)

        due_raw = row.get(due_field) if due_field else None
        due = parse_date(due_raw)
        deal = {
            "name": str(row.get(name_field, "")).strip() if name_field else "",
            "company": company,
            "stage": stage_id,
            "value": value or 0,
            "next_step": str(row.get(next_step_field, "")).strip() if next_step_field else "",
            "due": due,
            "overdue": bool(due and due < today),
            "_category": category,
            "_forecast": stage_entry["forecast"],
        }
        deals_all.append(deal)

    expected_revenue = sum(d["value"] for d in deals_all if d["_forecast"])
    expected_revenue_deals = sum(1 for d in deals_all if d["_forecast"])
    conversations = sum(1 for d in deals_all if d["_category"] in ("active", "won"))
    won = sum(1 for d in deals_all if d["_category"] == "won")

    lead_active_deals = [d for d in deals_all if d["_category"] in ("lead", "active")]
    lead_active_deals.sort(key=lambda d: (d["due"] is None, d["due"] or ""))
    lead_active_deals = lead_active_deals[:50]
    for d in lead_active_deals:
        d.pop("_category", None)
        d.pop("_forecast", None)

    stages_out = []
    for st in stage_by_id.values():
        st = dict(st)
        st["value_sum"] = round(st["value_sum"], 2)
        stages_out.append(st)

    payload = {
        "generated_at": generated_at,
        "sources": {
            "pipeline": {"status": "ok", "adapter": "file", "updated_at": generated_at, "hint": unassigned_hint},
            "leads": {"status": "not_configured"},
            "events": {"status": "not_configured", "available": False},
        },
        "stages": stages_out,
        "kpis": {
            "expected_revenue": round(expected_revenue, 2),
            "expected_revenue_deals": expected_revenue_deals,
            "conversations": conversations,
            "won": won,
            "companies_in_pipeline": len(companies_lead_active),
        },
        "deals": lead_active_deals,
        "leads": {"status": "not_configured"},
        "events": {"available": False, "items": []},
    }
    write_out(payload)
    print("sales.json geschrieben (Quelle: %s, Deals: %d, erwarteter Umsatz: %.2f)" % (
        os.path.basename(newest), len(deals_all), expected_revenue))
except SystemExit:
    raise
except Exception as e:
    try:
        write_out({"generated_at": generated_at, "sources": {"pipeline": {"status": "error", "adapter": "file",
                   "updated_at": generated_at, "hint": str(e)[:200]}, "leads": {"status": "not_configured"},
                   "events": {"status": "not_configured", "available": False}},
                   "stages": [], "kpis": {"expected_revenue": 0, "expected_revenue_deals": 0, "conversations": 0,
                   "won": 0, "companies_in_pipeline": 0}, "deals": [], "leads": {"status": "not_configured"},
                   "events": {"available": False, "items": []}})
    except Exception:
        pass
    print("sales-file.sh Fehler: %s" % e)
    sys.exit(0)
PYEOF
rc=$?

if [ "$rc" -eq 3 ]; then
  # Modul aus oder Pipeline-Quelle ungleich "file": sales.json gehoert einem
  # anderen Schreiber und wurde in diesem Lauf bewusst nicht angefasst. Das
  # ist kein Fehler, deshalb ohne Absturz-Pruefung sauber beenden.
  echo "sales-collector uebersprungen (Modul aus oder andere Pipeline-Quelle, sales.json unangetastet)."
  exit 0
fi

verify_json_output "$rc" "$OUT_FILE" "sales-collector" "$GENERATED_AT" || exit 1

chmod 644 "$OUT_FILE" 2>/dev/null || true
