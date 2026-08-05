#!/bin/bash
# Focus Alert Hook for Claude Code
# Plays a chime + desktop notification when Claude needs attention.
# Optional: Slack, Telegram, or WhatsApp integration.
#
# Supports: macOS (afplay + osascript) and Windows (PowerShell)
# Configure messaging integrations via environment variables.
#
# Source: https://gist.github.com/NulightJens/6d7315edcc07e03ff055c3b9b3a47224

# ============================================================
# CONFIGURATION — Set these environment variables
# ============================================================
# CLAUDE_ALERT_SOUND       Path to sound file (default: system Glass sound)
# CLAUDE_SLACK_WEBHOOK      Slack incoming webhook URL
# CLAUDE_TELEGRAM_TOKEN     Telegram bot token
# CLAUDE_TELEGRAM_CHAT_ID   Telegram chat ID
# CLAUDE_WHATSAPP_URL       WhatsApp Cloud API endpoint
# CLAUDE_WHATSAPP_TOKEN     WhatsApp API bearer token
# CLAUDE_WHATSAPP_TO        WhatsApp recipient phone (E.164 format)
# ============================================================

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Python-Interpreter aufloesen (Windows-Store-Stub aussortieren, siehe
# git-secret-scan.sh). Hier bewusst fail-open: der Hook ist reiner Komfort,
# ohne Interpreter greift der bestehende "unknown"-Fallback.
PYBIN=""
for _cand in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $_cand -c "import sys" </dev/null >/dev/null 2>&1; then PYBIN="$_cand"; break; fi
done
PYBIN="${PYBIN:-python3}"

# Extract notification type if available
NOTIFICATION_TYPE=$(echo "$INPUT" | $PYBIN -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('notification_type', data.get('hook_event_name', 'unknown')))
except: print('unknown')
" 2>/dev/null || echo "unknown")

# Build human-readable message
case "$NOTIFICATION_TYPE" in
    permission_prompt)  MESSAGE="Claude needs permission to continue" ;;
    idle_prompt)        MESSAGE="Claude is waiting for your input" ;;
    Stop)               MESSAGE="Claude finished working" ;;
    TaskCompleted)      MESSAGE="Claude completed a task" ;;
    *)                  MESSAGE="Claude needs your attention" ;;
esac

# ============================================================
# 1. PLAY CHIME SOUND
# ============================================================
play_sound() {
    local SOUND_FILE="${CLAUDE_ALERT_SOUND:-}"

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        if [[ -z "$SOUND_FILE" ]]; then
            SOUND_FILE="/System/Library/Sounds/Glass.aiff"
        fi
        afplay "$SOUND_FILE" &
    elif [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -s)" == *"MSYS"* ]] || command -v powershell.exe &>/dev/null; then
        # Windows (Git Bash, WSL, or native)
        if [[ -z "$SOUND_FILE" ]]; then
            SOUND_FILE="C:\\Windows\\Media\\Windows Notify.wav"
        fi
        powershell.exe -NoProfile -Command "
            Add-Type -AssemblyName PresentationCore
            \$player = New-Object System.Windows.Media.MediaPlayer
            \$player.Open('$SOUND_FILE')
            \$player.Play()
            Start-Sleep 4
        " &
    elif command -v paplay &>/dev/null; then
        # Linux (PulseAudio)
        if [[ -z "$SOUND_FILE" ]]; then
            SOUND_FILE="/usr/share/sounds/freedesktop/stereo/complete.oga"
        fi
        paplay "$SOUND_FILE" &
    elif command -v aplay &>/dev/null; then
        # Linux (ALSA fallback)
        if [[ -n "$SOUND_FILE" ]]; then
            aplay "$SOUND_FILE" &
        fi
    fi
}

# ============================================================
# 2. DESKTOP NOTIFICATION
# ============================================================
send_desktop_notification() {
    if [[ "$(uname)" == "Darwin" ]]; then
        osascript -e "display notification \"$MESSAGE\" with title \"Claude Code\" sound name \"Glass\""
    elif command -v powershell.exe &>/dev/null; then
        powershell.exe -NoProfile -Command "
            [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
            \$balloon = New-Object System.Windows.Forms.NotifyIcon
            \$balloon.Icon = [System.Drawing.SystemIcons]::Information
            \$balloon.BalloonTipTitle = 'Claude Code'
            \$balloon.BalloonTipText = '$MESSAGE'
            \$balloon.Visible = \$true
            \$balloon.ShowBalloonTip(5000)
            Start-Sleep 6
            \$balloon.Dispose()
        "
    elif command -v notify-send &>/dev/null; then
        notify-send "Claude Code" "$MESSAGE" --icon=dialog-information
    fi
}

# ============================================================
# 3. SLACK NOTIFICATION (via Incoming Webhook)
# ============================================================
send_slack() {
    local WEBHOOK="${CLAUDE_SLACK_WEBHOOK:-}"
    if [[ -z "$WEBHOOK" ]]; then return; fi

    curl -s -X POST "$WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"text\": \":robot_face: *Claude Code Alert*\n${MESSAGE}\"}" \
        >/dev/null 2>&1 &
}

# ============================================================
# 4. TELEGRAM NOTIFICATION (via Bot API)
# ============================================================
send_telegram() {
    local TOKEN="${CLAUDE_TELEGRAM_TOKEN:-}"
    local CHAT_ID="${CLAUDE_TELEGRAM_CHAT_ID:-}"
    if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then return; fi

    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${CHAT_ID}\", \"text\": \"Claude Code Alert\\n${MESSAGE}\", \"parse_mode\": \"Markdown\"}" \
        >/dev/null 2>&1 &
}

# ============================================================
# 5. WHATSAPP NOTIFICATION (via Cloud API)
# ============================================================
send_whatsapp() {
    local URL="${CLAUDE_WHATSAPP_URL:-}"
    local TOKEN="${CLAUDE_WHATSAPP_TOKEN:-}"
    local TO="${CLAUDE_WHATSAPP_TO:-}"
    if [[ -z "$URL" || -z "$TOKEN" || -z "$TO" ]]; then return; fi

    curl -s -X POST "$URL" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"messaging_product\": \"whatsapp\",
            \"to\": \"${TO}\",
            \"type\": \"text\",
            \"text\": { \"body\": \"Claude Code Alert: ${MESSAGE}\" }
        }" \
        >/dev/null 2>&1 &
}

# ============================================================
# EXECUTE ALL CONFIGURED CHANNELS
# ============================================================
play_sound
# send_desktop_notification  # disabled 2026-05-05: only sound, no popup
send_slack
send_telegram
send_whatsapp

# Wait for background processes to finish
wait 2>/dev/null

exit 0
