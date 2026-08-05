#!/usr/bin/env bash
# =============================================================================
# preflight.sh — AI Operating System: Pre-Flight-Check
# =============================================================================
# Read-only check. Aendert NICHTS auf der Festplatte.
#
# Zweck: Bevor du bootstrap.sh ausfuehrst — pruefe ob alle Voraussetzungen
# erfuellt sind. Fehlt etwas? Du bekommst die exakten Install-Commands in
# der richtigen Reihenfolge.
#
# Ausfuehrung:
#   bash preflight.sh
#
# Exit codes:
#   0 = alles ready, du kannst bootstrap.sh starten
#   1 = es fehlt was, schau in den Output (Install-Commands sind dort)
# =============================================================================

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

# --- Detect active shell config file (for PATH-Fix-Hints) ---
detect_shell_rc() {
  case "${SHELL:-}" in
    */zsh)  echo "$HOME/.zshrc" ;;
    */bash) echo "$HOME/.bashrc" ;;
    *)      echo "$HOME/.zshrc" ;;  # default fallback for macOS
  esac
}

SHELL_RC="$(detect_shell_rc)"

# =============================================================================
# Header
# =============================================================================
echo ""
echo "================================================"
echo "  AI Operating System — Pre-Flight-Check"
echo "================================================"
echo ""
echo "Pruefe Voraussetzungen (read-only, aendert nichts)..."
echo ""

# =============================================================================
# 1. macOS Version
# =============================================================================
hdr "Betriebssystem"
if [[ "$(uname)" != "Darwin" ]]; then
  miss "Kein macOS — dieser Setup laeuft nur auf macOS."
  hint "Linux/Windows: Workshop-TN-Hinweis abwarten."
  MISSING=$((MISSING + 1))
else
  os_full="$(sw_vers -productVersion)"
  os_major="$(echo "$os_full" | cut -d. -f1)"
  if [ "$os_major" -lt 13 ]; then
    miss "macOS $os_full — zu alt (mindestens 13/Ventura noetig)."
    hint "macOS-Update via Apple-Menu → Systemeinstellungen → Allgemein → Softwareupdate"
    MISSING=$((MISSING + 1))
  elif [ "$os_major" -eq 13 ]; then
    warn "macOS $os_full — laeuft, aber 14+ empfohlen (Homebrew warnt bei 13)."
    WARNINGS=$((WARNINGS + 1))
  else
    ok "macOS $os_full"
  fi
fi
echo ""

# =============================================================================
# 2. Shell (zsh empfohlen)
# =============================================================================
hdr "Shell"
current_shell="${SHELL:-unknown}"
if [[ "$current_shell" == */zsh ]]; then
  ok "zsh aktiv ($current_shell)"
else
  warn "Aktive Shell: $current_shell — zsh empfohlen (macOS-Default seit Catalina)."
  hint "Auf zsh wechseln: chsh -s /bin/zsh"
  hint "Danach Terminal komplett zumachen + neu oeffnen, dann preflight nochmal."
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 3. git
# =============================================================================
hdr "git"
if command -v git &>/dev/null; then
  ok "git $(git --version | cut -d' ' -f3)"
else
  miss "git fehlt."
  hint "Install: xcode-select --install"
  hint "Dauert 5-15 min. Danach preflight nochmal laufen lassen."
  MISSING=$((MISSING + 1))
fi
echo ""

# =============================================================================
# 4. Claude Code Binary
# =============================================================================
hdr "Claude Code"
# PATH wird oft erst nach Shell-Restart aktualisiert.
# Daher zusaetzlich nach Binary-File suchen.
CLAUDE_BIN=""
if command -v claude &>/dev/null; then
  CLAUDE_BIN="$(command -v claude)"
elif [ -x "$HOME/.local/bin/claude" ]; then
  CLAUDE_BIN="$HOME/.local/bin/claude"
elif [ -x "$HOME/.claude/local/claude" ]; then
  CLAUDE_BIN="$HOME/.claude/local/claude"
fi

if [ -n "$CLAUDE_BIN" ]; then
  if command -v claude &>/dev/null; then
    ok "claude $(claude --version 2>/dev/null | head -1 | awk '{print $1}') — im PATH"
  else
    warn "Claude Code installiert ($CLAUDE_BIN) — aber NICHT im PATH."
    bin_dir="$(dirname "$CLAUDE_BIN")"
    hint "PATH-Fix fuer aktive Shell ($SHELL_RC):"
    hint "  echo 'export PATH=\"$bin_dir:\$PATH\"' >> $SHELL_RC && source $SHELL_RC"
    hint "Danach: claude --version"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  miss "Claude Code fehlt."
  hint "Install: curl -fsSL https://claude.ai/install.sh | bash"
  hint "Dauert ~30 sec. WICHTIG: nach Install den PATH-Fix oben anwenden,"
  hint "weil der Anthropic-Installer ~/.bashrc adressiert auch wenn du zsh nutzt."
  MISSING=$((MISSING + 1))
fi
echo ""

# =============================================================================
# 5. Homebrew (optional, fuer Node noetig)
# =============================================================================
hdr "Homebrew (optional, fuer Node-Install benoetigt)"
# Source brew shellenv if present (covers Apple Silicon + Intel)
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
[ -x /usr/local/bin/brew ] && eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null

if command -v brew &>/dev/null; then
  ok "brew $(brew --version | head -1 | cut -d' ' -f2)"
else
  warn "Homebrew fehlt (nur noetig wenn Node nicht ueber andere Quelle kommt)."
  hint "Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  hint "Danach (Apple Silicon): echo 'eval \"\$(/opt/homebrew/bin/brew shellenv)\"' >> $SHELL_RC && source $SHELL_RC"
  hint "Danach (Intel-Mac):     echo 'eval \"\$(/usr/local/bin/brew shellenv)\"' >> $SHELL_RC && source $SHELL_RC"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 6. Node / npm (fuer Statusline, Dashboard, Playwright, Skill-Deps)
# =============================================================================
hdr "Node.js / npx (fuer Statusline + Dashboard + Playwright)"
if command -v npx &>/dev/null; then
  ok "node $(node --version 2>/dev/null) / npm $(npm --version 2>/dev/null)"
else
  warn "Node/npx fehlt. Statusline, Dashboard und Playwright brauchen Node."
  if command -v brew &>/dev/null; then
    hint "Install via Homebrew: brew install node"
  else
    hint "Erst Homebrew installieren (siehe oben), dann: brew install node"
  fi
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 7. playwright-cli (optional, fuer Browser-Automation + HTML/PDF-Pipeline)
# =============================================================================
hdr "playwright-cli (optional, fuer Browser-Automation + HTML/PDF)"
if command -v playwright-cli &>/dev/null; then
  pw_ver="$(playwright-cli --version 2>/dev/null | head -1 || echo 'unknown')"
  ok "playwright-cli $pw_ver"
  # Check Chromium binary present
  if [ -d "$HOME/Library/Caches/ms-playwright" ] || [ -d "$HOME/.cache/ms-playwright" ]; then
    ok "Chromium-Binary gefunden (Browser-Cache)"
  else
    warn "Chromium-Binary fehlt — bootstrap.sh installiert es automatisch."
    hint "Manueller Install: npx playwright install chromium"
    WARNINGS=$((WARNINGS + 1))
  fi
else
  warn "playwright-cli fehlt — bootstrap.sh installiert es automatisch (npm-basiert)."
  hint "Manueller Install: npm i -g @playwright/cli@latest && npx playwright install chromium"
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# 8. Obsidian (optional — separate GUI-Install)
# =============================================================================
hdr "Obsidian"
if [ -d "/Applications/Obsidian.app" ]; then
  ok "Obsidian.app installiert"
else
  warn "Obsidian.app nicht in /Applications gefunden."
  hint "Download: https://obsidian.md (kostenlos, kein Account noetig)"
  hint "Kein Blocker fuer bootstrap.sh — kann nach dem Bootstrap nachinstalliert werden."
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "================================================"
if [ "$MISSING" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  Alles bereit. Du kannst jetzt bootstrap.sh starten.${NC}"
  echo "================================================"
  echo ""
  echo "Naechster Schritt:"
  echo "  bash bootstrap.sh --dry-run    # Vorschau"
  echo "  bash bootstrap.sh              # Echter Run"
  exit 0
elif [ "$MISSING" -eq 0 ]; then
  echo -e "${YELLOW}${BOLD}  $WARNINGS Warning(s) — du kannst bootstrap.sh starten,${NC}"
  echo -e "${YELLOW}${BOLD}  aber empfohlene Komponenten fehlen (siehe oben).${NC}"
  echo "================================================"
  echo ""
  echo "Empfehlung: Warnings beheben, dann nochmal preflight, dann bootstrap."
  echo "Oder direkt weiter: bash bootstrap.sh"
  exit 0
else
  echo -e "${RED}${BOLD}  $MISSING fehlende Voraussetzung(en) + $WARNINGS Warning(s)${NC}"
  echo -e "${RED}${BOLD}  bootstrap.sh wird ohne diese Komponenten nicht durchlaufen.${NC}"
  echo "================================================"
  echo ""
  echo "Naechster Schritt: Install-Commands oben in der Reihenfolge ausfuehren,"
  echo "danach 'bash preflight.sh' nochmal — bis alle Checks gruen sind."
  exit 1
fi
