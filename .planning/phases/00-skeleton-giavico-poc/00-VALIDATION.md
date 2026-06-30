---
phase: 0
slug: skeleton-giavico-poc
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-22
---

# Phase 0 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pytest 7.4.3 (installed) + bash smoke scripts |
| **Config file** | `giavico/pytest.ini` — Wave 0 gap (does not exist yet) |
| **Quick run command** | `bash preflight.sh` |
| **Full suite command** | `bash preflight.sh && bash scripts/no-verify-cmd-test.sh && bash scripts/force-loop-test.sh && cd ~/Work/mine/giavico && python -m pytest tests/ -v` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash preflight.sh`
- **After every plan wave:** Run `bash preflight.sh && bash scripts/no-verify-cmd-test.sh && bash scripts/force-loop-test.sh && cd ~/Work/mine/giavico && python -m pytest tests/ -v`
- **Before `/gsd:verify-work`:** Full suite must be green + GIAV-05 human sign-off recorded in PROGRESS
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 00-01-xx | 01 | 1 | SKEL-06 | smoke | `grep -q 'block()' ~/.claude/hooks/common.sh && grep -q 'emit()' ~/.claude/hooks/common.sh` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-03a | smoke | `bash scripts/test-exit-code-2.sh` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-03b | smoke | `bash scripts/test-stderr-template.sh` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-03c | smoke | `bash -c 'for f in ~/.claude/hooks/*.sh; do [ -x "$f" ] || exit 1; done'` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-03d | smoke | `grep -q 'CURRENT STATE' .progress/PROGRESS.md && grep -q 'HISTORY LOG' .progress/PROGRESS.md` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-03e | smoke | `bash scripts/test-stub-reject.sh` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-03f | smoke | `bash scripts/test-progress-hook.sh` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-03g | smoke | `bash scripts/test-trace-hook.sh` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-07 | integration | `bash preflight.sh` | ❌ W0 | ⬜ pending |
| 00-01-xx | 01 | 1 | SKEL-05 | smoke | `grep 'disallowedTools: Write, Edit' ~/.claude/agents/verifier.md` | ❌ W0 | ⬜ pending |
| 00-02-xx | 02 | 1 | PLAN-01 | integration | `bash scripts/no-verify-cmd-test.sh` | ❌ W0 | ⬜ pending |
| 00-02-xx | 02 | 1 | LOOP-01 | integration | `bash scripts/force-loop-test.sh` | ❌ W0 | ⬜ pending |
| 00-02-xx | 02 | 1 | LOOP-02 | integration | `bash scripts/force-loop-test.sh` | ❌ W0 | ⬜ pending |
| 00-02-xx | 02 | 1 | ONBD-01 | smoke | `bash install.sh && ls ~/.claude/hooks/*.sh` | ❌ W0 | ⬜ pending |
| 00-03-xx | 03 | 2 | GIAV-01 | unit | `cd ~/Work/mine/giavico && python -m pytest tests/test_ingest.py -x` | ❌ W0 | ⬜ pending |
| 00-03-xx | 03 | 2 | GIAV-02 | unit | `cd ~/Work/mine/giavico && python -m pytest tests/test_normalize.py -x` | ❌ W0 | ⬜ pending |
| 00-03-xx | 03 | 2 | GIAV-03 | unit | `cd ~/Work/mine/giavico && python -m pytest tests/test_recommend.py -x` | ❌ W0 | ⬜ pending |
| 00-03-xx | 03 | 2 | GIAV-04 | integration | `cd ~/Work/mine/giavico && python -m pytest tests/ -x` | ❌ W0 | ⬜ pending |
| 00-03-xx | 03 | 2 | GIAV-05 | manual | Human sign-off in PROGRESS | manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

**Harness (in `build-anything/`):**
- [ ] `scripts/test-exit-code-2.sh` — stubs for SKEL-03a
- [ ] `scripts/test-stderr-template.sh` — stubs for SKEL-03b
- [ ] `scripts/test-stub-reject.sh` — stubs for SKEL-03e
- [ ] `scripts/test-progress-hook.sh` — stubs for SKEL-03f
- [ ] `scripts/test-trace-hook.sh` — stubs for SKEL-03g
- [ ] `scripts/no-verify-cmd-test.sh` — covers PLAN-01
- [ ] `scripts/force-loop-test.sh` — covers LOOP-01, LOOP-02
- [ ] `preflight.sh` — covers SKEL-03 (all 7) + SKEL-07

**Giavico (in `~/Work/mine/giavico/`):**
- [ ] `pytest.ini` — test configuration
- [ ] `tests/conftest.py` — shared fixtures (mocked Anthropic client)
- [ ] `tests/test_ingest.py` — covers GIAV-01
- [ ] `tests/test_normalize.py` — covers GIAV-02
- [ ] `tests/test_recommend.py` — covers GIAV-03 (mocked API)
- [ ] `fixtures/sample.xlsx` — test fixture Excel file
- [ ] Framework install: `pip install pandas==3.0.3 openpyxl==3.1.5 anthropic python-dotenv pytest` in `.venv/`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| App starts and all 3 modules are accessible | GIAV-05 | Requires human to visually confirm the app is usable | 1. Run `cd ~/Work/mine/giavico && python main.py` with a real Excel file. 2. Confirm all 3 modules complete without error. 3. Record PASS/FAIL in PROGRESS as `GIAV-05: PASS`. |
| verifier agent available after install | SKEL-05 (post-install) | Agents require session restart after direct file write | 1. Run `bash install.sh`. 2. Restart Claude Code session. 3. Confirm verifier agent is available in new session. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
