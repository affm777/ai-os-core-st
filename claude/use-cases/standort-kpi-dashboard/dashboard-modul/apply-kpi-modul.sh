#!/bin/bash
# Verankert das Standorte-Modul (KPI-Dashboard) im installierten AIOS-Dashboard.
#
# Das Modul selbst lebt in ~/.claude/dashboard/public/aios-kpi.js und ueberlebt
# einen bootstrap.sh-Lauf (bootstrap kopiert nur, loescht nie). Was ein
# bootstrap-Lauf ueberschreibt, sind index.html und server.mjs — dieses
# Skript verankert die Aenderungen dort idempotent neu.
#
# Dieses Modul ist ein optionales lokales Delta, kein Teil des Standard-
# Dashboards. Es wird pro Projekt einmalig angewendet, wenn der Skill
# "standort-kpi-dashboard" den Dashboard-Reiter "Standorte" braucht.
set -euo pipefail

PYBIN=""
for _cand in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $_cand -c "import sys" </dev/null >/dev/null 2>&1; then PYBIN="$_cand"; break; fi
done
if [ -z "$PYBIN" ]; then
  echo "FEHLER: kein funktionierender Python-Interpreter (python3/python/py -3 geprueft)." >&2
  echo "Windows: winget install Python.Python.3.12, danach neues Terminal." >&2
  exit 1
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASH="$HOME/.claude/dashboard"
IDX="$DASH/public/index.html"
SRV="$DASH/server.mjs"
JS_SRC="$SRC_DIR/aios-kpi.js"
JS_DST="$DASH/public/aios-kpi.js"

[ -f "$JS_SRC" ] || { echo "FEHLT: $JS_SRC"; exit 1; }
[ -f "$IDX" ]    || { echo "FEHLT: $IDX — Dashboard installiert? (bootstrap.sh / /aios-dashboard)"; exit 1; }
[ -f "$SRV" ]    || { echo "FEHLT: $SRV"; exit 1; }

# 1) Modul-Datei kopieren (immer, idempotent — einfache Kopie).
cp "$JS_SRC" "$JS_DST"
echo "Modul kopiert nach $JS_DST"

# 2) Einmaliges Backup der index.html, bevor sie zum ersten Mal gepatcht wird.
if [ ! -f "$IDX.bak-kpi" ]; then
  cp "$IDX" "$IDX.bak-kpi"
  echo "Backup angelegt: $IDX.bak-kpi"
fi

# 3) index.html patchen: Sidebar-Gruppe "Finanzen", Nav-Button, Page-Section,
#    Script-Tag — je idempotent und selbstheilend (entfernt eine falsch
#    platzierte Vorversion und setzt sie an die richtige Stelle neu, statt nur
#    auf pure Abwesenheit zu pruefen).
# shellcheck disable=SC2086
$PYBIN - "$IDX" <<'PY'
import sys, io, re
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
before = s

# --- Sidebar-Gruppe "Finanzen": eigene Gruppe statt Unterbringung in
#     "Arbeit", VOR der Gruppe "System" (hier docken perspektivisch weitere
#     Zahlen-Reiter an, z.B. OPOS/Rechnungen, Umsatz). Nav-Button
#     (data-page="kpi") sitzt darin als erstes (und einziges) Element, kein
#     data-module-Gate, also immer sichtbar. ---
kpi_btn = (
    '      <button class="sb-item" data-page="kpi" title="Standorte">'
    '<span class="sb-ico"><svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M3 16.5h14"></path><path d="M4.5 16.5V8l5.5-4 5.5 4v8.5"></path><path d="M8 16.5v-4h4v4"></path></svg></span>'
    '<span class="sb-label">Standorte</span></button>\n'
)
finanzen_label = '      <div class="sb-group-label">Finanzen</div>\n'
finanzen_group_empty = '    <div class="sb-group">\n' + finanzen_label + '    </div>\n'
system_anchor = '    <div class="sb-group">\n      <div class="sb-group-label">System</div>\n'

# Alten oder falsch platzierten Standorte-Button IMMER zuerst entfernen (z.B.
# die fruehere Platzierung in der "Arbeit"-Gruppe vor dem Inbox-Button), dann
# an der richtigen Stelle neu setzen. Nach dem Entfernen bleibt eine ggf.
# schon vorhandene Finanzen-Gruppe (Label) unangetastet stehen.
s, _nsub = re.subn(r'[ \t]*<button class="sb-item" data-page="kpi"[^>]*>.*?</button>\n', '', s)

if finanzen_label not in s:
    if system_anchor not in s:
        raise SystemExit("Anker (System-Gruppe) nicht gefunden, index.html hat sich geaendert.")
    s = s.replace(system_anchor, finanzen_group_empty + system_anchor, 1)

s = s.replace(finanzen_label, finanzen_label + kpi_btn, 1)

changed = s != before

# --- Page-Section + Wrap-Div: MUSS innerhalb von <div class="content"> stehen
#     (sonst laeuft der Inhalt links unter die Sidebar). Anker ist daher das
#     </div>, das den Content-Wrapper schliesst, direkt vor dem Aktions-Overlay-
#     Kommentar — nicht der Kommentar selbst. ---
page_section = (
    '  <section class="page" data-page="kpi">\n'
    '    <section class="blk" style="margin-top:24px"><div id="kpiWrap"></div></section>\n'
    '  </section>\n\n'
)
content_close_anchor = '</div>\n\n<!-- Aktions-Overlay: global, schwebt über jeder Seite, keine Navigation -->'
if page_section + content_close_anchor not in s:
    # vorhandene (ggf. falsch platzierte, z.B. ausserhalb von .content) Page-Section
    # IMMER zuerst entfernen (auch wenn der Anker erst danach noch nicht sichtbar
    # ist, weil die alte Section genau zwischen </div> und dem Kommentar sitzt).
    # Exaktes String-Match statt Regex: die Section hat verschachtelte
    # </section>-Tags, ein non-greedy Regex wuerde nur bis zum inneren
    # </section> matchen und einen Rest stehen lassen. Wir kennen die exakt
    # generierte Form (immer dieselbe Zeichenkette), also reicht ein Literal-Replace.
    s = s.replace(page_section, '', 1)
    if content_close_anchor not in s:
        raise SystemExit("Anker (Content-Wrapper-Ende vor Aktions-Overlay) nicht gefunden, index.html hat sich geaendert.")
    s = s.replace(content_close_anchor, page_section + content_close_anchor, 1)
    changed = True

# --- Script-Tag, direkt VOR aios-system.js. Anker bewusst aios-system.js
#     statt aios-branding.js: Letzteres fehlt in Teilnehmer-Ableitungen, aus
#     denen derivation/strip-dashboard-modules.sh die Module Vertrieb und
#     Personal Branding entfernt hat, aios-system.js gibt es dagegen immer. ---
if 'aios-kpi.js' not in s:
    anchor = '<script src="aios-system.js"></script>'
    if anchor not in s:
        raise SystemExit("Anker <script src=aios-system.js> nicht gefunden, index.html hat sich geaendert.")
    s = s.replace(anchor, '<script src="aios-kpi.js"></script>\n' + anchor, 1)
    changed = True

if changed:
    io.open(p, "w", encoding="utf-8").write(s)
    print("index.html gepatcht (Nav-Button + Page-Section + Script-Tag).")
else:
    print("index.html bereits vollstaendig verankert, nichts zu tun.")
PY

# 4) server.mjs patchen: "kpi" in die Sections-Liste aufnehmen, sonst liest der
#    Server data/kpi.json nie ein (aggregateData() haelt die Liste hart codiert).
#    Idempotent per grep-Check, Backup einmalig wie bei index.html.
if grep -q "'kpi'" "$SRV"; then
  echo "server.mjs bereits verankert, nichts zu tun."
else
  if [ ! -f "$SRV.bak-kpi" ]; then
    cp "$SRV" "$SRV.bak-kpi"
    echo "Backup angelegt: $SRV.bak-kpi"
  fi
  # shellcheck disable=SC2086
  # Anker per Regex auf den Array-Inhalt statt auf eine feste Liste der
  # letzten Eintraege: derivation/strip-dashboard-modules.sh entfernt in
  # Teilnehmer-Ableitungen 'branding' und 'sales' aus genau dieser Liste,
  # ein fester String-Anker wuerde dort ins Leere laufen.
  $PYBIN - "$SRV" <<'PY'
import sys, io, re
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
pattern = re.compile(r"const sections = \[[^\]]*\];")
m = pattern.search(s)
if not m:
    raise SystemExit("Anker (sections-Array) nicht gefunden, server.mjs hat sich geaendert.")
s = pattern.sub(lambda mo: mo.group(0)[:-2] + ", 'kpi'];", s, count=1)
io.open(p, "w", encoding="utf-8").write(s)
PY
  echo "server.mjs gepatcht: 'kpi' zur Sections-Liste hinzugefuegt."
fi

# 5) Laeuft der Server bereits, muss er neu starten, damit die server.mjs-Aenderung
#    greift (Node haelt die alte Sections-Liste sonst im Speicher). Gleicher Ablauf
#    wie im Argument "stop" des /aios-dashboard-Skills: PID lesen, beenden, der
#    naechste /aios-dashboard-Aufruf startet automatisch neu.
PID_FILE="$DASH/.pid"
if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    echo "Laufenden Dashboard-Server (PID $PID) beendet, damit die server.mjs-Aenderung greift."
    echo "Naechster /aios-dashboard-Aufruf startet ihn automatisch neu."
  fi
fi

echo "Fertig: Modul 'Standorte' verankert."
