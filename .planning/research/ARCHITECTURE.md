# Architecture Patterns

**Domain:** Claude Code signature harness kit — global enforcement layer
**Researched:** 2026-06-22
**Confidence:** HIGH (all claims verified against official Claude Code docs)

---

## Recommended Architecture

The kit has exactly two layers. Nothing in between. No abstraction layer, no
registry service, no runtime coordinator. The two layers communicate through
the file system and through Claude Code's native primitives (hooks,
settings.json merge, CLAUDE.md loading order).

```
SIGNATURE LAYER (~/.claude/)         PROJECT LAYER (repo/.claude/ + CLAUDE.md)
─────────────────────────────        ──────────────────────────────────────────
settings.json  ← global hooks        settings.json  ← project hooks (additive)
agents/        ← verifier            CLAUDE.md      ← ~100 line TOC + @-imports
skills/        ← numbered procs      docs/          ← expanded sections
hooks/         ← shell scripts       .progress/     ← PROGRESS file lives here
failure-lib/   ← flat-file DB        (no local copy of signature assets)
CLAUDE.md      ← global prefs
```

The project layer NEVER copies signature assets. It references them by the
paths Claude Code natively resolves (`~/.claude/...`). This is what makes
lessons compound: update `~/.claude`, every project gets the update on the
next session.

---

## Component Boundaries

| Component | Lives In | Responsibility | Talks To |
|-----------|----------|----------------|----------|
| Global hooks | `~/.claude/hooks/` | Enforcement scripts (exit-code 2 = block) | Claude Code hook runner → failure-lib writer |
| Global settings | `~/.claude/settings.json` | Hook wiring for all projects | Project settings.json (merged additively for arrays) |
| Verifier agent | `~/.claude/agents/verifier.md` | Independent check of generator output | Reads PROGRESS file, failure-lib; writes verdict to stdout |
| Skills | `~/.claude/skills/` | Numbered procedures (human-written) | Invoked by agent via Skill tool; read failure-lib for context |
| Failure library | `~/.claude/failure-lib/` | Flat-file database of past failures | Written by PostToolUse hook; read by verifier + `/retro` skill |
| PROGRESS file | `<project>/.progress/PROGRESS.md` | Live build state, survives context reset | Written by PostToolUse hook; read by verifier + handoff skill |
| Project CLAUDE.md | `<project>/CLAUDE.md` | ~100 line TOC into docs/ | Loaded by Claude Code at session start alongside `~/.claude/CLAUDE.md` |
| Project docs/ | `<project>/docs/` | Expanded sections (arch, decisions, tasks) | Read on demand; no hooks, no enforcement |
| Project settings.json | `<project>/.claude/settings.json` | Project-specific hook overrides | Merges with global; array keys combine, scalar keys project wins |

---

## Question-by-Question Answers

### Q1: How should ~/.claude be organized as a versioned repo?

`~/.claude` itself is the git repo root. This is the correct choice because:

- Claude Code reads `~/.claude/settings.json`, `~/.claude/agents/`, `~/.claude/skills/`, and `~/.claude/CLAUDE.md` directly by convention. No symlinks needed.
- The entire signature layer ships as one `git clone` into `~/.claude`.
- A version tag on the repo is the version of the harness. Projects record which tag they were initialized against.

**Directory layout:**

```
~/.claude/
├── CLAUDE.md                    # Global prefs loaded into every session (~100 lines)
├── settings.json                # Global hook wiring; applies to all projects
├── VERSION                      # Plain text: "v0.1.0" — the harness version
├── CHANGELOG.md                 # Human-readable lesson history
│
├── hooks/                       # Shell scripts invoked by hook runner
│   ├── lib/                     # Shared functions sourced by hook scripts
│   │   └── common.sh            # jq helpers, PROGRESS writer, failure-lib writer
│   ├── write-progress.sh        # PostToolUse: Edit|Write → append to PROGRESS
│   ├── grep-stubs-reject.sh     # PreToolUse: Bash|Edit|Write → block if stubs found
│   └── skip-permissions.sh      # Unattended mode: auto-accept safe operations
│
├── agents/
│   └── verifier.md              # Verifier subagent definition (read-only tools)
│
├── skills/
│   ├── handoff/
│   │   └── SKILL.md             # /handoff — write structured handoff note
│   ├── retro/
│   │   └── SKILL.md             # /retro — read PROGRESS + failure-lib, propose lessons
│   └── start-project/
│       └── SKILL.md             # /start-project — scaffold project layer from template
│
├── failure-lib/                 # Flat-file failure database
│   ├── INDEX.md                 # Human-readable index of all failure IDs
│   └── failures/
│       └── <YYYY-MM-DD>-<slug>.md   # One file per failure record
│
└── templates/                   # Scaffolding used by /start-project skill
    ├── CLAUDE.md.tmpl
    ├── docs/
    │   ├── architecture.md.tmpl
    │   ├── decisions.md.tmpl
    │   └── tasks.md.tmpl
    └── .claude/
        └── settings.json.tmpl
```

**Versioning strategy:**

- Semantic versions (v0.1.0 / v0.2.0 / v1.0.0). Patch = lesson added to
  existing phase. Minor = new enforcement hook or skill. Major = breaking
  change to project-layer contract (e.g., PROGRESS file format change).
- Git tags are the source of truth. `VERSION` file exists for shell scripts
  that need to read the version without a git call.
- Projects record harness version in their `docs/architecture.md` at
  bootstrap time. This is the only coupling.

---

### Q2: How should the project layer reference the signature layer without duplication?

The answer is: let Claude Code's native loading order do the work. Do not
symlink. Do not copy. Do not `@import`.

**What Claude Code does natively (HIGH confidence — official docs):**

1. At session start, Claude Code loads `~/.claude/CLAUDE.md` first.
2. Then it loads the project's `CLAUDE.md` (from repo root or `CLAUDE.md` in
   `.claude/`). Project instructions take precedence when they conflict.
3. `~/.claude/settings.json` hook arrays combine with `.claude/settings.json`
   hook arrays. Project scalar settings override global scalars.
4. `~/.claude/agents/verifier.md` is available as a user-scope subagent in
   every project without any project-side declaration.
5. `~/.claude/skills/` skills are available in every project.

So the project layer's `CLAUDE.md` does NOT need to say "load the signature
layer." The signature layer is already loaded.

**What the project CLAUDE.md should contain (~100 lines):**

```markdown
# <Project Name>

## Signature Harness
Harness version: v0.1.0 (see ~/.claude/VERSION)
Rules: see ~/.claude/failure-lib/INDEX.md for enforcement rationale

## State
PROGRESS: .progress/PROGRESS.md — read this first every session

## Sections (expand from docs/ when needed)
- Architecture: docs/architecture.md
- Decisions: docs/decisions.md
- Active tasks: docs/tasks.md

## Quick commands
- /handoff — write session handoff note
- /retro — review PROGRESS + failures, propose lessons
- @verifier — invoke verifier subagent on current output

## Project conventions
[3-5 project-specific rules here — things the signature layer doesn't know]
```

The project `docs/` folder is NOT pulled from the signature layer. It is
scaffolded by the `/start-project` skill at initialization time from
templates, then maintained by the human. The signature layer provides the
template; the project owns the content.

---

### Q3: How should hooks be structured to be language-agnostic?

**The rule:** Hook scripts receive JSON on stdin. They read tool_name and
tool_input from that JSON. They make decisions based on text patterns, not
language-aware parsing. They are language-agnostic because they never import
a language runtime.

**Two-part structure:**

```
Hook script (thin, event-specific)     Shared lib (common.sh)
─────────────────────────────────      ─────────────────────
reads stdin JSON                       write_progress() function
extracts relevant fields via jq        write_failure() function
calls shared lib functions             format_block_response() function
exits 0 (pass) or 2 (block)            read_project_root() function
emits JSON output for Claude
```

**Example: write-progress.sh (PostToolUse on Edit|Write)**

```bash
#!/usr/bin/env bash
# Receives JSON from Claude Code on stdin
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd')

source "$(dirname "$0")/lib/common.sh"

# Language-agnostic: we only care that a file was written
write_progress "$CWD" "$TOOL" "$FILE"
exit 0
```

**Example: grep-stubs-reject.sh (PreToolUse on Write|Edit)**

```bash
#!/usr/bin/env bash
INPUT=$(cat)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_content // .tool_input.content // empty')

# Language-agnostic stub patterns — these appear in every language
if echo "$CONTENT" | grep -qE '(TODO|FIXME|pass$|\.\.\.|\bnotImplemented\b|raise NotImplementedError|throw new Error\("not implemented"\))'; then
  source "$(dirname "$0")/lib/common.sh"
  SLUG=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
  write_failure "$SLUG" "stub-written" "$CONTENT"
  # Exit 2: block the write, feed stderr to Claude
  echo "BLOCKED: File contains stubs or placeholder implementations. Complete the implementation before writing." >&2
  exit 2
fi
exit 0
```

**What goes in hook scripts vs. shared lib:**

| In hook script | In common.sh |
|---------------|-------------|
| Event-specific JSON field extraction | `write_progress(cwd, tool, file)` — appends to PROGRESS |
| Single decision logic (block/pass) | `write_failure(slug, tag, context)` — creates failure record |
| Error message for Claude on stderr | `format_block_response(reason)` — formats JSON output |
| Source common.sh when needed | `get_project_root(cwd)` — walks up to find CLAUDE.md |

**The language-agnostic constraint is preserved because:**
- Hooks receive and emit plain JSON/text
- Pattern matching is done with grep on raw file content (not AST-aware)
- No hook script imports node, python, jvm, etc.
- Stubs are detected by universal text patterns, not language-specific syntax

---

### Q4: How should the failure library be organized as flat files?

**Naming convention:**

```
~/.claude/failure-lib/failures/<YYYY-MM-DD>-<project>-<slug>.md
```

Example: `2026-06-22-giavico-stub-written-in-normalization.md`

- Date-first for chronological ordering with `ls`
- Project prefix for filtering by project
- Slug is the failure category, kebab-case

**File format (every failure record):**

```markdown
---
id: 2026-06-22-giavico-stub-written-in-normalization
date: 2026-06-22
project: giavico
category: stub-written
tag: model-crutch
phase: 0
severity: medium
converted-to-hook: no
hook-file:
---

# Failure: Stub Written in Normalization Module

## What happened
Claude wrote `pass` in the normalize_schema() function body, claiming the
implementation would follow, then attempted to proceed to the next task.

## Context
File: src/normalization/schema.py, line 47
Tool call: Write (new_content field)

## Impact
The next build step called normalize_schema() and got None return, failing
silently for 3 subsequent tool calls before the verifier caught it.

## Prevention
grep-stubs-reject hook now catches `pass$` pattern in Write/Edit targets.

## Raw context (first 200 chars of offending content)
def normalize_schema(df):
    pass  # TODO: implement
```

**Index file (`~/.claude/failure-lib/INDEX.md`):**

```markdown
# Failure Library Index

| ID | Date | Project | Category | Tag | Converted |
|----|------|---------|----------|-----|-----------|
| 2026-06-22-giavico-stub-written | 2026-06-22 | giavico | stub-written | model-crutch | yes |
```

Index is maintained by the `/retro` skill and updated by `write_failure()` in
common.sh. The index is what the verifier and `/retro` skill read for
discovery; individual files hold full context.

**Rule tagging:**
- `architecture` — structural pattern that is always wrong regardless of model
- `model-crutch` — pattern that the current model exhibits but a better model
  may not; candidate for pruning at the periodic review step

---

### Q5: How should the verifier subagent be invoked and separated from the generator?

**The structural separation (non-negotiable per project spec):**

The generator is the main conversation thread. The verifier is a subagent
defined in `~/.claude/agents/verifier.md`. They never share a context window.
The verifier receives only what is written to files — it does not see the
generator's reasoning or scratch work.

**verifier.md frontmatter:**

```yaml
---
name: verifier
description: Independently verifies completed work against acceptance criteria. Use after any claimed completion.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: sonnet
permissionMode: default
memory: user
color: red
---
```

Body (system prompt) instructs the verifier to:

1. Read the PROGRESS file to understand what was claimed complete
2. Run the binary check command listed in the PROGRESS file
3. Read failure-lib/INDEX.md and check if any known failure patterns apply
4. Output a structured verdict (see format below)
5. NEVER edit any project file

**Invocation pattern:**

Two paths — both are valid and serve different purposes:

```
Path A: Human-initiated
  Human types: @verifier check the normalization module
  Result: Verifier runs in its own context window, returns verdict

Path B: Hook-initiated (PostToolUse, agent handler type)
  After generator writes a file:
  settings.json PostToolUse hook with type: "agent"
  Spawns verifier subagent automatically
  Verifier returns verdict, exit code propagates to generator
```

For Phase 0, use Path A (simpler, no hook wiring needed). Phase 1 adds Path B.

**Verifier output format:**

Verifier writes its verdict to stdout in a structured block that the generator
can read:

```
VERDICT: PASS | FAIL | PARTIAL
BINARY-CHECK: <command that was run>
RESULT: <exit code of that command>
FAILURES-MATCHED:
  - <failure-id> : <why it matches>
BLOCKING-ISSUES:
  - <description>
NOTES:
  - <non-blocking observations>
```

This is plain text, not JSON. Plain text survives being injected into Claude's
context without escaping issues and is readable by humans reviewing transcripts.

---

### Q6: How should the PROGRESS file be structured for both human and agent readability?

**Location:** `<project-root>/.progress/PROGRESS.md`

The `.progress/` directory is gitignored in the project (it is runtime state,
not source). The PROGRESS file is appended by the `write-progress.sh` hook
after every Edit/Write tool call. It is never truncated automatically; pruning
is a human decision or a periodic `/retro` step.

**File format:**

```markdown
# PROGRESS — <Project Name>
Harness: v0.1.0
Last updated: 2026-06-22T14:32:01Z

## Session: 2026-06-22 (session-abc123)
Started: 2026-06-22T13:00:00Z

### Completed
- [x] 2026-06-22T13:05:22Z | Write | src/ingestion/excel.py | "Excel reader skeleton"
- [x] 2026-06-22T13:18:44Z | Edit  | src/ingestion/excel.py | "read_sheet() implemented"
- [x] 2026-06-22T13:45:10Z | Write | tests/test_excel.py    | "basic ingestion test"

### In Progress
- [ ] src/normalization/schema.py — normalize_schema() function

### Binary Check
Command: pytest tests/test_excel.py -x
Last result: PASS (2026-06-22T13:50:00Z)

### Open Issues
- normalize_schema() not yet started
- schema detection for merged cells unresolved

### Verifier Calls
- 2026-06-22T13:51:00Z | PASS | excel ingestion module

---
## Session: 2026-06-21 (session-xyz789)
[prior session entries...]
```

**Agent readability:** The hook appends timestamped entries in a predictable
format. The verifier reads the "Binary Check" section to know what command to
run. The `/retro` skill reads the "Open Issues" and "Verifier Calls" sections.
The `/handoff` skill reads the "In Progress" section to generate the handoff
note.

**Human readability:** Chronological, markdown, no special syntax required.
`grep` and `cat` are sufficient tools for a human to extract any section.

**Append format for write-progress.sh:**

```bash
# common.sh: write_progress()
write_progress() {
  local CWD="$1" TOOL="$2" FILE="$3"
  local PROGRESS_FILE
  PROGRESS_FILE=$(get_project_root "$CWD")/.progress/PROGRESS.md
  local TS
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "- [ ] ${TS} | ${TOOL} | ${FILE} | \"\"" >> "$PROGRESS_FILE"
}
```

The description field (`""`) is filled in by the generator when it summarizes
its own edit, passed as an optional fourth argument via the hook's
`additionalContext` JSON field.

---

### Q7: What is the right build order?

Dependencies are strict. Each item blocks the next.

```
Phase 0 — Skeleton (must exist before anything else)
  1. ~/.claude/ git repo initialized
  2. ~/.claude/hooks/lib/common.sh — write_progress(), write_failure(), get_project_root()
  3. ~/.claude/hooks/write-progress.sh — depends on common.sh
  4. ~/.claude/settings.json — wires write-progress.sh to global PostToolUse
  5. ~/.claude/agents/verifier.md — the verifier (read-only tools, no writes)
  6. ~/.claude/skills/handoff/SKILL.md — /handoff skill (reads PROGRESS)
  7. ~/.claude/failure-lib/ + INDEX.md — empty initially, populated by hooks
  8. ~/.claude/templates/ — project bootstrap templates
  9. ~/.claude/skills/start-project/SKILL.md — /start-project uses templates
 10. Giavico project bootstrapped via /start-project
 11. Giavico CLAUDE.md + docs/ + .progress/PROGRESS.md created
 12. End-to-end run: generator builds → PROGRESS updated → @verifier called

Phase 1 — Enforcement (requires Phase 0 complete)
 13. ~/.claude/hooks/grep-stubs-reject.sh — depends on common.sh from step 2
 14. settings.json updated to wire stub-rejection to PreToolUse
 15. All Phase 0 failure records in failure-lib converted to hooks/rules
 16. Rule tagging applied (architecture vs model-crutch) to all rules
 17. Re-run of Giavico to confirm old failures are blocked

Phase 2 — Context Plane (requires Phase 1 complete)
 18. ~/.claude/skills/retro/SKILL.md — /retro reads PROGRESS + failure-lib
 19. KV-cache ordering applied in ~/.claude/CLAUDE.md (stable content first)
 20. Handoff skill updated to write structured handoff note format
 21. Long-task survival test: context reset mid-session, verify coherence

Phase 3 — Self-Improve (requires Phase 2 complete)
 22. /retro skill updated to propose candidate lessons (not just review)
 23. Human approval gate: lesson proposal format defined
 24. Approval → write new failure-lib record + update hook/rule
 25. Periodic prune step for model-crutch tagged rules

Phase 4 — Heavy Retrieval (conditional, requires evidence from Phase 3)
 26. Only if trace proves retrieval is the bottleneck
```

---

## Data Flow

The complete information flow through the system:

```
Generator (main session)
  │
  ├─→ Edit/Write tool call
  │     │
  │     ├─→ PreToolUse hook: grep-stubs-reject.sh
  │     │     ├── reads tool_input.new_content from stdin JSON
  │     │     ├── grep for stub patterns
  │     │     ├── [if found] write_failure() → failure-lib/failures/<record>.md
  │     │     ├──            update INDEX.md
  │     │     ├──            exit 2 + stderr → Claude Code blocks tool call
  │     │     └── [if clean] exit 0 → tool call proceeds
  │     │
  │     └─→ PostToolUse hook: write-progress.sh
  │           ├── reads tool_name, tool_input.file_path from stdin JSON
  │           ├── write_progress() → .progress/PROGRESS.md (append)
  │           └── exit 0
  │
  ├─→ Human or hook invokes @verifier
  │     │
  │     └─→ Verifier subagent (fresh context window, read-only tools)
  │           ├── Read: .progress/PROGRESS.md → find binary check command
  │           ├── Bash: run binary check command → get exit code
  │           ├── Read: ~/.claude/failure-lib/INDEX.md → scan known failures
  │           ├── Grep: project files for matched failure patterns
  │           ├── emits verdict block (PASS/FAIL/PARTIAL + details)
  │           └── returns to generator context as subagent result
  │
  └─→ Human invokes /retro (Phase 3+)
        │
        └─→ /retro skill (runs in main context)
              ├── Read: .progress/PROGRESS.md
              ├── Read: ~/.claude/failure-lib/INDEX.md + individual records
              ├── proposes candidate lessons with recommended tag
              ├── presents to human for approval
              └── [if approved] writes new failure record + proposes hook update
```

---

## Scalability Considerations

| Concern | Phase 0-1 | Phase 2-3 | Phase 4+ |
|---------|-----------|-----------|----------|
| Failure library size | <50 records, full scan in grep | 50-500 records, INDEX.md scan first | 500+ records: earn vector index |
| PROGRESS file size | Append-only, grows per session | /retro prunes old sessions | Archive old sessions to .progress/archive/ |
| Hook execution time | Synchronous, <100ms acceptable | Async hooks for non-blocking checks | HTTP hooks to dedicated policy server |
| Skill context cost | All skills load on invocation | Path-scoped rules reduce baseline load | Subagent-preloaded skills for heavy workflows |
| Multi-project lessons | Manual: human copies lesson to global | /retro proposes → human promotes to ~/.claude | Automated lesson promotion with approval gate |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Copying Signature Assets Into Projects

**What:** Copying hook scripts or verifier.md into each project repo.

**Why bad:** Lessons committed to `~/.claude` do not propagate to projects
that copied old versions. The compounding effect is lost. You end up with N
diverged copies of enforcement rules.

**Instead:** Reference only. The project CLAUDE.md records the harness version
it was initialized against, but uses the current `~/.claude` at runtime.

---

### Anti-Pattern 2: Generator Grading Its Own Output

**What:** Having the main generator thread check whether its own output is
correct before declaring done.

**Why bad:** Structural grade inflation. The generator has already committed
to an approach and will rationalize it as correct. This is the documented
failure mode the verifier subagent is designed to prevent.

**Instead:** Always use the `@verifier` subagent. It runs in a fresh context
window with no knowledge of the generator's reasoning path. Its read-only
tools restriction means it cannot be pressured into accepting broken output
by "just fixing it real quick."

---

### Anti-Pattern 3: State in Context Window

**What:** Relying on the generator's memory of what was done rather than
reading PROGRESS file.

**Why bad:** Context compaction will destroy this state. Sessions end. Models
hallucinate prior completions. The PROGRESS file is the only durable record.

**Instead:** Every session starts with: read `.progress/PROGRESS.md`. Every
completion ends with: PROGRESS file updated (by hook). Verifier reads PROGRESS
file, not generator's claims.

---

### Anti-Pattern 4: Enforcement Through Documentation

**What:** Writing rules in CLAUDE.md and trusting the agent to follow them.

**Why bad:** Claude Code loads CLAUDE.md as guidance, not enforcement. The
agent can and will deviate under pressure, when context is full, or when
generating stubs "temporarily." Only hooks, permissions, and verifier checks
are enforced regardless of context state.

**Instead:** Every lesson that matters lives in a hook script (PreToolUse
block) or a verifier check, in addition to being documented. Documentation is
the explanation; enforcement is the guarantee.

---

### Anti-Pattern 5: One settings.json for Both Layers

**What:** Putting all hook wiring in the project's `.claude/settings.json`
instead of `~/.claude/settings.json`.

**Why bad:** The lesson only applies to one project. The next project starts
without it.

**Instead:** Global enforcement → `~/.claude/settings.json`. Project-specific
overrides (e.g., project-specific binary check command) → `.claude/settings.json`.
Because array keys combine, global hooks apply alongside project hooks with
no conflict.

---

## Sources

- Claude Code hooks reference (official): https://code.claude.com/docs/en/hooks
- Claude Code .claude directory explorer (official): https://code.claude.com/docs/en/claude-directory
- Claude Code subagents documentation (official): https://code.claude.com/docs/en/sub-agents
- Hook lifecycle events and exit codes: HIGH confidence — verified in official docs
- settings.json merge behavior (array combine, scalar override): HIGH confidence — official docs
- ~/.claude/agents/ user-scope applies to all projects: HIGH confidence — official docs
- Subagent memory: user scope at ~/.claude/agent-memory/: HIGH confidence — official docs
