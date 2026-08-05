# Rechnungen aus dem Postfach direkt in die OPOS-Liste

Rechnungen kommen per Mail rein, PDF-Anhang oder nur als Text, und müssen von Hand in die offene-Posten-Liste (OPOS) übertragen werden: Zahlungsempfänger, IBAN, Rechnungsnummer, Betrag, Beschreibung, Datum. Bei mehreren Standorten und mehreren Dutzend Rechnungen im Monat ist das eine der Buchhaltungsaufgaben, die am meisten Zeit kostet und am anfälligsten für Zahlendreher ist.

Dieses Bundle übernimmt das Übertragen, nicht die Buchführung selbst. Der Skill sucht Rechnungs-Mails im Postfach, die seit dem letzten Lauf dazugekommen sind, liest die Anhänge inhaltlich, schlägt Buchungszeilen vor und trägt sie erst nach Bestätigung in die Excel-Liste ein. Das Postfach selbst bleibt unangetastet, es wird nichts markiert oder verschoben. Die Zielnutzerin (Buchhaltung, ohne IT-Hintergrund) sieht dabei nie JSON oder Code: nur eine Vorschlagstabelle im Chat, eine Ja/Nein-Bestätigung, danach die vertraute Excel-Datei.

```
Postfach                    Claude                          OPOS-Liste (Excel)
────────                    ──────                          ──────────────────
Rechnungs-Mails         →   /rechnungseingang-opos      →   neue Zeilen im Blatt
(Anhang oder Text)          liest, prüft Duplikate,          "offen"
seit letztem Lauf            schlägt Zeilen vor          →   Postfach bleibt
                             (Vorschlag → Bestätigung)        unangetastet
```

## Konventionen in dieser Anleitung

- **„Sag Claude:"** + Block, du tippst das in den **Chat** von Claude Code.
- Der Ordner `skills/rechnungseingang-opos/` zieht als `.claude/skills/rechnungseingang-opos/` in dein Projekt.

## Voraussetzungen

- Standard-Bootstrap (`bash mac/bootstrap.sh`, Windows: `bash windows/bootstrap.sh`) ist durchgelaufen.
- **Microsoft-365-Connector** verbunden, mit Admin-Zustimmung für den Tenant. Eine eigene Adminrolle brauchst du dafür **nicht**: Postfach-Suche und Anhänge lesen funktionieren mit einem normalen Mitarbeiter-Konto, sobald die Admin-Zustimmung einmal für den Tenant erteilt wurde.
- Eine bestehende OPOS-Excel-Liste mit zwei Blättern ("offen" und "bezahlt") und den Spalten Zahlungsempfänger, IBAN, Rechnungsnummer, Betrag, Beschreibung, Rechnungsdatum, Eingetragen von.
- Python mit `openpyxl` (für Lesen/Schreiben der Excel-Datei): `pip3 install openpyxl`, falls nicht vorhanden.

## Schritt 1 — Bundle ins Projekt holen

Sag Claude (er kennt sein Working-Verzeichnis und legt die Dateien passend ab):

```
Lade das Use-Case-Bundle "rechnungseingang-opos" aus meinem Setup-Repo:
~/ai-os-core/claude/use-cases/rechnungseingang-opos

Platziere es in meinem aktuellen Projekt so:
- skills/rechnungseingang-opos/  → .claude/skills/rechnungseingang-opos/

Bestätige mir, welche Dateien angekommen sind.
```

Danach `/exit` und `claude` neu starten, damit der Skill geladen wird.

## Schritt 2 — Erster Lauf

Sag Claude:

```
Prüf das Postfach auf neue Rechnungen und trag sie in die OPOS-Liste ein.
```

Der Skill fragt beim allerersten Lauf einmal kurz nach eurem Kürzel (für die Spalte "Eingetragen von"), eurer Ablagelogik, dem Pfad zur OPOS-Datei und ab wann Rechnungen berücksichtigt werden sollen, danach nie wieder. Anschließend läuft er durch:

1. sucht Mails, die seit dem letzten Lauf dazugekommen sind (mit etwas Überlappung, damit nichts durchs Raster fällt) und einen Anhang haben oder Stichwörter wie Rechnung, Zahlungserinnerung, Gutschrift enthalten,
2. liest Anhänge inhaltlich (auch mehrseitige und Sammel-PDFs mit mehreren Rechnungen in einer Datei), zerlegt Sammel-PDFs in einzelne Positionen,
3. gleicht jede Rechnung gegen die bestehende Liste ab (Duplikat-Check vor allem über die Rechnungsnummer),
4. zeigt eine Vorschlagstabelle, Gutschriften gesondert markiert, Duplikate nur als kurze Randnotiz,
5. trägt nach deiner Bestätigung die Zeilen ein und merkt sich den Zeitpunkt, damit der nächste Lauf dort ansetzt.

## Belegte Messergebnisse

Aus einem End-to-End-Test gegen ein Testpostfach mit 48 fiktiven Mails, Ground Truth in einem Manifest:

- **16 von 16 Rechnungszeilen korrekt** erfasst (15 Einzelrechnungen + 1 Gutschrift), alle harten Felder (Betrag, IBAN, Rechnungsnummer, Datum) exakt, keine einzige Ziffer falsch.
- Ein Sammel-PDF mit drei Rechnungen wurde vollständig in drei Einzelzeilen zerlegt.
- Ein Duplikat (Zahlungserinnerung zu einer bereits erfassten Rechnung) wurde erkannt und nicht doppelt eingetragen.
- Eine Gutschrift wurde nicht stillschweigend verbucht, sondern zurückgefragt und danach als Negativzeile eingetragen.
- Eine Rechnung, die nur im Mailtext stand (kein Anhang), wurde inklusive IBAN aus dem Text korrekt erfasst.
- Eine interne Inkonsistenz in einem Gutschrift-PDF (Positionssumme passte nicht zur Zwischensumme) wurde aktiv gemeldet statt stillschweigend übernommen.

## Grenzen

- **Excel-Anhänge sind nicht inline lesbar** über den Connector ("Binary attachment"). Betrifft diesen Use Case nicht direkt (Rechnungen kommen als PDF oder Text), ist aber relevant, falls Rechnungsdaten künftig als Excel-Anhang kämen: dann bräuchte es einen Ablage-Ordner statt Mail-Anhang.
- **Die Postfach-Quelle ist frei wählbar:** eigenes Postfach, ein Sammelpostfach mit beliebiger Adresse (der Erstlauf fragt danach, nichts ist fest verdrahtet), oder beide zusammen (Feld `auch_eigenes_postfach`, dann werden beide durchsucht und dieselbe Rechnung nur einmal vorgeschlagen). Der Sammelpostfach-Weg ist gebaut, aber noch nicht end-to-end getestet: Suche und Anhang-Lesen liefen im Testlauf sauber, das eigentliche Schreiben in die OPOS-Liste wurde dabei nicht ausgeführt. Zusätzlich lassen sich Kategorien im geteilten Postfach nicht setzen, nur lesen, deshalb läuft der Duplikatsschutz bewusst über die Rechnungsnummer in der Excel und nicht über eine Kategorie im Postfach (siehe Skill, Abschnitt 4a).
- Der Skill rät nie: unsicher lesbare Felder werden explizit als "bitte prüfen" markiert, nie stillschweigend geraten.

## Nächste Ausbaustufe (dokumentiert, nicht vorgebaut)

- SharePoint-Ablage der Rechnungs-PDFs pro Standort statt nur der OPOS-Zeile.
- Tägliche automatische Routine (z. B. per Scheduled Task) statt manuellem Anstoß.

## Was im Bundle liegt

```
rechnungseingang-opos/
├── README.md                              ← das hier
└── skills/
    └── rechnungseingang-opos/SKILL.md     ← sucht, liest, schlägt vor, trägt nach Bestätigung ein
```
