# shellcheck shell=bash
# python-bin.sh — gemeinsame Interpreter-Aufloesung fuer alle Collectors.
#
# Wird gesourct, hat deshalb bewusst keinen Shebang und ist nicht ausfuehrbar.
# Setzt $PYBIN auf den ersten Kandidaten, der sich tatsaechlich AUSFUEHREN
# laesst.
#
# Warum ausfuehren statt suchen: Unter Windows liegt in
# %LOCALAPPDATA%\Microsoft\WindowsApps eine Datei namens "python3", die kein
# Interpreter ist, sondern ein Store-Stub. Sie beendet sich mit Exit 49 und
# gibt nichts aus. "command -v python3" findet sie und meldet faelschlich
# Erfolg. Die winget-Installation von Python liefert ausserdem nur python.exe,
# kein python3.exe, deshalb reicht der Name allein nie als Nachweis.

# Unter Git Bash (MSYS) übersetzt die Runtime "/tmp"-Pfade an native
# Windows-Programme auf einen ANDEREN Ort als mktemp in der Bash sieht
# (msys2.org/docs/filesystem-paths/). TMPDIR am echten Windows-Temp-Root
# verankern, damit mktemp-Pfade für Bash UND natives Python konsistent sind.
#
# Erkennung BEWUSST allein über die cygpath-Praesenz, nicht ueber $MSYSTEM:
# die Variable setzt nur die Login-Shell (/etc/profile). Claude Code startet
# bash.exe nicht als Login-Shell, dort ist MSYSTEM leer, und ein Gate darauf
# schaltet die gesamte Pfad-Normalisierung genau im wichtigsten Kontext ab
# (in-Session-Refresh, Cloud PC 04.08.). cygpath existiert nur in der
# MSYS-Welt, auf macOS/Linux ist der Zweig damit automatisch inaktiv.
if command -v cygpath >/dev/null 2>&1; then
  export TMPDIR="$(cygpath -w /tmp)"
fi

# Natives Windows-Python kodiert stdout sonst nach cp1252 (Codepage des
# Terminals): sobald ein Umlaut in Quelldaten auftaucht, kippt beim Schreiben
# der JSON-Ausgabe ein UnicodeDecodeError/UnicodeEncodeError. Ausserhalb des
# cygpath-Zweigs, weil der Export auf macOS keinen Schaden anrichtet.
export PYTHONIOENCODING=utf-8

PYBIN=""
for _cand in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $_cand -c "import sys" </dev/null >/dev/null 2>&1; then PYBIN="$_cand"; break; fi
done

if [ -z "$PYBIN" ]; then
  echo "FEHLER: kein funktionierender Python-Interpreter gefunden (geprueft: python3, python, py -3)." >&2
  echo "Windows: winget install --id Python.Python.3.12, danach neues Terminal oeffnen." >&2
  echo "macOS:   xcode-select --install" >&2
  exit 1
fi

# verify_json_output <exit_code> <datei> <label> [erwartetes-generated_at]
# Gemeinsame Absicherung gegen den Fail-Open-Fall "Interpreter da, Payload
# abgestuerzt": die Collectors laufen mit "set -uo pipefail" statt "set -e",
# damit ein einzelner fehlgeschlagener Python-Aufruf nicht sofort den ganzen
# Collector abbricht (z.B. wenn spaeter im Skript noch aufgeraeumt werden
# soll). Ohne diese Pruefung laeuft ein abgestuerzter Heredoc aber einfach bis
# zum abschliessenden "echo ... fertig" durch und meldet Erfolg, obwohl keine
# oder eine kaputte Datei geschrieben wurde.
#
# Rueckgabe 0 = alles gut (Exit-Code 0, Datei existiert, ist valides JSON,
# und falls das 4. Argument gesetzt ist: "generated_at" darin stimmt mit
# diesem Lauf ueberein).
# Rueckgabe 1 = Fehler, mit einer verstaendlichen Meldung auf stderr.
#
# Das 4. Argument ist wichtig, weil data/*.json nach dem ersten Lauf schon
# existiert: stuerzt der Python-Aufruf VOR dem finalen Schreiben ab, bleibt
# die alte, aber weiterhin valide Datei aus einem frueheren Lauf liegen. Ohne
# den generated_at-Abgleich wuerde das faelschlich als Erfolg durchgehen.
# Collectors, die nur ihren eigenen Anteil in eine von einem anderen
# Schreiber gepflegte Datei mergen (z.B. heute.sh), muessen dieses Argument
# immer mitgeben, weil bei ihnen der Datei-Vorlauf garantiert existiert.
#
# WICHTIG fuer Aufrufer: das ist eine Absicherung gegen ABSTURZ, nicht gegen
# leere/degradierte Ergebnisse. Ein Collector, der bewusst z.B.
# {"available": false, "reason": "not_configured"} schreibt, hat damit ganz
# normal gueltiges JSON erzeugt und besteht diese Pruefung zu Recht.
verify_json_output() {
  local rc="$1" file="$2" label="$3" expected_ts="${4:-}"
  if [ "$rc" -ne 0 ]; then
    echo "FEHLER: $label ist mit Exit-Code $rc abgebrochen (Python-Payload vermutlich abgestuerzt)." >&2
    return 1
  fi
  if [ ! -s "$file" ]; then
    echo "FEHLER: $label hat keine Ausgabedatei geschrieben: $file" >&2
    return 1
  fi
  # Belt-and-suspenders zum TMPDIR-Anker oben: $file vor der Übergabe an
  # natives Windows-Python normalisieren, falls es doch ein MSYS-Pfad ist.
  # Auf macOS ist cygpath nicht vorhanden, dann No-op.
  local pyfile="$file"
  if command -v cygpath >/dev/null 2>&1; then
    pyfile="$(cygpath -m "$file" 2>/dev/null || printf '%s' "$file")"
  fi
  if ! $PYBIN -c "import json,sys
with open(sys.argv[1], encoding='utf-8') as f:
    json.load(f)" "$pyfile" 2>/dev/null; then
    echo "FEHLER: $label hat keine gueltige JSON-Datei geschrieben: $file" >&2
    return 1
  fi
  if [ -n "$expected_ts" ]; then
    if ! $PYBIN -c "import json,sys
with open(sys.argv[1], encoding='utf-8') as f:
    d = json.load(f)
sys.exit(0 if d.get('generated_at') == sys.argv[2] else 1)" "$pyfile" "$expected_ts" 2>/dev/null; then
      echo "FEHLER: $label hat $file in diesem Lauf nicht neu geschrieben (generated_at stammt aus einem früheren Lauf, Python-Payload vermutlich abgestürzt)." >&2
      return 1
    fi
  fi
  return 0
}

# normalize_path_list <datei>
# Windows/MSYS-Sonderfall: Pfade, die als Kommandozeilenargument an natives
# Python gehen, uebersetzt Git Bash (MSYS) automatisch (/c/Users/... wird zu
# C:/Users/...). Pfade, die aus einer Datei GELESEN werden (z.B. eine
# find-Trefferliste, die ein Python-Payload danach oeffnet), bleiben dagegen im
# MSYS-Format und sind fuer natives Python unauffindbar. Diese Funktion
# ersetzt jede nicht-leere Zeile der Datei in-place durch ihr "cygpath -m"-
# Aequivalent. Ohne cygpath (macOS/Linux): No-op, Datei bleibt unveraendert
# (macOS/Linux betroffen nicht).
normalize_path_list() {
  local file="$1"
  if command -v cygpath >/dev/null 2>&1; then
    local tmp
    tmp="$(mktemp)"
    while IFS= read -r _line || [ -n "$_line" ]; do
      [ -z "$_line" ] && continue
      cygpath -m "$_line" 2>/dev/null || printf '%s\n' "$_line"
    done < "$file" > "$tmp"
    mv "$tmp" "$file"
  fi
}
