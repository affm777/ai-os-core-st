---
name: new-project
description: Setzt ein neues Projekt, eine Area oder ein laufendes Thema schlank auf — CLAUDE.md, .planning/STATE.md, Vault-Notiz und project-repos.yaml-Eintrag in einem Rutsch. Nutze diesen Skill IMMER wenn der User ein neues Vorhaben startet, eine neue Area anlegt oder ein laufendes Thema strukturieren will — auch ohne das Wort "Projekt", z.B. bei "ich starte was Neues", "ich hab da was Neues vor", "leg das mal an", "lass uns das aufsetzen", "ich brauch eine Struktur dafuer", "wo soll ich das ablegen". Auto-invoke besonders wenn der User in einem Ordner arbeitet der noch keine CLAUDE.md hat und ueber laengere Arbeit am Thema spricht.
when_to_use: |
  Trigger-Phrasen: "neues Projekt aufsetzen", "neue Area", "neues Thema starten", "leg ein Projekt an", "ich starte was Neues", "ich brauch Struktur für X", "lass uns das aufsetzen", "Projekt-Skeleton bauen", "/new-project". Annahme: User ist im richtigen Projekt-Ordner (CWD = Projekt-Stamm).
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Bash(mkdir:*), Bash(grep:*), Bash(ls:*), Bash(date:*), Bash(pwd:*)
---

# Neues Projekt schlank aufsetzen

Minimum Viable Setup: **CLAUDE.md (Root), `.planning/STATE.md`, Vault-Notiz, project-repos.yaml-Eintrag**. Kein PROJECT.md, kein Roadmap, kein config.json. Funktioniert fuer Projekte mit Enddatum, Areas ohne Enddatum, Client-Arbeit und laufende Themen.

**Annahme:** Wer diesen Skill ausfuehrt, ist im richtigen Projekt-Ordner (CWD = Projekt-Stamm). Wer kein Projekt-Verzeichnis will, nutzt den Skill nicht und legt Notizen direkt im Vault an.

## Flow

```
Banner → Phase 0 (Existing-Files-Check) → Phase 0.5 (Kontext optional)
  → Phase 0.7 (Pfad-Wahl) → Phase 1 (pfadspezifische Luecken)
  → Phase 2 (Write) → Phase 3 (Report)
```

### Banner

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 NEW PROJECT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Ich setze die Grundstruktur fuer dein neues Projekt auf:
- Eine Anleitung fuer Claude (CLAUDE.md): wie es bei diesem
  Projekt arbeiten soll
- Einen Fortschritts-Tracker (.planning/STATE.md): wo du
  gerade was tust
- Eine Projekt-Notiz im Vault: das langfristige Gedaechtnis
  dieses Projekts
- Einen Eintrag in der Projekt-Liste, damit Action Items
  aus Meetings hier landen

Projekt-Ordner: [CWD]
```

### Phase 0: Existing-Files-Check

Pruefen ob `CLAUDE.md` oder `.planning/STATE.md` im CWD existieren. Wenn ja:

```
AskUserQuestion:
  header: "Already initialized"
  question: "In diesem Verzeichnis existiert bereits [CLAUDE.md | STATE.md | beides]. Wie weiter?"
  options:
    - label: "Abbrechen"
      description: "Nichts ändern. User kann /resume-session oder /wrap-up nutzen."
    - label: "Neu ueberschreiben"
      description: "Bestehende Dateien durch frisches Setup ersetzen. Explizite Confirm-Zeile vorher."
    - label: "Nur fehlende Teile"
      description: "Existierende Dateien belassen, nur fehlende Artefakte anlegen."
```

Bei "Neu ueberschreiben": vor Phase 2 noch einmal klartext confirmen mit Liste der betroffenen Dateien.

### Phase 0.5: Kontext-Slot (optional)

```
AskUserQuestion:
  header: "Kontext"
  question: "Willst du erst Kontext teilen (Unterlagen, Briefings, Notizen), oder direkt zu den Fragen?"
  options:
    - label: "Kontext zuerst teilen (Recommended)"
      description: "Texte, Briefings, Links reinkippen. Ich extrahiere Felder automatisch und frage nur nach Luecken."
    - label: "Direkt zu den Fragen"
      description: "6 gezielte Fragen, kein Freeform-Slot."
```

**Wenn "Kontext zuerst teilen":**

> "Wirf rein was du hast, Text, Briefing, Links, Notizen, Ausschnitte. Schreib 'weiter' oder 'fertig' wenn du durch bist."

Aus dem Input diese Felder extrahieren (wenn ableitbar):
- Name → Slug
- Kurzbeschreibung (1-2 Saetze)
- Typ (Venture / Client / Internal / Area)
- Sprache
- Typ-Detail (Angebot / Dienstleistung / Ziel / Thema)

In Phase 1 nur die fehlenden Felder erfragen.

### Phase 0.7: Pfad-Wahl

Genau eine AskUserQuestion VOR allen anderen Lücken-Fragen. Die Antwort steuert allein die Second-Brain-Ablage (`02_Projects` vs `03_Areas`) und wie viele Lücken-Fragen folgen.

```
AskUserQuestion:
  header: "Vorhaben"
  question: "Was legen wir an?"
  options:
    - label: "Projekt mit Ziel und Enddatum"
      description: "Venture, Client-Auftrag oder internes Projekt. Landet unter
                    02_Projects im Second Brain (Projekte mit Enddatum)."
    - label: "Laufende Area / laufendes Thema"
      description: "Recherche, Community, Ongoing Ops, kein Enddatum. Landet
                    unter 03_Areas (laufende Verantwortungen)."
```

Routing:
- "Projekt mit Ziel und Enddatum" → **PATH_A**
- "Laufende Area..."              → **PATH_B** (Typ ist hart `Area`)

Felder, die in Phase 0.5 bereits aus Kontext extrahiert wurden, NICHT erneut fragen.

### Phase 1: Pfadspezifische Lücken-Fragen

#### PATH_A — Projekt mit Enddatum

| # | Frage | Modus |
|---|---|---|
| 1 | "Wie heisst das Projekt?" | freeform |
| 2 | "Beschreib in 1-2 Saetzen worum es geht." | freeform |
| 3 | "Welcher Sub-Typ passt?" | AskUserQuestion, 3 Options |
| 4 | "Sprache?" | AskUserQuestion, 3 Options |

**Frage 3 Options:**
- **Venture** — Eigenes Produkt, Service, Firma aufbauen
- **Client** — Dienstleistung fuer externen Kunden
- **Internal** — Internes Projekt mit Enddatum (Steuern, Marketing, Ops)

**Frage 4 Options:** Deutsch / Englisch / Gemischt.

Kein Typ-spezifischer Follow-up.

`TYP_DETAIL_LINE` = leer (kein Detail-Satz)
`VAULT_FOLDER` = `02_Projects`

#### PATH_B — Laufendes Thema / Area

| # | Frage | Modus |
|---|---|---|
| 1 | "Wie heisst die Area?" | freeform |
| 2 | "Beschreib in 1-2 Saetzen worum es geht." | freeform |
| 3 | "Sprache?" | AskUserQuestion, 3 Options |
| 4 | "Welches Thema deckt das ab?" | freeform |

`Typ` = `Area` (hart, nicht abfragen)
`TYP_DETAIL_LINE` = `**Thema:** {{Antwort Frage 4}}`
`VAULT_FOLDER` = `03_Areas`, Frontmatter `type: area`, `status: ongoing`

### Phase 2: Write

1. **CLAUDE.md im Root** erstellen:
   - `Read ~/.claude/templates/new-project/CLAUDE.md.template`
   - Platzhalter ersetzen: `{{PROJEKTNAME}}`, `{{KURZBESCHREIBUNG}}`, `{{TYP_DETAIL_LINE}}`, `{{SLUG}}`, `{{VAULT_FOLDER}}`, `{{SPRACHE}}`
   - `Write CWD/CLAUDE.md`
   - `TYP_DETAIL_LINE` Beispiele: `**Auftraggeber:** Kunde (anonymisiert)` oder `**Thema:** AI-Coding-Community` (leer lassen wenn kein Detail)
   - `VAULT_FOLDER` = `02_Projects` (Venture/Client/Internal) oder `03_Areas` (Area)

2. **.planning/STATE.md** erstellen:
   - `mkdir -p CWD/.planning`
   - `Read ~/.claude/templates/new-project/STATE.md.template`
   - Platzhalter ersetzen: `{{PROJEKTNAME}}`, `{{KURZBESCHREIBUNG}}`, `{{TYP}}`, `{{HEUTE}}` (2x)
   - `Write CWD/.planning/STATE.md`

3. **Vault-Notiz** erstellen:
   - `mkdir -p ~/Documents/Second-Brain/{{VAULT_FOLDER}}/{{SLUG}}`
   - `Read ~/Documents/Second-Brain/00_Meta/Templates/Project.md`
   - Platzhalter ersetzen:
     - `{{title}}` → Projektname
     - `{{date:YYYY-MM-DD}}` → Heute
     - `SLUG-HIER` → Slug
     - `type: project` → `type: project` (Venture/Client/Internal) oder `type: area` (Area)
     - `status: in-progress` → `in-progress` oder `ongoing` (Area)
     - `area/business` → `area/business` (Business-Typ) oder `area/engineering` (Tech-Typ), Default `business`
     - `[2-3 Saetze]` → Kurzbeschreibung
     - `[[Person]] — Rolle` → Team aus Kontext-Slot, sonst entfernen oder leer lassen
     - `[Wo steht das Projekt?]` → "Frisch aufgesetzt am {{HEUTE}}"
     - `~/Desktop/projects/PROJEKTORDNER` → CWD-Pfad oder "reines Vault-Projekt"
   - `Write ~/Documents/Second-Brain/{{VAULT_FOLDER}}/{{SLUG}}/{{SLUG}}.md`

4. **project-repos.yaml** (immer):
   - Prüfen ob `~/.claude/project-repos.yaml` existiert. Wenn nein: anlegen mit folgendem Header-Kommentar (wörtlich, mit echten Umlauten):
     ```
     # Source of Truth für das Mapping Projekt-Slug -> Repo-Pfad.
     # Einzige Pflegestelle: bei jedem neuen Projekt hier eine Zeile ergänzen.
     # Format: {{slug}}: {{pfad}}  (ein Eintrag pro Zeile, siehe unten)
     ```
   - Grep auf `^{{SLUG}}:` → Dup-Check. Wenn schon drin: skip, warnen.
   - Sonst: Append-Zeile `{{SLUG}}: {{CWD}}` ans Ende.
   - **Pfadformat (PFLICHT):** `{{CWD}}` wird immer als nativer Forward-Slash-Pfad geschrieben, nie als Backslash-Pfad, nie im MSYS-Format (`/c/Users/...`), nie mit `~`. Unter Windows/Git Bash: `cygpath -m "$PWD"` verwenden (ergibt z. B. `C:/Users/...`). Sonst (macOS/Linux): `$PWD` direkt.

### Phase 3: Confirmation Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 PROJEKT AUFGESETZT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{{PROJEKTNAME}}
Tag: project/{{SLUG}}
Typ: {{TYP}}

| Artefakt     | Pfad                                |
|--------------|-------------------------------------|
| CLAUDE.md    | [CWD]/CLAUDE.md                     |
| STATE.md     | [CWD]/.planning/STATE.md            |
| Vault-Notiz  | ~/Documents/Second-Brain/{{VAULT_FOLDER}}/{{SLUG}}/{{SLUG}}.md |
| Repo-YAML    | [ergaenzt | kein Repo | Duplikat]   |

───────────────────────────────────────────────────────
```

## Regeln

- **Frage-Wording business-tauglich.** Erklaere die Wirkung fuer den User, nicht die technische Aktion. Verwende "Projekt-Ordner" statt "Code-Repo"/"CWD"/"Repository", "Projekt-Notiz im Vault" statt "yaml-Eintrag", "Anleitung fuer Claude (CLAUDE.md)" statt nur "CLAUDE.md im Root". Kein Jargon in User-facing Strings (Banner, Fragen, Optionen, Beschreibungen, Reports).
- **Slug-Ableitung:** lowercase, Umlaute ersetzen (ae/oe/ue/ss), Leerzeichen und Unterstriche zu Bindestrichen, Sonderzeichen raus.
- **Area-Tag im Vault-Frontmatter:** `area/business` Default, `area/engineering` nur wenn Typ-Detail klar technisch (Software, Dev-Tool, Infra, etc.).
- **Frontmatter-Tags OHNE `#`** im YAML-Block (nur Inline-Markdown nutzt `#`).
- **Freeform-Extraktion aus Phase 0.5:** so viele Felder wie moeglich ableiten, nicht erneut fragen. Bei Unsicherheit (z.B. Typ nicht klar ableitbar): lieber nachfragen als falsch setzen.
- **Ueberschreiben-Option in Phase 0:** erfordert explizite zweite Confirm-Zeile mit Datei-Liste.
- **Abbruch jederzeit:** User kann "skip", "spaeter" oder "weiter" sagen. Fehlende Felder werden `[TODO]`.
- **Neue Vault-Notiz** wird beim naechsten `/brain:sort-inbox` automatisch in `00_Meta/system/vault-index.md` aufgenommen. Kein manueller Reindex.

## Templates

- `~/.claude/templates/new-project/CLAUDE.md.template`
- `~/.claude/templates/new-project/STATE.md.template`
- `~/Documents/Second-Brain/00_Meta/Templates/Project.md` (existierend, wird wiederverwendet)
