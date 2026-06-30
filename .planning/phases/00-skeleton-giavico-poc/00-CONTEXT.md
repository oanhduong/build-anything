# Phase 0: Skeleton + Giavico PoC - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish a verified hook enforcement skeleton at `~/.claude` and prove it drives the Giavico PoC end-to-end with one clean human-verified run.

Two sub-goals, both required:
- **Sub-goal A (Harness skeleton):** All 7 preflight checks pass. Three enforcement hooks wired (progress-after-edit, stub-reject, trace). Verification loop (Stop hook + LOOP-01/LOOP-02) working. One-step install confirmed on current machine.
- **Sub-goal B (Giavico PoC):** Three modules (Excel ingestion + schema detection, auto normalization, AI analysis + recommendation) build and run end-to-end from `~/Work/mine/giavico`, driven by the harness, verified by human.

Enforcement hardening (Phase 1), context plane (Phase 2), and self-improve (Phase 3) are out of scope.

</domain>

<decisions>
## Implementation Decisions

### Harness repo strategy
- `build-anything` (this repo) is the harness source — hooks/, agents/, skills/, failure-lib/, CLAUDE.md live here and are installed into `~/.claude`
- Install script merges harness assets into `~/.claude` — never clobbers existing GSD files
- Install appends new hooks to existing settings.json arrays (GSD hooks stay, harness hooks appended after)
- Repo ships a harness-only baseline `settings.json`; on a fresh machine (no GSD) this is written as-is; on the current machine the install script merges it
- `~/.claude` stays as the active GSD install; harness files are added alongside, not replacing

### Giavico PoC
- Runtime: Python (pandas + openpyxl for Excel ingestion; Anthropic Python SDK for AI recommendations)
- Location: standalone repo at `~/Work/mine/giavico` — separate from build-anything (mirrors real-world usage: harness drives an external project)
- Module 3 AI backend: Claude API via Anthropic Python SDK; specific model TBD at plan time (Haiku or Sonnet)
- Done command uses `cd giavico && ...` (as specified in roadmap success criteria)

### Hook coexistence with GSD
- Three new harness hooks appended to existing settings.json arrays: progress-after-edit and trace → PostToolUse; stub-reject → PreToolUse
- GSD hooks execute first (existing array order preserved); harness hooks appended
- Shared library: `common.sh` (bash) — canonical exit-2 blocking, stderr emission, trace writing; every harness hook sources it
- No per-stack adapters; grep-based detection only (language-agnostic per ENFC-04)
- Trace entry format: one-line plain text — `TIMESTAMP TOOL TARGET EXIT_CODE` — appended to `~/.claude/trace.log`

### Stop hook + verification loop
- **Research first:** Phase researcher must confirm exact Stop hook API (field names, exit code behavior, `stop_hook_active` semantics) before the Stop hook is planned. This is a critical blocker — LOOP-01 silently fails if the API is misunderstood.
- LOOP-02 iteration counter lives in the PROGRESS file (a BLOCKED_COUNT field) — consistent with "state lives in files" pattern
- PLAN-01 enforcement: both preflight check AND runtime enforcement
  - `preflight.sh` validates tasks in PLAN.md have verify commands (catches at plan review time)
  - PreToolUse hook checks PROGRESS for a verify command before Write/Edit (blocks if missing — "No verify command — declare one before writing code")

### Claude's Discretion
- Exact PROGRESS file schema fields (beyond what SKEL-04 specifies: CURRENT STATE + HISTORY LOG + BLOCKED_COUNT)
- Specific Claude model for Giavico module 3 (Haiku vs Sonnet — pick based on cost/latency tradeoff)
- Trace log rotation policy (if any)
- Preflight check ordering within `preflight.sh`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Harness requirements
- `.planning/REQUIREMENTS.md` — Full requirement set: SKEL-01..07, PLAN-01, LOOP-01..02, ONBD-01..02, GIAV-01..05. Every task must trace to one of these.
- `.planning/PROJECT.md` — Architecture principles, constraints, key decisions table, out-of-scope list. Read before any structural decision.

### Phase 0 scope
- `.planning/ROADMAP.md` §Phase 0 — Done command, success criteria (8 binary checks), sub-goals A and B. The done command is the ground truth for what Phase 0 means.

### Research gaps (blocker)
- `.planning/STATE.md` §Blockers/Concerns — Two confirmed research gaps: (1) `stop_hook_active` field name and Stop hook exit-code behavior; (2) whether `~/.claude/agents/` user-scope agents require session restart after edits. Phase researcher must resolve both before planning the Stop hook and verifier agent.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `~/.claude/hooks/gsd-check-update.js` — Example of a SessionStart hook in Node.js; shows how Claude Code invokes hooks
- `~/.claude/hooks/gsd-context-monitor.js` — Example of a PostToolUse hook; shows hook invocation pattern and how exit codes work in practice
- `~/.claude/settings.json` — Live settings file with existing hook arrays; install script must read and merge this

### Established Patterns
- Existing GSD hooks are Node.js; new harness hooks will be shell (bash) — both are valid in the same settings.json
- PostToolUse hooks in settings.json are already an array — appending to the array is the established pattern

### Integration Points
- `~/.claude/settings.json` — Primary integration point; harness install appends to `hooks.PostToolUse`, `hooks.PreToolUse`, `hooks.Stop`
- `~/.claude/agents/` — Verifier agent (verifier.md) goes here; research needed on whether session restart is required after adding new agents
- `~/Work/mine/giavico` — Does not exist yet; needs to be created as a new Python project

</code_context>

<specifics>
## Specific Ideas

- The done command from ROADMAP.md is the canonical test: `./preflight.sh && ./scripts/no-verify-cmd-test.sh && ./scripts/force-loop-test.sh && cd giavico && npm test` (note: runtime may be `python -m pytest` or similar once Python is confirmed — planner should adjust)
- The 8 success criteria in ROADMAP.md §Phase 0 are binary and externally checkable — each maps to a specific script or human action
- `GIAV-05` is a human-verify step (not automated) — human owner manually starts the app and records PASS in PROGRESS

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 00-skeleton-giavico-poc*
*Context gathered: 2026-06-22*
