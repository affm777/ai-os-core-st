# YAML-Frontmatter-Cheatsheet (Skills + Subagents)

Stand April 2026, basierend auf code.claude.com/docs/en/skills + sub-agents.

## Skills — alle Felder

| Feld | Pflicht | Zweck | Beispiel |
|---|---|---|---|
| `name` | nein | Display-Name (default = Verzeichnis-Name) | `automation-helper` |
| `description` | **JA** (de facto) | Was Skill macht + wann nutzen. Triggert Auto-Invocation. | siehe Formel unten |
| `when_to_use` | nein | Zusaetzliche Trigger-Phrasen, wird an `description` angehaengt | siehe Formel unten |
| `argument-hint` | nein | Autocomplete-Hint | `[issue-number]` |
| `arguments` | nein | Named positional args | `name age` → `$name`, `$age` |
| `disable-model-invocation` | nein | `true` → nur User-getriggert via `/name` | `true` |
| `user-invocable` | nein | `false` → aus `/`-Menue ausblenden, nur Auto-Invoke | `false` |
| `allowed-tools` | nein | Pre-approved Tools | `Read, Write, Bash(git add *)` |
| `model` | nein | Model-Override fuer diesen Skill | `sonnet`, `haiku`, `inherit` |
| `effort` | nein | Reasoning-Effort | `low`, `medium`, `high`, `xhigh`, `max` |
| `context: fork` | nein | Skill laeuft im Subagent-Kontext (isoliert) | `context: fork` |
| `agent` | nein | Welcher Subagent-Typ wenn `context: fork` | `general-purpose`, `Explore` |
| `paths` | nein | Glob-Patterns die Auto-Activation einschraenken | `["src/**/*.ts"]` |
| `hooks` | nein | Lifecycle-Hooks (PreToolUse, PostToolUse, Stop) | siehe Hooks-Doku |
| `shell` | nein | `bash` (default) oder `powershell` | `bash` |

**Schreibweise: alle Hyphens (`disable-model-invocation`, `allowed-tools`).** Einzige Ausnahme: `when_to_use` mit Underscore.

## description — Best-Practice-Formel

```yaml
description: |
  <Was-Skill-tut>. Use when <Trigger 1>, <Trigger 2>, or when the user says "<woertliche Phrase>".
```

**Hard-Cap:** 1.536 Zeichen kombiniert mit `when_to_use`. Front-load den Hauptanwendungsfall — bei Cap-Erreichen wird abgeschnitten.

**Beispiel (Anthropic offiziell):**
```yaml
description: Explains code with visual diagrams and analogies. Use when explaining how code works, teaching about a codebase, or when the user asks "how does this work?"
```

**Beispiel (mehrsprachig):**
```yaml
description: Helps a non-technical founder turn a repetitive task into a reusable Claude Code skill.
when_to_use: |
  Trigger phrases (DE + EN): "automatisier das", "mach daraus einen Skill",
  "ich mache das taeglich", "automate this", "turn into a skill".
```

## Subagents — alle Felder

| Feld | Pflicht | Zweck |
|---|---|---|
| `name` | **JA** | Subagent-Name |
| `description` | **JA** | Triggert Auto-Delegation |
| `tools` | nein | Comma-separated Allowlist |
| `disallowedTools` | nein | Comma-separated Blocklist |
| `model` | nein | Model-Override |
| `permissionMode` | nein | Permission-Strenge |
| `maxTurns` | nein | Turn-Limit |
| `skills` | nein | Preload SKILL.md-Inhalte |
| `mcpServers` | nein | MCP-Server-Allowlist |
| `hooks` | nein | Lifecycle-Hooks |
| `memory` | nein | `user`, `project`, `local` |
| `effort` | nein | Reasoning-Effort |
| `isolation: worktree` | nein | Eigener Git-Worktree |
| `color` | nein | UI-Farbe |
| `initialPrompt` | nein | Auto-Prompt beim Spawn |
| `background` | nein | Hintergrund-Task |

## Pfade

**Skills:**
- Personal: `~/.claude/skills/<name>/SKILL.md`
- Project: `<project>/.claude/skills/<name>/SKILL.md`
- Plugin: `<plugin>/skills/<name>/SKILL.md` (Namespace `plugin-name:skill-name`)

**Subagents:**
- Personal: `~/.claude/agents/<name>.md`
- Project: `<project>/.claude/agents/<name>.md`

**Slash Commands (Legacy):**
- `~/.claude/commands/<name>.md`
- Subdirs namespacen: `~/.claude/commands/brain/sort-inbox.md` → `/brain:sort-inbox`

## Live-Reload

- Edits an bestehenden SKILL.md: sofort wirksam
- **Brand-neue Skill-Verzeichnisse:** Claude Code Restart noetig
