# Signature Harness Kit

## What This Is

A versioned, global layer that imposes an opinionated way of working onto vanilla Claude Code — skills, enforcement hooks, a verifier subagent, and a file-based failure library — installed at `~/.claude`. Every project bootstrapped with the kit gets a thin CLAUDE.md + docs/ that pulls in this layer, so hard-won lessons from one product become enforcement rules for the next.

## Core Value

Knowledge compounds: a lesson distilled from one build is committed into the signature repo and auto-enforced when the next project starts.

## Requirements

### Validated

(None yet — ship to validate)

### Active

#### Skeleton (Phase 0)
- [ ] Native Claude Code loop runs as the builder engine (no re-implementation)
- [ ] One verifier subagent separated from the generator
- [ ] PROGRESS file updated after every file edit
- [ ] Minimal hooks: write-progress-after-edit, grep-for-stubs-and-reject, skip-permission-prompts-for-unattended-runs
- [ ] Giavico PoC (3 modules: Excel ingestion + schema detection, auto normalization, AI analysis + recommendation) builds and runs end-to-end using the kit
- [ ] One clean end-to-end run verified by the human owner

#### Enforcement (Phase 1)
- [ ] Every leak from Phase 0 converted to hook / linter / skill / verifier check
- [ ] Every rule tagged `architecture` or `model-crutch`
- [ ] Re-running the Giavico build, old failures are blocked automatically

#### Context Plane (Phase 2)
- [ ] Files hub + state file + handoff note
- [ ] 2–3 pull tools: search, get-file, expand-summary
- [ ] KV-cache ordering applied (stable content at top)
- [ ] Long task survives context reset + session handoff without losing coherence

#### Self-Improve (Phase 3)
- [ ] `/retro` command: reads PROGRESS + failure log + run trace, proposes candidate lessons
- [ ] Human approval gate before any lesson becomes enforcement
- [ ] Approved lesson converts to enforcement and is carried forward into signature repo
- [ ] Periodic prune step for `model-crutch` rules

#### Heavy Retrieval (Phase 4 — conditional)
- [ ] Vector/hybrid index + qualified hub
- [ ] Gate: only built if a trace proves retrieval is the bottleneck

### Out of Scope

- Rebuilding Claude Code's engine (loop, tool use, context compaction, subagents, hooks) — the kit layers ON TOP
- Vector DB / knowledge graph in Phase 0–3 — earn each layer with evidence
- Per-stack adapters in hooks/linters — hooks must be language-agnostic across Node, Java, Kotlin, Python, React, Angular
- Auto-activating skills or rules without human approval gate — auto-draft is permitted; auto-activation is not
- Auto-generating architecture-tagged rules unattended — architecture rules are permanent and hand-authored only
- Whole-project autonomous execution — kit unit of autonomy is one bounded task, not a full project run

## Context

**Two-layer architecture:**
- **Signature layer**: global versioned repo at `~/.claude`. Holds curated skills, enforcement hooks, verifier subagent, file-based failure library. This is the long-lived asset that compounds over time.
- **Project layer**: thin bootstrap in any repo — CLAUDE.md ~100 lines as a table of contents into docs/, which pulls in the signature layer.

**Mapping to Claude Code primitives:**
- Context TOC → CLAUDE.md (stable content at top for KV-cache; selection over storage)
- Curated skills → SKILL.md under 200 lines, numbered procedures with explicit stop conditions
- Enforcement → pre/post tool-use hooks + linters; error messages written to teach the agent self-fix
- Verifier → separate subagent; priority: code checks → domain-rule checks → LLM-as-judge last
- State/handoff → PROGRESS file (PostToolUse hook) + structured handoff note (Stop hook); state lives in files not context window
- Self-improve → threshold-triggered auto-distill (SessionEnd hook); human approves/rejects pending-lessons queue at SessionStart; `/retro` is manual override only

**Test target — Giavico PoC (separate repo):**
A real product with a real failing case. Three modules: (1) Excel ingestion + schema detection, (2) auto normalization, (3) AI analysis + recommendation. Used in Phase 0 to prove the loop runs end-to-end once before adding kit features.

**Stack context:**
Projects built with this kit span Node, Java, Kotlin, Python, React, Angular — hooks must be language-agnostic.

## Constraints

- **Architecture**: Build ON Claude Code; never rebuild its engine
- **Enforcement**: Lessons must be enforced (hook/linter/skill/verifier check), not just documented
- **Done criteria**: Every task needs a binary, externally-checkable definition of done — a machine-runnable verify command produced at PLAN time, not verify time
- **Verification loop**: Stop hook runs the verify command; bounded at 2–3 iterations; ceiling → BLOCKED + escalate (never silent infinite retry)
- **Human gate**: Auto-draft of model-crutch rules and procedural skills is permitted; auto-activation is never permitted. Architecture-tagged rules are never auto-generated. Every lesson passes human approval before becoming enforcement.
- **Rule tagging**: Every enforcement rule tagged `architecture` (permanent) or `model-crutch` (current-model weakness, prune later); model-crutch rules carry the Claude model version they address
- **Language-agnostic hooks**: No per-stack adapters; generic grep-based checks only
- **Failure library**: File-based for now — no vector DB, no knowledge graph
- **Evidence-first**: Do not build context machinery or heavy retrieval before a trace proves where quality leaks
- **Scope of autonomy**: The kit's unit of autonomy is ONE bounded task (at most one phase in auto mode). The kit makes long projects survivable — it does NOT run an entire project unattended. Human verify stays at each phase checkpoint.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Phase 0 uses Giavico PoC as test target | Real product with real failing cases gives the observability layer something concrete to expose | — Pending |
| Phase 4 (heavy retrieval) is conditional | Only build if a trace proves retrieval is the bottleneck — earn each layer with evidence | — Pending |
| Failure library is file-based in v1 | Avoid premature complexity; vector DB/knowledge graph deferred until proven needed | — Pending |
| Enforcement over documentation | A lesson written down but not enforced will be forgotten — enforcement is the only durable form | — Pending |
| Verifier is always a separate subagent | Generator grading itself produces grade inflation — structural separation is non-negotiable | — Pending |

---
*Last updated: 2026-06-22 — added verification loop (PLAN-01/LOOP-01/LOOP-02), onboarding (ONBD-01/02), auto-distill self-improve, verifier two-tier scope, scope-of-autonomy constraint*
