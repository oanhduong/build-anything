# Requirements: Signature Harness Kit

**Defined:** 2026-06-22
**Revised:** 2026-06-22 (added verification loop, onboarding, revised self-improve for auto-distill)
**Core Value:** Knowledge compounds — a lesson distilled from one build is committed into the signature repo and auto-enforced when the next project starts.

---

## v1 Requirements

### Phase 0 — Skeleton

- [x] **SKEL-01**: Harness global layer installs at `~/.claude` as a versioned git repo with defined directory layout (skills/, agents/, hooks/, failure-lib/, CLAUDE.md)
- [x] **SKEL-02**: Project bootstrap drops a ~100-line CLAUDE.md (context TOC) + docs/ into any target repo; references global layer without duplication
- [x] **SKEL-03**: 7 preflight checks verified before any real build work begins: (a) exit-code-2 hook test, (b) stderr-not-stdout template test, (c) chmod +x preflight on all hooks, (d) PROGRESS file schema in place, (e) stub-reject hook fires on `pass$`/`TODO`/`NotImplemented`, (f) progress-after-edit hook fires on Write/Edit, (g) minimal trace hook writes tool name + target + exit code + timestamp
- [x] **SKEL-04**: `PostToolUse` hook updates PROGRESS file after every Write/Edit; PROGRESS has two sections: `CURRENT STATE` (overwritten each session, capped) and `HISTORY LOG` (append-only, one-liners per edit)
- [x] **SKEL-05**: Verifier subagent defined at `~/.claude/agents/verifier.md` with `disallowedTools: Write, Edit` and `permissionMode: dontAsk`; human-invoked only in Phase 0. Verifier EXECUTES criteria, never invents them. Two tiers: (1) universal kit-shipped checks (no stub/NotImplemented, real run not just compile, no stray hardcode, every declared function is called); (2) phase-specific verify command from PLAN-01. Quality of verification depends on PLAN producing a runnable done-criterion — the strongest gate sits at plan time, not verify time.
- [x] **SKEL-06**: `common.sh` shared library exists with canonical hook-response functions (block with exit 2, emit to stderr, write trace line)
- [x] **SKEL-07**: All enforcement hooks use exit code 2 (not 1) for blocking; block messages emitted to stderr (not stdout); all hook scripts are chmod +x

### Phase 0 — Verification Loop

- [x] **PLAN-01**: Every task carries a machine-runnable verify command — a binary, externally-checkable definition of done produced at PLAN time, not at verify time. A task without a runnable verify command is BLOCKED from execution. (Implements "put the spec in the check" + "every task needs a binary done".)
- [x] **LOOP-01**: Stop hook runs the task's verify command when Claude tries to end the turn. Fail → exit 2 with failure reason on stderr → Claude must continue. Pass → exit 0 → Claude may stop. This is the mechanism that forces the loop — without it the verifier only judges, never makes Claude redo the work.
- [x] **LOOP-02**: LOOP-01 is bounded. The Stop hook counts iterations per task; at a ceiling of 2–3 it stops forcing, writes `BLOCKED: <reason>` to PROGRESS, and escalates (human or stronger model). Hitting the ceiling is a signal that the criteria or the generator is wrong — not a silent failure, not infinite retry.

### Phase 0 — Onboarding

- [x] **ONBD-01**: Kit ships a one-step install path (clone or script) that places hooks/, agents/, commands/, skills/, and settings.json into `~/.claude`. A developer on a fresh machine can be running with the kit in one command.
- [x] **ONBD-02**: Kit runs without GSD. Global hooks fire on any Claude Code session. GSD is optional and only adds value for phase-driven builds. The kit's enforcement layer is always-on independently of whether GSD is present.
- [x] **ONBD-03**: After install, preflight self-check runs automatically. On first project session, `bootstrap-project.sh` (SessionStart hook) auto-creates `.progress/PROGRESS.md` if missing. `install.sh` runs `preflight.sh` automatically after install — no manual step required.

### Phase 0 — Giavico PoC

- [x] **GIAV-01**: Giavico PoC module 1 implemented: read arbitrary Excel file, detect and infer schema
- [x] **GIAV-02**: Giavico PoC module 2 implemented: map detected schema into a normalized structure
- [x] **GIAV-03**: Giavico PoC module 3 implemented: analyze normalized data, output AI recommendations
- [x] **GIAV-04**: All 3 modules callable end-to-end in a single run (not "should work" — actually runs and produces output)
- [x] **GIAV-05**: Human owner verifies: kit drives the Giavico build, app starts, all 3 modules callable (binary pass/fail)

### Phase 1 — Enforcement

- [x] **ENFC-01**: Every failure exposed in the Phase 0 Giavico run is converted to a hook, linter rule, skill, or verifier check. Verifier checks added here follow the two-tier structure from SKEL-05: universal kit checks first, then phase-specific verify commands.
- [x] **ENFC-02**: Every enforcement rule is tagged `architecture` (permanent) or `model-crutch` (current-model weakness); model-crutch rules carry the Claude model version they address (e.g., `claude-sonnet-4-6`)
- [x] **ENFC-03**: Every enforcement hook block message is written to TEACH self-fix (explains what failed and how to correct it), not just to block
- [x] **ENFC-04**: Hooks are language-agnostic: no per-stack adapters; grep-based detection only (covers Node, Java, Kotlin, Python, React, Angular with the same script)
- [x] **ENFC-05**: Done check: re-running the Giavico build with the Phase 1 harness, every failure category from Phase 0 is automatically blocked before it reaches the verifier

### Phase 2 — Context Plane

- [x] **CTXP-01**: CLAUDE.md audit enforced: no dynamic content (timestamps, PROGRESS tails, current-task notes) in CLAUDE.md; stable reference content only; TOC structure at top
- [x] **CTXP-02**: Structured session handoff note written at session end (via Stop hook or `/handoff` skill); contains: current task, last 3 edits, open blockers, next action
- [x] **CTXP-03**: Context pull skill provides 2–3 operations: `search` (grep docs/ and context files — failure-lib is already auto-surfaced at session start via `load-lessons.sh` and contextually via post-write/on-error hooks), `get-file` (read a specific context file), `expand-summary` (fetch full section from a TOC pointer)
- [x] **CTXP-04**: Long task (multi-session) survives context reset and session handoff without losing coherence: the next session can reconstruct task state from PROGRESS + handoff note alone

### Phase 3 — Self-Improve

- [x] **SELF-01**: Auto-distill and `/retro` are both blocked without a trace file as input. Distillation without trace evidence is not permitted.
- [x] **SELF-02**: Candidate lessons are grounded in trace evidence (tool name, file, exit code, timestamp) — not prose speculation. Each lesson cites at least one trace entry.
- [x] **SELF-03**: Auto-distill fires on a **threshold trigger**, not every session: (a) feature-complete signal, or (b) same failure repeated N times in failure-lib. The SessionEnd/Stop hook checks the threshold; if met, it auto-reads trace + PROGRESS + failure-lib, drafts candidate lessons, and appends them to a pending-lessons queue. No human action required at distill time.
- [x] **SELF-04**: SessionStart hook surfaces the pending-lessons queue as a one-line notice ("N lessons pending — run `/retro approve` to review"). Human approves or rejects in one quick batch, not one-by-one. Extend `load-lessons.sh` (already in place) rather than creating a new SessionStart hook.
- [x] **SELF-05**: Auto-distill greps the failure-lib before proposing any lesson. Duplicate lessons (already present in the library) are suppressed and not added to the pending queue.
- [x] **SELF-06**: Approved lesson is committed to failure-lib as a new entry in the current format (`id`/`tags`/`when`/`error-match` frontmatter); existing hooks (`load-lessons.sh`, `lessons-post-write.sh`, `lessons-on-error.sh`) surface it automatically — no separate hook/skill/verifier-check conversion step. Rejected lesson is discarded. Note: the old `enforcement-type: verifier-check` tier is gone — verifier no longer greps failure-lib; lessons surface via hooks instead.
- [x] **SELF-07**: Prune step fires on model version upgrade: reviews all `model-crutch`-tagged rules, retires rules that address behaviors the current model version no longer exhibits.
- [x] **SELF-08**: `/retro` is a manual override only — not the primary distill path. It accepts an explicit trace file, runs the same grounded-lesson logic as auto-distill, and outputs a candidate list for immediate human review.
- [x] **SELF-09**: Skills may be auto-drafted by the agent as candidate lessons but are **never auto-activated** without passing the human approval gate. Rules tagged `architecture` are never auto-generated unattended — only `model-crutch` rules and low-risk procedural skills go through the auto-draft path.

### Phase 4 — Heavy Retrieval (Conditional)

- [x] **RETR-01**: Phase 4 is only planned and built if Phase 3 traces show grep-based retrieval is causing measurable quality loss (miss-rate or latency bottleneck)
- [ ] **RETR-02**: If gate opens: vector/hybrid index over failure-lib + docs/; retrieval replaces grep-based search in context pull skill

---

## v2 Requirements

### Not in this milestone

- **MULTI-01**: Failure library sync across machines (multi-machine team) — requires documented git push/pull operational procedure for `~/.claude`
- **HOOK-01**: `agent` hook handler type — experimental in Claude Code; defer until stable
- **VERF-01**: Verifier auto-invoked via hook (Phase 0 verifier is human-invoked only; Phase 1 may introduce hook-wiring)
- **CI-01**: CI integration for Giavico PoC — automated test suite in CI; Phase 0 uses human verify only

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Rebuilding Claude Code's engine (loop, tool use, context compaction) | Hard constraint — kit layers ON TOP; reimplementation adds maintenance burden with no benefit |
| Per-stack adapters in hooks/linters (Node-specific, Python-specific, etc.) | Hard constraint — hooks must be language-agnostic; per-stack adapters fragment the harness |
| Vector DB / knowledge graph in Phases 0–3 | Evidence-first — earn each layer; file-based failure library is sufficient until trace proves otherwise |
| Auto-activating skills or rules without human approval gate | Hard constraint — auto-draft is permitted for model-crutch and procedural skills; auto-activation never is |
| Auto-generating architecture-tagged rules | Hard constraint — `architecture` rules are permanent and may never be auto-generated unattended |
| Whole-project autonomous execution | Scope guardrail — kit unit of autonomy is ONE bounded task (at most one phase in auto mode); not a full-project runner |
| Heavy retrieval (Phase 4) without trace evidence | Hard gate — Phase 4 not built unless Phase 3 trace proves retrieval is the bottleneck |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SKEL-01 | Phase 0 | Complete |
| SKEL-02 | Phase 0 | Complete |
| SKEL-03 | Phase 0 | Complete |
| SKEL-04 | Phase 0 | Complete |
| SKEL-05 | Phase 0 | Complete |
| SKEL-06 | Phase 0 | Complete |
| SKEL-07 | Phase 0 | Complete |
| PLAN-01 | Phase 0 | Complete |
| LOOP-01 | Phase 0 | Complete |
| LOOP-02 | Phase 0 | Complete |
| ONBD-01 | Phase 0 | Complete |
| ONBD-02 | Phase 0 | Complete |
| ONBD-03 | Phase 0 | Complete |
| GIAV-01 | Phase 0 | Complete |
| GIAV-02 | Phase 0 | Complete |
| GIAV-03 | Phase 0 | Complete |
| GIAV-04 | Phase 0 | Complete |
| GIAV-05 | Phase 0 | Complete |
| ENFC-01 | Phase 1 | Complete |
| ENFC-02 | Phase 1 | Complete |
| ENFC-03 | Phase 1 | Complete |
| ENFC-04 | Phase 1 | Complete |
| ENFC-05 | Phase 1 | Complete |
| CTXP-01 | Phase 2 | Complete |
| CTXP-02 | Phase 2 | Complete |
| CTXP-03 | Phase 2 | Complete |
| CTXP-04 | Phase 2 | Complete |
| SELF-01 | Phase 3 | Complete |
| SELF-02 | Phase 3 | Complete |
| SELF-03 | Phase 3 | Complete |
| SELF-04 | Phase 3 | Complete |
| SELF-05 | Phase 3 | Complete |
| SELF-06 | Phase 3 | Complete |
| SELF-07 | Phase 3 | Complete |
| SELF-08 | Phase 3 | Complete |
| SELF-09 | Phase 3 | Complete |
| RETR-01 | Phase 4 | Complete |
| RETR-02 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 38 total (+1 ONBD-03 promoted from deferred)
- Mapped to phases: 38
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-22*
*Last updated: 2026-06-23 — promoted ONBD-03 from deferred to Phase 0 complete (bootstrap-project.sh + auto-preflight in install.sh); updated CTXP-03 (failure-lib auto-surfaced by hooks, search targets docs/ and context files); updated SELF-04 (extend load-lessons.sh); updated SELF-06 (lessons committed in id/tags/when/error-match format, verifier no longer greps failure-lib)*

*Roadmap created: 2026-06-22 — phase assignments confirmed, done commands defined for all 5 phases (0–4); Phase 4 marked conditional*
