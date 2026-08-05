// aios-statusline.js
//
// Eigene, GSD-freie Statusleiste fuer Claude Code. Rendert eine schlanke Zeile
//   {Modell} │ {Ordner} │ {Kontext-Balken} │ {⊞ AIOS Dashboard-Button}
// Nur Node-Builtins (fs/path/os), keine externen Pakete.
//
// Wird als statusLine.command verdrahtet (via noderun.sh). Claude Code fuettert
// per stdin ein JSON (model, workspace, context_window). Die stdout-Zeile ist die
// Statusleiste.
//
// Kontext-Balken-Mathematik uebernommen aus der frueheren GSD-Statusline (nur der
// generische Teil). Dashboard-Button (OSC-8-Hyperlink, frisch gelesenes Token)
// portiert aus natehbt/aios-dashboard-button.
//
// Grundsatz: ein Fehler hier darf die Statusleiste nie zerstoeren. Jeder
// Zweifelsfall endet mit einer Zeile ohne Button (oder leer).

const fs = require('fs');
const path = require('path');
const os = require('os');

// --- Dashboard-Button-Konfiguration (feste Pfade, Standard-Setup) ------------
const DASH_URL = 'http://127.0.0.1:4747/';
const TOKEN_FILE = path.join(os.homedir(), '.claude', 'dashboard', '.token');
const PID_FILE = path.join(os.homedir(), '.claude', 'dashboard', '.pid');
const BTN_TEXT = ' ⊞ AIOS ';
const BTN_BG = '48;2;255;138;71';      // helleres, weiches Brand-Orange (ein Ton)
const BTN_FG = '38;2;255;255;255';     // Weiss

// Laeuft der Dashboard-Server? Nur dann ist ein Link sinnvoll.
function serverRunning() {
  try {
    const pid = fs.readFileSync(PID_FILE, 'utf8').trim();
    if (!pid) return false;
    process.kill(Number(pid), 0); // Signal 0: existiert der Prozess? wirft sonst.
    return true;
  } catch (e) {
    return false;
  }
}

// Adresse mit frisch gelesenem Token. Token rotiert bei jedem Server-Start,
// deshalb bei JEDEM Render neu lesen. Wird nur gelesen, nie geschrieben/geloggt.
function buildLink() {
  try {
    const token = fs.readFileSync(TOKEN_FILE, 'utf8').trim();
    if (!token) return null;
    return `${DASH_URL}?t=${token}`;
  } catch (e) {
    return null;
  }
}

// OSC-8-Hyperlink: der sichtbare Text wird klickbar, die Adresse samt Token
// bleibt in der Escape-Sequenz (landet im Terminal-Scrollback, siehe
// dashboard/README.md). \x1b]8;;URL\x1b\\ oeffnet, \x1b]8;;\x1b\\ schliesst.
// \x1b[24m schaltet Unterstreichung ab. Ein einziger, weicher Orange-Ton.
function buildButton() {
  if (!serverRunning()) return null;
  const link = buildLink();
  if (!link) return null;
  return `\x1b]8;;${link}\x1b\\` +
    `\x1b[24m\x1b[${BTN_BG}m\x1b[${BTN_FG}m${BTN_TEXT}\x1b[0m` +
    `\x1b]8;;\x1b\\`;
}

// --- Kontext-Balken -----------------------------------------------------------
// Claude Code reserviert einen Puffer fuer Auto-Compact (Default ~16.5% des
// Fensters, per CLAUDE_CODE_AUTO_COMPACT_WINDOW als Token-Zahl ueberschreibbar).
// Wir skalieren die verbleibenden Prozent auf den nutzbaren Bereich, damit der
// Balken die effektive Auslastung zeigt.
function buildContextBar(data) {
  const remaining = data.context_window && data.context_window.remaining_percentage;
  if (remaining == null) return '';
  const totalCtx = (data.context_window && data.context_window.total_tokens) || 1000000;
  const acw = parseInt(process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW || '0', 10);
  const bufferPct = acw > 0 ? Math.min(100, (acw / totalCtx) * 100) : 16.5;

  const usableRemaining = Math.max(0, ((remaining - bufferPct) / (100 - bufferPct)) * 100);
  const used = Math.max(0, Math.min(100, Math.round(100 - usableRemaining)));

  const filled = Math.floor(used / 10);
  const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);

  if (used < 50) return ` \x1b[32m${bar} ${used}%\x1b[0m`;
  if (used < 65) return ` \x1b[33m${bar} ${used}%\x1b[0m`;
  if (used < 80) return ` \x1b[38;5;208m${bar} ${used}%\x1b[0m`;
  return ` \x1b[5;31m💀 ${bar} ${used}%\x1b[0m`;
}

// --- Zeile bauen --------------------------------------------------------------
function renderLine(data) {
  const model = (data.model && data.model.display_name) || 'Claude';
  const dir = (data.workspace && data.workspace.current_dir) || process.cwd();
  const dirname = path.basename(dir);
  const ctx = buildContextBar(data);

  let line = `\x1b[2m${model}\x1b[0m \x1b[2m│\x1b[0m \x1b[2m${dirname}\x1b[0m${ctx}`;

  const button = buildButton();
  if (button) line += ` \x1b[2m│\x1b[0m ${button}`;

  return line;
}

// --- stdin --------------------------------------------------------------------
function run() {
  let input = '';
  // Timeout-Guard: schliesst stdin nicht innerhalb 3s (Pipe-Probleme), still raus.
  const stdinTimeout = setTimeout(() => process.exit(0), 3000);
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { input += chunk; });
  process.stdin.on('end', () => {
    clearTimeout(stdinTimeout);
    try {
      const data = JSON.parse(input);
      process.stdout.write(renderLine(data));
    } catch (e) {
      // Silent fail: Statusleiste nie bei Parse-Fehler brechen.
    }
  });
}

module.exports = { renderLine, buildContextBar, buildButton };

if (require.main === module) run();
