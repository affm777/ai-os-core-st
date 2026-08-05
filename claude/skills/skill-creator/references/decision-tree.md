# Decision-Tree: Skill vs Slash Command vs Subagent

Stand April 2026. Slash Commands sind in Skills aufgegangen — fuer Neubau immer Skill, nur in Sonderfaellen Subagent.

## Quick-Lookup-Tabelle

| Use-Case | Primitiv | Frontmatter-Twist |
|---|---|---|
| Wiederkehrendes User-getriggertes Playbook | **Skill** | `disable-model-invocation: true` falls KEIN Auto-Invoke gewuenscht |
| Hintergrundwissen das Claude situativ ziehen soll | **Skill** | `user-invocable: false` |
| Multi-Step Workflow mit Reference Docs | **Skill** mit Supporting Files | Progressive Disclosure |
| Side-Task mit viel Read-Noise (Codebase-Map, Research) | **Skill** mit `context: fork` | `agent: general-purpose` oder `Explore` |
| Skill ruft langlebigen Worker auf | **Skill mit `context: fork`** | spawn Subagent isoliert |
| Reusable Worker-Persona mit eigenem Memory | **Subagent** | `~/.claude/agents/<name>.md` |
| Simple "Insert Template Text" | **Skill** mit User-Invocation | wie alter Slash Command |

## Entscheidungs-Heuristik (3 Fragen)

**Frage 1: Wie wird es ausgeloest?**
- "Wenn der User <Phrase> sagt" → Skill mit `description` + `when_to_use`
- "Wenn der User explizit `/name` tippt" → Skill mit `disable-model-invocation: true`
- "Wenn ein anderer Skill das delegiert" → Subagent

**Frage 2: Wie viel Read-Volumen / Context-Noise?**
- < 5k Tokens Reads → Skill ohne fork
- > 5k Tokens Reads ODER > 5 Items zu verarbeiten → Skill mit `context: fork`
- Permanent isolierte Persona mit eigenem Tool-Set → Subagent

**Frage 3: Braucht es Memory ueber Sessions hinweg?**
- Nein → Skill
- Ja, projekt-spezifisch → Subagent mit `memory: project`
- Ja, user-weit → Subagent mit `memory: user`

## Anti-Pattern: Wann KEINEN Skill bauen

- Einmaliger Use-Case (mach es einfach inline, kein Skill noetig)
- Workflow ist noch nicht stabil (erst 3-5x manuell durchziehen, dann Pattern abstrahieren)
- Workflow ist trivial (1-Satz-Prompt, lohnt keinen Skill-Overhead)

## Beispiele aus der Praxis

| Pain Point | Primitiv | Begründung |
|---|---|---|
| "Ich screene Pitch-Decks täglich" | Skill mit `context: fork` | Voice-Trigger natürlich, Web-Research isoliert |
| "Ich extrahiere Action Items aus Fathom-Meetings" | Skill | Auto-Invoke bei "neues Meeting", kurzer Body |
| "Ich pruefe Wettbewerber zu Firma X" | Skill mit `context: fork` | Massive Web-Reads, im Hauptkontext laestig |
| "Ich migriere Daten von DB1 nach DB2" | Subagent | Long-Running, eigenes Memory pro Migration-Typ |
| "Mein wiederkehrender Wochenreport" | Skill | Einfacher, Daily-Trigger via Scheduled Task |
