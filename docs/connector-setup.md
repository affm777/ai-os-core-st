# MCP-Connector-Setup — AI Operating System

Anleitung zur Einrichtung der MCP-Connectors für das AI Operating System nach dem Pre-Call.

MCP (Model Context Protocol) erlaubt Claude Code direkten Zugriff auf deine Apps (Gmail, Calendar, Fathom-Meetings). Diese Verbindungen sind nicht Teil von `bootstrap.sh` — sie werden hier einmalig per Browser-OAuth eingerichtet.

---

## Was dieses Doc NICHT ist

Kein Skript und keine Schritt-für-Schritt-Begleitung. Diese Anleitung ist eine Referenz zum eigenständigen Einrichten und Nachschlagen der Connectors.

---

## Sektion 1: Anthropic Built-in Connectors (Gmail, Calendar, Drive)

Gmail, Google Calendar und Google Drive sind **eingebaute Anthropic Connectors** — sie sind direkt in claude.ai verfügbar und werden nach der OAuth-Verbindung automatisch in Claude Code synchronisiert.

### Vorgehen (einmalig pro Connector)

1. Öffne: [https://claude.ai/settings/connectors](https://claude.ai/settings/connectors)
2. Suche den gewünschten Connector (Gmail, Google Calendar, Google Drive)
3. Klicke **"Connect"** oder **"+"** neben dem Connector
4. Google OAuth-Bildschirm öffnet sich → **"Zulassen"** / **"Allow"** klicken
5. Warte auf Bestätigung (kurze Ladezeit)
6. Connector erscheint als aktiv in der Liste

**Hinweis:** Nach der Verbindung auf claude.ai sind die Connectors automatisch in Claude Code verfügbar — kein zusätzlicher Schritt nötig.

### Gmail einrichten

1. [claude.ai/settings/connectors](https://claude.ai/settings/connectors) öffnen
2. "Gmail" klicken → "Connect"
3. Google-Account auswählen → "Zulassen"
4. Testen in Claude Code: *"Zeig mir meine letzten 5 E-Mails"*

### Google Calendar einrichten

1. [claude.ai/settings/connectors](https://claude.ai/settings/connectors) öffnen
2. "Google Calendar" klicken → "Connect"
3. Google-Account auswählen → "Zulassen"
4. Testen: *"Was steht morgen in meinem Kalender?"*

### Google Drive einrichten

1. [claude.ai/settings/connectors](https://claude.ai/settings/connectors) öffnen
2. "Google Drive" klicken → "Connect"
3. Google-Account auswählen → "Zulassen"

**Hinweis:** Google Drive Connector ist grundsätzlich verfügbar. Bei Problemen: Drive-Aufgaben alternativ im claude.ai Web-Chat (nicht Claude Code) durchführen.

---

## Sektion 2: Fathom Custom Connector (Meeting-Transkripte)

Fathom ist **kein eingebauter Anthropic Connector**, sondern ein eigener Remote-MCP-Server. Es gibt zwei Wege:

### Variante A: Über claude.ai (empfohlen — funktioniert überall)

1. Öffne: [https://claude.ai/settings/connectors](https://claude.ai/settings/connectors)
2. Klicke **"Add custom connector"** oder **"+ Custom"**
3. Gib folgende URL ein: `https://api.fathom.ai/mcp`
4. Klicke auf "Connect" / "Add"
5. Fathom OAuth-Flow: In deinem Fathom-Account einloggen und Zugriff erlauben
6. Connector erscheint als aktiv

**Voraussetzung:** Aktiver Fathom-Account mit aufgezeichneten Meetings.

### Variante B: Über Claude Code CLI (lokaler Scope, alternativ)

```bash
claude mcp add fathom -- npx mcp-remote@latest https://api.fathom.ai/mcp
```

Dieser Weg registriert Fathom nur für das aktuelle Projekt (`--scope local`). Für globale Verfügbarkeit Variante A bevorzugen.

**Hinweis:** Variante B ist für den Einstieg nicht nötig, sie lohnt sich erst bei fortgeschrittener Nutzung.

---

## Sektion 3: Verifikation

Nach dem Einrichten der Connectors: Claude Code starten und testen.

### Welche Connectors sind aktiv?

Starte Claude Code und frage:

```
Welche MCP-Connectors und Tools hast du gerade aktiv?
```

Claude listet alle verbundenen MCPs mit ihren Tools. Erwartet (nach vollständiger Einrichtung):
- Gmail-Tools (z.B. `list_emails`, `search_emails`)
- Google Calendar-Tools (z.B. `list_events`, `create_event`)
- Fathom-Tools (z.B. `list_meetings`, `get_meeting_transcript`)

### Schnell-Test Gmail

```
Suche meine letzten 3 ungelesenen E-Mails
```

### Schnell-Test Calendar

```
Was sind meine nächsten 5 Termine?
```

### Schnell-Test Fathom (für /brain:sync-meetings)

```
Liste meine letzten 5 aufgezeichneten Meetings auf
```

---

## Weiterführend

Sobald alle Connectors aktiv sind, funktionieren die Workshop-Slash-Commands:

- `/brain:sync-meetings` — Fathom-Transkripte in Obsidian Vault übertragen
- `/resume-session`: Session mit Vault-Context starten (nutzt Vault-Daten, nicht direkt Connectors)

Was der einzelne Slash-Command genau tut, steht in seiner eigenen Beschreibung: `/help` listet sie auf, und jeder Skill erklärt sich beim ersten Aufruf selbst.
