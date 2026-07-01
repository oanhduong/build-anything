---
phase: 05-verifier-independence
plan: 03
subsystem: infra
tags: [bash, stop-hook, acceptance-criteria, verdicts, two-gate, awk]

# Dependency graph
requires:
  - phase: 05-verifier-independence/05-02
    provides: "verdict capture pipeline: verdicts-capture.sh, VERDICTS.md schema, stub-reject VERDICTS.md protection"
provides:
  - "stop-hook.sh two-gate verification: VERIFY_CMD pre-filter (Gate 1) + per-criterion VERDICTS.md check (Gate 2)"
  - "Per-criterion status listing in stderr with last-match awk semantics"
  - "Backward-compatible: SPEC.md-absent sessions fall through to VERIFY_CMD-only behavior"
affects: [05-verifier-independence, all future phases using stop-hook.sh]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-gate stop: Gate 1 = VERIFY_CMD (mechanical pre-filter), Gate 2 = per-criterion VERDICTS.md check"
    - "SPEC.md ## Acceptance Criteria section extracted via awk between section headers, sed-stripped of list prefix"
    - "last-match awk semantics for VERDICTS.md criterion lookup (most recent verdict wins on duplicate blocks)"
    - "BLOCKED_COUNT incremented on criterion-gate failure — both gate failures count toward ceiling"
    - "auto-distill.sh fires only inside all-PASS branch (moved from VERIFY_CMD-pass branch)"

key-files:
  created: []
  modified:
    - hooks/stop-hook.sh

key-decisions:
  - "while-read process-substitution instead of mapfile for bash 3.2 compatibility (macOS)"
  - "last-match awk (via last_verdict variable updated on each block, printed at END) handles duplicate verdict blocks"
  - "BLOCKED_COUNT incremented on criterion-gate failure — any blocked stop counts toward ceiling"
  - "SPEC.md-absent path exits 0 preserving backward-compat for pre-Phase-5 sessions"

patterns-established:
  - "Gate 2 only activates when SPEC.md exists with ## Acceptance Criteria — graceful fallback otherwise"
  - "per-criterion stderr listing: [PASS]/[FAIL]/[not yet verified] prefix for each criterion text verbatim"

requirements-completed: [VERIF-01, VERIF-03]

# Metrics
duration: 2min
completed: 2026-07-01
---

# Phase 05 Plan 03: Two-Gate Verification Flow Summary

**stop-hook.sh augmented with Gate 2: per-criterion VERDICTS.md check after VERIFY_CMD pre-filter, with last-match awk semantics and backward-compatible SPEC.md-absent fallback**

## Performance

- **Duration:** 2 min
- **Started:** 2026-07-01T03:59:46Z
- **Completed:** 2026-07-01T04:01:28Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Replaced single VERIFY_CMD exit logic with two-gate flow: Gate 1 (VERIFY_CMD pre-filter) + Gate 2 (per-criterion VERDICTS.md check)
- All 6 tests in test-verifier-independence.sh pass GREEN, including Binary A, VERIF-01 (fail), and VERIF-03
- LOOP-01/LOOP-02 (force-loop-test.sh) and PLAN-01 (no-verify-cmd-test.sh) unbroken

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace VERIFY_CMD success branch with two-gate flow** - `dad14d7e` (feat)

**Plan metadata:** (see final commit below)

## Files Created/Modified
- `hooks/stop-hook.sh` - Two-gate verification: Gate 1 VERIFY_CMD pre-filter + Gate 2 per-criterion VERDICTS.md check

## Decisions Made
- Used `while IFS= read -r line` + process substitution instead of `mapfile` for bash 3.2 compatibility
- Used last-match awk (`last_verdict` updated on each block, printed at END) so the most recent verifier run wins on duplicate criterion blocks in VERDICTS.md
- BLOCKED_COUNT incremented on criterion-gate failure (not just VERIFY_CMD failure) — any blocked stop counts toward ceiling
- auto-distill.sh moved inside the all-PASS branch only (was in VERIFY_CMD-pass branch before; must not fire unless task is truly complete)
- SPEC.md-absent (or no Acceptance Criteria section) exits 0 — backward-compat for sessions that predate Phase 5

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- stop-hook.sh now enforces criterion-gate: generator cannot self-grade by controlling VERIFY_CMD alone
- VERIF-01 and VERIF-03 requirements satisfied
- Phase 5 plan 04 can proceed: full suite (test-enforcement.sh) verification and phase closeout

---
*Phase: 05-verifier-independence*
*Completed: 2026-07-01*
