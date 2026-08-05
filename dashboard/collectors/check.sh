#!/usr/bin/env bash
# =============================================================================
# check.sh (Deterministischer System-Check-Sammler für /system-check)
# =============================================================================
# Read-only gegenüber dem restlichen System. Einzige Schreibziele:
#   $OUTPUT_DIR/system-check.json und $REPORT_DIR/YYYY-MM-DD-system-check.md
#
# Aufruf:
#   bash check.sh [light|full]   (Default: light)
#
# Härtungsregel: Ein Check, der selbst nicht ausführbar ist (Datei fehlt,
# Tool fehlt, Parse-Fehler), liefert FAIL mit Erklärung, niemals ein
# stilles Ueberspringen.
#
# Alle Pfade sind über CHECK_*-Umgebungsvariablen überschreibbar (für
# Tests). Ohne Overrides zeigt das Skript auf das echte System.
# =============================================================================

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

# Windows-Umgebungsvariablen wie APPDATA oder LOCALAPPDATA kommen im
# Windows-Format mit Backslashes. In Bash laesst sich damit kein Pfad bauen,
# Checks gegen "$LOCALAPPDATA/..." schlugen deshalb unter Windows immer fehl,
# auch wenn die gesuchte Software installiert war. Auf dem Mac existiert weder
# die Variable noch cygpath, dann gibt die Funktion einfach den Eingabewert
# zurueck und nichts aendert sich.
win_env_to_unix() {
  local p="${1:-}"
  [ -z "$p" ] && { printf '%s' ""; return 0; }
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

MODE="${1:-light}"
if [[ "$MODE" != "light" && "$MODE" != "full" ]]; then
  echo "Usage: check.sh [light|full]" >&2
  exit 2
fi

# --- Pfade (überschreibbar für Tests) ---
CLAUDE_DIR="${CHECK_CLAUDE_DIR:-$HOME/.claude}"
SETTINGS_PATH="${CHECK_SETTINGS_PATH:-$CLAUDE_DIR/settings.json}"
HOOKS_DIR="${CHECK_HOOKS_DIR:-$CLAUDE_DIR/hooks}"
MCP_AUTH_CACHE="${CHECK_MCP_AUTH_CACHE:-$CLAUDE_DIR/mcp-needs-auth-cache.json}"
PROJECT_REPOS_YAML="${CHECK_PROJECT_REPOS_YAML:-$CLAUDE_DIR/project-repos.yaml}"
VAULT_DIR="${CHECK_VAULT_DIR:-$HOME/Documents/Second-Brain}"
TRASH_STAGING_DIR="${CHECK_TRASH_STAGING_DIR:-$CLAUDE_DIR/trash-staging}"
SAFETY_LOG="${CHECK_SAFETY_LOG:-$HOOKS_DIR/safety.log}"
CLAUDE_ROOT_FOR_BACKUPS="${CHECK_CLAUDE_ROOT:-$CLAUDE_DIR}"
OUTPUT_DIR="${CHECK_OUTPUT_DIR:-$HOME/.claude/dashboard/data}"
REPORT_DIR="${CHECK_REPORT_DIR:-$HOME/.claude/dashboard/reports}"
TEMPLATE_PATH="${CHECK_TEMPLATE_PATH:-$HOME/.claude/templates/new-project/STATE.md.template}"

mkdir -p "$OUTPUT_DIR" "$REPORT_DIR"

ROWS_FILE="$(mktemp)"
trap 'rm -f "$ROWS_FILE"' EXIT

FS=$'\x1f'  # Feld-Trenner, Zeile = ein Check-Ergebnis

# emit id name status detail fix
emit() {
  local id="$1" name="$2" status="$3" detail="$4" fix="$5"
  detail="${detail//$'\n'/ }"
  fix="${fix//$'\n'/ }"
  printf '%s%s%s%s%s%s%s%s%s\n' "$id" "$FS" "$name" "$FS" "$status" "$FS" "$detail" "$FS" "$fix" >> "$ROWS_FILE"
}

now_epoch() { date +%s; }

# --- Hilfsfunktion: Datum YYYY-MM-DD zu Epoch (macOS + Linux) ---
date_to_epoch() {
  local d="$1"
  date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null || date -d "$d" +%s 2>/dev/null
}

file_mtime_epoch() {
  # GNU stat (Git Bash) zuerst versuchen: unter GNU-stat ist "-f" ein anderer
  # Schalter (Dateisystem-Status) als bei BSD-stat, der Aufruf endet mit
  # Exit 1, schreibt vorher aber einen mehrzeiligen Block nach stdout, den
  # "2>/dev/null" nicht abfängt (das fängt nur stderr). Ohne Abfangen in
  # einer Variable liefert die Funktion dann Text PLUS Zahl zurück, was bei
  # Aufrufern im arithmetischen Kontext abstürzt.
  local f="$1" m=""
  m=$(stat -c %Y "$f" 2>/dev/null) || m=$(stat -f %m "$f" 2>/dev/null) || m=""
  [[ "$m" =~ ^[0-9]+$ ]] && printf '%s' "$m"
  return 0
}

# =============================================================================
# Check 1: settings.json parsebar
# =============================================================================
check_settings_json() {
  if [[ ! -f "$SETTINGS_PATH" ]]; then
    emit "1" "settings.json parsebar" "fail" \
      "Datei nicht gefunden: $SETTINGS_PATH" \
      "Datei aus jüngstem Backup wiederherstellen (z. B. ein settings.json.bak-* oder settings.json.backup-* im ~/.claude-Root) oder aus settings.json.template neu aufsetzen."
    return
  fi
  local err
  if err=$($PYBIN -m json.tool "$SETTINGS_PATH" 2>&1 >/dev/null); then
    emit "1" "settings.json parsebar" "ok" "$SETTINGS_PATH ist valides JSON." ""
  else
    emit "1" "settings.json parsebar" "fail" \
      "JSON-Parse-Fehler in $SETTINGS_PATH: $err" \
      "JSON-Fehler manuell beheben, danach gegen ein jüngeres Backup (settings.json.bak-* oder settings.json.backup-*) diffen."
  fi
  SETTINGS_OK=$([[ "$err" == "" ]] && echo 1 || echo 0)
}

# =============================================================================
# Hilfsfunktion für Check 2+3: Hook-Kommandos aus settings.json extrahieren
# Ausgabe je Zeile: "<runner>\t<pfad>"
# =============================================================================
extract_hook_commands() {
  $PYBIN - "$SETTINGS_PATH" <<'PYEOF'
import json, sys, re, os
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
hooks = d.get("hooks", {})
seen = set()
home = os.path.expanduser("~")
for _event, entries in hooks.items():
    if not isinstance(entries, list):
        continue
    for entry in entries:
        for h in entry.get("hooks", []):
            cmd = h.get("command", "")
            if not cmd:
                continue
            expanded = cmd.replace("$HOME", home).replace('"', "")
            m = re.match(r"^(bash|python3|node|sh)\s+(\S+)", expanded)
            if m:
                runner, p = m.group(1), m.group(2)
            else:
                parts = expanded.split()
                runner, p = "direct", (parts[0] if parts else "")
            if p and p not in seen:
                seen.add(p)
                print(f"{runner}\t{p}")
PYEOF
}

# =============================================================================
# Check 2: Registrierte Hooks existieren + ausführbar
# Check 3: Hook-Syntax (bash -n / node --check)
# =============================================================================
check_hooks_exist_and_syntax() {
  if [[ "${SETTINGS_OK:-0}" != "1" ]]; then
    emit "2" "Registrierte Hooks existieren + ausführbar" "fail" \
      "settings.json ist nicht lesbar (siehe Check 1), Hook-Registry kann nicht geprüft werden." \
      "Erst Check 1 beheben (settings.json reparieren), Check 2 danach erneut laufen lassen."
    emit "3" "Hook-Syntax" "fail" \
      "settings.json ist nicht lesbar (siehe Check 1), Hook-Syntax kann nicht geprüft werden." \
      "Erst Check 1 beheben (settings.json reparieren), Check 3 danach erneut laufen lassen."
    return
  fi

  local pairs
  pairs=$(extract_hook_commands)

  if [[ -z "$pairs" ]]; then
    emit "2" "Registrierte Hooks existieren + ausführbar" "ok" "Keine Hook-Kommandos in settings.json registriert." ""
    emit "3" "Hook-Syntax" "ok" "Keine Hook-Skripte zu prüfen." ""
    return
  fi

  local missing=()
  local not_exec=()
  local syntax_errors=()
  local n=0

  while IFS=$'\t' read -r runner p; do
    [[ -z "$p" ]] && continue
    n=$((n + 1))

    if [[ ! -e "$p" ]]; then
      missing+=("$p")
      continue
    fi
    # Unter Windows (Git Bash) ist chmod auf NTFS ein No-Op, das -x-Bit ist
    # dort kein verlaesslicher Indikator, daher Test dort ueberspringen.
    if [[ "$runner" == "direct" && ! -x "$p" && "$(uname -s)" != MINGW* && "$(uname -s)" != MSYS* ]]; then
      not_exec+=("$p")
    fi

    case "$p" in
      *.sh)
        local err
        if ! err=$(bash -n "$p" 2>&1); then
          syntax_errors+=("$p: $err")
        fi
        ;;
      *.js)
        if command -v node >/dev/null 2>&1; then
          local err
          if ! err=$(node --check "$p" 2>&1); then
            syntax_errors+=("$p: $err")
          fi
        else
          syntax_errors+=("$p: node nicht verfügbar, Syntax-Check übersprungen (siehe Check 4)")
        fi
        ;;
    esac
  done <<< "$pairs"

  if (( ${#missing[@]} == 0 && ${#not_exec[@]} == 0 )); then
    emit "2" "Registrierte Hooks existieren + ausführbar" "ok" "Alle $n registrierten Hook-Dateien vorhanden (und, wo direkt aufgerufen, ausführbar)." ""
  else
    local detail="Fehlend: ${missing[*]:-keine}. Nicht ausführbar (Direktaufruf ohne Interpreter, fehlendes +x): ${not_exec[*]:-keine}."
    emit "2" "Registrierte Hooks existieren + ausführbar" "fail" "$detail" \
      "Fehlende Hook-Datei(en) wiederherstellen bzw. Pfad in settings.json korrigieren; bei fehlendem +x: chmod +x <datei>."
  fi

  if (( ${#syntax_errors[@]} == 0 )); then
    emit "3" "Hook-Syntax" "ok" "Alle geprüften .sh/.js-Hooks sind syntaktisch fehlerfrei." ""
  else
    local detail
    detail=$(printf '%s | ' "${syntax_errors[@]}")
    emit "3" "Hook-Syntax" "fail" "$detail" "Syntaxfehler im betroffenen Hook beheben (bash -n bzw. node --check lokal nachvollziehen)."
  fi
}

# =============================================================================
# Check 4: Node erreichbar (gleiche Auflösung wie hooks/noderun.sh)
# =============================================================================
check_node() {
  local resolved=""
  if command -v node >/dev/null 2>&1; then
    resolved="$(command -v node) ($(node --version 2>/dev/null))"
  else
    local nvm_node
    nvm_node=$(ls -d "$HOME/.nvm/versions/node"/*/bin/node 2>/dev/null | sort -V | tail -1)
    if [[ -n "$nvm_node" && -x "$nvm_node" ]]; then
      resolved="$nvm_node ($("$nvm_node" --version 2>/dev/null))"
    fi
    # Windows-Kandidaten: offizieller Installer-Pfad, sowie nvm-windows-Layout
    # (anderes Verzeichnisschema als nvm-Unix, daher eigener Kandidat).
    if [[ -z "$resolved" && -x "/c/Program Files/nodejs/node.exe" ]]; then
      resolved="/c/Program Files/nodejs/node.exe ($("/c/Program Files/nodejs/node.exe" --version 2>/dev/null))"
    fi
    if [[ -z "$resolved" ]]; then
      local nvmw_node
      nvmw_node=$(ls -d "$(win_env_to_unix "${APPDATA:-}")/nvm/v"*/node.exe 2>/dev/null | sort -V | tail -1)
      if [[ -n "$nvmw_node" && -x "$nvmw_node" ]]; then
        resolved="$nvmw_node ($("$nvmw_node" --version 2>/dev/null))"
      fi
    fi
  fi
  if [[ -n "$resolved" ]]; then
    emit "4" "Node erreichbar" "ok" "Aufgelöst wie noderun.sh (PATH zuerst, sonst neueste nvm-Version): $resolved" ""
  else
    emit "4" "Node erreichbar" "fail" \
      "Kein node über PATH oder ~/.nvm/versions/node auffindbar (gleiche Logik wie hooks/noderun.sh)." \
      "Node.js installieren, z. B. via 'nvm install --lts', oder PATH prüfen."
  fi
}

# =============================================================================
# Check 5: Scheduled Tasks gelaufen
# Marker 1: jüngster "(scheduled)"-Eintrag im vault-log
# Marker 2: mtime von .last-cleanup
# WARN > 26h, FAIL > 3 Tage (72h), je Marker
# =============================================================================
check_scheduled_tasks() {
  local worst="ok"
  local details=()
  local found=0

  local vault_log="$VAULT_DIR/00_Meta/system/vault-log.md"
  if [[ -f "$vault_log" ]]; then
    local last_line
    last_line=$(grep -E '\(scheduled\)' "$vault_log" | tail -1)
    if [[ -n "$last_line" ]]; then
      local d
      d=$(echo "$last_line" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' | head -1 | tr -d '[]')
      local epoch
      epoch=$(date_to_epoch "$d")
      if [[ -n "$epoch" ]]; then
        found=1
        local age_h=$(( ( $(now_epoch) - epoch ) / 3600 ))
        details+=("Vault-Sweep (scheduled) vor ca. ${age_h}h (Tagesauflösung)")
        if (( age_h > 72 )); then
          worst="fail"
        elif (( age_h > 26 )) && [[ "$worst" != "fail" ]]; then
          worst="warn"
        fi
      fi
    fi
  fi

  local last_cleanup="$CLAUDE_DIR/.last-cleanup"
  if [[ -f "$last_cleanup" ]]; then
    local mtime_epoch
    mtime_epoch=$(file_mtime_epoch "$last_cleanup")
    if [[ -n "$mtime_epoch" ]]; then
      found=1
      local age_h=$(( ( $(now_epoch) - mtime_epoch ) / 3600 ))
      details+=("Cleanup-Marker (.last-cleanup) vor ${age_h}h")
      if (( age_h > 72 )); then
        worst="fail"
      elif (( age_h > 26 )) && [[ "$worst" != "fail" ]]; then
        worst="warn"
      fi
    fi
  fi

  # Zusätzlich: echter Erfolg/Fehler-Status je Routine aus automationen.json
  # (vom automationen.sh-Collector aus den Session-Transcripts abgeleitet).
  # Fehlt oder ist kaputt: still überspringen, die Marker-Logik oben bleibt
  # unberührt (wichtig für Erst-Setups ohne vorherigen Collector-Lauf).
  # check.sh läuft auch standalone ohne vorherigen refresh.sh-Durchlauf,
  # dann ist automationen.json ggf. vom letzten Refresh: tolerant by design.
  # Vor dem found==0-Guard geprüft, damit automationen.json allein schon als
  # gültige Marker-Quelle zählt (Erst-Setup ohne vault-log/.last-cleanup).
  local automationen_json="$OUTPUT_DIR/automationen.json"
  local auto_fix=""
  if [[ -f "$automationen_json" ]]; then
    local auto_rows
    auto_rows=$($PYBIN - "$automationen_json" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(0)
tasks = d.get("tasks", [])
if not isinstance(tasks, list):
    sys.exit(0)
for t in tasks:
    if not isinstance(t, dict):
        continue
    name = t.get("name", "")
    titel = t.get("titel", name)
    status = t.get("status", "")
    fehler_text = (t.get("fehler_text") or "")[:80]
    print("\t".join([str(name), str(titel), str(status), fehler_text]))
PYEOF
)
    if [[ -n "$auto_rows" ]]; then
      found=1
      while IFS=$'\t' read -r a_name a_titel a_status a_fehler; do
        [[ -z "$a_name" ]] && continue
        if [[ "$a_status" == "fehler" ]]; then
          worst="fail"
          details+=("Routine ${a_titel}: letzter Lauf mit Fehler (${a_fehler})")
          auto_fix="Routine in der Claude Desktop App prüfen und manuell anstoßen, Details auf der Automationen-Seite."
        elif [[ "$a_status" == "ueberfaellig" ]]; then
          [[ "$worst" != "fail" ]] && worst="warn"
          details+=("Routine ${a_titel}: kein Lauf innerhalb des erwarteten Rhythmus")
          [[ -z "$auto_fix" ]] && auto_fix="Routine in der Claude Desktop App prüfen und manuell anstoßen, Details auf der Automationen-Seite."
        fi
      done <<< "$auto_rows"
    fi
  fi

  if (( found == 0 )); then
    # Kein einziger Marker irgendeiner Quelle = Erst-Setup, in dem noch keine
    # Routine gelaufen ist (nicht "kaputt": sobald eine Routine einmal lief,
    # bleibt mindestens ein Marker dauerhaft bestehen). warn statt fail.
    emit "5" "Scheduled Tasks gelaufen" "warn" \
      "Noch keine Scheduled-Task-Marker vorhanden (weder '(scheduled)'-Eintrag im vault-log noch .last-cleanup noch automationen.json)." \
      "Normal direkt nach dem Setup — die nächtlichen Routinen laufen automatisch, sobald sie einmal fällig waren."
    return
  fi

  local detail_str
  detail_str=$(printf '%s; ' "${details[@]}")
  local fix="$auto_fix"
  if [[ -z "$fix" && "$worst" != "ok" ]]; then
    fix="Scheduled Task prüfen und ggf. manuell anstoßen (z. B. /brain:sort-inbox scheduled)."
  fi
  emit "5" "Scheduled Tasks gelaufen" "$worst" "$detail_str" "$fix"
}

# =============================================================================
# Check 6: Connector-Auth (mcp-needs-auth-cache.json)
# =============================================================================
check_connector_auth() {
  if [[ ! -f "$MCP_AUTH_CACHE" ]]; then
    emit "6" "Connector-Auth" "ok" "mcp-needs-auth-cache.json nicht vorhanden, keine bekannten Re-Auth-Anforderungen." ""
    return
  fi
  local out
  out=$($PYBIN - "$MCP_AUTH_CACHE" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    print("ERROR")
    sys.exit(0)
if not isinstance(d, dict):
    print("ERROR")
    sys.exit(0)
print(len(d))
for k in d:
    print(k)
PYEOF
)
  local first_line
  first_line=$(echo "$out" | head -1)
  if [[ "$first_line" == "ERROR" ]]; then
    emit "6" "Connector-Auth" "fail" "mcp-needs-auth-cache.json ist nicht parsebar (kein valides JSON-Objekt)." "Datei prüfen: $MCP_AUTH_CACHE"
    return
  fi
  if [[ -z "$first_line" || "$first_line" == "0" ]]; then
    emit "6" "Connector-Auth" "ok" "Keine Connectoren mit Re-Auth-Bedarf." ""
    return
  fi
  local names
  names=$(echo "$out" | tail -n +2 | paste -sd, -)
  emit "6" "Connector-Auth" "warn" "Re-Auth nötig für: $names" "Connector(en) im Claude-Client neu autorisieren (OAuth-Flow erneut durchlaufen): $names"
}

# =============================================================================
# Check 7: Vault-Maschinerie (letzter Sweep, Inbox-Count, vault-index-Frische)
# WARN Sweep > 48h oder Inbox > 40
# =============================================================================
check_vault_machinery() {
  local vault_log="$VAULT_DIR/00_Meta/system/vault-log.md"
  if [[ ! -f "$vault_log" ]]; then
    emit "7" "Vault-Maschinerie" "fail" "vault-log.md nicht gefunden unter $vault_log" \
      "Vault-Pfad prüfen (CHECK_VAULT_DIR) oder einmalig /brain:rebuild-index laufen lassen."
    return
  fi

  local status="ok"
  local msgs=()

  local last_sweep_line
  last_sweep_line=$(grep -E '^## \[[0-9]{4}-[0-9]{2}-[0-9]{2}\] sweep' "$vault_log" | tail -1)
  if [[ -n "$last_sweep_line" ]]; then
    local d
    d=$(echo "$last_sweep_line" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' | head -1 | tr -d '[]')
    local epoch
    epoch=$(date_to_epoch "$d")
    if [[ -n "$epoch" ]]; then
      local age_h=$(( ( $(now_epoch) - epoch ) / 3600 ))
      msgs+=("letzter Sweep vor ca. ${age_h}h")
      (( age_h > 48 )) && status="warn"
    fi
  else
    msgs+=("kein Sweep-Eintrag im vault-log gefunden")
    status="warn"
  fi

  local inbox_dir="$VAULT_DIR/01_Inbox"
  local inbox_count=0
  if [[ -d "$inbox_dir" ]]; then
    inbox_count=$(find "$inbox_dir" -maxdepth 1 -type f ! -name ".*" | wc -l | tr -d ' ')
  fi
  msgs+=("Inbox: ${inbox_count} Dateien")
  (( inbox_count > 40 )) && status="warn"

  local idx="$VAULT_DIR/00_Meta/system/vault-index.md"
  if [[ -f "$idx" ]]; then
    local idx_mtime_h
    idx_mtime_h=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$idx" 2>/dev/null || stat -c "%y" "$idx" 2>/dev/null)
    msgs+=("vault-index zuletzt aktualisiert: $idx_mtime_h")
  fi

  local detail_str
  detail_str=$(printf '%s; ' "${msgs[@]}")
  local fix=""
  [[ "$status" == "warn" ]] && fix="Inbox mit /brain:sort-inbox einsortieren bzw. Sweep-Ursache prüfen."
  emit "7" "Vault-Maschinerie" "$status" "$detail_str" "$fix"
}

# =============================================================================
# Check 8: Vault-Lint-Frische (jüngster lint-reports/*-lint.md)
# WARN > 7 Tage
# =============================================================================
check_vault_lint() {
  local lint_dir="$VAULT_DIR/00_Meta/system/lint-reports"
  # Verzeichnis/Report fehlt komplett = /brain:health-check lief noch nie.
  # Das ist die erkennbare Erst-Setup-Signatur (nicht "kaputt"), deshalb warn
  # statt fail, mit Onboarding-Hinweis statt Fehler-Ton.
  if [[ ! -d "$lint_dir" ]]; then
    emit "8" "Vault-Lint-Frische" "warn" "Noch kein Vault-Lint-Report vorhanden: $lint_dir" "Einmalig /brain:health-check ausführen, dann läuft die wöchentliche Frische-Prüfung."
    return
  fi
  local latest
  latest=$(ls -1 "$lint_dir" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-lint\.md$' | sort | tail -1)
  if [[ -z "$latest" ]]; then
    emit "8" "Vault-Lint-Frische" "warn" "Noch kein Lint-Report im erwarteten Format YYYY-MM-DD-lint.md in $lint_dir" "Einmalig /brain:health-check ausführen, dann läuft die wöchentliche Frische-Prüfung."
    return
  fi
  local d="${latest%-lint.md}"
  local epoch
  epoch=$(date_to_epoch "$d")
  if [[ -z "$epoch" ]]; then
    emit "8" "Vault-Lint-Frische" "fail" "Datum aus Dateinamen $latest nicht parsebar." "Dateinamen-Konvention YYYY-MM-DD-lint.md prüfen."
    return
  fi
  local age_d=$(( ( $(now_epoch) - epoch ) / 86400 ))
  local status="ok"
  (( age_d > 7 )) && status="warn"
  local fix=""
  [[ "$status" == "warn" ]] && fix="/brain:health-check ausführen, um einen frischen Lint-Report zu erzeugen."
  local findings
  findings=$(grep -ciE 'FAIL|WARN' "$lint_dir/$latest" 2>/dev/null || echo "0")
  emit "8" "Vault-Lint-Frische" "$status" "Jüngster Report: $latest, Alter: ${age_d} Tage, ca. ${findings} WARN/FAIL-Zeilen darin (informativ)." "$fix"
}

# =============================================================================
# Check 9: STATE.md je Projekt (project-repos.yaml)
# WARN fehlend oder nicht konform (Sektionen: Current Position, Pending Todos,
# Session Continuity). Alter ist nur informativ, beeinflusst den Status nicht.
# =============================================================================
check_state_md_for_project() {
  local slug="$1" proj_path="$2"

  local state_file=""
  if [[ -f "$proj_path/.planning/STATE.md" ]]; then
    state_file="$proj_path/.planning/STATE.md"
  elif [[ -f "$proj_path/STATE.md" ]]; then
    state_file="$proj_path/STATE.md"
  fi

  if [[ -z "$state_file" ]]; then
    emit "9.$slug" "STATE.md: $slug" "warn" \
      "Keine STATE.md gefunden (weder .planning/STATE.md noch STATE.md im Root von $proj_path)." \
      "STATE.md gemäß Template anlegen: $TEMPLATE_PATH"
    return
  fi

  local has_current_pos=0 has_pending=0 has_session_cont=0
  grep -qE '^## ?Current Position|^Current Position[[:space:]]*$' "$state_file" && has_current_pos=1
  # Ebene 2 und 3 gelten beide: "Pending Todos" darf als eigene Top-Level-Sektion
  # ("## Pending Todos") oder als Unterpunkt von "## Accumulated Context"
  # ("### Pending Todos") gefuehrt werden. Muss deckungsgleich bleiben mit
  # RE_PENDING in portfolio.sh und RE_PENDING_HEADING in server.mjs.
  grep -qE '^#{2,3}[[:space:]]*Pending Todos[[:space:]]*$' "$state_file" && has_pending=1
  grep -qE '^## Session Continuity' "$state_file" && has_session_cont=1

  local age_d="n/a"
  local mtime_epoch
  mtime_epoch=$(file_mtime_epoch "$state_file")
  [[ -n "$mtime_epoch" ]] && age_d=$(( ( $(now_epoch) - mtime_epoch ) / 86400 ))

  if (( has_current_pos == 1 && has_pending == 1 && has_session_cont == 1 )); then
    emit "9.$slug" "STATE.md: $slug" "ok" \
      "$state_file ist Template-konform (Current Position, Pending Todos, Session Continuity vorhanden). Alter: ${age_d} Tage (informativ)." ""
  else
    local missing=""
    (( has_current_pos == 0 )) && missing+="Current Position, "
    (( has_pending == 0 )) && missing+="Pending Todos, "
    (( has_session_cont == 0 )) && missing+="Session Continuity, "
    missing="${missing%, }"
    emit "9.$slug" "STATE.md: $slug" "warn" \
      "$state_file ist nicht Template-konform. Fehlende Sektionen: $missing. Alter: ${age_d} Tage (informativ)." \
      "Migriere die STATE.md von $slug verlustfrei in die Template-Struktur ($TEMPLATE_PATH): Backup anlegen, kompletten Inhalt erhalten, nur unter die Template-Überschriften umsortieren, danach Diff zeigen."
  fi
}

check_all_projects_state_md() {
  # Datei fehlt komplett = noch kein Projekt angelegt (Erst-Setup-Signatur),
  # kein defekter Zustand. warn + Onboarding-Hinweis statt fail.
  if [[ ! -f "$PROJECT_REPOS_YAML" ]]; then
    emit "9" "STATE.md je Projekt" "warn" "Noch keine project-repos.yaml vorhanden: $PROJECT_REPOS_YAML" "Erstes Projekt über /new-project anlegen, das schreibt project-repos.yaml automatisch."
    return
  fi

  local any=0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue
    if [[ "$line" =~ ^([a-zA-Z0-9_-]+):[[:space:]]*(.+)[[:space:]]*$ ]]; then
      local slug="${BASH_REMATCH[1]}"
      local proj_path="${BASH_REMATCH[2]}"
      proj_path="${proj_path%\"}"
      proj_path="${proj_path#\"}"
      proj_path="${proj_path%%#*}"
      proj_path="$(echo "$proj_path" | sed -e 's/[[:space:]]*$//')"
      # Pfadformat vereinheitlichen: Backslash-Pfade (Windows-nativ eingetragen)
      # zu Forward-Slash umbauen. Bash kommt mit dem MSYS-Format (/c/Users/...)
      # bereits nativ klar, das bleibt unverändert.
      proj_path="${proj_path//\\//}"
      [[ -z "$proj_path" ]] && continue
      any=1
      check_state_md_for_project "$slug" "$proj_path"
    fi
  done < "$PROJECT_REPOS_YAML"

  if (( any == 0 )); then
    emit "9" "STATE.md je Projekt" "warn" "project-repos.yaml enthält noch keine parsebaren Projekt-Zeilen." "Erstes Projekt über /new-project anlegen, das schreibt project-repos.yaml automatisch."
  fi
}

# =============================================================================
# Check 10 (full): Repo-Drift Live vs. Starter
# Ausgelagert nach check-repo-drift.sh (Werkstatt-Datei, siehe dort).
# Wird weiter unten per source eingebunden, wenn die Datei vorhanden ist.
# Fehlt sie, entfaellt Check 10 ersatzlos.
# =============================================================================

# =============================================================================
# Check 11 (full): Haushalt
# trash-staging ältester Ordner > 30 Tage, safety.log > 5000 Zeilen,
# > 2 Backup-Dateien im ~/.claude-Root
# =============================================================================
check_haushalt() {
  if [[ -d "$TRASH_STAGING_DIR" ]]; then
    local oldest_epoch="" oldest_name=""
    while IFS= read -r -d '' d; do
      local m
      m=$(file_mtime_epoch "$d")
      [[ -z "$m" ]] && continue
      if [[ -z "$oldest_epoch" || "$m" -lt "$oldest_epoch" ]]; then
        oldest_epoch="$m"
        oldest_name="$(basename "$d")"
      fi
    done < <(find "$TRASH_STAGING_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

    if [[ -n "$oldest_epoch" ]]; then
      local age_d=$(( ( $(now_epoch) - oldest_epoch ) / 86400 ))
      local status="ok"
      (( age_d > 30 )) && status="warn"
      local fix=""
      [[ "$status" == "warn" ]] && fix="Alte trash-staging-Ordner sichten und löschen (ältester: $oldest_name, ${age_d} Tage alt)."
      emit "11-trash-staging" "Haushalt: trash-staging" "$status" "Ältester Ordner: $oldest_name, ${age_d} Tage alt." "$fix"
    else
      emit "11-trash-staging" "Haushalt: trash-staging" "ok" "trash-staging ist leer." ""
    fi
  else
    emit "11-trash-staging" "Haushalt: trash-staging" "ok" "Kein trash-staging-Verzeichnis vorhanden." ""
  fi

  if [[ -f "$SAFETY_LOG" ]]; then
    local lines
    lines=$(wc -l < "$SAFETY_LOG" | tr -d ' ')
    local status="ok"
    (( lines > 5000 )) && status="warn"
    local fix=""
    [[ "$status" == "warn" ]] && fix="safety.log rotieren bzw. kürzen: $SAFETY_LOG (${lines} Zeilen)."
    emit "11-safety-log" "Haushalt: safety.log" "$status" "${lines} Zeilen." "$fix"
  else
    emit "11-safety-log" "Haushalt: safety.log" "ok" "safety.log nicht vorhanden." ""
  fi

  local backup_count=0
  local backups=()
  while IFS= read -r -d '' f; do
    backup_count=$((backup_count + 1))
    backups+=("$(basename "$f")")
  done < <(find "$CLAUDE_ROOT_FOR_BACKUPS" -maxdepth 1 -type f \
    \( -iname "*.backup-*" -o -iname "*.bak-*" -o -iname "*-backup-*" -o -iname "*.bak" \) \
    ! -iname "*.template" -print0)
  local status="ok"
  (( backup_count > 2 )) && status="warn"
  local fix=""
  [[ "$status" == "warn" ]] && fix="Alte Backup-Dateien im ~/.claude-Root aufräumen: ${backups[*]}"
  emit "11-root-backups" "Haushalt: Backup-Dateien im Root" "$status" "${backup_count} Backup-Datei(en) gefunden: ${backups[*]:-keine}." "$fix"
}

# =============================================================================
# Check 12 (full): Dependencies (node, npm, Chromium/Playwright, ccusage)
# WARN je fehlend. ccusage fehlt = Statistik-Modul "nicht verfügbar", kein FAIL.
# =============================================================================
check_dependencies() {
  if command -v node >/dev/null 2>&1; then
    emit "12-node" "Dependency: node" "ok" "$(command -v node) ($(node --version 2>/dev/null))" ""
  else
    emit "12-node" "Dependency: node" "warn" "node nicht im PATH gefunden." "Node.js installieren, z. B. via 'nvm install --lts'."
  fi

  if command -v npm >/dev/null 2>&1; then
    emit "12-npm" "Dependency: npm" "ok" "$(command -v npm) ($(npm --version 2>/dev/null))" ""
  else
    emit "12-npm" "Dependency: npm" "warn" "npm nicht im PATH gefunden." "npm kommt i. d. R. mit der Node-Installation, diese prüfen."
  fi

  local pw_cache="$HOME/Library/Caches/ms-playwright"
  if compgen -G "$pw_cache/chromium*" > /dev/null 2>&1; then
    emit "12-chromium" "Dependency: Chromium (Playwright)" "ok" "Chromium-Build gefunden unter $pw_cache" ""
  # Windows-Pendant (LOCALAPPDATA ist in Git Bash gesetzt), nur geprüft wenn der Mac-Pfad nicht existiert.
  elif compgen -G "$(win_env_to_unix "${LOCALAPPDATA:-}")/ms-playwright/chromium*" > /dev/null 2>&1; then
    emit "12-chromium" "Dependency: Chromium (Playwright)" "ok" "Chromium-Build gefunden unter $(win_env_to_unix "${LOCALAPPDATA:-}")/ms-playwright" ""
  else
    emit "12-chromium" "Dependency: Chromium (Playwright)" "warn" "Kein Chromium-Build unter $pw_cache gefunden." "npx playwright install chromium ausführen."
  fi

  if command -v ccusage >/dev/null 2>&1; then
    emit "12-ccusage" "Dependency: ccusage" "ok" "$(command -v ccusage)" ""
  else
    emit "12-ccusage" "Dependency: ccusage" "warn" "ccusage nicht gefunden, Nutzungs-Statistik-Modul ist 'nicht verfügbar' (kein Fehlerzustand)." "Optional: ccusage installieren (npm i -g ccusage) für das Nutzungs-Statistik-Modul."
  fi
}

# =============================================================================
# Ablauf
# =============================================================================
SETTINGS_OK=0

check_settings_json
check_hooks_exist_and_syntax
check_node
check_scheduled_tasks
check_connector_auth
check_vault_machinery
check_vault_lint
check_all_projects_state_md

# Optionaler Check 10 (Werkstatt): nur vorhanden, wenn check-repo-drift.sh
# neben diesem Skript liegt. In abgeleiteten Repos fehlt die Datei bewusst.
COLLECTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$COLLECTOR_DIR/check-repo-drift.sh" ]]; then
  # shellcheck source=/dev/null
  source "$COLLECTOR_DIR/check-repo-drift.sh"
fi

if [[ "$MODE" == "full" ]]; then
  if declare -f check_repo_drift >/dev/null; then
    check_repo_drift
  fi
  check_haushalt
  check_dependencies
fi

# =============================================================================
# JSON + Markdown-Report schreiben
# =============================================================================
# GENERATED_AT wird hier (statt wie sonst am Skriptanfang) unmittelbar vor dem
# schreibenden Python-Aufruf gebildet und als Argument durchgereicht (statt
# lokal in Python neu zu berechnen), damit verify_json_output unten den
# Absturz-Fall zuverlaessig von einer stehengebliebenen alten
# system-check.json unterscheiden kann (siehe python-bin.sh).
GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')
$PYBIN - "$ROWS_FILE" "$MODE" "$OUTPUT_DIR" "$REPORT_DIR" "$GENERATED_AT" <<'PYEOF'
import sys, json, datetime, os

rows_file, mode, out_dir, report_dir, generated_at = sys.argv[1:6]
checks = []
with open(rows_file, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\x1f")
        if len(parts) != 5:
            continue
        cid, name, status, detail, fix = parts
        checks.append({"id": cid, "name": name, "status": status, "detail": detail, "fix": fix})

summary = {"ok": 0, "warn": 0, "fail": 0}
for c in checks:
    s = c["status"]
    if s in summary:
        summary[s] += 1

now = generated_at
data = {
    "generated_at": now,
    "mode": mode,
    "checks": checks,
    "summary": summary,
}

os.makedirs(out_dir, exist_ok=True)
os.makedirs(report_dir, exist_ok=True)

json_path = os.path.join(out_dir, "system-check.json")
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

today = datetime.date.today().isoformat()
report_path = os.path.join(report_dir, f"{today}-system-check.md")
lamp = {"ok": "OK", "warn": "WARN", "fail": "FAIL"}

lines = []
lines.append(f"# System-Check {today} ({mode})")
lines.append("")
lines.append(f"Erzeugt: {now}")
lines.append("")
lines.append(f"Zusammenfassung: {summary['ok']} OK, {summary['warn']} WARN, {summary['fail']} FAIL")
lines.append("")
lines.append("| Status | ID | Name | Detail |")
lines.append("|---|---|---|---|")
for c in checks:
    detail_cell = c["detail"].replace("|", "/")
    lines.append(f"| {lamp.get(c['status'], c['status'].upper())} | {c['id']} | {c['name']} | {detail_cell} |")
lines.append("")

problems = [c for c in checks if c["status"] != "ok"]
if problems:
    lines.append("## Fix-Sektion (WARN/FAIL)")
    lines.append("")
    for c in problems:
        lines.append(f"### {lamp.get(c['status'], c['status'].upper())}: {c['name']} ({c['id']})")
        lines.append("")
        lines.append(c["detail"])
        lines.append("")
        if c["fix"]:
            lines.append(f"Fix: `{c['fix']}`")
        lines.append("")
else:
    lines.append("Keine offenen Befunde.")
    lines.append("")

with open(report_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
    f.write("\n")

print(f"JSON: {json_path}")
print(f"Report: {report_path}")
print(f"Summary: ok={summary['ok']} warn={summary['warn']} fail={summary['fail']}")
PYEOF
rc=$?

# Haertung gegen den Fail-Open-Fall (siehe python-bin.sh): stuerzt dieser
# letzte Python-Aufruf ab (z.B. Schreibfehler, kaputte ROWS_FILE-Zeile),
# durfte check.sh bisher trotzdem mit "exit 0" enden, obwohl system-check.json
# nicht (oder nicht frisch) geschrieben wurde. Jetzt wird das sichtbar.
verify_json_output "$rc" "$OUTPUT_DIR/system-check.json" "check-collector" "$GENERATED_AT" || exit 1

exit 0
