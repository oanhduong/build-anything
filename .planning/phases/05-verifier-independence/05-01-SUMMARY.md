---
phase: 05-verifier-independence
plan: 01
subsystem: testing
tags: [tdd, verifier, verdicts, stop-hook, stub-reject, bash, hooks]

# Dependency graph
requires:
  - phase: 00-04-complete
    provides: stop-hook.sh, stub-reject.sh, common.sh, test-enforcement.sh infrastructure
provides:
  - 6-test TDD scaffold (test-verifier-independence.sh) covering Binary A, Binary B, VERIF-01/02/03
  - verdicts-capture.sh scaffold (Wave 1 fill-in placeholder, correct structure)
  - NON_BLOCKING exemption for verdicts-capture.sh in test-enforcement.sh
affects: [05-02, 05-03, 05-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TDD anchor: write failing tests first (Wave 0), then implement (Wave 1/2)"
    - "Mock JSON injection pattern for stop-hook and stub-reject direct invocation"
    - "Scaffold pattern: correct structure exits 0 so ENFC checks pass before implementation"

key-files:
  created:
    - scripts/test-verifier-independence.sh
    - hooks/verdicts-capture.sh
  modified:
    - scripts/test-enforcement.sh

key-decisions:
  - "Tests are intentionally RED at Wave 0 — 5 of 6 fail; VERIF-01 (pass) is GREEN for correct reason (VERIFY_CMD passes)"
  - "verdicts-capture.sh scaffold exits 0 unconditionally so ENFC-02/03/04 pass before Wave 1 fills in the implementation"
  - "NON_BLOCKING list exemption for verdicts-capture.sh added pre-install so test-enforcement.sh stays green"

patterns-established:
  - "Binary A/B test pattern: mount tmp dir, write SPEC.md or mock Write call, invoke hook with mock JSON, assert exit code + stderr"
  - "VERIF-01/03 use stop-hook directly via HARNESS_DIR variable, not installed path"

requirements-completed: [VERIF-01, VERIF-02, VERIF-03]

# Metrics
duration: 3min
completed: 2026-07-01
---

# Phase 5 Plan 01: Verifier Independence Test Scaffold Summary

**6-test TDD anchor for verifier independence: Binary A (SPEC+no-VERDICTS exits 2), Binary B (write-block on VERDICTS.md), VERIF-01 pass/fail, VERIF-02 capture, VERIF-03 criterion verbatim reporting**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-07-01T03:44:46Z
- **Completed:** 2026-07-01T03:47:08Z
- **Tasks:** 2 of 2
- **Files modified:** 3

## Accomplishments
- Created `scripts/test-verifier-independence.sh` with 6 test cases — syntax-clean, executable, all assertion strings load-bearing and verbatim as specified
- Created `hooks/verdicts-capture.sh` scaffold with correct PostToolUse structure (tag: architecture, set -euo pipefail, source common.sh, How to fix: N/A) — ENFC-02/03/04 ready
- Updated `scripts/test-enforcement.sh` NON_BLOCKING list at line 93 to include `verdicts-capture.sh`
- Wave 0 verification confirmed: 5 tests RED (Binary A, Binary B, VERIF-02, VERIF-01-fail, VERIF-03), 1 GREEN (VERIF-01-pass) — exactly the expected state

## Task Commits

Each task was committed atomically:

1. **Task 1: Create test-verifier-independence.sh with 6 test cases** - `19e787a7` (feat)
2. **Task 2: Create verdicts-capture.sh scaffold and add to NON_BLOCKING list** - `d060f35a` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified
- `scripts/test-verifier-independence.sh` — 6-test TDD anchor for Phase 5 binary exit criteria
- `hooks/verdicts-capture.sh` — PostToolUse scaffold; Wave 1 fill-in placeholder
- `scripts/test-enforcement.sh` — Line 93 NON_BLOCKING list extended with verdicts-capture.sh

## Decisions Made
- Tests are intentionally RED at Wave 0. This is the TDD anchor pattern: the test file defines what must be true after Wave 1/2 implementations make them GREEN.
- `verdicts-capture.sh` scaffold exits 0 unconditionally so ENFC-02/03/04 enforcement tests pass even before Wave 1 installs the real implementation.
- NON_BLOCKING exemption added pre-install because verdicts-capture.sh is a PostToolUse hook with no blocking calls.

## Deviations from Plan

### Criterion Observation (not an auto-fix)

The acceptance criterion for Task 2 states:
```
git diff scripts/test-enforcement.sh | grep "^[-+]" | grep -v "verdicts-capture.sh" | grep -v "^---\|^+++"
```
outputs nothing. However, the `-` (removed) line of the targeted NON_BLOCKING change doesn't contain `verdicts-capture.sh` (it's the old value being replaced), so it always appears in this output. The criterion's intent — ensuring no other lines were modified — is satisfied: only the NON_BLOCKING line changed. This is a false-positive in the criterion's regex design, not an error in execution.

None - plan executed exactly as written (no auto-fixes required, criterion observation only).

## Issues Encountered
None — both tasks executed cleanly on first attempt.

## Next Phase Readiness
- `scripts/test-verifier-independence.sh` is the RED TDD anchor for 05-02, 05-03, 05-04
- 05-02 (verdicts-capture.sh implementation) will make VERIF-02 GREEN
- 05-03 (stop-hook SPEC.md integration) will make Binary A, VERIF-01-fail, VERIF-03 GREEN
- 05-04 (stub-reject VERDICTS.md block) will make Binary B GREEN
- No blockers for Wave 1 start

---
*Phase: 05-verifier-independence*
*Completed: 2026-07-01*
