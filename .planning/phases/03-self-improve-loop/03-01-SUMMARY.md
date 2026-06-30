---
phase: 03-self-improve-loop
plan: 01
subsystem: infra
tags: [bash, failure-lib, trace, distillation, self-improve]

# Dependency graph
requires:
  - phase: 00-skeleton-giavico-poc
    provides: hooks/common.sh block()/emit(), trace.log format (TIMESTAMP TOOL TARGET EXIT_CODE)
  - phase: 01-enforcement-hardening
    provides: failure-lib frontmatter format and classification (architecture vs model-crutch)
provides:
  - scripts/auto-distill.sh — standalone trace-grounded lesson distiller (engine for SELF-01/02/03/05/09)
  - failure-lib/pending/ — runtime candidate queue directory
  - .gitignore entry for ephemeral .progress/lesson-hit-counts.json
affects: [03-02 Stop-hook threshold path, 03-03 /retro skill, 03-04 e2e self-improve test]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Trace-grounded distillation: candidates carry verbatim trace evidence (SELF-02)"
    - "Single source of truth: one script shelled out to by both Stop-hook and /retro"
    - "Pending-queue gating: drafts land in pending/ until human approval, never failure-lib/ directly"

key-files:
  created:
    - scripts/auto-distill.sh
    - failure-lib/pending/.gitkeep
  modified:
    - .gitignore

key-decisions:
  - "Candidate id derived from TOOL+TARGET tokens (lowercased, kebab-cased, auto- prefix, ~50 char cap) for stable dedup"
  - "Dedup greps failure-lib/*.md only (committed lessons) plus a pending/ existence guard against intra/inter-run stacking"
  - "Default model-crutch version string claude-sonnet-4-6, overridable via CLAUDE_MODEL env var"
  - "Empty/clean trace emits '0 new candidates' and exits 0 — only missing/unreadable arg blocks (Pitfall 5)"

patterns-established:
  - "set -uo pipefail (NOT set -e) in trace-scanning scripts so grep no-match (rc=1) does not abort"
  - "evidence: frontmatter line copies a real trace entry verbatim as the grounding proof for a candidate lesson"

requirements-completed: [SELF-01, SELF-02, SELF-03, SELF-05, SELF-09]

# Metrics
duration: 2min
completed: 2026-06-23
---

# Phase 3 Plan 01: auto-distill.sh Distiller Engine Summary

**Standalone trace-grounded lesson distiller that blocks without a trace (SELF-01), drafts evidence-bearing model-crutch candidates into failure-lib/pending/ only (SELF-02/09), and dedups by id against committed failure-lib lessons (SELF-05) — fully language-agnostic (ENFC-04).**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-23T11:39:12Z
- **Completed:** 2026-06-23T11:41:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `scripts/auto-distill.sh` — the Phase 3 distillation engine; single source of truth both the Stop-hook threshold path (Plan 02) and `/retro run` (Plan 03) will shell out to
- Trace scanning that selects non-zero EXIT_CODE lines, derives stable candidate ids from TOOL+TARGET, and drafts mirror-format candidate `.md` files with a verbatim `evidence:` trace line
- Two-layer dedup: greps committed `failure-lib/*.md` by `^id:` and guards against re-drafting an existing `pending/` candidate
- `failure-lib/pending/` queue directory (tracked via `.gitkeep`) and gitignored runtime hit-count file

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold pending queue dir and gitignore runtime hit-count** - `ed2f0a7` (chore)
2. **Task 2: Build scripts/auto-distill.sh — the trace-grounded distiller** - `3a2977a` (feat)

## Files Created/Modified
- `scripts/auto-distill.sh` - Trace-grounded distiller; SELF-01/02/03/05/09 logic, architecture-tagged infra
- `failure-lib/pending/.gitkeep` - Keeps the runtime candidate queue tracked when empty
- `.gitignore` - Ignores ephemeral `.progress/lesson-hit-counts.json`

## Decisions Made
- Candidate id = `auto-` + kebab-cased lowercased TOOL+TARGET, capped ~50 chars, for deterministic dedup across runs
- Dedup scope is committed `failure-lib/*.md` only (never `pending/` for the committed check), plus a separate `pending/` existence guard to avoid stacking duplicates within or across runs before approval
- Default model-version token `claude-sonnet-4-6`, overridable via `CLAUDE_MODEL` env var, keeping candidates always model-crutch tagged (SELF-09)
- Empty/clean trace is a graceful no-op (exit 0); only a missing/unreadable trace argument blocks (exit 2)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reworded ENFC-04 header comment to satisfy the no-interpreter grep check**
- **Found during:** Task 2 (verification)
- **Issue:** The acceptance grep `! grep -qE '(^|[^a-z])(python|node|java|kotlin) '` flagged the script's own header comment line `# ENFC-04: ... no python/node/java/kotlin invocations.` (the `kotlin ` substring matched). No actual interpreter was invoked — it was a false positive on documentation text.
- **Fix:** Reworded the comment to `# ENFC-04: language-agnostic — no per-stack interpreter/runtime invocations.`, removing the literal language tokens while preserving intent.
- **Files modified:** scripts/auto-distill.sh
- **Verification:** Re-ran the ENFC-04 grep — now passes (no match).
- **Committed in:** `3a2977a` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Cosmetic comment wording only — no behavior change, no scope creep. All other acceptance criteria passed on first implementation.

## Issues Encountered
- None beyond the deviation above. SELF-01/02/05/09 all passed on first smoke run; empty-trace and committed-failure-lib dedup paths verified explicitly.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Distiller engine is the foundation for the remaining Phase 3 plans:
  - Plan 02 wires the Stop-hook threshold to call `auto-distill.sh`
  - Plan 03 builds the `/retro` skill (run/approve) that consumes `pending/`
  - Plan 04 is the e2e self-improve test that greps `^evidence:` on drafted candidates
- No blockers.

---
*Phase: 03-self-improve-loop*
*Completed: 2026-06-23*

## Self-Check: PASSED
- FOUND: scripts/auto-distill.sh
- FOUND: failure-lib/pending/.gitkeep
- FOUND: .planning/phases/03-self-improve-loop/03-01-SUMMARY.md
- FOUND: .gitignore entry (.progress/lesson-hit-counts.json)
- FOUND: commit ed2f0a7 (Task 1)
- FOUND: commit 3a2977a (Task 2)
