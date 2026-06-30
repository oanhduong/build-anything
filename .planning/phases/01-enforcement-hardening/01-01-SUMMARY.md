---
phase: 01-enforcement-hardening
plan: 01
subsystem: infra
tags: [failure-lib, enforcement, verifier-check, hook, model-crutch, architecture]

# Dependency graph
requires:
  - phase: 00-skeleton-giavico-poc
    provides: Phase 0 failure catalogue (eval-subshell, openpyxl-engine, dotenv-module-scope, mock-import-boundary, static-test-fixture, home-scope) — mined from SUMMARY files, STATE.md decisions, and git history
provides:
  - 6 failure-lib/*.md entries covering all Phase 0 failure categories
  - Machine-readable YAML frontmatter per entry (id, tag, enforcement-type, model-version)
  - Self-fix instructions (How to Fix) in every entry
  - Verifier guidance (Verifier Instruction) in all verifier-check entries
  - Data layer for verifier.md runtime failure-lib scan (Plan 02)
affects: [01-02-enforcement-hardening, 01-03-enforcement-hardening, verifier-agent]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "failure-lib entry format: YAML frontmatter (id/tag/enforcement-type/model-version) + structured markdown body (What Failed / Why It Happens / How to Fix / Grep Pattern or Verifier Instruction)"
    - "architecture entries: no model-version field; model-crutch entries: model-version required"
    - "enforcement-type=hook for grep-verifiable architecture rules; enforcement-type=verifier-check for Python-specific patterns"

key-files:
  created:
    - failure-lib/eval-subshell.md
    - failure-lib/static-test-fixture.md
    - failure-lib/openpyxl-engine.md
    - failure-lib/dotenv-module-scope.md
    - failure-lib/mock-import-boundary.md
    - failure-lib/home-scope.md
  modified: []

key-decisions:
  - "failure-lib entry classification: architecture = permanent rule regardless of model; model-crutch = model-version-specific weakness requiring model-version field"
  - "Python-specific failures (openpyxl-engine, dotenv-module-scope, mock-import-boundary) cannot become grep hooks (ENFC-04); all go to failure-lib as verifier-check entries"
  - "F-HOME-SCOPE included as failure-lib entry with enforcement-type=verifier-check despite being test-script-specific; verifier instruction covers bash test scripts that pipe to hooks"
  - "F-STATIC-FIXTURE tagged architecture (not model-crutch) — static fixture rule is permanent and version-independent"

patterns-established:
  - "Pattern: failure-lib entry format — YAML frontmatter + 4-section body (What Failed, Why It Happens, How to Fix, Grep Pattern or Verifier Instruction)"
  - "Pattern: enforcement-type=hook entries carry Grep Pattern section; enforcement-type=verifier-check entries carry Verifier Instruction section"
  - "Pattern: model-crutch entries always carry model-version field; architecture entries never do"

requirements-completed: [ENFC-01]

# Metrics
duration: 2min
completed: 2026-06-22
---

# Phase 1 Plan 01: Enforcement Hardening — Failure Library Population Summary

**6 failure-lib entries covering all Phase 0 failures: 2 architecture (hook + verifier-check) + 4 model-crutch (all verifier-check, all tagged claude-sonnet-4-6)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-06-22T14:12:02Z
- **Completed:** 2026-06-22T14:13:33Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- All 6 Phase 0 failure categories documented in failure-lib/ with machine-readable YAML frontmatter
- Architecture entries (eval-subshell, static-test-fixture) correctly omit model-version field
- Model-crutch entries (openpyxl-engine, dotenv-module-scope, mock-import-boundary, home-scope) all carry model-version: claude-sonnet-4-6
- Every entry has a "How to Fix" section; every verifier-check entry has a "Verifier Instruction" section
- ENFC-01 data layer complete: failure-lib is now the source of truth for all identified Phase 0 failure patterns

## Task Commits

Each task was committed atomically:

1. **Task 1: Write architecture-tagged failure-lib entries (eval-subshell, static-test-fixture)** - `1560a19` (feat)
2. **Task 2: Write model-crutch failure-lib entries (openpyxl-engine, dotenv-module-scope, mock-import-boundary, home-scope)** - `a4b5e23` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `failure-lib/eval-subshell.md` - Architecture entry: subshell eval fix for stop-hook.sh; enforcement-type=hook
- `failure-lib/static-test-fixture.md` - Architecture entry: commit fixtures as static files; enforcement-type=verifier-check
- `failure-lib/openpyxl-engine.md` - Model-crutch entry: pd.read_excel engine='openpyxl' required for .xlsx; enforcement-type=verifier-check
- `failure-lib/dotenv-module-scope.md` - Model-crutch entry: load_dotenv() at module level not just entrypoint; enforcement-type=verifier-check
- `failure-lib/mock-import-boundary.md` - Model-crutch entry: patch at import location not global namespace; enforcement-type=verifier-check
- `failure-lib/home-scope.md` - Model-crutch entry: HOME=val bash -c '...' for pipeline HOME scoping; enforcement-type=verifier-check

## Decisions Made

- F-STATIC-FIXTURE tagged `architecture` not `model-crutch` — the static fixture rule applies permanently regardless of model version
- F-HOME-SCOPE included as failure-lib entry with `verifier-check` enforcement — even though it manifested in a test script, the verifier instruction correctly targets bash test scripts that set HOME and pipe to hooks
- All Python-specific failures classified as `model-crutch` — they are version-specific weaknesses in claude-sonnet-4-6, not permanent architecture rules

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- failure-lib/ data layer complete; Plan 02 can now write the verifier.md runtime scan instruction that references these entries
- Plan 02 also needs to add `# tag:` annotations to all existing hooks (ENFC-02) and "How to fix:" to stop-hook.sh block messages (ENFC-03)
- All 6 ENFC-01 failure entries are in place; replay-giavico-failures.sh (Plan 03) can reference them for injection tests

---
*Phase: 01-enforcement-hardening*
*Completed: 2026-06-22*
