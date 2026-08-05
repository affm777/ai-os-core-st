#!/bin/bash
# noderun.sh (Windows-Overlay-Fassung): fuehrt ein Node-Skript mit dynamisch
# aufgeloestem node aus. Wird von windows/bootstrap.sh nach ~/.claude/hooks/
# kopiert und ersetzt dort die Mac/Unix-Fassung (die auf ~/.nvm/versions/node
# aufloest, was es unter Git Bash auf Windows so nicht gibt).
# Zweck: kein hardcodierter node-Pfad in settings.json (Hooks sollen ein
# Node-Update ueberleben). Aufloesung: PATH zuerst, dann Standard-Installer-Pfad,
# dann nvm-windows (hoechste Version).
if command -v node >/dev/null 2>&1; then
  exec node "$@"
fi
if [ -x "/c/Program Files/nodejs/node.exe" ]; then
  exec "/c/Program Files/nodejs/node.exe" "$@"
fi
# APPDATA kommt aus Windows mit Backslashes, in Bash muss daraus ein
# Unix-Pfad werden, sonst greift das Glob nie.
APPDATA_UNIX="${APPDATA:-}"
if [ -n "$APPDATA_UNIX" ] && command -v cygpath >/dev/null 2>&1; then
  APPDATA_UNIX="$(cygpath -u "$APPDATA_UNIX" 2>/dev/null || printf '%s' "$APPDATA_UNIX")"
fi
NVM_WIN_NODE=$(ls -d "$APPDATA_UNIX/nvm/v"*/node.exe 2>/dev/null | sort -V | tail -1)
if [ -n "$NVM_WIN_NODE" ]; then
  exec "$NVM_WIN_NODE" "$@"
fi
echo "noderun.sh (windows): kein node-Binary gefunden (PATH + Program Files + nvm-windows geprueft)" >&2
exit 1
