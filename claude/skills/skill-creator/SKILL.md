---
name: skill-creator
description: Baut aus einem wiederkehrenden Workflow einen sauberen, token-effizienten Claude Code Skill — interaktiver Wizard fuer Cold-Start, schnelle Inferenz fuer Warm-Start, Migration von Slash-Command → Skill. Nutze diesen Skill IMMER wenn der User wiederkehrende Arbeit beschreibt oder sagt "ich mache X taeglich", "ich kopier immer denselben Prompt", "Claude soll sich merken", "automatisier das", "bau mir einen Skill", "mach daraus einen Skill", "command zu skill migrieren" — selbst wenn er nicht explizit das Wort "Skill" sagt. Auch bei "wie kann ich das wiederholbar machen", "ich mache das jeden Montag", "kannst du dir das merken" auto-invoken.
when_to_use: |
  Trigger-Phrasen (Deutsch): "automatisier das", "mach daraus einen Skill", "ich mache das taeglich", "Claude soll sich merken", "wiederkehrend", "bau mir einen Skill", "skill anlegen", "skill erstellen", "command zu skill migrieren", "ich kopier immer denselben Prompt", "wie mach ich das wiederholbar". Englisch: "build me a skill", "automate this", "turn into a skill", "make this repeatable", "remember this workflow". Auto-invoke auch bei impliziten Triggern: User beschreibt Routine ("jeden Montag pruefe ich..."), kopiert Prompts mehrfach, fragt "kannst du dir das merken".
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(mkdir:*), Bash(ls:*), Bash(rm:*), Bash(cp:*)
---

# Skill Creator

Du baust aus einem wiederkehrenden Workflow einen sauberen, token-effizienten Claude Code Skill. Adaptiv: wenn der User schon viel Kontext geliefert hat, springst du direkt zur Verifikation. Wenn er nur "bau mir einen Skill" sagt, fuehrst du ihn durch einen kompakten Wizard.

## Wie ein Skill geladen wird (Progressive Disclosure)

Skills haben drei Lade-Stufen — wichtig fuer Body-Laenge:

| Stufe | Was wird geladen | Wann |
|---|---|---|
| **Metadata** | `name` + `description` (~50 tokens) | Immer im Kontext, bei jedem User-Prompt |
| **Body** | Komplette `SKILL.md` (~500-2000 tokens) | Erst wenn der Skill auto-invoked oder via Slash gerufen wird |
| **Bundled Files** | `references/*.md`, `examples/*.md`, `scripts/*` | Nur wenn der Skill-Body sie aktiv liest |

**Folge fuer Skill-Design:** Body kompakt halten, Details die nur in Spezialfaellen gebraucht werden in `references/` lazy-load. Description darf "pushy" sein (zaehlt nur 50 tokens, wirkt als Trigger-Anker), Body soll Schritte und Logik enthalten, Referenzen sind on-demand.

## Modus-Erkennung (immer als erstes)

Schaue dir die letzte User-Nachricht plus Konversations-Kontext an und entscheide:

- **Cold Start** — User sagt nur eine Trigger-Phrase ohne Details ("Ich will einen Skill bauen", "automatisier das"). Du weisst nichts ueber den Workflow. → **Wizard-Modus** unten.
- **Warm Start** — User hat schon konkrete Details geliefert ("Bau einen Skill der Pitch-Decks aus ~/Inbound liest und in deal-pipeline schreibt"). → **Inferenz + Sammel-Verifikation** unten.
- **Autonomous** — User sagt explizit "skip wizard", "bau einfach", "vertrau mir, leg an", "no questions". → **Autonomous-Modus** unten.

Sage dem User in 1 Satz welchen Modus du gewaehlt hast und warum, bevor du startest.

## Wizard-Modus (Cold Start)

Nutze AskUserQuestion fuer strukturierte Fragen. **Eine Frage pro Aufruf**, jede mit 3-4 Multiple-Choice-Optionen plus "Bin mir nicht sicher". Wenn der User "Bin mir nicht sicher" waehlt, leite aus Kontext ab oder frage konkret nach im Free-Text.

### Frage 1 — Aufgabe

```
question: "Was machst du wiederkehrend? Welche Aufgabe willst du automatisieren?"
options:
  - "Daten aus Dateien rausziehen (PDFs, Mails, Webseiten)"
  - "Notizen oder Memos in mein Vault schreiben"
  - "Etwas pruefen oder bewerten (Pitch-Decks, Bewerbungen, Deals)"
  - "Bin mir nicht sicher — lass mich frei beschreiben"
```

Falls "frei beschreiben": stell eine offene Folge-Frage ohne AskUserQuestion ("Erzaehl mir in 1-2 Saetzen was du machst") und mappe selbst auf eine Kategorie.

### Frage 2 — Trigger

```
question: "Wann soll der Skill anspringen?"
options:
  - "Ich tippe einen Slash-Command (z.B. /screen-deal)"
  - "Ich sage in Worten was ich brauche, KI erkennt selbst"
  - "Beides — manchmal so, manchmal so"
  - "Bin mir nicht sicher"
```

Mapping:
- Slash-only → `disable-model-invocation: true` setzen
- KI erkennt → ausfuehrliche `description` + `when_to_use`
- Beides → Default (keine `disable-model-invocation`-Flag)
- Unsicher → Default

### Frage 3 — Input

```
question: "Was liest der Skill als Input?"
options:
  - "Eine Datei aus einem Ordner (z.B. neuestes PDF)"
  - "Inhalt einer URL oder Webseite"
  - "Text den ich tippe oder diktiere"
  - "Nichts — Skill hat alle Infos schon"
  - "Bin mir nicht sicher"
```

### Frage 4 — Output

```
question: "Was produziert der Skill?"
options:
  - "Eine neue Datei (z.B. Memo im Vault)"
  - "Eine bestehende Datei aktualisieren"
  - "Eine Antwort hier im Chat (kein File)"
  - "Bin mir nicht sicher"
```

### Frage 5 — Web-Research

```
question: "Soll der Skill im Web recherchieren?"
options:
  - "Ja — Web-Search mit Quellen (Perplexity oder Tavily)"
  - "Ja — nur eine bekannte URL aufrufen"
  - "Nein"
  - "Bin mir nicht sicher"
```

### Tools-Mapping (Skill macht das selbst)

User soll YAML nicht lernen. Mappe Antworten:

| Antwort | `allowed-tools` |
|---|---|
| Datei lesen | `Read, Glob` |
| Datei schreiben (neu) | `Write` |
| Datei aktualisieren | `Edit` |
| URL aufrufen | `WebFetch` |
| Web-Search mit Quellen | `mcp__perplexity-ask__*` falls verfuegbar, sonst `mcp__tavily*`, sonst `WebSearch` |
| Ordner anlegen | `Bash(mkdir:*)` |
| Datei loeschen | `Bash(rm:*)` |

## Warm-Start-Modus

User hat schon Details geliefert. Inferiere alles aus dem Kontext:

```
Skill-Name:       <vorschlag-slug>
Pfad:             ~/.claude/skills/<name>/SKILL.md
Trigger:          <auto-invoke / nur slash / beides>
Trigger-Phrasen:  "<phrase 1>", "<phrase 2>", "<phrase 3>"
Input:            <was der Skill liest>
Output:           <was der Skill schreibt>
Tools:            <liste>
Was er tut:       <1-Satz-Klartext>
```

Zeige diese Skizze, dann **eine** AskUserQuestion:

```
question: "Stimmt diese Skizze fuer deinen Skill?"
options:
  - "Ja, los — bau das so"
  - "Nein, lass mich korrigieren"
  - "Ich will lieber durch den Wizard gefuehrt werden"
```

Bei "korrigieren": offene Frage was geaendert werden soll.
Bei "Wizard": springe zu Wizard-Modus.

## Autonomous-Modus

Inferiere alles, zeige NUR finale Skizze + Pfad als einzige AskUserQuestion:

```
question: "Ich lege folgenden Skill an:\n  Name: <name>\n  Pfad: ~/.claude/skills/<name>/SKILL.md\n  Was er tut: <1-Satz>\nOK?"
options:
  - "Ja, anlegen"
  - "Nein, doch lieber Wizard"
```

## Vor Write — IMMER (alle drei Modi)

Letzte Confirmation-Gate vor `Write`. Zeige:

```
Skill-Name:       <name>
Pfad:             ~/.claude/skills/<name>/SKILL.md
Trigger-Phrasen:  <liste>
Tools:            <liste>
Body-Outline:     <Schritt 1, 2, 3 ...>
```

AskUserQuestion: "Anlegen?"
- "Ja, anlegen"
- "Nein, abbrechen"

## Communication-Style-Calibration (vor jeder User-Frage)

Bevor du AskUserQuestion oder offene Folge-Fragen stellst, kalibriere kurz das Sprachniveau des Users:

- **Tech-Vokabular** (User sagt "MCP", "YAML-Frontmatter", "tool-call") → du kannst direkt mit Begriffen arbeiten.
- **Non-Tech-Vokabular** (User beschreibt Workflow in Klartext, fragt nach Prompts statt nach Tools) → benutze nur Klartext, erklaere Begriffe in einem halben Satz wenn unvermeidbar ("YAML-Frontmatter ist ein kleiner Konfig-Block oben in der Datei"), zeige nie YAML-Beispiele die der User selbst tippen soll.

Diese Kalibrierung passt nur die Frage-Sprache an, nicht den finalen Skill-Body. Der Skill-Body folgt unten den Schreibregeln.

## Skill schreiben

Wenn YAML-Felder unklar sind, lies `references/frontmatter-cheatsheet.md`. Wenn die Primitiv-Wahl unklar ist (Skill / Subagent), lies `references/decision-tree.md`.

Schritte:

1. `mkdir -p ~/.claude/skills/<name>`
2. `Write ~/.claude/skills/<name>/SKILL.md` mit folgender Struktur:

```markdown
---
name: <name>
description: <was-er-tut>. Triggert wenn <trigger-phrase-1>, <trigger-phrase-2>, oder wenn jemand "<woertliche phrase>" sagt.
when_to_use: |
  Trigger-Phrasen: "<phrase 1>", "<phrase 2>", ...
allowed-tools: <liste>
---

# <Skill-Name>

<1-2 Zeilen: was produziert der Skill>

## Workflow

1. **<Schritt-Name>**: <Was passiert>
2. **<Schritt-Name>**: ...

## <Optional: Output-Format>

<Beispiel kompakt>
```

**Schreibregeln (mit Begruendung):**

- **< 200 Zeilen Total** — laengere Bodies werden bei jedem Skill-Trigger geladen und kosten Tokens. Was selten gebraucht wird, gehoert in `references/`.
- **Schritte nummeriert + aktiv formuliert** — der Skill-Body ist eine Anleitung an Claude, kein Lehrbuch. Aktive Verben ("Lies X", "Schreibe Y") triggern Tool-Use besser als passive Beschreibungen.
- **Lange Beispiele in `examples/<name>.md`, nicht inline** — Beispiele sind erst beim konkreten Gebrauch noetig, das ist klassischer Lazy-Load-Fall.
- **Inline-Tabellen nur fuer Quick-Reference (max 10 Zeilen)** — laengere Tabellen sprengen die 200-Zeilen-Grenze und schlagen den Skill-Body voll, ohne dass jeder Trigger die Tabelle braucht.

**Description-Heuristik ("pushy" schreiben):** Schreib in `description` nicht nur was der Skill tut, sondern auch *wann* er invoken soll, inklusive impliziter Trigger. Beispiel:

```
description: <Was-er-tut>. Nutze diesen Skill IMMER wenn <Trigger-Bedingung>, selbst wenn der User nicht explizit X sagt. Auch bei <impliziter-Trigger-1>, <impliziter-Trigger-2> auto-invoken.
```

**Begruendung:** Skill-Auto-Invoke ist ein Recall-Problem. Eine knappe Description triggert nur bei woertlichem Match. Eine pushy Description erweitert das Trigger-Set, ohne den Body zu vergroessern (Description bleibt unter 100 tokens).

**"Why" statt rigide MUSTs:** Wenn du im Skill-Body "ALWAYS X" oder "NEVER Y" in Caps schreibst, ist das ein Yellow-Flag — frag dich kurz, ob du den Grund nennen kannst. Mit Grund kann der Skill-User adaptiv reagieren wenn die Regel im Edge-Case nicht passt. Ohne Grund wird die Regel entweder blind befolgt oder ignoriert.

## Bericht nach Erstellung

Gib am Ende aus:

```
Skill angelegt: ~/.claude/skills/<name>/SKILL.md

Trigger-Phrasen die ihn auto-invoken:
  - "<phrase 1>"
  - "<phrase 2>"

Test jetzt:
  - Slash:    /<name>
  - Auto:     "<konkrete Test-Phrase>" (sollte den Skill auto-invoken)

Hinweis: Falls Auto-Invoke nicht triggert, Claude Code restart noetig — brand-neue Skill-Verzeichnisse brauchen Reload.
```

## Light-Test-Loop (optional — nach Erstellung anbieten)

Nach erfolgreicher Erstellung **eine** AskUserQuestion:

```
question: "Willst du den Skill kurz testen? Wir spielen 2-3 realistische Prompts durch, du sagst was nicht passt, ich verbessere."
options:
  - "Ja, kurzer Test-Lauf"
  - "Nein, ich teste selbst spaeter"
```

Bei "Ja":

1. Schlage 2-3 konkrete Test-Prompts vor (basierend auf den Trigger-Phrasen + Input/Output aus dem Wizard).
2. Pro Prompt: User tippt ihn. Du beobachtest Skill-Verhalten. User sagt qualitativ was passt / nicht passt.
3. Eine Iteration: aus dem Feedback Skill-Body anpassen (Edit-Tool).
4. Stop nach max 1 Iteration — wenn nach 1 Iteration noch Probleme: "Skill ist gut genug fuer den Anfang, du verbesserst ihn organisch beim naechsten echten Gebrauch."

**Begruendung:** Skill-Quality ist iterativ, perfekter erster Wurf ist unrealistisch. Aber 1 Iteration faengt die offensichtlichen Trigger-Lecks und Tool-Mapping-Fehler ab. Mehr als 1 Iteration ohne echten Gebrauch ist Over-Engineering.

**Kein** Subagent-Eval-Loop, **kein** benchmark.json, **kein** HTML-Viewer. Das ist Skill-Quality-Lab-Niveau und Overkill für den Alltagsgebrauch.

## Migrations-Modus (Spezialfall)

User sagt "migriere mir den `<name>`-Command zum Skill" oder "mach aus dem Command einen Skill".

Workflow:

1. `Read ~/.claude/commands/<name>.md`
2. Inferiere die Skizze (description erweitert mit Trigger-Phrasen, Body 1:1, Tools-Allowlist aus Body-Inhalt ableiten)
3. Zeige Skizze, AskUserQuestion: "Migration so durchfuehren?" (Ja / Korrigieren / Abbrechen)
4. Bei Ja: `mkdir -p ~/.claude/skills/<name>` + `Write SKILL.md`
5. AskUserQuestion: "Skill testen — funktioniert Slash-Aufruf?" mit Optionen "Ja, alten Command löschen" / "Nein, Skill behalten + alten auch behalten" / "Skill löschen, Migration zurück"
6. Bei "alten löschen": `rm ~/.claude/commands/<name>.md`

## Anti-Patterns (mit Begruendung)

- **Skill ohne Trigger-Phrasen** — wird nie auto-invoked, der User muss den Slash-Command kennen, das macht den Skill unsichtbar.
- **SKILL.md > 500 Zeilen** — token-teuer (laedt bei jedem Trigger), schwer wartbar, schwer zu lesen. Verschiebe Detail-Material in `references/`.
- **Lange Beispiele inline statt in `examples/`** — Beispiele sind klassischer Lazy-Load-Fall (siehe Progressive-Disclosure oben).
- **Sprache mischen** — User arbeitet in Deutsch, Trigger-Phrasen aber Englisch → Auto-Invoke greift seltener weil User-Phrasen nicht matchen.
- **Hardcoded Listen die woanders schon Single-Source-of-Truth sind** — Drift-Risiko, wenn die Quelle aktualisiert wird vergisst man die Kopie.
- **Vergessen den User vor `Write` zu fragen** — Skill-Anlegen ist ein nicht-trivialer Side-Effect, ohne Confirmation-Gate ueberraschst du den User.
- **Im Wizard-Modus mehr als 5 Fragen** — der User verliert Geduld, kuerzer ist besser. Wenn du nach 5 Fragen noch unsicher bist, frag offen statt Multiple-Choice.
- **Caps-Imperative ("ALWAYS X", "NEVER Y") ohne Grund** — wirkt rigide und verhindert dass der Skill in Edge-Cases adaptiv reagiert. Schreib statt "ALWAYS X" lieber "Tu X, weil sonst Y passiert".

## Weiterfuehrend

- YAML-Frontmatter-Cheatsheet: [references/frontmatter-cheatsheet.md](references/frontmatter-cheatsheet.md)
- Wann Skill, wann Subagent: [references/decision-tree.md](references/decision-tree.md)
- Best-in-class Beispiel-Skill: [examples/good-skill-example.md](examples/good-skill-example.md)
