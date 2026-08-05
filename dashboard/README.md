# AIOS-Dashboard — Betriebsdoku (Stufe 1)

Lokale Mini-App als Cockpit für das lokale Claude-Code-Setup. Läuft ausschließlich auf `127.0.0.1:4747`, keine Fremd-Dependencies, kein `npm install`.

## Start / Stop

Normalerweise über den Skill `/aios-dashboard` (startet bei Bedarf automatisch, öffnet den Browser mit gültigem Token). Manuell:

```bash
# Start (detached, mit Log)
nohup node ~/.claude/dashboard/server.mjs > ~/.claude/dashboard/server.log 2>&1 &

# Stop
kill "$(cat ~/.claude/dashboard/.pid)"

# Health-Ping
TOKEN=$(cat ~/.claude/dashboard/.token)
curl -s "http://127.0.0.1:4747/api/data?t=${TOKEN}" | head -c 200
```

`/aios-dashboard stop` beendet den Server sauber, `/aios-dashboard refresh` stößt einen Collector-Neulauf an und öffnet danach den Browser.

## Token

Bei jedem Server-Start wird ein neues Zufalls-Token nach `~/.claude/dashboard/.token` geschrieben (0600, nur Owner lesbar). Unter Windows ist 0600 wirkungslos (NTFS kennt keine Unix-Rechte), dort schützt stattdessen die Benutzerprofil-ACL. Jede Route verlangt das Token (Query-Param `t=` beim ersten Aufruf, danach per HttpOnly-Cookie). Ohne gültiges Token → `403`. Zusätzlich wird der Origin/Referer-Header geprüft (nur `127.0.0.1:4747`/`localhost:4747` oder leer erlaubt), das schützt gegen Cross-Site-Requests aus fremden Browser-Tabs.

Token niemals im Chat oder in Logs ausgeben — nur der Pfad `~/.claude/dashboard/.token` ist referenzierbar.

## Port

Fest auf `4747`. Bei belegtem Port meldet der Server das klar auf `stderr` und beendet sich mit Exit-Code 1 (kein stiller Fehlstart, kein zweiter Prozess auf demselben Port).

## Statusleisten-Button

Die Statusleiste (`~/.claude/hooks/aios-statusline.js`) hängt rechts einen anklickbaren `⊞ AIOS`-Button an, sobald der Dashboard-Server läuft. Der Button liest bei jedem Render das aktuelle `.token` frisch und baut daraus einen OSC-8-Hyperlink auf `http://127.0.0.1:4747/`. Er bleibt also immer gültig, solange der Server läuft, und verschwindet automatisch, wenn er gestoppt ist.

- **Kein Bookmark nötig:** Der Button ersetzt einen Bookmark, weil das Token bei jedem Server-Neustart rotiert und ein alter Link damit `403` liefert. Der Button liest immer das frische Token.
- **Terminal:** Der Klick braucht ein Terminal, das OSC-8-Hyperlinks kann (iTerm2, WezTerm, VS Code/Cursor-Terminal). In macOS Terminal.app ist der Button sichtbar, aber nicht klickbar.
- **Token im Scrollback:** Die vollständige Adresse samt Token steckt in der (unsichtbaren) Escape-Sequenz und landet damit im Scrollback-Puffer des Terminals. Auf einem privaten Rechner unkritisch; wer das nicht will, nutzt den Button nicht.
- **Bestandsnutzer:** Wer schon eine `~/.claude/settings.json` hat, bekommt die neue Statusline nicht automatisch (bootstrap überschreibt vorhandene settings nie). Einmalig den `statusLine`-Block aus `settings.json.template` übernehmen: `"command": "bash \"$HOME/.claude/hooks/noderun.sh\" \"$HOME/.claude/hooks/aios-statusline.js\""`.

## Dateien und API-Kontrakt

Für den aktuellen Datei-Baum, den Datenweg (Aktualisieren-Knopf vs. `/aios-dashboard`-Skill) und die Sektionsliste ist `INSTALL.md` die gepflegte Quelle (Abschnitt 4 „Was drin ist und wie die Logik läuft"). Diese Datei hier bleibt bewusst auf reine Betriebsdetails beschränkt (Start/Stop, Token, Port, Statusleiste, Autostart, Briefing/Scheduling), damit es nicht zwei driftende Beschreibungen desselben Kontrakts gibt.

## Collectors einzeln laufen lassen

```bash
bash ~/.claude/dashboard/collectors/portfolio.sh
bash ~/.claude/dashboard/collectors/vault-stats.sh
bash ~/.claude/dashboard/collectors/usage.sh
bash ~/.claude/dashboard/collectors/skills.sh        # -> skills.json + commands.json
bash ~/.claude/dashboard/collectors/automationen.sh  # -> automationen.json
bash ~/.claude/dashboard/collectors/refresh.sh   # alle + check.sh light
```

Alle Collectors sind read-only gegenüber Vault/Projekten, einziges Schreibziel ist `data/*.json`.

## Autostart (optional, launchd — dokumentiert, NICHT installiert)

Für automatischen Start beim Login kann ein LaunchAgent angelegt werden. Beispiel-Plist (manuell anlegen unter `~/Library/LaunchAgents/com.aios.dashboard.plist`, NICHT automatisch von diesem Skill/Server erzeugt):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.aios.dashboard</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>/Users/DEIN-BENUTZERNAME/.claude/dashboard/server.mjs</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/Users/DEIN-BENUTZERNAME/.claude/dashboard/server.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/DEIN-BENUTZERNAME/.claude/dashboard/server.log</string>
</dict>
</plist>
```

Laden: `launchctl load ~/Library/LaunchAgents/com.aios.dashboard.plist`
Entladen/Deinstallieren: `launchctl unload ~/Library/LaunchAgents/com.aios.dashboard.plist && rm ~/Library/LaunchAgents/com.aios.dashboard.plist`

Node-Pfad im Beispiel anpassen (`command -v node`, bei nvm-Installationen versioniert unter `~/.nvm/versions/node/`).

## Autostart unter Windows (Aufgabenplanung)

Für automatischen Start beim Login kann analog eine Aufgabe in der Windows-Aufgabenplanung angelegt werden (dokumentiertes Beispiel, NICHT automatisch installiert):

```bash
schtasks /Create /SC ONLOGON /TN "AIOS Dashboard" /TR "\"C:\Program Files\nodejs\node.exe\" \"%USERPROFILE%\.claude\dashboard\server.mjs\""
```

Node-Pfad im Beispiel anpassen (bei nvm-windows-Installationen versioniert unter `%APPDATA%\nvm\`).
Entfernen: `schtasks /Delete /TN "AIOS Dashboard" /F`

## Bekannte Grenzen

- Aufgaben lassen sich über Checkboxen ab-/anhaken und entfernen (mit Rückgängig), Projekte manuell auf aktiv/ruhend setzen und in der Reihenfolge sortieren — das schreibt gezielt in `### Pending Todos` der jeweiligen `STATE.md`. Freitext-Änderungen an der Status-Datei darüber hinaus laufen weiter über die Claude-Code-Session, nicht über das Dashboard.
- `heute` und `recommendations` werden ausschließlich vom `/briefing`-Skill befüllt (siehe Abschnitt "Briefing + Scheduling").
- `ccusage` optional: fehlt es, zeigt `usage.json` `{available: false, hint: "npm i -g ccusage"}`.

## Briefing + Scheduling

Der Skill `/briefing` (`~/.claude/skills/briefing/SKILL.md`) füllt `data/heute.json` und `data/recommendations.json`:

- **Täglicher Modus** (`/briefing`, ohne Argument): `check.sh light` + Kalender (gws-calendar-agenda) + Mail-Triage (gws-gmail-triage, nur Betreffs/Zähler, keine Bodies) + fällige Airtable-Deals + `refresh.sh`, danach eine Slack-Essenz (max. 8 Zeilen). Zustellung ist standardmäßig ein Dry-Run (nur Chat-Anzeige), echter Versand nur mit Argument `send` und nach expliziter Freigabe des Dry-Run-Texts im selben Gespräch.
- **Wochen-Modus** (`/briefing weekly`): zusätzlich `check.sh full` + `claude doctor` + `/brain:health-check scheduled`, plus `collectors/tuning-signals.sh` (deterministischer Signal-Sammler über die Session-Logs der letzten 7 Tage: Sessions/Skill-Aufrufe/Wrap-up-Quote/Fehler-Marker je Projekt, ungenutzte Skills). Daraus maximal drei Tuning-Empfehlungen in `data/recommendations.json`, mit stabilen ids (dismissed/done-Einträge werden nie erneut vorgeschlagen).
- Aktions-Katalog: `briefing` ist in `actions.json` als `kind: claude`, `prompt: "/briefing"` eingetragen (täglicher Dry-Run-Lauf über den Dashboard-Button, analog zu `summary`).

### Scheduled Task `morning-briefing` (noch NICHT angelegt)

Erst nach mindestens 5 manuellen `/briefing`-Läufen und expliziter Freigabe durch den Nutzer wird ein Scheduled Task angelegt, analog zum bestehenden `fathom-sync`-Muster:

```
~/.claude/scheduled-tasks/morning-briefing/SKILL.md
---
name: morning-briefing
description: Täglicher autonomer Briefing-Lauf: System-Check light, Kalender/Mail/Deals-Aggregat, Slack-Essenz.
---

/briefing
```

Registrierung der Cron-Kadenz danach über den `schedule`-Skill (Claude-Code-Routinen), wie bei den bestehenden Tasks unter `~/.claude/scheduled-tasks/` (`fathom-sync`, `inbox-sort`, `vault-health`). Wichtig: der Scheduled Task ruft `/briefing` OHNE `send`-Argument auf, solange kein separater, noch zu treffender Entscheid für automatischen Slack-Versand vorliegt — bis dahin bleibt jeder Lauf ein Dry-Run, den der Nutzer manuell im Dashboard/Chat einsieht.
