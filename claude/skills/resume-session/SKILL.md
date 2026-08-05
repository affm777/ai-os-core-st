---
name: resume-session
description: Stellt den Arbeitskontext für das aktuelle Projekt wieder her aus STATE.md, Vault-Session-Logs, offenen Action-Items, jüngsten Decisions und der Vault-Timeline. Nutze diesen Skill IMMER zu Session-Beginn wenn der User nicht klar sagt was er machen will, oder wenn er einsteigend wirkt, auch ohne explizit "resume" zu sagen. Trigger-Beispiele wie "lass uns weitermachen", "wo waren wir", "Kontext wiederherstellen", "wir starten neu", "was war zuletzt", "moin", "wir machen heute weiter mit X", "was steht an". Auto-invoke besonders bei kalten Session-Starts ohne konkrete Aufgabe.
when_to_use: |
  Trigger-Phrasen: "lass uns weitermachen", "wo waren wir", "Kontext wiederherstellen", "wir starten neu", "session start", "was war zuletzt", "was steht an", "moin", "was machen wir heute", "/resume-session". Idealerweise zu Session-Beginn. Wenn die Session schon läuft und User nur ein Detail abfragt, NICHT triggern (Aufgaben-Frage vs. Session-Restoration unterscheiden).
allowed-tools: Read, Glob, Grep, Bash(grep:*), Bash(find:*), Bash(ls:*), Bash(head:*), Bash(tail:*), Bash(awk:*)
---

# Session-Kontext wiederherstellen

Du bist ein Kontext-Restaurator. Stelle den vollstaendigen Arbeitskontext fuer das aktuelle Projekt wieder her.

## Schritte

0. **Projekt-Tag ermitteln**
   - Lies die Projekt-CLAUDE.md und suche den `## Vault-Integration` Block
   - Extrahiere den Projekt-Tag (z.B. `project/mein-projekt`)
   - Wenn kein Tag vorhanden: Vault-Suche komplett ueberspringen, nur STATE.md nutzen

1. **STATE.md lesen** (`.planning/STATE.md` oder `STATE.md` im Projekt-Root)
   - Zeige: Aktuelle Phase, letzter Stand, naechste Schritte, offene Blocker

2. **Letzten Session Log laden** (nur wenn Projekt-Tag vorhanden)
   - Suche in `~/Documents/Second-Brain/` nach Dateien mit `type: session-log` UND dem Projekt-Tag
   - NUR den neuesten fuer DIESES Projekt nehmen — NICHT global suchen
   - Zeige die Zusammenfassung

3. **Offene Action Items finden** (nur wenn Projekt-Tag vorhanden)
   - Suche im Vault nach `- [ ]` in Dateien mit dem Projekt-Tag
   - Liste die offenen Items auf

4. **Letzte 3 Decisions laden** (nur wenn Projekt-Tag vorhanden)
   - Suche Dateien mit `type: decision` und dem Projekt-Tag
   - Zeige die juengsten 3 Decisions mit Kontext

5. **Letztes Meeting laden** (nur wenn Projekt-Tag vorhanden)
   - Suche Dateien mit `type: meeting` und dem Projekt-Tag
   - Zeige das juengste Meeting (Titel, Datum, Zusammenfassung)

5.5 **Vault-Timeline laden (cross-projekt Kontext)**
    - `00_Meta/system/vault-log.md` via **Read-Tool** lesen (nicht Bash/cat). Read ist von der globalen `Read(...Second-Brain/**)` Permission gedeckt. Bei langer Datei `offset` ans Ende setzen, sodass die letzten ~10 Zeilen erscheinen.
    - Zeige: was wurde im Vault zuletzt gemacht (Sweeps, Reindex, Lint, Compress aus anderen Projekten)
    - Das ist Cross-Session- und Cross-Projekt-Kontext, der unabhaengig vom aktuellen Projekt-Tag relevant sein kann
    - Wenn `system/vault-log.md` nicht existiert: kurz melden, weiter machen

6. **Zusammenfassung ausgeben**
   Format:
   ```
   === KONTEXT WIEDERHERGESTELLT ===
   Projekt: [Name]
   Letzte Session: [Datum] — [Zusammenfassung]
   Offene Items: [Anzahl]
   Juengste Decisions: [Liste]
   Naechster Schritt: [aus STATE.md]
   ```

7. **Fragen:** "Soll ich mit [naechster Schritt] weitermachen?"

## Fallback

- Kein Projekt-Tag in CLAUDE.md → Vault-Suche komplett ueberspringen, NUR STATE.md verwenden
- NIEMALS ungefiltert den gesamten Vault durchsuchen
- Lieber weniger Kontext als falschen Kontext aus anderen Projekten

## Wichtig

- Lies die Dateien tatsaechlich, nicht nur die Pfade ausgeben
- Bei fehlenden Dateien: kurz melden, nicht abbrechen
- Kompakt halten — der User will schnell wieder einsteigen
