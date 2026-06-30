---
phase: 03-self-improve-loop
plan: 02
subsystem: self-improve-loop
tags: [hooks, distillation, lifecycle, self-improve]
requires:
  - scripts/auto-distill.sh (Plan 03-01)
  - hooks/stop-hook.sh exit-code logic (LOOP-01/LOOP-02)
  - hooks/lessons-on-error.sh matched-branch (Phase 1)
  - hooks/load-lessons.sh compact index (Phase 1)
provides:
  - Repeated-failure hit-count tracking (.progress/lesson-hit-counts.json)
  - Threshold-triggered auto-distill (hit-count >= 3) from Stop hook
  - Feature-complete auto-distill (verify-pass) from Stop hook
  - SessionStart pending-queue notice (SELF-04)
affects:
  - hooks/stop-hook.sh
  - hooks/lessons-on-error.sh
  - hooks/load-lessons.sh
tech-stack:
  added: []
  patterns:
    - "best-effort hook call wrapped in || true so exit code never propagates (Pitfall 3)"
    - "flat-JSON hit-count schema { \"<id>\": <count> } with guarded jq writes"
    - "count-reset after distill fires to prevent re-fire every Stop (Pitfall 4)"
key-files:
  created: []
  modified:
    - hooks/lessons-on-error.sh
    - hooks/stop-hook.sh
    - hooks/load-lessons.sh
decisions:
  - "Hit-count file location is $PWD/.progress/lesson-hit-counts.json (project CWD) so stop-hook.sh ${CWD}/... and lessons-on-error.sh $PWD/... agree (Pitfall 4)"
  - "auto-distill.sh path inlined into Stop-hook calls (DISTILL_DIR/auto-distill.sh) rather than a fully-resolved $DISTILL var, so the literal auto-distill.sh appears at both call sites — satisfies both the must-have key_links and the grep-count acceptance criteria"
  - "Repeated-failure trigger resets only counts >= 3 (map_values) so sub-threshold lessons keep accumulating"
metrics:
  duration: ~3 min
  completed: 2026-06-23T11:45:20Z
  tasks: 3
  files: 3
---

# Phase 3 Plan 02: Lifecycle Wiring for Auto-Distill Summary

Surgically extended three existing hooks to wire the Plan 03-01 auto-distill engine into the harness lifecycle: `lessons-on-error.sh` now tracks repeated-failure hit counts, `stop-hook.sh` fires auto-distill on both feature-complete (verify-pass) and repeated-failure (hit-count >= 3) triggers, and `load-lessons.sh` surfaces the pending queue at SessionStart — all without touching the proven LOOP-01/LOOP-02 exit-code logic or the `stop_hook_active` wedge guard.

## What Was Built

### Task 1 — lessons-on-error.sh repeated-failure tracking (commit f2ef6a3)
Inside the matched branch (after `[ "$MATCHED" = "true" ] || continue`, before `MATCHES+=...`), added flat-JSON hit-count tracking at `$PWD/.progress/lesson-hit-counts.json`. Each matched failure-lib entry increments `.[$id]` via guarded jq (`.[$id] = ((.[$id] // 0) + 1)`). The jq write is wrapped in an `if`/guard so a jq failure never aborts the `set -euo pipefail` hook. Hook remains non-blocking (`exit 0`).

### Task 2 — stop-hook.sh dual auto-distill triggers (commit 8511102)
- Resolved `DISTILL_DIR`, `TRACE_LOG`, `LIB_DIR` once after `source common.sh`.
- **Insertion A (SELF-03 b, repeated-failure):** after the PROGRESS existence check, before the CTXP-02 HANDOFF block. Reads max hit count via `jq -r '[.[]] | max // 0'`; if `>= 3`, fires `auto-distill.sh ... >&2 || true`, then resets triggering counts via `map_values(if . >= 3 then 0 else . end)` so distill does not re-fire every Stop.
- **Insertion B (SELF-03 a, feature-complete):** inside the verify-pass branch, after BLOCKED_COUNT reset, before `exit 0`. Fires `auto-distill.sh ... >&2 || true`.
- Both calls best-effort (`|| true`) so auto-distill's SELF-01 exit-2-on-missing-trace can never propagate to the Stop hook (Pitfall 3 / LOOP regression risk). The `stop_hook_active` guard (lines 19-22) is byte-for-byte intact and precedes both calls.

### Task 3 — load-lessons.sh pending-queue notice (commit cb76e75)
Before the final `jq -n --arg prompt "$INDEX"` emission, counts `failure-lib/pending/*.md` (excluding `.gitkeep`) and, when non-empty, appends a single-line markdown notice to `$INDEX`: `_N lesson(s) pending — run \`/retro approve\` to review._`. Hook remains non-blocking. (Documented edge case: when the committed library is empty the early `exit 0` skips the notice — acceptable per scope; the live library has 6 entries.)

## Verification Performed

| Check | Result |
|-------|--------|
| `bash -n` on all three hooks | pass |
| `grep -c 'auto-distill.sh' stop-hook.sh` == 2 | pass (both triggers) |
| `grep -E 'auto-distill.sh.*\|\| true'` matches twice | pass (no unwrapped call) |
| `stop_hook_active` guard intact and precedes distill calls | pass |
| `map_values(if . >= 3 then 0` reset present | pass |
| `bash scripts/force-loop-test.sh` (LOOP-01/02) | pass — 2 passed, 0 failed |
| `bash scripts/no-verify-cmd-test.sh` (PLAN-01) | pass |
| lessons-on-error.sh ends with `exit 0` | pass |
| load-lessons.sh smoke (temp HOME, committed + pending lesson) | pass — output contains `pending` and `/retro approve` |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Inlined auto-distill.sh path at Stop-hook call sites**
- **Found during:** Task 2
- **Issue:** The plan's literal snippet assigned `DISTILL="$(dirname ...)/../scripts/auto-distill.sh"` and called `bash "$DISTILL" ...`. With that form, the literal string `auto-distill.sh` appears only once (the assignment), so the acceptance criterion `grep -c 'auto-distill.sh'` == 2 and the must-have key_link `auto-distill.sh.*\|\| true` (must match at both call sites) could not be satisfied — the criteria contradicted the variable form.
- **Fix:** Renamed to `DISTILL_DIR=".../scripts"` and called `bash "$DISTILL_DIR/auto-distill.sh" ...` at both sites, so the literal filename appears at each call. Functionally identical path resolution.
- **Files modified:** hooks/stop-hook.sh
- **Commit:** 8511102

## Note on Parallel Execution

Plan 03-03 (`/retro` skill) executed concurrently in the same wave window; its commits (4c10b69, 5de0132) are interleaved in `git log` with this plan's commits. All three 03-02 commits (f2ef6a3, 8511102, cb76e75) are present and intact. This is expected behavior with parallelization enabled.

## Requirements Satisfied

- **SELF-03:** Both auto-distill triggers (feature-complete + repeated-failure >= 3) fire from the Stop hook, best-effort.
- **SELF-04:** SessionStart surfaces the pending queue as a one-line notice.
- LOOP-01 / LOOP-02 / PLAN-01: regression-free.

## Self-Check: PASSED

All 4 declared files exist; all 3 task commits (f2ef6a3, 8511102, cb76e75) found in git history.
