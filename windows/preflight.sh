#!/usr/bin/env bash
# =============================================================================
# preflight.sh — AI Operating System: Pre-Flight-Check (Windows/Git Bash)
# =============================================================================
# Read-only check. Aendert NICHTS auf der Festplatte.
#
# Zweck: Bevor du bootstrap.sh ausfuehrst — pruefe ob alle Voraussetzungen
# erfuellt sind. Fehlt etwas? Du bekommst die exakten Fix-Commands (winget)
# in der richtigen Reihenfolge.
#
# Ausfuehrung (in Git Bash):
#   bash windows/preflight.sh
#
# Exit codes:
#   0 = alles ready, du kannst bootstrap.sh starten
#   1 = es fehlt was, schau in den Output (Fix-Commands sind dort)
# =============================================================================

export MSYS_NO_PATHCONV=1
set -uo pipefail

# --- Color output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
miss() { echo -e "${RED}✗${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
hint() { echo -e "  ${CYAN}→${NC} $*"; }
hdr()  { echo -e "${BOLD}$*${NC}"; }

# --- Counters ---
MISSING=0
WARNINGS=0

# LOCALAPPDATA ist in Git Bash gesetzt, aber im Windows-Format mit Backslashes
# ("C:\Users\...\AppData\Local"). Damit laesst sich in Bash kein Pfad bauen:
# "$LOCALAPPDATA/ms-playwright" existiert nie, egal ob installiert ist oder
# nicht. Beide Checks weiter unten meldeten deshalb dauerhaft falsch-negativ.
LOCALAPPDATA_UNIX="${LOCALAPPDATA:-}"
if [ -n "$LOCALAPPDATA_UNIX" ] && command -v cygpath >/dev/null 2>&1; then
  LOCALAPPDATA_UNIX="$(cygpath -u "$LOCALAPPDATA_UNIX" 2>/dev/null || printf '%s' "$LOCALAPPDATA_UNIX")"
fi
# Fallback, falls die Variable ganz fehlt
[ -z "$LOCALAPPDATA_UNIX" ] && LOCALAPPDATA_UNIX="$HOME/AppData/Local"

# =============================================================================
# OS-Gate: nur Git Bash (MSYS/MINGW) auf Windows
# =============================================================================
uname_s="$(uname -s 2>/dev/null || echo unknown)"
case "$uname_s" in
  MINGW*|MSYS*) ;;
  *)
    echo ""
    miss "Dieses Skript ist fuer Windows (Git Bash)."
    hint "Auf dem Mac: bash mac/preflight.sh"
    exit 1
    ;;
esac

# =============================================================================
# Header
# =============================================================================
echo ""
echo "================================================"
echo "  AI Operating System — Pre-Flight-Check (Windows)"
echo "================================================"
echo ""
echo "Pruefe Voraussetzungen (read-only, aendert nichts)..."
echo ""

# =============================================================================
# 1. Windows-11-Build
# =============================================================================
hdr "Windows-Version"
build="$(powershell.exe -NoProfile -Command '[System.Environment]::OSVersion.Version.Build' 2>/dev/null | tr -d '\r')"
if [ -z "$build" ]; then
  warn "Windows-Build konnte nicht ermittelt werden (powershell.exe nicht erreichbar?)."
  WARNINGS=$((WARNINGS + 1))
elif [ "$build" -lt 22621 ] 2>/dev/null; then
  miss "Windows-Build $build — zu alt (mindestens 22621 / 22H2 noetig)."
  hint "Windows-Update ausfuehren: Einstellungen > Windows Update > Nach Updates suchen"
  MISSING=$((MISSING + 1))
else
  ok "Windows-Build $build"
fi
echo ""

# =============================================================================
# 2. Git for Windows
# =============================================================================
hdr "Git for Windows"
if command -v git &>/dev/null; then
  ok "git $(git --version | cut -d' ' -f3)"
else
  miss "git fehlt."
  hint "Install: winget install --id Git.Git --accept-source-agreements --accept-package-agreements"
  MISSING=$((MISSING + 1))
fi
echo ""

# =============================================================================
# 3. bash.exe-Vollpfad (wird spaeter von bootstrap in settings.json geschrieben)
# =============================================================================
hdr "Git Bash Pfad"
bash_path="$(command -v bash 2>/dev/null || true)"
if [ -n "$bash_path" ]; then
  bash_win_path="$(cygpath -m "$bash_path" 2>/dev/null || echo "$bash_path")"
  ok "bash.exe gefunden: $bash_win_path"
else
  warn "bash.exe-Pfad konnte nicht ermittelt werden."
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 4. powershell.exe im PATH von Git Bash
# =============================================================================
hdr "powershell.exe (fuer Claude-Hooks)"
if command -v powershell.exe &>/dev/null; then
  ok "powershell.exe im PATH"
else
  warn "powershell.exe nicht im PATH von Git Bash gefunden."
  hint "Claude-Hooks koennen sonst haengen bleiben."
  hint "Fix: C:\\Windows\\System32\\WindowsPowerShell\\v1.0 zum PATH hinzufuegen"
  hint "(Einstellungen > System > Erweiterte Systemeinstellungen > Umgebungsvariablen)"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 5. Claude Code
# =============================================================================
hdr "Claude Code"
CLAUDE_BIN=""
if command -v claude &>/dev/null; then
  CLAUDE_BIN="$(command -v claude)"
elif command -v claude.exe &>/dev/null; then
  CLAUDE_BIN="$(command -v claude.exe)"
elif [ -x "$USERPROFILE/.local/bin/claude" ]; then
  CLAUDE_BIN="$USERPROFILE/.local/bin/claude"
fi

if [ -n "$CLAUDE_BIN" ]; then
  claude_ver="$(claude --version 2>/dev/null | head -1 | awk '{print $1}')"
  ok "claude $claude_ver ($CLAUDE_BIN)"
  # grober Versionsvergleich gegen 2.1.214 (alte Windows-Encoding-Bugs)
  if [ -n "$claude_ver" ]; then
    min_ver="2.1.214"
    lower="$(printf '%s\n%s\n' "$claude_ver" "$min_ver" | sort -V | head -1)"
    if [ "$lower" != "$min_ver" ] && [ "$claude_ver" != "$min_ver" ]; then
      warn "claude $claude_ver ist aelter als 2.1.214 (bekannte Windows-Encoding-Bugs)."
      hint "Fix: claude update"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
else
  miss "Claude Code fehlt."
  hint "Install: winget install --id Anthropic.ClaudeCode --accept-source-agreements --accept-package-agreements"
  MISSING=$((MISSING + 1))
fi
echo ""

# =============================================================================
# 6. Node.js
# =============================================================================
hdr "Node.js (fuer Statusline + Dashboard + Playwright)"
if command -v node &>/dev/null; then
  ok "node $(node --version 2>/dev/null) / npm $(npm --version 2>/dev/null)"
else
  warn "Node fehlt."
  hint "Install: winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 7. Python (Resolver-Kette: python3 -> python -> py -3)
# =============================================================================
hdr "Python"
python_found=""
for cand in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $cand -c "import sys" </dev/null &>/dev/null; then
    python_found="$cand"
    break
  fi
done

if [ -n "$python_found" ]; then
  # shellcheck disable=SC2086
  py_ver="$($python_found --version 2>&1)"
  ok "Python gefunden ueber '$python_found' — $py_ver"
else
  miss "Kein funktionierender Python-Interpreter gefunden."
  hint "Install: winget install --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements"
  hint "Falls 'python'/'python3' trotzdem in den Microsoft Store springt:"
  hint "Einstellungen > Apps > Erweiterte App-Einstellungen > App-Ausfuehrungsaliase"
  hint "python.exe und python3.exe dort AUS schalten."
  MISSING=$((MISSING + 1))
fi
echo ""

# =============================================================================
# 8. Benutzername / HOME-Pfad (Leerzeichen, Nicht-ASCII)
# =============================================================================
hdr "Benutzerprofil-Pfad"
home_path="${USERPROFILE:-${HOME:-}}"
if [ -n "$home_path" ]; then
  path_flagged=0
  if [[ "$home_path" =~ [[:space:]] ]] || LC_ALL=C grep -qP '[^\x00-\x7F]' <<< "$home_path" 2>/dev/null; then
    warn "Profil-Pfad enthaelt Leerzeichen oder Nicht-ASCII-Zeichen: $home_path"
    hint "npm/Node-Tooling bricht bei manchen Paketen auf solchen Pfaden."
    WARNINGS=$((WARNINGS + 1))
    path_flagged=1
  fi
  if [[ "$home_path" == *[\(\)\[\]\{\}\$\&\;\'\"\`\!]* ]]; then
    warn "Profil-Pfad enthaelt Shell-Sonderzeichen: $home_path"
    hint "npm/Node-Tooling kann auf solchen Pfaden brechen (Klammern, \$, & und aehnliche)."
    WARNINGS=$((WARNINGS + 1))
    path_flagged=1
  fi
  if [ "$path_flagged" = "0" ]; then
    ok "Profil-Pfad unauffaellig: $home_path"
  fi
else
  warn "USERPROFILE/HOME nicht gesetzt."
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 9. Controlled Folder Access (Windows Defender)
# =============================================================================
hdr "Controlled Folder Access"
cfa="$(powershell.exe -NoProfile -Command '(Get-MpPreference).EnableControlledFolderAccess' 2>/dev/null | tr -d '\r')"
if [ -z "$cfa" ]; then
  : # keine Rechte oder Abfrage fehlgeschlagen -> still ueberspringen
elif [ "$cfa" = "0" ]; then
  ok "Controlled Folder Access aus"
else
  warn "Controlled Folder Access aktiv — Schreibzugriffe in Dokumente koennen stumm geblockt werden."
  hint "Git Bash, Node und Obsidian als erlaubte Apps eintragen:"
  hint "Windows-Sicherheit > Viren- und Bedrohungsschutz > Ransomware-Schutz > Kontrollierten Ordnerzugriff verwalten"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 10. OneDrive-Documents-Redirect
# =============================================================================
hdr "Dokumente-Ordner (OneDrive-Redirect?)"
docs_path="$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('MyDocuments')" 2>/dev/null | tr -d '\r')"
if [[ "$docs_path" == *OneDrive* ]]; then
  warn "Dokumente-Ordner zeigt auf OneDrive: $docs_path"
  hint "Der Second-Brain-Vault liegt trotzdem fest unter C:\\Users\\<Name>\\Documents\\Second-Brain"
  hint "(physischer Pfad). In Obsidian genau diesen Pfad oeffnen, nicht den OneDrive-Knoten."
else
  ok "Dokumente-Ordner: ${docs_path:-unbekannt}"
fi
echo ""

# =============================================================================
# 11. Playwright-Browser-Cache
# =============================================================================
hdr "Playwright-Browser-Cache"
if [ -d "$LOCALAPPDATA_UNIX/ms-playwright" ]; then
  ok "Chromium-Cache gefunden ($LOCALAPPDATA_UNIX/ms-playwright)"
else
  warn "Playwright-Browser-Cache noch nicht vorhanden — bootstrap.sh installiert ihn automatisch."
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 12. Obsidian
# =============================================================================
hdr "Obsidian"
if [ -d "$LOCALAPPDATA_UNIX/Programs/Obsidian" ] || [ -d "$LOCALAPPDATA_UNIX/Obsidian" ] || [ -d "/c/Program Files/Obsidian" ]; then
  ok "Obsidian installiert"
else
  warn "Obsidian nicht gefunden."
  hint "Install: winget install --id Obsidian.Obsidian --accept-source-agreements --accept-package-agreements"
  hint "Kein Blocker fuer bootstrap.sh — kann nach dem Bootstrap nachinstalliert werden."
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "================================================"
if [ "$MISSING" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  Alles bereit. Weiter mit: bash windows/bootstrap.sh --dry-run${NC}"
  echo "================================================"
  exit 0
elif [ "$MISSING" -eq 0 ]; then
  echo -e "${YELLOW}${BOLD}  $WARNINGS Warning(s) — du kannst bootstrap.sh starten,${NC}"
  echo -e "${YELLOW}${BOLD}  aber empfohlene Komponenten fehlen (siehe oben).${NC}"
  echo "================================================"
  echo ""
  echo "Empfehlung: Warnings beheben, dann nochmal preflight, dann bootstrap."
  echo "Oder direkt weiter: bash windows/bootstrap.sh"
  exit 0
else
  echo -e "${RED}${BOLD}  $MISSING fehlende Voraussetzung(en) + $WARNINGS Warning(s)${NC}"
  echo -e "${RED}${BOLD}  bootstrap.sh wird ohne diese Komponenten nicht durchlaufen.${NC}"
  echo "================================================"
  echo ""
  echo "Naechster Schritt: Fix-Commands oben in der Reihenfolge ausfuehren,"
  echo "danach 'bash windows/preflight.sh' nochmal — bis alle Checks gruen sind."
  exit 1
fi
