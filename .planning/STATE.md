# State: build-anything

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-06-30 — Milestone v1.0 Integrity Layer started

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-30)

**Core value:** Every build is reviewed by a system that cannot be fooled by the generator — correctness is enforced structurally, not by trust.
**Current focus:** Milestone v1.0 — Integrity Layer (defining phases)

## Accumulated Context

- Phases 0–3 complete and verified by scripts/test-enforcement.sh
- Phase 4 (heavy retrieval) gate closed — no measured grep bottleneck yet
- All hooks installed at ~/.claude/hooks/; installed via install.sh
- VERIFY_CMD in PROGRESS.md is the current single source of done-signal — insufficient for semantic correctness
- The generator currently can write its own VERIFY_CMD (self-grading violation)
