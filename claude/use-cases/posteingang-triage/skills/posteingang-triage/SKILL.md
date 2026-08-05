---
name: posteingang-triage
description: Sichtet Mails seit dem letzten Lauf (erster Lauf: letzte 7 Tage) und sortiert sie inhaltsbasiert in sechs Kategorien (Interessent P1/P2/P3, Bestandskunde, Bewerbung, Sonstiges). Zeigt eine Digest-Tabelle mit Abarbeitungsreihenfolge, setzt nach Bestätigung Outlook-Kategorien und bietet für P1-Anfragen einen Antwort-Entwurf an. Triggert bei "Posteingang sichten", "Posteingang vorsortieren", "Mails triagieren", "/posteingang-triage".
when_to_use: |
  Trigger-Phrasen: "Posteingang sichten", "Posteingang vorsortieren", "Mails triagieren", "sortier mein Postfach", "/posteingang-triage". Ohne Argument = Mails seit dem letzten Lauf (erster Lauf: letzte 7 Tage). Gedacht für 2-3 Läufe pro Tag, kein Dauerlauf.
allowed-tools: Read, Write
---

# Posteingangs-Triage

Du sichtest den Posteingang und sortierst ihn inhaltlich vor. Zielnutzer ist ein Team ohne IT-Hintergrund. Es sieht nie JSON oder Code, nur eine Digest-Tabelle im Chat, die vertrauten Kategorien in Outlook und, wenn gewünscht, fertige Antwort-Entwürfe zum Gegenlesen.

## Grundprinzip: assistiert, nicht autonom

Du schlägst die Einordnung vor. Der Mensch bestätigt. ERST DANACH setzt du Kategorien oder legst Entwürfe an. Kein Schreibzugriff vor der Bestätigung, und selbst danach ausschließlich Entwürfe, niemals Versand.

## 0. Tools laden (PFLICHT, ein Aufruf)

Die M365-Connector-Tools sind deferred. Bevor du irgendetwas tust, lade sie in EINEM ToolSearch-Aufruf:

```
ToolSearch: select:mcp__claude_ai_Microsoft_365__outlook_email_search,mcp__claude_ai_Microsoft_365__outlook_create_label,mcp__claude_ai_Microsoft_365__outlook_modify_labels,mcp__claude_ai_Microsoft_365__outlook_create_reply_draft,mcp__claude_ai_Microsoft_365__read_resource
```

Erst danach sind die Tools aufrufbar.

## 1. Mails suchen

`outlook_email_search` braucht zwingend mindestens einen der Parameter `query`, `sender`, `recipient`, `afterDateTime`, `beforeDateTime`, `folderName`, `mailboxOwnerEmail`, `order` oder `cursor`. Ein Aufruf ganz ohne Parameter schlägt fehl (`VALIDATION_ERROR: outlook_email_search requires at least one of: query, sender, recipient, afterDateTime, beforeDateTime, folderName, mailboxOwnerEmail, order, or cursor`). Funktionierender Aufruf: `folderName: "Inbox"` zusammen mit `afterDateTime`.

**Zeitfenster:** `afterDateTime` ist der Zeitpunkt des letzten erfolgreichen Laufs, abgelegt in `.claude/skills/posteingang-triage/.last-run` (ISO-Zeitstempel). Existiert die Datei nicht, ist es der erste Lauf: `afterDateTime` auf vor 7 Tagen setzen. So bekommt jeder Lauf nur, was seit dem letzten dazugekommen ist, nichts wird doppelt geholt und nichts übersehen. Will der Nutzer explizit einen anderen Zeitraum, diesen statt des Defaults verwenden.

**Bereits bearbeitete Mails ausschließen:** Maßgeblich dafür, ob eine Mail schon bearbeitet ist, ist ob der Skill ihr bereits eine der sechs Kategorien zugewiesen hat (siehe Abschnitt 4), nicht ihr Lesestatus. Gelesen/ungelesen ist nur noch ein Hinweis im Digest, kein Filter mehr: eine Mail darf nicht deshalb übersprungen werden, weil sie schon gelesen ist. Begründung: im Testlauf waren die vier wichtigsten Anfragen (P1) bereits als gelesen markiert, weil in einer früheren Sitzung ein Antwortentwurf geöffnet worden war, ein Lauf, der sich strikt auf "ungelesen" verlässt, hätte alle vier übersehen.

Existiert im Postfach zusätzlich die Kategorie „OPOS erfasst" (gehört zum separaten Rechnungs-Skill), Mails mit dieser Kategorie ebenfalls überspringen. Ist sie nicht vorhanden, hat das keine Auswirkung.

## 2. Inhaltsbasiert klassifizieren

Jede Mail bekommt genau eine der sechs Kategorien. Die Klassifikation stützt sich rein auf Inhalt (Betreff + Text), nicht auf den Absender.

- **Interessent P1**: konkreter Anfrage- UND Terminwunsch, hochwertige Anfrage, ausdrückliche Rückrufbitte, genanntes Budget, oder eine Empfehlung wird erwähnt. Ausschlaggebend ist die Kombination aus Relevanz und Reaktionszeit, die die Anfrage verlangt.
- **Interessent P2**: konkrete inhaltliche Frage (z. B. zu einem Angebot, Kosten, Ablauf), aber ohne erkennbaren Termindruck.
- **Interessent P3**: vage Info-Anfrage, unspezifisches Interesse, noch keine konkrete Frage oder Absicht.
- **Bestandskunde**: Bezug auf eine frühere Leistung, einen bestehenden Termin oder eine Rechnung.
- **Bewerbung**: Bewerbungsschreiben oder Rückfrage zu einer Stelle.
- **Sonstiges**: Werbung, Newsletter, organisatorische Mails ohne Kundenbezug.

Für jede P1-Mail: einen Satz notieren, was konkret den Ausschlag für P1 gegeben hat (für die Digest-Begründung).

## 3. Digest-Tabelle zeigen und auf Bestätigung warten

Eine Tabelle im Chat, sortiert nach empfohlener Abarbeitungsreihenfolge (P1 zuerst, dann P2, dann Bestandskunden/Bewerbungen/P3/Sonstiges nach Ermessen). Je Mail: Absender, Betreff, vorgeschlagene Kategorie. Bei jeder P1-Mail zusätzlich die Ein-Satz-Begründung.

Dann auf Bestätigung bzw. Korrekturen warten. Erst bei Zustimmung weiter.

## 4. Nach Bestätigung: Kategorien setzen

Existieren die sechs Kategorien (Interessent P1, Interessent P2, Interessent P3, Bestandskunde, Bewerbung, Sonstiges) noch nicht in Outlook, einmalig mit `outlook_create_label` anlegen, mit sinnvollen, gut unterscheidbaren Farben (z. B. P1 kräftig/auffällig, P3 und Sonstiges zurückhaltend). Danach jede Mail mit `outlook_modify_labels` entsprechend der bestätigten Tabelle kategorisieren.

Danach den aktuellen Zeitstempel in `.claude/skills/posteingang-triage/.last-run` schreiben, damit der nächste Lauf dort ansetzt und nichts doppelt bearbeitet wird.

## 5. Persönlichen Ton lernen (einmalig, vor dem ersten Entwurf)

Bevor ein Antwortentwurf angeboten wird (Abschnitt 6): prüfen, ob `.claude/skills/posteingang-triage/TONE.md` bereits existiert.

**TONE.md existiert bereits:** nichts tun, direkt weiter zu Abschnitt 6. Die Datei wird NIE automatisch überschrieben, auch nicht wenn sie veraltet wirkt, der Nutzer darf sie von Hand anpassen. Eine Aktualisierung passiert ausschließlich auf ausdrücklichen Wunsch ("aktualisiere meinen Ton" o. ä.), dann die folgenden Schritte erneut durchlaufen und die bestehende Datei ersetzen.

**TONE.md existiert noch nicht:** einmalig den Schreibstil lernen.
1. Mit `outlook_email_search` gegen `folderName: "Sent Items"` die eigenen gesendeten Mails der letzten ca. 90 Tage suchen, bis zu ca. 50 Stück.
2. Inhalte der gefundenen Mails über `read_resource` laden.
3. Weniger als 5 gesendete Mails im Zeitraum gefunden? → Fallback (siehe unten), Rest dieses Schritts überspringen.
4. Aus den gelesenen Mails destillieren: Anrede-Form (Du/Sie), typische Begrüßung und Grußformel, Satzlänge und Knappheit, wiederkehrende Wendungen, Formalitätsgrad, Umgang mit Emojis/Ausrufezeichen.
5. Ergebnis als kurzes, strukturiertes Stilprofil mit 2-3 kurzen Beispielformulierungen in `.claude/skills/posteingang-triage/TONE.md` schreiben. KEINE Zitate ganzer Mails, keine personenbezogenen Daten Dritter.

**Fallback bei weniger als 5 gesendeten Mails:** trotzdem eine `TONE.md` anlegen, mit neutralem, professionellem Default-Ton (Sie-Form, klar, freundlich-zurückhaltend) und einem sichtbaren Hinweis-Absatz, dass dieses Profil noch nicht aus dem echten Postfach gelernt wurde und auf Zuruf ("aktualisiere meinen Ton") nachgeschärft werden kann. Im Chat kurz in Alltagssprache darauf hinweisen, dass der Fallback gegriffen hat.

## 6. Antwort-Entwürfe für P1 anbieten

Für jede P1-Mail im Chat anbieten, einen Antwort-Entwurf zu erstellen. Bei Zustimmung: `TONE.md` (Abschnitt 5) als Stil-Anker laden und den Entwurf daran ausrichten, dann `outlook_create_reply_draft` NUR als Entwurf, NIEMALS senden.

Entwurfston: an `TONE.md` ausgerichtet, professionell, warm, einladend. Harte Grenzen (branchenspezifisch anzupassen, z. B. bei Gesundheits- oder Beratungsdienstleistungen):
- Keine Erfolgszusicherung oder unzulässigen Versprechen.
- Keine Preiszusagen oder konkreten Kostenangaben.
- Terminvorschlag anbieten (z. B. Rückruf oder Beratungstermin), keine fachliche Einschätzung im Entwurf.

Fertigen Entwurfstext im Chat zeigen, bevor oder nachdem er als Draft angelegt wurde, damit das Team ihn gegenlesen kann.

## 7. Abschlussmeldung (Alltagssprache)

Kurz zusammenfassen: wie viele Mails je Kategorie, wie viele P1-Entwürfe erstellt. Keine Stacktraces oder technischen Fehlermeldungen. Ist ein Tool nicht erreichbar, das in Alltagssprache erklären ("Ich konnte gerade nicht auf das Postfach zugreifen, bitte gleich nochmal versuchen").

## Grenzen (hart)

- Keine Kategorie setzen und keinen Entwurf anlegen ohne vorherige Bestätigung durch den Menschen.
- Antwort-Entwürfe werden NIEMALS gesendet, nur als Entwurf abgelegt.
- Keine Preiszusagen, keine unzulässigen Versprechen in Entwürfen.
- Klassifikation ausschließlich inhaltsbasiert, Absender ist kein Kriterium (im Echtbetrieb wäre die Absender-Historie ein sinnvolles Zusatzsignal, siehe Ausbaustufe).
- Der Nutzer bekommt nie JSON oder Code zu sehen, nur die Digest-Tabelle, die Kategorien in Outlook und die Entwurfstexte.
- `TONE.md` wird NIE automatisch überschrieben, nur auf ausdrücklichen Wunsch des Nutzers neu destilliert.

## Nächste Ausbaustufe (dokumentiert, nicht vorgebaut)

- Automatische Routine 2-3x täglich statt manuellem Anstoß.
- Absender-Historie (frühere Mails, bekannter Kunde ja/nein) als zusätzliches Klassifikationssignal neben dem Inhalt.
