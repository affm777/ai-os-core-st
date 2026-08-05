# CLAUDE.md (Global)

Globale Anweisungen fuer Claude Code — gilt fuer alle Projekte.

## Session Start

1. Projekt-CLAUDE.md lesen wenn vorhanden (PFLICHT)
2. STATE.md lesen wenn vorhanden (PFLICHT). Suchreihenfolge:
   a. `.planning/STATE.md` (Standard-Konvention strukturierter Projekte)
   b. `STATE.md` im Projekt-Root (einfache Projekte)
   Wenn beide existieren: aeltere ignorieren, User auf Dublette hinweisen.
3. SessionStart Hook liefert automatisch: Decisions, letzter Session Log, Learning Index

## Second Brain (Obsidian Vault)

**Vault-Pfad:** `~/Documents/Second-Brain/`
**Details:** `~/.claude/rules/vault-workflow.md`

### Kontext-Routing: Was lebt wo?

| Information | Projekt-Verzeichnis | Second Brain (Vault) |
|---|---|---|
| CLAUDE.md, STATE.md, ROADMAP | Projekt | - |
| Deliverables (Code, HTML, PDFs) | Projekt | - |
| Projekt-Uebersicht (Business) | - | Vault (02_Projects/ oder 03_Areas/) |
| Meeting Notes, Decisions | - | Vault |
| Learnings, Referenzen | - | Vault |
| Personen-Kontext | - | Vault |

**Faustregel:** Wenn das Projekt geloescht wird — was willst du behalten? → Second Brain.

### Projekt-Lifecycle

Projekte (02_Projects/) haben ein Enddatum. Areas (03_Areas/) sind laufend.
Bei Statuswechsel (z.B. Firma gegruendet) → proaktiv Verschiebung vorschlagen.
NUR vorschlagen, NIEMALS eigenstaendig verschieben. Details → vault-workflow.md

### Vault Top-Level (7 Ordner)

`00_Meta` (System), `01_Inbox` (Capture), `02_Projects` (mit Enddatum), `03_Areas` (laufend), `04_Resources` (projekt-uebergreifend, flach), `05_Contacts/{People,Organizations}` (Menschen + Firmen), `06_Archive` (abgeschlossen). Details: `vault-structure.md` im Vault + `vault-workflow.md`.

### Gueltige Typen (10, MECE)

decision, learning, concept, resource, session-log, meeting, person, organization, project, meta

- `decision` zwischen Optionen entschieden | `learning` aus Tun gelernt | `concept` synthetisiertes Pattern | `resource` externes Material (Artikel, Brand-Guides, Manuals) | `session-log` Solo-Outcome | `meeting` synchron mit anderen | `person`/`organization` Kontakte | `project` Index-File in 02_Projects | `meta` System-Files (vault-index, vault-log, lint-reports, Dashboards)

**Templates:** `00_Meta/Templates/`, neue Vault-Dateien IMMER via Template.
**Decision Validity:** `validity: active|superseded|archived`, nur active in Kontext laden.
**Vault-Index:** `00_Meta/system/vault-index.md` (TSV, grep-basiert) und `00_Meta/system/vault-log.md` (append-only Timeline) werden von `/brain:sort-inbox`, `/brain:rebuild-index`, `/brain:health-check` gepflegt. Details in `vault-workflow.md`.

## Session Ende

Bei "Schluss", "Fertig", "Session beenden" → `/wrap-up` ausfuehren (aktualisiert STATE.md automatisch).
Nach grosser Aufgabe (ohne /wrap-up): Proaktiv anbieten: "Soll ich STATE.md aktualisieren?"

## Schreibstil (global, PFLICHT)

- **Umlaute (ä, ö, ü, ß) IMMER ausschreiben.** Niemals ae/oe/ue/ss. Gilt für alle Outputs: Chat-Antworten, Markdown-Dateien, READMEs, Commit-Messages, Code-Kommentare, Vault-Files. Einzige Ausnahme: technische Strings (Dateinamen, URLs, Slugs, Variablennamen, JSON-Keys). Im Zweifel: Umlaut. Wenn ein Umlaut bereits im Bestandstext fehlt, beim Editieren mitkorrigieren.
- Keine Gedankenstriche (—, –). Stattdessen Komma, Punkt, Doppelpunkt, Klammern.
- **Edit-in-place (PFLICHT):** Bei Änderungswünschen an bestehenden Dokumenten/Dateien NUR das ändern, was explizit verlangt wurde. Niemals ganze Dokumente oder Sektionen neu schreiben oder ersetzen, niemals Bestandteile (Bilder, Links, Sektionen, Formatierung) entfernen oder umbauen, die nicht Gegenstand der Aufgabe waren. Im Zweifel: kleiner Edit statt Rewrite.

## Security (KRITISCH)

**NIEMALS:** API-Keys in Code, Secrets in Git, Tokens in Logs.
**Vor jedem Commit:** Secret-Scan, erzwungen durch PreToolUse-Hook `git-secret-scan.sh` (blockt bei Verdacht).

**Security (Agent-Permissions + Code-Quality):** `~/.claude/rules/security-basics.md` (Teil 1: kategorische Imperative gegen IPI, OAuth-Cross-Context, MCP-Transcript-Injection, Vault-Exfiltration. Teil 2: OWASP, Input Validation, Quality Gates).

## Browser-Automatisierung: Playwright ist führend (PFLICHT)

**Jede** Browser-Aufgabe läuft über Playwright: Seiten öffnen, Formulare ausfüllen, Dateien hochladen, Screenshots, Verifikation. Die Chrome-Erweiterung (`claude-in-chrome`) wird nicht verwendet. Auch wenn eine Aufgabe naheliegend über den Browser des Nutzers ginge: Playwright nehmen, nicht nach der Erweiterung fragen.

Bei Erstellung oder Änderung von UI-Elementen, HTML-Dokumenten oder visuellen Deliverables:
1. Playwright öffnet im Browser
2. Screenshot erstellen und visuell prüfen
3. Bei Problemen: iterativ verbessern (Fix, Screenshot, Verify Loop)
4. Screenshots danach sofort löschen

Braucht eine Aufgabe eine angemeldete Sitzung (z. B. Microsoft 365, SharePoint), die Playwright nicht hat: den Nutzer den Schritt selbst machen lassen und danach nur noch lesend weiterarbeiten. Keine Anmeldedaten eingeben.

## Context Management

- Hauptsession = Koordinator, Sub-Agents = Arbeiter
- MCP-Abfragen mit grossen Responses → via Sub-Agent delegieren (Context-Schutz)
- Unabhaengige Aufgaben → parallel (mehrere Tool-Calls in einer Nachricht)
- Agent-Typen: `Explore` (Codebase), `general-purpose` (Multi-Step), `Plan` (Architektur), Feature-Dev-Familie
- Agent-Teams experimentell via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, wenn Multi-Hypothesen noetig

## Self-Learning

Problem geloest oder neues Pattern entdeckt → Learning im Vault dokumentieren:
In `01_Inbox/` als neue Learning-Datei anlegen. /brain:sort-inbox sortiert spaeter ein.
Frontmatter mit `type: learning` setzen, damit es automatisch im Learning Index erscheint.

## Regeln (Details)

- CLAUDE.md kurz halten: Global max ~150 Zeilen, Projekt max ~100 Zeilen. Details in Rules auslagern.

| Thema | Datei |
|-------|-------|
| Security (Agent-Permissions + Code-Quality) | `~/.claude/rules/security-basics.md` |
| Vault Workflow | `~/.claude/rules/vault-workflow.md` |

**Archiv (on-demand, nicht auto-geladen):** `~/.claude/rules-archive/` — bewusst ausserhalb `rules/` damit die Harness es nicht auto-loaded. Ablageort für situatives Wissen, das nur bei bestimmten Aufgaben gebraucht wird: pro Datei hier eine Zeile ergänzen, WANN sie per Read geladen werden soll. Details: README im Ordner.
- `fullstack-patterns.md` — Tech-Stack-Defaults, API-Design, Testing-Strategie. Laden bei: neues Full-Stack-/Web-Projekt aufsetzen.
