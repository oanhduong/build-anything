# Phase 2: Context Plane - Context

**Gathered:** 2026-06-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Add the files hub, structured handoff note, and context pull skills so that a long multi-session task survives context reset without losing coherence — the next session must be able to reconstruct exact task state (current task, last 3 edits, open blockers, next action) from PROGRESS + handoff note alone.

Pre-existing infrastructure that Phase 2 builds on (do NOT re-implement):
- `bootstrap-project.sh` (SessionStart) — already creates `.progress/PROGRESS.md` on first use
- `load-lessons.sh` (SessionStart) — already injects failure-lib lesson index into context
- `lessons-post-write.sh` / `lessons-on-error.sh` — failure-lib already surfaced contextually

Self-improve loop (Phase 3) and heavy retrieval (Phase 4) are out of scope.

</domain>

<decisions>
## Implementation Decisions

### Handoff note location
- Separate `.progress/HANDOFF.md` file — not embedded in PROGRESS.md
- PROGRESS.md is the machine-readable state file (CURRENT_TASK, VERIFY_CMD, BLOCKED_COUNT, HISTORY LOG)
- HANDOFF.md is the human/agent-readable narrative note, overwritten each session stop
- Four required fields: current task, last 3 edits, open blockers, next action (as defined by CTXP-02)

### Handoff trigger
- Stop hook writes HANDOFF.md unconditionally on every session stop — not gated on VERIFY_CMD
- This ensures handoff fires for exploratory sessions too, not only tasks under verification
- The existing stop-hook.sh is extended: handoff write happens BEFORE the verify loop check (so even blocked tasks leave a handoff)
- `/handoff` skill also implemented as a manual override — user can write a fresh HANDOFF.md mid-session without stopping; both write to the same `.progress/HANDOFF.md`

### Context pull skill
- Single skill file with 3 subcommand operations (not three separate skills)
- Operations:
  - `search <query>` — grep over `docs/` and `.progress/` (NOT failure-lib; failure-lib is already surfaced by load-lessons.sh and lessons-on-error.sh hooks)
  - `get-file <path>` — read a specific context file and return its contents
  - `expand-summary <section>` — fetch a full section from a TOC pointer (e.g., expand a CLAUDE.md table entry into the full doc it references)
- Output format: plain markdown — readable by Claude without parsing
- Installed as a skill in `skills/` directory

### CLAUDE.md audit enforcement (CTXP-01)
- PreToolUse hook on Write/Edit when the target path matches `CLAUDE.md` or `*/CLAUDE.md`
- Grep for dynamic content patterns that violate KV-cache stability:
  - ISO 8601 timestamps (regex: `[0-9]{4}-[0-9]{2}-[0-9]{2}`)
  - PROGRESS tails or inline state dumps (`CURRENT_TASK:`, `## CURRENT STATE`, `BLOCKED_COUNT:`)
  - "Last updated:" or "Current task:" lines
- Blocking: exit 2, stderr message explains exactly what dynamic pattern was detected and instructs the author to move it to `.progress/PROGRESS.md` or a session-specific file instead
- Tag: architecture (KV-cache ordering is a permanent constraint, not model-crutch)

### context-reset-test.sh design
- The done command for Phase 2 (`./scripts/context-reset-test.sh`)
- Simulates context reset: write a known task state to PROGRESS + HANDOFF, then verify a fresh read of only those two files reconstructs exact state
- Script is automated (no real session restart needed) — write synthetic PROGRESS + HANDOFF, read them back, assert all four required fields are present and non-empty
- Returns [PASS]/[FAIL] per check in the same style as Phase 0/1 test scripts

### Claude's Discretion
- Exact HANDOFF.md markdown structure/sections (beyond the 4 required fields)
- Context pull skill invocation syntax (`/context-pull search foo` vs `/ctx search foo`)
- Grep flags and search depth for `search` subcommand
- Whether `expand-summary` falls back gracefully when a TOC pointer resolves to a missing file

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 2 requirements
- `.planning/REQUIREMENTS.md` — CTXP-01..04 (the four Phase 2 acceptance criteria). Every task must trace to one of these.
- `.planning/PROJECT.md` — Architecture principles (KV-cache ordering, state in files, language-agnostic hooks), constraints, out-of-scope list.

### Phase 2 scope and done command
- `.planning/ROADMAP.md` §Phase 2 — Done command (`./scripts/context-reset-test.sh`), success criteria (4 binary checks). Ground truth for what Phase 2 means.

### Pre-existing infrastructure to extend (not replace)
- `hooks/stop-hook.sh` — Current Stop hook (LOOP-01/LOOP-02); Phase 2 extends this to also write HANDOFF.md before the verify loop
- `hooks/bootstrap-project.sh` — SessionStart hook that creates PROGRESS.md; HANDOFF.md creation logic may be co-located here or added alongside
- `hooks/load-lessons.sh` — SessionStart hook that injects failure-lib index; `search` skill must NOT duplicate this (search targets docs/ and .progress/, not failure-lib)
- `hooks/common.sh` — canonical block()/emit()/trace_write() library; all new hooks source this

### Phase 1 enforcement patterns (follow exactly)
- `.planning/phases/01-enforcement-hardening/01-CONTEXT.md` — Decisions on hook style, tag annotations, block message format (How to fix: pattern), language-agnostic grep checks
- `hooks/stub-reject.sh` — Reference hook showing PreToolUse enforcement style with exit 2 + stderr block message

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `hooks/stop-hook.sh` — Already reads PROGRESS, writes to it, handles exit codes; Phase 2 adds HANDOFF.md write before the verify-loop block. The pattern: read PROGRESS fields → take action → emit result.
- `hooks/common.sh` — `block()`, `emit()`, `trace_write()` — new hooks for Phase 2 source this; CLAUDE.md audit hook uses `block()` for exit-2 blocking.
- `hooks/bootstrap-project.sh` — Template for SessionStart hook that creates a file if missing; same pattern for HANDOFF.md if it doesn't exist.
- `scripts/test-stub-reject.sh`, `scripts/replay-giavico-failures.sh` — Reference scripts showing `[PASS]`/`[FAIL]` per-check output style; `context-reset-test.sh` follows this style exactly.

### Established Patterns
- Hook enforcement pattern (Phase 1): PreToolUse → grep for bad pattern → block with exit 2 + "How to fix:" message to stderr. CLAUDE.md audit hook follows this.
- Tag annotations: `# tag: architecture` or `# tag: model-crutch <model-version>` in all hook files — ENFC-02 already enforced; new hooks must carry tags.
- Block message format from ENFC-03: every blocking hook message contains a failure description AND an explicit self-fix instruction.
- Test script style: named `[PASS] <id>: <description>` or `[FAIL]`, final summary `N passed, M failed`.

### Integration Points
- `hooks/stop-hook.sh` — extend to write `.progress/HANDOFF.md` before the verify-loop check
- `scripts/` — add `context-reset-test.sh` as Phase 2 done command
- `skills/` — currently empty; add `context-pull.md` skill here
- `settings.json` — PreToolUse array: add CLAUDE.md audit hook alongside existing `stub-reject.sh`
- `.progress/` — PROGRESS.md already exists (managed by bootstrap-project.sh); HANDOFF.md is the new file

</code_context>

<specifics>
## Specific Ideas

- No specific "I want it like X" references — standard harness patterns apply
- The `context-reset-test.sh` script is the ground truth for CTXP-04; it must work without a real session restart (synthetic fixture-based test)
- The handoff note is the primary recovery artifact — the model should be able to reconstruct what was happening purely by reading `.progress/PROGRESS.md` + `.progress/HANDOFF.md` with no other context

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-context-plane*
*Context gathered: 2026-06-23*
