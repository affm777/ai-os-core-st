#!/usr/bin/env node
// server.mjs — AIOS-Dashboard, Stufe 1 (read-only). NUR Node-Built-ins, kein npm install.
// Bindet ausschliesslich 127.0.0.1:4747. Token-Pflicht auf jeder Route, Origin-Check,
// statisches Ausliefern nur aus public/ mit Pfad-Traversal-Schutz.

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFile } from 'node:child_process';
import os from 'node:os';

const HOST = '127.0.0.1';
const PORT = 4747;
const DASH_DIR = path.join(os.homedir(), '.claude', 'dashboard');
const PUBLIC_DIR = path.join(DASH_DIR, 'public');
const DATA_DIR = path.join(DASH_DIR, 'data');
const COLLECTORS_DIR = path.join(DASH_DIR, 'collectors');
const TOKEN_FILE = path.join(DASH_DIR, '.token');
const PID_FILE = path.join(DASH_DIR, '.pid');
const LOG_FILE = path.join(DASH_DIR, 'server.log');
const CONFIG_FILE = path.join(DASH_DIR, 'config.json');

const ALLOWED_ORIGINS = new Set([
  `http://127.0.0.1:${PORT}`,
  `http://localhost:${PORT}`,
]);

const STALE_MS = 12 * 60 * 60 * 1000; // 12h

// Bash-Binary aufloesen: unter Windows gibt es kein System-'bash' im PATH,
// Git Bash bringt eines mit. Reihenfolge: expliziter Override (AIOS_BASH) →
// Claude-Code-eigene Env-Var (falls gesetzt) → Windows-Default-Pfad von
// Git for Windows (nur wenn er existiert) → 'bash' (macOS/Linux, sowie
// Windows-Fallback falls Git woanders liegt und im PATH ist).
// Auf macOS ohne gesetzte Env-Vars liefert das exakt 'bash' wie bisher.
function resolveBash() {
  if (process.env.AIOS_BASH) return process.env.AIOS_BASH;
  if (process.env.CLAUDE_CODE_GIT_BASH_PATH) return process.env.CLAUDE_CODE_GIT_BASH_PATH;
  if (process.platform === 'win32') {
    const gitBash = 'C:/Program Files/Git/bin/bash.exe';
    try {
      if (fs.existsSync(gitBash)) return gitBash;
    } catch {
      // ignore, fall through to 'bash'
    }
  }
  return 'bash';
}
const BASH_BIN = resolveBash();

// Log-Datei wie die Token-Datei auf 600 beschraenken: appendFileSync uebernimmt
// sonst den Prozess-umask (meist 644) und macht das Log fuer jeden Nutzer der
// Maschine lesbar. Das Token darf dort ohnehin nie hineingeraten (siehe unten),
// aber 600 ist die konsistente Grundabsicherung.
// Auf NTFS (Windows) ist 0o600 wirkungslos, dort greift stattdessen die
// Benutzerprofil-ACL (nur der angemeldete User hat Zugriff auf %USERPROFILE%).
function ensureLogFile() {
  try {
    if (!fs.existsSync(LOG_FILE)) fs.writeFileSync(LOG_FILE, '', { mode: 0o600 });
    fs.chmodSync(LOG_FILE, 0o600);
  } catch {
    // ignore, log() faengt Schreibfehler ohnehin ab
  }
}
ensureLogFile();

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}\n`;
  try {
    fs.appendFileSync(LOG_FILE, line);
  } catch {
    // ignore log write failures, never crash on logging
  }
}

// --- Token-Setup ---
function ensureToken() {
  const token = crypto.randomBytes(24).toString('hex');
  // Auf NTFS (Windows) ist 0o600 wirkungslos, dort schuetzt stattdessen die
  // Benutzerprofil-ACL (nur der angemeldete User hat Zugriff auf %USERPROFILE%).
  fs.writeFileSync(TOKEN_FILE, token, { mode: 0o600 });
  fs.chmodSync(TOKEN_FILE, 0o600);
  return token;
}

const SERVER_TOKEN = ensureToken();
// Auf NTFS (Windows) ist 0o600 wirkungslos, dort schuetzt stattdessen die
// Benutzerprofil-ACL.
fs.writeFileSync(PID_FILE, String(process.pid), { mode: 0o600 });

function cleanupOnExit() {
  try { fs.unlinkSync(PID_FILE); } catch {}
}
process.on('SIGINT', () => { cleanupOnExit(); process.exit(0); });
process.on('SIGTERM', () => { cleanupOnExit(); process.exit(0); });

// --- Auth ---
function parseCookies(req) {
  const header = req.headers.cookie || '';
  const out = {};
  header.split(';').forEach((part) => {
    const idx = part.indexOf('=');
    if (idx === -1) return;
    const k = part.slice(0, idx).trim();
    const v = part.slice(idx + 1).trim();
    if (k) out[k] = decodeURIComponent(v);
  });
  return out;
}

function isOriginAllowed(req) {
  const origin = req.headers.origin;
  const referer = req.headers.referer;
  if (!origin && !referer) return true; // direkte Navigation / curl ohne Header
  if (origin && ALLOWED_ORIGINS.has(origin.replace(/\/$/, ''))) return true;
  if (referer) {
    try {
      const u = new URL(referer);
      if (ALLOWED_ORIGINS.has(`${u.protocol}//${u.host}`)) return true;
    } catch {
      return false;
    }
  }
  return false;
}

function checkToken(req, url) {
  const queryToken = url.searchParams.get('t');
  if (queryToken && queryToken === SERVER_TOKEN) return true;
  const cookies = parseCookies(req);
  if (cookies.aios_token && cookies.aios_token === SERVER_TOKEN) return true;
  return false;
}

function forbidden(res, msg = 'Forbidden') {
  res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end(msg);
}

function notFound(res) {
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Not found');
}

// --- Statisches Ausliefern (nur public/, realpath-Check) ---
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

function serveStatic(req, res, urlPath) {
  const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
  const requested = path.join(PUBLIC_DIR, rel);

  let realPublic, realRequestedDir;
  try {
    realPublic = fs.realpathSync(PUBLIC_DIR);
  } catch {
    return notFound(res);
  }
  // Pfad muss innerhalb von PUBLIC_DIR liegen (realpath-Check gegen Traversal/Symlinks)
  let realRequested;
  try {
    realRequested = fs.realpathSync(requested);
  } catch {
    return notFound(res);
  }
  if (realRequested !== realPublic && !realRequested.startsWith(realPublic + path.sep)) {
    log(`403 path-traversal-attempt: ${urlPath}`);
    return forbidden(res, 'Forbidden');
  }
  let stat;
  try {
    stat = fs.statSync(realRequested);
  } catch {
    return notFound(res);
  }
  if (stat.isDirectory()) {
    return notFound(res);
  }
  const ext = path.extname(realRequested).toLowerCase();
  const mime = MIME[ext] || 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': mime });
  fs.createReadStream(realRequested).pipe(res);
}

// --- Datenaggregation ---
function safeReadJson(filePath) {
  try {
    const raw = fs.readFileSync(filePath, 'utf-8');
    return { data: JSON.parse(raw), mtime: fs.statSync(filePath).mtimeMs };
  } catch {
    return null;
  }
}

function freshnessFlag(mtimeMs) {
  if (mtimeMs == null) return 'missing';
  const age = Date.now() - mtimeMs;
  return age > STALE_MS ? 'stale' : 'ok';
}

// Liest die lokale Dashboard-Config (~/.claude/dashboard/config.json), NIE im Repo.
// Bei Fehler (fehlt, kaputtes JSON) liefert sie null, damit aggregateData() den Default setzt.
function loadDashboardConfig() {
  try {
    const raw = fs.readFileSync(CONFIG_FILE, 'utf-8');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function aggregateData() {
  const sections = ['system-check', 'portfolio', 'vault-stats', 'usage', 'heute', 'recommendations', 'skills', 'automationen', 'inbox', 'meta'];
  const out = {};
  for (const section of sections) {
    const filePath = path.join(DATA_DIR, `${section}.json`);
    const loaded = safeReadJson(filePath);
    if (loaded === null) {
      out[section] = { present: false, freshness: 'missing', data: null };
    } else {
      out[section] = {
        present: true,
        freshness: freshnessFlag(loaded.mtime),
        updated_at: new Date(loaded.mtime).toISOString(),
        data: loaded.data,
      };
    }
  }
  // Manuelle Projekt-Overrides (Ruhend/Aktiv + Reihenfolge) ueber die Portfolio-Daten legen,
  // damit sie portfolio.sh-Refreshes ueberdauern (die Datei wird bei jedem Refresh neu geschrieben).
  if (out.portfolio && out.portfolio.present && out.portfolio.data && Array.isArray(out.portfolio.data.projects)) {
    const ov = loadOverrides();
    out.portfolio.data.order = ov.order;
    for (const p of out.portfolio.data.projects) {
      p.manual_status = (ov.status[p.slug] === 'aktiv' || ov.status[p.slug] === 'ruhend') ? ov.status[p.slug] : null;
    }
  }
  const cfg = loadDashboardConfig();
  out.config = cfg
    ? { present: true, data: cfg }
    : { present: false, data: { onboarding_completed: false, modules: { branding: { enabled: false }, sales: { enabled: false } } } };
  out.generated_at = new Date().toISOString();
  return out;
}

// --- Refresh-Aktion ---
let refreshRunning = false;

function runRefresh(callback) {
  if (refreshRunning) {
    callback(new Error('refresh laeuft bereits'));
    return;
  }
  refreshRunning = true;
  const script = path.join(COLLECTORS_DIR, 'refresh.sh');
  execFile(BASH_BIN, [script], { timeout: 120000 }, (err, stdout, stderr) => {
    refreshRunning = false;
    if (err) {
      log(`refresh error: ${err.message} stderr=${stderr}`);
      callback(err);
      return;
    }
    log('refresh ok');
    callback(null);
  });
}

// =====================================================================
// Stufe 2: Leichte Aktionen (Todo-Toggle/Remove/Undo, Empfehlungsstatus)
// Stufe 3: Claude-Aktions-Katalog
// =====================================================================

const REPOS_YAML = path.join(os.homedir(), '.claude', 'project-repos.yaml');
const BACKUPS_DIR = path.join(DASH_DIR, 'backups');
const ACTIONS_LOG = path.join(DASH_DIR, 'actions.log');
const ACTIONS_CATALOG_FILE = path.join(DASH_DIR, 'actions.json');
const ACTIONS_DATA_DIR = path.join(DATA_DIR, 'actions');
const CONTENT_BACKUPS_DIR = path.join(BACKUPS_DIR, 'content');
try { fs.mkdirSync(BACKUPS_DIR, { recursive: true }); } catch {}
try { fs.mkdirSync(ACTIONS_DATA_DIR, { recursive: true }); } catch {}

// --- Manuelle Projekt-Overrides (Ruhend/Aktiv + Reihenfolge) ---
// Einziges Schreibziel: dashboard/data/project-overrides.json. Beruehrt NIE eine STATE.md.
const OVERRIDES_FILE = path.join(DATA_DIR, 'project-overrides.json');

function loadOverrides() {
  try {
    const o = JSON.parse(fs.readFileSync(OVERRIDES_FILE, 'utf-8'));
    return {
      status: (o && typeof o.status === 'object' && o.status) || {},
      order: Array.isArray(o && o.order) ? o.order : [],
    };
  } catch {
    return { status: {}, order: [] };
  }
}

function saveOverrides(o) {
  const payload = { status: o.status || {}, order: o.order || [], updated_at: new Date().toISOString() };
  fs.writeFileSync(OVERRIDES_FILE, JSON.stringify(payload, null, 2), { mode: 0o600 });
}

// Bekannte Slugs ausschliesslich aus project-repos.yaml (+ Test-Projekt) — nie vom Client.
function knownSlugs() {
  const s = new Set(Object.keys(loadProjectRepos()));
  const t = getTestProject();
  if (t) s.add(t.slug);
  return s;
}

// letztes Backup je Projekt-Slug, nur solange der Server-Prozess laeuft (Undo-Mechanik)
const lastBackups = {};

function sendJson(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(obj));
}

function readJsonBody(req, maxBytes = 1024 * 1024) {
  return new Promise((resolve, reject) => {
    let data = '';
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        reject(new Error('body zu gross'));
        req.destroy();
        return;
      }
      data += chunk;
    });
    req.on('end', () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch (e) {
        reject(new Error('ungueltiges JSON'));
      }
    });
    req.on('error', reject);
  });
}

function logAction(fields) {
  const ts = new Date().toISOString();
  const line = [ts, ...fields]
    .map((f) => String(f == null ? '' : f).replace(/[\t\n\r]/g, ' '))
    .join('\t') + '\n';
  try {
    fs.appendFileSync(ACTIONS_LOG, line);
  } catch {
    // niemals auf Log-Fehlern crashen
  }
}

// --- project-repos.yaml (gleiches simples Format wie portfolio.sh) ---
function loadProjectRepos() {
  const out = {};
  let raw;
  try {
    raw = fs.readFileSync(REPOS_YAML, 'utf-8');
  } catch {
    return out;
  }
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const m = trimmed.match(/^([a-zA-Z0-9_-]+):\s*(.+)$/);
    if (m) out[m[1]] = m[2].trim();
  }
  return out;
}

function getTestProject() {
  const testDir = process.env.DASHBOARD_TEST_PROJECT;
  if (!testDir) return null;
  return { slug: 'aios-test-projekt', path: testDir };
}

function findStatePath(projectPath) {
  const candidates = [
    path.join(projectPath, '.planning', 'STATE.md'),
    path.join(projectPath, 'STATE.md'),
  ];
  return candidates.find((p) => { try { return fs.existsSync(p); } catch { return false; } }) || null;
}

function loadPortfolioEntries() {
  try {
    const raw = fs.readFileSync(path.join(DATA_DIR, 'portfolio.json'), 'utf-8');
    const parsed = JSON.parse(raw);
    return parsed.projects || [];
  } catch {
    return [];
  }
}

// Loest einen client-gelieferten Projekt-Slug ausschliesslich ueber project-repos.yaml
// (oder die Test-Variable) auf. Nimmt NIEMALS einen client-gelieferten Pfad direkt entgegen.
function resolveProjectForWrite(slug) {
  const test = getTestProject();
  if (test && slug === test.slug) {
    const statePath = findStatePath(test.path);
    if (!statePath) return { error: 'test-state-missing' };
    return { slug, projectPath: test.path, statePath, isTest: true };
  }
  const repos = loadProjectRepos();
  const projectPath = repos[slug];
  if (!projectPath) return { error: 'unknown-project' };
  const statePath = findStatePath(projectPath);
  if (!statePath) return { error: 'state-missing' };
  // Cross-Check gegen den zuletzt gesammelten Portfolio-Stand (Abschnitt 2 der Spec)
  const entries = loadPortfolioEntries();
  const entry = entries.find((e) => e.slug === slug);
  if (!entry || entry.state_path !== statePath) {
    return { error: 'portfolio-mismatch' };
  }
  return { slug, projectPath, statePath, isTest: false, entry };
}

// realpath-Allowlist: dashboard/-Verzeichnis + alle bekannten STATE.md-Pfade
// (inkl. Test-Projekt wenn gesetzt). Schuetzt gegen Symlink-Traversal.
function buildAllowlist() {
  const list = new Set();
  try { list.add(fs.realpathSync(DASH_DIR)); } catch {}
  const repos = loadProjectRepos();
  for (const slug of Object.keys(repos)) {
    const projectPath = repos[slug];
    const statePath = findStatePath(projectPath);
    if (statePath) {
      try { list.add(fs.realpathSync(statePath)); } catch {}
    }
  }
  const test = getTestProject();
  if (test) {
    const statePath = findStatePath(test.path);
    if (statePath) {
      try { list.add(fs.realpathSync(statePath)); } catch {}
    }
  }
  return list;
}

function isRealpathAllowed(targetPath, allowlist) {
  let real;
  try {
    real = fs.realpathSync(targetPath);
  } catch {
    return false;
  }
  return allowlist.has(real);
}

// --- STATE.md Struktur-Konformitaet (identische Logik zu portfolio.sh) ---
// Eine einzige Quelle fuer den Sektionskopf, geteilt von Konformitaets-Tor und
// Extraktor. Frueher forderte das Tor exakt "### Pending Todos", der Extraktor
// akzeptierte "##" und "###" — eine STATE.md mit "## Pending Todos" als eigener
// Top-Level-Sektion galt dadurch als "altes Format".
const RE_PENDING_HEADING = /^(#{2,3})\s*Pending Todos\s*$/m;

function isConform(content) {
  const reCurrentPos = /^## ?Current Position|^Current Position\s*$/m;
  const reSessionCont = /^## Session Continuity/m;
  return reCurrentPos.test(content) && RE_PENDING_HEADING.test(content) && reSessionCont.test(content);
}

// Extrahiert die Pending-Todos-Sektion als Zeichen-Offsets in `content` (absolut).
// Die Grenze richtet sich nach der Ebene des Sektionskopfes: gestoppt wird bei der
// naechsten Ueberschrift gleicher oder hoeherer Ebene, tiefere Ueberschriften sind
// Themen-Cluster und gehoeren zur Sektion. Eine fest verdrahtete Grenze wuerde bei
// einem "##"-Kopf schon an der ersten "###"-Cluster-Ueberschrift abschneiden.
function extractPendingSection(content) {
  const m = RE_PENDING_HEADING.exec(content);
  if (!m) return null;
  const level = m[1].length;
  const sectionStart = m.index + m[0].length;
  const rest = content.slice(sectionStart);
  const stopRe = new RegExp(`^#{1,${level}}\\s+\\S`, 'm');
  const stopMatch = stopRe.exec(rest);
  const sectionEnd = stopMatch ? sectionStart + stopMatch.index : content.length;
  return { sectionStart, sectionEnd };
}

// Liefert Zeilen mit absoluten Start/End-Offsets (End exklusiv, ohne \n) innerhalb `content`.
function linesWithOffsets(sectionText, baseOffset) {
  const parts = sectionText.split('\n');
  const out = [];
  let offset = baseOffset;
  for (const text of parts) {
    const start = offset;
    const end = offset + text.length;
    out.push({ text, start, end });
    offset = end + 1;
  }
  return out;
}

function lineHash(text) {
  return crypto.createHash('sha256').update(text, 'utf8').digest('hex').slice(0, 16);
}

function toggleLine(content, line) {
  const newText = line.text.replace(/\[( |x|X)\]/, (m, g1) => (g1 === ' ' ? '[x]' : '[ ]'));
  return content.slice(0, line.start) + newText + content.slice(line.end);
}

function removeLine(content, line) {
  let start = line.start;
  let end = line.end;
  if (content[end] === '\n') {
    end += 1;
  } else if (content[start - 1] === '\n') {
    start -= 1;
  }
  return content.slice(0, start) + content.slice(end);
}

function refreshPortfolioOnly() {
  return new Promise((resolve) => {
    execFile(BASH_BIN, [path.join(COLLECTORS_DIR, 'portfolio.sh')], { timeout: 30000 }, (err, stdout, stderr) => {
      if (err) log(`portfolio-refresh error: ${err.message} stderr=${stderr}`);
      resolve();
    });
  });
}

async function handleTodoMutate(req, res, mode) {
  let body;
  try {
    body = await readJsonBody(req);
  } catch (e) {
    return sendJson(res, 400, { error: 'invalid-body', detail: e.message });
  }
  const project = body.project;
  const hashParam = body.line_hash;
  if (!project || !hashParam) {
    logAction([`todo/${mode}`, project || '', hashParam || '', 'rejected', 'missing-fields']);
    return sendJson(res, 400, { error: 'missing-fields', detail: 'project und line_hash sind Pflicht.' });
  }

  const resolved = resolveProjectForWrite(project);
  if (resolved.error) {
    logAction([`todo/${mode}`, project, hashParam, 'rejected', resolved.error]);
    return sendJson(res, 404, { error: resolved.error, detail: 'Projekt/Pfad nicht auflösbar.' });
  }

  const allowlist = buildAllowlist();
  if (!isRealpathAllowed(resolved.statePath, allowlist)) {
    logAction([`todo/${mode}`, project, hashParam, 'rejected', 'not-in-allowlist']);
    return sendJson(res, 403, { error: 'not-in-allowlist', detail: 'Ziel-Pfad ausserhalb der Allowlist.' });
  }

  let content;
  try {
    content = fs.readFileSync(resolved.statePath, 'utf-8');
  } catch (e) {
    logAction([`todo/${mode}`, project, hashParam, 'rejected', 'read-failed']);
    return sendJson(res, 500, { error: 'read-failed', detail: e.message });
  }

  if (!isConform(content)) {
    logAction([`todo/${mode}`, project, hashParam, 'rejected', 'not-template-conform']);
    return sendJson(res, 409, { error: 'not-template-conform', detail: 'STATE.md ist nicht Template-konform, Bearbeitung abgelehnt.' });
  }

  const section = extractPendingSection(content);
  if (!section) {
    logAction([`todo/${mode}`, project, hashParam, 'rejected', 'no-pending-section']);
    return sendJson(res, 404, { error: 'no-pending-section', detail: 'Keine ### Pending Todos Sektion gefunden.' });
  }

  const sectionText = content.slice(section.sectionStart, section.sectionEnd);
  const lines = linesWithOffsets(sectionText, section.sectionStart);
  const checkboxRe = /^\s*-\s\[( |x|X)\]\s+(.*)$/;
  let target = null;
  for (const line of lines) {
    if (!checkboxRe.test(line.text)) continue;
    if (lineHash(line.text) === hashParam) {
      target = line;
      break;
    }
  }
  if (!target) {
    logAction([`todo/${mode}`, project, hashParam, 'rejected', 'hash-not-found']);
    return sendJson(res, 404, { error: 'hash-not-found', detail: 'Zeile mit diesem Hash nicht in der Pending-Todos-Sektion gefunden.' });
  }

  const backupPath = path.join(BACKUPS_DIR, `${resolved.slug}-STATE.md.${Date.now()}`);
  try {
    fs.copyFileSync(resolved.statePath, backupPath);
  } catch (e) {
    logAction([`todo/${mode}`, project, hashParam, 'rejected', 'backup-failed']);
    return sendJson(res, 500, { error: 'backup-failed', detail: e.message });
  }
  lastBackups[resolved.slug] = backupPath;

  const newContent = mode === 'toggle' ? toggleLine(content, target) : removeLine(content, target);
  try {
    fs.writeFileSync(resolved.statePath, newContent, 'utf-8');
  } catch (e) {
    logAction([`todo/${mode}`, project, hashParam, 'error', 'write-failed']);
    return sendJson(res, 500, { error: 'write-failed', detail: e.message });
  }

  logAction([`todo/${mode}`, project, hashParam, 'ok', `backup=${backupPath}`]);
  await refreshPortfolioOnly();
  return sendJson(res, 200, aggregateData());
}

async function handleTodoUndo(req, res) {
  let body;
  try {
    body = await readJsonBody(req);
  } catch (e) {
    return sendJson(res, 400, { error: 'invalid-body', detail: e.message });
  }
  const project = body.project;
  if (!project) {
    logAction(['todo/undo', '', '', 'rejected', 'missing-project']);
    return sendJson(res, 400, { error: 'missing-project' });
  }
  const resolved = resolveProjectForWrite(project);
  if (resolved.error) {
    logAction(['todo/undo', project, '', 'rejected', resolved.error]);
    return sendJson(res, 404, { error: resolved.error });
  }
  const backupPath = lastBackups[resolved.slug];
  if (!backupPath || !fs.existsSync(backupPath)) {
    logAction(['todo/undo', project, '', 'rejected', 'no-backup']);
    return sendJson(res, 404, { error: 'no-backup', detail: 'Kein Backup fuer dieses Projekt in dieser Session vorhanden.' });
  }
  const allowlist = buildAllowlist();
  if (!isRealpathAllowed(resolved.statePath, allowlist)) {
    logAction(['todo/undo', project, '', 'rejected', 'not-in-allowlist']);
    return sendJson(res, 403, { error: 'not-in-allowlist' });
  }
  try {
    fs.copyFileSync(backupPath, resolved.statePath);
  } catch (e) {
    logAction(['todo/undo', project, '', 'error', 'restore-failed']);
    return sendJson(res, 500, { error: 'restore-failed', detail: e.message });
  }
  delete lastBackups[resolved.slug];
  logAction(['todo/undo', project, '', 'ok', `restored-from=${backupPath}`]);
  await refreshPortfolioOnly();
  return sendJson(res, 200, aggregateData());
}

// Setzt den manuellen Aktiv/Ruhend-Override eines Projekts (oder 'auto' = Automatik folgt Sitzungen).
async function handleProjectStatus(req, res) {
  let body;
  try {
    body = await readJsonBody(req);
  } catch (e) {
    return sendJson(res, 400, { error: 'invalid-body', detail: e.message });
  }
  const project = body.project;
  const status = body.status;
  const allowed = new Set(['aktiv', 'ruhend', 'auto']);
  if (!project || !allowed.has(status)) {
    logAction(['project/status', project || '', status || '', 'rejected', 'invalid-input']);
    return sendJson(res, 400, { error: 'invalid-input', detail: 'project und status (aktiv|ruhend|auto) sind Pflicht.' });
  }
  if (!knownSlugs().has(project)) {
    logAction(['project/status', project, status, 'rejected', 'unknown-project']);
    return sendJson(res, 404, { error: 'unknown-project', detail: 'Projekt nicht in project-repos.yaml.' });
  }
  const ov = loadOverrides();
  if (status === 'auto') delete ov.status[project];
  else ov.status[project] = status;
  try {
    saveOverrides(ov);
  } catch (e) {
    logAction(['project/status', project, status, 'error', 'write-failed']);
    return sendJson(res, 500, { error: 'write-failed', detail: e.message });
  }
  logAction(['project/status', project, status, 'ok', '']);
  return sendJson(res, 200, aggregateData());
}

// Speichert die manuelle Projekt-Reihenfolge (nur bekannte Slugs, dedupliziert, gedeckelt).
async function handleProjectOrder(req, res) {
  let body;
  try {
    body = await readJsonBody(req);
  } catch (e) {
    return sendJson(res, 400, { error: 'invalid-body', detail: e.message });
  }
  const order = body.order;
  if (!Array.isArray(order)) {
    return sendJson(res, 400, { error: 'invalid-input', detail: 'order muss ein Array von Slugs sein.' });
  }
  const known = knownSlugs();
  const clean = [];
  const seen = new Set();
  for (const s of order.slice(0, 200)) {
    if (typeof s === 'string' && known.has(s) && !seen.has(s)) {
      seen.add(s);
      clean.push(s);
    }
  }
  const ov = loadOverrides();
  ov.order = clean;
  try {
    saveOverrides(ov);
  } catch (e) {
    logAction(['project/order', '', String(clean.length), 'error', 'write-failed']);
    return sendJson(res, 500, { error: 'write-failed', detail: e.message });
  }
  logAction(['project/order', '', String(clean.length) + ' slugs', 'ok', '']);
  return sendJson(res, 200, aggregateData());
}

async function handleRecommendationStatus(req, res) {
  let body;
  try {
    body = await readJsonBody(req);
  } catch (e) {
    return sendJson(res, 400, { error: 'invalid-body', detail: e.message });
  }
  const id = body.id;
  const status = body.status;
  const allowedStatus = new Set(['open', 'dismissed', 'done']);
  if (!id || !allowedStatus.has(status)) {
    logAction(['recommendation/status', '', id || '', 'rejected', 'invalid-input']);
    return sendJson(res, 400, { error: 'invalid-input', detail: 'id und status (open|dismissed|done) sind Pflicht.' });
  }
  const filePath = path.join(DATA_DIR, 'recommendations.json');
  if (!fs.existsSync(filePath)) {
    logAction(['recommendation/status', '', id, 'rejected', 'file-missing']);
    return sendJson(res, 409, { error: 'file-missing', detail: 'recommendations.json existiert noch nicht (Briefing-Lauf noetig).' });
  }
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  } catch (e) {
    logAction(['recommendation/status', '', id, 'rejected', 'parse-error']);
    return sendJson(res, 500, { error: 'parse-error', detail: e.message });
  }
  const list = Array.isArray(parsed) ? parsed : Array.isArray(parsed.recommendations) ? parsed.recommendations : null;
  if (!list) {
    logAction(['recommendation/status', '', id, 'rejected', 'unexpected-shape']);
    return sendJson(res, 500, { error: 'unexpected-shape' });
  }
  const item = list.find((r) => r.id === id);
  if (!item) {
    logAction(['recommendation/status', '', id, 'rejected', 'not-found']);
    return sendJson(res, 404, { error: 'not-found' });
  }
  item.status = status;
  try {
    fs.writeFileSync(filePath, JSON.stringify(parsed, null, 2), 'utf-8');
  } catch (e) {
    logAction(['recommendation/status', '', id, 'error', 'write-failed']);
    return sendJson(res, 500, { error: 'write-failed', detail: e.message });
  }
  logAction(['recommendation/status', '', id, 'ok', status]);
  return sendJson(res, 200, { ok: true, id, status });
}

// --- Content-Pipeline: Backlog <-> Entwuerfe verschieben (Iteration 2) ---
function isSlugValid(slug) {
  return typeof slug === 'string' && /^[a-z0-9][a-z0-9-]*$/.test(slug);
}

// Loest content_path aus der Branding-Config auf und realpath-prueft posts/-Containment.
// Rueckgabe entweder { error: 'branding-disabled'|'path-missing'|'not-contained' }
// oder { realContentPath, realPostsDir }. Gemeinsam genutzt von content/move und
// content/read, damit das Sicherheitsmuster an genau einer Stelle gepflegt wird.
function resolveBrandingContentPath() {
  const cfg = loadDashboardConfig();
  const brandingCfg = (cfg && cfg.modules && cfg.modules.branding) || {};
  if (!brandingCfg.enabled) {
    return { error: 'branding-disabled' };
  }
  const rawContentPath = brandingCfg.content_path || '';
  const contentPath = rawContentPath
    ? path.resolve(rawContentPath.replace(/^~(?=$|\/)/, os.homedir()))
    : '';
  if (!contentPath || !fs.existsSync(contentPath) || !fs.statSync(contentPath).isDirectory()) {
    return { error: 'path-missing' };
  }
  let realContentPath, realPostsDir;
  try {
    realContentPath = fs.realpathSync(contentPath);
    realPostsDir = fs.realpathSync(path.join(contentPath, 'posts'));
  } catch {
    return { error: 'path-missing' };
  }
  if (realPostsDir !== realContentPath && !realPostsDir.startsWith(realContentPath + path.sep)) {
    return { error: 'not-contained' };
  }
  return { realContentPath, realPostsDir };
}

// Status-Code je Fehlercode von resolveBrandingContentPath(), einheitlich fuer alle Aufrufer.
function brandingPathErrorStatus(error) {
  return error === 'not-contained' ? 403 : 409;
}

// Verschiebt per rename; faellt bei geraeteuebergreifenden Pfaden (EXDEV, z.B.
// anderes Filesystem/Mount) auf Kopieren + Loeschen der Quelle zurueck.
function moveFileAcrossDevices(src, dest) {
  try {
    fs.renameSync(src, dest);
  } catch (e) {
    if (e && e.code === 'EXDEV') {
      fs.copyFileSync(src, dest);
      fs.unlinkSync(src);
    } else {
      throw e;
    }
  }
}

function runBrandingSync() {
  return new Promise((resolve) => {
    execFile(BASH_BIN, [path.join(COLLECTORS_DIR, 'branding.sh')], { timeout: 30000 }, (err, stdout, stderr) => {
      if (err) log(`branding-sync error: ${err.message} stderr=${stderr}`);
      resolve();
    });
  });
}

async function handleContentMove(req, res) {
  let body;
  try {
    body = await readJsonBody(req);
  } catch (e) {
    return sendJson(res, 400, { ok: false, error: 'invalid-body', detail: e.message });
  }
  const { slug, from, to } = body;
  const validDirs = new Set(['backlog', 'drafts']);
  if (!isSlugValid(slug) || !validDirs.has(from) || !validDirs.has(to) || from === to) {
    logAction(['content/move', slug || '', `${from || ''}->${to || ''}`, 'rejected', 'invalid-input']);
    return sendJson(res, 400, { ok: false, error: 'invalid-input' });
  }

  const resolved = resolveBrandingContentPath();
  if (resolved.error) {
    logAction(['content/move', slug, `${from}->${to}`, 'rejected', resolved.error]);
    return sendJson(res, brandingPathErrorStatus(resolved.error), { ok: false, error: resolved.error });
  }
  const { realContentPath, realPostsDir } = resolved;

  // srcPath/destPath werden ausschliesslich aus realPostsDir (bereits containment-geprueft)
  // und dem regex-validierten Slug gebaut, Traversal ueber den Slug ist damit ausgeschlossen.
  const srcPath = from === 'backlog'
    ? path.join(realPostsDir, 'backlog', `${slug}.md`)
    : path.join(realPostsDir, 'drafts', slug, 'post.md');
  const destPath = to === 'drafts'
    ? path.join(realPostsDir, 'drafts', slug, 'post.md')
    : path.join(realPostsDir, 'backlog', `${slug}.md`);
  const draftDir = path.join(realPostsDir, 'drafts', slug);

  let realSrc;
  try {
    realSrc = fs.realpathSync(srcPath);
  } catch {
    logAction(['content/move', slug, `${from}->${to}`, 'rejected', 'source-missing']);
    return sendJson(res, 404, { ok: false, error: 'source-missing' });
  }
  if (realSrc !== realContentPath && !realSrc.startsWith(realContentPath + path.sep)) {
    logAction(['content/move', slug, `${from}->${to}`, 'rejected', 'not-contained']);
    return sendJson(res, 403, { ok: false, error: 'not-contained' });
  }

  if (fs.existsSync(destPath)) {
    logAction(['content/move', slug, `${from}->${to}`, 'rejected', 'dest-exists']);
    return sendJson(res, 409, { ok: false, error: 'dest-exists' });
  }

  let cleanupEmptyDraftDir = false;
  if (from === 'drafts' && to === 'backlog') {
    let siblings;
    try {
      siblings = fs.readdirSync(draftDir);
    } catch (e) {
      logAction(['content/move', slug, `${from}->${to}`, 'rejected', 'source-missing']);
      return sendJson(res, 404, { ok: false, error: 'source-missing' });
    }
    const extras = siblings.filter((f) => f !== 'post.md');
    if (extras.length > 0) {
      logAction(['content/move', slug, `${from}->${to}`, 'rejected', 'assets-present']);
      return sendJson(res, 400, { ok: false, error: 'assets-present', detail: 'Im Entwurfsordner liegen weitere Dateien, bitte manuell verschieben.' });
    }
    cleanupEmptyDraftDir = true;
  }

  try {
    fs.mkdirSync(CONTENT_BACKUPS_DIR, { recursive: true });
    fs.copyFileSync(realSrc, path.join(CONTENT_BACKUPS_DIR, `${Date.now()}-${slug}.md`));
  } catch (e) {
    logAction(['content/move', slug, `${from}->${to}`, 'error', 'backup-failed']);
    return sendJson(res, 500, { ok: false, error: 'backup-failed', detail: e.message });
  }

  try {
    if (from === 'backlog' && to === 'drafts') {
      fs.mkdirSync(path.dirname(destPath), { recursive: true });
    }
    moveFileAcrossDevices(realSrc, destPath);
    if (cleanupEmptyDraftDir) {
      try { fs.rmdirSync(draftDir); } catch {}
    }
  } catch (e) {
    logAction(['content/move', slug, `${from}->${to}`, 'error', 'move-failed']);
    return sendJson(res, 500, { ok: false, error: 'move-failed', detail: e.message });
  }

  logAction(['content/move', slug, `${from}->${to}`, 'ok', '']);
  await runBrandingSync();
  return sendJson(res, 200, { ok: true });
}

// Naives Frontmatter-Splitting (gleiche Konvention wie parse_frontmatter() in branding.sh,
// nur ohne Feld-Parsing): beginnt die Datei mit einer Zeile "---", ist alles bis zur naechsten
// alleinstehenden "---"-Zeile der rohe Frontmatter-Block, der Rest ist der Body. Ohne
// erkennbaren Block: frontmatter "" und body = kompletter Inhalt.
function splitFrontmatter(raw) {
  const lines = raw.split('\n');
  if (!lines.length || lines[0].trim() !== '---') {
    return { frontmatter: '', body: raw };
  }
  let endIdx = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      endIdx = i;
      break;
    }
  }
  if (endIdx === -1) {
    return { frontmatter: '', body: raw };
  }
  return {
    frontmatter: lines.slice(1, endIdx).join('\n'),
    body: lines.slice(endIdx + 1).join('\n'),
  };
}

const CONTENT_READ_MAX_BYTES = 200 * 1024;

// --- Content-Pipeline: einzelnen Post lesen (Backlog/Entwurf/Veroeffentlicht) ---
async function handleContentRead(req, res, url) {
  const col = url.searchParams.get('col');
  const slug = url.searchParams.get('slug');
  const validCols = new Set(['backlog', 'drafts', 'published']);
  if (!validCols.has(col) || !isSlugValid(slug)) {
    logAction(['content/read', slug || '', col || '', 'rejected', 'invalid-input']);
    return sendJson(res, 400, { ok: false, error: 'invalid-input' });
  }

  const resolved = resolveBrandingContentPath();
  if (resolved.error) {
    logAction(['content/read', slug, col, 'rejected', resolved.error]);
    return sendJson(res, brandingPathErrorStatus(resolved.error), { ok: false, error: resolved.error });
  }
  const { realContentPath, realPostsDir } = resolved;

  let filePath;
  if (col === 'backlog') {
    filePath = path.join(realPostsDir, 'backlog', `${slug}.md`);
  } else if (col === 'drafts') {
    filePath = path.join(realPostsDir, 'drafts', slug, 'post.md');
  } else {
    // published: branding.sh strippt ein optionales Datumspraefix (YYYY-MM-DD-) aus dem
    // Ordnernamen, das UI kennt nur den gestrippten Slug. Ordner heisst also entweder exakt
    // der Slug (kein Praefix im Dateisystem) oder "<YYYY-MM-DD>-<slug>".
    const publishedDir = path.join(realPostsDir, 'published');
    let entries;
    try {
      entries = fs.readdirSync(publishedDir, { withFileTypes: true });
    } catch {
      logAction(['content/read', slug, col, 'rejected', 'not-found']);
      return sendJson(res, 404, { ok: false, error: 'not-found' });
    }
    const escapedSlug = slug.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const dateRe = new RegExp(`^\\d{4}-\\d{2}-\\d{2}-${escapedSlug}$`);
    const match = entries.find((e) => e.isDirectory() && (e.name === slug || dateRe.test(e.name)));
    if (!match) {
      logAction(['content/read', slug, col, 'rejected', 'not-found']);
      return sendJson(res, 404, { ok: false, error: 'not-found' });
    }
    filePath = path.join(publishedDir, match.name, 'post.md');
  }

  let realFile;
  try {
    realFile = fs.realpathSync(filePath);
  } catch {
    logAction(['content/read', slug, col, 'rejected', 'not-found']);
    return sendJson(res, 404, { ok: false, error: 'not-found' });
  }
  if (realFile !== realContentPath && !realFile.startsWith(realContentPath + path.sep)) {
    logAction(['content/read', slug, col, 'rejected', 'not-contained']);
    return sendJson(res, 403, { ok: false, error: 'not-contained' });
  }

  let raw;
  try {
    raw = fs.readFileSync(realFile, 'utf-8');
  } catch (e) {
    logAction(['content/read', slug, col, 'error', 'read-failed']);
    return sendJson(res, 500, { ok: false, error: 'read-failed', detail: e.message });
  }

  let truncated = false;
  if (Buffer.byteLength(raw, 'utf-8') > CONTENT_READ_MAX_BYTES) {
    raw = Buffer.from(raw, 'utf-8').slice(0, CONTENT_READ_MAX_BYTES).toString('utf-8');
    truncated = true;
  }
  const { frontmatter, body } = splitFrontmatter(raw);

  logAction(['content/read', slug, col, 'ok', truncated ? 'truncated' : '']);
  return sendJson(res, 200, { ok: true, col, slug, frontmatter, body, truncated });
}

function resolveClaudeBinary() {
  const candidates = [
    process.env.CLAUDE_BIN,
    path.join(os.homedir(), '.local', 'bin', 'claude'),
  ].filter(Boolean);
  for (const c of candidates) {
    try {
      if (fs.existsSync(c)) return c;
    } catch {}
  }
  return 'claude';
}

// Einmalig beim Start pruefen, nicht bei jedem Katalog-Abruf: das claude-Binary
// wechselt waehrend der Laufzeit des Servers nicht. Absoluter Kandidatenpfad ->
// direkt existsSync, sonst PATH manuell absuchen (kein execFileSync-Overhead).
function checkClaudeAvailable() {
  const bin = resolveClaudeBinary();
  if (path.isAbsolute(bin)) {
    try { return fs.existsSync(bin); } catch { return false; }
  }
  const dirs = (process.env.PATH || '').split(path.delimiter);
  for (const d of dirs) {
    try { if (fs.existsSync(path.join(d, bin))) return true; } catch {}
  }
  return false;
}
const CLAUDE_AVAILABLE = checkClaudeAvailable();

// --- Stufe 3: Claude-Aktions-Katalog ---
// Katalog kommt aus actions.json (statisches "enabled"), wird hier aber fuer
// kind:"claude"-Aktionen zusaetzlich gegen das tatsaechlich gefundene Binary
// gespiegelt: fehlt es, zeigt der Button das sofort statt erst nach dem Klick.
function loadActionsCatalog() {
  let catalog;
  try {
    catalog = JSON.parse(fs.readFileSync(ACTIONS_CATALOG_FILE, 'utf-8'));
  } catch {
    catalog = { actions: [] };
  }
  if (!CLAUDE_AVAILABLE) {
    catalog.actions = (catalog.actions || []).map((a) => (
      a.kind === 'claude' && a.enabled !== false
        ? { ...a, enabled: false, hint: 'claude-Binary nicht gefunden — Aktion inaktiv.' }
        : a
    ));
  }
  return catalog;
}

let runningAction = null;
let lastActionResult = null;

async function handleActionRun(req, res) {
  let body;
  try {
    body = await readJsonBody(req);
  } catch (e) {
    return sendJson(res, 400, { error: 'invalid-body', detail: e.message });
  }
  const name = body.name;
  const project = body.project;
  const catalog = loadActionsCatalog();
  const def = (catalog.actions || []).find((a) => a.name === name);
  if (!def) {
    logAction(['action/run', project || '', name || '', 'rejected', 'unknown-action']);
    return sendJson(res, 400, { error: 'unknown-action' });
  }
  if (def.enabled === false) {
    logAction(['action/run', project || '', name, 'rejected', 'disabled']);
    return sendJson(res, 501, { error: 'disabled', detail: def.hint || 'Aktion noch nicht verfuegbar.' });
  }
  if (runningAction) {
    logAction(['action/run', project || '', name, 'rejected', `busy:${runningAction.name}`]);
    return sendJson(res, 409, { error: 'busy', detail: `Es laeuft bereits eine Aktion: ${runningAction.name}` });
  }

  let cwd = DASH_DIR;
  let slugLabel = 'global';
  if (def.scope === 'project') {
    if (!project) {
      logAction(['action/run', '', name, 'rejected', 'missing-project']);
      return sendJson(res, 400, { error: 'missing-project', detail: 'Diese Aktion braucht ein Projekt.' });
    }
    const resolved = resolveProjectForWrite(project);
    if (resolved.error) {
      logAction(['action/run', project, name, 'rejected', resolved.error]);
      return sendJson(res, 404, { error: resolved.error });
    }
    cwd = resolved.projectPath;
    slugLabel = resolved.slug;
  }

  const timeoutMs = def.timeout_ms || 300000;
  const startedAt = new Date().toISOString();
  runningAction = { name, project: project || null, started_at: startedAt };
  logAction(['action/run', project || '', name, 'started', `cwd=${cwd}`]);

  function finish(status, output, extra) {
    runningAction = null;
    const ts = Date.now();
    const outFile = path.join(ACTIONS_DATA_DIR, `${name}-${slugLabel}-${ts}.txt`);
    try {
      fs.mkdirSync(ACTIONS_DATA_DIR, { recursive: true });
      fs.writeFileSync(outFile, output || '', 'utf-8');
    } catch {}
    lastActionResult = {
      name,
      project: project || null,
      status,
      started_at: startedAt,
      finished_at: new Date().toISOString(),
      output_file: outFile,
      ...extra,
    };
    logAction(['action/run', project || '', name, status, `output=${outFile}`]);
  }

  if (def.kind === 'shell') {
    let scriptArgs;
    if (name === 'system-check') scriptArgs = [path.join(COLLECTORS_DIR, 'check.sh'), 'light'];
    else if (name === 'refresh-data') scriptArgs = [path.join(COLLECTORS_DIR, 'refresh.sh')];
    else scriptArgs = null;
    if (!scriptArgs) {
      runningAction = null;
      logAction(['action/run', project || '', name, 'rejected', 'no-shell-mapping']);
      return sendJson(res, 400, { error: 'no-shell-mapping' });
    }
    execFile(BASH_BIN, scriptArgs, { timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) finish('error', `${stdout}\n${stderr}`, { error: err.message });
      else finish('ok', stdout);
    });
    return sendJson(res, 202, { ok: true, started_at: startedAt, name });
  }

  if (def.kind === 'claude') {
    const claudeBin = resolveClaudeBinary();
    const prompt = def.prompt;
    if (!prompt) {
      runningAction = null;
      logAction(['action/run', project || '', name, 'rejected', 'no-prompt']);
      return sendJson(res, 400, { error: 'no-prompt' });
    }
    execFile(
      claudeBin,
      ['-p', prompt, '--output-format', 'text'],
      { cwd, timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024 },
      (err, stdout, stderr) => {
        if (err) {
          const isTimeout = !!err.killed && err.signal === 'SIGTERM';
          finish(isTimeout ? 'timeout' : 'error', `${stdout}\n${stderr}`, { error: err.message });
        } else {
          finish('ok', stdout);
        }
      }
    );
    return sendJson(res, 202, { ok: true, started_at: startedAt, name });
  }

  runningAction = null;
  logAction(['action/run', project || '', name, 'rejected', 'unknown-kind']);
  return sendJson(res, 400, { error: 'unknown-kind' });
}

function handleActionStatus(req, res) {
  return sendJson(res, 200, { running: runningAction, last: lastActionResult });
}

// --- Request-Handler ---
const server = http.createServer(async (req, res) => {
  let url;
  try {
    url = new URL(req.url, `http://${HOST}:${PORT}`);
  } catch {
    return forbidden(res, 'Bad Request');
  }

  if (!isOriginAllowed(req)) {
    log(`403 origin-rejected: ${req.headers.origin || req.headers.referer || 'none'}`);
    return forbidden(res, 'Forbidden (origin)');
  }

  const hasValidToken = checkToken(req, url);
  if (!hasValidToken) {
    log(`403 no-token: ${url.pathname}`);
    return forbidden(res, 'Forbidden (token)');
  }

  // Token gueltig: Cookie setzen, damit Folge-Requests ohne Query-Param auskommen
  res.setHeader('Set-Cookie', `aios_token=${SERVER_TOKEN}; Path=/; HttpOnly; SameSite=Strict`);

  try {
    if (url.pathname === '/api/data' && req.method === 'GET') {
      const data = aggregateData();
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(data));
      return;
    }

    if (url.pathname === '/api/refresh' && req.method === 'POST') {
      runRefresh((err) => {
        if (err) {
          res.writeHead(503, { 'Content-Type': 'application/json; charset=utf-8' });
          res.end(JSON.stringify({ error: err.message }));
          return;
        }
        const data = aggregateData();
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify(data));
      });
      return;
    }

    if (url.pathname === '/api/todo/toggle' && req.method === 'POST') {
      return await handleTodoMutate(req, res, 'toggle');
    }
    if (url.pathname === '/api/todo/remove' && req.method === 'POST') {
      return await handleTodoMutate(req, res, 'remove');
    }
    if (url.pathname === '/api/todo/undo' && req.method === 'POST') {
      return await handleTodoUndo(req, res);
    }
    if (url.pathname === '/api/project/status' && req.method === 'POST') {
      return await handleProjectStatus(req, res);
    }
    if (url.pathname === '/api/project/order' && req.method === 'POST') {
      return await handleProjectOrder(req, res);
    }
    if (url.pathname === '/api/recommendation/status' && req.method === 'POST') {
      return await handleRecommendationStatus(req, res);
    }
    if (url.pathname === '/api/content/move' && req.method === 'POST') {
      return await handleContentMove(req, res);
    }
    if (url.pathname === '/api/content/read' && req.method === 'GET') {
      return await handleContentRead(req, res, url);
    }
    if (url.pathname === '/api/action/run' && req.method === 'POST') {
      return await handleActionRun(req, res);
    }
    if (url.pathname === '/api/action/status' && req.method === 'GET') {
      return handleActionStatus(req, res);
    }
    if (url.pathname === '/api/actions/catalog' && req.method === 'GET') {
      return sendJson(res, 200, loadActionsCatalog());
    }
    if (url.pathname === '/api/action/output' && req.method === 'GET') {
      const file = url.searchParams.get('file') || '';
      // nur Basename erlaubt, kein Pfad-Traversal, Datei muss real in ACTIONS_DATA_DIR liegen
      if (!file || file !== path.basename(file)) {
        return sendJson(res, 400, { error: 'invalid-file' });
      }
      const target = path.join(ACTIONS_DATA_DIR, file);
      let real, realDir;
      try {
        real = fs.realpathSync(target);
        realDir = fs.realpathSync(ACTIONS_DATA_DIR);
      } catch {
        return notFound(res);
      }
      if (real !== realDir && !real.startsWith(realDir + path.sep)) {
        return forbidden(res, 'Forbidden');
      }
      try {
        const content = fs.readFileSync(real, 'utf-8');
        res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end(content);
      } catch {
        return notFound(res);
      }
      return;
    }

    if (req.method === 'GET') {
      return serveStatic(req, res, url.pathname);
    }

    return notFound(res);
  } catch (err) {
    log(`500 unhandled: ${url.pathname} ${err && err.stack ? err.stack : err}`);
    try {
      sendJson(res, 500, { error: 'internal-error', detail: String(err && err.message ? err.message : err) });
    } catch {}
  }
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} ist bereits belegt. Dashboard-Server laeuft evtl. schon (siehe .pid).`);
    cleanupOnExit();
    process.exit(1);
  }
  console.error(`Server-Fehler: ${err.message}`);
  cleanupOnExit();
  process.exit(1);
});

server.listen(PORT, HOST, () => {
  log(`Dashboard-Server laeuft auf http://${HOST}:${PORT} (PID ${process.pid})`);
  // Kein Token auf stdout/ins Log: server.log wird von Skill und READMEs
  // dorthin umgeleitet und ist damit potenziell fuer jeden Nutzer der Maschine
  // lesbar. Das Token steht ausschliesslich in TOKEN_FILE (600), von dort liest
  // auch der Skill es.
  console.log(`AIOS-Dashboard laeuft: http://${HOST}:${PORT}/ — Token siehe ${TOKEN_FILE}`);
});
