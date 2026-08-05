#!/usr/bin/env bash
# check-prereqs.sh — read-only Voraussetzungs-Check fuer das AIOS-Dashboard.
# Aendert NICHTS. Meldet Pflicht-Tools (fehlend = Fehler) und optionale Tools (fehlend = Hinweis).

set -uo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[optional]${NC} $*"; }
err()  { echo -e "${RED}[FEHLT]${NC} $*"; }

FAIL=0

echo "AIOS-Dashboard — Voraussetzungen"
echo "================================"

# --- Node >= 16 (Pflicht) ---
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [ "${NODE_MAJOR:-0}" -ge 16 ]; then
    ok "Node $(node --version) (>= 16)"
  else
    if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
      err "Node $(node --version) — Version 16+ noetig. Update: https://nodejs.org oder 'winget install OpenJS.NodeJS.LTS'"
    else
      err "Node $(node --version) — Version 16+ noetig. Update: https://nodejs.org oder 'brew install node'"
    fi
    FAIL=1
  fi
else
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
    err "node nicht gefunden — installieren: 'winget install OpenJS.NodeJS.LTS' oder https://nodejs.org"
  else
    err "node nicht gefunden — installieren: 'brew install node' oder https://nodejs.org"
  fi
  FAIL=1
fi

# --- Python (Pflicht) ---
# Frueher stand hier "command -v python3". Das meldete unter Windows GRUEN fuer
# den Microsoft-Store-Stub: eine Datei namens python3, die mit Exit 49 abbricht.
# Die Versionsausgabe wurde dann zu "python3 was" (zweites Wort aus "Python was
# not found"). Deshalb wird jeder Kandidat jetzt ausgefuehrt, nicht nur gesucht.
PYBIN=""
for _cand in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $_cand -c "import sys" </dev/null >/dev/null 2>&1; then PYBIN="$_cand"; break; fi
done
if [ -n "$PYBIN" ]; then
  # shellcheck disable=SC2086
  ok "Python gefunden ueber '$PYBIN' — $($PYBIN --version 2>&1 | cut -d' ' -f2)"
else
  if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* ]]; then
    err "Kein lauffaehiges Python (geprueft: python3, python, py -3) — die Collectors bauen damit die JSON-Daten. Windows: 'winget install Python.Python.3.12', danach neues Terminal"
  else
    err "Kein lauffaehiges Python (geprueft: python3, python, py -3) — die Collectors bauen damit die JSON-Daten. macOS: 'xcode-select --install'"
  fi
  FAIL=1
fi

# --- bash (Pflicht) ---
if command -v bash >/dev/null 2>&1; then
  ok "bash ${BASH_VERSION:-vorhanden}"
else
  err "bash nicht gefunden."
  FAIL=1
fi

echo "--- optional ---"

# --- gws-CLI (optional) ---
if command -v gws >/dev/null 2>&1; then
  ok "gws-CLI vorhanden (Zweitkonto/Kalender headless, 0 Tokens)"
else
  warn "gws-CLI nicht installiert — Zweitkonto bleibt leer, sichtbar als 'nicht installiert'. Dashboard laeuft normal."
fi

# --- claude-Binary (optional) ---
if command -v claude >/dev/null 2>&1; then
  ok "claude-Binary vorhanden (Claude-Aktionen aus dem Dashboard)"
else
  warn "claude-Binary nicht im PATH — Claude-Aktions-Buttons sind inaktiv."
fi

# --- ccusage (optional) ---
if command -v ccusage >/dev/null 2>&1; then
  ok "ccusage vorhanden (Kosten-/Nutzungsauswertung)"
else
  warn "ccusage nicht installiert — Nutzungs-Kachel zeigt Installationshinweis ('npm i -g ccusage')."
fi

echo "================================"
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}Alle Pflicht-Voraussetzungen erfuellt.${NC} Weiter mit der Installation (siehe INSTALL.md)."
  exit 0
else
  echo -e "${RED}Es fehlen Pflicht-Voraussetzungen (siehe oben).${NC} Bitte nachinstallieren und erneut pruefen."
  exit 1
fi
