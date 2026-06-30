# Phase 3: Self-Improve Loop - Context

**Gathered:** 2026-06-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the compounding loop: threshold-triggered auto-distill drafts candidate lessons from trace evidence, human approves via pending queue, approved lessons are committed to `failure-lib/` and surfaced automatically by existing hooks.

Pre-existing infrastructure that Phase 3 builds on (do NOT re-implement):
- `hooks/stop-hook.sh` — Stop hook (LOOP-01/LOOP-02); Phase 3 extends to check distill threshold and call auto-distill when met
- `hooks/load-lessons.sh` — SessionStart hook; Phase 3 extends to show pending-queue notice (SELF-04)
- `failure-lib/` — existing lessons (6 entries); distiller deduplicates against these before proposing new ones
- `hooks/lessons-on-error.sh` — fires on Bash exit≠0; tracks hit counts for repeated-failure threshold
- `hooks/common.sh` — `block()`, `emit()`, `trace_write()`; new scripts source this

Phase 4 (heavy retrieval) is out of scope.

</domain>

<decisions>
## Implementation Decisions

### Threshold trigger mechanics
- Two triggers for auto-distill; both are checked by stop-hook.sh:
  - **(a) Feature-complete**: Stop hook fires after verify exits 0 (successful task completion) → run auto-distill
  - **(b) Repeated-failure**: Same failure-lib `id` matched ≥3 times → run auto-distill
- Hit counts for repeated-failure are tracked in `.progress/lesson-hit-counts.json`
- `lessons-on-error.sh` is extended to increment the hit count for each matched failure-lib entry; writes to `.progress/lesson-hit-counts.json`
- stop-hook.sh checks hit counts on each invocation; if any entry ≥3, trigger auto-distill

### Pending queue storage
- Candidate lessons live in `failure-lib/pending/` directory as individual `.md` files
- Each candidate file uses the final failure-lib format (`id`/`tags`/`when`/`error-match` frontmatter) plus a required `evidence:` field citing at least one trace entry (tool name, file, exit code, timestamp)
- Candidates are NEVER auto-moved to `failure-lib/` — they stay in `pending/` until human approves or rejects
- Duplicate suppression: auto-distill greps `failure-lib/` (not `pending/`) before proposing any lesson; a candidate whose `id` already exists is silently dropped
- `architecture`-tagged rules are never auto-generated; only `model-crutch` rules and low-risk procedural skills go through auto-draft path

### `/retro` skill structure
- Single skill at `skills/retro/SKILL.md` with 3 subcommands:
  - `approve` — batch-review all files in `failure-lib/pending/`; show each candidate with evidence; human types `y/n` per candidate or `all`; approved ones are committed to `failure-lib/`; rejected ones are deleted from `pending/`
  - `run <trace-file>` — manual distill override; calls `scripts/auto-distill.sh` with explicit trace file; errors with "trace required" if no arg given (SELF-01)
  - `prune` — review all `model-crutch`-tagged rules in `failure-lib/`; show which ones carry a model version older than current; human confirms which to retire; retired entries are deleted and committed
- load-lessons.sh is extended to count files in `failure-lib/pending/` at SessionStart; if count > 0, emit one-line notice: "N lessons pending — run \`/retro approve\` to review"

### Auto-distill script design
- Lives at `scripts/auto-distill.sh` — a standalone script, NOT embedded in stop-hook.sh
- stop-hook.sh calls `auto-distill.sh` when threshold is met, passing: trace.log path, PROGRESS.md path, failure-lib path
- `/retro run <trace-file>` also calls `auto-distill.sh` with explicit trace file
- Script logic:
  1. Parse trace.log + PROGRESS.md for error patterns and repeated failures
  2. Grep failure-lib for duplicate suppression
  3. For each novel pattern: draft a candidate `.md` file in `failure-lib/pending/` with evidence field
  4. Emit count of candidates written (or "0 new candidates — all patterns already in failure-lib")
- Auto-distill never proposes `architecture`-tagged rules — only `model-crutch` and procedural skill candidates

### Done command and e2e test
- `./scripts/retro-e2e-test.sh` is the Phase 3 done command
- Test sequence:
  1. Inject a synthetic repeated failure hit into `.progress/lesson-hit-counts.json` (≥3 count for a known id)
  2. Inject a synthetic trace entry into a temp trace file
  3. Call `auto-distill.sh` with the temp trace file
  4. Verify a candidate appears in `failure-lib/pending/`
  5. Verify the candidate has an `evidence:` field
  6. Verify duplicate suppression: run auto-distill again — same candidate NOT re-added
  7. Run `retro approve` (or equivalent approval script) on the candidate
  8. Verify the approved lesson appears in `failure-lib/` and was committed to `~/.claude`
- Script uses `[PASS] <id>: <description>` / `[FAIL]` style consistent with Phase 0/1 scripts

### Claude's Discretion
- Exact format of `lesson-hit-counts.json` (key structure, versioning)
- How auto-distill handles partial trace files or empty trace.log
- Whether `retro-e2e-test.sh` calls install.sh as a pre-step (like replay-giavico-failures.sh does)
- Exact prose in the pending-queue notice emitted by load-lessons.sh

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 3 requirements
- `.planning/REQUIREMENTS.md` — SELF-01..09 (9 Phase 3 acceptance criteria). Every task must trace to one of these.
- `.planning/PROJECT.md` — Constraints: human gate is non-negotiable, `architecture` rules never auto-generated, auto-draft for `model-crutch` and procedural skills only, language-agnostic hooks.

### Phase 3 scope and done command
- `.planning/ROADMAP.md` §Phase 3 — Done command (`./scripts/retro-e2e-test.sh`), success criteria (5 binary checks). Ground truth for what Phase 3 means.

### Pre-existing infrastructure to extend (not replace)
- `hooks/stop-hook.sh` — Current Stop hook; Phase 3 adds threshold check + auto-distill call at the top, before the verify loop
- `hooks/load-lessons.sh` — SessionStart hook; Phase 3 extends to emit pending-queue notice
- `hooks/lessons-on-error.sh` — PostToolUse Bash hook; Phase 3 extends to increment hit counts in `.progress/lesson-hit-counts.json`
- `hooks/common.sh` — canonical `block()`/`emit()`/`trace_write()` library; all new hooks/scripts source this
- `~/.claude/trace.log` — the trace file auto-distill reads; written by `hooks/trace.sh` each tool invocation

### Phase 1/2 enforcement patterns (follow exactly)
- `.planning/phases/01-enforcement-hardening/01-CONTEXT.md` — Hook style, tag annotations, block message format
- `.planning/phases/02-context-plane/02-CONTEXT.md` — Extension pattern for stop-hook.sh and load-lessons.sh
- `hooks/stub-reject.sh` — Reference PreToolUse hook with exit 2 + stderr block message

### Existing failure-lib for dedup reference
- `failure-lib/` — 6 existing entries (dotenv-module-scope, eval-subshell, home-scope, mock-import-boundary, openpyxl-engine, static-test-fixture). Auto-distill must not reproduce these.

### Test script style reference
- `scripts/replay-giavico-failures.sh` — Shows [PASS]/[FAIL] per-check style and final summary; `retro-e2e-test.sh` follows this exactly.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `hooks/stop-hook.sh` — Phase 3 extends this: add threshold check before verify loop; if threshold met, call `scripts/auto-distill.sh`; preserve existing verify loop and exit-code logic
- `hooks/load-lessons.sh` — Phase 3 extends: after injecting lesson index, count `failure-lib/pending/*.md`; if count > 0, emit one-line notice
- `hooks/lessons-on-error.sh` — Phase 3 extends: on matched failure-lib entry, increment its hit count in `.progress/lesson-hit-counts.json`
- `scripts/replay-giavico-failures.sh` — Reference for e2e test script structure; `retro-e2e-test.sh` mirrors this pattern
- `hooks/common.sh` — `emit()` function for writing to stderr; auto-distill.sh uses this for output

### Established Patterns
- Tag annotations: `# tag: architecture` or `# tag: model-crutch <model-version>` in all enforcement files; auto-distill candidates that lack a model version in model-crutch tag are rejected
- Block message format: failure description + "How to fix:" — candidate lesson `when`/`error-match` fields mirror this pattern
- Test script style: `[PASS] <id>: <description>` or `[FAIL] <id>: <description>`, final summary `N passed, M failed`, exits non-zero if any fail

### Integration Points
- `hooks/stop-hook.sh` — extend threshold check BEFORE the existing verify loop (line 1 of main logic)
- `hooks/load-lessons.sh` — extend at the end to emit pending-queue notice
- `hooks/lessons-on-error.sh` — extend to write `.progress/lesson-hit-counts.json`
- `scripts/` — add `auto-distill.sh` and `retro-e2e-test.sh`
- `skills/retro/` — new skill directory; add `SKILL.md`
- `failure-lib/pending/` — new subdirectory; created by auto-distill.sh on first run

</code_context>

<specifics>
## Specific Ideas

- The pending queue notice from load-lessons.sh must be a single line — consistent with the existing compact lesson index injection (no verbose formatting)
- `auto-distill.sh` must be independently testable: `retro-e2e-test.sh` calls it directly with a synthetic trace file, no real session needed
- Duplicate suppression greps `failure-lib/` (committed lessons), not `failure-lib/pending/` — so re-running auto-distill with the same trace does not stack up duplicate candidates

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-self-improve-loop*
*Context gathered: 2026-06-23*
