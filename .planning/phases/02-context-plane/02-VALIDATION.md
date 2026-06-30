---
phase: 2
slug: context-plane
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-23
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash (no test framework — same as Phase 0/1) |
| **Config file** | none — standalone bash scripts |
| **Quick run command** | `bash scripts/context-reset-test.sh` |
| **Full suite command** | `bash scripts/context-reset-test.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/context-reset-test.sh`
- **After every plan wave:** Run `bash scripts/context-reset-test.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | CTXP-01 | unit (injection) | `echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"Updated: 2026-06-23"}}' \| bash hooks/claude-md-audit.sh; [ $? -eq 2 ]` | ❌ W0 | ⬜ pending |
| 2-01-02 | 01 | 1 | CTXP-02 | integration | `bash scripts/context-reset-test.sh` | ❌ W0 | ⬜ pending |
| 2-01-03 | 01 | 1 | CTXP-03 | structural | `test -f ~/.claude/skills/context-pull/SKILL.md && grep -q 'search' ~/.claude/skills/context-pull/SKILL.md` | ❌ W0 | ⬜ pending |
| 2-01-04 | 01 | 1 | CTXP-04 | e2e | `bash scripts/context-reset-test.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/context-reset-test.sh` — covers CTXP-02, CTXP-04 (main done command); CTXP-01 hook injection check co-located as additional check block following replay-giavico-failures.sh pattern
- [ ] `hooks/claude-md-audit.sh` — CTXP-01 enforcement hook (must exist before its injection test can run)
- [ ] `~/.claude/skills/context-pull/SKILL.md` (installed via install.sh) — CTXP-03 skill file
- [ ] `~/.claude/skills/handoff/SKILL.md` (installed via install.sh) — CTXP-02 manual override skill

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Skill live-reload after install.sh on existing session | CTXP-03 | Claude Code skill reload behavior not fully scriptable | After `./install.sh`, verify `/context-pull search test` responds in same session |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
