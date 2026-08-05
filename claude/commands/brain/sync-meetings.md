---
description: Synchronisiere neue Fathom-Meetings in den Obsidian-Vault
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash(ls:*)
  - Bash(mkdir:*)
  - Bash(date:*)
  - Bash(grep:*)
  - Bash(find:*)
  - mcp__claude_ai_Fathom__list_meetings
  - mcp__claude_ai_Fathom__get_identity
argument-hint: "[created_after ISO-Timestamp, z.B. 2026-04-01T00:00:00Z — optional, ueberschreibt .last-fathom-sync]"
---

Du synchronisierst Fathom-Meetings in den Obsidian-Vault unter `~/Documents/Second-Brain/`. Arbeite autonom, frage nur bei harten Fehlern.

## Invarianten (gelten fuer jeden Execution-Mode, jede Situation)

- **Jedes neue Vault-Artefakt landet in `01_Inbox/`.** Kein Write-Pfad ausserhalb
  `~/Documents/Second-Brain/01_Inbox/` und `~/Documents/Second-Brain/00_Meta/system/` ist erlaubt.
  Projekt-Erkennung (Schritt 3, 5b) steuert NUR tags und frontmatter, **niemals den Pfad**.
- STATE.md-Writes nur on-demand. Scheduled = kein Write ausserhalb `Second-Brain/01_Inbox/`.
- Vor jedem Write pruefen: Pfad enthaelt `01_Inbox/`? Wenn nicht → Ausfuehrung stoppen,
  Fehler-Log nach `01_Inbox/YYYY-MM-DD-sync-error.md`.

## Execution-Mode

- **on-demand** (User tippt `/brain:sync-meetings` interaktiv): Rueckfragen OK, STATE.md-Writes erlaubt.
- **scheduled** (Desktop-App Scheduled Task, keine User-Praesenz): autonom, keine Rueckfragen, KEINE Writes ausserhalb `01_Inbox/`.

**Erkennungsregel:** `scheduled`-Mode aktiv, wenn (a) das Skill-Argument das Wort `scheduled` enthaelt ODER (b) im Prompt-Kontext ein Marker wie `SCHEDULED_TASK: true`, `Desktop Scheduled Task`, oder `Autonomer Run` vorkommt. Sonst on-demand.

## Schritt 1, Sync-Stand + Setup

1. `created_after` bestimmen (Prioritaet absteigend):
   a. Skill-Argument (ISO 8601) → `source=argument`.
   b. `Read` auf `~/Documents/Second-Brain/00_Meta/system/.last-fathom-sync` — als absoluten Pfad aufloesen ($HOME expandieren, Scheduled Task hat keine CWD). Datei = eine Zeile ISO 8601 → `source=last-sync`. Bei ENOENT oder Format-Fehler: weiter zu (c), nicht silent.
   c. `date -u -v-7d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "-7 days" +"%Y-%m-%dT%H:%M:%SZ"` (BSD/macOS-Syntax mit GNU-Fallback für Linux/Git-Bash) → `source=fallback-7d`.

   Report PFLICHT: `Sync-Stand-Quelle: <source>`.

2. **On-demand only:** In `.planning/STATE.md` oder `STATE.md` des CWD erledigte Items (`- [x]` oder `~~...~~`) entfernen. **Scheduled: ueberspringen.**
3. Projekt-Mapping laden: `~/.claude/project-repos.yaml` (Slug → Repo-Pfad). Fehlt die Datei: Schritt 5b komplett ueberspringen.

## Schritt 2, Meetings abrufen

`mcp__claude_ai_Fathom__list_meetings` mit `created_after`, `include_summary: true`, `include_action_items: true`, `include_transcript: false`, `max_pages: 3`.

- Leere Liste → Meldung + Ende.
- `>20 Meetings`: on-demand fragen, scheduled alle nehmen.
- API-Fehler: 3x retry mit 5s, dann abbrechen + `01_Inbox/YYYY-MM-DD-sync-error.md` mit Fehlermeldung.

## Schritt 3, Vault-Kontext laden (einmalig)

- Personen: `ls 05_Contacts/People/ 05_Contacts/Organizations/` + aus `00_Meta/system/vault-index.md` Aliases (`awk -F'\t' '$3=="person" || $3=="organization"'`).
- Projekte: aus jedem `02_Projects/<slug>/<slug>.md` Titel + `aliases:` aus Frontmatter.

## Schritt 4, Delegation + Sortierung

**Sortierung (PFLICHT vor Schritt 5):** Meetings nach `created_at` aufsteigend (ASC) sortieren. Damit ist der zuletzt verarbeitete Meeting-Timestamp automatisch der juengste und Schritt 5g (inkrementeller Timestamp-Write) bleibt monotone increasing.

**Threshold:**
- **1-10 Meetings** → alles im Hauptkontext (effizient bis mittelgross).
- **>10 Meetings** → `general-purpose` Sub-Agent spawnen, Split nach Datum (chronologisch). Main fuehrt Schritt 5b (STATE.md-Writes) danach gebundelt aus.

## Schritt 5, Pro Meeting

### 5.0 Duplikat-Check (semantisch, vault-weit)

URL-Match ist unzuverlaessig (calls-id vs. share-token). Datums-Grep + semantischer Vergleich.

**Kandidaten finden:**
```bash
grep -rlE "^created_date: <YYYY-MM-DD>" ~/Documents/Second-Brain/ --include="*.md" 2>/dev/null \
  | xargs grep -l "^type: meeting" 2>/dev/null
```
Keine Kandidaten → weiter zu 5a.

**Semantischer Vergleich** (pro Kandidat `Read limit: 60` → Frontmatter + Anfang):
- **Klar dasselbe** (Titel semantisch gleich + Attendees decken sich + Thema passt) → SKIP. Report: `Skipped: <rec_id> "<title>" → <pfad>`.
- **Klar unterschiedlich** → weiter zu 5a.
- **Unklar** (gleicher Titel, Zeit-/Scope-Differenz) → schreiben MIT `dedup_warning: true` im Frontmatter und Callout im Body:
  ```
  > [!warning] Moegliches Duplikat
  > Inhaltliche Ueberlappung mit [[<kandidat-basename>]]. Bitte pruefen und ggf. mergen oder Flag entfernen.
  ```

### 5a-e Meeting-File schreiben (bei keinem Duplikat)

**WRITE-PATH-REGEL (unveraenderlich, keine Ausnahmen):**
Pfad: `~/Documents/Second-Brain/01_Inbox/YYYY-MM-DD-meeting-<slug>.md`
Slug: lowercase, `[a-z0-9-]`, Umlaute zu ae/oe/ue/ss.
Das Projekt-Matching (Schritt 3) steuert NUR `project/<slug>`-Tag im Frontmatter, nicht den Pfad.
Kontrolle vor jedem Write: Pfad enthaelt `01_Inbox/`? Wenn nicht → kein Write, stattdessen
`01_Inbox/YYYY-MM-DD-sync-error.md` mit Beschreibung des abgewiesenen Pfads.

**Frontmatter (exakte Reihenfolge):**
```yaml
---
title: "<Meeting-Titel>"
created_date: <YYYY-MM-DD>
type: meeting
status: draft
tags:
  - type/meeting
  - project/<slug wenn erkannt, siehe 5b-Regeln>
attendees:
  - "[[Person-Name]]"
source: fathom
fathom_recording_id: <id>
fathom_url: <calls-url von MCP>
duration_min: <if derivable>
propagated_to_state: false
dedup_warning: false  # true setzen wenn Schritt 5.0 "unklar" ergab
aliases: []
---
```

**Body (Deutsch, auch wenn Meeting EN; dann `source_language: en` ergaenzen):**
```markdown
# <Titel>

**Datum:** <YYYY-MM-DD>
**Teilnehmer:** [[Person1]], [[Person2]]
**Fathom-Link:** [Recording](<url>)

## Zusammenfassung
<kurz, Deutsch, keine Gedankenstriche, echte Umlaute>

## Entscheidungen
<nur wenn klar: WAS/WER/WARUM>

## Action Items
- [ ] <Beschreibung> ([[Assignee]], Fälligkeit: <wenn genannt>)

## Offene Fragen
<nur wenn klar erkennbar>
```

KEIN Transkript. Namenskonflikt: `-<rec_id-kurz>` anhaengen.

**Attendees-Linking:** Mapping aus Schritt 3. Bei Match `[[Dateiname]]`, sonst `[[Person-Name]]`. Keine Placeholder-Files anlegen.

### 5f Decisions extrahieren

Nur bei klar entschiedenen (nicht angedacht/vertagt) Punkten eigene Datei `01_Inbox/YYYY-MM-DD-decision-<slug>.md` mit `type: decision`, `validity: active`, `source_meeting: "[[meeting-slug]]"`. Body: Kontext, Optionen, Entscheidung, Begruendung, Quelle.

### 5g Inkrementeller Timestamp-Write (PFLICHT, nach jedem Meeting)

Sofort nach erfolgreichem 5a-e Write des Meeting-Files: `00_Meta/system/.last-fathom-sync` mit dem `created_at` (ISO 8601 UTC) des **gerade verarbeiteten** Meetings ueberschreiben. **Ein Edit pro Meeting.**

Begruendung: Wenn das Skill mittendrin abbricht (Tool-Fehler, Context-Limit, Scheduled-Task-Kill), ist der Timestamp dennoch auf dem Stand des letzten erfolgreich verarbeiteten Meetings. Naechster Run holt nur das, was wirklich noch fehlt. **Schritt 6 wird dadurch zum Sanity-Check, nicht zum sole-write.**

**Monotone Guard:** Da Schritt 4 nach `created_at` ASC sortiert, ist der jeweils geschriebene Timestamp automatisch >= dem vorherigen. Bei out-of-order Lieferung trotz Sortierung (defensiv): bestehenden Wert in `.last-fathom-sync` lesen, nur ueberschreiben wenn neuer Wert > alter Wert.

## Schritt 5b, STATE.md-Propagation (on-demand only)

**Scheduled: komplett ueberspringen.**

**Meeting-Guard:** Frontmatter `propagated_to_state` pruefen.
- `true` → SKIP.
- `false` / `pending` / fehlt → weiter, danach auf `true` setzen.

**Projekt-Match** (erste Regel gewinnt):
1. Titel enthaelt Projekt-Slug/Alias (case-insensitive, Wort-Grenze).
2. Mind. 2 Attendees sind im Projekt-Hub als `[[Wikilink]]`.
3. Mehrere Treffer → ambiguous, skip.
4. Keiner → skip.

**Item-Dedup-Check (PFLICHT vor jedem Append):**
1. `<repo>/.planning/STATE.md` einmal lesen. Alle `- [ ]`-Zeilen unter `### Pending Todos` sammeln.
2. Pro Action Item: Signatur = erste 3-5 inhaltliche Woerter lowercase (Nouns/Verben, Fuellwoerter raus, Issue-Nummern optional).
3. Substring-Match (case-insensitive) der Signatur gegen gesammelte Zeilen.
4. **Match** → Skip, im Report als `skipped-dup`.
5. **Kein Match** → Append.

**Write:** `<repo>/.planning/STATE.md` → `### Pending Todos` → passender `#### `-Themen-Cluster. Cluster sind Stränge (Thema), niemals Herkunft: bestehenden Cluster wählen, der das Item fachlich trifft. Passt keiner eindeutig → `#### Aus Meetings` nur als Transit (wird bei /wrap-up oder on-demand-Sweep in Stränge aufgelöst). Die Herkunft steht am Item selbst:
```
- [ ] <Beschreibung> ([[<meeting-basename>]], Owner: <Assignee>)
```
Danach `propagated_to_state: true` im Meeting-File setzen (auch wenn alle Items Duplikate waren).

## Schritt 6, Sync-Timestamp Sanity-Check

Schritt 5g hat den Timestamp inkrementell nach jedem Meeting geschrieben. Hier nur Final-Verification:

1. `Read` auf `00_Meta/system/.last-fathom-sync`.
2. Vergleiche mit `created_at` des juengsten verarbeiteten Meetings.
3. **Match** → OK, nichts zu tun.
4. **Mismatch (z.B. weil 5g uebersprungen wurde)** → letzte Korrektur: Edit `.last-fathom-sync` auf den juengsten verarbeiteten Wert + im Report `Sync-Timestamp-Korrektur in Schritt 6` vermerken.

NIEMALS `current time` schreiben, immer `created_at` des juengsten verarbeiteten Meetings (partial-fail-safe).

## Schritt 7, Report

```
Sync abgeschlossen: <N> gefunden, <verarbeitet> verarbeitet, <skipped> uebersprungen.

Sync-Stand-Quelle: <argument|last-sync|fallback-7d>
created_after: <ISO>

Neue Files in 01_Inbox/:
- <liste>

Skipped (Duplikate):
- <rec_id> "<title>" → <pfad>

Decisions: <N>, Action Items: <N>
STATE.md-Updates: <slug>: <N> Items (Cluster: <liste>, davon <M> im Transit "Aus Meetings")
STATE.md-Cleanup: <M> erledigte entfernt (wenn on-demand)

Sync-Timestamp: <ISO>
Errors: <liste rec_id + reason, falls vorhanden>
```

## Grenzen

- Writes nur nach `~/Documents/Second-Brain/` und Projekt-Repos (nur on-demand, nur STATE.md).
- Existierende Files nie ueberschreiben (Namenskonflikt: `-<rec_id-kurz>` anhaengen).
- Keine Placeholder-Personen-Files.
- KEIN Transkript im Vault. Referenz via `fathom_url`.
- Schreibstil: echte Umlaute, keine Gedankenstriche.
- `propagated_to_state: false` muss bei jedem neuen Meeting initialisiert sein.
- KEIN `.md`-Sync-Log im Vault. Report ist Conversational-Output.

## Projekt-Mapping (Source-of-Truth)

- Repo-Pfade: `~/.claude/project-repos.yaml`
- Titel + Aliases: `02_Projects/<slug>/<slug>.md` Frontmatter
- Attendees pro Projekt: `[[Wikilinks]]` im Hub-Body unter "Team" oder aehnlich

Neues Projekt: Zeile in `project-repos.yaml` + Hub via Template. Kein Skill-Edit.
