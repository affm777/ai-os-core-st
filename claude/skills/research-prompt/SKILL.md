---
name: research-prompt
description: Einziger Eingang für Prompts an externe KI-Modelle (Gemini Deep Research, Gemini, ChatGPT, Claude, Perplexity, NotebookLM). Generiert einen optimierten Prompt aus Projekt-Kontext (CLAUDE.md, Rules, STATE.md, Memory), nutzt intern den prompt-engineer-Agent und kopiert das Ergebnis in die Zwischenablage. Triggert wenn jemand sagt "bau mir einen Prompt für Gemini/ChatGPT/...", "generier Research-Prompt", "ich will bei Gemini X recherchieren", "mach aus meinen Notizen einen Prompt", "research-prompt".
when_to_use: |
  Trigger-Phrasen: "bau mir einen Prompt für Gemini/ChatGPT/Claude/Perplexity", "generier Research-Prompt", "Gemini Deep Research", "ich will bei Gemini recherchieren", "formulier mir einen Research-Auftrag", "mach aus meinen Notizen einen Prompt", "dieser Prompt ist noch nicht gut", "/research-prompt". Jede Anfrage, deren Output in das Eingabefeld eines anderen KI-Modells wandern soll. Argument: Thema oder Fragestellung, optional Ziel-Modell.
allowed-tools: Read, Write, Glob, Grep, Bash(pbcopy:*), Bash(clip.exe:*), Bash(mkdir:*), Bash(ls:*), Bash(date:*)
---

# Prompt für externe KI generieren

Generiere einen optimierten Prompt für ein externes KI-Modell und kopiere ihn in die Zwischenablage. Default-Ziel: Gemini Deep Research. Nennt der User ein anderes Ziel (ChatGPT, Claude, Perplexity, NotebookLM, Gemini Standard), den Prompt dafür kalibrieren (Format, Länge, Stärken des Ziel-Modells).

## Argument

Pflicht: Thema oder Fragestellung (z.B. "Docker build optimization for Next.js with NEXT_PUBLIC env vars"). Optional: Ziel-Modell.

## Ablauf

1. **Projekt-Kontext laden:**
   - CLAUDE.md (Tech Stack, Architektur, Gotchas, Konventionen)
   - .claude/rules/ (alle Rule-Dateien die zum Thema passen)
   - .planning/STATE.md (aktueller Projektstand, offene Blocker)
   - .planning/research/gemini_deep_research/ (bereits vorhandene Research, um Duplikate zu vermeiden)
   - memory/ Gotchas die zum Thema relevant sind

2. **Prompt Engineer spawnen:**
   - Spawne einen `prompt-engineer` Sub-Agent
   - Übergib:
     - Das Thema des Users
     - Extrahierten Projekt-Kontext (Tech Stack, Constraints, bekannte Gotchas)
     - Das Ziel-Modell (Default: Gemini Deep Research) mit Anweisung, den Prompt dafür zu kalibrieren; bei Deep Research: "in English"
   - Der Prompt soll enthalten:
     - Expert Persona fuer Gemini
     - Strukturierte Teilbereiche mit Sub-Topics
     - Comparison Tables + Implementation Sketches als gewuenschtes Output-Format
     - Scope Constraints (2025-2026 Quellen, Team-Groesse, Budget, EU-Datensouveraenitaet wo relevant)
     - Projekt-spezifische Details die Gemini kennen muss (bestehendes Setup, bekannte Probleme)

3. **Prompt in Zwischenablage kopieren:**
   - Kopiere den fertigen Prompt via `pbcopy` (unter Windows/Git Bash: `clip.exe`, gleiche Pipe-Syntax)
   - Melde: "Prompt in Zwischenablage ({N} Woerter). In Gemini Deep Research einfuegen."

4. **Prompt als Referenz speichern:**
   - Erstelle `.planning/research/gemini_deep_research/` falls nicht vorhanden
   - Speichere den Prompt in `.planning/research/gemini_deep_research/prompt-YYYY-MM-DD-{slug}.md`
   - Damit spaeter nachvollziehbar ist, welcher Prompt zu welchem Research-Ergebnis fuehrte

## Hinweise

- Schritt 4 (Referenz speichern) gilt nur für Deep-Research-Aufträge; schnelle Prompts für andere Ziel-KIs nur via pbcopy (Windows: clip.exe) ausliefern
- Deep-Research-Prompts MÜSSEN in English sein (Gemini Deep Research arbeitet besser auf Englisch); andere Ziele: Sprache nach Zweck
- Projekt-spezifische Details einbauen, NICHT generisch lassen
- Bekannte Gotchas aus memory/ einbeziehen wenn thematisch relevant
- Bestehende Research referenzieren damit Gemini nicht dieselben Themen wiederholt
- Funktioniert in jedem Projekt
