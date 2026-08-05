# AIOS-Dashboard — Installation & Betrieb

Ein lokales Cockpit für dein Claude-Code-Setup: Projekte, offene Aufgaben, Postfach, Kalender, System-Health und Second-Brain-Kennzahlen auf einen Blick. Läuft ausschließlich lokal auf `http://127.0.0.1:4747`.

> **Hinweis:** Dieses Dashboard **wird von `bootstrap.sh` mitinstalliert** (nach `~/.claude/dashboard`), und der Skill `/aios-dashboard` ist Teil des Standard-Skill-Satzes. Diese Anleitung beschreibt den Betrieb und, für den seltenen Fall ohne `bootstrap.sh`, die manuelle Installation. Laufzeitdaten (`.token`, `.pid`, `data/*.json`) bleiben lokal und werden nie überschrieben.

---

## 1. Voraussetzungen

| Pflicht | Wofür | Prüfen |
|---|---|---|
| **Node.js ≥ 16** | Der Server ist ein einzelnes Node-Skript und nutzt **nur Node-Built-ins** — **kein `npm install`, keine Fremd-Dependencies**. | `node --version` |
| **python3** | Die Collectors bauen die JSON-Daten (Standard auf macOS vorhanden). Unter Windows ist `python3` oft nur der Microsoft-Store-Stub: `python --version` bzw. `py -3 --version` prüfen. | `python3 --version` |
| **bash** | Die Collectors sind Bash-Skripte (macOS-Standard). | `bash --version` |

| Optional | Wofür | Ohne? |
|---|---|---|
| **gws-CLI** | Zieht einen **zweiten** Gmail-/Kalender-Account headless (0 Tokens). | Das Zweitkonto bleibt leer, sichtbar als „nicht installiert". Das Dashboard funktioniert normal weiter. |
| **claude-Binary** | Ausführen von „Claude-Aktionen" aus dem Dashboard heraus. | Der Server prüft das Binary beim Start; fehlt es, sind die betroffenen Aktions-Buttons sofort als inaktiv markiert (nicht erst nach dem Klick). |
| **ccusage** (`npm i -g ccusage`) | Kosten-/Nutzungsauswertung. | Die Nutzungs-Kachel zeigt einen Installationshinweis. |

**Voraussetzungen automatisch prüfen (read-only, ändert nichts):**
```bash
bash dashboard/check-prereqs.sh
```

---

## 2. Betrieb (nach `bootstrap.sh`)

`bootstrap.sh` hat das Dashboard bereits nach `~/.claude/dashboard` kopiert und den Skill `/aios-dashboard` installiert. Der einfachste Weg ist der Skill in einer Claude-Code-Session:

```
/aios-dashboard
```

Das startet den Server bei Bedarf, zieht frische Live-Daten und öffnet den Browser mit gültigem Token. Manuell geht es auch:

```bash
# Server starten (im Hintergrund, mit Log)
nohup node ~/.claude/dashboard/server.mjs > ~/.claude/dashboard/server.log 2>&1 &

# Im Browser öffnen (Token wird beim Start erzeugt)
open "http://127.0.0.1:4747/?t=$(cat ~/.claude/dashboard/.token)"
```

**Unter Windows (Git Bash)** statt `open`:
```bash
powershell.exe -NoProfile -Command "Start-Process 'http://127.0.0.1:4747/?t=$(cat ~/.claude/dashboard/.token)'"
```
Beim ersten Serverstart fragt die Windows-Firewall ggf. nach: der Server lauscht nur auf `127.0.0.1`, der Prompt kann mit „Abbrechen" geschlossen werden, es funktioniert trotzdem.

**Ohne `bootstrap.sh` (manuelle Installation)** aus dem Repo-Wurzelverzeichnis (`ai-os-core/`):
```bash
cp -R dashboard ~/.claude/dashboard
cp -R claude/skills/aios-dashboard ~/.claude/skills/aios-dashboard
bash ~/.claude/dashboard/check-prereqs.sh
```

Beim ersten Öffnen sind viele Kacheln noch leer — die Daten kommen mit dem ersten „Aktualisieren" (Schritt 3 unten) bzw. über den Skill (Schritt 4 unten).

**Server stoppen:**
```bash
kill "$(cat ~/.claude/dashboard/.pid)"
```
**Unter Windows (Git Bash)** statt `kill`:
```bash
taskkill //PID $(cat ~/.claude/dashboard/.pid) //F
```
(Doppelte Slashes, weil Git Bash `/PID` und `/F` sonst als Pfad umzuinterpretieren versucht — MSYS-Pfadkonvertierung.)

---

## 3. Live-Daten über den Skill

Der reine Server kann **keine** Connectoren aufrufen. Um dein **Postfach** und deinen **privaten Kalender** frisch zu ziehen, gibt es den Skill `/aios-dashboard` (bereits via `bootstrap.sh` installiert), der in einer claude.ai-Session läuft:

```
/aios-dashboard
```
Das startet den Server bei Bedarf, zieht die privaten Live-Daten (Postfach + Kalender) und öffnet den Browser.

> **Postfach anbinden:** Dein primäres Konto läuft über den **MCP-Gmail-Connector** (in claude.ai unter Einstellungen → Connectors aktivieren). Ein optionales zweites Konto läuft über die **gws-CLI**. Ist kein Konto angebunden, zeigt die Inbox-Kachel einen **klaren Hinweis „Kein Postfach angebunden"** — sie schlägt nicht still fehl.

---

## 4. Was drin ist und wie die Logik läuft

```
dashboard/
├── server.mjs        Ein Node-Prozess, bindet nur 127.0.0.1:4747, Token-Auth pro Route
├── public/           Frontend (App-Shell + Views: index.html, aios-*.js)
├── collectors/       Bash-Skripte, die die Daten sammeln (read-only ggü. Vault/Projekten)
├── actions.json      Katalog der Aktions-Buttons
└── data/             Ausgabe der Collectors (JSON), bleibt bis zum ersten Lauf leer

(Der /aios-dashboard-Skill liegt im Repo unter claude/skills/aios-dashboard/ und wird nach ~/.claude/skills/ installiert.)
```

**Zwei getrennte Datenwege:**

1. **„Aktualisieren"-Knopf / `POST /api/refresh` (headless, 0 Tokens):** ruft `collectors/refresh.sh` auf. Die Collectors lesen lokal (Projekt-Status-Dateien, Vault, Nutzung, Skills) und — falls die gws-CLI da ist — das gws-Zweitkonto. Ergebnis landet als `data/*.json`. **Dieser Weg kann keine Connectoren.**
2. **Skill `/aios-dashboard` (interaktive Session):** zieht zusätzlich dein **primäres Postfach** und den **privaten Kalender** über die claude.ai-Connectoren und legt sie als `data/inbox.json` / `data/heute.json` ab. Der Server liest diese Dateien danach nur noch.

**Token-Sicherheit:** Bei jedem Start wird ein neues Zufalls-Token nach `~/.claude/dashboard/.token` geschrieben (0600). Jede Route verlangt es; zusätzlich wird der Origin/Referer geprüft. Der Server ist damit nur lokal und nur für dich erreichbar.

**Fehler werden sichtbar gemacht (kein stiller Fehler):**
- Kein Postfach angebunden → Inbox zeigt „Kein Postfach angebunden" mit Anleitung.
- Connector-/Auth-Fehler → das betroffene Konto wird als „Quelle nicht erreichbar" markiert, nie als „0 ungelesen".
- gws-CLI nicht installiert → Zweitkonto/Kalender als „nicht installiert" gekennzeichnet, kein falsches „frei".
- Fehlende Daten insgesamt → Kachel zeigt einen Hinweis statt leer zu bleiben.

---

## 5. Häufige Fälle

- **Port 4747 belegt:** Der Server meldet das klar und beendet sich (kein zweiter Prozess). Alten Prozess über `kill "$(cat ~/.claude/dashboard/.pid)"` beenden (Windows/Git Bash: `taskkill //PID $(cat ~/.claude/dashboard/.pid) //F`).
- **Autostart beim Login:** optional per launchd möglich — Beispiel-Plist steht in `README.md` (Abschnitt „Autostart"), muss manuell angelegt werden.
- **Collector einzeln laufen lassen:** `bash ~/.claude/dashboard/collectors/portfolio.sh` (analog für die anderen). Details in `README.md`.
