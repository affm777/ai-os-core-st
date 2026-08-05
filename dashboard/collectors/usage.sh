#!/bin/bash
# usage.sh — Nutzungsstatistik: ccusage (falls installiert) + Session-/Skill-Zaehlung
# aus ~/.claude/projects/*/*.jsonl der letzten 7 Tage. Read-only, zaehlt NUR,
# uebernimmt NIEMALS Transkript-Inhalte in die JSON-Ausgabe.
#
# Zaehlpolitik (siehe tuning-signals.sh / Dashboard-Plan):
#   - HAUPTSESSION = Datei mit mind. einer "isSidechain":false-Zeile.
#     Sub-Agent-Transkripte (subagents/agent-*.jsonl) zaehlen separat.
#   - Sessions/Quoten/Coverage: nur Hauptsessions.
#   - Skill-Zaehler: ueber ALLE Sessions (inkl. Sub-Agents).

set -euo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="$HOME/.claude/dashboard"
DATA_DIR="$DASH_DIR/data"
PROJECTS_DIR="$HOME/.claude/projects"
REPOS_YAML="$HOME/.claude/project-repos.yaml"
mkdir -p "$DATA_DIR"

OUT_FILE="$DATA_DIR/usage.json"
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

# --- ccusage ---
CCUSAGE_TMP="$(mktemp)"
CCUSAGE_AVAILABLE=false
if command -v ccusage >/dev/null 2>&1; then
  if ccusage daily --json > "$CCUSAGE_TMP" 2>/dev/null; then
    CCUSAGE_AVAILABLE=true
  fi
fi

# --- Dateiliste (letzte 7 Tage, KEIN maxdepth: subagents/ mitnehmen) ---
FILES_TMP="$(mktemp)"
trap 'rm -f "$FILES_TMP" "$CCUSAGE_TMP"' EXIT
if [[ -d "$PROJECTS_DIR" ]]; then
  find "$PROJECTS_DIR" -type f -name "*.jsonl" -mtime -7 2>/dev/null > "$FILES_TMP"
fi
# MSYS-Pfade aus der Trefferliste fuer natives Windows-Python aufloesbar
# machen (siehe normalize_path_list in python-bin.sh).
normalize_path_list "$FILES_TMP"

# "set -e" wuerde bei einem abstuerzenden Python-Payload das Skript sofort
# beenden (guter Grundschutz, siehe unten), aber VOR jeder eigenen Pruefung
# und mit einer nackten Traceback-Zeile statt einer verstaendlichen Meldung.
# Schlimmer: "> $OUT_FILE" leert die Datei schon beim Parsen der Umleitung,
# bevor Python ueberhaupt laeuft. Stuerzt das Payload dann ab, bleibt kein
# Absturz-Hinweis zurueck, sondern eine leere/kaputte usage.json (die
# skills.sh und portfolio.sh lesen). Deshalb hier "set -e" fuer diesen einen
# Aufruf gezielt aussetzen, den Exit-Code selbst einsammeln und verstaendlich
# melden, wie bei den anderen Collectors.
set +e
$PYBIN - "$GENERATED_AT" "$CCUSAGE_AVAILABLE" "$FILES_TMP" "$REPOS_YAML" <<'PYEOF' > "$OUT_FILE"
import sys, json, os, re, time

generated_at, ccusage_available_str, files_tmp, repos_yaml = sys.argv[1:5]
ccusage_available = ccusage_available_str == "true"

with open(files_tmp, encoding="utf-8") as f:
    files = [l.strip() for l in f if l.strip()]

# Registrierte Projektpfade
project_paths = []
if os.path.isfile(repos_yaml):
    with open(repos_yaml, encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            m = re.match(r"^([A-Za-z0-9_-]+):\s*(.+)$", s)
            if m:
                project_paths.append((m.group(1), os.path.normpath(os.path.expanduser(m.group(2).strip()))))

def project_for_cwd(cwd):
    if not cwd:
        return None
    c = os.path.normpath(cwd)
    best = None
    for slug, p in project_paths:
        if c == p or c.startswith(p + os.sep):
            if best is None or len(p) > len(best[1]):
                best = (slug, p)
    return best[0] if best else None

# Sessions, die bewusst direkt im Second-Brain-Verzeichnis laufen (Vault-Automationen:
# sort-inbox, sync-meetings, health-check ...), sind KEINE kontextlosen Streu-Sessions.
# Sie bekommen einen eigenen Bucket und fallen aus dem off_project-Nenner der Abdeckung.
SECOND_BRAIN = os.path.normpath(os.path.expanduser("~/Documents/Second-Brain"))
def is_automation(cwd):
    if not cwd:
        return False
    c = os.path.normpath(cwd)
    return c == SECOND_BRAIN or c.startswith(SECOND_BRAIN + os.sep)

WD = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

main_count = 0
sub_count = 0
wrapup = 0
resume = 0
cov_in = 0
cov_off = 0
cov_auto = 0
skill_counts = {}
by_project = {}
by_day = {}   # "YYYY-MM-DD" -> n (nur Hauptsessions)

# Fail-closed am ERGEBNIS statt an der Vorbedingung: einzelne unlesbare
# Dateien sind tolerierbar (z.B. race mit einer parallel schreibenden
# Session), aber wenn ALLE gefundenen Pfade unlesbar sind, ist das kein
# legitim leeres Ergebnis, sondern ein Systemfehler (z.B. MSYS-Pfade, die
# natives Python nicht findet). Sonst sieht ein Totalausfall wie "0 Sessions"
# aus und wird als "meta": {"status": "ok"} durchgereicht.
opened_count = 0

for path in files:
    is_main = False
    cwd = None
    session_skills = set()
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            opened_count += 1
            for line in fh:
                if not line.strip():
                    continue
                if '"isSidechain":false' in line:
                    is_main = True
                if cwd is None and '"cwd"' in line:
                    cm = re.search(r'"cwd"\s*:\s*"([^"]*)"', line)
                    if cm:
                        cwd = cm.group(1)
                if '"name":"Skill"' in line:
                    for sm in re.findall(r'"name":"Skill","input":\{"skill":"([^"]*)"', line):
                        session_skills.add(sm)
                # Vom Nutzer getippte Slash-Commands stehen als <command-name>-Block
                # in User-Messages (nicht als Skill-Tool-Use). Beide Formen zaehlen
                # je Session als eine Invocation (Set dedupliziert automatisch).
                # Muster bewusst streng: Name muss mit Buchstabe beginnen und der
                # schliessende Tag ist Pflicht. Sonst matcht die Regex ihren eigenen
                # Quelltext, sobald ueber dieses Skript gesprochen wurde, und
                # Fragmente landen als vermeintliche Skills in der Auswertung.
                if '<command-name>' in line:
                    for cm in re.findall(r'<command-name>\s*/?([A-Za-z][A-Za-z0-9:_-]*)\s*</command-name>', line):
                        session_skills.add(cm)
    except Exception:
        continue

    for s in session_skills:
        skill_counts[s] = skill_counts.get(s, 0) + 1

    if not is_main:
        sub_count += 1
        continue

    main_count += 1
    if "wrap-up" in session_skills:
        wrapup += 1
    if "resume-session" in session_skills:
        resume += 1

    slug = project_for_cwd(cwd)
    if slug is not None:
        cov_in += 1
        by_project[slug] = by_project.get(slug, 0) + 1
    elif is_automation(cwd):
        cov_auto += 1
        by_project["(Automation)"] = by_project.get("(Automation)", 0) + 1
    else:
        cov_off += 1
        by_project["(ohne Projekt)"] = by_project.get("(ohne Projekt)", 0) + 1

    try:
        d = time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(path)))
        by_day[d] = by_day.get(d, 0) + 1
    except OSError:
        pass

# Totalausfall abbrechen statt eine leere/degradierte JSON zu schreiben (siehe
# Kommentar bei "opened_count" oben). Einzelne unlesbare Dateien bleiben ok.
if len(files) > 0 and opened_count == 0:
    print(
        f"FEHLER: {len(files)} Session-Datei(en) gefunden, aber keine einzige "
        "lesbar (Pfad-Problem? siehe normalize_path_list in python-bin.sh).",
        file=sys.stderr,
    )
    sys.exit(1)

# by_day: die letzten 7 Kalendertage bis heute
today = time.localtime()
today_mid = time.mktime((today.tm_year, today.tm_mon, today.tm_mday, 0, 0, 0, 0, 0, -1))
day_series = []
for off in range(6, -1, -1):
    lt = time.localtime(today_mid - off * 86400)
    ds = time.strftime("%Y-%m-%d", lt)
    day_series.append({
        "d": WD[lt.tm_wday],
        "date": time.strftime("%d.%m.", lt),   # kurzes Datum fuer die Achse
        "n": by_day.get(ds, 0),
        "today": off == 0,                      # letzter Balken ist heute
    })

by_project_arr = sorted(
    [{"p": k, "n": v} for k, v in by_project.items()],
    key=lambda x: -x["n"],
)[:8]

top_skills = sorted(skill_counts.items(), key=lambda kv: -kv[1])[:10]

def quote(n, d):
    return round(n / d, 2) if d else None

out = {
    "generated_at": generated_at,
    "sessions_last_7_days": {
        "total": main_count,
        "main": main_count,
        "subagent": sub_count,
        "by_day": day_series,
        "by_project": by_project_arr,
    },
    "skill_invocations_last_7_days": {
        "total": sum(skill_counts.values()),
        "top": [{"skill": s, "count": c} for s, c in top_skills],
        # Vollstaendige Zaehlkarte: "top" ist auf 10 gekappt, der Skills-Katalog
        # braucht aber Zahlen fuer jeden installierten Skill.
        "counts": skill_counts,
    },
    "core_workflow": {
        "main_sessions": main_count,
        "resume_sessions": resume,
        "resume_quote": quote(resume, main_count),
        "wrapup_sessions": wrapup,
        "wrapup_quote": quote(wrapup, main_count),
    },
    "project_coverage": {
        "in_project": cov_in,
        "off_project": cov_off,
        "automation": cov_auto,
        "quote": quote(cov_in, cov_in + cov_off),
    },
}

if ccusage_available:
    out["ccusage"] = {"available": True}
else:
    out["ccusage"] = {"available": False, "hint": "npm i -g ccusage"}

print(json.dumps(out, ensure_ascii=False, indent=2))
PYEOF
rc=$?
set -e

verify_json_output "$rc" "$OUT_FILE" "usage-collector" "$GENERATED_AT" || exit 1

# ccusage-Rohdaten (falls vorhanden) separat anhaengen. Gleiche Absicherung
# wie oben: dieser zweite Aufruf liest das gerade frisch geschriebene
# usage.json und haengt nur "ccusage.daily" an, "generated_at" bleibt dabei
# unveraendert der obige GENERATED_AT-Wert, der Abgleich bleibt also gueltig.
if [[ "$CCUSAGE_AVAILABLE" == true ]]; then
  set +e
  $PYBIN - "$OUT_FILE" "$CCUSAGE_TMP" <<'PYEOF2'
import json, sys
out_file, ccusage_tmp = sys.argv[1], sys.argv[2]
with open(out_file, encoding="utf-8") as f:
    data = json.load(f)
try:
    with open(ccusage_tmp, encoding="utf-8") as f:
        ccusage_data = json.load(f)
    data["ccusage"]["daily"] = ccusage_data
except Exception as e:
    data["ccusage"] = {"available": False, "hint": "ccusage-Output nicht parsebar: " + str(e)}
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
PYEOF2
  rc2=$?
  set -e
  verify_json_output "$rc2" "$OUT_FILE" "usage-collector (ccusage-Anhang)" "$GENERATED_AT" || exit 1
fi

chmod 644 "$OUT_FILE"
echo "usage.json geschrieben: $OUT_FILE"
