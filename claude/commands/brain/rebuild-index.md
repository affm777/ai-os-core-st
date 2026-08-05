# /brain:rebuild-index — Vault-Index komplett neu aufbauen

Du baust den maschinen-gepflegten Vault-Index `00_Meta/system/vault-index.md` from scratch neu auf. Wird genutzt bei Erstinstallation, Drift-Verdacht oder als woechentliche Wartung.

## Wichtig: Sub-Agent fuer den Scan (PFLICHT)

Der Scan ueber alle Vault-Dateien belastet den Hauptkontext. Delegiere die Frontmatter-Extraktion an einen `general-purpose` Sub-Agent. Er liefert nur das fertige TSV zurueck, nicht die Roh-Dateien.

**Skalierungs-Regel:**
- Vault < 500 Files → 1 Sub-Agent
- Vault 500-2000 Files → 1 Sub-Agent (ok), aber bei Token-Druck splitten
- Vault > 2000 Files → **mehrere Sub-Agents in Batches** (z.B. 500 Files pro Batch), Main fuehrt TSV-Blocks zusammen via Append
- Bei Aufteilung: Jedes Batch bekommt eine disjunkte File-Liste, liefert eigenen TSV-Block, Main concatenated in der Reihenfolge

Hintergrund: Folgt dem `Batch-Delegation mit Report-Only-Return`-Pattern des `skill-designer`-Agents.

## Schritte

1. **Vault scannen**
   - `find ~/Documents/Second-Brain -name "*.md" -type f` ausfuehren
   - Ausschliessen: `01_Inbox/**`, `00_Meta/Templates/**`, `00_Meta/system/vault-index.md`, `00_Meta/system/vault-log.md`, `00_Meta/system/lint-reports/**`, `.obsidian/**`, `.trash/**`
   - Anzahl ermitteln (`wc -l`)

1.5. **Backup**
   - Wenn `00_Meta/system/vault-index.md` existiert: `cp 00_Meta/system/vault-index.md 00_Meta/system/backups/vault-index.md.bak.YYYY-MM-DD`
   - Wenn der Backup-Ordner fehlt: `mkdir -p 00_Meta/system/backups` zuerst
   - Wenn alter Index nicht existiert (Erstinstallation): skip
   - Backup-Pfad im Final-Bericht erwaehnen
   - Garbage-Collection optional: alte `.bak.*` Files > 30 Tage manuell pruefen, kein Auto-Delete

2. **Frontmatter-Extraktion via Sub-Agent**
   Spawn einen `general-purpose` Sub-Agent mit folgendem Auftrag:
   - Lies die Frontmatter (zwischen den `---` Markern) jeder Datei in der Liste
   - Extrahiere: `title`, `type`, `tags`, `aliases`, `created_date`/`updated`
   - Vergib pro Datei 1-3 **Topics**: fuzzy semantische Schlagwoerter (lowercase, bindestrich-separiert), abgeleitet aus Titel + Tags + ggf. ersten 500 Zeichen Body. Topics sind NICHT identisch mit Tags. Beispiele: `chromium-rendering`, `claude-md-config`, `canvas-frameworks`, `ai-coaching`, `vault-tooling`. Gleiche Themen MUESSEN gleiche Topics bekommen (Konsistenz wichtiger als Praezision).
   - Liefere TSV zurueck mit Spalten: `path<TAB>title<TAB>type<TAB>tags<TAB>aliases<TAB>topics<TAB>updated`
     - `path` relativ zu `~/Documents/Second-Brain/`
     - `tags` als space-separierte Liste, kein Array-Markup
     - `aliases` als `|`-getrennt, `-` wenn leer
     - `topics` als `|`-getrennt, `-` wenn keine vergeben werden konnten
     - `updated` als ISO-Datum (YYYY-MM-DD)
   - WICHTIG: KEINE Tabs in den Werten selbst. Falls ein Titel einen Tab enthielte, durch Space ersetzen.

3. **Index-Datei schreiben**
   - Header-Frontmatter setzen: `updated: <heute>`, `file_count: <N>`
   - TSV-Header-Zeile + alle Datenzeilen in den ```tsv Code-Block schreiben
   - Komplette Ueberschreibung von `00_Meta/system/vault-index.md`

4. **Vault-Log Eintrag**
   - Append an `00_Meta/system/vault-log.md`:
     `## [YYYY-MM-DD] reindex | full rebuild, N files, M unique topics`

5. **Bericht**
   ```
   === VAULT REINDEX FERTIG ===
   Dateien indiziert: N
   Unique Topics: M
   Index:   00_Meta/system/vault-index.md
   Backup:  00_Meta/system/backups/vault-index.md.bak.YYYY-MM-DD (alter Index, manuell loeschen wenn nicht mehr noetig)
   Log:     vault-log.md aktualisiert
   ```

## Regeln

- IMMER via Sub-Agent scannen, NIEMALS Frontmatter im Hauptkontext lesen
- Bestehende `vault-index.md` wird komplett ueberschrieben (kein Merge-Versuch)
- Topics konsistent vergeben: bei Unsicherheit lieber bestehendes Topic recyceln als neues erfinden
- Keine Auto-Topics wenn unklar, lieber `-` setzen
- Bei sehr grossen Vaults (>2000 Dateien): Sub-Agent in Batches arbeiten lassen (z.B. 500 Dateien pro Batch), TSV-Blocks zusammenfuehren
