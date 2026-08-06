# Routines — dein AI OS läuft ohne dich

Routines sind Aufgaben, die Claude zu festen Zeiten **automatisch auf deinem Rechner** ausführt. Du legst sie einmal an, danach halten sie deinen Second Brain in Ordnung, ohne dass du etwas tust.

Vier Routines empfehlen wir zum Start. Die ersten drei bauen aufeinander auf: die erste füllt den Posteingang, die zweite räumt ihn auf, die dritte prüft einmal pro Woche, ob alles heil ist. Die vierte stellt dir morgens deine Schaltstelle mit frischen Daten hin.

---

## Wichtig zuerst: Local Routines, nicht Cloud Routines

Routines gibt es an zwei Stellen, und nur eine davon funktioniert für diese Aufgaben.

| | Wo es läuft | Zugriff auf deine Skills und den Vault |
|---|---|---|
| **Local Routines** (Desktop App) | dein Rechner | ja, vollständig |
| **Cloud Routines** | Anthropic-Server | nein |

Die Routines unten rufen Skills auf und schreiben auf deinen Rechner. In der Cloud gibt es beides nicht. Eine dort angelegte Routine schlägt fehl, und zwar auf eine verwirrende Art: Der Fehler sieht aus wie ein kaputter Skill, ist aber nur der falsche Ort.

**Also immer: Claude Desktop App → Routines → New routine → Local.**

Zwei Einstellungen gelten für alle vier Routines gleich:

- **Permission idealerweise auf „Auto".** Eine Routine läuft unbeaufsichtigt; steht die Permission strenger, bleibt der Lauf mittendrin an einer Bestätigungsfrage hängen, die gerade niemand beantwortet. Auto ist eine Empfehlung, keine Pflicht: Wer restriktiver bleiben will, bestätigt die Berechtigungen beim ersten Lauf einmal dauerhaft.
- **Modell: Sonnet 5 reicht** für alle vier Aufgaben.

Der Rechner muss zur geplanten Zeit laufen und die App offen sein. Schaltet sich der Laptop schlafen, pausiert die Routine. In der Übersicht gibt es dafür einen „Aktiv halten"-Schalter.

---

## Routine 1 — Meetings in den Second Brain

Holt neue Meetings aus Fathom, schreibt sie als strukturierte Notiz in deinen Posteingang und verlinkt automatisch die beteiligten Personen und das passende Projekt.

**Voraussetzung:** Fathom als Connector verbunden, siehe [connector-setup.md](connector-setup.md).

**Name**
```
fathom-sync
```

**Description**
```
Täglicher autonomer Fathom-Sync: neue Meetings aus Fathom MCP nach Obsidian-Vault 01_Inbox/, mit Personen-Cross-Linking und Projekt-Matching.
```

**Instructions**
```
Schreibe zuerst den Lauf-Zeitstempel fürs Dashboard (immer, auch wenn nichts zu tun ist):
`mkdir -p ~/.claude/scheduled-tasks/fathom-sync && date +%Y-%m-%dT%H:%M:%S%z > ~/.claude/scheduled-tasks/fathom-sync/.last-run`

Danach der eigentliche Lauf:
/brain:sync-meetings scheduled
```

**Empfohlener Zeitplan:** täglich, früh morgens (z. B. 06:00). Dann liegt die Nachbereitung von gestern schon da, wenn du den Rechner aufklappst.

**Einstellungen:** Working folder: Mac `~/Documents/Second-Brain`, Windows `C:\Users\<dein-name>\Documents\Second-Brain` · Permission: Auto · Modell: Sonnet 5

---

## Routine 2 — Posteingang einsortieren

Nimmt alles, was sich in `01_Inbox/` angesammelt hat, und legt es an den richtigen Ort: zum Projekt, zur Area, zu den Resources oder den Kontakten. Aktualisiert dabei den Index und die Timeline.

**Name**
```
inbox-sort
```

**Description**
```
Täglicher autonomer Inbox-Sweep im Second Brain.
```

**Instructions**
```
Schreibe zuerst den Lauf-Zeitstempel fürs Dashboard (immer, auch wenn nichts zu tun ist):
`mkdir -p ~/.claude/scheduled-tasks/inbox-sort && date +%Y-%m-%dT%H:%M:%S%z > ~/.claude/scheduled-tasks/inbox-sort/.last-run`

Danach der eigentliche Lauf:
/brain:sort-inbox scheduled
```

**Empfohlener Zeitplan:** täglich, abends. So läuft das Einsortieren nach getaner Arbeit und nicht mitten hinein.

**Einstellungen:** Working folder: Mac `~/Documents/Second-Brain`, Windows `C:\Users\<dein-name>\Documents\Second-Brain` · Permission: Auto · Modell: Sonnet 5

---

## Routine 3 — Wöchentlicher Health-Check

Prüft den ganzen Vault auf Index-Drift, kaputte Wikilinks, fehlende Cross-Referenzen, verwaiste Dateien und veraltete Decisions. Schreibt einen Bericht, ändert aber nichts von selbst.

**Name**
```
vault-health
```

**Description**
```
Wöchentlicher Vault-Health-Check: prüft Index-Drift, kaputte Wikilinks, fehlende Cross-Referenzen, verwaiste Dateien und veraltete Decisions.
```

**Instructions**
```
Schreibe zuerst den Lauf-Zeitstempel fürs Dashboard (immer, auch wenn nichts zu tun ist):
`mkdir -p ~/.claude/scheduled-tasks/vault-health && date +%Y-%m-%dT%H:%M:%S%z > ~/.claude/scheduled-tasks/vault-health/.last-run`

Danach der eigentliche Lauf:
/brain:health-check scheduled
```

**Empfohlener Zeitplan:** wöchentlich, z. B. Sonntagabend oder Montagfrüh.

**Einstellungen:** Working folder: Mac `~/Documents/Second-Brain`, Windows `C:\Users\<dein-name>\Documents\Second-Brain` · Permission: Auto · Modell: Sonnet 5

Der Report landet unter `00_Meta/system/lint-reports/`. Bewusst nur Befund, keine automatischen Korrekturen: Was repariert wird, entscheidest du.

---

## Routine 4 — Schaltstelle morgens frisch

Fährt den lokalen Dashboard-Server hoch, zieht alle Daten neu (Systemzustand, Vault, Postfach, Kalender etc., je nachdem, was bei dir verbunden ist) und öffnet die Schaltstelle im Browser. Wenn du morgens den Rechner aufklappst, steht der aktuelle Stand schon da.

**Voraussetzung:** Dashboard installiert (kommt über `bootstrap.sh` mit), Skill `/aios-dashboard` vorhanden.

**Name**
```
dashboard-refresh
```

**Description**
```
Täglicher Frisch-Start der AIOS-Schaltstelle: Server hochfahren, Shell-Collectors und private Connector-Daten (Postfach, Kalender etc.) neu ziehen, Dashboard öffnen.
```

**Instructions**
```
Schreibe zuerst den Lauf-Zeitstempel fürs Dashboard (immer, auch wenn nichts zu tun ist):
`mkdir -p ~/.claude/scheduled-tasks/dashboard-refresh && date +%Y-%m-%dT%H:%M:%S%z > ~/.claude/scheduled-tasks/dashboard-refresh/.last-run`

Danach der eigentliche Lauf:
/aios-dashboard refresh
```

**Empfohlener Zeitplan:** täglich, kurz vor deinem Arbeitsbeginn (z. B. 09:30). Der Browser öffnet sich dabei automatisch.

**Einstellungen:** Working folder: Pflichtfeld, Mac `~/.claude`, Windows `C:\Users\<dein-name>\.claude` (siehe Abschnitt unten) · Permission: Auto · Modell: Sonnet 5

---

## Working folder für Routine 4 setzen

Die ersten drei Routines bekommen als Working folder den Second Brain (`~/Documents/Second-Brain`); der ist im Auswahldialog normal sichtbar, einfach hinklicken. Routine 4 ist der Sonderfall, denn sie schreibt an zwei festen Stellen: in `~/.claude/dashboard/` (Server, Token, Daten) und in `~/.claude/scheduled-tasks/dashboard-refresh/` (Lauf-Zeitstempel). Der gemeinsame Nenner ist `~/.claude`.

Wähle **nicht** `~/.claude/dashboard` allein. Dann liegt der Zeitstempel außerhalb des erlaubten Bereichs, und die Routine bleibt nachts an einer Rückfrage hängen, die niemand beantwortet.

Im Routine-Formular beim Feld **Working folder** auf **Anderen Ordner auswählen** klicken, dann je nach System:

**Mac:** `.claude` ist ein versteckter Ordner (der Punkt am Anfang), im Dialog siehst du ihn nicht. Deshalb **Cmd + Shift + G** drücken, in die Eingabezeile `~/.claude` einfügen, **Enter**, dann **Auswählen** klicken.

**Windows:** Im Dialog zu **Dieser PC → Windows (C:) → Benutzer → <dein Konto>** navigieren; dort ist der Ordner `.claude` sichtbar, anklicken und bestätigen. Alternativ **Strg + L** drücken und den vollständigen Pfad eintippen, z. B. `C:\Users\<dein-name>\.claude`. Wichtig: nicht `~/.claude` eintippen, die Tilde versteht Windows nicht und der Dialog antwortet mit „You can't open this location using this program".

Danach steht der Pfad im Feld und die Routine läuft unbeaufsichtigt durch.

---

## So legst du eine Routine an

1. Claude Desktop App öffnen
2. In der Seitenleiste auf **Routines**
3. **New routine** → **Local** wählen
4. **Name** kopieren und einsetzen
5. **Description** kopieren und einsetzen
6. **Instructions** kopieren und einsetzen
7. **Working folder** setzen (Routines 1 bis 3: der Second Brain, `~/Documents/Second-Brain`. Routine 4: Mac `~/.claude`, Windows `C:\Users\<dein-name>\.claude`, siehe Abschnitt oben)
8. **Schedule** wählen, **Permission** auf **Auto**, **Modell** auf **Sonnet 5**
9. Speichern, dann **„Aktiv halten"** in der Übersicht einschalten

Jedes Feld hat oben einen eigenen Kopier-Block. Du kopierst also dreimal einzeln, statt einen Sammelblock auseinanderzupflücken.

Steht die Permission nicht auf Auto, fragt Claude beim ersten Lauf nach Berechtigungen. Bestätige sie einmal dauerhaft, sonst bleibt die Routine beim nächsten unbeaufsichtigten Lauf hängen.

---

## Prüfen, ob es läuft

Die Routine schreibt ihren Lauf in `00_Meta/system/vault-log.md` mit. Eine Zeile pro Durchgang. Wenn dort nach dem ersten geplanten Zeitpunkt nichts steht, lief sie nicht.

Zusätzlich hinterlegt die erste Instruktions-Zeile bei **jedem** Lauf einen Zeitstempel in `~/.claude/scheduled-tasks/<name>/.last-run` — auch wenn es nichts zu tun gab. Das lokale Dashboard liest genau diese Datei und zeigt dann die exakte Uhrzeit des letzten Laufs („heute 10:30") statt nur des Datums.

Wichtig: Dieser Zeitstempel bedeutet nur „Lauf gestartet", nicht „Lauf erfolgreich durchgelaufen". Ob der Lauf tatsächlich erfolgreich war oder mit einem Fehler abgebrochen ist, liest das Dashboard separat aus den Session-Transcripts der Routine aus und zeigt es sowohl auf der Automationen-Seite (Verlauf der letzten Läufe, Fehlertext) als auch im System-Health-Check an.

Häufigste Ursachen, in dieser Reihenfolge:

1. Routine als Cloud Routine statt als Local Routine angelegt
2. Laptop war zur geplanten Zeit zu, „Aktiv halten" nicht eingeschaltet
3. Permission nicht auf Auto und Berechtigungen beim ersten Lauf nicht dauerhaft bestätigt
4. Connector abgelaufen — bei Fathom hilft neu verbinden

---

## Wo die Routines auf der Festplatte liegen

```
~/.claude/scheduled-tasks/<name>/SKILL.md
```

Dort stehen `name`, `description` und der auszuführende Befehl. Du kannst die Datei direkt bearbeiten, die Änderung greift beim nächsten Lauf.

Was **nicht** in dieser Datei steht: Zeitplan, Modell, Berechtigungsmodus und ob die Routine aktiv ist. Das verwaltet die App separat. Ein Backup dieser Datei allein stellt eine Routine also nicht wieder her.
