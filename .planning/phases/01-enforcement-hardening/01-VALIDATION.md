---
phase: 1
slug: enforcement-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-22
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash scripts (no test framework — consistent with Phase 0 approach) |
| **Config file** | none |
| **Quick run command** | `bash scripts/replay-giavico-failures.sh` |
| **Full suite command** | `bash scripts/replay-giavico-failures.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/replay-giavico-failures.sh` (once it exists; prior tasks use per-task grep checks)
- **After every plan wave:** Run `bash scripts/replay-giavico-failures.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | ENFC-01 | grep | `ls failure-lib/*.md \| wc -l` ≥ 6 | ❌ Wave 0 | ⬜ pending |
| 1-01-02 | 01 | 0 | ENFC-02 | grep | `grep -rL 'tag:' ~/.claude/hooks/` returns empty | ❌ Wave 0 | ⬜ pending |
| 1-01-03 | 01 | 0 | ENFC-03 | grep | `for f in ~/.claude/hooks/*.sh; do grep -q 'How to fix:' "$f" \|\| echo FAIL; done` | ❌ Wave 0 | ⬜ pending |
| 1-01-04 | 01 | 0 | ENFC-04 | grep | `grep -rE '\b(node\|python\|java\|kotlin)\b' ~/.claude/hooks/` returns empty | ❌ Wave 0 | ⬜ pending |
| 1-01-05 | 01 | 0 | ENFC-05 | integration | `bash scripts/replay-giavico-failures.sh` exits 0 | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `failure-lib/eval-subshell.md` — covers ENFC-01 (F-EVAL-SUBSHELL)
- [ ] `failure-lib/openpyxl-engine.md` — covers ENFC-01 (F-OPENPYXL-ENGINE)
- [ ] `failure-lib/dotenv-module-scope.md` — covers ENFC-01 (F-DOTENV-SCOPE)
- [ ] `failure-lib/mock-import-boundary.md` — covers ENFC-01 (F-MOCK-IMPORT-BOUNDARY)
- [ ] `failure-lib/static-test-fixture.md` — covers ENFC-01 (F-STATIC-FIXTURE)
- [ ] `failure-lib/home-scope.md` — covers ENFC-01 (F-HOME-SCOPE)
- [ ] Updated `hooks/stub-reject.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `hooks/progress-after-edit.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `hooks/trace.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `hooks/stop-hook.sh` — add `# tag: architecture` + "How to fix:" in block messages (ENFC-02, ENFC-03)
- [ ] Updated `hooks/common.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `agents/verifier.md` — add failure-lib runtime scan instruction (ENFC-01 verifier-check path)
- [ ] `scripts/replay-giavico-failures.sh` — ENFC-05 done command (integration test covering all ENFC-01..04)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| failure-lib entries document self-fix instructions clearly | ENFC-03 | Prose quality check | Read each failure-lib/*.md body; verify "How to fix:" is present and actionable |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
