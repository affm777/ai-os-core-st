# Ein Kennzahlen-Reiter, ohne eine Zeile Code je Standort

Bei mehreren Standorten kommen die Monatszahlen (Umsatz Ist/Plan, Kosten, Behandlungszahlen) selten einheitlich rein: mal aus einer SharePoint-Bibliothek, mal aus einem lokalen Eingangsordner, mit unterschiedlichen Spaltennamen, manchmal transponiert (Monate als Spalten statt Zeilen). Bis daraus ein verlässlicher Standort-Vergleich wird, sitzt jemand meist von Hand an mehreren Excel-Dateien gleichzeitig.

Dieses Bundle sammelt die Excel-Berichte aus dem Ablage-Ordner (SharePoint/OneDrive) und dem lokalen Eingangsordner ein, erkennt das jeweilige Layout, konsolidiert je Standort und Monat, und trägt das Ergebnis nach Bestätigung in einen eigenen Dashboard-Reiter „Standorte" ein. Neue Standorte erscheinen automatisch als weitere Karte, ohne dass am Skill oder am Dashboard-Modul etwas geändert werden muss.

```
Ablage-Ordner + Eingangsordner    Claude                          Dashboard
──────────────────────────       ──────                          ─────────
Excel-Berichte je Standort  →    /standort-kpi-dashboard     →   Reiter „Standorte"
(unterschiedliche Layouts)       liest, mappt Spalten,             Kachelübersicht +
                                  konsolidiert je Monat             Verlaufsgrafik je Standort
                                  (Vorschlag → Bestätigung)
```

## Konventionen in dieser Anleitung

- **„Sag Claude:"** + Block, du tippst das in den **Chat** von Claude Code.
- Der Ordner `skills/standort-kpi-dashboard/` zieht als `~/.claude/skills/standort-kpi-dashboard/` in dein globales Setup (in jeder Claude-Code-Session verfügbar, im Slash-Menü und im Dashboard unter Skills & Commands sichtbar), der Ordner `dashboard-modul/` bleibt in deinem Arbeitsordner liegen und wird beim ersten „Ja, ins Dashboard aufnehmen" vom Skill selbst ausgeführt.

## Voraussetzungen

- Standard-Bootstrap (`bash mac/bootstrap.sh`, Windows: `bash windows/bootstrap.sh`) ist durchgelaufen, inklusive Dashboard (`/aios-dashboard`).
- **Microsoft-365-Connector** verbunden, mit Admin-Zustimmung für den Tenant, für den Zugriff auf die SharePoint-Bibliothek bzw. den OneDrive-Ordner. Läuft auch ohne Adminrolle des Nutzerkontos.
- Python mit `openpyxl` (zum Parsen der Berichte): `pip3 install openpyxl`, falls nicht vorhanden.
- **Wichtig:** Excel-Anhänge sind über den M365-Connector nicht inline lesbar ("Binary attachment"). Berichte, die als Excel-Datei reinkommen, laufen deshalb ausschließlich über einen Ablage-Ordner (SharePoint-Bibliothek oder OneDrive-Ordner), ersatzweise über einen lokalen Eingangsordner, nie als Mail-Anhang. PDF-Anhänge sind davon nicht betroffen und inhaltlich lesbar.

## Schritt 1 — Bundle installieren

Sag Claude (er kennt sein Working-Verzeichnis und legt die Dateien passend ab):

```
Lade das Use-Case-Bundle "standort-kpi-dashboard" aus meinem Setup-Repo:
~/ai-os-core/claude/use-cases/standort-kpi-dashboard

Installiere es global, damit es in jedem Projekt zur Verfügung steht:
- skills/standort-kpi-dashboard/  → ~/.claude/skills/standort-kpi-dashboard/
- dashboard-modul/                → ./kpi/dashboard-modul/

Bestätige mir, welche Dateien angekommen sind.
```

Danach `/exit` und `claude` neu starten, damit der Skill geladen wird.

## Schritt 2 — Erster Lauf

Sag Claude:

```
Sammel die Standort-Kennzahlen ein und zeig mir, wie die Standorte dastehen.
```

Der Skill fragt beim allerersten Lauf einmal kurz nach dem Ablage-Ordner für die Standort-Berichte (Name der SharePoint-Bibliothek oder des OneDrive-Ordners, ersatzweise ein lokaler Eingangsordner, Default `./kpi/eingang/`), danach nie wieder. Anschließend läuft er durch:

1. sammelt Excel-Berichte aus dem hinterlegten Ablage-Ordner und, falls konfiguriert, aus dem lokalen Eingangsordner,
2. erkennt Standortname und Spaltenbedeutung robust gegen abweichende Bezeichnungen und gegen transponierte Layouts, fragt bei Unsicherheit statt zu raten,
3. konsolidiert je Standort und Monat, zeigt fehlende Monate als sichtbare Lücke statt einer stillen 0,
4. fragt „Soll ich die Kennzahlen ins Dashboard aufnehmen?" und richtet beim ersten Ja den Reiter „Standorte" im Dashboard ein (Nav-Button, Seite, Skript-Einbindung), danach genügt für jeden weiteren Lauf das Neuschreiben der Datenbasis.

## Belegte Messergebnisse

Aus einem End-to-End-Test mit Testdaten für vier Standorte über sechs Monate, Ground Truth in einem Manifest:

- **24 von 24 gelieferten Standort-Monaten exakt** gegen das Manifest übernommen.
- Ein Standort mit abweichendem Format (andere Spaltennamen, transponiertes Layout) wurde korrekt gemappt ("Erlöse" → Umsatz Ist).
- Eine Leerzeile mitten in den Daten eines Standorts wurde korrekt übersprungen.
- Ein fehlender Monat bei einem Standort wurde als sichtbare Lücke gerendert, keine Interpolation, keine stille 0. Das Aggregat wich vom Manifest-Aggregat exakt um diesen nie gelieferten Monat ab, das Dashboard zeigte korrekt nur das tatsächlich Gelieferte.
- Ein neuer, nachgelieferter Standort erschien ohne Code-Änderung als vierte Karte, die Kacheln rechneten live mit.
- Die Erst-Lauf-Installation des Dashboard-Reiters als lokales Delta funktionierte inklusive eines dafür notwendigen Patches am Dashboard-Server.

## Grenzen

- **Excel-Anhänge sind nicht inline lesbar** über den M365-Connector. Berichte kommen deshalb ausschließlich über einen Ablage-Ordner (SharePoint-Bibliothek oder OneDrive-Ordner) oder ersatzweise einen lokalen Eingangsordner, nie als Mail-Anhang.
- Eine frisch angelegte SharePoint-Site oder -Bibliothek ist rund 90 Minuten lang über die Suche nicht auffindbar (Indexierungsverzögerung). Bestehende, längst genutzte Bibliotheken sind davon nicht betroffen.
- Ein Sammelpostfach als Ablage-Quelle wurde nicht getestet.
- Fehlende Werte werden nie geraten oder mit 0 aufgefüllt, immer als offene Frage oder sichtbare Lücke gezeigt.

## Nächste Ausbaustufe (dokumentiert, nicht vorgebaut)

- Sammelpostfach als zusätzliche Ablage-Quelle (bislang nur der einzelne Ablage-Ordner und der lokale Eingangsordner).
- Automatische monatliche Routine (z. B. per Scheduled Task) statt manuellem Anstoß.
- Soll-Ist-Alerts: automatische Warnung, wenn die Plan-Abweichung eines Standorts eine Schwelle überschreitet.

## Was im Bundle liegt

```
standort-kpi-dashboard/
├── README.md                              ← das hier
├── skills/
│   └── standort-kpi-dashboard/SKILL.md    ← sammelt, mappt, konsolidiert, schreibt Dashboard-Daten
└── dashboard-modul/
    ├── aios-kpi.js                        ← Dashboard-Reiter "Standorte" (Kacheln, Zeitraum-Filter, Standort-Ranking, Trendpfeile, Verlaufsgrafiken)
    └── apply-kpi-modul.sh                 ← verankert den Reiter im installierten Dashboard (einmalig, idempotent)
```
