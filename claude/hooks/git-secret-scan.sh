#!/bin/bash
# git-secret-scan.sh: PreToolUse-Hook (Bash).
# Erzwingt die CLAUDE.md-Regel "Vor jedem Commit: Secret-Scan" deterministisch:
# blockt git commit (Exit 2), wenn im gestagten Diff Zeilen nach Secrets aussehen.
# Muster bewusst schaerfer als der Prosa-Grep (Zuweisung + bekannte Key-Formate),
# damit Fachtexte mit Woertern wie "Token" keine Fehlalarme ausloesen.

INPUT=$(cat)

# Python-Interpreter aufloesen. Unter Windows ist "python3" im PATH haeufig nur
# der Microsoft-Store-Stub: er existiert als Datei, beendet sich aber mit Exit 49
# ohne Ausgabe. Deshalb wird hier ausgefuehrt statt nur gesucht (command -v
# wuerde den Stub als gueltig durchwinken).
PYBIN=""
for _cand in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $_cand -c "import sys" </dev/null >/dev/null 2>&1; then PYBIN="$_cand"; break; fi
done

# Commit-Verdacht-Erkennung an einer Stelle gebuendelt, damit alle drei
# Fundstellen (kein Python, kaputtes JSON, Haupt-Dispatch) dieselbe
# Options-Toleranz nutzen. Vorher pruefte jede Stelle eine eigene, kuerzere
# Muster-Liste; "git --git-dir=... commit" oder "git -c k=v commit" fielen
# durch keines der Muster und der Hook stieg bereits am Dispatch mit
# Exit 0 aus, ohne je in die eigentliche Scan-Logik zu kommen.
is_commit_verdict() {
  case "$1" in
    *"git commit"*|*"git.exe commit"*) return 0 ;;
    *"git -C "*"commit"*|*"git.exe -C "*"commit"*) return 0 ;;
    *"git --git-dir"*"commit"*|*"git.exe --git-dir"*"commit"*) return 0 ;;
    *"git -c "*"commit"*|*"git.exe -c "*"commit"*) return 0 ;;
    *"git --work-tree"*"commit"*|*"git.exe --work-tree"*"commit"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Fail-closed, aber gezielt: dieser Hook haengt an JEDEM Bash-Aufruf, ein
# pauschales Exit 2 wuerde ohne Python die ganze Session lahmlegen. Ohne
# Interpreter kann der Commit-Befehl nicht sauber geparst werden, also wird
# anhand des ungeparsten Rohtexts entschieden und nur bei Commit-Verdacht
# geblockt. Frueher lief der Hook hier still auf Exit 0 und der Secret-Scan
# war unbemerkt wirkungslos.
if [ -z "$PYBIN" ]; then
  if is_commit_verdict "$INPUT"; then
    {
      echo "SECRET-SCAN BLOCKIERT: kein funktionierender Python-Interpreter gefunden."
      echo "Der Commit wird vorsorglich geblockt, weil der Secret-Scan nicht laufen kann."
      echo "Geprueft wurden: python3, python, py -3."
      echo "Fix (Windows): winget install --id Python.Python.3.12, danach neues Terminal oeffnen."
      echo "Siehe docs/windows/troubleshooting.md Punkt 2."
    } >&2
    exit 2
  fi
  exit 0
fi

CMD=$(printf '%s' "$INPUT" | $PYBIN -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', '') or '')
except Exception:
    print('')
" 2>/dev/null)
if [ -z "$CMD" ]; then
  # CMD leer heisst: der Input war nicht parsbar (etwa unescapte Backslashes
  # aus einem Windows-Pfad im cwd-Feld). Frueher lief der Hook hier still auf
  # Exit 0 durch, der Scan war dann wirkungslos ohne dass es jemand merkt.
  # Deshalb dieselbe gezielte Fail-closed-Regel wie beim fehlenden Interpreter:
  # nur bei Commit-Verdacht im Rohtext blocken, alles andere weiterlaufen lassen.
  if is_commit_verdict "$INPUT"; then
    {
      echo "SECRET-SCAN BLOCKIERT: Hook-Input nicht parsbar, Commit-Verdacht im Rohtext."
      echo "Der Commit wird vorsorglich geblockt, weil der Secret-Scan nicht laufen kann."
      echo "Haeufigste Ursache: unescapte Backslashes aus einem Windows-Pfad im Feld cwd."
    } >&2
    exit 2
  fi
  exit 0
elif ! is_commit_verdict "$CMD"; then
  exit 0
fi

CWD=$(printf '%s' "$INPUT" | $PYBIN -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('cwd', '') or '')
except Exception:
    print('')
" 2>/dev/null)

# Zielverzeichnis bevorzugt aus dem Kommando selbst ableiten: bei "git -C <pfad>
# commit" oder "cd <pfad> && git commit" ist <pfad> das eigentliche Ziel, nicht
# das Session-cwd. Frueher wurde nur ins cwd gewechselt; lag das cwd in keinem
# Repo (oder in einem ANDEREN Repo als dem Zielpfad im Kommando), stieg der Hook
# beim rev-parse still aus bzw. scannte den falschen Diff (Umgehung, 03.08.).
CMD_DIR=$(printf '%s' "$CMD" | $PYBIN -c '
import sys, re
cmd = sys.stdin.read()
DQ = chr(34)
SQ = chr(39)

def unquote(s):
    if len(s) >= 2 and s[0] in (DQ, SQ) and s[-1] == s[0]:
        return s[1:-1]
    return s

pat = DQ + "[^" + DQ + "]*" + DQ + "|" + SQ + "[^" + SQ + "]*" + SQ + "|\\S+"
m = re.search(r"git(?:\.exe)?\s+-C\s+(" + pat + ")", cmd)
if m:
    print(unquote(m.group(1)))
    sys.exit()
m = re.search(r"(?:^|[;&]\s*)(?:cd|Set-Location)\s+(" + pat + ")\\s*(?:&&|;)", cmd)
if m:
    print(unquote(m.group(1)))
' 2>/dev/null)
CMD_DIR="${CMD_DIR//\\//}"
CWD="${CWD//\\//}"

# Tilde-/HOME-Expansion: CMD_DIR kommt als reiner Kommandotext, "cd ~/pfad"
# oder "cd $HOME/pfad" wird VOR dem Hook nicht von einer Shell expandiert.
# Ohne diese Expansion scheitert die folgende "[ -d ]"-Pruefung fuer jeden
# Tilde-/HOME-Pfad, TARGET_DIR bleibt leer, und der Scan lief frueher still
# im Ambient-cwd des Hooks (statt im eigentlichen Zielverzeichnis) weiter,
# was einen Fake-Secret-Commit durchliess (Umgehung V3, Cloud PC 03.08.).
case "$CMD_DIR" in
  '$HOME') CMD_DIR="$HOME" ;;
  '$HOME/'*) CMD_DIR="$HOME/${CMD_DIR#'$HOME/'}" ;;
  '${HOME}') CMD_DIR="$HOME" ;;
  '${HOME}/'*) CMD_DIR="$HOME/${CMD_DIR#'${HOME}/'}" ;;
  '~') CMD_DIR="$HOME" ;;
  '~/'*) CMD_DIR="$HOME/${CMD_DIR#'~/'}" ;;
esac

# Zielverzeichnis-Aufloesung, jetzt mit explizitem Fehlschlag-Merker: wurde im
# Kommando ein Zielpfad genannt (CMD_DIR, aus "cd ..." oder "git -C ..."),
# aber dieser Pfad ist keine existierende Directory, gilt das Ziel als NICHT
# aufloesbar, auch wenn cwd zufaellig auf ein Repo zeigt. Vorher fiel die
# Pruefung in diesem Fall einfach auf "kein cd" zurueck und der Scan lief im
# Ambient-cwd des Hook-Prozesses weiter, was zufaellig ein unbeteiligtes Repo
# treffen und einen leeren, "sauberen" Diff liefern konnte (Umgehung V3).
TARGET_DIR=""
CMD_DIR_NAMED_BUT_UNRESOLVED=0
if [ -n "$CMD_DIR" ]; then
  if [ -d "$CMD_DIR" ]; then
    TARGET_DIR="$CMD_DIR"
  else
    CMD_DIR_NAMED_BUT_UNRESOLVED=1
  fi
elif [ -n "$CWD" ] && [ -d "$CWD" ]; then
  TARGET_DIR="$CWD"
fi

if [ -z "$TARGET_DIR" ]; then
  {
    echo "SECRET-SCAN BLOCKIERT: Zielverzeichnis nicht aufloesbar, Commit-Verdacht im Kommando."
    if [ "$CMD_DIR_NAMED_BUT_UNRESOLVED" = "1" ]; then
      echo "Im Kommando wurde ein Zielpfad genannt (cd/-C), der aber keine existierende Directory ist: $CMD_DIR"
    else
      echo "Weder im Kommando (cd/-C) noch im Session-cwd liess sich ein gueltiges Verzeichnis finden."
    fi
    echo "Der Commit wird vorsorglich geblockt, weil sonst im falschen (Ambient-)Verzeichnis gescannt wuerde."
  } >&2
  exit 2
fi
cd "$TARGET_DIR" 2>/dev/null

ASSIGN='(api[_-]?key|apikey|secret|password|passwd|bearer|access[_-]?token|auth[_-]?token|client[_-]?secret)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_/+-]{8,}'
KEYFMT='sk_live_[A-Za-z0-9]|sk-ant-[A-Za-z0-9]|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_|sbp_[a-f0-9]{20,}|whsec_[A-Za-z0-9]{16,}|xox[bap]-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY'

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  NO_REPO=0
else
  NO_REPO=1
fi

# "git add <pfade>"-Anteil des Kommandos extrahieren (auch verkettet vor dem
# commit, z.B. "git add x.txt && git commit -m ..."). Zum Pruefzeitpunkt ist
# in diesem Fall noch nichts gestaged, "git diff --cached" liefert leer, das
# ist die uebliche Form in der ein Agent committet (Umgehung A1, 03.08.).
#
# Zwischen "git" und "add" toleriert die Regex globale git-Optionen (-C
# <pfad>, --git-dir, --work-tree, -c key=val): sonst bricht z.B.
# "git -C /abs add x.txt && git -C /abs commit -m ..." den Match, die
# Dateiliste bleibt leer, und beim Pruefzeitpunkt ist noch nichts gestaged
# (Umgehung V4, Cloud PC 03.08.).
ADD_PATHS=$(printf '%s' "$CMD" | $PYBIN -c '
import sys, re, shlex
cmd = sys.stdin.read()
DQ = chr(34)
SQ = chr(39)
optval = "(?:" + DQ + "[^" + DQ + "]*" + DQ + "|" + SQ + "[^" + SQ + "]*" + SQ + "|\\S+)"
gitopt = ("(?:-C\\s+" + optval
          + "|--git-dir(?:=|\\s+)" + optval
          + "|--work-tree(?:=|\\s+)" + optval
          + "|-c\\s+\\S+=\\S+)")
m = re.search(r"git(?:\.exe)?\s+(?:" + gitopt + r"\s+)*add\s+(.*?)(?:&&|;|$)", cmd)
if not m:
    sys.exit()
rest = m.group(1).strip()
try:
    tokens = shlex.split(rest)
except ValueError:
    tokens = rest.split()
all_flag = False
paths = []
for t in tokens:
    if t in (".", "-A", "--all", "-u", "--update"):
        all_flag = True
        continue
    if t.startswith("-"):
        continue
    paths.append(t)
if all_flag or not paths:
    print("__ALL__")
else:
    for p in paths:
        print(p)
' 2>/dev/null)

SCAN_FILES=""
if [ "$ADD_PATHS" = "__ALL__" ]; then
  if [ "$NO_REPO" = "0" ]; then
    SCAN_FILES=$(git status --porcelain 2>/dev/null | cut -c4-)
  else
    SCAN_FILES=$(find . -maxdepth 1 -type f 2>/dev/null | sed 's|^\./||')
  fi
elif [ -n "$ADD_PATHS" ]; then
  SCAN_FILES="$ADD_PATHS"
fi

# Additiv zum Diff-Scan: die genannten/ermittelten Dateien direkt im
# Arbeitsbaum scannen (noch nicht gestaged). Groessenbegrenzung pro Datei,
# Binaerdateien werden uebersprungen. READ_COUNT zaehlt tatsaechlich lesbare
# Dateien (unabhaengig von Treffern) mit, damit die Fail-closed-Pruefung am
# Ende zwischen "durchsucht, keine Treffer" und "genannte Dateien allesamt
# nicht lesbar" unterscheiden kann.
ADD_HITS=0
ADD_FILES_HIT=""
READ_COUNT=0
if [ -n "$SCAN_FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    grep -Iq . "$f" 2>/dev/null || continue
    READ_COUNT=$(( READ_COUNT + 1 ))
    CONTENT=$(head -c 200000 "$f" 2>/dev/null)
    H1=$(printf '%s' "$CONTENT" | grep -icE "$ASSIGN" 2>/dev/null)
    H2=$(printf '%s' "$CONTENT" | grep -cE "$KEYFMT" 2>/dev/null)
    FHITS=$(( ${H1:-0} + ${H2:-0} ))
    if [ "$FHITS" -gt 0 ]; then
      ADD_HITS=$(( ADD_HITS + FHITS ))
      ADD_FILES_HIT="$ADD_FILES_HIT
  - $f"
    fi
  done <<EOF
$SCAN_FILES
EOF
fi

if [ "$NO_REPO" = "1" ]; then
  if [ -z "$SCAN_FILES" ]; then
    # Kein Repo im ermittelten Zielverzeichnis gefunden UND keine "git
    # add"-Pfade im Kommando, aus denen sich etwas scannen liesse. Frueher
    # stieg der Hook hier still auf Exit 0 aus (Umgehung A2, 03.08.); jetzt
    # dieselbe gezielte Fail-closed-Regel wie bei fehlendem Interpreter bzw.
    # unparsbarem Input: bei Commit-Verdacht ohne Scan-Moeglichkeit blocken.
    {
      echo "SECRET-SCAN BLOCKIERT: kein Git-Repo im Zielverzeichnis gefunden, Commit-Verdacht im Kommando."
      echo "Der Commit wird vorsorglich geblockt, weil der Secret-Scan nicht laufen kann."
      echo "Geprueft wurde: $TARGET_DIR"
    } >&2
    exit 2
  fi
  DIFF=""
else
  DIFF=$(git diff --cached 2>/dev/null)
  case "$CMD" in
    *" -a "*|*" -a"|*" -am "*|*" -am"|*"--all"*)
      DIFF="$DIFF
$(git diff 2>/dev/null)"
      ;;
  esac
fi

ADDED=$(printf '%s' "$DIFF" | grep -E '^\+[^+]' 2>/dev/null)
HITS=$(printf '%s' "$ADDED" | grep -icE "$ASSIGN" 2>/dev/null)
HITS2=$(printf '%s' "$ADDED" | grep -cE "$KEYFMT" 2>/dev/null)
TOTAL=$(( ${HITS:-0} + ${HITS2:-0} + ${ADD_HITS:-0} ))

if [ "$TOTAL" -gt 0 ]; then
  {
    echo "SECRET-SCAN BLOCKIERT: $TOTAL verdaechtige Zeile(n) im Commit."
    echo "Pruefe manuell mit: git diff --cached | grep -inE '<muster>'"
    echo "Betroffene Dateien:"
    printf '%s' "$DIFF" | grep -E '^\+\+\+ ' | sed 's|^+++ b/|  - |' | head -10
    if [ -n "$ADD_FILES_HIT" ]; then
      printf '%s\n' "$ADD_FILES_HIT" | head -10
    fi
    echo "Wenn es sich um harmlose Beispiel-/Doku-Werte handelt: Zeile umformulieren oder Datei aus dem Commit nehmen."
  } >&2
  exit 2
fi

# Fail-closed am ERGEBNIS statt nur an der Vorbedingung: TOTAL=0 heisst bisher
# unterschiedslos "sauber". Das deckt aber auch den Fall ab, dass gar nichts
# tatsaechlich gescannt wurde (Diff leer UND die genannten add-Dateien
# allesamt unlesbar, oder ein "git add" im Kommando erkannt, aber keine
# Dateiliste extrahierbar). Nur ein GENUIN leerer Diff ohne jeden add-Bezug
# (z.B. "git commit --allow-empty" ohne vorheriges "git add") gilt als
# nachgewiesen "nichts zu scannen" und bleibt Exit 0.
if [ -z "$DIFF" ]; then
  NOTHING_SCANNED=0
  if [ -n "$SCAN_FILES" ] && [ "${READ_COUNT:-0}" -eq 0 ]; then
    # Genannte/ermittelte add-Dateien waren AUSNAHMSLOS nicht lesbar.
    NOTHING_SCANNED=1
  elif [ -z "$SCAN_FILES" ] && [ -z "$ADD_PATHS" ]; then
    # Kein SCAN_FILES und die add-Regex hat gar nicht gegriffen (nicht mal
    # der "__ALL__"-Fallback). Grober Rohtext-Check als letztes Netz: taucht
    # "add" als eigenes Wort in einem git-Aufruf auf, den unsere Regex nicht
    # erfasst hat, gilt das als add-Verdacht ohne extrahierbare Dateiliste.
    case "$CMD" in
      *"git "*" add "*|*"git.exe "*" add "*|*"git add "*|*"git.exe add "*)
        NOTHING_SCANNED=1 ;;
    esac
  fi
  if [ "$NOTHING_SCANNED" = "1" ]; then
    {
      echo "SECRET-SCAN BLOCKIERT: Commit-Verdacht, aber nichts tatsaechlich gescannt."
      echo "Weder der gestagte Diff noch die genannten/ermittelten add-Dateien liessen sich lesen."
      if [ -n "$SCAN_FILES" ]; then
        echo "Genannte Dateien (keine davon lesbar):"
        printf '%s\n' "$SCAN_FILES" | sed 's/^/  - /' | head -10
      fi
      echo "Der Commit wird vorsorglich geblockt, weil der Secret-Scan sonst wirkungslos waere."
    } >&2
    exit 2
  fi
fi

exit 0
