---
phase: 06-spec-gate
plan: "01"
subsystem: spec-gate
tags: [tdd-red-anchor, spec-gate, test-harness, skill-scaffold]
dependency_graph:
  requires: []
  provides: [test-spec-gate-sh, spec-skill-scaffold]
  affects: [scripts/test-spec-gate.sh, skills/spec/SKILL.md]
tech_stack:
  added: []
  patterns: [bash-test-harness, shasum-a256-canonical-pipeline, mktemp-mock-pattern, skill-frontmatter]
key_files:
  created:
    - scripts/test-spec-gate.sh
    - skills/spec/SKILL.md
  modified: []
decisions:
  - CANONICAL token pipeline (awk+sed+shasum -a 256) used verbatim in Binary C/D to guard normalization consistency (Pitfall 2)
  - VERIFY_CMD set to exit 0 in every test PROGRESS.md setup to prevent PLAN-01 from intercepting before the spec gate (Pitfall 7)
  - Binary D stays GREEN at wave 0: current stub-reject exits 0 for valid content, confirming happy-path baseline
  - Binary E stays GREEN at wave 0: .progress/SPEC.md target path not blocked by existing VERDICTS.md check
  - skills/spec/SKILL.md scaffold defers full interview + token logic to wave 2 (plan 03)
metrics:
  duration: "2m"
  completed_date: "2026-07-01"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
requirements_satisfied: [GATE-02, GATE-03]
---

# Phase 6 Plan 01: Spec Gate TDD Red Anchor Summary

TDD RED anchor (Binary A/B/C/D/E) for the spec gate plus /spec skill scaffold — three assertions fail against unmodified stub-reject.sh, two stay GREEN, overall exits non-zero.

## What Was Built

### Task 1: scripts/test-spec-gate.sh (RED anchor)

Five binary assertions follow the test-verifier-independence.sh harness pattern exactly (set -uo pipefail, HARNESS_DIR, STUB_REJECT, counter helpers, mktemp+MOCK+cd pattern):

- Binary A: stub-reject must exit 2 with "SPEC.md absent" when .progress/SPEC.md does not exist
- Binary B: stub-reject must exit 2 with "SPEC.md unconfirmed" when SPEC.md has criteria but no confirm-token field
- Binary C: stub-reject must exit 2 with "SPEC.md token invalid" when a valid token exists but criteria text was tampered
- Binary D: stub-reject must exit 0 for a SPEC.md with a correctly computed token (normalization-consistency guard, Pitfall 2)
- Binary E: stub-reject must exit 0 when the Write target IS .progress/SPEC.md (self-write exemption, Pitfall 1)

Every test case sets VERIFY_CMD: exit 0 in its PROGRESS.md so PLAN-01 cannot intercept before the not-yet-implemented spec gate (Pitfall 7). Binary C and D compute the confirm-token using the CANONICAL pipeline (awk+sed+shasum -a 256) on the written file, then sed-patch the PENDING placeholder.

Wave 0 outcome: Binary A/B/C fail (exit 0 from unmodified stub-reject vs expected exit 2), D/E stay green — overall exits non-zero (RED).

### Task 2: skills/spec/SKILL.md (scaffold)

Valid SKILL.md with name: spec frontmatter. Prose body describes the confirm-token gate purpose and names the six-step flow (3 risk questions, propose draft, wait for literal confirm, compute shasum -a 256, write SPEC.md, derive VERIFY_CMD) that wave 2 (plan 03) will implement. No stub markers present. install.sh deploys via skills/ glob automatically.

## Verification Results

| Check | Outcome |
|-------|---------|
| bash scripts/test-spec-gate.sh exits non-zero | OK (exit 1, 3 failures) |
| Binary A/B/C fail against unmodified stub-reject | OK |
| Binary D/E remain green | OK |
| bash scripts/test-enforcement.sh | OK (32/32) |
| bash scripts/test-verifier-independence.sh | OK (6/6) |
| skills/spec/SKILL.md has name: spec | OK |
| No stub markers in SKILL.md | OK (grep -cE returns 0) |

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: test-spec-gate.sh | e8cc58d8 | scripts/test-spec-gate.sh (+187 lines) |
| Task 2: skills/spec/SKILL.md | 1e5a23b1 | skills/spec/SKILL.md (+28 lines) |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: OK
