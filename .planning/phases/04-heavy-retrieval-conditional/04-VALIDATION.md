---
phase: 4
slug: heavy-retrieval-conditional
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-24
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash scripts (same pattern as all prior phases) |
| **Config file** | none — scripts are standalone |
| **Quick run command** | `bash scripts/check-retrieval-gate.sh` |
| **Full suite command** | `bash scripts/check-retrieval-gate.sh && bash scripts/retrieval-e2e-test.sh` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/check-retrieval-gate.sh`
- **After every plan wave:** Run `bash scripts/check-retrieval-gate.sh && bash scripts/retrieval-e2e-test.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 1 | RETR-01 | integration | `bash scripts/check-retrieval-gate.sh` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 2 | RETR-02 | integration | `bash scripts/retrieval-e2e-test.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/check-retrieval-gate.sh` — gate check script (RETR-01)
- [ ] `scripts/build-retrieval-index.sh` — index builder (RETR-02)
- [ ] `scripts/retrieval-e2e-test.sh` — e2e test harness (RETR-02)
- [ ] Python deps: `pip install chromadb` (or requirements.txt entry)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gate evidence file present before proceeding | RETR-01 | Gate check must run before any Phase 4 build work | Run `check-retrieval-gate.sh`; confirm `gate-evidence.md` written |
| Hybrid fallback to grep when index missing | RETR-02 | Degraded-mode behavior requires live skill invocation | Remove `~/.claude/.retrieval/`, invoke `context-pull search failure`, verify grep result returned |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
