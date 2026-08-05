# Der Posteingang sortiert sich selbst vor

Ein volles Postfach ist keine Prioritätenliste. Eine dringende Anfrage mit Terminwunsch steht neben einer Bewerbung, neben einem Newsletter, neben einer Rückfrage eines Bestandskunden, und wer morgens als Erstes reinschaut, arbeitet oft einfach von oben nach unten statt nach Dringlichkeit.

Dieses Bundle sichtet die Mails seit dem letzten Lauf (beim allerersten Lauf die letzten 7 Tage), ordnet jede inhaltlich einer von sechs Kategorien zu (drei Interessenten-Prioritäten, Bestandskunde, Bewerbung, Sonstiges) und zeigt eine Abarbeitungsreihenfolge. Nach Bestätigung setzt der Skill die passenden Outlook-Kategorien und bietet für die dringendsten Fälle direkt einen Antwortentwurf an, immer nur als Entwurf, nie automatisch versendet. Bearbeitet ist eine Mail, sobald sie eine Kategorie trägt, nicht sobald sie gelesen wurde: gelesen/ungelesen ist nur noch ein Hinweis im Digest, kein Filter.

```
Postfach                    Claude                          Postfach + Chat
────────                    ──────                          ───────────────
Mails seit letztem       →  /posteingang-triage         →   6 Farb-Kategorien gesetzt
Lauf (Start: 7 Tage)          klassifiziert, zeigt Digest      Entwürfe für P1 im
                              (Vorschlag → Bestätigung)        Drafts-Ordner
```

## Konventionen in dieser Anleitung

- **„Sag Claude:"** + Block, du tippst das in den **Chat** von Claude Code.
- Der Ordner `skills/posteingang-triage/` zieht als `.claude/skills/posteingang-triage/` in dein Projekt.

## Voraussetzungen

- Standard-Bootstrap (`bash mac/bootstrap.sh`, Windows: `bash windows/bootstrap.sh`) ist durchgelaufen.
- **Microsoft-365-Connector** verbunden, mit Admin-Zustimmung für den Tenant. Läuft auch mit einem normalen Mitarbeiter-Konto ohne Adminrolle, sobald die Admin-Zustimmung einmal für den Tenant erteilt wurde.
- Kein Excel nötig, der Skill arbeitet gegen das Postfach. Lokale Ablage im Skill-Ordner: eine `.last-run`-Datei, die sich den Zeitpunkt des letzten Laufs merkt, und eine `TONE.md` mit dem gelernten Schreibstil (deshalb `allowed-tools: Read, Write` in der SKILL.md, statt nur `Read`).

## Schritt 1 — Bundle ins Projekt holen

Sag Claude (er kennt sein Working-Verzeichnis und legt die Dateien passend ab):

```
Lade das Use-Case-Bundle "posteingang-triage" aus meinem Setup-Repo:
~/ai-os-core/claude/use-cases/posteingang-triage

Platziere es in meinem aktuellen Projekt so:
- skills/posteingang-triage/  → .claude/skills/posteingang-triage/

Bestätige mir, welche Dateien angekommen sind.
```

Danach `/exit` und `claude` neu starten, damit der Skill geladen wird.

## Schritt 2 — Erster Lauf

Sag Claude:

```
Sichte den Posteingang und sortier ihn vor.
```

Ohne weitere Angabe nimmt der Skill alle Mails seit dem letzten Lauf, beim allerersten Mal die letzten 7 Tage. Anschließend läuft er durch:

1. klassifiziert jede Mail rein inhaltsbasiert (Betreff + Text, nicht Absender) in eine der sechs Kategorien: Interessent P1/P2/P3, Bestandskunde, Bewerbung, Sonstiges,
2. zeigt eine Digest-Tabelle, sortiert nach Abarbeitungsreihenfolge, mit Ein-Satz-Begründung bei jeder P1-Mail,
3. legt nach deiner Bestätigung die sechs Kategorien in Outlook an (falls noch nicht vorhanden) und setzt sie je Mail,
4. bietet für jede P1-Mail einen Antwortentwurf an, professionell und einladend, aber ohne Preiszusagen oder unzulässige Versprechen, nur als Entwurf im Drafts-Ordner, nie automatisch gesendet.

## Persönlicher Schreibstil (TONE.md)

Ein Antwortentwurf klingt nur dann brauchbar, wenn er nach dir klingt, nicht nach generischer KI-Prosa. Deshalb lernt der Skill beim ersten Entwurf einmalig deinen eigenen Schreibstil: er sichtet rund 50 deiner zuletzt gesendeten Mails der letzten 90 Tage, destilliert daraus Anrede-Form, typische Begrüßung und Grußformel, Satzlänge, wiederkehrende Wendungen, Formalitätsgrad und Umgang mit Emojis/Ausrufezeichen, und legt das Ergebnis als kurzes Stilprofil in `TONE.md` neben der `.last-run`-Datei ab. Jeder spätere P1-Entwurf orientiert sich daran.

Finden sich weniger als 5 gesendete Mails im Zeitraum, legt der Skill trotzdem eine `TONE.md` an, mit einem neutralen, professionellen Default-Ton und einem sichtbaren Hinweis, dass dieses Profil noch nicht aus dem echten Postfach gelernt wurde. Du bekommst das im Chat gemeldet.

`TONE.md` wird danach nie automatisch verändert, auch nicht wenn sie veraltet wirkt. Du darfst sie von Hand anpassen. Willst du sie aus dem aktuellen Postfach neu lernen lassen, sag Claude:

```
Aktualisiere meinen Ton.
```

## Belegte Messergebnisse

Erster End-to-End-Test (altes Zeitfenster-Modell, gefiltert auf "ungelesen") gegen ein Testpostfach mit 48 fiktiven Mails, Ground Truth in einem Manifest:

- **30 von 30 Mails korrekt klassifiziert**, inklusive exakter Priorität (je 4 P1/P2/P3, 8 Bestandskunden, 5 Bewerbungen, 5 Sonstiges).
- Die Klassifikation lief in diesem Test rein inhaltsbasiert, da alle Testmails vom selben Absender kamen. Im Echtbetrieb kommt die Absender-Historie als zusätzliches Erleichterungssignal dazu.
- 6 Farb-Kategorien wurden angelegt, 32 Mails kategorisiert (inklusive 2 Systemmails als Sonstiges).
- Für alle 4 P1-Anfragen wurden Antwortentwürfe im Drafts-Ordner erstellt, nicht gesendet, ohne Preiszusagen und ohne unzulässige Versprechen.

Wiederholungslauf mit der aktuellen Kategorie- und Zeitfenster-Logik (2026-07-29): erneut 30 von 30 korrekt über alle sechs Kategorien, 4 Antwortentwürfe für Anfragen hoher Priorität erstellt. Dieser Lauf deckte zugleich auf, dass genau die vier wichtigsten Anfragen bereits als gelesen markiert waren, weil zuvor ein Antwortentwurf geöffnet worden war: unter der alten "ungelesen"-Logik wären sie komplett übersehen worden. Das ist der Grund für den Wechsel, gesetzte Kategorie statt Lesestatus als Merkmal für "bearbeitet".

## Grenzen

- Klassifikation ist rein inhaltsbasiert, der Absender fließt bewusst nicht ein (siehe Ausbaustufe).
- Antwortentwürfe werden nie automatisch versendet, immer nur als Entwurf abgelegt.
- Die Testdaten kamen von einem einzigen Absender, echte Absender-Diversität wurde nicht getestet.

## Nächste Ausbaustufe (dokumentiert, nicht vorgebaut)

- Automatische Routine 2-3x täglich statt manuellem Anstoß.
- Absender-Historie (frühere Mails, bekannter Kunde ja/nein) als zusätzliches Klassifikationssignal neben dem Inhalt.

## Was im Bundle liegt

```
posteingang-triage/
├── README.md                          ← das hier
└── skills/
    └── posteingang-triage/
        ├── SKILL.md                   ← klassifiziert, zeigt Digest, kategorisiert, lernt Ton, entwirft
        ├── .last-run                  ← entsteht beim ersten Lauf, Zeitstempel
        └── TONE.md                    ← entsteht beim ersten Entwurf, gelerntes Stilprofil
```
