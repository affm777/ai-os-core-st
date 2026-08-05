#!/bin/bash
# vault-write-guard.sh
#
# PreToolUse hook for the Write tool. Blocks creation of new knowledge artefacts
# (type: meeting|decision|learning|session-log|concept|person|organization)
# anywhere inside ~/Documents/Second-Brain/ EXCEPT 01_Inbox/ and 00_Meta/.
#
# Rationale: The /sync-meetings skill body says "ausnahmslos Inbox", but in
# scheduled (autonomous) runs the LLM has dropped that constraint twice and
# written meeting files directly into 02_Projects/<slug>/. This hook is the
# deterministic safety net.
#
# Allowed:
#   - Any path outside ~/Documents/Second-Brain/         → exit 0
#   - Existing files (Edits/Updates)                     → exit 0
#   - 01_Inbox/, 00_Meta/                                → exit 0
#   - Project/Area hub pages (type: project|area)        → exit 0
#   - Files without a knowledge-artefact `type:` field   → exit 0
#
# Blocked:
#   - New file in Vault outside Inbox/Meta with type:
#     meeting, decision, learning, session-log, concept, person, organization

# Bewusst kein "set -e": der Hook muss seine eigene Fehlerbehandlung erreichen.
# Mit set -e riss ein fehlschlagender Interpreter-Aufruf das Skript vorher aus
# dem Lauf (Exit 49 vom Windows-Store-Stub), der Guard blockte also nie.

INPUT=$(cat)

# Python-Interpreter aufloesen, siehe Kommentar in git-secret-scan.sh:
# ausfuehren statt suchen, weil der Windows-Store-Stub als Datei existiert.
PYBIN=""
for _cand in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $_cand -c "import sys" </dev/null >/dev/null 2>&1; then PYBIN="$_cand"; break; fi
done

# Fail-closed, gezielt: ohne Interpreter laesst sich der Zielpfad nicht parsen.
# Sieht der Rohtext nach einem Vault-Schreibzugriff aus, wird geblockt statt
# still durchgelassen. Alles ausserhalb des Vaults passiert wie bisher.
if [ -z "$PYBIN" ]; then
  case "$INPUT" in
    *"Second-Brain"*)
      cat >&2 <<'EOF'
WRITE-GUARD blocked: kein funktionierender Python-Interpreter gefunden.

Der Schreibzugriff zeigt auf den Second-Brain-Vault, der Guard kann den Pfad
ohne Interpreter aber nicht pruefen und blockt deshalb vorsorglich.
Geprueft wurden: python3, python, py -3.

Fix (Windows): winget install --id Python.Python.3.12, danach neues Terminal.
Siehe docs/windows/troubleshooting.md Punkt 2.
EOF
      exit 2 ;;
    *) exit 0 ;;
  esac
fi

PARSE_OK=$(printf '%s' "$INPUT" | $PYBIN -c "
import sys, json
try:
    json.loads(sys.stdin.read())
    print('OK')
except Exception:
    print('FAIL')
" 2>/dev/null)

# Fail-closed, gezielt: dasselbe Muster wie in git-secret-scan.sh. Ein Parse-
# Fehler (z. B. unescapte Backslashes aus einem Windows-Pfad im Feld cwd) fuehrte
# hier frueher stillschweigend zu einem leeren FILE_PATH und damit zu Exit 0,
# selbst wenn der Rohtext eindeutig auf einen neuen Wissens-Artefakt ausserhalb
# von Inbox/Meta zeigte.
#
# WICHTIG: die Inbox/Meta-Freigabe darf sich NICHT auf den gesamten Rohtext
# stuetzen, sondern nur auf den tatsaechlichen Zielpfad. Vault-Dateien
# verweisen im Fliesstext staendig auf andere Pfade (Wikilinks, "siehe auch
# 01_Inbox/..."), ein blosser Substring-Treffer irgendwo im Content wuerde
# sonst einen Treffer ausserhalb der Inbox neutralisieren. Deshalb wird der
# file_path-Wert gezielt aus dem Rohtext isoliert (der Bruch liegt erfahrungs-
# gemaess im Feld cwd, nicht in tool_input.file_path) und NUR dieser Wert
# gegen Inbox/Meta geprueft. Laesst er sich nicht isolieren, gilt im Zweifel:
# blocken statt freigeben.
if [ "$PARSE_OK" != "OK" ]; then
  RAW_FILE_PATH=$(printf '%s' "$INPUT" \
    | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')

  BLOCK_MSG='WRITE-GUARD blocked: Hook-Input nicht parsbar, Vault-Schreibzugriff mit Wissens-Artefakt-Typ erkannt.

Der Guard kann den Zielpfad nicht strukturiert pruefen (JSON nicht parsbar), aber
der isolierte file_path-Wert (oder in Ermangelung dessen der Rohtext) zeigt einen
Second-Brain-Pfad ausserhalb von 01_Inbox/00_Meta sowie ein Frontmatter-Feld
type: mit einem der geschuetzten Werte (meeting, decision, learning,
session-log, concept, person, organization). Deshalb wird vorsorglich geblockt.

Haeufigste Ursache: unescapte Backslashes aus einem Windows-Pfad im Feld cwd.

Fix:
  1. Ziel-Pfad nach 01_Inbox/ umleiten.
  2. /brain:sort-inbox laufen lassen, sobald der Interpreter wieder verfuegbar ist.

Override: edit $HOME/.claude/hooks/vault-write-guard.sh falls dies ein Fehlalarm ist.'

  # Pfadtrenner normalisieren: Claude Code liefert unter Windows Backslash-Pfade
  # (C:\Users\...\Second-Brain\...). Alle case-Muster unten pruefen auf
  # Forward-Slashes; ohne diese Zeile greift keines und der Guard fiel still auf
  # exit 0 durch — fail-open fuer JEDEN Vault-Schreibzugriff unter Windows
  # (nachgewiesen 03.08. auf dem Cloud PC: Backslash-Pfad Exit 0, identischer
  # Forward-Slash-Pfad Exit 2). Auf macOS ist die Ersetzung ein No-op.
  RAW_FILE_PATH="${RAW_FILE_PATH//\\//}"

  if [ -n "$RAW_FILE_PATH" ]; then
    # file_path liess sich isolieren: NUR dieser Wert entscheidet ueber
    # Inbox/Meta, unabhaengig davon was sonst noch im Content steht.
    case "$RAW_FILE_PATH" in
      *"/Second-Brain/01_Inbox/"*|*"/Second-Brain/00_Meta/"*)
        exit 0 ;;
      *"/Second-Brain/"*)
        if printf '%s' "$INPUT" | grep -qE '"?type"?[[:space:]]*:[[:space:]]*"?(meeting|decision|learning|session-log|concept|person|organization)"?'; then
          echo "$BLOCK_MSG" >&2
          exit 2
        fi
        exit 0 ;;
      *)
        exit 0 ;;
    esac
  fi

  # file_path liess sich nicht isolieren: im Zweifel blocken, wenn der Rohtext
  # ueberhaupt auf einen Second-Brain-Bezug plus geschuetzten Typ hindeutet.
  # Auch hier auf normalisiertem Rohtext pruefen, sonst greift das Muster bei
  # Backslash-Pfaden nicht (siehe Begruendung oben).
  if printf '%s' "${INPUT//\\//}" | grep -qE '/Second-Brain/' \
     && printf '%s' "$INPUT" | grep -qE '"?type"?[[:space:]]*:[[:space:]]*"?(meeting|decision|learning|session-log|concept|person|organization)"?'; then
    echo "$BLOCK_MSG" >&2
    exit 2
  fi
  exit 0
fi

FILE_PATH=$(printf '%s' "$INPUT" | $PYBIN -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', {})
    # Write/Edit/MultiEdit tragen den Pfad in file_path, NotebookEdit heisst
    # das Feld notebook_path. Ohne diesen Fallback laeuft der Guard bei
    # NotebookEdit-Input mangels FILE_PATH sofort auf 'nicht unser Fall'.
    print(ti.get('file_path', '') or ti.get('notebook_path', '') or '')
except Exception:
    print('')
")
CONTENT=$(printf '%s' "$INPUT" | $PYBIN -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('content', '') or '')
except Exception:
    print('')
")
TOOL_NAME=$(printf '%s' "$INPUT" | $PYBIN -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', '') or '')
except Exception:
    print('')
")

# Empty inputs → not our concern
[ -z "$FILE_PATH" ] && exit 0

# Pfadtrenner normalisieren, siehe Begruendung im Fallback-Zweig oben.
# Git Bash kann Laufwerkspfade der Form C:/Users/... auch mit -f pruefen,
# die Bestandsdatei-Erkennung weiter unten bleibt also intakt.
FILE_PATH="${FILE_PATH//\\//}"

# Only guard Vault paths
case "$FILE_PATH" in
  *"/Second-Brain/"*) ;;
  *) exit 0 ;;
esac

# Allow Inbox + Meta
case "$FILE_PATH" in
  *"/Second-Brain/01_Inbox/"*) exit 0 ;;
  *"/Second-Brain/00_Meta/"*) exit 0 ;;
esac

# Bestandsdatei: bisher liess die reine Existenzpruefung JEDE Aenderung durch,
# unabhaengig vom Inhalt (V9-Luecke, 03.08.). Zwei-Schritt-Umgehung: Schritt 1
# legt per Write eine harmlose Datei OHNE type: ausserhalb Inbox/Meta an (das
# ist korrekt erlaubt, siehe Block unten), Schritt 2 fuehrt per Edit/MultiEdit
# oder ueberschreibendem Write einen geschuetzten type: nachtraeglich ein.
# Deshalb jetzt: bei bestehenden Dateien den simulierten NEUEN Inhalt gegen
# den ALTEN type:-Wert vergleichen. Legitime Follow-up-Edits (sync-meetings
# ergaenzt z.B. "propagated_to_state: true" an einer Datei mit unveraendertem
# "type: meeting") bleiben unberuehrt, weil sich dort der type:-Wert nicht
# aendert.
if [ -f "$FILE_PATH" ]; then
  # MSYS-Pfade (/c/Users/...) kann natives Windows-Python nicht oeffnen
  # (dieselbe Klasse wie V10 in den Collectors): der Pfad geht deshalb
  # cygpath-normalisiert als Argument an Python, nicht roh aus dem JSON.
  FILE_PATH_PY="$FILE_PATH"
  # Gate allein ueber die cygpath-Praesenz: $MSYSTEM setzt nur die
  # Login-Shell, im Claude-Code-Kontext (nicht-Login-bash) ist sie leer.
  if command -v cygpath >/dev/null 2>&1; then
    FILE_PATH_PY="$(cygpath -m "$FILE_PATH" 2>/dev/null || printf '%s' "$FILE_PATH")"
  fi
  TYPE_DECISION=$(printf '%s' "$INPUT" | $PYBIN -c '
import sys, json

PROTECTED = {"meeting", "decision", "learning", "session-log", "concept", "person", "organization"}

def extract_type(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return ""
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line.startswith("type:"):
            v = line[len("type:"):].strip()
            v = v.strip(chr(34) + chr(39))
            return v
    return ""

try:
    data = json.load(sys.stdin)
except Exception:
    print("ERROR")
    sys.exit()

ti = data.get("tool_input", {}) or {}
tool = data.get("tool_name", "") or ""
file_path = sys.argv[1] if len(sys.argv) > 1 else (ti.get("file_path", "") or ti.get("notebook_path", "") or "")

try:
    with open(file_path, encoding="utf-8") as f:
        old_content = f.read()
except Exception:
    # Unlesbarer Alt-Inhalt heisst: die Typ-Simulation hat keine Basis.
    # Frueher wurde still mit leerem Inhalt weitergerechnet, ein Edit sah
    # dann wie "keine Aenderung" aus und lief durch (auf Windows ueber
    # MSYS-Pfade real passiert). Nicht pruefbar ist nicht bestanden.
    print("UNREADABLE")
    sys.exit()

old_type = extract_type(old_content)

if tool == "Write":
    new_content = ti.get("content", "") or ""
elif tool == "Edit":
    old_s = ti.get("old_string")
    new_s = ti.get("new_string")
    if old_s is not None and new_s is not None and old_s in old_content:
        new_content = old_content.replace(old_s, new_s, 1)
    else:
        new_content = old_content
elif tool == "MultiEdit":
    new_content = old_content
    for e in (ti.get("edits", []) or []):
        o = e.get("old_string")
        n = e.get("new_string")
        if o is not None and n is not None and o in new_content:
            new_content = new_content.replace(o, n, 1)
else:
    # NotebookEdit u.a.: kein Markdown-Frontmatter, type: nicht ermittelbar,
    # unveraenderter Inhalt gilt als sicherer Default.
    new_content = old_content

new_type = extract_type(new_content)

if new_type in PROTECTED and new_type != old_type:
    print("BLOCK:" + new_type)
else:
    print("OK")
' "$FILE_PATH_PY" 2>/dev/null)

  case "$TYPE_DECISION" in
    BLOCK:*)
      NEWTYPE="${TYPE_DECISION#BLOCK:}"
      cat >&2 <<EOF
WRITE-GUARD blocked: $TOOL_NAME fuehrt an einer Bestandsdatei einen neuen oder geaenderten geschuetzten type: "$NEWTYPE" ausserhalb 01_Inbox/00_Meta ein.

  Path: $FILE_PATH
  Tool: $TOOL_NAME
  Neuer type: $NEWTYPE

Vault rule (vault-workflow.md): "Vault-Dateien landen AUSNAHMSLOS in 01_Inbox/.
NIEMALS direkt in Zielordner. Einsortieren macht ALLEIN /brain:sort-inbox."

Fix:
  1. Wenn dies wirklich ein neuer Wissens-Artefakt ist: zuerst per Write nach 01_Inbox/ anlegen.
  2. /brain:sort-inbox laufen lassen, sobald sie fertig ist.

Override: edit \$HOME/.claude/hooks/vault-write-guard.sh falls dies ein Fehlalarm ist.
EOF
      exit 2
      ;;
    OK) exit 0 ;;
    *)
      # Fail-closed am Ergebnis: liefert die Typ-Pruefung weder OK noch
      # BLOCK (Python abgestuerzt, Input nicht parsbar), gilt die Aenderung
      # als NICHT geprueft und wird geblockt, statt still durchzulaufen.
      # Dieselbe Fehlerklasse wie V3/V4/V9: eine Pruefung, die ins Leere
      # laeuft, darf nicht wie ein Bestehen aussehen.
      {
        echo "WRITE-GUARD blocked: Typ-Pruefung an Bestandsdatei nicht auswertbar ($TOOL_NAME)."
        echo "  Path: $FILE_PATH"
        echo "  Die Aenderung wird vorsorglich geblockt, weil der Guard sonst wirkungslos waere."
        echo "Override: edit \$HOME/.claude/hooks/vault-write-guard.sh falls dies ein Fehlalarm ist."
      } >&2
      exit 2
      ;;
  esac
fi

# Neue Datei ausserhalb Inbox/Meta ueber ein Edit-artiges Tool (Edit,
# MultiEdit, NotebookEdit): diese Tools liefern kein content-Feld
# (old_string/new_string bzw. edits[] bzw. new_source statt content), der
# Wissens-Artefakt-Typ laesst sich also nicht aus dem Frontmatter bestimmen.
# Fail-closed: ohne content wird eine neue Datei hier vorsorglich geblockt.
# Fuer Write aendert sich nichts, dort ist content immer gesetzt und dieser
# Zweig greift nicht.
if [ "$TOOL_NAME" != "Write" ] && [ -z "$CONTENT" ]; then
  cat >&2 <<EOF
WRITE-GUARD blocked: neue Datei ausserhalb 01_Inbox/00_Meta ueber $TOOL_NAME.

  Path: $FILE_PATH
  Tool: $TOOL_NAME

$TOOL_NAME liefert kein content-Feld, der Guard kann den Wissens-Artefakt-Typ
der neuen Datei deshalb nicht bestimmen und blockt vorsorglich.

Fix:
  1. Datei zuerst per Write nach 01_Inbox/ anlegen.
  2. /brain:sort-inbox laufen lassen, sobald sie fertig ist.

Override: edit \$HOME/.claude/hooks/vault-write-guard.sh falls dies ein Fehlalarm ist.
EOF
  exit 2
fi

# Extract `type:` from frontmatter (between the first two `---` lines)
TYPE=$(printf '%s\n' "$CONTENT" | awk '
  BEGIN { in_fm=0; done=0 }
  /^---[[:space:]]*$/ {
    if (in_fm == 0 && done == 0) { in_fm=1; next }
    if (in_fm == 1) { done=1; exit }
  }
  in_fm == 1 && /^type:[[:space:]]/ {
    sub(/^type:[[:space:]]*/, "")
    gsub(/["'"'"']/, "")
    sub(/[[:space:]]+$/, "")
    print
    exit
  }
')

case "$TYPE" in
  meeting|decision|learning|session-log|concept|person|organization)
    cat >&2 <<EOF
WRITE-GUARD blocked: new "$TYPE" artefact must land in 01_Inbox/ first.

  Path:    $FILE_PATH
  Type:    $TYPE

Vault rule (vault-workflow.md): "Vault-Dateien landen AUSNAHMSLOS in 01_Inbox/.
NIEMALS direkt in Zielordner. Einsortieren macht ALLEIN /brain:sort-inbox."

Fix:
  1. Write to: ~/Documents/Second-Brain/01_Inbox/$(basename "$FILE_PATH")
  2. Run /brain:sort-inbox when ready, it routes to the correct project folder.

Override: edit \$HOME/.claude/hooks/vault-write-guard.sh if this is a false positive.
EOF
    exit 2
    ;;
esac

# project, area, and untyped writes pass through
exit 0
