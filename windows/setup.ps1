# =============================================================================
# setup.ps1 - AI Operating System: Windows-Ersteinrichtung
# =============================================================================
# Wird per "irm <raw-Adresse dieses Skripts> | iex" in einer normalen PowerShell ausgefuehrt
# (funktioniert auch unter Execution Policy "Restricted", weil kein Skript-
# File auf der Platte liegt). Bewusst simpel und stabil gehalten - alle
# veraenderliche Pruef-Logik lebt in windows/preflight.sh im Repo.
#
# Ablauf: Windows-Check -> winget-Check -> Installationen -> Repo klonen ->
# Hinweis, wie es in Git Bash weitergeht.
#
# ABLEITUNG: $RepoUrl unten ist die einzige Stelle, die pro Einsatz angepasst
# werden muss. Siehe docs/ableitung.md.
# =============================================================================

$ErrorActionPreference = 'Stop'
$failedInstalls = @()

# Quelle des Setup-Repos. Bei einer Ableitung auf das jeweilige
# Teilnehmer-Repo umstellen.
$RepoUrl = 'https://github.com/affm777/ai-os-core-st.git'

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Text)
    Write-Host "[FEHLER] $Text" -ForegroundColor Red
}

# =============================================================================
# 1. Begruessung
# =============================================================================
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  AI Operating System - Windows-Einrichtung" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dieses Skript bereitet deinen Rechner fuer das AI Operating System vor:"
Write-Host "  - prueft deine Windows-Version"
Write-Host "  - installiert Git, Node.js, Python und Claude Code (per winget)"
Write-Host "  - klont das Setup-Repository"
Write-Host ""
Write-Host "Es aendert nur diese Komponenten, sonst nichts an deinem System."
Write-Host ""

# =============================================================================
# 2. Windows-11-Check (Build >= 22621 / 22H2)
# =============================================================================
Write-Step "Windows-Version pruefen"
$build = [System.Environment]::OSVersion.Version.Build
if ($build -lt 22621) {
    Write-Err "Windows-Build $build gefunden - mindestens 22621 (Windows 11, Version 22H2) noetig."
    Write-Host "Bitte zuerst Windows Update ausfuehren (Einstellungen > Windows Update > Nach Updates suchen)."
    Write-Host "Danach dieses Skript erneut starten."
    exit 1
}
Write-Ok "Windows-Build $build - passt."

# =============================================================================
# 3. winget-Check
# =============================================================================
Write-Step "winget pruefen"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Err "winget wurde nicht gefunden."
    Write-Host "Bitte im Microsoft Store nach 'App Installer' suchen und aktualisieren, dann neu starten."
    exit 1
}
Write-Ok "winget gefunden."

# =============================================================================
# 4. Installationen via winget
# =============================================================================
Write-Step "Benoetigte Programme installieren"

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [scriptblock]$AlreadyInstalledCheck
    )

    if (& $AlreadyInstalledCheck) {
        Write-Ok "$Name ist bereits installiert - ueberspringe."
        return
    }

    Write-Host "Installiere $Name ($Id) ..."
    try {
        winget install --id $Id --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -ne 0) {
            throw "winget-Exitcode $LASTEXITCODE"
        }
        # Nachweis statt Vertrauen: --silent wird nicht von jedem Installer
        # respektiert. Oeffnet einer trotzdem einen Dialog und niemand bedient
        # ihn, liefert winget dennoch Exit 0 und das Paket fehlt. Genau so ging
        # im Test die Python-Installation still verloren.
        winget list --id $Id --exact --accept-source-agreements | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "$Name meldet Erfolg, ist aber nicht auffindbar - bitte manuell pruefen."
            $script:failedInstalls += $Name
            return
        }
        Write-Ok "$Name installiert."
    }
    catch {
        Write-Warn "$Name konnte nicht automatisch installiert werden ($_)."
        $script:failedInstalls += $Name
    }
}

Install-WingetPackage -Id "Git.Git" -Name "Git" -AlreadyInstalledCheck {
    [bool](Get-Command git -ErrorAction SilentlyContinue)
}

Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js" -AlreadyInstalledCheck {
    [bool](Get-Command node -ErrorAction SilentlyContinue)
}

Install-WingetPackage -Id "Python.Python.3.12" -Name "Python" -AlreadyInstalledCheck {
    # Der Store-Stub unter WindowsApps heisst python.exe, ist aber kein
    # Interpreter. Ein reines Get-Command haette ihn als "bereits installiert"
    # gewertet und die echte Installation uebersprungen.
    $py = Get-Command python -ErrorAction SilentlyContinue
    ($py -and $py.Source -notmatch 'WindowsApps') -or [bool](Get-Command py -ErrorAction SilentlyContinue)
}

Install-WingetPackage -Id "Anthropic.ClaudeCode" -Name "Claude Code" -AlreadyInstalledCheck {
    [bool](Get-Command claude -ErrorAction SilentlyContinue)
}

# =============================================================================
# 5. Microsoft-Store-Python-Aliase pruefen
# =============================================================================
Write-Step "Python-Store-Alias pruefen"
$storeStub = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\python.exe"
if (Test-Path $storeStub) {
    Write-Warn "Microsoft-Store-Python-Stub gefunden: $storeStub"
    Write-Host "Das kann echte Python-Installationen blockieren. Falls 'python' spaeter nicht funktioniert:"
    Write-Host "  Einstellungen > Apps > Erweiterte App-Einstellungen > App-Ausfuehrungsaliase"
    Write-Host "  Dort 'python.exe' und 'python3.exe' AUS schalten."
}
else {
    Write-Ok "Kein Store-Stub gefunden."
}

# =============================================================================
# 6. git config core.longpaths
# =============================================================================
Write-Step "Git fuer lange Pfade konfigurieren"
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    $fallbackGit = "C:\Program Files\Git\cmd\git.exe"
    if (Test-Path $fallbackGit) {
        $gitCmd = $fallbackGit
    }
}
if ($gitCmd) {
    & $gitCmd config --global core.longpaths true
    Write-Ok "core.longpaths=true gesetzt."
}
else {
    Write-Warn "Git wurde gerade erst installiert, ist in dieser Sitzung aber noch nicht im PATH."
    Write-Host "core.longpaths wird beim naechsten Start automatisch nachgeholt (siehe Git-Bash-Schritt unten)."
}

# =============================================================================
# 7. Repo klonen
# =============================================================================
Write-Step "Repository klonen"
$repoPath = Join-Path $env:USERPROFILE "ai-os-core"
if (Test-Path $repoPath) {
    Write-Ok "Ordner $repoPath existiert bereits - ueberspringe Klonen."
}
else {
    Write-Host "Ist das Repository privat, oeffnet sich gleich ein Browser-Fenster fuer den"
    Write-Host "GitHub-Login. Dort einfach anmelden. Bei einem oeffentlichen Repository"
    Write-Host "laeuft der Klon ohne Anmeldung durch."
    Write-Host ""
    $gitExe = if ($gitCmd) { $gitCmd } else { "git" }
    try {
        & $gitExe clone $RepoUrl $repoPath
        if ($LASTEXITCODE -ne 0) {
            throw "git clone Exitcode $LASTEXITCODE"
        }
        Write-Ok "Repository geklont nach $repoPath."
    }
    catch {
        Write-Warn "Klonen ist fehlgeschlagen ($_)."
        $script:failedInstalls += "Repository-Klon (manuell: git clone $RepoUrl $repoPath)"
    }
}

# =============================================================================
# 8. Cursor-Standardterminal auf Git Bash umstellen
# =============================================================================
# Cursors mitgelieferter Standard ist PowerShell 5.1, unsere Kommandos sind
# Bash. Idempotent: nur setzen, wenn der Schluessel fehlt oder abweicht.
# Fremde Einstellungen in der Datei bleiben unangetastet, vorher ein Backup.
Write-Step "Cursor-Standardterminal pruefen"
$cursorUserDir = Join-Path $env:APPDATA "Cursor\User"
if (Test-Path $cursorUserDir) {
    $cursorSettingsPath = Join-Path $cursorUserDir "settings.json"
    $desiredProfile = "Git Bash"
    $settingsKey = "terminal.integrated.defaultProfile.windows"

    if (Test-Path $cursorSettingsPath) {
        $rawContent = Get-Content -Path $cursorSettingsPath -Raw
    }
    else {
        $rawContent = "{}"
    }

    try {
        if ([string]::IsNullOrWhiteSpace($rawContent)) {
            $rawContent = "{}"
        }
        $settingsObj = $rawContent | ConvertFrom-Json -ErrorAction Stop

        $currentValue = $null
        if ($settingsObj.PSObject.Properties.Name -contains $settingsKey) {
            $currentValue = $settingsObj.$settingsKey
        }

        if ($currentValue -eq $desiredProfile) {
            Write-Ok "Cursor-Standardterminal ist bereits '$desiredProfile'."
        }
        else {
            if (Test-Path $cursorSettingsPath) {
                Copy-Item -Path $cursorSettingsPath -Destination "$cursorSettingsPath.bak" -Force
            }

            if ($settingsObj.PSObject.Properties.Name -contains $settingsKey) {
                $settingsObj.$settingsKey = $desiredProfile
            }
            else {
                $settingsObj | Add-Member -MemberType NoteProperty -Name $settingsKey -Value $desiredProfile
            }

            ($settingsObj | ConvertTo-Json -Depth 10) | Set-Content -Path $cursorSettingsPath -Encoding UTF8
            Write-Ok "Cursor-Standardterminal auf '$desiredProfile' gesetzt (Backup: settings.json.bak)."
        }
    }
    catch {
        Write-Warn "Cursor-settings.json konnte nicht gelesen werden (kaputtes JSON?) - Datei wurde NICHT angefasst."
        Write-Host "Manuell nachtragen: Cursor-Einstellungen -> '$settingsKey' -> '$desiredProfile'."
    }
}
else {
    Write-Warn "Cursor ist noch nicht installiert - Terminal-Umstellung wird uebersprungen."
    Write-Host "Nach der ersten Cursor-Installation manuell nachholen (siehe docs/windows/setup.md)."
}

# =============================================================================
# 9. Fehlgeschlagene Installationen sammeln
# =============================================================================
if ($failedInstalls.Count -gt 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "  Manuell nachinstallieren (Firmen-Proxy o.ae.):" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Yellow
    foreach ($item in $failedInstalls) {
        Write-Host "  - $item"
    }
    Write-Host ""
    Write-Host "Download-Links:"
    Write-Host "  Git:         https://git-scm.com/download/win"
    Write-Host "  Node.js:     https://nodejs.org"
    Write-Host "  Python:      https://python.org"
    Write-Host "  Claude Code: https://claude.ai/download"
    Write-Host ""
}

# =============================================================================
# 10. Abschluss
# =============================================================================
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Fast geschafft - naechster Schritt:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Dieses Fenster schliessen."
Write-Host "2. Git Bash oeffnen (Startmenue: 'Git Bash')."
Write-Host "3. Dort ausfuehren:"
Write-Host ""
Write-Host "     cd ~/ai-os-core && bash windows/preflight.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "Zum Einfuegen im Terminal Rechtsklick nutzen, nicht Strg+V."
Write-Host "Warum ein neues Fenster? PATH-Aenderungen durch die Installationen"
Write-Host "wirken erst in neu geoeffneten Fenstern. Und ab jetzt laeuft alles"
Write-Host "in Git Bash weiter, nicht mehr in PowerShell."
Write-Host ""
