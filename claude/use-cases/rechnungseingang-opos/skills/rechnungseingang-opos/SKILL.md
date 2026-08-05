---
name: rechnungseingang-opos
description: Überträgt Rechnungen aus dem Postfach in die OPOS-Liste (Excel). Sucht unverarbeitete Mails mit Anhang oder Rechnungs-Stichwörtern, liest Anhänge, schlägt Buchungszeilen vor und trägt sie nach Bestätigung ein. Triggert bei "Rechnungen erfassen", "OPOS aktualisieren", "Postfach für OPOS prüfen", "/rechnungseingang-opos".
when_to_use: |
  Trigger-Phrasen: "Rechnungen aus dem Postfach erfassen", "OPOS-Liste aktualisieren", "Rechnungen erfassen", "prüf das Postfach auf neue Rechnungen", "/rechnungseingang-opos". Ohne Argument = kompletter Lauf gegen den Posteingang. Erster Lauf fragt einmalig nach Kürzel und Excel-Pfad, danach nicht mehr.
allowed-tools: Bash(python3:*), Bash(python:*), Bash(py:*), Read, Write, Edit, AskUserQuestion
---

# Rechnungseingang → OPOS

Du überträgst Rechnungen aus dem Postfach in die OPOS-Excel-Liste. Zielnutzerin ist die Buchhaltung, ohne IT-Hintergrund. Sie sieht nie JSON, Code oder Configs, nur: eine Vorschlagstabelle im Chat, eine Ja/Nein-Bestätigung, danach die vertraute Excel-Datei mit neuen Zeilen. Das Postfach selbst bleibt unangetastet, es wird nichts markiert oder verschoben (siehe Schritt 2, Delta-Logik über einen Zeitstempel).

## Grundprinzip: assistiert, nicht autonom

Du schlägst vor. Der Mensch bestätigt. ERST DANACH schreibst du Excel-Zeilen. Kein Schreibzugriff vor der Bestätigung. Ausgenommen sind rein technische Verwaltungsdateien ohne buchhalterische Wirkung (`.last-run`-Zeitstempel, `zwischenspeicher.json`, siehe Schritt 2 und 6a), die brauchen keine gesonderte Bestätigung.

## 0. Tools laden (PFLICHT, ein Aufruf)

Die M365-Connector-Tools sind deferred. Bevor du irgendetwas tust, lade sie in EINEM ToolSearch-Aufruf:

```
ToolSearch: select:mcp__claude_ai_Microsoft_365__outlook_email_search,mcp__claude_ai_Microsoft_365__read_resource
```

Erst danach sind die Tools aufrufbar.

## 1. Erstlauf-Setup (nur wenn noch keine Config existiert)

Prüfe, ob neben dieser SKILL.md eine `config.json` liegt (gleicher Ordner). Wenn nicht: einmalig im Chat fragen (auf Deutsch, ein kurzer Block, keine technischen Begriffe):

1. "Mit welchem Kürzel soll ich Einträge als 'Eingetragen von' kennzeichnen?" (z. B. "MM")
2. Zur Ablagelogik, in Anwendersprache, ohne Fachjargon:
   - "Arbeitet ihr dauerhaft in einer Datei mit den Tabs 'offen' und 'bezahlt', oder legt ihr pro Monat, Quartal oder Jahr eine neue Datei an?"
   - Bei einer Datei: "Wo liegt sie?" mit Default-Vorschlag `./opos/OPOS-Liste.xlsx` im aktuellen Projekt (Enter/Bestätigung übernimmt den Default).
   - Bei neuer Datei pro Zeitraum: "Nach welchem Muster heißt die Datei, und in welchem Ordner liegt sie?"
   - "Was passiert mit einer Rechnung, sobald sie bezahlt ist? Wandert sie in den Tab 'bezahlt', wird sie nur markiert, oder wird sie ausgelagert?"
   - Hinweis, nicht als Vorschrift: Monats- oder Quartals-Tabs innerhalb einer Datei sind meist ungünstig, weil je Zeitraum zwei Tabs (offen/bezahlt) entstehen und die Datei schnell unübersichtlich wird. Besser eine laufende Datei mit Datumsspalte, oder eine Datei je Zeitraum mit automatischem Übertrag der offenen Posten beim Wechsel (siehe Schritt 6).
   - Es gibt keine vom Skill bevorzugte Struktur, er passt sich der vorhandenen Arbeitsweise an.
3. "Wo kommen Rechnungen bei euch an: nur in eurem persönlichen Postfach, nur in einem Sammelpostfach (z. B. rechnungen@...), oder in beiden?" Bei Sammelpostfach oder beidem: die Adresse erfragen (keine Annahme über den Namen, das Postfach kann beliebig heißen). Wenn nur persönliches Postfach oder unsicher: leer lassen, es läuft dann gegen das eigene Postfach.
4. "Gibt es in eurem Postfach eine Kategorie, mit der ihr einzelne Rechnungen ganz bewusst von der Verarbeitung ausnehmen wollt, zum Beispiel strittige Rechnungen, private Belege, oder Fälle, die ihr schon anders erledigt habt? Falls ja, wie heißt sie genau?" Leer lassen bedeutet: kein Ausschluss, alles wird geprüft. Dazu einmalig der Hinweis: Wird eine solche Markierung erst Tage später wieder entfernt, kann die Mail inzwischen außerhalb des betrachteten Zeitraums liegen und nicht automatisch nachgeholt werden. Dann den Skill einmal bewusst mit einem passenden Zeitraum starten.

Antworten selbst in `config.json` neben der SKILL.md speichern, Schema:
```json
{
  "eingetragen_von": "MM",
  "dateimodus": "eine_datei",
  "excel_pfad": "/pfad/zur/OPOS-Liste.xlsx",
  "dateimuster": null,
  "bezahlt_verhalten": "tab_bezahlt",
  "sammelpostfach": "rechnungen@example.com",
  "auch_eigenes_postfach": false,
  "erstlauf_fenster_tage": 30,
  "ausschluss_kategorie": null
}
```
`dateimodus` ist `"eine_datei"`, `"monatlich"`, `"quartalsweise"` oder `"jährlich"`. Bei periodischem Modus steht in `dateimuster` das Namens- und Pfadschema (z. B. Ordner + Platzhalter für Monat/Quartal/Jahr) statt eines festen `excel_pfad`. `bezahlt_verhalten` ist `"tab_bezahlt"`, `"markiert"` oder `"ausgelagert"`. Das dient dem Skill nur dazu, die vorhandene Arbeitsweise zu kennen und beim Duplikatsschutz (Abschnitt 4a) die richtigen Orte zu durchsuchen, NICHT dazu, selbst umzubuchen: dieser Skill schreibt ausschließlich neue Zeilen in die offenen Posten, das Umbuchen einer bezahlten Rechnung bleibt Aufgabe des Menschen. `sammelpostfach` ist optional, leerer String oder Feld weglassen = eigenes Postfach. `auch_eigenes_postfach` gilt nur zusammen mit gesetztem `sammelpostfach` und bedeutet: BEIDE Quellen durchsuchen (Antwort "in beiden" aus Frage 3); fehlt das Feld, gilt `false`. `erstlauf_fenster_tage` wird nur beim allerersten Lauf erfragt (siehe Schritt 2) und danach nicht mehr benötigt, sobald `.last-run` existiert. `ausschluss_kategorie` ist der Name einer Outlook-Kategorie oder `null` (kein Ausschluss), siehe Schritt 3: ein Veto des Menschen, kein Erledigt-Nachweis, der Skill setzt diese Kategorie nie selbst.
Der Nutzer sieht diese Datei nie und muss sie nie anfassen. Bei jedem weiteren Lauf: `config.json` einfach lesen, nicht erneut fragen. Ändert der Nutzer später explizit Kürzel, Ablagelogik oder Pfad, aktualisierst du die Datei entsprechend.

## 2. Zeitraum bestimmen (Delta-Logik) und Rechnungs-Mails suchen

Analog zum Skill `posteingang-triage` steuert ein Zeitstempel, was als neu gilt. Das Postfach bleibt dabei unangetastet, es wird nichts markiert, verschoben oder aufgeräumt.

- Zeitstempel liegt in `.claude/skills/rechnungseingang-opos/.last-run` (ISO-Zeitstempel), gleicher Mechanismus wie bei `posteingang-triage`.
- Existiert die Datei: `afterDateTime` = vollständiger Zeitstempel minus ein Tag. Bewusster Puffer statt exakter Kante, soll aber nur Zustellverzögerungen abfangen, kein mehrtägiger Nachlauf. Eine doppelt gesehene Rechnung ist ungefährlich (die Rechnungsnummer fängt sie in Abschnitt 4a ab), eine übersehene Rechnung ist teuer, das rechtfertigt den Puffer.
- Existiert die Datei nicht (erster Lauf): einmalig fragen, ab wann Rechnungen berücksichtigt werden sollen, mit Vorschlag "die letzten 30 Tage". Antwort als `erstlauf_fenster_tage` in `config.json` merken (nicht erneut fragen, auch wenn der erste Lauf danach abbricht, bevor `.last-run` geschrieben wird). `afterDateTime` = heute minus `erstlauf_fenster_tage`.
- Äußert der Nutzer für den aktuellen Lauf ausdrücklich einen anderen Zeitraum, hat das Vorrang vor beiden obigen Regeln.
- `.last-run` erst NACH erfolgreichem Durchlauf (nach Schritt 6) auf den aktuellen Zeitpunkt schreiben. Bricht der Lauf vorher ab, bleibt der alte Stand stehen, damit nichts verloren geht.

**Suche:** `outlook_email_search` braucht mindestens einen Filter, ein parameterloser Aufruf wird mit `VALIDATION_ERROR` abgewiesen. Funktionierender Aufruf: `afterDateTime` zusammen mit `folderName: "Inbox"` (eigenes Postfach) oder `afterDateTime` zusammen mit `mailboxOwnerEmail` (Sammelpostfach, siehe unten). Gesucht werden Mails, die entweder einen Anhang haben ODER eines der Stichwörter in Betreff/Text enthalten: Rechnung, Invoice, Zahlungserinnerung, Gutschrift.

Ist in der `config.json` ein `sammelpostfach` gesetzt: bei JEDEM Aufruf von `outlook_email_search` und `read_resource` den Parameter `mailboxOwnerEmail` (bzw. den `?owner=`-Teil der von der Suche gelieferten URI) mit dieser Adresse setzen, statt gegen das eigene Postfach zu suchen. Anhang-URIs kommen aus der Suche bereits mit `?owner=` versehen, unverändert weiterverwenden.

Steht zusätzlich `auch_eigenes_postfach` auf `true`: ZWEI Suchen fahren, eine im Sammelpostfach (mit `mailboxOwnerEmail`) und eine im eigenen Postfach (mit `folderName: "Inbox"`), Ergebnisse zusammenführen. Beim Lesen der Anhänge je Mail den Parameter der Quelle verwenden, aus der die Mail stammt. Taucht dieselbe Rechnung in beiden Postfächern auf (gleiche Rechnungsnummer, z. B. weil eine Mail intern weitergeleitet wurde), nur EINMAL in die Vorschlagstabelle aufnehmen, mit Hinweis auf die doppelte Quelle; der Duplikatsschutz aus Abschnitt 4a greift erst gegen die Excel, nicht innerhalb eines Laufs.

**Zurückgestellte Vorgänge zusätzlich vorlegen:** neben der Suche im Zeitfenster immer auch `zwischenspeicher.json` (siehe Abschnitt 6a) prüfen und offene Einträge daraus wieder in die Vorschlagstabelle aufnehmen, bis sie erledigt oder vom Nutzer verworfen wurden.

## 3. Je Mail: Anhänge lesen und Rechnungen erkennen

- **Ausschluss-Kategorie zuerst prüfen** (nur wenn `ausschluss_kategorie` in der `config.json` gesetzt ist): Kategorien der Mail über `read_resource` lesen (im Sammelpostfach mit `?owner=`, das Lesen funktioniert in beiden Postfachtypen gleich, nur das Setzen nicht, siehe Abschnitt 4a). Trägt die Mail diese Kategorie, überspringen und NICHT verbuchen, im Abschlussreport auflisten (Absender, Betreff, Grund "ausgeschlossen durch Markierung"). Diese Markierung setzt und pflegt ausschließlich der Mensch, der Skill schreibt sie nie. Sie ist ein Veto ("bitte nicht verbuchen"), keine Erledigt-Markierung wie die frühere, inzwischen entfernte Kategorie-Logik, die beiden dürfen im Text nicht verwechselt werden.
- Anhänge über `read_resource` inhaltlich lesen (PDF-Text).
- **Sammel-PDFs** (mehrere Rechnungen in einer Datei) in einzelne Positionen zerlegen, jede Position wird eine eigene Vorschlagszeile.
- **Rechnungen ohne Anhang**, die nur im Mailtext stehen, ebenfalls als eigene Position erfassen.
- Mails ohne erkennbare Rechnung (reine Werbung, Terminbestätigungen o. ä., die zufällig ein Stichwort treffen): überspringen, im Abschlussreport unter "übersprungen" mit Grund nennen.

## 4. Felder extrahieren je Rechnung

Zahlungsempfänger, IBAN, Rechnungsnummer, Betrag (brutto), Beschreibung (kurz, buchhalterisch, z. B. "Laborleistungen Juni"), Rechnungsdatum.

- **Gutschriften**: NIE stillschweigend als normale Rechnung eintragen. Gesondert in der Vorschlagstabelle als "Gutschrift, bitte prüfen" markieren und explizit nachfragen, wie sie erfasst werden soll (z. B. negativer Betrag, eigene Zeile, oder verrechnet mit einer bestehenden Rechnung).
- **Duplikat-Check**: siehe Abschnitt 4a, Rechnungsnummer als harte Prüfung, bei fehlender Nummer Verdachtsvergleich.
- Fehlt ein Feld oder ist unsicher lesbar (z. B. Betrag nicht eindeutig): Zeile trotzdem in die Vorschlagstabelle aufnehmen, fehlendes Feld klar markieren ("nicht sicher lesbar, bitte prüfen"), NIE raten.

## 4a. Duplikatsschutz

Die Rechnungsnummer ist die harte Prüfung. Eine kategoriebasierte zweite Stufe gibt es bewusst nicht (mehr): sie funktionierte nur im eigenen Postfach, nicht im Sammelpostfach, diese Ungleichheit hätte mehr Verwirrung als Nutzen gestiftet. Der Skill verhält sich jetzt unabhängig vom Postfachtyp identisch, auch das Postfach selbst bleibt unangetastet (siehe Schritt 2). Die Ausschluss-Kategorie aus Schritt 3 gehört NICHT zum Duplikatsschutz, sie ist ein separates Veto des Menschen gegen einzelne Rechnungen, unabhängig davon, ob diese schon irgendwo erfasst sind.

**Drei Marker, drei getrennte Aufgaben, keiner übernimmt die Aufgabe eines anderen:**
1. **Rechnungsnummer in der Excel** (dieser Abschnitt): setzt der Skill, ist der Erledigt-Nachweis, verhindert Doppelbuchung.
2. **Ausschluss-Kategorie im Postfach** (Schritt 3): setzt der Mensch, ist ein Veto, kein Erledigt-Nachweis.
3. **Zeitstempel `.last-run`** (Schritt 2): setzt der Skill, bestimmt nur, wie weit zurückgeschaut wird, sagt nichts darüber aus, ob eine Rechnung schon verbucht ist.

1. **Rechnungsnummer.** Vor dem Verbuchen die Rechnungsnummer gegen die Spalte Rechnungsnummer BEIDER Tabs ("offen" und "bezahlt") abgleichen (via python3/openpyxl lesen, keine Schreibaktion; unter Windows ist `python3` oft nur der Microsoft-Store-Stub, dann stattdessen `python` oder `py -3` verwenden). Bekannte Nummer: NICHT erneut verbuchen, sondern dem Nutzer melden, dass die Rechnung bereits erfasst ist, mit Fundort (Tab und Zeile). Wird mit mehreren Dateien gearbeitet (`dateimodus` periodisch), zusätzlich die Vorgängerdatei einbeziehen (ihr Name lässt sich aus `dateimuster` für die vorherige Periode ableiten), sonst wird eine übertragene Rechnung (siehe Schritt 6) doppelt erfasst.
2. **Sonderfall ohne Rechnungsnummer:** Fehlt die Rechnungsnummer, über die Kombination Zahlungsempfänger, Betrag und Rechnungsdatum gegen beide Tabs (und ggf. Vorgängerdatei) abgleichen. Ein Treffer ist ein Verdacht, keine Gewissheit: nicht automatisch überspringen, sondern in der Vorschlagstabelle als "möglicherweise bereits erfasst, bitte prüfen" markieren und den Nutzer entscheiden lassen.

## 5. Vorschlagstabelle zeigen und auf Bestätigung warten

Eine einzige, übersichtliche Tabelle im Chat mit allen Kandidaten-Zeilen (Spalten wie die Excel: Zahlungsempfänger, IBAN, Rechnungsnummer, Betrag, Beschreibung, Rechnungsdatum), dazu:
- Unklare Fälle sichtbar markiert, mit dem was genau fehlt oder unsicher ist.
- Gutschriften gesondert ausgewiesen.
- Duplikate NICHT in der Eintrage-Tabelle, sondern als kurze separate Zeile "X Duplikate übersprungen: ...".

Dann auf Ja/Nein bzw. Korrekturen des Nutzers warten. Erst bei Zustimmung weiter. Bei Korrekturwunsch: Tabelle entsprechend anpassen und erneut zur Bestätigung vorlegen.

## 6. Nach Bestätigung: schreiben

**Zieldatei bestimmen:** Steht `dateimodus` auf `"eine_datei"`, direkt `excel_pfad` verwenden. Steht er auf `"monatlich"`, `"quartalsweise"` oder `"jährlich"`, den Dateinamen anhand `dateimuster` und dem aktuellen Zeitraum ableiten. Existiert diese Datei bereits: normal weiterarbeiten. Existiert sie noch nicht und es handelt sich erkennbar um einen Periodenwechsel (die Datei der Vorperiode existiert): dem Nutzer anbieten, die neue Datei aus dem Muster anzulegen und die offenen Posten der Vorgängerdatei zu übertragen (siehe unten), erst nach Bestätigung ausführen. In jedem anderen Fall (Datei fehlt ohne erkennbaren Periodenwechsel) NICHT selbst neu anlegen, sondern den Nutzer darauf hinweisen und nachfragen.

**Übertrag bei Periodenwechsel:** Beim Anlegen einer neuen Perioden-Datei alle noch offenen Zeilen (Tab "offen") aus der Vorgängerdatei unverändert in den Tab "offen" der neuen Datei kopieren. Bezahlte Posten bleiben in der alten Datei, sie wird dadurch faktisch zum Archiv. Ohne diesen Übertrag verschwinden gerade die überfälligen, teuersten Rechnungen aus dem Blick.

**Excel:** Bestätigte Zeilen via `python3` mit `openpyxl` ans Ende von Blatt "offen" anhängen (nicht überschreiben, nur anhängen). Spaltenreihenfolge exakt: Zahlungsempfänger | IBAN | Rechnungsnummer | Betrag | Beschreibung | Rechnungsdatum | Eingetragen von. "Eingetragen von" = Kürzel aus `config.json`. Gutschriften nur eintragen, wenn der Nutzer in Schritt 5 dafür eine klare Vorgabe gemacht hat.

**Zeitstempel aktualisieren:** Erst nachdem das Excel-Schreiben erfolgreich abgeschlossen ist, den aktuellen Zeitpunkt in `.claude/skills/rechnungseingang-opos/.last-run` schreiben (siehe Schritt 2). Bricht der Lauf vorher ab, bleibt der alte Zeitstempel stehen.

## 6a. Offene Punkte aktiv klären

Schritt 5 ist die Freigabe der vollständigen Vorschläge, also das Ja zum Verbuchen. Was dort sauber durchging, ist mit Schritt 6 erledigt und taucht hier nicht mehr auf. Dieser Abschnitt behandelt ausschließlich, was nach der Freigabe noch fehlte oder unklar war (fehlende IBAN, unklarer Betrag, Gutschrift statt Rechnung, kein erkennbares Rechnungsdatum), sprich diese Fälle aktiv an, statt sie nur im Abschlussreport zu vergraben. Nutze dafür das `AskUserQuestion`-Tool, mehrere offene Punkte gebündelt statt jede Kleinigkeit einzeln zu fragen.

Je offenem Punkt lässt du den Nutzer wählen:
- **Jetzt nachtragen:** Nutzer liefert das fehlende Feld direkt, die Zeile wird komplett eingetragen.
- **Vorerst zurückstellen:** Zeile wird NICHT eingetragen. Da das Postfach nicht markiert wird und die Mail irgendwann aus dem Zeitfenster fällt (Schritt 2), braucht es einen eigenen kleinen Zwischenspeicher: `zwischenspeicher.json` neben der SKILL.md, eine Liste mit je einem Eintrag pro zurückgestelltem Vorgang, Schema `{"bezug": {"betreff": "...", "absender": "...", "datum": "...", "nachrichten_id": "..."}, "bereits_bekannt": {...Felder aus Schritt 4...}, "es_fehlt": "IBAN"}`. Bei jedem weiteren Lauf werden diese Einträge zusätzlich zum Zeitfenster vorgelegt (siehe Schritt 2), bis sie erledigt oder vom Nutzer verworfen wurden, dann aus `zwischenspeicher.json` entfernen.
- **Bewusst unvollständig verbuchen:** Zeile wird mit klar markierter Lücke eingetragen (z. B. Feld "fehlt, siehe Notiz").

## 7. Abschlussreport (kurz, Alltagssprache)

Beispiel-Format:
- **Erfasst:** 5 Rechnungen in die OPOS-Liste eingetragen.
- **Übersprungen:** 2 (1 Duplikat "Rechnungsnr. 4711", 1 Gutschrift auf Nutzerwunsch nicht automatisch verbucht).
- **Ausgeschlossen:** 1 (Rechnung von einem Lieferanten, Betreff "Rechnung April", ausgeschlossen durch Markierung). Diese Zeile IMMER mit aufführen, ist `ausschluss_kategorie` gesetzt, auch wenn die Zahl 0 ist, damit ausgeschlossene Rechnungen nie still verschwinden.
- **Unklar:** 1 (bei einer Rechnung konnte ich den Betrag nicht sicher lesen, bitte kurz prüfen).

Keine Stacktraces, keine technischen Fehlermeldungen. Ist ein Tool nicht erreichbar (z. B. Connector-Fehler), das in Alltagssprache erklären ("Ich konnte gerade nicht auf das Postfach zugreifen, bitte gleich nochmal versuchen") statt die technische Fehlermeldung zu zeigen.

## Grenzen (hart)

- Kein Schreiben von Excel-Zeilen ohne vorherige Bestätigung durch den Menschen.
- Der Skill setzt oder ändert nie eine Outlook-Kategorie und verschiebt nie eine Mail. Er liest ausschließlich die vom Menschen gepflegte `ausschluss_kategorie` (falls gesetzt), sonst bleibt das Postfach unangetastet.
- Gutschriften nie automatisch wie normale Rechnungen behandeln.
- Duplikate nie doppelt eintragen.
- Keine Beträge oder Felder raten, wenn sie nicht sicher lesbar sind, immer als unklar ausweisen.
- Der Nutzer bekommt nie JSON, Code oder die `config.json` selbst zu sehen, nur die Excel-Datei und den Chat.

## Nächste Ausbaustufe (dokumentiert, nicht vorgebaut)

- SharePoint-Ablage der Rechnungs-PDFs pro Standort statt nur OPOS-Zeile.
- Tägliche automatische Routine (z. B. per Scheduled Task) statt manuellem Anstoß.

Sammelpostfach statt Einzelpostfach als Quelle ist bereits gebaut (siehe `sammelpostfach` in `config.json`, Schritt 1 und 2), aber noch nicht end-to-end getestet: Der Testlauf deckte Suche und Anhang-Lesen ab, nicht das tatsächliche Schreiben in die OPOS-Liste. Im geteilten Postfach lassen sich Kategorien zudem nur lesen, nicht setzen, deshalb bleibt der Duplikatsschutz bewusst an die Rechnungsnummer in der Excel geknüpft (Abschnitt 4a), nicht an eine Kategorie im Postfach.
