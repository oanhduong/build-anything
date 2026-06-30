---
phase: 01-enforcement-hardening
plan: 03
subsystem: infra
tags: [enforcement, bash, replay, acceptance-test, ENFC-01, ENFC-02, ENFC-03, ENFC-04, ENFC-05]

# Dependency graph
requires:
  - phase: 01-enforcement-hardening
    plan: 01
    provides: "6 failure-lib entries with enforcement-type: verifier-check (ENFC-01 data layer)"
  - phase: 01-enforcement-hardening
    plan: 02
    provides: "# tag: architecture on all hooks (ENFC-02); How to fix: in all hooks (ENFC-03); verifier.md runtime scan"
provides:
  - "scripts/replay-giavico-failures.sh — Phase 1 done command that proves ENFC-01..05 in a single run"
  - "ENFC-05 satisfied: done command exits 0 with 0 failed when all prior plans are in place"
affects: [phase-02-context-plane, install-sh, acceptance-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Phase 1 done command pattern: single script proves all ENFC requirements; [PASS]/[FAIL] per test; exits 0 iff all pass"
    - "PRE-STEP pattern: call install.sh at top of replay script before any ~/.claude/hooks/ checks (Pitfall 5 avoidance)"
    - "Exempt hook pattern: progress-after-edit.sh and trace.sh exempted from ENFC-03 fail path since they carry # How to fix: N/A"

key-files:
  created:
    - scripts/replay-giavico-failures.sh
  modified: []

key-decisions:
  - "replay-giavico-failures.sh calls install.sh as PRE-STEP before ENFC-02/03/04 checks on ~/.claude/hooks/ — ensures source changes propagate to installed path before grep assertions run"
  - "ENFC-01 section delegates F-EVAL-SUBSHELL to existing force-loop-test.sh rather than duplicating test logic — reuse proven injection idiom"
  - "ENFC-01 Python verifier-check failures verified via failure-lib file existence + grep for enforcement-type: verifier-check — cannot be injection-tested (ENFC-04 boundary)"
  - "ENFC-03 loop checks all installed hooks; progress-after-edit.sh and trace.sh are exempt via conditional branch (they carry # How to fix: N/A, so grep matches — no actual exemption needed)"

patterns-established:
  - "Pattern: Phase N done command structure — PRE-STEP (install) + ENFC section loops + [PASS]/[FAIL] counters + summary line + exit [ $FAIL -eq 0 ]"
  - "Pattern: failure-lib verifier-check proof via file existence + frontmatter grep rather than runtime injection (language-specific enforcement stays out of hooks)"

requirements-completed: [ENFC-04, ENFC-05]

# Metrics
duration: 2min
completed: 2026-06-22
---

# Phase 1 Plan 03: Replay Giavico Failures Script Summary

**`scripts/replay-giavico-failures.sh` — single-run Phase 1 acceptance test proving ENFC-01..05 via injection tests, grep assertions, and failure-lib existence checks; exits 0 with 0 failed**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-22T14:16:26Z
- **Completed:** 2026-06-22T14:17:30Z
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint — APPROVED)
- **Files modified:** 1

## Accomplishments
- `scripts/replay-giavico-failures.sh` created, chmod +x, and committed
- Script calls `install.sh` as PRE-STEP before any `~/.claude/hooks/` assertions (avoids Pitfall 5)
- ENFC-01 section: 8 assertions covering F-EVAL-SUBSHELL, F-NO-TAG-HOOK, F-HOW-TO-FIX-GREP, 5 verifier-check failure-lib entries, and PLAN-01 re-check
- ENFC-02 section: `grep -rL 'tag:' "$HOME/.claude/hooks/"` must return empty
- ENFC-03 section: per-hook `How to fix:` presence check with exempt branch for non-blocking hooks
- ENFC-04 section: per-hook language-binary grep (`node|python|python3|java|kotlin` must be absent)
- Summary line: "Results: N passed, M failed" with `[ "$FAIL" -eq 0 ]` exit gate

## Task Commits

1. **Task 1: Write scripts/replay-giavico-failures.sh** - `e4cec74` (feat)
2. **Fix: Scope tag grep to *.sh (post-checkpoint fix)** - `816f24c` (fix)
3. **Task 2: checkpoint:human-verify** — APPROVED (20 passed, 0 failed, exit 0)

**Plan metadata:** `9ae7438` (docs: complete replay-giavico-failures plan)

## Files Created/Modified
- `scripts/replay-giavico-failures.sh` - Phase 1 done command: 120-line bash script proving all ENFC-01..05 requirements

## Decisions Made
- Called `install.sh` as PRE-STEP (not as prerequisite documentation) so the script is self-contained and always tests the correct installed state
- Delegated F-EVAL-SUBSHELL test to `force-loop-test.sh` rather than duplicating the LOOP-01/LOOP-02 test logic — keeps injection test as single source of truth
- Verified Python verifier-check failures via `[ -f "$ENTRY" ] && grep -q '^enforcement-type: verifier-check$'` — confirms failure-lib data layer exists without requiring runtime execution

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Scope tag grep to *.sh — exclude .gitkeep and GSD .js hooks**
- **Found during:** Post-checkpoint verification
- **Issue:** The `grep -rL 'tag:'` in the ENFC-01 and ENFC-02 sections was hitting non-shell files (.gitkeep, GSD .js hook files) in the hooks directory, causing false failures
- **Fix:** Changed `grep -rL 'tag:' "$HARNESS_DIR/hooks/"` to `grep -rL 'tag:' "$HARNESS_DIR/hooks/"*.sh` to scope the glob to shell scripts only
- **Files modified:** scripts/replay-giavico-failures.sh
- **Verification:** `bash scripts/replay-giavico-failures.sh` — 20 passed, 0 failed, exit 0
- **Committed in:** `816f24c` (fix)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Scoping fix required for correctness; grep was matching unintended files. No scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 1 auto-tasks are complete; `scripts/replay-giavico-failures.sh` is ready to run
- Checkpoint task (human-verify) APPROVED: user ran `bash scripts/replay-giavico-failures.sh` — 20 passed, 0 failed, exit 0
- Phase 1 (ENFC-01..05) is fully closed
- Phase 2 (Context Plane) can begin after checkpoint sign-off

---
*Phase: 01-enforcement-hardening*
*Completed: 2026-06-22*
