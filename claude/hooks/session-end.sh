#!/bin/bash
# Session-End Hook für Claude Code
# Erinnert an STATE.md Update

# Input lesen
INPUT=$(cat)

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  SESSION BEENDET"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Empfohlen: /wrap-up ausfuehren"
echo "  → Sichert Wissen im Second Brain"
echo "  → Aktualisiert STATE.md"
echo "  → Prueft Projekt-Lifecycle"
echo ""
echo "  Alternativ: 'Aktualisiere STATE.md mit dem Stand dieser Session'"
echo "═══════════════════════════════════════════════════════════"

exit 0
