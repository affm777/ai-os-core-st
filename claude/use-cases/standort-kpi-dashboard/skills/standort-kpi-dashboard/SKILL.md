---
name: standort-kpi-dashboard
description: Sammelt Standort-Kennzahlen (Umsatz Ist/Plan, Kosten, Abschreibungen, EBIT, Behandlungszahlen) aus Excel-Berichten im Ablage-Ordner (SharePoint/OneDrive) oder lokalen Eingangsordner ein, konsolidiert sie je Standort und Monat und trägt sie auf Wunsch ins Dashboard ein. Triggert bei "Standort-Kennzahlen einsammeln", "KPIs aktualisieren", "Zahlen der Standorte prüfen", "/standort-kpi-dashboard".
when_to_use: |
  Trigger-Phrasen: "Standort-Kennzahlen einsammeln", "KPIs aktualisieren", "Zahlen der Standorte prüfen", "wie stehen die Standorte da", "/standort-kpi-dashboard". Ohne Argument = kompletter Lauf gegen den Ablage-Ordner und den lokalen Eingangsordner. Erster Lauf fragt einmalig nach dem Ablage-Ordner (SharePoint-Bibliothek oder OneDrive-Ordner), danach nicht mehr.
allowed-tools: Bash(bash:*), Bash(python3:*), Bash(python:*), Bash(py:*), Read, Write, Edit
---

# Standort-KPI-Dashboard

Du sammelst Standort-Kennzahlen aus Excel-Berichten ein und zeigst sie als kurze Tabelle im Chat. Zielnutzerin ist die Geschäftsführung bzw. Standortleitung, ohne IT-Hintergrund. Sie sieht nie JSON, Code oder Configs, nur: eine deutsche Zusammenfassungstabelle, eine Ja/Nein-Frage, danach den Dashboard-Reiter „Standorte".

## Grundprinzip: assistiert, nicht autonom

Du sammelst und konsolidierst, zeigst das Ergebnis, und schreibst ERST nach Bestätigung ins Dashboard. Kein Schreibzugriff auf `data/kpi.json` oder das Installations-Skript vor der Bestätigung.

## 0. Tools laden (PFLICHT, ein Aufruf)

Die M365-Connector-Tools sind deferred. Bevor du irgendetwas tust, lade sie in EINEM ToolSearch-Aufruf:

```
ToolSearch: select:mcp__claude_ai_Microsoft_365__sharepoint_folder_search,mcp__claude_ai_Microsoft_365__sharepoint_search,mcp__claude_ai_Microsoft_365__read_resource
```

Erst danach sind die Tools aufrufbar. Excel-Berichte kommen NIE als Mail-Anhang: Excel-Anhänge liefert der Connector nur als Binärdaten zurück ("Binary attachment"), nicht als lesbaren Inhalt. Deshalb wird `outlook_email_search` in diesem Skill nicht verwendet.

## 1. Erstlauf-Setup (nur wenn noch keine Config existiert)

Prüfe, ob neben dieser SKILL.md eine `config.json` liegt (gleicher Ordner). Wenn nicht: einmalig im Chat fragen (auf Deutsch, ein kurzer Block, keine technischen Begriffe):

1. "Wo liegen eure Standort-Berichte als Excel-Dateien? Meistens ist das eine SharePoint-Bibliothek oder ein OneDrive-Ordner, den ihr ohnehin schon für den Berichtsaustausch nutzt (z. B. eine Bibliothek namens 'Standortberichte'). Wie heißt diese Bibliothek bzw. dieser Ordner?" Reicht der Bibliotheks- oder Ordnername (nicht der vollständige Pfad), das genügt, der Skill findet ihn darüber.
2. Nur falls es keine SharePoint-/OneDrive-Ablage gibt: "Alternativ kann ich die Berichte auch aus einem lokalen Ordner auf diesem Rechner lesen, Default `./kpi/eingang/`. Soll ich stattdessen diesen Weg nehmen?"

Hinweis, den du dem Nutzer beim Erstlauf mitgibst (nur wenn die Bibliothek/der Ordner gerade erst neu angelegt wurde): Eine frisch angelegte SharePoint-Site oder -Bibliothek ist etwa 90 Minuten lang über die Suche nicht auffindbar, das ist eine bekannte Indexierungsverzögerung. Bestehende, längst genutzte Bibliotheken sind davon nicht betroffen. Wer also gerade erst eine neue Ablage anlegt, sollte diesen Vorlauf einplanen, bevor der erste Lauf gestartet wird.

Antwort selbst in `config.json` neben der SKILL.md speichern, Schema:
```json
{
  "ablageordner": { "typ": "sharepoint", "name": "Standortberichte" },
  "eingangsordner": null
}
```
`ablageordner.typ` ist `"sharepoint"` oder `"onedrive"`, `ablageordner.name` der Bibliotheks- oder Ordnername aus Frage 1. Wurde stattdessen Frage 2 bejaht, bleibt `ablageordner` `null` und `eingangsordner` trägt den lokalen Pfad (z. B. `"./kpi/eingang/"`). Beide Felder gleichzeitig gesetzt ist ebenfalls zulässig (siehe Schritt 2b, lokaler Ordner bleibt dann Fallback).
Der Nutzer sieht diese Datei nie und muss sie nie anfassen. Bei jedem weiteren Lauf: `config.json` einfach lesen, nicht erneut fragen. Ändert der Nutzer später explizit die Ablage, aktualisierst du die Datei entsprechend.

## 2. Quellen einsammeln

**a) Ablage-Ordner (SharePoint/OneDrive), falls `ablageordner` gesetzt ist:** Mit `sharepoint_folder_search(name: <ablageordner.name>)` den Ordner einmalig auffinden (bei einer eben erst angelegten Bibliothek siehe Hinweis in Schritt 1). `read_resource` auf die zurückgegebene Ordner-URI listet den Inhalt samt itemIds sofort auf, unabhängig vom Suchindex. Für jede darin liegende `.xlsx`/`.xls`-Datei `read_resource` auf die Datei-URI: liefert den Zellinhalt bereits als strukturierten Text. Liefert `read_resource` stattdessen einen Konvertierungsfehler (Graph 406, "couldn't convert this file for text extraction"), NICHT stillschweigend überspringen und NICHT auf demselben Element erneut versuchen (das hilft nachweislich nicht): dem Nutzer konkret melden, dass genau diese Datei bitte einmal neu in die Bibliothek hochgeladen werden soll.

**b) Excel-Dateien im lokalen Eingangsordner, falls `eingangsordner` gesetzt ist:** Alle `.xlsx`/`.xls`-Dateien im `eingangsordner` aus der Config einlesen (lokaler Dateizugriff, kein Connector nötig). Dient als Fallback, wenn keine SharePoint-/OneDrive-Ablage existiert, oder ergänzend für Berichte, die jemand direkt lokal ablegt.

Beide Quellen (soweit konfiguriert) gleichberechtigt behandeln, jede gefundene Excel-Datei durchläuft Schritt 3.

## 3. Parsen

**Aus dem Ablage-Ordner (2a):** Der von `read_resource` gelieferte Text ist bereits der extrahierte Zellinhalt (kein Binärformat, kein `openpyxl` nötig). Die Mapping-Heuristik unten direkt auf diesen Text anwenden.

**Aus dem lokalen Eingangsordner (2b):** Mit `python3` und `openpyxl` öffnen (nur lesen, keine Schreibaktion in diesem Schritt). Unter Windows ist `python3` oft nur der Microsoft-Store-Stub: schlägt der Aufruf fehl, stattdessen `python` oder `py -3` verwenden.

Für beide Quellen gilt danach dieselbe Zuordnungslogik:

- **Standortname** ableiten aus Dateiname, Tabellenblatt-Titel oder einer erkennbaren Kopfzeile — in dieser Reihenfolge prüfen, den ersten eindeutigen Treffer nehmen.
- **Robust gegen abweichende Spaltennamen.** Mapping-Heuristik (Groß-/Kleinschreibung und Umlaute ignorieren):
  - "Erlöse", "Umsatz", "Ist-Umsatz" → `umsatz_ist`
  - "Umsatzziel", "Plan", "Soll", "Budget" → `umsatz_plan`
  - "Kosten", "Ausgaben" → `kosten`
  - "Behandlungen", "Patienten", "Fälle", "Termine" → `behandlungen`
  - "Abschreibungen", "AfA", "Abschreibung" → `abschreibungen`
  - "EBIT", "Betriebsergebnis", "Ergebnis vor Zinsen und Steuern" → `ebit`
  - "Monat", "Periode" → `monat` (auf "YYYY-MM" normalisieren, z. B. aus "Januar 2026" oder "01/2026")
- **Leerzeilen überspringen.**
- **Kennzahlen-als-Zeilen-Layout erkennen:** manche Berichte haben Monate als Spalten und Kennzahlen als Zeilen (transponiert) statt Monate als Zeilen. Beide Layouts erkennen und ins gleiche Zielschema überführen.
- **EBIT wird gelesen, nie gerechnet.** `ebit` kommt ausschließlich aus einer Quelle, die den Wert direkt ausweist. Fehlt er in einer Datei, bleibt das Feld für den betroffenen Monat leer und der Nutzer bekommt in Schritt 4 einen Hinweis darauf. Niemals aus Umsatz Ist minus Kosten (oder minus Abschreibungen) selbst herleiten, das wäre eine eigene Berechnung und keine Übernahme.
- **Was nicht sicher zuzuordnen ist, NIE raten.** Stattdessen die betroffene Spalte/Zeile sammeln und dem Nutzer in Schritt 4 als offene Frage zeigen (z. B. "In der Datei X heißt eine Spalte 'Netto-Ergebnis' — soll das Umsatz Ist, Kosten oder etwas anderes sein?").

## 4. Konsolidieren und Zusammenfassung zeigen

Je Standort und Monat zu einem Datensatz zusammenführen (mehrere Quellen für denselben Standort/Monat: neuere Datei gewinnt, in der Zusammenfassung kurz erwähnen). Dann eine kompakte deutsche Tabelle im Chat:

- Welche Standorte gefunden wurden.
- Welche Monate je Standort vorliegen und welche fehlen (Lücken klar benennen, z. B. "Standort Nord: Jan–Mai, Juni fehlt").
- Offene Zuordnungsfragen aus Schritt 3, falls vorhanden — auf Antwort warten, bevor weitergemacht wird.

## 5. Dashboard-Frage

Nach der Zusammenfassung fragen: **"Soll ich die Kennzahlen ins Dashboard aufnehmen?"**

- **Erstes Ja (Dashboard-Reiter existiert noch nicht):**
  ```bash
  bash <projekt>/kpi/dashboard-modul/apply-kpi-modul.sh
  ```
  Das verankert den Reiter „Standorte" im installierten Dashboard (Nav-Button, Seite, Skript) und nimmt `kpi` in die Datenquellen des Dashboard-Servers auf. Das Skript beendet einen laufenden Dashboard-Server, falls einer läuft, damit die Änderung greift, der nächste `/aios-dashboard`-Aufruf startet ihn automatisch neu.
  Danach `~/.claude/dashboard/data/kpi.json` komplett neu schreiben (dieser Skill ist der einzige Schreiber, kein Read-Merge), Schema siehe unten.
- **Spätere Läufe:** Reiter existiert bereits (prüfe, ob `~/.claude/dashboard/public/aios-kpi.js` existiert) — nur `data/kpi.json` neu schreiben, `apply-kpi-modul.sh` nicht erneut nötig (aber unschädlich, wenn doch aufgerufen: idempotent).
- **Bei Nein:** nur die Chat-Zusammenfassung, keine Datei schreiben.

## Schema von `data/kpi.json`

Ziel: `~/.claude/dashboard/data/kpi.json`, komplette Datei neu schreiben (kein Read-Merge):

```json
{
  "generated_at": "2026-07-28T10:00:00+02:00",
  "zeitraum": { "von": "2026-01", "bis": "2026-06" },
  "standorte": [
    {
      "name": "Standort Nord",
      "monate": [
        { "monat": "2026-01", "umsatz_ist": 42000, "umsatz_plan": 45000,
          "kosten": 31000, "abschreibungen": 3200, "ebit": 7800, "behandlungen": 120 }
      ]
    }
  ],
  "hinweise": []
}
```

- `zeitraum.von`/`bis`: der insgesamt abgedeckte Berichtszeitraum über alle Standorte, Format "YYYY-MM".
- `standorte[].monate`: **fehlende Monate fehlen einfach im Array** — keine Interpolation, keine 0-Füllung. Das Dashboard zeigt eine Lücke sichtbar an statt eines stillschweigenden Nullwerts.
- Einzelne Felder je Monat können ebenfalls fehlen (z. B. `behandlungen` unbekannt) — im Dashboard erscheint dafür ein "?" mit Tooltip, nie eine stille 0.
- `hinweise`: optionale Freitext-Hinweise (z. B. Datenqualitäts-Anmerkungen aus Schritt 3), erscheinen im Dashboard unter der Standort-Übersicht.

**Neuer Standort = neue Datei mit neuem Standortnamen.** Er erscheint beim nächsten Lauf automatisch als weitere Karte im Dashboard, ohne dass an Skill oder Modul etwas geändert werden muss, das ist das Kernversprechen dieses Skills.

## Nächste Ausbaustufe (dokumentiert, nicht vorgebaut)

- Sammelpostfach als zusätzliche Ablage-Quelle (bislang nur der einzelne Ablage-Ordner und der lokale Eingangsordner).
- Automatische monatliche Routine (z. B. per Scheduled Task) statt manuellem Anstoß.
- Soll-Ist-Alerts: automatische Warnung, wenn die Plan-Abweichung eines Standorts eine Schwelle überschreitet.

## Grenzen (hart)

- Kein Schreiben (`data/kpi.json` oder `apply-kpi-modul.sh`) ohne vorherige Bestätigung durch den Menschen.
- Keine Werte oder Spaltenzuordnungen raten, wenn sie nicht sicher lesbar sind, immer als offene Frage zeigen.
- `ebit` niemals selbst aus Umsatz Ist minus Kosten (oder minus Abschreibungen) berechnen, immer nur aus einer Quelle übernehmen, die den Wert direkt ausweist. Fehlt er, bleibt das Feld leer statt hergeleitet.
- Fehlende Monate oder Felder nie mit 0 auffüllen.
- Der Nutzer bekommt nie JSON, Code oder die `config.json` selbst zu sehen, nur die Chat-Tabelle, die Ja/Nein-Frage und den Dashboard-Reiter.
