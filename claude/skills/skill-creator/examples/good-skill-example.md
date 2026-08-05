# Beispiel: Ein gut gebauter Skill

## Use-Case

Ein Founder bekommt taeglich 5-10 Mails mit Pitch-Decks. Er will die wichtigsten Eckdaten extrahieren und in einer Vault-Notiz ablegen.

## SKILL.md (gut, ~80 Zeilen)

```markdown
---
name: extract-pitch-summary
description: Extracts the 7 key data points from a Pitch-Deck PDF and writes them to a Vault note. Use when the user says "fass das Pitch-Deck zusammen", "extrahier die Eckdaten", or drops a PDF into the inbound folder.
when_to_use: |
  Trigger: User mentions "pitch deck", "extract summary", "fass zusammen", or drags PDF into ~/Inbound/decks/.
allowed-tools: Read, Write, Glob
---

# Extract Pitch Summary

Du extrahierst aus einem Pitch-Deck-PDF die 7 Eckdaten und schreibst sie als Vault-Notiz.

## Workflow

1. **Input lesen:** Neuestes PDF aus `~/Inbound/decks/` (via Glob, sortiert nach mtime).
2. **Extrahieren** (in dieser Reihenfolge):
   - Firma + Geschaeftsmodell (1 Satz)
   - Stage (Pre-Seed / Seed / Series A/B/C)
   - Team (Founder + Schluesselrollen)
   - Traction (MRR / Users / GMV — was im Deck steht)
   - Round (Ticket, Pre-Money, Co-Investors)
   - Markt (TAM, falls erwaehnt)
   - Ask (was wollen sie konkret)
3. **Vault-Notiz schreiben** unter `~/Documents/Second-Brain/01_Inbox/YYYY-MM-DD-<firma-slug>.md` mit Frontmatter `type: resource`, `tags: [pitch-deck]`.
4. **Confirm** dem User: "Notiz angelegt, 7 Eckdaten extrahiert. Soll ich auch zu [[deal-pipeline]] verlinken?"

## Output-Format

\`\`\`markdown
---
title: <Firma> Pitch-Summary
type: resource
created_date: YYYY-MM-DD
tags: [pitch-deck, project/<slug>]
---

# <Firma>

| Feld | Wert |
|---|---|
| Modell | ... |
| Stage | ... |
...

**Naechster Schritt:** Deep-Dive lohnt? (Y/N)
\`\`\`

## Anti-Patterns

- Nicht extrahieren was nicht im Deck steht — lieber "im Deck nicht erwaehnt" als raten.
- Keine Marktanalyse — das macht der `/screen-deal`-Skill.
```

## Was diesen Skill gut macht

1. **Description front-loaded:** "Extracts the 7 key data points from a Pitch-Deck PDF" — sofort klar was passiert
2. **Trigger-Phrasen mehrsprachig:** "fass das Pitch-Deck zusammen" und "extract summary"
3. **Body unter 80 Zeilen** — Founder kann es in 1 Min ueberblicken
4. **Klare 4-Schritte-Pipeline** — kein Wischiwaschi
5. **Output-Format inline** — kein Drift zwischen Calls
6. **Anti-Patterns explizit** — Skill weiss was er NICHT tun soll

## Was vermieden wurde

- Keine Erklaerungen ueber AI/Vault/Best-Practices im Body (gehoert in Doku)
- Keine inline 30-Zeilen-Beispiele (waere Token-Verschwendung)
- Kein `context: fork` — Pipeline ist kurz, Read-Volumen niedrig
- Keine Sub-Skill-Calls — Skill macht nur EINE Sache
