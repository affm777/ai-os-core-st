# Troubleshooting — Windows

Bekannte Probleme beim Windows-Setup, jeweils Symptom → Ursache → Lösung. Für macOS-spezifische Probleme siehe [../troubleshooting.md](../troubleshooting.md).

---

## 1) `bash: $'\r': command not found`

**Symptom:** Beim Ausführen eines Skripts (z.B. `bash windows/preflight.sh`) erscheinen Fehlermeldungen wie `$'\r': command not found` oder das Skript bricht mitten im Ablauf unerwartet ab.

**Ursache:** Windows-Zeilenenden (CRLF) statt Unix-Zeilenenden (LF) in der Skript-Datei. Bash interpretiert das `\r` am Zeilenende als Teil des Befehls.

**Lösung:** Das Repo erzwingt LF für Shell-Skripte über `.gitattributes`, ein frischer `git clone` sollte das Problem also nicht zeigen. Tritt es trotzdem auf:
1. Repo neu klonen (`git clone https://github.com/affm777/ai-os-core-st.git ~/ai-os-core`) statt die bestehende Kopie zu reparieren.
2. Falls du die Datei selbst in einem Windows-Editor bearbeitet hast: den Editor auf LF-Zeilenenden umstellen (z.B. in VS Code unten rechts in der Statusleiste "CRLF" anklicken → "LF" wählen) und erneut speichern.

---

## 2) `python` öffnet den Microsoft Store statt Python auszuführen

**Symptom:** `python --version` oder `python3 --version` in Git Bash öffnet den Microsoft Store statt eine Versionsnummer anzuzeigen.

**Ursache:** Windows liefert einen "Store-Stub" für `python.exe`/`python3.exe` mit, der bei fehlender echter Installation automatisch in den Store verlinkt. Der Stub bleibt auch nach einer regulären Python-Installation manchmal aktiv, wenn er in der PATH-Reihenfolge vor der echten `python.exe` steht.

**Lösung:**
1. **App-Ausführungsaliase deaktivieren:** Einstellungen → Apps → Erweiterte App-Einstellungen → App-Ausführungsaliase (oder direkt: Einstellungen → Apps → Apps und Features → App-Ausführungsaliase). Dort die Schalter für "App Installer python.exe" und "App Installer python3.exe" ausschalten.
2. Python über winget nachinstallieren, falls noch nicht geschehen:
   ```bash
   winget install --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
   ```
3. Terminal komplett neu öffnen (siehe Problem 3) und erneut prüfen.

`windows/preflight.sh` prüft Python über eine Resolver-Kette (`python3` → `python` → `py -3`) und gibt bei diesem Symptom denselben Hinweis aus.

---

## 3) Befehl nach der Installation "nicht gefunden"

**Symptom:** Ein Tool wurde gerade per `winget` installiert (z.B. Git, Node, Claude Code), aber `git --version`, `node --version` oder `claude --version` melden weiterhin "command not found" bzw. "wird nicht als Befehl erkannt".

**Ursache:** `winget` aktualisiert die PATH-Umgebungsvariable für neue Prozesse, aber ein bereits offenes Terminal-Fenster hat seine Umgebung schon geladen und bekommt die Änderung nicht automatisch mit.

**Lösung:** Das Terminal-Fenster **komplett schließen** (nicht nur den Tab) und neu öffnen. Git Bash neu starten, dann den Befehl erneut prüfen.

**Sonderfall Editor-Terminal (Cursor, VS Code):** Lief der Editor schon **vor** der Installation, reicht ein neuer Terminal-Tab im Editor NICHT — jeder neue Tab erbt weiterhin den PATH-Stand vom Editor-Start, `claude` bleibt dort "wird nicht als Befehl erkannt". Der naheliegende Selbsthilfeversuch (neuer Tab) scheitert hier zuverlässig und sieht nach einer kaputten Installation aus, ist aber derselbe PATH-Cache-Effekt. Der Editor muss komplett beendet (nicht nur das Fenster geschlossen, sondern der Prozess) und neu gestartet werden, danach zieht auch der Editor-Terminal-Tab den aktuellen PATH.

---

## 4) Benutzername mit Leerzeichen oder Umlaut

**Symptom:** `npm install`, `bootstrap.sh` oder Node-basierte Hooks brechen mit kryptischen Pfad-Fehlern ab, wenn dein Windows-Benutzerkonto einen Namen mit Leerzeichen (z.B. `Max Mustermann`) oder Umlaut (z.B. `Jörg Müller`) trägt. Der Windows-Benutzerordner heißt dann entsprechend `C:\Users\Max Mustermann` bzw. `C:\Users\Jörg Müller`.

**Ursache:** Manche Node-/npm-interne Tools und ältere Windows-Build-Tools kommen mit Leerzeichen oder Nicht-ASCII-Zeichen im Pfad nicht zuverlässig zurecht.

**Lösung (Workarounds):**
1. npm-Prefix und -Cache auf einen Pfad ohne Leerzeichen/Umlaut umlegen:
   ```bash
   npm config set prefix "C:/npm-global"
   npm config set cache "C:/npm-cache"
   ```
   Danach `C:\npm-global` zum PATH hinzufügen (Einstellungen → System → Info → Erweiterte Systemeinstellungen → Umgebungsvariablen).
2. Im Zweifel: Fehlermeldung und betroffenen Befehl an Affom melden, dieses Muster ist bekannt, aber nicht in jedem Einzelfall vorab gelöst.

---

## 5) `npm install` / `git clone` extrem langsam

**Symptom:** `windows/bootstrap.sh` hängt scheinbar minutenlang bei der Playwright-Installation oder ein `git clone` dauert deutlich länger als auf einem vergleichbaren Mac.

**Ursache:** **Microsoft Defender Antivirus** scannt neu geschriebene Dateien in Echtzeit ("Echtzeitschutz"), bevor sie verwendet werden dürfen. Bei vielen kleinen Dateien (wie `node_modules` oder einem Git-Objektverzeichnis) summiert sich das spürbar.

**Lösung (optional, braucht Admin-Rechte):** Eine Ausnahme für den Projektordner eintragen: Windows-Sicherheit → Viren- & Bedrohungsschutz → Einstellungen verwalten → Ausschlüsse hinzufügen oder entfernen → Ordner `~/ai-os-core` (und optional `~/.claude`) hinzufügen. Ohne Admin-Rechte: einfach abwarten, das Ergebnis ist am Ende identisch, nur langsamer.

---

## 6) Obsidian-Vault-Dateien fehlen oder laden extrem langsam

**Symptom:** Im Obsidian-Vault fehlen Dateien, die laut `bootstrap.sh`-Output angelegt wurden, oder Notizen laden mit spürbarer Verzögerung bzw. zeigen kurz ein Cloud-Symbol.

**Ursache:** **OneDrive Files-On-Demand.** Liegt `Documents` (und damit der Second-Brain-Vault) innerhalb eines OneDrive-synchronisierten Ordners, hält Windows manche Dateien standardmäßig nur als Platzhalter lokal vor und lädt den echten Inhalt erst bei Zugriff nach.

**Lösung:** Im Explorer den Ordner `Second-Brain` (oder gleich den ganzen `Documents`-Ordner) mit Rechtsklick öffnen → **"Immer auf diesem Gerät behalten"** wählen. Das erzwingt vollständige lokale Vorhaltung aller Dateien, keine Platzhalter mehr.

---

## 7) Dateien werden nicht geschrieben, kein Fehler sichtbar

**Symptom:** `windows/bootstrap.sh` läuft scheinbar fehlerfrei durch (grüne `[OK]`-Zeilen), aber Dateien unter `~/.claude/` oder im Vault fehlen anschließend trotzdem, ganz ohne Fehlermeldung im Terminal.

**Ursache:** **Controlled Folder Access** (Teil von Windows-Sicherheit → Viren- & Bedrohungsschutz → Ransomware-Schutz). Diese Funktion blockiert Schreibzugriffe von nicht explizit erlaubten Apps auf geschützte Ordner (dazu kann `Documents` gehören) still, ohne den schreibenden Prozess selbst mit einem Fehler abbrechen zu lassen.

**Lösung:** Windows-Sicherheit → Viren- & Bedrohungsschutz → Ransomware-Schutz → "Überwachten Ordnerzugriff verwalten" → "App durch überwachten Ordnerzugriff zulassen" → Git Bash (`bash.exe`), Node.js (`node.exe`) und Obsidian als zulässige Apps hinzufügen.

---

## 8) Firewall-Fenster beim Dashboard-Start

**Symptom:** Beim ersten `/aios-dashboard`-Aufruf öffnet sich ein Windows-Sicherheitshinweis ("Windows Defender Firewall hat einige Funktionen dieser App blockiert"), der nach Netzwerkzugriff für Node.js fragt.

**Ursache:** Der Dashboard-Server (`server.mjs`) öffnet einen lokalen HTTP-Port. Windows fragt bei jedem neuen netzwerklauschenden Prozess einmalig nach, unabhängig davon, ob der Port tatsächlich nach außen erreichbar ist.

**Lösung:** Harmlos, der Server lauscht ausschließlich auf `127.0.0.1` (nur der eigene Rechner, kein externer Zugriff). Das Fenster kann mit **"Abbrechen"** geschlossen werden, das Dashboard funktioniert trotzdem weiter. Für dauerhafte Ruhe kannst du stattdessen "Zugriff zulassen" für private Netzwerke anklicken, nötig ist es aber nicht.

---

## 9) Claude findet Dateien nicht / Suche liefert leere Ergebnisse

**Symptom:** Datei-Suchen innerhalb einer Claude-Code-Session (z.B. für Codebase-Fragen) liefern leere oder unvollständige Ergebnisse, obwohl die Dateien nachweislich existieren.

**Ursache:** Claude Code nutzt intern `ripgrep` für schnelle Textsuche. Die eingebaute Ripgrep-Variante ist unter Windows in manchen Umgebungen unzuverlässig.

**Lösung:** Eine eigenständige ripgrep-Installation nachziehen und Claude Code anweisen, diese statt der eingebauten zu nutzen:
```bash
winget install BurntSushi.ripgrep.MSVC --accept-source-agreements --accept-package-agreements
```
Danach in `~/.claude/settings.json` im `env`-Block ergänzen:
```json
"USE_BUILTIN_RIPGREP": "0"
```
Terminal bzw. Claude-Code-Session neu starten.

---

## 10) `Filename too long` bei `git`

**Symptom:** `git clone`, `git checkout` oder `git pull` bricht mit einer Fehlermeldung wie `Filename too long` oder `unable to create file ... : Filename too long` ab.

**Ursache:** Windows begrenzt Dateipfade traditionell auf 260 Zeichen (`MAX_PATH`). Manche Repo-Pfade (insbesondere verschachtelte `node_modules`) überschreiten das.

**Lösung, zwei Teile:**
1. Git selbst auf lange Pfade umstellen:
   ```bash
   git config --global core.longpaths true
   ```
2. Zusätzlich, als Administrator (PowerShell, "Als Administrator ausführen"), die Windows-eigene Beschränkung aufheben:
   ```powershell
   New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
   ```
   Danach einmal neu starten.

---

## 11) `winget` wird nicht erkannt

**Symptom:** `windows/setup.ps1` bricht direkt mit "winget wurde nicht gefunden" ab, oder `winget --version` in der PowerShell liefert "wird nicht als Befehl erkannt".

**Ursache:** `winget` (Windows Package Manager) kommt über die App **"App Installer"** aus dem Microsoft Store, die auf älteren oder frisch eingerichteten Windows-11-Installationen noch nicht aktuell genug ist. Zusätzlich braucht `winget` mindestens Windows 11, Version 22H2 (Build 22621), ältere Builds bringen es gar nicht mit.

**Lösung:**
1. Windows-Version prüfen: Einstellungen → System → Info → Windows-Spezifikationen → "Build". Mindestens 22621 nötig, sonst zuerst Windows Update durchlaufen lassen.
2. Im Microsoft Store nach **"App Installer"** suchen und auf "Aktualisieren" klicken (nicht "Installieren", die App ist meist schon vorhanden, nur veraltet).
3. PowerShell neu öffnen, `winget --version` erneut prüfen.

---

## 12) Hooks oder Statusline reagieren nicht oder hängen

**Symptom:** Die Statusline zeigt keinen Inhalt an, oder Hooks (z.B. der Secret-Scan vor einem Commit) feuern nicht bzw. lassen die Session hängen.

**Ursache:** Claude Code braucht unter Windows einen expliziten Pfad zu `bash.exe` (Git Bash), um Hook- und Statusline-Skripte auszuführen, weil es kein natives Unix-Environment gibt. Dieser Pfad steckt in `env.CLAUDE_CODE_GIT_BASH_PATH` in `~/.claude/settings.json` und wird von `windows/bootstrap.sh` beim Generieren der Datei automatisch gesetzt. Fehlt der Eintrag (z.B. weil `settings.json` manuell angelegt oder von einer alten Version übernommen wurde) oder zeigt er ins Leere, bleiben Hooks stumm.

**Lösung:**
1. In `~/.claude/settings.json` prüfen, ob im `env`-Block ein Eintrag wie
   ```json
   "CLAUDE_CODE_GIT_BASH_PATH": "C:/Program Files/Git/bin/bash.exe"
   ```
   existiert und der Pfad tatsächlich auf eine vorhandene Datei zeigt (Forward-Slashes, kein Backslash).
2. Fehlt er oder ist er falsch: `bash windows/bootstrap.sh` erneut ausführen, das regeneriert die Datei mit dem korrekten Pfad (bestehende `settings.json` bleibt dabei unangetastet, siehe README-Abschnitt "Was passiert mit meinen vorhandenen Files?" — in diesem Fall den Eintrag manuell nachtragen oder die Datei nach Rücksprache neu generieren lassen).
3. Zusätzlich prüfen, dass `powershell.exe` im PATH auffindbar ist (`which powershell.exe` in Git Bash) — manche Hooks rufen intern PowerShell für Windows-spezifische Schritte auf.

---

## 13) Eingefügte Befehle beginnen mit `^[[200~` und schlagen fehl

**Symptom:** Ein per Rechtsklick oder `Shift + Einfg` eingefügter Befehl landet in Git Bash mit sichtbaren Steuerzeichen in der Zeile und bricht ab:

```
$ ^[[200~bash windows/preflight.sh~
bash: $'\E[200~bash': command not found
```

**Ursache:** Beim Einfügen sendet das Terminal sogenannte Bracketed-Paste-Marker, die dem Programm signalisieren, wo eingefügter Text anfängt und aufhört. Wertet die Readline-Konfiguration sie nicht aus, landen sie als normaler Text in der Eingabe. Das ist ein Zeichen einer sehr alten Git-Version: aktuelles Git for Windows liefert bash 5.2/readline 8.2 mit, das die Marker sauber auswertet.

**Lösung:**
1. Git for Windows aktualisieren (`winget upgrade Git.Git`), danach ein neues Git-Bash-Fenster öffnen.
2. `windows/bootstrap.sh` setzt in `~/.inputrc` die Zeile `set enable-bracketed-paste on` (legt die Datei neu an oder ergänzt/korrigiert die Zeile in einer bestehenden Datei, mit Backup, Fremdinhalt bleibt erhalten). Damit schützt Bracketed Paste eingefügten Text als Block, keine Brace-Expansion, keine verschluckten Zeichen.
3. Für die laufende Sitzung ohne Bootstrap-Lauf: `bind 'set enable-bracketed-paste on'` eintippen (nicht einfügen).

---

## 14) winget meldet Erfolg, das Programm fehlt trotzdem

**Symptom:** `setup.ps1` läuft ohne Fehlermeldung durch, aber `preflight.sh` oder `bootstrap.sh` melden danach eine Komponente als fehlend (typischer Fall: Python).

**Ursache:** `winget install` wird mit `--silent` aufgerufen, damit keine Installer-Fenster aufpoppen. Nicht jeder Installer respektiert das. Öffnet einer trotzdem einen Dialog und niemand bedient ihn (etwa weil das PowerShell-Fenster schon zu war), bricht die Installation ab, `winget` liefert aber trotzdem Exit 0.

**Lösung:**
1. Den Install-Befehl aus der Fehlermeldung von `preflight.sh` bzw. `bootstrap.sh` manuell in PowerShell ausführen, dieses Mal **ohne** das Fenster zu schließen. Erscheint ein Wizard: durchklicken.
2. Danach ein **neues** Git-Bash-Fenster öffnen, sonst kennt die Shell den aktualisierten PATH nicht.
3. Prüfen mit `bash windows/preflight.sh`.

Aktuelle Fassungen von `setup.ps1` prüfen nach jeder Installation zusätzlich per `winget list` nach und melden diesen Fall als Warnung.

---

## 15) playwright-cli findet kein System-Chrome

**Symptom:** `playwright-cli open --browser=chrome` (oder ein Beispiel, das den Agent dazu verleitet, `--browser=chrome` zu setzen) schlägt fehl, obwohl `windows/bootstrap.sh` bereits `npx --yes playwright install chromium` gelaufen ist und ein gebündeltes Chromium bereitliegt.

**Ursache:** `--browser=chrome`/`--browser=msedge` sind Playwright-**Channel**-Namen, die den auf dem System **installierten** Chrome bzw. Edge suchen, nicht das von `playwright install chromium` heruntergeladene gebündelte Chromium. Auf einer frischen Windows-Maschine ohne separat installiertes Chrome existiert dieser Channel schlicht nicht. Das mitgelieferte `SKILL.md` von `@playwright/cli` listet `--browser=chrome` als erstes Beispiel unter "Use specific browser", was Agenten dazu verleitet, den Channel unnötig zu setzen.

**Lösung:**
1. `playwright-cli open` **ohne** `--browser`-Flag aufrufen. Ohne den Channel-Parameter startet die CLI das gebündelte Chromium aus `playwright install chromium`, genau das, was `windows/bootstrap.sh` bereits installiert hat.
2. Ist auf der Maschine ausnahmsweise kein Chromium-Download möglich (Firewall/Proxy), aber ein System-Browser vorhanden: `--browser=msedge` verwenden, Edge ist auf jedem Windows 11 vorinstalliert. `--browser=chrome` nur setzen, wenn Chrome nachweislich separat installiert ist.

Kein zusätzlicher Chrome-Download in `setup.ps1` vorgesehen: das gebündelte Chromium aus dem Bootstrap deckt den Regelfall ab, ein zweiter Browser-Download würde Setup-Zeit und Installationsgröße unnötig erhöhen.

---

## 16) AIOS-Button in der Statuszeile ist nicht klickbar

**Symptom:** Unten in der Claude-Code-Statuszeile steht der orangene Knopf `⊞ AIOS`, aber ein Klick (auch Strg+Klick) öffnet keinen Browser. In Cursor landet stattdessen nur das Zeichen in der Suchleiste.

**Ursache:** Der Knopf ist ein Terminal-Hyperlink (OSC-8-Escape-Sequenz). Beide Windows-Terminals können solche Links darstellen, aber Claude Codes eigene Terminal-Erkennung stuft sie nicht als hyperlink-fähig ein und filtert die Sequenz aus der Statuszeile heraus (die Farben bleiben, der Link verschwindet). Auf macOS greift die Erkennung korrekt, deshalb funktioniert der Knopf dort.

**Lösung:** Die Umgebungsvariable `FORCE_HYPERLINK=1` übersteuert die Erkennung. `windows/bootstrap.sh` setzt sie automatisch im `env`-Block der generierten `settings.json`. Wer eine ältere, selbst gepflegte `settings.json` hat (der Bootstrap überschreibt sie nie), trägt die Zeile einmal von Hand nach:

```json
"env": {
  "FORCE_HYPERLINK": "1"
}
```

Danach Claude Code neu starten, der Knopf öffnet per Strg+Klick den Browser. Übergangsweise geht auch `export FORCE_HYPERLINK=1` vor dem `claude`-Start. Unabhängig davon öffnet `/aios-dashboard` das Dashboard immer, inklusive frischer Daten.

---

## Noch ein Problem?

Falls keine der obigen Lösungen hilft: Terminal-Output oder Fehlermeldung an Affom schicken. Für allgemeine (nicht Windows-spezifische) Probleme: [../troubleshooting.md](../troubleshooting.md).
