#!/bin/bash
# heute.sh — deterministischer Kalender-Collector fuer das Dashboard (0 Tokens).
#
# Zieht die HEUTIGEN Termine des optionalen gws-Zweitkontos ueber die gws-CLI, die
# ein eigenes gespeichertes OAuth-Token hat und KEIN Claude/MCP braucht. Laeuft damit
# bei jedem "Aktualisieren" mit, ohne einen Claude-Lauf und ohne Tokens. Das gws-Konto
# ist optional: ist die gws-CLI nicht installiert, wird das sichtbar gemacht (unavailable).
#
# WICHTIG — Zwei-Schreiber-Schutz:
#   heute.json wird auch vom interaktiven /aios-dashboard-Skill geschrieben (privater
#   Kalender via MCP, Mail-Triage, Deals). Dieser Collector fasst NUR die
#   gws-Kalendereintraege an (quelle == "gws") und ERHAELT alles andere
#   (mail, deals, privat-Kalendereintraege, sources.*) aus der bestehenden Datei.
#
# Fehlersichtbarkeit: schlaegt der gws-Aufruf fehl/ist nicht authentifiziert,
#   wird sources.gws_calendar.status = "auth_error" gesetzt (nicht still leer),
#   damit das Dashboard "Termine heute frei" nur bei einem sauberen Lauf zeigt.

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="$HOME/.claude/dashboard"
DATA_DIR="$DASH_DIR/data"
mkdir -p "$DATA_DIR"
OUT_FILE="$DATA_DIR/heute.json"
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

# gws-Kalender abfragen (read-only). stdout enthaelt evtl. eine Keyring-Zeile vor dem JSON.
GWS_RAW=""
GWS_STATUS="ok"
if command -v gws >/dev/null 2>&1; then
  if ! GWS_RAW=$(gws calendar +agenda --today --format json 2>/dev/null); then
    GWS_STATUS="auth_error"
  fi
else
  GWS_STATUS="unavailable"
fi

RAW_TMP="$(mktemp)"
trap 'rm -f "$RAW_TMP"' EXIT
printf '%s' "$GWS_RAW" > "$RAW_TMP"

$PYBIN - "$GENERATED_AT" "$OUT_FILE" "$RAW_TMP" "$GWS_STATUS" <<'PYEOF'
import sys, json, os, re

generated_at, out_file, raw_tmp, gws_status = sys.argv[1:5]

# --- Bestehende heute.json laden (Read-Merge) ---
existing = {}
if os.path.isfile(out_file):
    try:
        with open(out_file, encoding="utf-8") as f:
            existing = json.load(f)
    except Exception:
        existing = {}

prev_kal = existing.get("kalender") if isinstance(existing.get("kalender"), list) else []
# Alles ausser den bisherigen gws-Eintraegen erhalten (privat kommt aus /aios-dashboard).
kept = [e for e in prev_kal if isinstance(e, dict) and e.get("quelle") != "gws"]

# --- gws-Rohdaten parsen ---
gws_events = []
if gws_status == "ok":
    try:
        with open(raw_tmp, encoding="utf-8") as f:
            raw = f.read()
        i = raw.find("{")
        data = json.loads(raw[i:]) if i >= 0 else {}
        events = data.get("events") or []
        for ev in events:
            if not isinstance(ev, dict):
                continue
            # Titel robust aus mehreren moeglichen Feldern
            titel = ev.get("summary") or ev.get("title") or ev.get("titel") or "(ohne Titel)"
            # Startzeit robust: start kann String (ISO) oder Objekt {dateTime|date} sein
            start = ev.get("start")
            zeit = ""
            iso = None
            if isinstance(start, dict):
                iso = start.get("dateTime") or start.get("date")
            elif isinstance(start, str):
                iso = start
            if iso:
                m = re.search(r"T(\d{2}:\d{2})", iso)
                zeit = m.group(1) if m else ("ganztags" if re.match(r"^\d{4}-\d{2}-\d{2}$", iso) else "")
            gws_events.append({"zeit": zeit, "titel": titel, "konto": "gws", "quelle": "gws"})
    except Exception:
        gws_status = "parse_error"

def sort_key(e):
    z = e.get("zeit") or ""
    return (0, z) if re.match(r"^\d{2}:\d{2}$", z) else (1, z)

kalender = sorted(kept + gws_events, key=sort_key)

# sources erhalten + gws-Status aktualisieren
sources = existing.get("sources") if isinstance(existing.get("sources"), dict) else {}
sources["gws_calendar"] = {"status": gws_status, "updated_at": generated_at, "count": len(gws_events)}

out = {
    "generated_at": generated_at,
    "kalender": kalender,
    "mail": existing.get("mail", {"handeln": 0, "warten": 0, "kenntnis": 0, "top": []}),
    "deals": existing.get("deals", []),
    "sources": sources,
}
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)
print("heute.json geschrieben (gws-kalender: %d, status: %s)" % (len(gws_events), gws_status))
PYEOF
rc=$?

# heute.json existiert durch den Zwei-Schreiber-Betrieb IMMER schon (Vorlauf
# vom /aios-dashboard-Skill oder einem frueheren Lauf), deshalb hier zwingend
# mit generated_at-Abgleich pruefen (siehe python-bin.sh), sonst wuerde ein
# mittendrin abgestuerzter Lauf durch die stehengebliebene alte Datei als
# Erfolg durchgehen.
verify_json_output "$rc" "$OUT_FILE" "heute-collector" "$GENERATED_AT" || exit 1

chmod 644 "$OUT_FILE" 2>/dev/null || true
