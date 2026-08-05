#!/bin/bash
# automationen.sh — Listet die echten geplanten Tasks (~/.claude/scheduled-tasks/*)
# und leitet Rhythmus + echten Lauf-Status aus den Session-Transcripts ab.
# Quelle für den letzten Lauf-ZEITPUNKT, in dieser Reihenfolge (der neuere gewinnt):
#   1) ~/.claude/scheduled-tasks/<name>/.last-run  (ISO mit Uhrzeit, von der Routine
#      als ERSTER Schritt geschrieben — bedeutet nur "gestartet", nicht "erfolgreich").
#   2) task-spezifische Marker (z.B. .last-fathom-sync) → tagesgenau.
#   3) vault-log-Timeline (Stichwort-Match) → tagesgenauer Fallback.
# Der echte Erfolg/Fehler-STATUS kommt separat aus den Session-Transcripts
# unter ~/.claude/projects/*/*.jsonl (siehe scan_runs). Ein Fehler-Lauf dort
# überschreibt jeden Marker-Status.
# Read-only. Kein LLM. Schreibziel: data/automationen.json.

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="${DASH_DIR:-$HOME/.claude/dashboard}"
DATA_DIR="$DASH_DIR/data"
TASKS_DIR="${TASKS_DIR:-$HOME/.claude/scheduled-tasks}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/.claude/projects}"
VAULT_LOG="${VAULT_LOG:-$HOME/Documents/Second-Brain/00_Meta/system/vault-log.md}"
mkdir -p "$DATA_DIR"

OUT_FILE="$DATA_DIR/automationen.json"
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

$PYBIN - "$GENERATED_AT" "$TASKS_DIR" "$VAULT_LOG" "$OUT_FILE" "$PROJECTS_DIR" <<'PYEOF'
import sys, os, re, json, glob, time
from datetime import datetime

generated_at, tasks_dir, vault_log, out_file, projects_dir = sys.argv[1:6]
VAULT_SYS_DIR = os.path.dirname(vault_log)
LOCAL_TZ = datetime.now().astimezone().tzinfo
TODAY = datetime.now().date()

def parse_frontmatter(path):
    try:
        with open(path, encoding="utf-8") as f:
            txt = f.read()
    except OSError:
        return {}
    out = {}
    m = re.match(r"^---\s*\n(.*?)\n---", txt, re.DOTALL)
    block = m.group(1) if m else txt[:400]
    for key in ("name", "description"):
        km = re.search(r"^%s:\s*(.+)$" % key, block, re.MULTILINE)
        if km:
            out[key] = km.group(1).strip().strip('"').strip("'")
    return out

def read_iso(path):
    """Liest eine ISO-8601-Zeile aus einer Datei -> aware/naive datetime oder None."""
    try:
        with open(path, encoding="utf-8") as f:
            s = f.read().strip()
    except OSError:
        return None
    if not s:
        return None
    s = s.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(s)
    except ValueError:
        # nur Datum?
        try:
            return datetime.strptime(s[:10], "%Y-%m-%d")
        except ValueError:
            return None

def to_local(dt):
    if dt.tzinfo is None:
        return dt
    return dt.astimezone(LOCAL_TZ).replace(tzinfo=None)

def parse_iso_utc_to_local(ts):
    """Transcript-Timestamps sind UTC (Z-Suffix). None bei Parse-Fehler."""
    if not ts:
        return None
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None
    return to_local(dt)

# vault-log Zeilen: "## [YYYY-MM-DD] <op> | <summary>"
log_lines = []
if os.path.isfile(vault_log):
    with open(vault_log, encoding="utf-8") as f:
        for ln in f:
            lm = re.match(r"^##\s*\[(\d{4}-\d{2}-\d{2})\]\s*(.*)$", ln.strip())
            if lm:
                log_lines.append((lm.group(1), lm.group(2).lower()))

def vaultlog_last(patterns):
    best = None
    for date, text in log_lines:
        if any(p in text for p in patterns):
            if best is None or date > best:
                best = date
    if not best:
        return None
    try:
        return datetime.strptime(best, "%Y-%m-%d")
    except ValueError:
        return None

# (datetime, has_time, quelle) — erste Quelle, die trifft, gewinnt.
def resolve_marker(name, meta):
    marker = os.path.join(tasks_dir, name, ".last-run")
    dt = read_iso(marker)
    if dt:
        return to_local(dt), True, "marker"
    for extra in meta.get("extra_markers", []):
        dt = read_iso(os.path.join(VAULT_SYS_DIR, extra))
        if dt:
            # Diese Marker sind tagesgenau (Uhrzeit bedeutungslos) -> keine Zeit zeigen.
            return to_local(dt), False, "extra"
    dt = vaultlog_last(meta.get("patterns", [name]))
    if dt:
        return dt, False, "vault-log"
    return None, False, None

def humanize(dt, has_time):
    if dt is None:
        return "—"
    ld = to_local(dt) if dt.tzinfo else dt
    days = (TODAY - ld.date()).days
    t = " %02d:%02d" % (ld.hour, ld.minute) if has_time else ""
    if days <= 0:
        return "heute" + t
    if days == 1:
        return "gestern" + t
    if days < 7:
        return "vor %d Tagen" % days
    return ld.strftime("%d.%m.")

def days_ago(dt):
    if dt is None:
        return None
    ld = to_local(dt) if dt.tzinfo else dt
    return (TODAY - ld.date()).days

# --- Transcript-Scanner --------------------------------------------------
# Bewusste Entscheidungen:
# - Kein Cache: der Billig-Filter (nur erste Zeile lesen) reicht bei den
#   üblichen Größenordnungen (aktuell ~50 Dateien / ~22 MB), Voll-Scan nur
#   bei Treffer.
# - tool_result.is_error zaehlt NICHT als Lauf-Fehler: normale Tool-Retries
#   innerhalb eines ansonsten erfolgreichen Laufs waeren sonst False-Positives.
#   Nur ein Session-weiter API-Fehler (isApiErrorMessage / model "<synthetic>")
#   zaehlt als Fehler-Lauf.
# - Scan generisch ueber ALLE projects/*/-Slugs: fremde Teilnehmer-Setups
#   haben andere cwd-Slugs als dieser Rechner, der Scan darf sich nicht auf
#   einen Slug festlegen.
TASK_RE = re.compile(r'<scheduled-task name="([^"]+)"')

def scan_runs(pdir):
    runs = {}
    if not os.path.isdir(pdir):
        return runs
    for f in glob.glob(os.path.join(pdir, "*", "*.jsonl")):
        try:
            with open(f, encoding="utf-8") as fh:
                head = json.loads(fh.readline())
        except (OSError, ValueError, TypeError):
            continue
        if head.get("type") != "queue-operation" or head.get("operation") != "enqueue":
            continue
        # WICHTIG: Regex nur auf dem bereits json-geparsten content-Feld,
        # niemals raw ueber den Dateiinhalt (sonst matchen Transcripts von
        # Sessions, die selbst ueber Scheduled Tasks sprechen, faelschlich).
        m = TASK_RE.search(head.get("content") or "")
        if not m:
            continue
        name = m.group(1)
        ts = parse_iso_utc_to_local(head.get("timestamp"))
        if ts is None:
            continue  # Lauf ohne verwertbaren Zeitstempel wird verworfen
        error_text = None
        try:
            with open(f, encoding="utf-8") as fh:  # Voll-Scan nur bei Treffer
                for ln in fh:
                    try:
                        o = json.loads(ln)
                    except ValueError:
                        continue
                    msg = o.get("message") or {}
                    if o.get("isApiErrorMessage") or msg.get("model") == "<synthetic>":
                        c = msg.get("content")
                        if isinstance(c, list) and c and isinstance(c[0], dict):
                            error_text = (c[0].get("text") or "API Error")[:160]
                        else:
                            error_text = "API Error"
        except OSError:
            continue
        status = "fehler" if error_text else "ok"
        # Session vermutlich noch offen: Datei in den letzten 15 Minuten
        # geschrieben und (bisher) kein Fehler.
        try:
            mtime = os.path.getmtime(f)
        except OSError:
            mtime = 0
        if status == "ok" and (time.time() - mtime) < 15 * 60:
            status = "laeuft"
        runs.setdefault(name, []).append({
            "ts": ts, "status": status,
            "session_id": head.get("sessionId"), "error": error_text,
        })
    for name in runs:
        runs[name].sort(key=lambda r: r["ts"], reverse=True)
        runs[name] = runs[name][:7]
    return runs

TRANSCRIPT_RUNS = scan_runs(projects_dir)

# Kuratierte Anzeige-Metadaten je bekanntem Task. Stichwoerter nur noch als
# Fallback (Marker haben Vorrang); "meeting" bewusst raus, matchte Sweep-Zeilen.
META = {
    "fathom-sync":  {"titel": "Meeting-Notizen einsammeln", "rhythmus": "nachts · täglich",
                     "patterns": ["fathom", "sync-meetings", "sync-fix"],
                     "extra_markers": [".last-fathom-sync"], "max_age": 3},
    "inbox-sort":   {"titel": "Inbox einsortieren", "rhythmus": "nachts · täglich",
                     "patterns": ["sweep", "sort-inbox"], "max_age": 3},
    "vault-health": {"titel": "Second Brain prüfen", "rhythmus": "wöchentlich",
                     "patterns": ["lint", "health"], "max_age": 9},
}

def rhythm_from_desc(desc):
    d = (desc or "").lower()
    if "wöchentlich" in d or "woechentlich" in d:
        return "wöchentlich"
    if "täglich" in d or "taeglich" in d:
        return "nachts · täglich"
    return "geplant"

tasks = []
for d in sorted(glob.glob(os.path.join(tasks_dir, "*"))):
    if not os.path.isdir(d):
        continue
    name = os.path.basename(d)
    fm = parse_frontmatter(os.path.join(d, "SKILL.md"))
    if not fm.get("name") and not os.path.isfile(os.path.join(d, "SKILL.md")):
        continue
    meta = META.get(name, {})
    desc = fm.get("description", "")
    max_age = meta.get("max_age", 8)

    marker_dt, marker_has_time, marker_quelle = resolve_marker(name, meta)
    runs = TRANSCRIPT_RUNS.get(name, [])
    newest_run = runs[0] if runs else None

    # zuletzt = juengerer von Marker-Zeit und juengstem Transcript-Lauf.
    last_dt, has_time, quelle = marker_dt, marker_has_time, marker_quelle
    if newest_run is not None:
        rt = newest_run["ts"]
        if last_dt is None or rt > last_dt:
            last_dt, has_time, quelle = rt, True, "transcript"

    age = days_ago(last_dt)

    if newest_run is not None and newest_run["status"] == "fehler":
        status = "fehler"
    elif age is None or age > max_age:
        status = "ueberfaellig"
    else:
        status = "ok"

    fehler_text = newest_run["error"] if (status == "fehler" and newest_run) else None

    ok_run = next((r for r in runs if r["status"] == "ok"), None)
    zuletzt_erfolgreich = humanize(ok_run["ts"], True) if ok_run else None

    verlauf = [{
        "ts": r["ts"].strftime("%Y-%m-%dT%H:%M:%S"),
        "status": r["status"],
        "session_id": r["session_id"],
    } for r in runs]

    tasks.append({
        "name": name,
        "titel": meta.get("titel", name),
        "rhythmus": meta.get("rhythmus") or rhythm_from_desc(desc),
        "zuletzt": humanize(last_dt, has_time),
        "quelle": quelle or "unbekannt",
        "status": status,
        "desc": desc or "Geplanter Task.",
        "verlauf": verlauf,
        "zuletzt_erfolgreich": zuletzt_erfolgreich,
        "fehler_text": fehler_text,
    })

with open(out_file, "w", encoding="utf-8") as f:
    json.dump({"generated_at": generated_at, "tasks": tasks}, f, ensure_ascii=False, indent=2)

print("automationen.json geschrieben: %d Tasks" % len(tasks))
PYEOF
rc=$?

verify_json_output "$rc" "$OUT_FILE" "automationen-collector" "$GENERATED_AT" || exit 1

chmod 644 "$OUT_FILE" 2>/dev/null || true
echo "automationen-collector fertig"
