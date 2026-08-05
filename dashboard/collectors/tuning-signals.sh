#!/usr/bin/env bash
# =============================================================================
# tuning-signals.sh (Deterministischer Signal-Sammler fuer den /briefing-Wochenmodus)
# =============================================================================
# Read-only gegenueber Session-Logs und Skills. Einziges Schreibziel:
#   $OUTPUT_DIR/tuning-signals.json
#
# Aufruf:
#   bash tuning-signals.sh [tage]   (Default: 7)
#
# Zaehlpolitik (WICHTIG, siehe Dashboard-Plan):
#   - HAUPTSESSION = .jsonl-Datei mit mindestens einer "isSidechain":false-Zeile.
#     Sub-Agent-Transkripte (.../subagents/agent-*.jsonl) haben ausschliesslich
#     "isSidechain":true und zaehlen NICHT als Hauptsession.
#   - VERHALTENS-QUOTEN (resume-quote, wrapup-quote, project-coverage, Fehlerquote)
#     nur ueber Hauptsessions. Sub-Agents blaehen sonst den Nenner auf.
#   - SKILL-ZAEHLER (skills_totals, unused_skills) ueber ALLE Sessions
#     (inkl. Sub-Agents), sonst wuerde z. B. playwright-cli als ungenutzt gelten.
#
# NIE Nachrichten-Inhalte, Prompts oder Tool-Outputs uebernehmen, nur Zaehlwerte.
# Haertungsregel: fehlende Verzeichnisse fuehren zu leeren/0-Werten, nie zu einem
# Absturz des Skripts (robust gegen frische Installationen ohne Historie).
# =============================================================================

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DAYS="${1:-7}"
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "Usage: tuning-signals.sh [tage]" >&2
  exit 2
fi

CLAUDE_DIR="${TUNING_CLAUDE_DIR:-$HOME/.claude}"
PROJECTS_DIR="${TUNING_PROJECTS_DIR:-$CLAUDE_DIR/projects}"
SKILLS_DIR="${TUNING_SKILLS_DIR:-$CLAUDE_DIR/skills}"
REPOS_YAML="${TUNING_REPOS_YAML:-$CLAUDE_DIR/project-repos.yaml}"
OUTPUT_DIR="${TUNING_OUTPUT_DIR:-$HOME/.claude/dashboard/data}"
mkdir -p "$OUTPUT_DIR"

GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

# Liste der .jsonl-Dateien im Fenster einsammeln (robust, falls Verzeichnis fehlt).
# KEIN maxdepth: Sub-Agent-Files liegen in tieferen subagents/-Ordnern und werden
# fuer die Skill-Zaehlung bewusst mitgenommen.
FILES_TMP="$(mktemp)"
trap 'rm -f "$FILES_TMP"' EXIT
if [[ -d "$PROJECTS_DIR" ]]; then
  find "$PROJECTS_DIR" -type f -name "*.jsonl" -mtime "-${DAYS}" 2>/dev/null > "$FILES_TMP"
fi
# MSYS-Pfade aus der Trefferliste fuer natives Windows-Python aufloesbar
# machen (siehe normalize_path_list in python-bin.sh).
normalize_path_list "$FILES_TMP"

$PYBIN - "$GENERATED_AT" "$DAYS" "$PROJECTS_DIR" "$SKILLS_DIR" "$FILES_TMP" "$REPOS_YAML" <<'PYEOF' > "$OUTPUT_DIR/tuning-signals.json"
import sys, json, os, re

generated_at, days, projects_dir, skills_dir, files_tmp, repos_yaml = sys.argv[1:7]
days = int(days)

with open(files_tmp, encoding="utf-8") as f:
    files = [l.strip() for l in f if l.strip()]

# --- Registrierte Projektpfade laden (fuer project-coverage) ---
project_paths = []  # (slug, normalisierter Pfad)
if os.path.isfile(repos_yaml):
    with open(repos_yaml, encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            m = re.match(r"^([A-Za-z0-9_-]+):\s*(.+)$", s)
            if m:
                p = os.path.normpath(os.path.expanduser(m.group(2).strip()))
                project_paths.append((m.group(1), p))

def project_for_cwd(cwd):
    if not cwd:
        return None
    c = os.path.normpath(cwd)
    best = None
    for slug, p in project_paths:
        if c == p or c.startswith(p + os.sep):
            if best is None or len(p) > len(best[1]):  # laengster Praefix gewinnt
                best = (slug, p)
    return best[0] if best else None

# Bewusste Vault-Automationen laufen direkt im Second-Brain-Verzeichnis und sind
# KEINE kontextlosen Streu-Sessions -> eigener Bucket, aus dem off_project-Nenner raus.
SECOND_BRAIN = os.path.normpath(os.path.expanduser("~/Documents/Second-Brain"))
def is_automation(cwd):
    if not cwd:
        return False
    c = os.path.normpath(cwd)
    return c == SECOND_BRAIN or c.startswith(SECOND_BRAIN + os.sep)

# --- Pro Datei: Hauptsession? Skills? Fehler? cwd? ---
main_projects = {}       # key -> {sessions, wrapup, resume, errors, registered}
skills_totals = {}       # ueber ALLE Sessions (inkl. Sub-Agents)
main_count = 0
sub_count = 0
sub_errors = 0
wrapup_total = 0
resume_total = 0
main_errors_total = 0
coverage_in = 0
coverage_off = 0
coverage_auto = 0
off_cwds = {}

# Fail-closed am ERGEBNIS statt an der Vorbedingung: einzelne unlesbare
# Dateien sind tolerierbar, aber wenn ALLE gefundenen Pfade unlesbar sind, ist
# das kein legitim leeres Ergebnis, sondern ein Systemfehler (z.B. MSYS-Pfade,
# die natives Python nicht findet). Sonst sieht ein Totalausfall wie "0
# Sessions, 0 Skills" aus und wird durchgereicht.
opened_count = 0

for path in files:
    parent = os.path.basename(os.path.dirname(path))
    is_main = False
    cwd = None
    session_skills = set()
    error_count = 0
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            opened_count += 1
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                if '"isSidechain":false' in line:
                    is_main = True
                error_count += line.count('"is_error":true')
                if cwd is None and '"cwd"' in line:
                    cm = re.search(r'"cwd"\s*:\s*"([^"]*)"', line)
                    if cm:
                        cwd = cm.group(1)
                # Vom Nutzer getippte Slash-Commands stehen als <command-name>-Block
                # in User-Messages (nicht als Skill-Tool-Use). Beide Formen zaehlen
                # je Session als eine Invocation (Set dedupliziert automatisch).
                if '<command-name>' in line:
                    for cmd in re.findall(r'<command-name>\s*/?([^<\s]+)', line):
                        if re.search(r'[A-Za-z]', cmd):   # Rausch-Keys wie "/" ausblenden
                            session_skills.add(cmd)
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                msg = obj.get("message")
                if not isinstance(msg, dict):
                    continue
                content = msg.get("content")
                if not isinstance(content, list):
                    continue
                for c in content:
                    if isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Skill":
                        inp = c.get("input")
                        if isinstance(inp, dict) and inp.get("skill"):
                            session_skills.add(inp.get("skill"))
    except Exception:
        continue

    # Skill-Zaehler ueber ALLE Sessions (je Session einmal pro Skill)
    for s in session_skills:
        skills_totals[s] = skills_totals.get(s, 0) + 1

    if not is_main:
        sub_count += 1
        sub_errors += error_count
        continue

    # ---- ab hier: Hauptsession ----
    main_count += 1
    main_errors_total += error_count
    has_wrap = "wrap-up" in session_skills
    has_resume = "resume-session" in session_skills
    if has_wrap:
        wrapup_total += 1
    if has_resume:
        resume_total += 1

    slug = project_for_cwd(cwd)
    if slug is not None:
        coverage_in += 1
    elif is_automation(cwd):
        coverage_auto += 1
    else:
        coverage_off += 1
        if cwd:
            off_cwds[cwd] = off_cwds.get(cwd, 0) + 1

    key = slug or ("(Automation)" if is_automation(cwd) else parent)
    proj = main_projects.setdefault(key, {
        "sessions": 0, "wrapup_sessions": 0, "resume_sessions": 0,
        "errors": 0, "registered": slug is not None,
    })
    proj["sessions"] += 1
    proj["errors"] += error_count
    if has_wrap:
        proj["wrapup_sessions"] += 1
    if has_resume:
        proj["resume_sessions"] += 1

# Totalausfall abbrechen statt eine leere/degradierte JSON zu schreiben (siehe
# Kommentar bei "opened_count" oben). Einzelne unlesbare Dateien bleiben ok.
if len(files) > 0 and opened_count == 0:
    print(
        f"FEHLER: {len(files)} Session-Datei(en) gefunden, aber keine einzige "
        "lesbar (Pfad-Problem? siehe normalize_path_list in python-bin.sh).",
        file=sys.stderr,
    )
    sys.exit(1)

def quote(n, d):
    return round(n / d, 2) if d else None

project_out = []
for name, p in sorted(main_projects.items(), key=lambda kv: -kv[1]["sessions"]):
    s = p["sessions"]
    project_out.append({
        "project": name,
        "registered": p["registered"],
        "sessions": s,
        "wrapup_sessions": p["wrapup_sessions"],
        "wrapup_quote": quote(p["wrapup_sessions"], s),
        "resume_sessions": p["resume_sessions"],
        "resume_quote": quote(p["resume_sessions"], s),
        "errors": p["errors"],
    })

# Ungenutzte Skills: Ordner ohne jeglichen Skill-Aufruf im Fenster (ueber ALLE Sessions).
# Der gsd-*-Filter bleibt defensiv: falls auf der Maschine noch geparkte GSD-Skills liegen,
# sollen die nicht als "ungenutzt" auftauchen.
unused_skills = []
if os.path.isdir(skills_dir):
    for entry in sorted(os.listdir(skills_dir)):
        full = os.path.join(skills_dir, entry)
        if not os.path.isdir(full) or entry.startswith("gsd-"):
            continue
        if not os.path.isfile(os.path.join(full, "SKILL.md")):
            continue
        if entry not in skills_totals:
            unused_skills.append(entry)

off_list = [{"cwd": c, "sessions": n} for c, n in sorted(off_cwds.items(), key=lambda kv: -kv[1])]

result = {
    "generated_at": generated_at,
    "window_days": days,
    "projects": project_out,
    "skills_totals": skills_totals,
    "unused_non_gsd_skills": unused_skills,
    "totals": {
        "sessions_main": main_count,
        "sessions_subagent": sub_count,
        "sessions_total": main_count + sub_count,
        "wrapup_sessions": wrapup_total,
        "wrapup_quote": quote(wrapup_total, main_count),
        "resume_sessions": resume_total,
        "resume_quote": quote(resume_total, main_count),
        "errors_main": main_errors_total,
        "errors_subagent": sub_errors,
        "error_rate_main": round(main_errors_total / main_count, 2) if main_count else None,
        "project_coverage": {
            "in_project": coverage_in,
            "off_project": coverage_off,
            "automation": coverage_auto,
            "quote": quote(coverage_in, coverage_in + coverage_off),
            "off_cwds": off_list[:8],
        },
    },
}
print(json.dumps(result, ensure_ascii=False, indent=2))
PYEOF
rc=$?

verify_json_output "$rc" "$OUTPUT_DIR/tuning-signals.json" "tuning-signals-collector" "$GENERATED_AT" || exit 1

chmod 644 "$OUTPUT_DIR/tuning-signals.json"
echo "tuning-signals.json geschrieben ($OUTPUT_DIR/tuning-signals.json)."
