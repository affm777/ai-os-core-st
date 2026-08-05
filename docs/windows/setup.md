# Windows-Setup — Langfassung

Diese Seite ergänzt die Kurzanleitung in der [README](../../README.md#setup-für-windows-11) um mehr Erklärtiefe: was im Hintergrund passiert, wie die einzelnen Warnungen aussehen und was du dabei anklickst. Wenn dir die Kurzfassung reicht, brauchst du diese Seite nicht.

> **Konvention:** Alle Terminal-Befehle hier laufen in **Git Bash**, nicht in PowerShell oder cmd. Einzige Ausnahme: der Oneliner in Schritt 1, der läuft in einer normalen PowerShell (kein Administrator nötig).

---

## Schritt 1: Der PowerShell-Oneliner im Detail

```powershell
irm https://raw.githubusercontent.com/affm777/ai-os-core-st/main/windows/setup.ps1 | iex
```

Die Adresse zeigt auf `windows/setup.ps1` dieses Repositories.

`irm` (Invoke-RestMethod) lädt den Inhalt dieser Adresse herunter, `iex` (Invoke-Expression) führt ihn als PowerShell-Code aus. Das funktioniert auch, wenn deine Execution Policy auf "Restricted" steht, weil dabei keine `.ps1`-Datei auf der Festplatte landet, die die Policy blockieren könnte.


### Was `setup.ps1` im Einzelnen tut

1. **Windows-Versionscheck.** Liest den Build-Wert aus `[System.Environment]::OSVersion.Version.Build` und bricht mit Fehlermeldung ab, wenn er unter 22621 liegt (Windows 11, Version 22H2). Ist das der Fall: Einstellungen → Windows Update → nach Updates suchen, danach das Skript erneut starten.
2. **winget-Check.** Prüft, ob der Windows Package Manager (`winget`) verfügbar ist. Fehlt er, bricht das Skript ab und verweist auf ein Update der App "App Installer" im Microsoft Store.
3. **Installationen über `winget`.** Installiert der Reihe nach Git, Node.js (LTS), Python und Claude Code, jeweils mit einem Already-Installed-Check davor (übersprungen, wenn schon vorhanden) und `--silent`, damit kein zusätzliches Installer-Fenster aufpoppt.
4. **Repo klonen.** Klont das Setup-Repository nach `~/ai-os-core`. Welches, steht in der Variablen `$RepoUrl` am Kopf von `setup.ps1`.
5. **Cursor-Standardterminal umstellen.** Ist Cursor installiert, ist dessen Standardterminal ab Werk PowerShell 5.1, unsere Kommandos sind aber Bash. `setup.ps1` setzt in Cursors `settings.json` den Schlüssel `terminal.integrated.defaultProfile.windows` auf `"Git Bash"`, aber nur, wenn er fehlt oder abweicht (Backup vorher, restlicher Inhalt bleibt unangetastet). Ist Cursor noch nicht installiert, kommt ein Hinweis, das nach der Cursor-Installation nachzuholen: Cursor-Einstellungen öffnen, `terminal.integrated.defaultProfile.windows` suchen, auf `Git Bash` setzen.
6. **Abschluss-Hinweis.** Zeigt dir, wie es in Git Bash weitergeht (Schritt 2 unten).

### SmartScreen-Warnungen

Bei den einzelnen `winget`-Installationen kann Windows SmartScreen einhaken, meist mit dem Satz:

> **"Windows hat Ihren PC geschützt"**
> Microsoft Defender SmartScreen hat den Start einer unbekannten App verhindert. Das Ausführen dieser App stellt möglicherweise ein Risiko für Ihren PC dar.


Das ist die Standard-Reaktion auf Installer, die noch keine ausreichende Reputation bei Microsoft aufgebaut haben, kein Zeichen für ein tatsächliches Problem bei bekannter Software wie Git oder Node.js. Klick auf **"Weitere Informationen"**, dann erscheint der Button **"Trotzdem ausführen"**. Diesen anklicken.

Manche Installer fragen zusätzlich per User Account Control (UAC) nach, ob die App Änderungen am Gerät vornehmen darf ("Möchten Sie zulassen, dass diese App Änderungen an Ihrem Gerät vornimmt?"). Mit **Ja** bestätigen.

### GitHub-Browser-Login (nur bei privatem Repository)

Ist dein Setup-Repository öffentlich, klont Git ohne jede Anmeldung, und dieser Abschnitt betrifft dich nicht.

Ist es privat, öffnet sich beim Klonen automatisch ein Browserfenster, das dich bei GitHub anmelden lässt. Das übernimmt der **Git Credential Manager** (kommt automatisch mit der Git-Installation): er speichert danach deine Zugangsdaten sicher im Windows Credential Manager, sodass du dich für weitere `git`-Befehle in diesem Repo nicht erneut anmelden musst. Melde dich dort mit dem GitHub-Account an, für den das Repository freigegeben wurde.

### Warum Git Bash und nicht PowerShell?

Ab Schritt 2 wechselt die Anleitung bewusst zu Git Bash, weil:
- `preflight.sh` und `bootstrap.sh` echte Bash-Skripte sind (`#!/usr/bin/env bash`), keine PowerShell-Skripte. Git Bash bringt die dafür nötige Unix-Umgebung (bash, coreutils, `chmod`, `mkdir -p` etc.) mit, PowerShell nicht.
- Claude Code selbst erwartet unter Windows eine Bash-kompatible Shell für seine Hooks (`noderun.sh`, `git-secret-scan.sh` etc.), siehe `env.CLAUDE_CODE_GIT_BASH_PATH` in der generierten `settings.json`.
- Damit läuft exakt derselbe Skript-Code wie auf dem Mac, nur mit anderen Fix-Kommandos (`winget` statt `brew`).

Git Bash kommt automatisch mit der Git-Installation aus Schritt 1 mit, ein separater Download ist nicht nötig.

---

## Schritt 2: Preflight-Check

```bash
cd ~/ai-os-core && bash windows/preflight.sh
```

Rein lesender Check, schreibt nichts auf die Festplatte. Für jede fehlende Voraussetzung bekommst du den exakten `winget`-Befehl ausgegeben, in der Reihenfolge, in der du sie ausführen solltest. Nach jedem einzelnen Install den Befehl erneut ausführen, bis alle Zeilen ein grünes Häkchen zeigen.

### Defender-Hinweis: die erste Installation kann dauern

Läuft im Preflight- oder Bootstrap-Schritt etwas über mehrere Minuten, ohne sichtbaren Fortschritt (z.B. bei `npm install` für Playwright oder direkt nach einer frischen `winget`-Installation): das ist in aller Regel **Microsoft Defender**, der neu geschriebene Dateien in Echtzeit scannt, bevor sie ausgeführt werden dürfen. Das ist kein Hänger, nur Geduld nötig. Details und ein optionaler Workaround (Ausnahme-Ordner) stehen in [troubleshooting.md](troubleshooting.md#5-npm-install--git-clone-extrem-langsam).

Beim `playwright install chromium`-Schritt zeigt Bootstrap direkt davor einen Hinweis: der danach erscheinende, mehrzeilige WARNING-Kasten von Playwright ("install your project's dependencies first") ist bei dieser globalen Installation ohne Projekt-`package.json` normal und kein Fehler.

---

## Schritt 3 + 4: Dry-Run und Bootstrap

```bash
bash windows/bootstrap.sh --dry-run
bash windows/bootstrap.sh
```

Funktional identisch zum Mac-Ablauf (siehe "Was macht bootstrap.sh?" in der README), mit drei Windows-spezifischen Unterschieden:
- **`settings.json` wird generiert, nicht kopiert.** Auf dem Mac wird `claude/settings.json.template` direkt kopiert. Unter Windows ersetzt `bootstrap.sh` zusätzlich Pfad-Präfixe (z.B. `python3` → den gefundenen Python-Interpreter, `$HOME` → den Windows-Pfad mit Forward-Slashes) und ergänzt `env.CLAUDE_CODE_GIT_BASH_PATH`.
- **Ein zusätzliches Overlay.** Nach dem Kopieren von `claude/` legt sich `windows/claude/hooks/noderun.sh` über die Mac-Version (ersetzt die nvm-Unix-Pfadauflösung durch Program-Files- und nvm-windows-Pfade).
- **Python-Resolver-Kette.** Statt hartem `python3` probiert das Skript der Reihe nach `python3`, `python`, `py -3` durch, weil unter Windows der Interpreter-Name je nach Installationsweg variiert.

---

## Schritt 5-7: Verifizieren, Obsidian, Claude Code

Siehe README, identisch zur Kurzfassung. Ein Detail zu Obsidian: das Fenster "Ordner als Vault öffnen" zeigt in der linken Seitenleiste oft einen OneDrive-Knoten "Dokumente" **und** darunter "Dieser PC" mit einem eigenen "Documents"-Zweig. Diese beiden Wege führen bei aktivem OneDrive zu unterschiedlichen physischen Orten. Der Vault liegt immer im lokalen Ordner unter "Dieser PC", nicht unter dem OneDrive-Knoten.

---

## Optionaler Tipp: Git Bash als Windows-Terminal-Profil

Wenn du öfter zwischen PowerShell und Git Bash wechselst, lohnt es sich, Git Bash als eigenes Profil im Windows Terminal einzurichten, statt es jedes Mal über das Startmenü zu suchen:

1. Windows Terminal öffnen
2. Über den Dropdown-Pfeil neben dem `+`-Tab auf **Einstellungen**
3. **Profil hinzufügen** → **Neues leeres Profil**
4. Als **Befehlszeile** den Pfad zur `git-bash.exe` eintragen, typischerweise:
   ```
   C:\Program Files\Git\git-bash.exe
   ```
5. Name vergeben (z.B. "Git Bash"), speichern

Danach lässt sich Git Bash über den Dropdown-Pfeil im Windows Terminal direkt öffnen, optional auch als Standardprofil setzen. Rein optional, für den täglichen Ablauf nicht nötig.

---

## Weiterführend

- Bekannte Probleme: [troubleshooting.md](troubleshooting.md)
- Manueller End-to-End-Test: [smoke-test.md](smoke-test.md)
- Mac-Gegenstück (falls zum Vergleich): [../smoke-test.md](../smoke-test.md), [../troubleshooting.md](../troubleshooting.md)
