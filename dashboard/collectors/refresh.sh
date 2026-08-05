#!/bin/bash
# refresh.sh — ruft check.sh (light) + die drei Stufe-1-Collectors nacheinander auf.
# Schreibt data/meta.json mit generated_at und Erfolg/Fehler je Collector.
# Ein gescheiterter Collector bricht die anderen NICHT ab.

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="$HOME/.claude/dashboard"
COLLECTORS_DIR="$DASH_DIR/collectors"
DATA_DIR="$DASH_DIR/data"
mkdir -p "$DATA_DIR"

GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

# Reihenfolge: automationen VOR system-check, damit Check 5 (Scheduled Tasks
# gelaufen) schon die frische automationen.json lesen kann. Ausserdem:
# usage vor portfolio + skills, da beide usage.json lesen
# (portfolio: echte 7-Tage-Sessions je Projekt; skills: Nutzungszahlen).
declare -a NAMES=("automationen" "system-check" "usage" "portfolio" "vault-stats" "skills" "heute" "branding" "sales-file")
# Bewusst nur Dateiname plus Argument, nicht der ganze Befehl als String: der
# Aufruf lief frueher ueber "eval", und darin brach jeder Pfad mit Sonderzeichen
# ab (echter Fall: Benutzerordner "AffomB(ai-os)", die Klammern las eval als
# Shell-Syntax). Es startete dann kein einziger Collector, der Refresh meldete
# aber trotzdem Erfolg.
declare -a FILES=(
  "automationen.sh"
  "check.sh"
  "usage.sh"
  "portfolio.sh"
  "vault-stats.sh"
  "skills.sh"
  "heute.sh"
  "branding.sh"
  "sales-file.sh"
)
declare -a ARGS=("" "light" "" "" "" "" "" "" "")

RESULTS_TMP="$(mktemp)"
trap 'rm -f "$RESULTS_TMP"' EXIT

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  # ARGS bewusst unquotiert: leerer Eintrag soll zu keinem Argument werden.
  # Die Werte sind Literale aus dieser Datei, kein Nutzer-Input.
  # shellcheck disable=SC2086
  if OUTPUT=$(bash "$COLLECTORS_DIR/${FILES[$i]}" ${ARGS[$i]} 2>&1); then
    echo "${name}	ok	" >> "$RESULTS_TMP"
  else
    # Fehlermeldung einzeilig, Tabs entfernen fuer TSV-Sicherheit
    ERR=$(echo "$OUTPUT" | tr '\t\n' '  ' | cut -c1-300)
    echo "${name}	error	${ERR}" >> "$RESULTS_TMP"
  fi
done

META_FILE="$DATA_DIR/meta.json"
$PYBIN - "$GENERATED_AT" "$RESULTS_TMP" <<'PYEOF' > "$META_FILE"
import sys, json

generated_at, results_tmp = sys.argv[1], sys.argv[2]

collectors = {}
with open(results_tmp, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line.strip():
            continue
        parts = line.split("\t")
        name = parts[0]
        status = parts[1] if len(parts) > 1 else "error"
        detail = parts[2] if len(parts) > 2 else ""
        collectors[name] = {"status": status, "detail": detail}

print(json.dumps({
    "generated_at": generated_at,
    "collectors": collectors,
}, ensure_ascii=False, indent=2))
PYEOF
rc=$?

# Dieselbe Absicherung wie in den einzelnen Collectors (siehe python-bin.sh):
# meta.json ist hier sogar der wichtigste Fall, weil sie den Erfolg/Fehler-
# Status ALLER neun Collectors traegt. Stuerzt dieser letzte Python-Aufruf ab,
# wuerde ohne Pruefung eine leere/kaputte meta.json zurueckbleiben und
# "refresh abgeschlossen" trotzdem gemeldet, das Dashboard verlöre also genau
# die Fehleruebersicht, die dieser Umbau ueberhaupt erst herstellen sollte.
verify_json_output "$rc" "$META_FILE" "refresh-meta" "$GENERATED_AT" || exit 1

chmod 644 "$META_FILE"
echo "refresh abgeschlossen, meta.json geschrieben."
