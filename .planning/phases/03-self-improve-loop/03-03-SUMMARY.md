---
phase: 03-self-improve-loop
plan: 03
subsystem: skills
tags: [skill, retro, self-improve, approval-gate, prune]

# Dependency graph
requires:
  - phase: 03-self-improve-loop
    plan: 01
    provides: scripts/auto-distill.sh (distiller engine + arg contract), failure-lib/pending/ queue
  - phase: 02-context-plane
    provides: skill frontmatter + numbered-step conventions (handoff, context-pull)
provides:
  - skills/retro/SKILL.md — /retro approve|run|prune orchestration skill (no distill logic — shells out to auto-distill.sh)
  - install.sh comments encoding skills-glob + pending-exclusion intent
affects: [03-04 e2e self-improve test consumes /retro run + approve flow]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Thin orchestration skill: /retro holds no distill logic, shells out to the single-source-of-truth script (SELF-08)"
    - "Human approval gate: candidates only enter failure-lib/ via /retro approve, never automatically (SELF-09)"
    - "Empty-set tolerance: /retro prune exits 0 with a message when zero model-crutch rules exist"

key-files:
  created:
    - skills/retro/SKILL.md
  modified:
    - install.sh

key-decisions:
  - "retro skill does NOT set disable-model-invocation: true — approve/prune are interactive review loops requiring model reasoning (unlike handoff's direct-action)"
  - "install.sh needs no functional change — skills/*/ glob already installs retro; only two clarifying comments added to encode intent"
  - "Approved candidates are moved (not converted) to failure-lib/ — file is already in live format; evidence: line retained for provenance (SELF-06, no format conversion)"

requirements-completed: [SELF-06, SELF-07, SELF-08, SELF-09]

# Metrics
duration: 1min
completed: 2026-06-23
---

# Phase 3 Plan 03: /retro Skill Summary

**The `/retro` skill — a thin orchestration layer over `auto-distill.sh` with three subcommands (`run`→distill, `approve`→move+commit/discard, `prune`→retire stale model-crutch rules) — implements the human approval gate (SELF-09) and manual override path (SELF-08) while holding zero distillation logic of its own; install.sh installs it via the existing skills glob.**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-06-23T11:43:44Z
- **Completed:** 2026-06-23T11:44:40Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `skills/retro/SKILL.md` — three clearly headed subcommand sections, all instructions-to-Claude (no executable distill code)
  - `run <trace-file>`: errors `trace required` with no arg (SELF-01 propagated), else shells out to `auto-distill.sh` — the same script the Stop hook uses (SELF-08)
  - `approve`: batch-reviews `pending/*.md` with per-candidate `y`/`n`/`all`, moves approved to `failure-lib/` and commits to `~/.claude` via `git -C`, discards rejected (SELF-06, SELF-09)
  - `prune`: finds `model-crutch`-tagged rules, compares model-version token, retires stale ones per human approval, and tolerates the empty set gracefully (SELF-07)
- `install.sh` confirmed to install the retro skill with zero functional change (the `skills/*/` glob already covers it); two clarifying comments added documenting the skills-glob coverage and the deliberate flat `failure-lib/*.md` glob that keeps the runtime `pending/` queue out of the install

## Task Commits

Each task was committed atomically:

1. **Task 1: Write skills/retro/SKILL.md with approve | run | prune subcommands** - `4c10b69` (feat)
2. **Task 2: Confirm install.sh installs retro skill and keeps pending/ out** - `5de0132` (chore)

## Files Created/Modified
- `skills/retro/SKILL.md` - /retro orchestration skill; run/approve/prune; no distill logic, shells out to auto-distill.sh
- `install.sh` - Added two intent-encoding comments (skills glob covers retro; flat failure-lib glob excludes pending/)

## Decisions Made
- retro skill omits `disable-model-invocation: true` — approve/prune are interactive review loops needing model reasoning, unlike the handoff direct-write skill
- install.sh required no functional edit: the `skills/*/` glob already installs `skills/retro/`, and the flat `failure-lib/*.md` glob already excludes `pending/`; only comments were added
- Approved candidates are moved, not converted — they are already in live failure-lib format; the `evidence:` line is retained for provenance (SELF-06 needs no conversion)

## Deviations from Plan

None - plan executed exactly as written. Both tasks passed their automated verify and full acceptance criteria on first implementation. (As anticipated by the plan, install.sh needed no functional change — only the two clarifying comments.)

## Issues Encountered
- None. All acceptance criteria passed on first pass.

## User Setup Required
None - no external service configuration required. Run `bash install.sh` to copy the retro skill into `~/.claude/skills/retro/` (or restart Claude Code if `~/.claude/skills/` did not previously exist).

## Next Phase Readiness
- `/retro run` + `/retro approve` flow is ready for Plan 04's e2e self-improve test, which exercises distill → pending → approve → committed-lesson end-to-end.
- No blockers.

---
*Phase: 03-self-improve-loop*
*Completed: 2026-06-23*

## Self-Check: PASSED
- FOUND: skills/retro/SKILL.md
- FOUND: install.sh (modified — comments added)
- FOUND: commit 4c10b69 (Task 1)
- FOUND: commit 5de0132 (Task 2)
