---
phase: 3
slug: self-improve-loop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-23
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash assertion scripts (`[PASS]`/`[FAIL]` convention) — no unit framework |
| **Config file** | none — scripts are self-contained, run directly |
| **Quick run command** | `bash scripts/auto-distill.sh <fixture-trace>` (smoke) |
| **Full suite command** | `bash scripts/retro-e2e-test.sh` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/auto-distill.sh <fixture-trace>` (smoke — script runs, drafts to pending, no crash)
- **After every plan wave:** Run `bash scripts/retro-e2e-test.sh`
- **Before `/gsd:verify-work`:** Full suite must be green; plus regression check: `bash scripts/force-loop-test.sh && bash scripts/no-verify-cmd-test.sh` (stop-hook.sh untouched)
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | SELF-01 | smoke | `bash scripts/auto-distill.sh; echo $?` (expect 2) | ❌ Wave 0 | ⬜ pending |
| 03-01-02 | 01 | 1 | SELF-03 | e2e step | inject hit-count, run distill, assert pending file | ❌ Wave 0 | ⬜ pending |
| 03-01-03 | 01 | 1 | SELF-05 | e2e step | run distill twice, assert no second candidate | ❌ Wave 0 | ⬜ pending |
| 03-01-04 | 01 | 1 | SELF-09 | structural | assert no write to `failure-lib/*.md`; assert no `architecture` candidate | ❌ Wave 0 | ⬜ pending |
| 03-02-01 | 02 | 1 | SELF-02 | e2e step | `grep "^evidence:" failure-lib/pending/*.md` | ❌ Wave 0 | ⬜ pending |
| 03-02-02 | 02 | 1 | SELF-04 | smoke | run `load-lessons.sh` with stdin, grep "pending" in output | ❌ Wave 0 | ⬜ pending |
| 03-02-03 | 02 | 1 | SELF-06 | e2e step | run approve, assert `failure-lib/<id>.md` + `git log` | ❌ Wave 0 | ⬜ pending |
| 03-02-04 | 02 | 1 | SELF-08 | structural | grep SKILL.md calls `auto-distill.sh`; no duplicated logic | ❌ Wave 0 | ⬜ pending |
| 03-03-01 | 03 | 2 | SELF-07 | manual+smoke | `/retro prune` against fixture lib | ❌ Wave 0 | ⬜ pending |
| 03-04-01 | 04 | 2 | SELF-01..09 | e2e | `bash scripts/retro-e2e-test.sh` (all 8 steps) | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/auto-distill.sh` — implements SELF-01/02/03/05/09 distill logic (the unit under test)
- [ ] `scripts/retro-e2e-test.sh` — Phase 3 done command, 8-step sequence per CONTEXT.md
- [ ] `failure-lib/pending/.gitkeep` — keep empty pending dir tracked
- [ ] Synthetic fixtures built inline in e2e test via `mktemp -d` (temp trace file + seeded `lesson-hit-counts.json`) — no permanent fixture files needed
- [ ] Regression guard: confirm `scripts/force-loop-test.sh` + `scripts/no-verify-cmd-test.sh` still pass after `stop-hook.sh` edits

*Wave 0 creates the scripts themselves as part of execution — no pre-existing framework to install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `retro prune` tolerates empty model-crutch set | SELF-07 | Prune UX requires human judgment on which rules to retire | Run `/retro prune` with current failure-lib (0 model-crutch entries), confirm graceful "nothing to prune" output and exit 0 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
