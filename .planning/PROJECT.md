# build-anything

## What This Is

A versioned global enforcement layer for Claude Code, installed at `~/.claude`. Compounds knowledge across builds: hooks enforce quality gates, a verifier subagent catches failures, a self-improve loop distills lessons into a failure library. The source repo (`build-anything`) is installed once; every project downstream benefits automatically.

## Core Value

Every build is reviewed by a system that cannot be fooled by the generator — correctness is enforced structurally, not by trust.

## Current Milestone: v1.0 — Integrity Layer

**Goal:** Eliminate the two root causes of silent failure: generator self-grading (no independent verifier), and execution without a human-confirmed spec.

**Target features:**
- Independent verifier subagent invoked by stop-hook (not generator self-grade)
- Spec + plan gate: human-confirmed SPEC artifact required before first Write/Edit
- Intent-aware failure library: lessons tagged by criterion violated, not just Bash exit code
- Structured BLOCKED exit: escalation report when retry ceiling reached

## Requirements

### Validated

- ✓ Hook triad: exit 2 block, stderr channel, chmod +x — Phase 0
- ✓ Stub-rejection hook (pattern: pass/stub-markers/NotImplemented) before Write/Edit — Phase 0
- ✓ Trace log: every tool call recorded with exit code — Phase 0
- ✓ PLAN-01: blocks Write/Edit when VERIFY_CMD absent — Phase 1
- ✓ CTXP-01: blocks dynamic content in CLAUDE.md — Phase 1
- ✓ Per-project bootstrap: PROGRESS.md created on SessionStart — Phase 1
- ✓ PROGRESS.md contract: CURRENT_TASK, VERIFY_CMD, BLOCKED_COUNT — Phase 2
- ✓ HANDOFF.md written on every session stop — Phase 2
- ✓ context-pull skill for context-reset resilience — Phase 2
- ✓ auto-distill.sh: trace-grounded lesson drafting — Phase 3
- ✓ /retro skill: approve/reject/prune lesson candidates — Phase 3
- ✓ lesson-hit-counts: repeated-failure distill trigger — Phase 3

### Active

- [ ] VERIF-01: stop-hook invokes independent verifier subagent per criterion (not VERIFY_CMD alone)
- [ ] VERIF-02: verifier returns structured PASS/FAIL per criterion with evidence
- [ ] VERIF-03: stop-hook reads criteria from SPEC artifact, passes each to verifier
- [ ] GATE-01: spec-interview skill produces SPEC.md via risk-driven interview; human confirms before execution
- [ ] GATE-02: PreToolUse hook blocks first Write/Edit when .progress/SPEC.md absent
- [ ] GATE-03: PreToolUse hook blocks when SPEC.md lacks Acceptance Criteria section
- [ ] GATE-04: VERIFY_CMD derived from criteria in SPEC.md (not free-form generator choice)
- [ ] DIST-01: failure-lib entries gain `criterion:` frontmatter field
- [ ] DIST-02: verifier failure (not just Bash error) triggers distill path into pending/
- [ ] DIST-03: lessons distilled from verifier failures tagged with violated criterion
- [ ] BLOCK-01: BLOCKED ceiling produces structured escalation report with criterion verdicts
- [ ] BLOCK-02: optional cost ceiling field in PROGRESS.md; stop-hook enforces it

### Out of Scope

- Phase 4 heavy retrieval — gate closed until grep bottleneck is measured
- Per-stack adapters — hooks are language-agnostic by architecture decision
- Rebuilding Claude Code engine (hook/subagent/skill primitives) — build on top, not replace
- Automated requirement approval — human-confirm gate is non-negotiable

## Context

Shell-only codebase. No build system. Installed via install.sh into ~/.claude. All hooks fire via Claude Code hook system; all skills are SKILL.md files; all agents are .md files in agents/. Phase 4 (vector retrieval) gate is explicitly closed pending a measured grep bottleneck.

## Constraints

- **Platform**: Build ON Claude Code primitives (hook, subagent, skill, plan mode) — do not rebuild the engine
- **Shell**: Minimize new shell glue — requirement/planning layer is artifacts and gates, not more hooks
- **Human gate**: Requirement confirmation must be human-in-loop — no auto-approval permitted
- **Tagging**: Every new rule must be tagged `architecture` or `model-crutch` at creation

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| exit 2 for blocking, exit 1 non-blocking | Claude Code hook semantics — exit 1 is always non-blocking | ✓ Good |
| stderr for human messages, stdout for JSON | Hook output channel contract | ✓ Good |
| stop_hook_active guard | Prevents infinite session wedge on exit 2 | ✓ Good |
| PROGRESS.md as machine-readable state | Survives context reset; hook-parseable with grep/awk | ✓ Good |
| Phase 4 gate-driven, no heavy retrieval yet | No measured bottleneck; premature optimization avoided | — Pending |
| Verifier subagent has disallowedTools Write+Edit | Prevents verifier from rationalizing broken output | ✓ Good |

---
*Last updated: 2026-06-30 after Milestone v1.0 initialization*
