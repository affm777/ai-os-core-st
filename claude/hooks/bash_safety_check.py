#!/usr/bin/env python3
"""
Claude Code safety hook for YOLO mode with safety rails.
- CRITICAL: Always blocked (exit 2) - catastrophic/irreversible
- DELETION: Blocked with redirect instruction - move to trash staging instead
- WARNING: Blocked with approval required - risky but recoverable

Trash staging: ~/.claude/trash-staging/YYYY-MM-DD/
Human reviews and empties staging manually.

Use with: claude --dangerously-skip-permissions

Source: https://gist.github.com/NulightJens/6d7315edcc07e03ff055c3b9b3a47224
"""
import json
import sys
import re
import os
from datetime import datetime

LOG_FILE = os.path.expanduser("~/.claude/hooks/safety.log")
TRASH_STAGING = os.path.expanduser("~/.claude/trash-staging")

# CRITICAL - Always blocked, catastrophic/irreversible damage
CRITICAL_PATTERNS = [
    (r'\bdd\s+.*of=/dev/(sd|hd|nvme|disk)', "dd writing to disk device"),
    (r'\bmkfs\b', "Filesystem creation (mkfs)"),
    (r'\bfdisk\b', "Disk partitioning (fdisk)"),
    (r'\bparted\b', "Disk partitioning (parted)"),
    (r'\bshred\s+.*(/dev/|/home|~)', "Shredding disk or home"),
    (r'\bgit\s+push\s+.*--force.*\s+(origin\s+)?(main|master)\b', "Force push to main/master"),
    (r'\bgit\s+push\s+-f\s+.*\s+(origin\s+)?(main|master)\b', "Force push to main/master"),
    (r'\bdrop\s+database\b', "DROP DATABASE"),
    (r'\bkubectl\s+delete\s+.*--all\s+.*-A', "kubectl delete all cluster-wide"),
    (r'\bchmod\s+.*-R\s+777\s+/', "Recursive chmod 777 on root"),
    # Windows (Git Bash) equivalents
    (r'\bformat\s+.*[a-zA-Z]:(\\|/|\s|$)', "Windows drive format"),
    (r'\bdiskpart\b', "Windows disk partitioning (diskpart)"),
]

# DELETION - Intercepted and redirected to trash staging
# Order matters: most specific first, catch-all last
DELETION_PATTERNS = [
    (r'\bfind\b.*-delete\b', "find with -delete"),
    (r'\bfind\b.*-exec\s+rm', "find -exec rm"),
    (r'\brm\s+', "File deletion (rm)"),
    # Windows (Git Bash) equivalents, scharfe Doppel-Flag-Muster zuerst
    (r'\brd\b(?=.*\/s)(?=.*\/q)', "Windows rd /s /q (recursive quiet delete)"),
    (r'\bdel\b(?=.*\/f)(?=.*\/s)', "Windows del /f /s (forced recursive delete)"),
    (r'\bRemove-Item\b(?=.*-Recurse)(?=.*-Force)', "PowerShell Remove-Item -Recurse -Force"),
    # PowerShell-Tool (Windows): Auffangfaelle analog zu \brm\s+ oben, damit
    # nicht nur die Doppel-Flag-Kombination oben abgedeckt ist. \s+ statt
    # blossem \b reduziert Fehlalarme bei "del"/"rd" als Teil normaler Woerter
    # oder Bezeichner in Strings/Kommentaren.
    (r'\bRemove-Item\b', "PowerShell Remove-Item (jede Form)"),
    (r'\bri\s+', "PowerShell-Alias ri (Remove-Item)"),
    (r'\brmdir\s+', "Windows/PowerShell rmdir"),
    (r'\bdel\s+', "Windows del (jede Form)"),
    (r'\brd\s+', "Windows rd (jede Form)"),
]

# WARNING - Blocked, requires approval, not deletion-related
WARNING_PATTERNS = [
    (r'\bgit\s+clean\s+.*-[a-zA-Z]*f', "Git clean with force"),
    (r'\bgit\s+reset\s+--hard', "Git hard reset"),
    (r'\bgit\s+checkout\s+--\s+\.', "Git checkout discard all"),
    (r'\bdocker\s+system\s+prune', "Docker system prune"),
    (r'\bdocker-compose\s+down\s+.*-v', "Docker compose down with volumes"),
    (r'\bdrop\s+table\b', "DROP TABLE"),
    (r'\btruncate\s+table\b', "TRUNCATE TABLE"),
    (r'\btruncate\s+', "File truncation"),
    (r'^>\s*\S', "Redirect truncation"),
    (r'\breg\s+delete\b', "Windows registry key deletion (reg delete)"),
]

# Safe exceptions - skip checking entirely
SAFE_EXCEPTIONS = [
    r'\.pyc\b', r'__pycache__', r'node_modules', r'\.o\b',
    r'\.tmp\b', r'\.log\b', r'\.cache', r'/tmp/',
    r'--help', r'--dry-run', r'--no-run',
]


def log_warning(command: str, reason: str):
    """Log warning to file for audit trail."""
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            timestamp = datetime.now().isoformat()
            f.write(f"[{timestamp}] WARNING: {reason}\n")
            f.write(f"  Command: {command}\n\n")
    except Exception:
        pass


def extract_rm_targets(command: str) -> str:
    """Extract file/dir targets from an rm command for the mv suggestion."""
    cleaned = re.sub(r'\brm\s+', '', command)
    cleaned = re.sub(r'\s+-[a-zA-Z]+', '', cleaned)
    cleaned = re.sub(r'\s+--[a-zA-Z-]+', '', cleaned)
    return cleaned.strip()


def get_staging_dir() -> str:
    """Get today's trash staging subdirectory path."""
    today = datetime.now().strftime("%Y-%m-%d")
    return os.path.join(TRASH_STAGING, today)


def check_command(command: str) -> tuple[str, str]:
    """Check command safety level."""
    for pattern in SAFE_EXCEPTIONS:
        if re.search(pattern, command, re.IGNORECASE):
            return "safe", ""

    for pattern, reason in CRITICAL_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return "critical", reason

    for pattern, reason in DELETION_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return "deletion", reason

    for pattern, reason in WARNING_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return "warning", reason

    return "safe", ""


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Hook error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    if tool_name not in ("Bash", "PowerShell") or not command:
        sys.exit(0)

    level, reason = check_command(command)

    if level == "critical":
        error_msg = f"""
CRITICAL COMMAND BLOCKED
Reason: {reason}
Command: {command[:80]}
This is IRREVERSIBLE and blocked even in YOLO mode.
If you really need this, run it manually in your terminal."""
        print(error_msg, file=sys.stderr)
        sys.exit(2)

    elif level == "deletion":
        log_warning(command, reason)
        staging = get_staging_dir()
        targets = extract_rm_targets(command)
        mv_cmd = f"mkdir -p {staging} && mv {targets} {staging}/"
        redirect_msg = f"""
DELETION INTERCEPTED — move to trash staging instead.
Reason: {reason}
Original: {command[:80]}
Use this instead:
  {mv_cmd}
Files land in {staging}/ for human review and manual deletion."""
        print(redirect_msg, file=sys.stderr)
        sys.exit(2)

    elif level == "warning":
        log_warning(command, reason)
        warn_msg = f"""
RISKY COMMAND — APPROVAL REQUIRED
Reason: {reason}
Command: {command[:80]}
This command is potentially destructive but recoverable.
Review and approve if you want to proceed."""
        print(warn_msg, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
