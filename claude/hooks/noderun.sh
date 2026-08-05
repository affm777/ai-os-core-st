#!/bin/bash
# noderun.sh: fuehrt ein Node-Skript mit dynamisch aufgeloestem node aus.
# Zweck: kein hardcodierter nvm-Versionspfad in settings.json (Hooks sollen
# ein nvm-Update ueberleben). Aufloesung: PATH zuerst, sonst neueste nvm-Version.
if command -v node >/dev/null 2>&1; then
  exec node "$@"
fi
NVM_NODE=$(ls -d "$HOME/.nvm/versions/node"/*/bin/node 2>/dev/null | sort -V | tail -1)
if [ -n "$NVM_NODE" ]; then
  exec "$NVM_NODE" "$@"
fi
echo "noderun.sh: kein node-Binary gefunden (PATH + ~/.nvm geprueft)" >&2
exit 1
