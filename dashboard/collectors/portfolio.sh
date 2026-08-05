#!/bin/bash
# portfolio.sh — Sammelt Projekt-Portfolio-Status aus project-repos.yaml + STATE.md.
# Read-only gegen Projekte. Einziges Schreibziel: dashboard/data/portfolio.json.
# Kein LLM, keine Bewertung: Ampel/Alter/Konformitaet sind rein deterministisch.

set -euo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="$HOME/.claude/dashboard"
DATA_DIR="$DASH_DIR/data"
REPOS_YAML="$HOME/.claude/project-repos.yaml"
mkdir -p "$DATA_DIR"

OUT_FILE="$DATA_DIR/portfolio.json"
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

NOW_EPOCH=$(date +%s)
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

USAGE_JSON="$DATA_DIR/usage.json"

# "set -e" beendet das Skript bei einem abstuerzenden Python-Payload sofort,
# aber ohne eigene Pruefung mit einer nackten Traceback-Zeile statt einer
# verstaendlichen Meldung. Anders als bei den anderen Collectors ist
# OUT_FILE hier aber schon strukturell sicher: es wird nie direkt beschrieben,
# sondern erst nach Erfolg per "mv" aus TMP_FILE ersetzt (siehe unten), ein
# Absturz kann die bestehende portfolio.json also nicht beschaedigen oder
# leeren. "set -e" fuer diesen Aufruf trotzdem gezielt aussetzen, um den
# Exit-Code selbst zu pruefen und verstaendlich zu meldem, statt nur auf die
# rohe Traceback-Ausgabe zu vertrauen.
set +e
$PYBIN - "$REPOS_YAML" "$GENERATED_AT" "$NOW_EPOCH" "$USAGE_JSON" > "$TMP_FILE" <<'PYEOF'
import sys, os, re, json, hashlib, time, subprocess

repos_yaml, generated_at, now_epoch, usage_json = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]

# Echte 7-Tage-Session-Zahl je Projekt (aus usage.json, falls vorhanden).
# Ehrliches Aktivitaets-Signal: eine frische STATE.md-mtime ohne echte Sessions
# (z. B. durch Kopieren/Touch) ist damit als "0 Sessions" erkennbar.
sessions_7d = {}
try:
    with open(usage_json, encoding="utf-8") as f:
        _u = json.load(f)
    for row in (_u.get("sessions_last_7_days", {}) or {}).get("by_project", []) or []:
        sessions_7d[row.get("p", "")] = row.get("n", 0)
except Exception:
    pass

# Pfadformat vereinheitlichen: project-repos.yaml trägt drei beobachtete
# Formate (Backslash-nativ, Forward-Slash-nativ, MSYS "/c/Users/..."). Natives
# Windows-Python kommt mit Backslash und "C:/" direkt klar; nur das
# MSYS-Format muss erkannt und auf "C:/Users/..." umgeschrieben werden, sonst
# findet os.path.isdir() das Projekt nicht.
def normalize_project_path(p):
    if os.name == "nt":
        m = re.match(r"^/([a-zA-Z])/(.*)$", p)
        if m:
            return f"{m.group(1)}:/{m.group(2)}"
    return p

projects = []
if os.path.isfile(repos_yaml):
    with open(repos_yaml, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or line.strip().startswith("#"):
                continue
            m = re.match(r"^([a-zA-Z0-9_-]+):\s*(.+)$", line.strip())
            if m:
                projects.append((m.group(1), normalize_project_path(m.group(2).strip())))

def ampel(days):
    if days is None:
        return "unbekannt"
    if days < 4:
        return "gruen"
    if days <= 10:
        return "gelb"
    return "rot"

def line_hash(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]

RE_CURRENT_POS = re.compile(r"^## ?Current Position|^Current Position\s*$", re.MULTILINE)
# Konformitaets-Tor und Extraktor teilen sich bewusst DIESELBE Regex. Frueher
# forderte das Tor exakt "### Pending Todos", waehrend der Extraktor darunter
# "##" und "###" akzeptierte. Eine STATE.md, die "Pending Todos" als eigene
# Top-Level-Sektion ("## Pending Todos") fuehrt statt als Unterpunkt von
# "## Accumulated Context", galt damit als "altes Format" — obwohl ihre
# Aufgaben lesbar gewesen waeren. Der Titel ist absichtlich exakt verankert
# (\s*$): ein Zusatz in der Ueberschrift wuerde den Extraktor ohnehin ins
# Leere laufen lassen, das gehoert dann ehrlich als "nicht konform" gemeldet
# statt als konformes Projekt mit stillschweigend leerer Aufgabenliste.
RE_PENDING = re.compile(r"^(#{2,3})\s*Pending Todos\s*$", re.MULTILINE)
RE_SESSION_CONT = re.compile(r"^## Session Continuity", re.MULTILINE)
RE_CHECKBOX = re.compile(r"^\s*-\s\[( |x|X)\]\s+", re.MULTILINE)

result = []
for slug, path in projects:
    entry = {
        "slug": slug,
        "path": path,
        "state_path": None,
        "exists": os.path.isdir(path),
        "mtime": None,
        "days_since_change": None,
        "ampel": "unbekannt",
        "template_conform": False,
        "pending_todos": [],
        "todos_outside_section": 0,
        "excerpt": None,
        "sessions_7d": sessions_7d.get(slug, 0),
    }

    state_candidates = [
        os.path.join(path, ".planning", "STATE.md"),
        os.path.join(path, "STATE.md"),
    ]
    state_path = next((p for p in state_candidates if os.path.isfile(p)), None)

    if state_path is None:
        result.append(entry)
        continue

    entry["state_path"] = state_path
    # Aktualitaet ehrlich bestimmen: bei Git-Repos das letzte Commit-Datum bevorzugen
    # (echter Arbeitszeitpunkt), sonst STATE.md-mtime als Fallback. Datei-mtime kann
    # durch Kopieren/Touch in die Zukunft rutschen -> negatives Alter auf 0 klemmen.
    def git_commit_epoch(proj_path):
        try:
            r = subprocess.run(
                ["git", "-C", proj_path, "log", "-1", "--format=%ct"],
                capture_output=True, text=True, timeout=5,
            )
            if r.returncode == 0 and r.stdout.strip().isdigit():
                return int(r.stdout.strip())
        except Exception:
            return None
        return None

    try:
        mtime_epoch = os.path.getmtime(state_path)
    except OSError:
        mtime_epoch = None

    recency_epoch = None
    recency_source = None
    g = git_commit_epoch(path)
    if g is not None:
        recency_epoch = g
        recency_source = "git"
    elif mtime_epoch is not None:
        recency_epoch = mtime_epoch
        recency_source = "mtime"

    if mtime_epoch is not None:
        entry["mtime"] = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(mtime_epoch))
    if recency_epoch is not None:
        raw_days = int((now_epoch - recency_epoch) // 86400)
        entry["mtime_suspect"] = raw_days < 0  # Zukunfts-Zeitstempel (Touch/Copy)
        days = max(0, raw_days)
        entry["days_since_change"] = days
        entry["recency_source"] = recency_source
        entry["ampel"] = ampel(days)

    try:
        with open(state_path, encoding="utf-8") as f:
            content = f.read()
    except OSError:
        content = ""

    m_pending = RE_PENDING.search(content)
    has_all = bool(RE_CURRENT_POS.search(content) and m_pending and RE_SESSION_CONT.search(content))
    entry["template_conform"] = has_all

    if has_all:
        # Sektionsgrenze RELATIV zur Ebene der gefundenen Ueberschrift bestimmen,
        # nicht absolut. Bei "### Pending Todos" sind "####"-Zeilen Themen-Cluster
        # und "#".."###" beenden die Sektion; bei "## Pending Todos" verschiebt
        # sich beides um eine Ebene. Die frueher fest verdrahteten Grenzen
        # (#{1,3} stoppt, #{4,6} ist Cluster) unterstellten immer einen
        # "###"-Kopf: bei einem "##"-Kopf las der Extraktor die erste
        # "###"-Cluster-Ueberschrift als Sektionsende und lieferte still eine
        # leere Aufgabenliste, obwohl darunter Aufgaben standen.
        level = len(m_pending.group(1))
        stop_re = re.compile(r"^#{1,%d}\s+\S" % level, re.MULTILINE)
        cluster_re = re.compile(r"^\s*#{%d,6}\s+(.*?)\s*$" % (level + 1))
        todos = []
        current_cluster = None
        if m_pending:
            rest = content[m_pending.end():]
            stop = stop_re.search(rest)
            section = rest[:stop.start()] if stop else rest
            for ln in section.splitlines():
                # Themen-Cluster-Ueberschrift innerhalb der Pending-Todos-Sektion:
                #   eine Ueberschrift tiefer als der Sektionskopf (zaehlt zur Sektion,
                #   da der Stopp erst bei gleicher/hoeherer Ebene greift)
                #   oder eine reine Fettzeile  **Titel**  /  **Titel:**
                hm = cluster_re.match(ln)
                if hm:
                    current_cluster = hm.group(1).strip().rstrip(":").strip() or None
                    continue
                bm = re.match(r"^\s*\*\*(.+?):?\*\*\s*$", ln)
                if bm:
                    current_cluster = bm.group(1).strip() or None
                    continue
                lm = re.match(r"^\s*-\s\[( |x|X)\]\s+(.*)$", ln)
                if lm:
                    todos.append({
                        "text": lm.group(2).strip(),
                        "checked": lm.group(1).lower() == "x",
                        "hash": line_hash(ln),
                        "cluster": current_cluster,
                    })
        entry["pending_todos"] = todos
        # Stiller-Fehler-Signal: offene/erledigte Checkbox-Zeilen, die ausserhalb der
        # ### Pending Todos Sektion stehen (andere Ueberschrift) und daher nicht erfasst werden.
        total_cb = len(RE_CHECKBOX.findall(content))
        entry["todos_outside_section"] = max(0, total_cb - len(todos))
    else:
        # erste Zeilen des obersten Status-Abschnitts als read-only Auszug (max 400 Zeichen)
        stripped = content.lstrip("\n")
        m2 = re.search(r"^#{1,3}\s+\S", stripped, re.MULTILINE)
        if m2:
            rest2 = stripped[m2.start():]
            nxt = re.search(r"^#{1,3}\s+\S", rest2[1:], re.MULTILINE)
            block = rest2[:nxt.start() + 1] if nxt else rest2
        else:
            block = stripped
        entry["excerpt"] = block[:400]

    result.append(entry)

print(json.dumps({
    "generated_at": generated_at,
    "projects": result,
}, ensure_ascii=False, indent=2))
PYEOF
rc=$?
set -e

# Pruefung laeuft bewusst gegen TMP_FILE, nicht gegen OUT_FILE: TMP_FILE
# kommt frisch aus mktemp, ein "generated_at"-Abgleich waere hier ueberfluessig
# (es kann keinen Alt-Inhalt aus einem frueheren Lauf geben, entweder die
# Datei ist leer/unvollstaendig, oder sie ist dieser Lauf). Die eigentliche
# Sicherung ist der "mv" danach: erst nach bestandener Pruefung ersetzt TMP_FILE
# die echte portfolio.json, ein Absturz kann die bestehende Datei also nie
# beschaedigen.
verify_json_output "$rc" "$TMP_FILE" "portfolio-collector" || exit 1

mv "$TMP_FILE" "$OUT_FILE"
chmod 644 "$OUT_FILE"
echo "portfolio.json geschrieben: $OUT_FILE"
