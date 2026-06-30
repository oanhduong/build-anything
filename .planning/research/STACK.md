# Technology Stack: Claude Code Signature Harness Kit

**Project:** Signature Harness Kit  
**Researched:** 2026-06-22  
**Primary sources:** code.claude.com/docs (official, fetched live), settings.json gist v2.1.104, official sub-agents and skills pages

---

## Primitive 1 — Hooks API

**Confidence: HIGH** — fetched directly from the official reference page.

### Hookable Events

Claude Code supports roughly 30 events across four cadence categories:

| Cadence | Events |
|---------|--------|
| Per-session | `SessionStart`, `SessionEnd` |
| Per-turn | `UserPromptSubmit`, `Stop`, `StopFailure` |
| Per-tool-call | `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied`, `PostToolBatch` |
| Async / observability | `FileChanged`, `CwdChanged`, `ConfigChange`, `Notification`, `MessageDisplay`, `SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `PreCompact`, `PostCompact`, `Elicitation`, `ElicitationResult`, `UserPromptExpansion`, `InstructionsLoaded`, `TeammateIdle` |

**For the harness, the events that matter most are:**

- `PreToolUse` on `Write|Edit` — enforce PROGRESS update, block stubs
- `PostToolUse` on `Write|Edit` — post-write validation (stub grep, linter)
- `Stop` — verify completion criteria before Claude declares done
- `SessionStart` — inject environment, set session-specific state
- `SubagentStart` / `SubagentStop` — observe verifier subagent lifecycle

### Configuration in settings.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/pre-edit-check.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/post-edit-update-progress.sh",
            "timeout": 15
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/pre-stop-verify.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

Config files and their merge order (highest to lowest precedence):

| File | Scope | Shareable |
|------|-------|-----------|
| Managed policy settings | Org-wide | Yes (admin) |
| `.claude/settings.local.json` | Project, personal | No (gitignore) |
| `.claude/settings.json` | Project | Yes (git) |
| `~/.claude/settings.json` | All projects | No |

**Harness recommendation:** put enforcement hooks in `~/.claude/settings.json` (global signature layer). Project-specific overrides go in `.claude/settings.json` in the project repo. Never put secrets in committed settings files.

### Hook Handler Types

| Type | Use in harness |
|------|---------------|
| `command` | Primary type — shell scripts that read JSON from stdin |
| `http` | Remote validation services; non-blocking by default unless response JSON sets `decision: "block"` |
| `mcp_tool` | Calls a connected MCP server tool; tool output treated as command stdout |
| `prompt` | Sends prompt to a Claude model for yes/no; default 30s timeout |
| `agent` | Spawns a subagent with tool access; experimental; default 60s timeout |

**Recommendation:** Use `command` type for all Phase 0 harness hooks. The `agent` type is marked experimental. The `prompt` type is useful for enforcement decisions that require natural language reasoning but adds latency.

### JSON Input to Hook Scripts (stdin)

All hooks receive a JSON payload on stdin. Common fields present in every event:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/dir",
  "permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
  "hook_event_name": "PreToolUse",
  "effort": { "level": "low|medium|high|xhigh|max" },
  "agent_id": "subagent-id",
  "agent_type": "agent-name"
}
```

For `PreToolUse` / `PostToolUse`, additional fields:

```json
{
  "tool_name": "Write",
  "tool_input": { "file_path": "/src/foo.ts", "content": "..." }
}
```

For `PostToolUse`, also includes `tool_output`. For `PostToolUseFailure`, includes `error`.

The `transcript_path` gives access to the full JSONL transcript, which is the mechanism for reading prior conversation history in a hook without relying on environment variables.

### Exit Codes and What They Signal

| Exit Code | Meaning |
|-----------|---------|
| `0` | Success. Parse stdout for optional JSON output. |
| `2` | Blocking error. Stderr is fed back to Claude / shown to user. Action is blocked (event-dependent). |
| Any other | Non-blocking error. Stderr shown in transcript; execution continues. |

**Critical:** exit code `1` is NOT blocking. Only `2` blocks. This is a common mistake.

### Blocking Behaviour by Event

| Event | exit 2 blocks? |
|-------|---------------|
| `PreToolUse` | Yes — prevents the tool call |
| `UserPromptSubmit` | Yes — prevents Claude from processing the prompt |
| `Stop` | Yes — prevents Claude from completing the turn |
| `PostToolUse` | No — tool already ran; use `decision: "block"` in JSON output instead |
| `PermissionRequest` | Yes — denies the permission |
| `SessionStart`, `SessionEnd` | No |

### JSON Output (stdout, only on exit 0)

Hooks can return a JSON object on stdout to influence Claude's behaviour:

```json
{
  "continue": true,
  "stopReason": "message shown if continue=false",
  "suppressOutput": false,
  "systemMessage": "warning shown to user",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask|defer",
    "permissionDecisionReason": "reason",
    "updatedInput": { "command": "modified tool input" },
    "additionalContext": "context injected into Claude's next turn"
  }
}
```

Key fields for harness use:

- `additionalContext` (on `PostToolUse`) — inject a PROGRESS-written confirmation or a stub-detection warning back to Claude without blocking
- `permissionDecision: "deny"` (on `PreToolUse`) — cleanly reject a tool call with a reason
- `continue: false` — stop the entire Claude session (use sparingly; this ends the loop)
- `decision: "block"` on `PostToolUse` JSON output — retroactively signal that this output should not be processed

### Timeout Constraints

| Event | Default timeout (command/http) | Default timeout (prompt) | Default timeout (agent) |
|-------|-------------------------------|--------------------------|------------------------|
| Most events | 600s | 30s | 60s |
| `UserPromptSubmit` | 30s | — | — |
| `MessageDisplay` | 10s | — | — |

Override with `"timeout": N` (seconds) in the hook entry.

**Harness constraint:** Phase 0 hooks must complete well within 30s (the `UserPromptSubmit` window). Target under 5s for per-edit hooks (`PostToolUse`). Slow hooks block every write — this is the most common cause of harness friction. Stub grep and PROGRESS writes should take under 1s on typical project sizes.

### Matcher Syntax

| Pattern | Evaluation |
|---------|-----------|
| `"*"`, `""`, or omitted | Match all occurrences |
| Letters, digits, `_`, `\|` | Exact match or pipe-separated list |
| Other characters | JavaScript regex |

MCP tools use the pattern `mcp__<server>__<tool>`. Use `mcp__memory__.*` for all tools from a server.

The `if` field adds a second filter using permission rule syntax (e.g., `"if": "Bash(git *)"` — fires only when Bash runs git commands). The `if` field is only evaluated on tool events, not on session or turn events.

**Bash `if` patterns are fail-open:** if the Bash command cannot be parsed, the hook fires anyway. Design hooks that are safe to run on any input.

### What Hooks Cannot Do

- Hooks run without a controlling terminal. Do not use interactive commands. Use `terminalSequence` in JSON output for notifications (supported since v2.1.141).
- HTTP hooks cannot block by status code alone — they must return `2xx + JSON {decision: "block"}` to block.
- `PostToolUse` hooks cannot undo a tool call that already executed. Use `PreToolUse` for blocking.
- Environment variables set inside a hook script do not persist to subsequent Claude tool calls unless you write to `$CLAUDE_ENV_FILE` (only available in `SessionStart`/`Setup`/`CwdChanged`/`FileChanged` hooks).

### Harness-Specific Hook Design

For the three Phase 0 hooks:

**write-progress-after-edit (PostToolUse on Write|Edit)**
```bash
#!/usr/bin/env bash
# Reads tool_input.file_path from stdin JSON, appends a timestamped line to PROGRESS
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "- [$TIMESTAMP] Edited: $FILE" >> "${CLAUDE_PROJECT_DIR}/PROGRESS"
```
Exit 0. No blocking needed. Fast — must complete in under 5s.

**grep-for-stubs-and-reject (PreToolUse on Write|Edit)**
```bash
#!/usr/bin/env bash
# Reads tool_input.content from stdin JSON, rejects if stub patterns found
INPUT=$(cat)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
if echo "$CONTENT" | grep -qE "(TODO|FIXME|NotImplemented|pass\s*#\s*stub|throw new Error.*not implemented)"; then
  echo "Stub pattern detected. Complete the implementation before writing." >&2
  exit 2
fi
```
Exit 2 blocks the write. Language-agnostic grep pattern — no per-stack adapters needed.

**skip-permission-prompts-for-unattended-runs**
Use `permissionMode: "bypassPermissions"` or `"auto"` in settings.json for unattended sessions rather than a hook. Or use a `PermissionRequest` hook that returns `{"hookSpecificOutput": {"decision": {"behavior": "allow"}}}` for specific tool patterns.

---

## Primitive 2 — Skills / Slash Commands

**Confidence: HIGH** — fetched from official skills and slash commands pages.

### Canonical Format: SKILL.md

The `.claude/commands/` format is the legacy path. The current standard is:

```
~/.claude/skills/<skill-name>/SKILL.md         # global (all projects)
.claude/skills/<skill-name>/SKILL.md            # project-specific
```

Both create a `/skill-name` slash command. Skills are preferred because they support:
- Supporting files directory (templates, scripts, examples)
- Frontmatter control over who invokes the skill (human vs Claude autonomous)
- Running in a forked subagent context (`context: fork`)
- Live reloading without session restart (edit detection on the directory)

**Files in `.claude/commands/` continue to work and support the same frontmatter.** Only use them if you have legacy files already — new skills go in `.claude/skills/`.

### SKILL.md File Format

```markdown
---
name: retro                          # display name (optional, defaults to dir name)
description: Reads PROGRESS + failure log + run trace, proposes candidate lessons. Use when asked to run a retrospective or /retro is invoked.
when_to_use: "invoke after a build run to surface lessons"
argument-hint: [run-id]              # shown in autocomplete
arguments: [run_id]                  # named arg; $run_id expands in content
disable-model-invocation: false      # true = manual /retro only, Claude won't auto-invoke
user-invocable: true                 # false = hidden from / menu (background knowledge)
allowed-tools: Read Bash             # tools allowed without permission prompt when skill is active
disallowed-tools: Write              # tools removed from pool while skill is active
model: inherit                       # or sonnet, opus, haiku, or full model ID
effort: medium
context: fork                        # run in a forked subagent context
agent: verifier                      # which subagent type to use when context: fork
hooks:                               # lifecycle hooks scoped to this skill
  PostToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "~/.claude/hooks/skill-post-write.sh"
paths:                               # only activate for files matching these globs
  - "src/**/*.ts"
---

## Current state

!`cat ${CLAUDE_PROJECT_DIR}/PROGRESS | tail -20`

## Task

Review the PROGRESS entries above and the failure library at @.claude/failures/.

Propose at most 5 candidate lessons. For each:
1. State the observed failure pattern
2. State the proposed enforcement rule
3. Tag it as `architecture` (permanent) or `model-crutch` (prune later)
4. Describe the binary done-check for the enforcement

Arguments passed: $run_id
```

### Key Frontmatter Fields for the Harness

| Field | Harness use |
|-------|------------|
| `disable-model-invocation: true` | Use for action skills like `/retro` and `/deploy` that must be explicitly triggered, not fired autonomously |
| `context: fork` | Use for the verifier skill — runs in its own context window so verification doesn't pollute the generator context |
| `agent: <name>` | Pair with `context: fork` to route to the verifier subagent definition |
| `allowed-tools` | Pre-approve tools the skill needs; avoids permission prompts during automated runs |
| `disallowed-tools` | Lock down skills that should never write (read-only verifier) |
| `hooks` | Scope hooks to a skill's execution only — keeps global hook config clean |
| `paths` | Load language-specific rules only when working in matching files (useful for per-stack rules if needed later) |

### String Substitutions in Skill Content

| Variable | Expands to |
|----------|-----------|
| `$ARGUMENTS` | Full argument string as typed |
| `$0`, `$1`, ... | Positional arguments (0-based) |
| `$name` | Named argument declared in `arguments` frontmatter |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_EFFORT}` | Current effort level string |
| `${CLAUDE_SKILL_DIR}` | Directory containing SKILL.md (use this to reference bundled scripts) |

### Dynamic Context Injection

Backtick syntax runs a shell command and inlines the output:

```markdown
!`cat ${CLAUDE_PROJECT_DIR}/PROGRESS | tail -20`
```

This is evaluated by Claude Code before Claude sees the content. Use it to inject PROGRESS content, failure library entries, or git status into skill prompts. The shell runs in the project working directory.

### File References

`@path/to/file` includes file contents inline:

```markdown
Review the failure library: @.claude/failures/
```

Relative paths resolve relative to the SKILL.md file, not the working directory.

### Size Limit

The combined `description` + `when_to_use` text is **truncated at 1,536 characters** in the skill listing (used by Claude to decide when to invoke). Keep descriptions tight. The body itself is loaded on-demand and has no hard character limit, but every line is a recurring token cost while the skill is active.

**Target under 200 lines for the SKILL.md body.** This is also the official recommendation for CLAUDE.md files.

### Skill Naming and Scope Precedence

Enterprise overrides personal; personal overrides project. A skill at any level overrides a bundled skill with the same name.

Command name comes from the **directory name**, not the `name` frontmatter field (exception: plugin root SKILL.md). So `~/.claude/skills/retro/SKILL.md` → `/retro`.

### Anti-Patterns for Skills

- Do not put multi-step procedures in CLAUDE.md. Move them to a SKILL.md — skill bodies load on-demand, CLAUDE.md loads every session.
- Do not rely on CLAUDE.md content alone to enforce actions. CLAUDE.md is context, not a hook. Enforcement that must fire every time needs a `PreToolUse` hook.
- Do not use `user-invocable: false` for skills users need to manually invoke. Only hide skills meant to be pure background knowledge.
- Do not import large files via `@path` in skills that run frequently — every `@` reference consumes context.

---

## Primitive 3 — Configuration System

**Confidence: HIGH** — fetched from official settings and memory pages.

### Settings File Hierarchy

| File | Scope | Shareable | Priority |
|------|-------|-----------|----------|
| Managed policy | Org-wide | Yes (admin-deployed) | 1 (highest) |
| CLI arguments | Session | N/A | 2 |
| `.claude/settings.local.json` | Project, personal | No (gitignored) | 3 |
| `.claude/settings.json` | Project | Yes (git) | 4 |
| `~/.claude/settings.json` | All projects | No | 5 (lowest) |

Non-conflicting keys merge across levels. A key set in `~/.claude/settings.json` still applies unless overridden at a higher level.

### Core Settings Keys Relevant to the Harness

```json
{
  "hooks": { ... },                          // hook registry — see Primitive 1
  "permissions": {
    "allow": ["Bash(npm run test *)", "Read(~/.zshrc)"],
    "deny": ["Bash(curl *)", "Read(.env)"],
    "ask": ["Bash(rm -rf *)"]
  },
  "env": {                                   // injected into every Bash call
    "HARNESS_VERSION": "0.1.0",
    "PROJECT_ROOT": "${CLAUDE_PROJECT_DIR}"
  },
  "model": "claude-sonnet-4-6",
  "effortLevel": "xhigh",
  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "~/.claude/auto-memory",
  "disableBundledSkills": false,             // set true if bundled skills conflict
  "claudeMdExcludes": [],                    // paths of CLAUDE.md files to skip
  "fileCheckpointingEnabled": true,          // Claude Code checkpoints edits
  "disableAllHooks": false                   // never set true in harness config
}
```

### Permission Rule Syntax

Rules in `permissions.allow` / `permissions.deny` / `permissions.ask`:

```
Bash(git *)              # git subcommands (glob)
Edit(*.ts)               # edits to TypeScript files
Write(~/sensitive/*)     # writes under a path
Read(.env)               # exact file
Agent(Explore)           # spawning the Explore subagent
```

Permission rules are additive across levels. An `allow` in `~/.claude/settings.json` and a `deny` in `.claude/settings.json` — the project `deny` wins (higher priority).

### What Hooks Can Inject Into the Environment

To set environment variables that persist into subsequent Bash tool calls, write to `$CLAUDE_ENV_FILE` from a `SessionStart`, `Setup`, `CwdChanged`, or `FileChanged` hook:

```bash
echo "export HARNESS_VERSION=0.1.0" >> "$CLAUDE_ENV_FILE"
echo "export PROJECT_ROOT=${CLAUDE_PROJECT_DIR}" >> "$CLAUDE_ENV_FILE"
```

This is the only supported mechanism. Setting `export` inside other hooks does not persist.

### CLAUDE.md Loading Behaviour

CLAUDE.md files are concatenated into a user message delivered after the system prompt. They are **not** part of the system prompt. Claude reads them and follows the instructions, but there is no hard enforcement — that is what hooks are for.

Load order (from outermost directory to working directory):

1. Managed policy CLAUDE.md (`/Library/Application Support/ClaudeCode/CLAUDE.md` on macOS)
2. `~/.claude/CLAUDE.md` (user-level)
3. CLAUDE.md files in ancestor directories walking down to cwd
4. `./CLAUDE.md` or `./.claude/CLAUDE.md` (project root)
5. `./CLAUDE.local.md` (personal, gitignored)

Subdirectory CLAUDE.md files load **on demand** when Claude reads files in those subdirectories, not at session start.

After `/compact`, only the project-root CLAUDE.md is re-injected. Nested CLAUDE.md files must wait for Claude to re-read a file in that subdirectory. This means critical context must live at the root CLAUDE.md, not only in subdirectory files.

**Size limit:** No hard character limit on CLAUDE.md, but the official recommendation is **under 200 lines per file**. Files longer than 200 lines consume more context and reduce adherence. For the harness, the project CLAUDE.md should be a ~100-line TOC pointing to docs/ — all heavy content goes in skills or docs.

**KV-cache ordering:** CLAUDE.md is delivered as a user message, which comes after the system prompt in the cache hierarchy. The cache prefix builds as: `tools → system → messages`. Content that changes frequently (e.g., timestamps, PROGRESS tails) breaks the cache for everything after it. Therefore:

- Put **stable** content at the top of CLAUDE.md (project name, architecture overview, immutable rules)
- Put **dynamic** content at the bottom or do not include it in CLAUDE.md at all
- Do NOT inline the PROGRESS file content in CLAUDE.md — inject it in skills with `!` syntax when needed
- HTML comments `<!-- notes for maintainers -->` are stripped before context injection — use them freely

### `.claude/rules/` Directory

For large projects, split CLAUDE.md into topic-specific files:

```
.claude/
  CLAUDE.md                    # 100-line TOC
  rules/
    architecture.md            # permanent architecture rules
    code-style.md              # formatting, naming
    testing.md                 # test requirements
    security.md                # never commit secrets, etc.
```

Rules without `paths` frontmatter load at session start like CLAUDE.md. Rules with `paths` load on-demand:

```markdown
---
paths:
  - "src/api/**/*.ts"
---
Use the standard error response format for all API handlers.
```

**Harness recommendation:** Use `paths` frontmatter in rules for language-specific guidance. This is the mechanism for per-stack rules without per-stack hook adapters — the rule loads only when Claude touches a matching file.

### Auto Memory

Auto memory (`MEMORY.md`) is distinct from CLAUDE.md. Claude writes it automatically. The first **200 lines or 25KB** of `MEMORY.md` loads at session start. Topic files (e.g., `debugging.md`) are loaded on demand.

Location: `~/.claude/projects/<repo>/memory/MEMORY.md`

Toggle with `autoMemoryEnabled: false` in settings.json or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.

For the harness, auto memory is a passive mechanism — do not rely on it for enforcement. It is useful for Claude accumulating debugging patterns and build commands organically, but every enforcement rule must be in a hook, skill, or explicit CLAUDE.md entry to survive across sessions.

---

## Primitive 4 — Subagent Primitives

**Confidence: HIGH** — fetched from the official sub-agents page.

### How the Agent Tool Works

When Claude invokes a subagent, it uses the `Agent` tool internally. Each subagent runs in its own context window with:
- Its own system prompt (the body of the AGENT.md file)
- Restricted or inherited tool access
- Independent permissions
- Optional persistent memory

The subagent returns a summary to the parent context. **The parent context does not see the subagent's full tool traces** — only the result. This is the mechanism that prevents generator-context flooding.

### Built-In Subagent Types

| Type | Model | Tools | CLAUDE.md loaded? |
|------|-------|-------|-------------------|
| `Explore` | Haiku | Read-only | No |
| `Plan` | Inherits | Read-only | No |
| `general-purpose` | Inherits | All | Yes |
| `statusline-setup` | Sonnet | Varies | Yes |
| `claude-code-guide` | Haiku | Varies | Yes |

`Explore` and `Plan` skip CLAUDE.md and git status for speed. All other built-in and custom subagents load both.

Disable a specific built-in by adding to `permissions.deny`:
```json
{ "permissions": { "deny": ["Agent(Explore)", "Agent(Plan)"] } }
```

Disable all built-ins in non-interactive / SDK mode via:
```
CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1
```

### Custom Subagent Definition Format

Subagent files use Markdown with YAML frontmatter. Two scope paths:

```
~/.claude/agents/<name>.md         # global (all projects)
.claude/agents/<name>.md           # project-specific
```

Example verifier subagent definition:

```markdown
---
name: verifier
description: Code and domain-rule verifier. Invoked after implementation to check correctness. Never invoked for generation tasks.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: sonnet
permissionMode: dontAsk
maxTurns: 20
memory: project
color: cyan
---

You are a verifier agent. Your only job is to check that the code submitted to you is correct, follows the project's domain rules, and passes binary done-checks.

Check in this order:
1. Compile / type-check (language-appropriate command)
2. Unit tests pass
3. Domain rule checks (from failure library in .claude/failures/)
4. If all pass, output: VERIFIED OK
5. If any fail, output: VERIFIED FAIL — <reason>

Never generate new code. Never suggest improvements. Only report pass/fail with evidence.
```

### Supported Frontmatter Fields for Custom Subagents

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Lowercase, hyphens. Used in `Agent(name)` references and hook `agent_type` field |
| `description` | Yes | Claude uses this to decide when to delegate |
| `tools` | No | Allowlist. Inherits all if omitted |
| `disallowedTools` | No | Denylist, applied before `tools` |
| `model` | No | `sonnet`, `opus`, `haiku`, `fable`, full model ID, or `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | No | Max agentic turns before stop |
| `skills` | No | Skill names to preload into subagent context at startup |
| `mcpServers` | No | MCP servers scoped to this subagent only |
| `hooks` | No | Lifecycle hooks scoped to this subagent |
| `memory` | No | `user`, `project`, or `local` — enables persistent MEMORY.md |
| `background` | No | `true` = always runs as background task |
| `effort` | No | Overrides session effort for this subagent |
| `isolation` | No | `worktree` = isolated git worktree |
| `color` | No | UI color: `red`, `blue`, `green`, `yellow`, `purple`, `orange`, `pink`, `cyan` |
| `initialPrompt` | No | Auto-submitted as first user turn when agent runs as main session |

### Tools Not Available to Subagents

These tools require the main session UI and cannot be used by any subagent:
- `AskUserQuestion`
- `EnterPlanMode`
- `ExitPlanMode` (unless `permissionMode: plan`)
- `ScheduleWakeup`
- `WaitForMcpServers`

### Passing Structured Output from Subagents

Subagents communicate results back to the parent via their text output. To get structured data:
- Instruct the subagent in its system prompt to output a specific format (JSON, or a VERIFIED OK / VERIFIED FAIL prefix as above)
- The parent agent reads the subagent's result text
- Programmatically (via Agent SDK), pass a JSON schema as `outputFormat` and read `structured_output` from the result

For the harness verifier pattern, a plain-text structured response (`VERIFIED OK` / `VERIFIED FAIL — <reason>`) is simpler and more robust than JSON output.

### Subagent Persistent Memory

When `memory` frontmatter is set, the subagent gets a directory:

| Scope | Location |
|-------|---------|
| `user` | `~/.claude/agent-memory/<name>/` |
| `project` | `.claude/agent-memory/<name>/` |
| `local` | `.claude/agent-memory-local/<name>/` |

The system prompt of the subagent automatically includes the first **200 lines or 25KB** of `MEMORY.md` in that directory. The subagent is instructed to curate `MEMORY.md` if it exceeds that limit.

Read, Write, and Edit tools are automatically enabled for the memory directory when `memory` is set.

**Harness use:** set `memory: project` on the verifier subagent so it accumulates codebase patterns, known failure modes, and verification shortcuts across sessions. This compounds the verifier's domain knowledge without manual curation.

### Preloading Skills into Subagents

The `skills` field injects full skill content into the subagent's context at startup:

```yaml
---
name: verifier
skills:
  - api-conventions
  - error-handling-patterns
---
```

Skills with `disable-model-invocation: true` cannot be preloaded. Unlisted skills can still be invoked by the subagent through the `Skill` tool during execution.

### Hooks Scoped to Subagents

Subagents can define hooks in their frontmatter that fire only during that subagent's execution:

```yaml
---
name: verifier
hooks:
  Stop:
    - hooks:
        - type: command
          command: "~/.claude/hooks/verifier-done.sh"
---
```

The `Stop` event inside a subagent frontmatter is converted to `SubagentStop` at runtime for the main session's hook handlers.

---

## Primitive 5 — Memory System

**Confidence: HIGH** — fetched from the official memory page.

### Two Independent Memory Mechanisms

| Mechanism | Author | Scope | Loaded into context |
|-----------|--------|-------|-------------------|
| CLAUDE.md files | Human | Project, user, org | Full content at session start |
| Auto memory (`MEMORY.md`) | Claude | Per-repo | First 200 lines or 25KB at session start |

These are complementary, not interchangeable. CLAUDE.md is the human-curated enforcement layer. Auto memory is organic learning. The harness uses both: CLAUDE.md for rules, auto memory for Claude to accumulate debugging patterns naturally.

### CLAUDE.md Is Not Enforced

CLAUDE.md delivers content as a user message. Claude reads it and follows it, but compliance is not guaranteed for ambiguous or verbose instructions. The official docs state: "The more specific and concise your instructions, the more consistently Claude follows them."

**Implication for harness design:** CLAUDE.md instructions are starting context, not rules. Any rule that must fire reliably needs a `PreToolUse` or `PostToolUse` hook. CLAUDE.md should point to hooks and say what they do, not attempt to replicate their logic in prose.

### The `/memory` Command

`/memory` lists all loaded CLAUDE.md, CLAUDE.local.md, and rules files. It also toggles auto memory on/off and opens the auto memory folder. Use it to verify the harness files are actually loading.

There is no programmatic "memory store" API accessible to hooks or skills. Persistent structured state lives in files (PROGRESS, failure library) and must be managed by hooks/skills writing to the filesystem.

---

## Primitive 6 — Constraints and Gotchas

**Confidence: HIGH** — from official docs; MEDIUM where noted from community sources.

### Hook Gotchas

1. **Exit 1 is not blocking.** Only exit 2 blocks. A hook that exits 1 shows stderr in the transcript and lets the action proceed.

2. **JSON output is only parsed on exit 0.** If you exit 2 (blocking), the stdout JSON is ignored. Put the human-readable reason in stderr.

3. **Hooks run without a controlling terminal.** Any command that tries to read from `/dev/tty` or requires interactive input will hang or error. Test hooks outside Claude Code first.

4. **Shell startup output corrupts JSON.** If your shell's `.bashrc` or `.zshrc` prints anything to stdout, the hook will emit that before the JSON and the parser will see invalid JSON. Use exec form (`"args"` present alongside `"command"`) to avoid shell startup, or suppress profile output in hook scripts.

5. **The `if` field is fail-open for Bash.** Unparseable Bash commands trigger the hook regardless of whether the pattern would match. Design hooks that are safe to run on any Bash command.

6. **`UserPromptSubmit` hooks have a 30s default timeout.** Hooks on this event block the user from getting a response. Do not run slow operations here.

7. **`MessageDisplay` hooks have a 10s default timeout.** Use only for fast display transformations.

8. **`PostToolUse` cannot undo.** Tool already ran. Use it for side effects (PROGRESS write) and feedback injection, not for blocking incorrect writes. Use `PreToolUse` for blocking.

9. **HTTP hooks are non-blocking by default.** A non-2xx response is a non-blocking error. To block from an HTTP hook, return 2xx + JSON `{"decision": "block"}`.

10. **Async hooks (`"async": true`) fire and forget.** The main flow does not wait for them. Use for logging and telemetry. Do not use for enforcement.

### CLAUDE.md Anti-Patterns

1. **Do not embed the PROGRESS file content in CLAUDE.md.** PROGRESS changes every edit, which breaks the KV-cache for the entire CLAUDE.md on every turn. Inject PROGRESS content in skills only, via `!` syntax.

2. **Do not pad CLAUDE.md with verbose prose.** Every line is a recurring token cost. "Use 2-space indentation" outperforms paragraphs explaining why.

3. **Do not put multi-step procedures in CLAUDE.md.** They load every session whether needed or not. Move them to a skill — body loads on-demand.

4. **Do not duplicate rules across CLAUDE.md and a skill.** Duplication creates contradictions. CLAUDE.md states what exists; skills define what to do.

5. **Nested subdirectory CLAUDE.md files do not survive compaction.** They are not re-injected after `/compact`. Critical handoff state must live at the project-root CLAUDE.md or in the PROGRESS file (read by skills).

6. **CLAUDE.md content is not system-prompt-level.** It arrives as a user message. If a rule must be at system-prompt level, use `--append-system-prompt` at the CLI invocation.

### Subagent Gotchas

1. **Subagents do not inherit CLAUDE.md if they are Explore or Plan.** Those built-in types skip CLAUDE.md for speed. Custom subagents (including the verifier) do load CLAUDE.md.

2. **Subagent files are loaded at session start.** Adding or editing a subagent file on disk requires restarting the session (unlike skills, which hot-reload). Use `/agents` interactive command to create subagents for immediate effect.

3. **`disallowedTools` is applied before `tools` when both are set.** A tool in both lists is removed.

4. **`permissionMode: bypassPermissions` on a subagent is overridden by the parent's mode if the parent uses `bypassPermissions` or `acceptEdits`.** Plan the permission hierarchy from the top down.

5. **Plugin subagents do not support `hooks`, `mcpServers`, or `permissionMode` in frontmatter.** These fields are silently ignored for plugin-sourced agents.

### Skills Gotchas

1. **`disable-model-invocation: true` also prevents the skill from being preloaded into subagents.** If you want a skill that only humans invoke AND you want to preload it into a subagent, you cannot do both — this is a current platform constraint.

2. **`allowed-tools` frontmatter in SKILL.md is ignored when using skills through the Agent SDK.** CLI behavior and SDK behavior differ here. For SDK usage, control tool access through the main `allowedTools` option.

3. **Skill descriptions are truncated at 1,536 characters.** Everything after the cap is invisible to Claude when deciding autonomous invocation. Front-load the key trigger conditions.

4. **The `name` frontmatter field does NOT set the slash command name** (except for plugin-root SKILL.md). The command name always comes from the directory name.

5. **Nested CLAUDE.md files in subdirectories are not loaded at session start**, only on demand. Skills that reference content in subdirectory CLAUDE.md files may see stale or missing context at invocation time.

### Config System Gotchas

1. **Most settings reload live, but some are read-once at startup** (`model`, `outputStyle`, `requiredVersions`). Model changes require a session restart.

2. **`claudeMd` key in managed settings cannot be excluded.** Managed CLAUDE.md always loads. Individual `claudeMdExcludes` patterns have no effect on it.

3. **`permissions.allow` and `permissions.deny` are per-tool-call rules, not session-level flags.** They do not change `permissionMode`; they modify which calls within the current mode require confirmation.

4. **The `env` key in settings.json injects variables into every Bash call.** Values are strings. Do not store secrets here — use `apiKeyHelper` (a script path) for dynamic credentials.

5. **`autoMode` setting is not shareable via project settings.** It belongs in `settings.local.json`. Do not commit it.

---

## Recommended Harness File Layout

```
~/.claude/                          # signature layer — global, version-controlled separately
  settings.json                     # global hooks, permissions, model config
  CLAUDE.md                         # user-level: personal baseline instructions
  skills/
    retro/SKILL.md                  # /retro — lesson distillation
    handoff/SKILL.md                # /handoff — session state serialization
  agents/
    verifier.md                     # verifier subagent definition
  hooks/
    pre-edit-check.sh               # stub detection (PreToolUse Write|Edit)
    post-edit-update-progress.sh    # PROGRESS update (PostToolUse Write|Edit)
    pre-stop-verify.sh              # done-check before Stop
  failures/                         # file-based failure library (one .md per lesson)

<project-repo>/
  CLAUDE.md                         # ~100 lines: project context TOC
  CLAUDE.local.md                   # gitignored: per-developer sandbox URLs
  PROGRESS                          # timestamped edit log; updated by hook
  .claude/
    settings.json                   # project-specific permissions/MCP/hooks
    rules/
      architecture.md               # permanent architecture rules
      model-crutch.md               # current-model weakness rules (tagged for pruning)
    skills/                         # project-specific skills (optional)
    agents/                         # project-specific subagent overrides (optional)
    failures/                       # project-specific failure library entries
```

---

## Sources

- [Hooks reference — code.claude.com/docs/en/hooks](https://code.claude.com/docs/en/hooks) — fetched live 2026-06-22
- [Skills — code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) — fetched live 2026-06-22
- [Slash Commands in the SDK — code.claude.com/docs/en/agent-sdk/slash-commands](https://code.claude.com/docs/en/agent-sdk/slash-commands) — fetched live 2026-06-22
- [Create custom subagents — code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents) — fetched live 2026-06-22
- [Memory — code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory) — fetched live 2026-06-22
- [Settings — code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings) — fetched live 2026-06-22
- [settings.json complete reference gist (v2.1.104)](https://gist.github.com/mculp/c082bd1e5a439410158974de90c89db7) — community, MEDIUM confidence for key names not in official docs
- [Claude Code hooks guide — morphllm.com](https://www.morphllm.com/claude-code-hooks) — community corroboration, LOW confidence used only where official docs gap
