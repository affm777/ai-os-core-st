# /brain:health-check — Vault Health-Check mit interaktivem Fix

Du fuehrst einen Health-Check des Vaults durch, schreibst einen Report, und bietest dann interaktiv an, die gefundenen Issues zu fixen. UX-Muster analog zu `/wrap-up`: erst zeigen was gefunden wurde, dann pro Kategorie auf Go warten, dann Aenderungen ausfuehren.

**Execution-Mode:** Enthaelt das Skill-Argument `scheduled` (oder der Prompt-Kontext den Scheduled-Run-Header `<scheduled-task ...>` / "This is an automated run of a scheduled task"), laeuft NUR die Report-Phase: Report nach `00_Meta/system/lint-reports/` schreiben, Vault-Log-Eintrag, dann ENDE. Keine Fix-Phase, keine Rueckfragen, keine Writes ausser Report + Vault-Log.

## Voraussetzung

`00_Meta/system/vault-index.md` muss existieren und aktuell sein. Falls Drift-Verdacht: zuerst `/brain:rebuild-index` empfehlen.

## Checks

Fuehre alle Checks via `grep` und gezielte Sub-Agent-Reads aus, NIE den ganzen Vault in den Kontext laden.

### 1. Orphans (Dateien ohne eingehende Links)

- Fuer jede Datei im Index (ausser MOCs und Meta-Dateien): pruefe ob es vault-weit irgendwo `[[dateiname]]` oder `[[alias]]` gibt
- `grep -r "\[\[<filename-without-md>" ~/Documents/Second-Brain/ -l` pro Kandidat (Sub-Agent-Job, Batches)
- Orphans listen, aber KEIN Auto-Delete

### 2. Broken Wikilinks

- `grep -roh "\[\[[^]]*\]\]" ~/Documents/Second-Brain/ --include="*.md"` extrahiert alle Wikilinks
- Fuer jeden Link: pruefe ob das Ziel als `path`, `title` oder in der `aliases`-Spalte des TSV-Index existiert
- Code-Block-Beispiele (in Backticks) und Template-Platzhalter ausschliessen
- Liste der toten Links + Quell-Datei

### 3. Stale Decisions

- `grep "	decision	" 00_Meta/system/vault-index.md` plus Frontmatter-Check auf `validity: active` und `updated` aelter als 90 Tage
- Liste der Stale-Kandidaten zur User-Review

### 4. Missing Cross-Refs

- Topics-Spalte im TSV gruppieren: Dateien mit gleichem Topic sammeln
- Pro Topic-Gruppe: pruefen ob die Dateien sich gegenseitig verlinken (`grep` auf Wikilinks)
- Fehlende Links als Vorschlaege ausgeben

### 5. Contradictions

- Decisions zum gleichen Topic finden (Topics-Spalte gruppieren)
- Sub-Agent: lies die Entscheidungs-Texte und pruefe auf Widersprueche
- Verdachtsfaelle listen, KEIN Auto-Fix

### 6. Index-Drift

- TSV-Eintraege gegen `find` auf Disk abgleichen
- Index-Eintrag ohne Datei → "Datei wurde ausserhalb /brain:sort-inbox geloescht"
- Datei ohne Index-Eintrag → "Datei wurde ausserhalb /brain:sort-inbox angelegt"
- Bei Drift: `/brain:rebuild-index` empfehlen

### 7. Projekt-Repos-Drift (YAML ↔ Vault)

Pruefe `~/.claude/project-repos.yaml` gegen die Vault-Projekt-Hubs. Drei Drift-Arten:

- **YAML-Eintrag ohne Vault-Hub**: `<slug>` steht in YAML, aber `02_Projects/<slug>/<slug>.md` existiert nicht → Hub-Anlage-Vorschlag
- **Vault-Hub ohne YAML-Eintrag**: Datei `02_Projects/<slug>/<slug>.md` existiert, aber `<slug>:` fehlt in YAML → YAML-Eintrag-Vorschlag (User muss Repo-Pfad liefern, oder explizit "kein Repo" sagen)
- **YAML-Pfad existiert nicht auf Disk**: `<slug>: <path>` zeigt auf nicht-existenten Ordner → Pfad-Korrektur oder Zeile entfernen

Wenn `project-repos.yaml` gar nicht existiert: Check ueberspringen, nicht als Fehler werten.

## Output

Schreibe Report nach `~/Documents/Second-Brain/00_Meta/system/lint-reports/YYYY-MM-DD-lint.md`:

```markdown
---
title: "Vault Lint Report YYYY-MM-DD"
type: meta
created_date: YYYY-MM-DD
---

# Vault Lint Report YYYY-MM-DD

## Summary
- Dateien gescannt: N
- Orphans: X
- Broken Wikilinks: Y
- Stale Decisions: Z
- Missing Cross-Refs: A
- Contradictions: B (Verdacht)
- Index-Drift: C
- Projekt-Repos-Drift: D

## Orphans
- ...

## Broken Wikilinks
- `[[xyz]]` in `path/to/file.md` -> Ziel existiert nicht (Vorschlag: ...)

## Stale Decisions
- ...

## Missing Cross-Refs
- `file-a.md` und `file-b.md` teilen Topic `xxx`, verlinken aber nicht. Vorschlag: gegenseitig verlinken.

## Contradictions (Review noetig)
- ...

## Drift
- ...

## Empfohlene naechste Schritte
- ...
```

## Interactive Fix Phase

Nach dem Report Summary zeigen und dann pro Kategorie mit Issues den User fragen. Reihenfolge: **Drift → Projekt-Repos-Drift → Broken Wikilinks → Missing Cross-Refs → Orphans → Stale Decisions → Contradictions**.

### Ablauf pro Kategorie

1. Summary-Zeile: `Kategorie X: N Issues gefunden.`
2. Frage: `Soll ich diese N Themen angehen? [j/n/zeigen]`
   - **j** → iteriere durch alle Issues, fuehre Fix-Aktion aus (siehe unten). Bei Ambiguitaet pro Issue einzeln nachfragen.
   - **n** → Kategorie ueberspringen, im Report vermerken `skipped by user`
   - **zeigen** → kompakte Liste aller Issues ausgeben (max 20 sichtbar, Rest als "+N weitere"), dann erneut fragen

### Fix-Aktionen

**Drift**
- Hinweis: "Bitte `/brain:sort-inbox` laufen lassen, der raeumt Index und Inbox auf."
- Nicht automatisch ausloesen, weil Sweep eigene Interaktion hat.

**Projekt-Repos-Drift**
- Pro Drift-Art:
  - **YAML ohne Vault-Hub**: Frage "Soll ich Vault-Hub `02_Projects/<slug>/<slug>.md` via Projekt-Template anlegen? [j/n]" — bei `j`: Template kopieren mit Platzhaltern, User faellt Platzhalter-Fuellen spaeter.
  - **Hub ohne YAML**: Frage "Soll ich `<slug>` in YAML eintragen? Repo-Pfad (absolut) oder 'nein' fuer rein-Vault-Projekt?" — bei Pfad-Angabe: Zeile appenden (Duplikat-Schutz). Bei 'nein': im Report als "Vault-only, kein YAML-Eintrag gewollt" markieren, nicht erneut vorschlagen.
  - **YAML-Pfad tot**: zeige Eintrag, frage "Pfad korrigieren (neuer Pfad) oder Zeile entfernen [p/r]?" — entsprechend editieren.
- Nichts stumm aendern, jede Schreib-Operation einzeln bestaetigen.

**Broken Wikilinks**
- Fuzzy-Match im TSV-Alias-Pool: `grep -i` auf Basename + `aliases`-Spalte
- Bei eindeutigem Match (genau 1 Treffer): `Edit` mit `replace_all: false` auf `[[alt]]` → `[[neu]]` oder Pipe-Syntax. User bestaetigt kurz ("OK?").
- Bei keinem Match: frage "Soll ich Zielseite `xyz` anlegen oder den Link als Fliesstext schreiben?"
- Bei mehreren Matches: zeige Kandidaten, User waehlt.

**Missing Cross-Refs**
- Pro Topic-Cluster: ergaenze gegenseitige Wikilinks in den Files, in passende Sektion (`## Verwandt` oder bestehende Sektion).
- Bei Hub-Page-Kandidaten: bevorzuge Ergaenzung in Hub-Page (einseitig reicht oft).

**Orphans**
- Hub-Page per TSV-Topic-Match ermitteln: `grep "topic-x" 00_Meta/system/vault-index.md | grep "	project\|	area	"`
- Bei **einem** passenden Hub: Link automatisch in passende Sektion (`## Decisions`/`## Sessions`/`## Meetings`/`## Learnings`, anlegen wenn nicht vorhanden), Format `- [[basename|title]] (YYYY-MM-DD)`, chronologisch sortiert (neueste zuerst).
- Bei **mehreren** passenden Hubs: pro Issue User fragen welche Hub-Page.
- Bei **keinem** passenden Hub: als "accepted orphan" im Report markieren, keine Aktion.

**Stale Decisions**
- Pro Decision kurzer Title + letztes Datum anzeigen.
- Frage: `Noch gueltig [j] / superseded [s] / archiviert [a] / zeigen [z]?`
  - **j** → `updated`-Feld im Frontmatter auf heute setzen (Refresh)
  - **s** → `validity: superseded` setzen. User fragen ob eine neuere Decision als Ersatz verlinkt werden soll.
  - **a** → `validity: archived` setzen
  - **z** → ganze Decision-Datei zeigen, dann erneut fragen

**Contradictions**
- Read-only, User-Review noetig. Nicht auto-fixen.
- Pro Verdachtsfall: betroffene Dateien listen, kurzer Hinweis auf den Widerspruch, User entscheidet manuell.

### Re-Check am Ende

Nach allen gefixten Kategorien: leichtgewichtiger Re-Check nur der betroffenen Kategorien (nicht kompletter Lint). Summary ausgeben:

```
=== VAULT LINT FIX-PHASE ABGESCHLOSSEN ===
Detected: N (Drift: x, Repos-Drift: d, Broken: y, Missing-Refs: z, Orphans: a, Stale: b, Contra: c)
Fixed:    M
Skipped:  K (by user)
Remaining: L
Report:   00_Meta/system/lint-reports/YYYY-MM-DD-lint.md
```

## Vault-Log Eintrag

Append an `00_Meta/system/vault-log.md`:
`## [YYYY-MM-DD] lint | N detected, M fixed, K skipped`

## Regeln

- **Detect ist immer automatisch, Fix braucht immer Go des Users** (j/n pro Kategorie).
- Nutze Sub-Agents fuer alle vault-weiten Reads in der Detect-Phase.
- Wenn ein Check mehr als ~50 Treffer liefert: Report zeigt die ersten 20, Rest als "+N weitere". In der Fix-Phase bearbeite ALLE Treffer wenn User j sagt (nicht nur die im Report gelisteten).
- Token-Budget: In der Fix-Phase nur Dateien mit Issues lesen, nie den ganzen Vault.
- NIEMALS stille Fixes: jede Schreib-Operation muss dem User angekuendigt werden.
