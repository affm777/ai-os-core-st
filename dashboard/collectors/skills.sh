#!/bin/bash
# skills.sh — Baut den Skills-Katalog fuers Dashboard: eine vollstaendige
# Inventur dessen, was im Setup tatsaechlich installiert ist.
# Read-only. Quellen: ~/.claude/skills/*/SKILL.md, ~/.claude/commands/**/*.md,
# User-Scope-Plugins aus ~/.claude/plugins/installed_plugins.json (Name +
# Beschreibung) plus 7-Tage-Nutzungszahlen aus data/usage.json.
# Gruppierung: "Fundament" = der ausgelieferte Kern laut fundament.json (von
# bootstrap.sh generiert) plus die beiden CLI-Builtins, "Weitere" = alles andere.
# Kein LLM, keine Bewertung. Schreibziel: data/skills.json.

set -uo pipefail

# Interpreter-Aufloesung: setzt $PYBIN, bricht mit klarer Meldung ab,
# wenn kein lauffaehiges Python existiert (Windows-Store-Stub, siehe Datei).
# shellcheck source=python-bin.sh
. "$(dirname "${BASH_SOURCE[0]}")/python-bin.sh"

DASH_DIR="$HOME/.claude/dashboard"
DATA_DIR="$DASH_DIR/data"
SKILLS_DIR="$HOME/.claude/skills"
COMMANDS_DIR="$HOME/.claude/commands"
USAGE_JSON="$DATA_DIR/usage.json"
mkdir -p "$DATA_DIR"

GENERATED_AT=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/')

$PYBIN - "$GENERATED_AT" "$SKILLS_DIR" "$COMMANDS_DIR" "$USAGE_JSON" "$DATA_DIR" "$DASH_DIR" "$HOME" <<'PYEOF'
import sys, os, re, json, glob

generated_at, skills_dir, commands_dir, usage_json, data_dir, dash_dir, home = sys.argv[1:8]

# ---- Nutzungszahlen (7 Tage) einlesen ----
# "counts" ist die vollstaendige Zaehlkarte, "top" nur die ersten 10 und damit
# blosser Fallback fuer eine usage.json aelteren Formats.
uses = {}
try:
    with open(usage_json, encoding="utf-8") as f:
        u = json.load(f)
    inv = u.get("skill_invocations_last_7_days", {}) or {}
    uses = dict(inv.get("counts") or {})
    if not uses:
        for row in inv.get("top", []) or []:
            uses[row.get("skill", "")] = row.get("count", 0)
except Exception:
    pass

# ---- Frontmatter-Parser (name + description, erster Satz) ----
def parse_frontmatter(path):
    try:
        with open(path, encoding="utf-8") as f:
            txt = f.read()
    except OSError:
        return None
    name, desc = None, None
    m = re.match(r"^---\s*\n(.*?)\n---", txt, re.DOTALL)
    block = m.group(1) if m else txt[:600]
    nm = re.search(r"^name:\s*(.+)$", block, re.MULTILINE)
    if nm:
        name = nm.group(1).strip().strip('"').strip("'")
    dm = re.search(r"^description:\s*(.+)$", block, re.MULTILINE)
    if dm:
        desc = dm.group(1).strip().strip('"').strip("'")
    return {"name": name, "desc": desc}

def first_clause(desc):
    if not desc:
        return ""
    # Trigger-Anhang nach " - " abschneiden (Konvention der SKILL.md-Descriptions)
    d = re.split(r"\s[-–]\sTrigger", desc)[0]
    d = re.split(r"\s-\s", d)[0] if " - " in d else d
    # erster Satz
    parts = re.split(r"(?<=[.!?])\s", d.strip())
    s = parts[0].strip() if parts else d.strip()
    if len(s) > 180:
        s = s[:177].rstrip() + "…"
    return s

# ---- Beschreibungs-Lexikon aus skills/ + commands/ ----
desc_by_name = {}
for p in glob.glob(os.path.join(skills_dir, "*", "SKILL.md")):
    fm = parse_frontmatter(p)
    if fm and fm.get("name"):
        desc_by_name[fm["name"]] = fm.get("desc") or ""
# Namespaced commands (z. B. brain/sync-meetings.md -> brain:sync-meetings)
for p in glob.glob(os.path.join(commands_dir, "**", "*.md"), recursive=True):
    fm = parse_frontmatter(p)
    rel = os.path.relpath(p, commands_dir)[:-3].replace(os.sep, ":")
    key = fm.get("name") if fm and fm.get("name") else rel
    if key and key not in desc_by_name:
        desc_by_name[key] = (fm.get("desc") if fm else "") or ""

# Abschaltzustand aus den Settings: einzelne Skills ueber skillOverrides ("off"),
# ganze Plugins ueber enabledPlugins (false). Beides wird angezeigt statt
# verschwiegen, damit sichtbar ist, was da ist und was ruht.
skill_off = set()
plugins_off = set()
try:
    with open(os.path.join(home, ".claude", "settings.json"), encoding="utf-8") as f:
        st = json.load(f)
    for k, v in (st.get("skillOverrides") or {}).items():
        if str(v).lower() == "off":
            skill_off.add(k)
    for k, v in (st.get("enabledPlugins") or {}).items():
        if v is False:
            plugins_off.add(k)
except Exception:
    pass

inaktiv = set()   # Namen wie im Katalog (Skill-Name bzw. <plugin>:<name>)

# User-Scope-Plugins (Marketplace). Die Registry nennt den exakten installPath,
# damit landet bei mehreren gecachten Versionen die richtige im Katalog.
# Namensschema <plugin>:<name> entspricht dem, was in den Transcripts gezaehlt wird.
try:
    with open(os.path.join(home, ".claude", "plugins", "installed_plugins.json"), encoding="utf-8") as f:
        reg = json.load(f)
    for reg_key, entry in (reg.get("plugins") or {}).items():
        for inst in (entry if isinstance(entry, list) else [entry]):
            if not isinstance(inst, dict) or inst.get("scope") != "user":
                continue
            root = inst.get("installPath")
            if not root or not os.path.isdir(root):
                continue
            plugin = str(reg_key).split("@")[0]
            plugin_aus = reg_key in plugins_off
            for p in glob.glob(os.path.join(root, "skills", "*", "SKILL.md")):
                fm = parse_frontmatter(p)
                nm = (fm.get("name") if fm else None) or os.path.basename(os.path.dirname(p))
                key = "%s:%s" % (plugin, nm)
                desc_by_name.setdefault(key, (fm.get("desc") if fm else "") or "")
                if plugin_aus or nm in skill_off:
                    inaktiv.add(key)
            for p in glob.glob(os.path.join(root, "commands", "*.md")):
                base = os.path.basename(p)[:-3]
                if base.startswith("_"):      # Konventions-/Include-Dateien
                    continue
                fm = parse_frontmatter(p)
                key = "%s:%s" % (plugin, base)
                desc_by_name.setdefault(key, (fm.get("desc") if fm else "") or "")
                if plugin_aus:
                    inaktiv.add(key)
except Exception:
    pass

def desc_for(name, fallback=""):
    return first_clause(desc_by_name.get(name, "")) or fallback

# ---- Fundament = was dieses Setup als Kern ausgeliefert bekommen hat ----
# Quelle ist das von bootstrap.sh geschriebene Manifest. Der Fallback deckt
# Setups ab, deren bootstrap-Lauf aelter ist als das Manifest.
try:
    with open(os.path.join(dash_dir, "fundament.json"), encoding="utf-8") as f:
        fundament = set(json.load(f).get("fundament") or [])
except Exception:
    fundament = set()
if not fundament:
    fundament = {"aios-dashboard", "briefing", "designer", "landing-page-builder", "new-project",
                 "playwright-cli", "research-prompt", "resume-session", "skill-creator",
                 "system-check", "wrap-up", "brain:health-check", "brain:rebuild-index",
                 "brain:sort-inbox", "brain:sync-meetings"}

# CLI-Builtins haben keine Datei, ihre Texte koennen nur kuratiert sein. Bewusst
# nur diese zwei: sie gehoeren zum gelehrten Kreislauf (Wrap-up, dann Clear).
# Alles andere aus der CLI-Mechanik (/model, /resume) faellt durch das Gate.
BUILTINS = {
    "clear": ("Chat leeren",
              "Leert den Chat-Verlauf für einen frischen Start. Der Arbeitsstand ist vorher durch das Wrap-up gesichert."),
    "exit":  ("Claude beenden",
              "Beendet die laufende Claude-Code-Sitzung im Terminal."),
}

# Kuratiertes Lexikon: Titel und neutrale Beschreibung. Gewinnt bewusst ueber die
# SKILL.md-Beschreibung, damit die Kacheln erklaeren statt zu triggern und keine
# persoenlichen Formulierungen aus lokalen Skills in die Oberflaeche laufen.
LEXIKON = {
    "resume-session": ("Arbeitsstand wiederherstellen",
        "Holt beim Start den letzten Stand: wo waren wir, was ist offen, was wurde entschieden."),
    "wrap-up": ("Sitzung abschließen",
        "Sichert Entscheidungen, Erkenntnisse und offene Punkte ins Second Brain und aktualisiert den Projektstatus."),
    "briefing": ("Tages-Briefing",
        "Stellt morgens zusammen: heutige Termine, neue Mails vorsortiert nach Handeln, Warten und Kenntnis, fällige Vertriebs-Schritte und der System-Status. Ergebnis ist eine kurze Essenz, auf Wunsch als Slack-Nachricht."),
    "system-check": ("System-Doktor",
        "Prüft das gesamte Setup und liefert zu jedem Befund eine fertige Korrektur-Anweisung."),
    "new-project": ("Neues Projekt anlegen",
        "Setzt ein Projekt mit korrekter Struktur und Status-Datei auf."),
    "skill-creator": ("Ablauf zum Skill machen",
        "Verwandelt einen wiederkehrenden Freitext-Auftrag in einen eigenen, aufrufbaren Skill."),
    "aios-dashboard": ("Schaltstelle öffnen",
        "Startet dieses Dashboard lokal auf deinem Rechner."),
    "mail": ("Antwort-Entwürfe",
        "Entwirft Mail-Antworten im eigenen Ton, senden tust du."),
    "designer": ("Dokumente & Slides",
        "Erstellt Print-Dokumente, PDFs und Präsentationen aus einfachem Text."),
    "landing-page-builder": ("Web-Seiten bauen",
        "Baut lauffähige Landingpages und Web-Oberflächen als echten Code."),
    "research-prompt": ("Recherche-Prompts",
        "Baut optimierte Prompts für externe KI-Recherchen."),
    "playwright-cli": ("Browser steuern & testen",
        "Steuert einen echten Browser, für Klickstrecken, Screenshots und Tests."),
    "brain:sort-inbox": ("Inbox einsortieren",
        "Sortiert neue Notizen des Second Brain in die Zielordner und pflegt den Index."),
    "brain:health-check": ("Second Brain prüfen",
        "Sucht Lücken und Unstimmigkeiten im Second Brain und meldet sie, ohne selbst zu ändern."),
    "brain:rebuild-index": ("Wissens-Index neu bauen",
        "Baut den Suchindex des Second Brain vollständig neu auf."),
    "brain:sync-meetings": ("Meetings einsammeln",
        "Übernimmt Meeting-Transkripte als Notizen ins Second Brain."),
}

def title_for(name):
    base = name.split(":")[-1].replace("-", " ").replace("_", " ")
    return base[:1].upper() + base[1:]

# ---- Emission: alles was installiert ist, in zwei Gruppen ----
# Das Gate gegen Transcript-Rauschen ist hier implizit: emittiert wird nur, was
# als Datei existiert, plus die zwei Builtins. Fragmente aus Transcript-Zaehlung
# koennen strukturell nicht mehr als Kachel erscheinen.
installed = set(desc_by_name)

def make(name, gruppe):
    lex = LEXIKON.get(name) or BUILTINS.get(name)
    # Builtins der CLI kennen keinen Abschalt-Schalter, sie sind immer aktiv.
    aktiv = True if name in BUILTINS else (name not in inaktiv and name not in skill_off)
    return {"cmd": "/" + name,
            "gruppe": gruppe,
            "titel": lex[0] if lex else title_for(name),
            "desc": lex[1] if lex else desc_for(name),
            "uses": uses.get(name, 0),
            "aktiv": aktiv}

# Alphabetisch als stabiler Tiebreak. Die Anzeige sortiert nach Nutzung, stabil,
# damit Kacheln bei Gleichstand nicht von Lauf zu Lauf springen.
fund_names = sorted(fundament & installed) + sorted(BUILTINS)
weitere_names = sorted(installed - fundament - set(BUILTINS))

skills = [make(n, "Fundament") for n in fund_names]
skills += [make(n, "Weitere") for n in weitere_names]

with open(os.path.join(data_dir, "skills.json"), "w", encoding="utf-8") as f:
    json.dump({"generated_at": generated_at, "skills": skills}, f, ensure_ascii=False, indent=2)

print("skills.json (%d Eintraege) geschrieben" % len(skills))
PYEOF
rc=$?

verify_json_output "$rc" "$DATA_DIR/skills.json" "skills-collector" "$GENERATED_AT" || exit 1

chmod 644 "$DATA_DIR/skills.json" 2>/dev/null || true
echo "skills-collector fertig"
