# Requirements: build-anything

**Defined:** 2026-06-30
**Core Value:** Every build is reviewed by a system that cannot be fooled by the generator — correctness is enforced structurally, not by trust.

## v1 Requirements

Milestone v1.0 — Integrity Layer. Continues from validated Phase 0–3 baseline.

### Verifier Independence (A1)

- [x] **VERIF-01**: stop-hook invokes independent verifier subagent per acceptance criterion — generator cannot score its own output
- [x] **VERIF-02**: verifier subagent returns structured `VERDICT: PASS|FAIL` per criterion with evidence string, not just command exit code
- [x] **VERIF-03**: stop-hook reads acceptance criteria list from SPEC artifact and passes each criterion to verifier individually

### Spec + Plan Gate (A2 + B)

- [ ] **GATE-01**: a new `/spec` skill produces `.progress/SPEC.md` via risk-driven interview; skill proposes draft, human must confirm before the spec is written
- [x] **GATE-02**: PreToolUse hook blocks any Write/Edit when `.progress/SPEC.md` is absent for the current task
- [x] **GATE-03**: PreToolUse hook blocks when SPEC.md exists but has no `## Acceptance Criteria` section (malformed spec is no spec)
- [ ] **GATE-04**: VERIFY_CMD stored in PROGRESS.md is derived from and matches the criteria in SPEC.md — generator cannot write a free-form VERIFY_CMD that bypasses real criteria

### Intent-Aware Failure Library (A3)

- [ ] **DIST-01**: failure-lib `.md` entries gain a `criterion:` frontmatter field identifying which acceptance criterion the lesson relates to
- [ ] **DIST-02**: when verifier returns FAIL on a criterion (even with Bash exit 0), a pending lesson is drafted via auto-distill with the criterion tag
- [ ] **DIST-03**: auto-distill.sh accepts a criterion argument; lessons created from verifier failures are tagged with violated criterion, not just tool+target

### Structured BLOCKED Exit (A4)

- [ ] **BLOCK-01**: when BLOCKED_COUNT reaches ceiling, stop-hook writes a structured escalation report to `.progress/BLOCKED-REPORT.md` containing: criteria attempted, per-criterion verdict, recommended escalation step
- [ ] **BLOCK-02**: PROGRESS.md accepts an optional `COST_CEILING:` field; stop-hook checks it and writes BLOCKED before the ceiling is exceeded

## v2 Requirements

Deferred — not in this milestone roadmap.

- Phase 4 heavy retrieval (vector index) — gate opens only when grep bottleneck is measured
- Token-budget enforcement beyond task-level ceiling
- Cross-project lesson federation

## Out of Scope

| Feature | Reason |
|---------|--------|
| Per-stack adapters (language-specific hooks) | Architecture decision: hooks are grep-based, language-agnostic |
| Rebuilding Claude Code hook/subagent/skill engine | Build on top of primitives, do not replace them |
| Automated requirement approval | Human-confirm gate is a hard architectural invariant |
| Phase 4 heavy retrieval | Gate closed — no measured grep bottleneck yet |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| VERIF-01 | Phase 5 | Complete |
| VERIF-02 | Phase 5 | Complete |
| VERIF-03 | Phase 5 | Complete |
| GATE-01 | Phase 6 | Pending |
| GATE-02 | Phase 6 | Complete |
| GATE-03 | Phase 6 | Complete |
| GATE-04 | Phase 6 | Pending |
| DIST-01 | Phase 7 | Pending |
| DIST-02 | Phase 7 | Pending |
| DIST-03 | Phase 7 | Pending |
| BLOCK-01 | Phase 8 | Pending |
| BLOCK-02 | Phase 8 | Pending |

**Coverage:**
- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-30*
*Last updated: 2026-06-30 — phase assignments confirmed by roadmap creation*
