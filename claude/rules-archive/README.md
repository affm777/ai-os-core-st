# rules-archive: On-Demand-Wissen

Dieser Ordner ist bewusst AUSSERHALB von `rules/`, damit Claude Code ihn NICHT bei jedem Session-Start automatisch lädt. Alles in `rules/` kostet bei jeder Session Kontext-Tokens; alles hier kostet nur dann etwas, wenn es gebraucht wird.

**Nutzung:** Lege hier Markdown-Dateien mit Wissen ab, das nur situativ relevant ist (z.B. Patterns für einen bestimmten Tech-Stack, Checklisten für seltene Aufgaben). Verweise in deiner `~/.claude/CLAUDE.md` im Abschnitt "Archiv" mit einer Zeile darauf, WANN die Datei geladen werden soll. Claude lädt sie dann per Read, sobald das Thema auftaucht.

**Faustregel:** Brauchst du eine Regel in fast jeder Session → `rules/`. Brauchst du sie nur bei bestimmten Aufgaben → hier ins Archiv.
