# Routines — dein AI OS läuft ohne dich

Routines sind Aufgaben, die Claude zu festen Zeiten **automatisch auf deinem Rechner** ausführt. Du legst sie einmal an, danach halten sie deinen Second Brain in Ordnung, ohne dass du etwas tust.

Vier Routines empfehlen wir zum Start. Die ersten drei bauen aufeinander auf: die erste füllt den Posteingang, die zweite räumt ihn auf, die dritte prüft einmal pro Woche, ob alles heil ist. Die vierte stellt dir morgens deine Schaltstelle mit frischen Daten hin.

---

## Wichtig zuerst: Desktop App, nicht Cowork

Routines gibt es an zwei Stellen, und nur eine davon funktioniert für diese drei Aufgaben.

| | Wo es läuft | Zugriff auf deine Skills und den Vault |
|---|---|---|
| **Routines in der Desktop App** | dein Rechner | ja, vollständig |
| **Cloud-Routines (Cowork)** | Anthropic-Server | nein |

Die drei Routines unten rufen alle einen `/brain:`-Skill auf und schreiben in deinen lokalen Vault. In der Cloud gibt es beides nicht. Eine dort angelegte Routine schlägt fehl, und zwar auf eine verwirrende Art: Der Fehler sieht aus wie ein kaputter Skill, ist aber nur der falsche Ort.

**Also immer: Claude Desktop App → Routines → New routine → Local.**

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

Der Report landet unter `00_Meta/system/lint-reports/`. Bewusst nur Befund, keine automatischen Korrekturen: Was repariert wird, entscheidest du.

---

## Routine 4 — Schaltstelle morgens frisch

Fährt den lokalen Dashboard-Server hoch, zieht alle Daten neu (Systemzustand, Vault, Postfach, Kalender, Vertrieb) und öffnet die Schaltstelle im Browser. Wenn du morgens den Rechner aufklappst, steht der aktuelle Stand schon da.

**Voraussetzung:** Dashboard installiert (kommt über `bootstrap.sh` mit), Skill `/aios-dashboard` vorhanden.

**Name**
```
dashboard-refresh
```

**Description**
```
Täglicher Frisch-Start der AIOS-Schaltstelle: Server hochfahren, Shell-Collectors und private Connector-Daten (Postfach, Kalender, Vertrieb) neu ziehen, Dashboard öffnen.
```

**Instructions**
```
Schreibe zuerst den Lauf-Zeitstempel fürs Dashboard (immer, auch wenn nichts zu tun ist):
`mkdir -p ~/.claude/scheduled-tasks/dashboard-refresh && date +%Y-%m-%dT%H:%M:%S%z > ~/.claude/scheduled-tasks/dashboard-refresh/.last-run`

Danach der eigentliche Lauf:
/aios-dashboard refresh
```

**Working folder:** Pflichtfeld für diese Routine, siehe eigener Abschnitt unten.

**Empfohlener Zeitplan:** täglich, kurz vor deinem Arbeitsbeginn (z. B. 09:30). Der Browser öffnet sich dabei automatisch. Willst du das nicht, hänge an die Instructions an: `aber Schritt 6 (Browser öffnen) überspringen`.

---

## Working folder für Routine 4 setzen

Die ersten drei Routines brauchen kein bestimmtes Verzeichnis. Routine 4 schon, denn sie schreibt an zwei festen Stellen: in `~/.claude/dashboard/` (Server, Token, Daten) und in `~/.claude/scheduled-tasks/dashboard-refresh/` (Lauf-Zeitstempel). Der gemeinsame Nenner ist `~/.claude`.

Wähle **nicht** `~/.claude/dashboard` allein. Dann liegt der Zeitstempel außerhalb des erlaubten Bereichs, und die Routine bleibt nachts an einer Rückfrage hängen, die niemand beantwortet.

`~/.claude` ist ein versteckter Ordner (der Punkt am Anfang), im Auswahldialog siehst du ihn deshalb nicht. So kommst du trotzdem hin:

1. Im Routine-Formular beim Feld **Working folder** auf **Anderen Ordner auswählen** klicken
2. Es öffnet sich der macOS-Ordner-Dialog
3. **Cmd + Shift + G** drücken, es erscheint eine Eingabezeile
4. Diesen Pfad hineinkopieren:
   ```
   ~/.claude
   ```
5. **Enter** drücken, der Dialog springt in den Ordner
6. **Auswählen** klicken

Danach steht `~/.claude` (bzw. `/Users/<dein-name>/.claude`) im Feld und die Routine läuft unbeaufsichtigt durch.

> **Unter Windows:** Im Datei-Dialog den Pfad `C:\Users\<dein-name>\.claude` direkt in die Adressleiste oben eintippen und Enter drücken. Ist der Ordner nicht sichtbar, im Explorer unter **Ansicht** die Option **Ausgeblendete Elemente** einblenden.

---

## So legst du eine Routine an

1. Claude Desktop App öffnen
2. In der Seitenleiste auf **Routines**
3. **New routine** → **Local** wählen
4. **Name** kopieren und einsetzen
5. **Description** kopieren und einsetzen
6. **Instructions** kopieren und einsetzen
7. **Working folder** setzen, falls die Routine ein bestimmtes Verzeichnis braucht (Routines 1 bis 3: nicht nötig. Routine 4: `~/.claude`, siehe Abschnitt oben)
8. **Schedule** wählen
9. Speichern, dann **„Aktiv halten"** in der Übersicht einschalten

Jedes Feld hat oben einen eigenen Kopier-Block. Du kopierst also dreimal einzeln, statt einen Sammelblock auseinanderzupflücken.

Beim ersten Lauf fragt Claude nach Berechtigungen. Bestätige sie einmal dauerhaft, sonst bleibt die Routine beim nächsten unbeaufsichtigten Lauf hängen.

---

## Prüfen, ob es läuft

Die Routine schreibt ihren Lauf in `00_Meta/system/vault-log.md` mit. Eine Zeile pro Durchgang. Wenn dort nach dem ersten geplanten Zeitpunkt nichts steht, lief sie nicht.

Zusätzlich hinterlegt die erste Instruktions-Zeile bei **jedem** Lauf einen Zeitstempel in `~/.claude/scheduled-tasks/<name>/.last-run` — auch wenn es nichts zu tun gab. Das lokale Dashboard liest genau diese Datei und zeigt dann die exakte Uhrzeit des letzten Laufs („heute 10:30") statt nur des Datums.

Wichtig: Dieser Zeitstempel bedeutet nur „Lauf gestartet", nicht „Lauf erfolgreich durchgelaufen". Ob der Lauf tatsächlich erfolgreich war oder mit einem Fehler abgebrochen ist, liest das Dashboard separat aus den Session-Transcripts der Routine aus und zeigt es sowohl auf der Automationen-Seite (Verlauf der letzten Läufe, Fehlertext) als auch im System-Health-Check an.

Häufigste Ursachen, in dieser Reihenfolge:

1. Routine in Cowork statt in der Desktop App angelegt
2. Laptop war zur geplanten Zeit zu, „Aktiv halten" nicht eingeschaltet
3. Berechtigungen beim ersten Lauf nicht dauerhaft bestätigt
4. Connector abgelaufen — bei Fathom hilft neu verbinden

---

## Wo die Routines auf der Festplatte liegen

```
~/.claude/scheduled-tasks/<name>/SKILL.md
```

Dort stehen `name`, `description` und der auszuführende Befehl. Du kannst die Datei direkt bearbeiten, die Änderung greift beim nächsten Lauf.

Was **nicht** in dieser Datei steht: Zeitplan, Modell, Berechtigungsmodus und ob die Routine aktiv ist. Das verwaltet die App separat. Ein Backup dieser Datei allein stellt eine Routine also nicht wieder her.
