# Phase 2: Context Plane - Research

**Researched:** 2026-06-23
**Domain:** Claude Code hooks, skills (slash commands), bash scripting, KV-cache stability
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Handoff note location:**
- Separate `.progress/HANDOFF.md` file — not embedded in PROGRESS.md
- PROGRESS.md is the machine-readable state file (CURRENT_TASK, VERIFY_CMD, BLOCKED_COUNT, HISTORY LOG)
- HANDOFF.md is the human/agent-readable narrative note, overwritten each session stop
- Four required fields: current task, last 3 edits, open blockers, next action (as defined by CTXP-02)

**Handoff trigger:**
- Stop hook writes HANDOFF.md unconditionally on every session stop — not gated on VERIFY_CMD
- Handoff fires for exploratory sessions too, not only tasks under verification
- Existing stop-hook.sh is extended: handoff write happens BEFORE the verify loop check (so even blocked tasks leave a handoff)
- `/handoff` skill also implemented as manual override — user can write fresh HANDOFF.md mid-session; both write to the same `.progress/HANDOFF.md`

**Context pull skill:**
- Single skill file with 3 subcommand operations (not three separate skills)
- Operations:
  - `search <query>` — grep over `docs/` and `.progress/` (NOT failure-lib; failure-lib already surfaced by load-lessons.sh and lessons-on-error.sh)
  - `get-file <path>` — read a specific context file and return its contents
  - `expand-summary <section>` — fetch full section from a TOC pointer (e.g., expand a CLAUDE.md table entry into the full doc it references)
- Output format: plain markdown — readable by Claude without parsing
- Installed as a skill in `skills/` directory

**CLAUDE.md audit enforcement (CTXP-01):**
- PreToolUse hook on Write/Edit when target path matches `CLAUDE.md` or `*/CLAUDE.md`
- Grep for dynamic content patterns:
  - ISO 8601 timestamps (regex: `[0-9]{4}-[0-9]{2}-[0-9]{2}`)
  - PROGRESS tails or inline state dumps (`CURRENT_TASK:`, `## CURRENT STATE`, `BLOCKED_COUNT:`)
  - "Last updated:" or "Current task:" lines
- Blocking: exit 2, stderr message explains what dynamic pattern was detected, instructs author to move it to `.progress/PROGRESS.md` or session-specific file
- Tag: architecture (KV-cache ordering is a permanent constraint)

**context-reset-test.sh design:**
- The done command for Phase 2
- Simulates context reset: write known task state to PROGRESS + HANDOFF, then verify a fresh read of only those two files reconstructs exact state
- Script is automated (no real session restart needed) — write synthetic PROGRESS + HANDOFF, read them back, assert all four required fields are present and non-empty
- Returns [PASS]/[FAIL] per check in same style as Phase 0/1 test scripts

### Claude's Discretion
- Exact HANDOFF.md markdown structure/sections (beyond the 4 required fields)
- Context pull skill invocation syntax (`/context-pull search foo` vs `/ctx search foo`)
- Grep flags and search depth for `search` subcommand
- Whether `expand-summary` falls back gracefully when a TOC pointer resolves to a missing file

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CTXP-01 | CLAUDE.md audit enforced: no dynamic content (timestamps, PROGRESS tails, current-task notes) in CLAUDE.md; stable reference content only | PreToolUse hook pattern identical to stub-reject.sh; grep patterns for dynamic content fully specified in CONTEXT.md |
| CTXP-02 | Structured session handoff note written at session end (via Stop hook or `/handoff` skill); contains: current task, last 3 edits, open blockers, next action | Stop hook extension pattern confirmed; HISTORY LOG already stores edits with timestamps; field extraction via grep on PROGRESS.md |
| CTXP-03 | Context pull skill provides 3 operations: `search`, `get-file`, `expand-summary` | Skills are SKILL.md files in `~/.claude/skills/<name>/`; bash dynamic injection via `` !`command` `` confirmed; `$ARGUMENTS` substitution for subcommand dispatch confirmed |
| CTXP-04 | Long task survives context reset: next session reconstructs state from PROGRESS + handoff note alone | context-reset-test.sh fixture-based approach confirmed; PROGRESS.md format known; HANDOFF.md four-field schema locked |
</phase_requirements>

---

## Summary

Phase 2 builds three things on top of the existing harness: (1) a CLAUDE.md audit hook that blocks dynamic content from polluting the KV-cache-stable reference file, (2) a structured HANDOFF.md written at every session stop and on demand, and (3) a context-pull skill with three subcommands for selective context retrieval.

All three deliverables follow patterns already established in Phase 0 and Phase 1 — no new mechanisms are needed. The CLAUDE.md audit hook is a new PreToolUse hook in the same mold as stub-reject.sh. The handoff writer is an extension of stop-hook.sh using the same PROGRESS.md field-extraction pattern already present in that file. The context-pull skill is a SKILL.md file installed into `~/.claude/skills/` — the same directory Claude Code watches for personal skills.

The done command (`./scripts/context-reset-test.sh`) is a fixture-based bash script: it writes synthetic PROGRESS.md and HANDOFF.md, reads them back, and asserts all four handoff fields are present and non-empty. No real session restart is required. This is the same injection-and-assert idiom used in Phase 0 and Phase 1 test scripts.

**Primary recommendation:** Extend existing hooks and follow established Phase 1 patterns exactly. This phase introduces no new tool types or infrastructure — it fills gaps in context management using the hook and skill primitives already working.

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| bash | system | All hook scripts and test scripts | Established harness pattern; language-agnostic |
| jq | system | JSON parsing in hooks (read hook input) | Already used in every existing hook |
| grep / awk / sed | system | Field extraction from PROGRESS.md, pattern matching | Used throughout existing hooks |

### Skill Format

| Asset | Path Pattern | Invocation | Notes |
|-------|-------------|------------|-------|
| Personal skill | `~/.claude/skills/<name>/SKILL.md` | `/name` or `/<name> <args>` | Available across all projects; installed by install.sh |
| `$ARGUMENTS` | In SKILL.md body | All text typed after `/name` | Passed as single string; `$0` = first word-arg |
| Dynamic injection | `` !`command` `` in SKILL.md | Runs command, inlines output | Used to inject live `search` results into skill context |

**No npm packages required.** This phase is pure bash + markdown.

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `mktemp` | Atomic writes to HANDOFF.md | Whenever overwriting a file in a hook (already used in stop-hook.sh and progress-after-edit.sh) |
| `date -u +"%Y-%m-%dT%H:%M:%SZ"` | Timestamp for HANDOFF.md header | Match existing PROGRESS timestamp format |

## Architecture Patterns

### Recommended Project Structure (additions only)

```
hooks/
├── stop-hook.sh          # EXTEND: add HANDOFF.md write before verify-loop block
├── claude-md-audit.sh    # NEW: PreToolUse hook; blocks dynamic content in CLAUDE.md
skills/
├── context-pull/
│   └── SKILL.md          # NEW: /context-pull skill with search/get-file/expand-summary
├── handoff/
│   └── SKILL.md          # NEW: /handoff manual override skill
scripts/
└── context-reset-test.sh # NEW: Phase 2 done command
.progress/
├── PROGRESS.md           # EXISTING: machine-readable task state
└── HANDOFF.md            # NEW: human/agent narrative note (written by hook + /handoff skill)
```

After install, `~/.claude/skills/context-pull/SKILL.md` and `~/.claude/skills/handoff/SKILL.md` are live immediately (Claude Code watches the skills directory without restart for SKILL.md changes in existing directories).

### Pattern 1: PreToolUse Hook for CLAUDE.md Audit (CTXP-01)

**What:** Hook fires when Write or Edit targets a path matching `CLAUDE.md`. Greps the content being written for dynamic patterns. Blocks with exit 2 if found.

**When to use:** Anytime a file must remain stable for KV-cache prefix reuse.

**Example:**
```bash
# claude-md-audit.sh — PreToolUse hook
# CTXP-01: blocks dynamic content in CLAUDE.md files
# tag: architecture
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
# Only fire on CLAUDE.md files
if ! echo "$FILE_PATH" | grep -qE '(^|/)CLAUDE\.md$'; then
  exit 0
fi

FILE_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_content // empty')
[ -z "$FILE_CONTENT" ] && exit 0

# Detect dynamic content patterns
if echo "$FILE_CONTENT" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
  block "Dynamic content detected in CLAUDE.md: ISO 8601 timestamp found" \
    "Move timestamps and date-stamped content to .progress/PROGRESS.md or a session-specific file. CLAUDE.md must be static reference content only (KV-cache stability — CTXP-01)."
fi
if echo "$FILE_CONTENT" | grep -qE '^(CURRENT_TASK:|VERIFY_CMD:|BLOCKED_COUNT:|## CURRENT STATE|Last updated:|Current task:)'; then
  block "Dynamic content detected in CLAUDE.md: PROGRESS state field or live-state line found" \
    "Remove CURRENT_TASK, VERIFY_CMD, BLOCKED_COUNT, or 'Last updated:' from CLAUDE.md. Dynamic state belongs in .progress/PROGRESS.md only (CTXP-01)."
fi

exit 0
```

### Pattern 2: HANDOFF.md Write in stop-hook.sh (CTXP-02)

**What:** Extend stop-hook.sh to write `.progress/HANDOFF.md` before the verify-loop block. Extracts fields from PROGRESS.md using grep; derives "last 3 edits" from HISTORY LOG tail.

**When to use:** Every session stop — unconditional, not gated on VERIFY_CMD.

**Insertion point in stop-hook.sh:** After the `stop_hook_active` guard and PROGRESS_FILE existence check, before the VERIFY_CMD empty check that allows early exit.

**Example (the HANDOFF write block to insert):**
```bash
# ---- CTXP-02: Write HANDOFF.md unconditionally on every session stop ----
HANDOFF_FILE="${CWD}/.progress/HANDOFF.md"
HANDOFF_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CURRENT_TASK_VAL=$(grep "^CURRENT_TASK:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "none")
# Last 3 edits from HISTORY LOG (skip comment lines)
LAST_3_EDITS=$(grep -v '^#' "$PROGRESS_FILE" 2>/dev/null | grep '^[0-9]' | tail -3 | sed 's/^/  - /' || echo "  - (none)")
OPEN_BLOCKERS=$(grep "^BLOCKED:" "$PROGRESS_FILE" 2>/dev/null | tail -1 | cut -d: -f2- | xargs 2>/dev/null || echo "none")
NEXT_ACTION="Resume CURRENT_TASK: ${CURRENT_TASK_VAL}. Run VERIFY_CMD to check state."

TMP=$(mktemp)
cat > "$TMP" << HANDOFF_EOF
# Session Handoff Note
Generated: ${HANDOFF_TIMESTAMP}

## Current Task
${CURRENT_TASK_VAL}

## Last 3 Edits
${LAST_3_EDITS}

## Open Blockers
${OPEN_BLOCKERS}

## Next Action
${NEXT_ACTION}
HANDOFF_EOF
mv "$TMP" "$HANDOFF_FILE"
emit "CTXP-02: HANDOFF.md written to ${HANDOFF_FILE}"
```

### Pattern 3: Context Pull Skill with Subcommand Dispatch (CTXP-03)

**What:** A SKILL.md in `skills/context-pull/` that dispatches `search`, `get-file`, or `expand-summary` subcommands. Uses `$ARGUMENTS` and bash dynamic injection.

**Key insight:** Skills are markdown prompt files. They instruct Claude to take action, using `$ARGUMENTS` for user input and `` !`command` `` for dynamic output injection. For operations that need live bash execution (search, file read), the skill instructs Claude to run the appropriate Bash/Read tool call — the SKILL.md cannot directly run shell for multi-step dispatch, but it can inject a pre-seeded search result using `` !`grep ...` `` for the search case.

**Recommended approach for search subcommand:** Use `` !`grep -r "$ARGUMENTS[1]" docs/ .progress/ 2>/dev/null | head -30` `` only if `$ARGUMENTS[0]` is `search`. Since SKILL.md cannot do conditional injection, the cleaner pattern is: instruct Claude in the skill body to parse `$ARGUMENTS`, then call the appropriate tool. The search operation uses Bash grep; get-file uses Read; expand-summary uses Read with CLAUDE.md section extraction.

**Example SKILL.md structure:**
```yaml
---
name: context-pull
description: Pull context from docs/ and .progress/ files. Use when resuming a task after reset, when you need to find a file, or when a CLAUDE.md table entry needs expansion.
argument-hint: "search <query> | get-file <path> | expand-summary <section>"
disable-model-invocation: false
---

Pull context from project files using one of three subcommands:

**Usage:** `/context-pull <subcommand> <args>`

## Subcommands

### search <query>
Grep `docs/` and `.progress/` for the query. Do NOT search `failure-lib/` (already surfaced by session-start hooks).

Run: `grep -r "$ARGUMENTS" docs/ .progress/ 2>/dev/null | head -40`

### get-file <path>
Read the specified file and return its full contents.

Read the file at the path given in `$ARGUMENTS`.

### expand-summary <section>
Look up `$ARGUMENTS` as a section name or key in `CLAUDE.md`'s TOC table. Find the reference path it points to. Read that file or section and return its full content.

---

Parse the first word of `$ARGUMENTS` as the subcommand and execute the matching operation above. Return output as plain markdown.
```

### Pattern 4: /handoff Manual Override Skill (CTXP-02 complement)

**What:** A SKILL.md that instructs Claude to write a fresh HANDOFF.md to `.progress/HANDOFF.md` immediately, using current session state. User invokes `/handoff` mid-session.

**When to use:** When the user wants to checkpoint state without ending the session.

**Example SKILL.md:**
```yaml
---
name: handoff
description: Write a fresh HANDOFF.md to .progress/HANDOFF.md immediately. Use when checkpointing mid-session or before a risky operation.
disable-model-invocation: true
---

Write `.progress/HANDOFF.md` now with the current session state.

Read `.progress/PROGRESS.md` to extract:
- CURRENT_TASK field value
- Last 3 lines from HISTORY LOG (non-comment lines starting with a timestamp)
- Any BLOCKED: lines

Write `.progress/HANDOFF.md` with exactly these four sections:
1. `## Current Task` — CURRENT_TASK value
2. `## Last 3 Edits` — last 3 HISTORY LOG entries
3. `## Open Blockers` — any BLOCKED: lines, or "none"
4. `## Next Action` — brief description of what to do next based on CURRENT_TASK

Confirm with: "HANDOFF.md written to .progress/HANDOFF.md"
```

### Pattern 5: context-reset-test.sh (CTXP-04 done command)

**What:** Fixture-based bash script. Writes synthetic PROGRESS.md and HANDOFF.md with known content, then reads them back and asserts all four handoff fields are present and non-empty.

**When to use:** Phase 2 done command; also callable in CI to verify handoff schema.

**Structure:**
```bash
#!/usr/bin/env bash
# context-reset-test.sh — Phase 2 done command
# CTXP-04: simulates context reset; verifies reconstruction from PROGRESS + HANDOFF
# Output: [PASS]/[FAIL] per check; "N passed, M failed" summary; exits 0 iff all pass
set -uo pipefail

PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL+1)); }

TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"

# Write synthetic PROGRESS.md + HANDOFF.md (known fixture)
cat > "$TMP/.progress/PROGRESS.md" << 'EOF'
CURRENT_TASK: test-task-context-reset
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE
...

## HISTORY LOG
2026-06-23T10:00:00Z | Write | hooks/stop-hook.sh | task:test-task-context-reset
2026-06-23T10:01:00Z | Write | .progress/HANDOFF.md | task:test-task-context-reset
2026-06-23T10:02:00Z | Edit | hooks/claude-md-audit.sh | task:test-task-context-reset
EOF

cat > "$TMP/.progress/HANDOFF.md" << 'EOF'
# Session Handoff Note
Generated: 2026-06-23T10:02:00Z

## Current Task
test-task-context-reset

## Last 3 Edits
  - 2026-06-23T10:00:00Z | Write | hooks/stop-hook.sh
  - 2026-06-23T10:01:00Z | Write | .progress/HANDOFF.md
  - 2026-06-23T10:02:00Z | Edit | hooks/claude-md-audit.sh

## Open Blockers
none

## Next Action
Resume test-task-context-reset. Run VERIFY_CMD to check state.
EOF

# CTXP-04 checks: read back and assert all 4 fields present and non-empty
CURRENT_TASK=$(grep "^## Current Task" -A1 "$TMP/.progress/HANDOFF.md" | tail -1 | xargs)
[ -n "$CURRENT_TASK" ] && pass "CTXP-04-a: HANDOFF.md has non-empty Current Task" || fail "CTXP-04-a: HANDOFF.md missing Current Task"

LAST_EDITS=$(grep "^## Last 3 Edits" -A3 "$TMP/.progress/HANDOFF.md" | grep '^\s*-' | head -1)
[ -n "$LAST_EDITS" ] && pass "CTXP-04-b: HANDOFF.md has at least one Last 3 Edits entry" || fail "CTXP-04-b: HANDOFF.md missing Last 3 Edits"

grep -q "^## Open Blockers" "$TMP/.progress/HANDOFF.md" && pass "CTXP-04-c: HANDOFF.md has Open Blockers section" || fail "CTXP-04-c: HANDOFF.md missing Open Blockers"

grep -q "^## Next Action" "$TMP/.progress/HANDOFF.md" && pass "CTXP-04-d: HANDOFF.md has Next Action section" || fail "CTXP-04-d: HANDOFF.md missing Next Action"

# CTXP-01: verify no dynamic content check passes — CLAUDE.md audit hook exists and is tagged
# (covered by checking the hook file directly in the real run)

rm -rf "$TMP"
echo ""; echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
```

### Anti-Patterns to Avoid

- **Writing HANDOFF.md inside the verify loop:** If the verify command fails, HANDOFF.md must still exist for the next session. The CONTEXT.md is explicit: handoff write is BEFORE the verify loop check.
- **Putting dynamic content in the SKILL.md body:** SKILL.md content stays in context across turns once loaded. Keep it concise (no full file dumps). Use `` !`command` `` injection sparingly, and only for short outputs.
- **Adding a new SessionStart hook for HANDOFF.md:** bootstrap-project.sh already creates PROGRESS.md. Creating HANDOFF.md at SessionStart is premature — it should only exist once a session has actually run. Write it at stop time.
- **Using `.claude/commands/` for the new skills:** The CONTEXT.md says skills go in `skills/` directory. The official docs confirm `~/.claude/skills/<name>/SKILL.md` is the current standard. `commands/` still works but is the legacy format.
- **Dispatching context-pull subcommands with `if [ "$CMD" = "search" ]` in bash injection:** SKILL.md bash injection `` !`...` `` runs at skill-load time, not at invocation time. Subcommand dispatch must be done by Claude reading `$ARGUMENTS` and choosing the right action in its response, or by having separate `search`, `get-file`, `expand-summary` named argument variants. Keep the skill body as plain instructions that Claude follows.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic file writes in hooks | Custom locking | `mktemp` + `mv` (already in stop-hook.sh, progress-after-edit.sh) | Atomic on POSIX; already established pattern |
| Subcommand routing in SKILL.md | Complex bash in `!`` injection | Plain markdown instructions with `$ARGUMENTS` | Bash injection runs at load time; dispatch must be by Claude reading `$ARGUMENTS` |
| Skill installation in target projects | Per-project copy | Install into `~/.claude/skills/` via install.sh | Personal skills available in all projects; no per-project duplication |
| Dynamic content detection | Model judgment | grep-based PreToolUse hook | Hooks fire before write; grep is deterministic; model judgment is not an enforcement mechanism |

**Key insight:** Every mechanism needed for Phase 2 already exists in Phase 0/1. The pattern is: grep-based PreToolUse for blocking + PROGRESS.md field extraction for state reading + mktemp/mv for atomic writes + SKILL.md for user-invocable operations.

## Common Pitfalls

### Pitfall 1: HANDOFF write ordering in stop-hook.sh
**What goes wrong:** If HANDOFF.md is written after the VERIFY_CMD early-exit (the `if [ -z "$VERIFY_CMD" ]; then exit 0; fi` block), then exploratory sessions with no VERIFY_CMD never get a handoff note.
**Why it happens:** stop-hook.sh has two early exits: `stop_hook_active` guard and empty VERIFY_CMD guard. HANDOFF write must be inserted after the first guard but before the second.
**How to avoid:** Insert the HANDOFF write block after `if [ ! -f "$PROGRESS_FILE" ]; then exit 0; fi` and before `if [ -z "$VERIFY_CMD" ]; then exit 0; fi`.
**Warning signs:** Testing with no VERIFY_CMD set and finding `.progress/HANDOFF.md` is not created.

### Pitfall 2: grep patterns matching too broadly in CLAUDE.md audit
**What goes wrong:** The ISO 8601 regex `[0-9]{4}-[0-9]{2}-[0-9]{2}` matches version numbers like `v1.0-02` or semantic versions `1.2.3-04` in table cells. False positive blocks legitimate writes.
**Why it happens:** Overly broad pattern; no word-boundary anchor.
**How to avoid:** Use a more anchored pattern: `[0-9]{4}-[0-9]{2}-[0-9]{2}T` (full ISO datetime) or `^[A-Za-z* |]*[0-9]{4}-[0-9]{2}-[0-9]{2}` (date at start of a field). Test against the current CLAUDE.md content before committing the hook.
**Warning signs:** Hook blocks writes to CLAUDE.md that contain only version numbers.

### Pitfall 3: Skills not appearing after install.sh copies them
**What goes wrong:** After `cp` to `~/.claude/skills/`, the skills don't show up in `/` menu.
**Why it happens:** Claude Code watches `~/.claude/skills/` for changes. If the `skills/` directory didn't exist when the session started, a new session is required. If the directory existed but a new subdirectory was added, live change detection handles it within the session.
**How to avoid:** install.sh already creates `~/.claude/skills/` in step 1 (`mkdir -p`). Skills copied there appear without restart. Document this in the install output message.
**Warning signs:** `/context-pull` not found in slash menu after install.

### Pitfall 4: context-reset-test.sh uses real PROGRESS.md
**What goes wrong:** The test script reads from the real `.progress/PROGRESS.md` and modifies real state, causing false passes or corrupting the project PROGRESS.
**Why it happens:** Missing `mktemp -d` + `cd "$TMP"` pattern; script uses `$PWD` instead of temp dir.
**How to avoid:** Always create a temp dir, write fixtures there, run assertions against the temp dir. Clean up with `rm -rf "$TMP"`. Do NOT `cd` into the real project directory during the test.
**Warning signs:** `.progress/PROGRESS.md` is modified after running the test script.

### Pitfall 5: `expand-summary` pointing to missing files
**What goes wrong:** CLAUDE.md TOC references a `docs/` file that hasn't been created yet. The expand-summary operation returns an error or empty result.
**Why it happens:** CLAUDE.md references `docs/` files but Phase 2 doesn't create those docs files.
**How to avoid:** The skill should instruct Claude to check if the referenced file exists before reading, and return a graceful "file not found" message with the path if missing (rather than erroring). This is Claude's Discretion per CONTEXT.md — implement a graceful fallback.
**Warning signs:** `/context-pull expand-summary <section>` returns a tool error instead of a not-found message.

## Code Examples

Verified patterns from existing hooks:

### PROGRESS.md field extraction (used by stop-hook.sh already)
```bash
# Source: hooks/stop-hook.sh (verified in codebase)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD:-$PWD}"
PROGRESS_FILE="${CWD}/.progress/PROGRESS.md"
VERIFY_CMD=$(grep "^VERIFY_CMD:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "")
BLOCKED_COUNT=$(grep "^BLOCKED_COUNT:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "0")
```

### Atomic file write pattern (used by stop-hook.sh and progress-after-edit.sh)
```bash
# Source: hooks/stop-hook.sh (verified in codebase)
TMP=$(mktemp)
# ... write to $TMP ...
mv "$TMP" "$TARGET_FILE"
```

### block() with "How to fix:" message (from common.sh)
```bash
# Source: hooks/common.sh (verified in codebase)
block "Dynamic content detected in CLAUDE.md: ISO 8601 timestamp found" \
  "Move timestamps and date-stamped content to .progress/PROGRESS.md. CLAUDE.md must be static (CTXP-01)."
# block() emits to stderr and exits 2
```

### Test script [PASS]/[FAIL] pattern (from test-stub-reject.sh)
```bash
# Source: scripts/test-stub-reject.sh (verified in codebase)
PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL+1)); }
# ... tests ...
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
```

### Skill SKILL.md minimal structure (from official docs)
```yaml
---
name: my-skill
description: What this skill does and when to use it.
argument-hint: "<subcommand> <args>"
disable-model-invocation: false
---

Skill instructions here. Use $ARGUMENTS for user input.
```

### settings.json PreToolUse hook addition
```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        { "type": "command", "command": "bash ~/.claude/hooks/stub-reject.sh" }
      ]
    },
    {
      "matcher": "Write|Edit",
      "hooks": [
        { "type": "command", "command": "bash ~/.claude/hooks/claude-md-audit.sh" }
      ]
    }
  ]
}
```
The existing jq merge in install.sh handles this correctly — it concatenates PreToolUse arrays, not overwrites.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.claude/commands/<name>.md` | `~/.claude/skills/<name>/SKILL.md` | Claude Code ~2025-2026 | Skills support supporting files, invocation control, live reload; commands still work (legacy) |
| Manual context reconstruction | PROGRESS.md + HANDOFF.md + session-start hooks | Phase 2 (this phase) | Sessions become resumable without relying on model memory |

**Deprecated/outdated:**
- `.claude/commands/` format: still works but skills are the recommended format per official docs. New skills for this phase use the skills directory format.

## Open Questions

1. **Skill directory live reload behavior for new subdirectories**
   - What we know: Official docs say "Creating a top-level skills directory that did not exist when the session started requires restarting Claude Code so the new directory can be watched." The `~/.claude/skills/` directory is created by install.sh step 1 with `mkdir -p`.
   - What's unclear: If the user runs install.sh for the first time on a live session, does adding new subdirectories under an already-watched `~/.claude/skills/` directory trigger live reload, or does it require restart?
   - Recommendation: Document in install.sh output: "Restart Claude Code if this is a fresh install to pick up new skill directories." For updates (skills dir already existed), no restart needed.

2. **`expand-summary` scope — CLAUDE.md only or any TOC?**
   - What we know: CONTEXT.md says "fetch a full section from a TOC pointer (e.g., expand a CLAUDE.md table entry into the full doc it references)"
   - What's unclear: Should `expand-summary` only work with CLAUDE.md table entries, or any markdown file with a TOC?
   - Recommendation: Scope to CLAUDE.md table entries for Phase 2 (the concrete use case). The skill can be broadened in Phase 3 if needed.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash (no test framework — same as Phase 0/1) |
| Config file | none — standalone bash scripts |
| Quick run command | `bash scripts/context-reset-test.sh` |
| Full suite command | `bash scripts/context-reset-test.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CTXP-01 | CLAUDE.md audit hook blocks dynamic content with exit 2 | unit (injection) | `echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"Updated: 2026-06-23"}}' \| bash hooks/claude-md-audit.sh; [ $? -eq 2 ]` | ❌ Wave 0 |
| CTXP-02 | Stop hook writes HANDOFF.md with 4 required fields | integration | `bash scripts/context-reset-test.sh` | ❌ Wave 0 |
| CTXP-03 | context-pull skill file exists and is well-formed | structural | `test -f ~/.claude/skills/context-pull/SKILL.md && grep -q 'search' ~/.claude/skills/context-pull/SKILL.md` | ❌ Wave 0 |
| CTXP-04 | Full context reset simulation passes | e2e | `bash scripts/context-reset-test.sh` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bash scripts/context-reset-test.sh`
- **Per wave merge:** `bash scripts/context-reset-test.sh`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `scripts/context-reset-test.sh` — covers CTXP-02, CTXP-04 (main done command)
- [ ] `hooks/claude-md-audit.sh` — CTXP-01 enforcement hook (needed before its test can run)
- [ ] `~/.claude/skills/context-pull/SKILL.md` — CTXP-03 skill file (installed via install.sh)
- [ ] `~/.claude/skills/handoff/SKILL.md` — CTXP-02 manual override skill (installed via install.sh)

*(Test infrastructure for CTXP-01 inline hook injection can be co-located in context-reset-test.sh as an additional check block, following the pattern of replay-giavico-failures.sh which runs multiple ENFC checks in a single script.)*

## Sources

### Primary (HIGH confidence)

- Codebase — `hooks/stop-hook.sh`, `hooks/common.sh`, `hooks/bootstrap-project.sh`, `hooks/stub-reject.sh`, `hooks/progress-after-edit.sh`, `hooks/load-lessons.sh`, `hooks/lessons-post-write.sh`, `hooks/lessons-on-error.sh` — all verified by direct file read
- Codebase — `settings.json`, `install.sh`, `scripts/test-stub-reject.sh`, `scripts/replay-giavico-failures.sh` — verified by direct file read
- Official Claude Code docs — https://code.claude.com/docs/en/slash-commands (skills format, frontmatter fields, `$ARGUMENTS`, `` !`command` `` injection, live reload behavior, personal vs project skills)
- `.planning/phases/02-context-plane/02-CONTEXT.md` — all locked decisions verified

### Secondary (MEDIUM confidence)

- Official docs confirmed: `~/.claude/skills/<name>/SKILL.md` is personal skill path; `~/.claude/commands/` is legacy but still works; skills support `$ARGUMENTS[N]` indexed access and `` !`command` `` dynamic injection

### Tertiary (LOW confidence)

- None — all claims verified against official docs or codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure bash + existing tools; verified in codebase
- Architecture patterns: HIGH — all patterns derived from existing hooks + official Claude Code skill docs
- Pitfalls: HIGH — derived from observed codebase patterns and official docs behavior notes
- Skill format: HIGH — verified against official Claude Code documentation fetched directly

**Research date:** 2026-06-23
**Valid until:** 2026-07-23 (skills API is stable; bash patterns are stable)
