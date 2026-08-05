# /brain:sort-inbox — Inbox aufraeumen und Wissen einsortieren

Du bist ein Wissens-Kurator. Raeume die Inbox auf und sortiere Inhalte in die richtige Stelle im Vault ein.

## Voraussetzung

`00_Meta/system/vault-index.md` muss existieren (TSV-Index aller Vault-Dateien). Falls nicht: STOP, dem User `/brain:rebuild-index` empfehlen. Details zum Index in `~/.claude/rules/vault-workflow.md` (Abschnitt "Vault Index").

## Delegation-Protocol

**Threshold:**
- < 10 Inbox-Files → alles im Hauptkontext.
- >= 10 → 1 `general-purpose` Sub-Agent fuer Schritte 3-7.
- >= 50 → mehrere Sub-Agents, Split nach Projekt.

**Hauptkontext (nicht delegierbar):** Schritt 1/1.5 (Scan), 2 (User-Questions), 6.7 (Writes ausserhalb Vault), 6.9 (Rename/Delete-Confirmation), 8.5 (User-Interaktion), 9/10 (Log + Report).

**Delegiert:** Schritte 3 (Frontmatter), 4 (Extraktion), 5 (Linking), 6 (Move), 6.5 (Index-Patches), 6.8 (Entity-Propagation), 7 (Wikilink-Audit).

**Sub-Agent-Return-Kontrakt:**
```
## Moved
- src-path → dst-path

## TSV-Patches
<block>

## Hub-Proposals
- <hub-path>: <section> -> <link-zeile>

## Meeting-Propagation-Candidates
- <meeting-path>: projekt=<slug> action_items=<N> propagated_to_state=<current-value>

## Open Questions
- <datei>: <unresolved wikilink / ambiguitaet>

## Frontmatter-Fixes
- <datei>: <fix>

## Errors
- <datei>: <grund>
```

Main buendelt TSV-Patches + Hub-Proposals (1-2 Edits statt N), stellt Open Questions, fuehrt Schritte 6.7/6.9/8.5 interaktiv aus.

**Sub-Agent-Input:** Inbox-Dateiliste, Vault-Index-Snapshot (aus grep), bekannte Projekt-Slugs (`02_Projects/*/` + `03_Areas/*/`), Taxonomie-Regeln.

## Execution-Mode

- **on-demand** (User tippt `/brain:sort-inbox` interaktiv): alle Schritte wie beschrieben, Rueckfragen erlaubt.
- **scheduled** (Desktop-App Scheduled Task, keine User-Praesenz): autonom, keine Rueckfragen. Es gilt: **eindeutige Faelle einsortieren, alles andere parken.**

**Erkennungsregel:** `scheduled`-Mode aktiv, wenn (a) das Skill-Argument das Wort `scheduled` enthaelt ODER (b) der Prompt-Kontext den Scheduled-Run-Header enthaelt (`<scheduled-task ...>` bzw. "This is an automated run of a scheduled task" / "The user is not present"). Sonst on-demand.

**Scheduled-Regeln (Abweichungen von den Schritten unten):**

1. **Eindeutig** (wird einsortiert) heisst ALLE Bedingungen erfuellt:
   - kein `dedup_warning: true` im Frontmatter
   - gueltiger `type` aus der Taxonomie UND Ziel laut Einsortier-Tabelle klar bestimmbar
   - Zielordner existiert bereits (NIEMALS neue Projekt-/Area-Ordner, Cluster oder MOCs anlegen)
   - kein Merge noetig (kein aehnlicher Titel in Inbox oder Vault laut TSV-Grep)
   - kein Loeschen, kein Rename noetig
2. **Alles andere wird geparkt:** Datei bleibt unveraendert in der Inbox.
3. **Write-Boundary:** Writes innerhalb `~/Documents/Second-Brain/` PLUS die deterministische STATE.md-Propagation (Schritt 6.7) in Projekt-Repos via `~/.claude/project-repos.yaml`.
   - **Schritt 6.7 (STATE.md-Propagation) LÄUFT im scheduled-Mode** — nicht überspringen. Begründung: 6.7 ist vollständig deterministisch (kein User-Prompt), doppelt idempotent (Meeting-Flag `propagated_to_state` + Item-Substring-Dedup) und append-only unter `### Pending Todos` (eindeutiger Themen-Cluster, bei Ambiguität Transit `#### Aus Meetings`). Ambiguität oder fehlender Repo-Pfad → skip. Es gibt KEINE cross-run-Deferral von 6.7 mehr; wer 6.7 defert, verliert Action Items still (der Marker `propagated_to_state: false` wird sonst nie wieder gegriffen).
   - **NUR Schritt 8.5 (CLAUDE.md-Check) wird ÜBERSPRUNGEN** — er ist inhärent interaktiv (Diff-Vorschlag `[y/n/edit]`, menschliche Urteilsfrage). 8.5-Kandidaten kommen in den Park-Report, damit der nächste on-demand-Lauf sie vorschlägt.
4. **Schritt-Deltas:** Schritt 2 (Löschfragen) → nie löschen, parken. Schritt 2.5 (dedup_warning) → parken. Schritt 6.9 → keine Renames/Deletes. Schritt 7c (fehlende Zielseite) → Datei parken statt fragen. Schritte 6.5 (Index-Patch), 6.7 (STATE.md-Propagation inkl. Reconciliation), 6.8 (Entity-Propagation) und 7a/b (Wikilink-Audit) laufen normal für alle einsortierten Dateien.
5. **Park-Report:** Wenn es IRGENDETWAS zu deferieren gibt (mindestens 1 geparkte Datei ODER mindestens 1 übersprungener 8.5-Kandidat), schreibe/aktualisiere `01_Inbox/sort-inbox-parked.md` (type: meta): pro Eintrag eine Zeile mit Grund + ggf. offener Frage. Wenn NICHTS zu deferieren ist und die Datei existiert: löschen. Der nächste on-demand-Lauf liest diese Datei ZUERST, stellt die offenen Fragen und löscht sie danach. **Kritisch:** Der Park-Report ist NICHT der Träger für 6.7-Deferrals mehr (6.7 läuft ja direkt) — er trägt nur noch geparkte Dateien und 8.5-CLAUDE.md-Kandidaten.
6. **Vault-Log-Eintrag** (Schritt 9) mit Zusatz `scheduled`: `## [YYYY-MM-DD] sweep (scheduled) | N einsortiert, M geparkt (<gruende kurz>)`.

## Schritte

### 1. Inbox scannen
- Lies alle Dateien in `~/Documents/Second-Brain/01_Inbox/`
- Zeige eine Uebersicht: Dateiname, Typ, Erstelldatum
- Erwartetes Dateiformat: `YYYY-MM-DD-[beschreibung].md`

### 1.5. Vault-Index pruefen (NICHT laden!)
- `00_Meta/system/vault-index.md` muss existieren. Wenn nicht: STOP, `/brain:rebuild-index` empfehlen.
- **Lade den Index NIE komplett in den Kontext.** Stattdessen: gezielte `grep`-Queries pro Lookup-Bedarf in den naechsten Schritten.
- Query-Muster:
  - Alias-Lookup: `grep -i "alias-text" 00_Meta/system/vault-index.md`
  - Topic-Lookup: `grep "topic-name" 00_Meta/system/vault-index.md`
  - Person-Lookup: `grep "	person	" 00_Meta/system/vault-index.md | grep -i "name"`
  - Projekt-Lookup: `grep "	project	" 00_Meta/system/vault-index.md`

### 2. Triage (mit Duplikat-Erkennung)
Pro Inbox-Datei:
- **Wertvoll:** weiterverarbeiten (Schritt 3-6).
- **Veraltet/irrelevant:** User fragen (loeschen oder archivieren).
- **Duplikat-Check:**
  - Inbox untereinander: aehnliche Titel, Person in anderer Schreibweise, gleiches Thema in mehreren Sessions → mergen.
  - Inbox gegen Vault via TSV-grep: `grep "	person	" 00_Meta/system/vault-index.md | grep -i "name"`, `grep "topic-x" 00_Meta/system/vault-index.md`.

Bei Unsicherheit IMMER User fragen (Namen, Personen, Decision-Ueberlappung). Keine eigenmaechtigen Merges.

### 2.5. Dedup-Warning-Guard (Meetings aus `/brain:sync-meetings`)

Meetings, die `/brain:sync-meetings` als **unklar** klassifiziert hat (gleicher Titel, leichte Zeit-/Scope-Differenz), kommen mit `dedup_warning: true` im Frontmatter und einem `> [!warning] Moegliches Duplikat`-Callout im Body in die Inbox. Das ist der Punkt, an dem der User semantisch entscheiden muss.

**Pro Inbox-Datei mit `dedup_warning: true`:**

1. Kandidat-Referenz aus dem Callout extrahieren (`[[<basename>]]`).
2. Kandidat-Datei und Inbox-Datei dem User nebeneinander zeigen (Titel, Attendees, Zusammenfassung — max 30 Zeilen je Datei).
3. User fragen:
   ```
   Moegliches Duplikat: <inbox-file> ↔ <kandidat-file>
   [1] Ist doch dasselbe Meeting → Inbox-File loeschen, Kandidat bleibt
   [2] Verschiedene Meetings → Warnung entfernen (dedup_warning: false, Callout raus), normal einsortieren
   [3] Teilueberlappung → beide behalten, in Inbox-File manuell mergen bevor Einsortieren
   ```
4. Handlung pro Antwort:
   - `[1]`: Inbox-File loeschen, Wikilink-Propagation mit `[1]`-Regel aus Schritt 6.9 (Delete), aus Rest-Sweep ausschliessen.
   - `[2]`: Im Inbox-Frontmatter `dedup_warning: false` setzen + Callout aus Body entfernen. Weiter mit Schritt 3.
   - `[3]`: Inbox-File zurueckstellen, User merged manuell. Im Report als `Manual merge pending` listen.

**Wichtig:** Solange `dedup_warning: true` ist, NICHT einsortieren (Schritt 6 ueberspringen). Das Flag ist ein harter Block bis User-Entscheidung.

### 3. Frontmatter pruefen und anreichern
- Pflichtfelder: title, created_date, type, status, tags, aliases
- Tags aus Taxonomie korrekt? Keine neuen Top-Level-Tags?
- Gueltige Typen: `decision`, `learning`, `concept`, `resource`, `session-log`, `meeting`, `person`, `organization`, `project`, `meta`
- **Verlinkung pruefen:** Personen nur via `[[Wikilinks]]` referenzieren (keine human/-Tags)
- Status von `draft` auf `done` setzen wenn fertig

### 4. Informations-Extraktion
- Meeting Note enthaelt Decision? Eigene Decision-Datei extrahieren
- Notiz enthaelt Learning? In bestehende Learning-Datei integrieren oder neue anlegen
- Extrahierte Dateien zurueckverlinken: `Extrahiert aus: [[Quell-Notiz]]`

### 5. Semantisches Linking (via TSV)
- VOR jeder Verlinkung: `grep` im TSV-Index nach verwandten Dateien (Topic-Spalte)
- Zu passenden Hubs (Concepts, Index-Files) in `04_Resources/` verlinken
- Neue MOCs nur anlegen wenn 5+ Dateien ein Thema teilen

### 6. Einsortieren
| Typ | Ziel |
|-----|------|
| Decision | `02_Projects/[slug]/` oder `03_Areas/[slug]/` |
| Learning | `04_Resources/` (bestehende Datei ergaenzen wenn Topic-Match) |
| Meeting Note | `02_Projects/[slug]/` (wenn Projekt aktiv) oder `03_Areas/[slug]/` |
| Session Log | `02_Projects/[slug]/` |
| Concept/Evergreen | `04_Resources/` |
| Person | `05_Contacts/People/` |
| Organization | `05_Contacts/Organizations/` |

Zum Bewegen `mv` nutzen, nicht Read+Write+Delete.

### 6.5. Vault-Index inkrementell patchen
Fuer jede in Schritt 6 bewegte/neu angelegte/geloeschte Datei: `00_Meta/system/vault-index.md` gezielt updaten.

- **Neue Datei:** TSV-Zeile in den Code-Block appendieren mit Spalten `path	title	type	tags	aliases	topics	updated`. Topics inhaltlich vergeben (max 3, lowercase, bindestrich-separiert, konsistent mit bestehenden Topics, also vorher `grep` ob aehnliches Topic schon existiert).
- **Verschobene Datei:** Bestehende Zeile finden (`grep`), `path`-Spalte updaten via `Edit`.
- **Geloeschte Datei:** Zeile aus dem TSV entfernen.
- **Entity-Page mit neuen Backlinks:** wenn die Entity neue Aliases bekommt, aliases-Spalte updaten.
- Im Frontmatter: `updated:` auf heute, `file_count:` neu zaehlen.

### 6.7. Meeting-Action-Items → STATE.md propagieren

**Modus:** Läuft in BEIDEN Modi (on-demand UND scheduled). Rein deterministisch, kein User-Prompt, doppelt idempotent — daher kein Grund zum Deferieren.

Für jede in Schritt 6 einsortierte Datei mit `type: meeting` + mind. 1 Action Item:

**Meeting-Guard:** Frontmatter `propagated_to_state` pruefen.
- `true` → SKIP (Meeting bereits propagiert).
- `false` / `pending` / fehlt → weiter, danach auf `true` setzen.

**Projekt-Match** (erste Regel gewinnt):
1. Titel enthaelt Projekt-Slug/Alias (case-insensitive, Wort-Grenze).
2. Mind. 2 Attendees sind im Projekt-Hub (`02_Projects/<slug>/<slug>.md`) als `[[Wikilink]]`.
3. Mehrere Treffer → ambiguous, skip.
4. Keiner → skip.

**Repo-Pfad:** `~/.claude/project-repos.yaml` (Slug → Pfad). Fehlt: skip.

**Item-Dedup-Check (PFLICHT vor jedem Append):**
1. `<repo>/.planning/STATE.md` einmal lesen. Alle `- [ ]`-Zeilen unter `### Pending Todos` (ueber alle `####`-Subsections) sammeln.
2. Pro Action Item aus dem Meeting: Signatur bilden = die ersten 3-5 inhaltlichen Woerter lowercase (Nouns/Verben, Fuellwoerter wie "der/die/an/fuer/nach/zu" raus, Issue-Nummern `#\d+` und Klammer-Kontext optional weglassen).
3. Substring-Match (case-insensitive) der Signatur gegen die gesammelten `- [ ]`-Zeilen.
4. **Match** → Skip dieses Item. Im Report als `skipped-dup: <item> ↔ <existing-line>` auflisten.
5. **Kein Match** → Append.

**Write:** `<repo>/.planning/STATE.md` → `### Pending Todos` → passender `#### `-Themen-Cluster. Cluster sind Stränge (Thema), niemals Herkunft: bestehenden Cluster wählen, der das Item fachlich trifft. Passt keiner eindeutig (im scheduled-Mode gilt jede Ambiguität als nicht eindeutig) → `#### Aus Meetings` nur als Transit (wird bei /wrap-up oder on-demand-Sweep in Stränge aufgelöst). Die Herkunft steht am Item selbst:
```
- [ ] <Beschreibung> ([[<meeting-basename>]], Owner: <Assignee>)
```
Danach `propagated_to_state: true` im Meeting-File setzen, auch wenn alle Items als Duplikate geskippt wurden (Meeting ist semantisch "verarbeitet").

**Reconciliation (Selbstheilung, beide Modi) — PFLICHT am Ende von Schritt 6.7:**

Der Marker `propagated_to_state` muss ein LEBENDER Marker sein, nicht nur bei frisch einsortierten Dateien greifen. Sonst gehen Action Items still verloren, wenn 6.7 je übersprungen wurde (Repo-Pfad fehlte zum Zeitpunkt, historischer Altbestand, früherer Deferral-Bug).

1. Vault-weit greppen nach verwaisten, schon einsortierten Meetings (außerhalb der Inbox):
   ```bash
   grep -rl "type: meeting" ~/Documents/Second-Brain/02_Projects/ ~/Documents/Second-Brain/03_Areas/ --include="*.md" \
     | xargs grep -L "propagated_to_state: true" 2>/dev/null
   ```
   Das liefert Meetings ohne `propagated_to_state: true` (Feld `false`, `pending` oder fehlt).
2. **Deckel:** max 15 Dateien pro Lauf (Token-Budget), neueste zuerst (Dateiname-Datum absteigend). Wenn mehr: Rest im Report als offene Reconciliation-Backlog-Zahl nennen.
3. **Recency-Gate (kritisch gegen Stale-Backfill):** Meeting-Datum aus dem Dateinamen (`YYYY-MM-DD`) lesen. ÄLTER als 14 Tage relativ zum Lauf-Datum → NICHT propagieren, nur `propagated_to_state: true` setzen. Begründung: Action Items alter Meetings sind längst erledigt oder anderswo getrackt (Issues, damalige STATE.md-Wrap-ups); ihr Backfill flutet die aktuelle STATE.md mit Rauschen, das der Item-Dedup NICHT fängt (erledigte Alt-Items stehen nicht mehr in STATE.md, würden also fälschlich neu angehängt). NUR Meetings ≤14 Tage laufen durch die volle Propagation.
4. Für jedes Meeting ≤14 Tage die volle 6.7-Logik anwenden: Meeting-Guard, Projekt-Match, Repo-Pfad, Item-Dedup-Check, Write, danach `propagated_to_state: true`.
5. **Terminierung (wichtig):** Ein Meeting ohne offene Action Items (keine vorhanden ODER alle bereits in STATE.md) bekommt ebenfalls `propagated_to_state: true` — nichts offen, gilt als verarbeitet. Zusammen mit dem Recency-Gate terminiert die Reconciliation sauber: feldlose Alt-Meetings werden einmalig auf `true` gesetzt und tauchen nie wieder auf.
6. **Skip-Regeln bleiben:** NUR ein ambiguer Projekt-Match MIT echten offenen Items in einem ≤14-Tage-Meeting bleibt `false` (braucht menschliche Zuordnung) → im Report zählen. Fehlender Repo-Pfad → skip. In BEIDEN Modi wird hier NICHT geparkt — die Dateien sind bereits einsortiert; parken ergäbe keinen Sinn.
7. Im Report: `Reconciliation: [X] ≤14d nachpropagiert, [W] alt→verarbeitet markiert, [Y] weiter ambiguous/ohne Repo, [Z] Backlog übrig`.

**Delegation:** immer Hauptkontext (Writes außerhalb Vault). Sub-Agent liefert Kandidaten via `## Meeting-Propagation-Candidates`. Reconciliation (Vault-Grep + STATE.md-Writes) ebenfalls Hauptkontext.

### 6.8. Entity-Update-Propagation (Karpathy-Pattern)
Nach Einsortierung jeder Datei: pruefe via TSV-Topic-Lookup, welche Entity-Pages (`type: project|person|concept|area`) zum Thema gehoeren, und ergaenze dort den Link in der passenden Sektion.

- `grep "topic-x" 00_Meta/system/vault-index.md | grep "	project	"` zeigt verwandte Projekt-Index-Dateien
- Pro betroffener Entity: Read der Entity-Page, pruefen ob Link bereits existiert, sonst ergaenzen
- **Link-Target:** passende Sektion nach Typ der Inbox-Datei:
  - `decision` → `## Decisions` (anlegen wenn nicht vorhanden)
  - `session-log` → `## Sessions`
  - `meeting` → `## Meetings`
  - `learning` → `## Learnings`
- **Link-Format:** `- [[basename|title]] (YYYY-MM-DD)`, chronologisch sortiert (neueste zuerst). Kein Gedankenstrich, die globale Schreibregel gilt auch für Hub-Einträge.
- **Limit:** max **5 verschiedene Entity-Pages** pro Inbox-Datei (Token-Cap). Das Limit gilt NUR fuer die Anzahl beruehrter Hub-Pages, NICHT fuer die Anzahl Links pro Hub-Page. Hub-Pages listen immer **alle** ihre Kinder vollstaendig.
- Im Bericht erwaehnen: "3 Entity-Pages aktualisiert (mein-projekt.md, Max Mustermann.md, zweites-projekt.md)"

### 6.9. Rename/Delete-Propagation
Wenn der Sweep eine Datei umbenennt oder loescht, muessen vault-weite Referenzen mitgezogen werden, sonst entstehen broken Wikilinks.

**Rename** (Basename-Aenderung):
1. `grep -rl "\[\[alter-basename" ~/Documents/Second-Brain/ --include="*.md"` findet Referenzen
2. Pro Trefferdatei: `Edit` mit `replace_all: true` auf `[[alter-basename]]` → `[[neuer-basename]]` und `[[alter-basename|` → `[[neuer-basename|`
3. TSV-Index `path`-Spalte updaten
4. Im Bericht: "Renamed X → Y, Z Wikilinks updated in N files"

**Delete**:
1. `grep -rl "\[\[basename" ~/Documents/Second-Brain/ --include="*.md"` findet Referenzen
2. Pro Trefferdatei: User fragen "Link auf geloeschte Datei `basename` in `pfad/datei.md` entfernen oder als Fliesstext belassen?". Default-Vorschlag: auf Hub-Pages (`type: project|area`) entfernen, auf Content-Files (Sessions/Meetings) als Fliesstext stehen lassen (Anzeige-Text behalten, `[[]]` entfernen).
3. TSV-Zeile entfernen
4. Im Bericht: "Deleted X, Z Wikilinks resolved in N files"

**Token-Budget:** grep ist billig, Edits nur auf Trefferdateien. Typisch 0-5 Edits pro Rename/Delete.

### 7. Wikilink-Audit (PFLICHT, nach Einsortieren)
Alle in dieser Session verarbeiteten Dateien systematisch pruefen:

a) **Wikilinks extrahieren:** `grep -oh "\[\[[^]]*\]\]"` pro Datei
b) **Gegen TSV-Index abgleichen:** Fuer jeden Link `grep` in `vault-index.md` auf `path` (Dateiname ohne .md), `title`, `aliases`-Spalte
   - Code-Block-Beispiele in Backticks ignorieren
   - Template-Platzhalter ignorieren
c) **Unresolved Links fixen:**
   - Tippfehler: korrekten Dateinamen/Alias ermitteln, Pipe-Syntax verwenden
   - Fehlende Zielseite: User fragen "Soll ich [Seite] anlegen oder als Fliesstext schreiben?"
   - NIEMALS einen Link stehen lassen der ins Nirgendwo fuehrt
d) **Stub-Cleanup:** Inbox auf leere .md Dateien pruefen und loeschen

### 8. Drift-Check
Wenn waehrend des Sweeps ein TSV-Eintrag aufgetaucht ist, dessen Datei auf Disk nicht existiert (oder umgekehrt): Drift-Warnung im Bericht ausgeben und `/brain:rebuild-index` empfehlen.

### 8.5. CLAUDE.md-Implikations-Check

Fuer jede im Sweep verarbeitete Datei mit `type: decision|learning` + `project/<slug>`-Tag: pruefen ob die Erkenntnis als dauerhafte Instruction in CLAUDE.md gehoert.

1. Projekt-Repo via `~/.claude/project-repos.yaml` (oder User-Frage bei erstem Auftreten).
2. `<repo>/CLAUDE.md` lesen. Falls Tag `scope/cross-project`: zusaetzlich `~/.claude/CLAUDE.md`.
3. Einstufen:
   - **JA-Signale:** "Immer X bei Y", "Niemals X", "Default X = Y", "Wenn X dann Y", wiederkehrendes Pattern.
   - **NEIN-Signale:** einmalige Entscheidung (Name, Farbe, Zahl), Kontext-Notiz, Ad-hoc-Beschluss.
4. Bei JA: `grep` Ziel-CLAUDE.md auf Keywords → wenn schon drin: skip. Sonst Diff-Vorschlag an User:
   ```
   Decision "<Titel>" koennte als Instruction in <projekt>/CLAUDE.md.
   + <konkrete Zeile>
   Uebernehmen? [y/n/edit]
   ```
   Bei `y`/`edit`: Edit anwenden, Vault-Datei bleibt (Audit-Trail). Bei `n`: skip.
5. Max 3 Vorschlaege pro Sweep. Weitere im Report listen.

### 9. Vault-Log Eintrag
Append an `00_Meta/system/vault-log.md`:
```
## [YYYY-MM-DD] sweep | N files ingested ([projekt: X, projekt: Y, ...]), M merges, K extracted, L drift-warnings
```

### 10. Bericht
```
=== SORT-INBOX ABGESCHLOSSEN ===
Verarbeitet: [Anzahl] Dateien
Einsortiert: [Liste mit Ziel-Ordnern]
Extrahiert: [Anzahl] Decisions, [Anzahl] Learnings
An bestehende Dateien angehaengt: [Liste]
Entity-Pages aktualisiert: [Liste]
Meeting-Propagation: [M] Items aus [N] Meetings nach STATE.md, [A] ambiguous, [R] ohne Projekt-Match
Reconciliation: [X] Alt-Meetings nachpropagiert, [Y] weiter ambiguous/ohne Repo, [Z] Backlog übrig
Geloescht: [Anzahl] (veraltet/duplikat)
Index-Patches: [Anzahl] Zeilen hinzugefuegt/geaendert/entfernt
Wikilink-Audit: [Anzahl] Links geprueft, [Anzahl] gefixt, [Anzahl] Stubs geloescht
Drift-Warnungen: [Anzahl] (siehe oben)
Vault-Log: aktualisiert
Inbox: [verbleibend] Dateien
```

## Regeln
- NIEMALS neue Top-Level-Tags erfinden (nur aus definierter Taxonomie)
- IMMER Grep auf den TSV-Index VOR Verlinkung (Search Before Link)
- Personen nur via `[[Wikilinks]]` referenzieren (keine human/-Tags)
- Flache YAML-Strukturen
- Hub-and-Spoke: Primaer zu MOCs verlinken, nicht kreuz und quer
- User fragen bevor Dateien geloescht werden
- Tags im Frontmatter IMMER OHNE `#` (das `#` ist NUR fuer Inline-Markdown)
- **Index-Patch nicht vergessen** in Schritt 6.5, sonst veraltet der Index
- **Vault-Log nicht vergessen** in Schritt 9
