# Roadmap: Signature Harness Kit

## Overview

Build a versioned global enforcement layer for Claude Code that compounds knowledge across projects. Phase 0 proves the skeleton and hook enforcement triad work against a real product (Giavico PoC). Phase 1 converts every leak from that run into machine-enforced rules. Phase 2 adds the context plane so long tasks survive session resets. Phase 3 closes the loop with trace-grounded self-improvement. Phase 4 is conditional — only built if Phase 3 trace proves grep-based retrieval is the actual bottleneck.

## Phases

**Phase Numbering:**
- Integer phases (0–4): Planned milestone work
- Decimal phases: Urgent insertions (marked INSERTED)

- [ ] **Phase 0: Skeleton + Giavico PoC** - Harness skeleton passes all 7 preflight checks AND Giavico PoC runs end-to-end with human sign-off
- [x] **Phase 1: Enforcement Hardening** - Every Phase 0 failure converted to a hook/linter/skill/verifier check; Giavico replay confirms every failure category is automatically blocked (completed 2026-06-22)
- [x] **Phase 2: Context Plane** - Files hub, structured handoff, and 3 pull tools in place; a simulated context reset mid-task is fully recoverable from PROGRESS + handoff note alone (completed 2026-06-23)
- [ ] **Phase 3: Self-Improve Loop** - Auto-distill fires on threshold, human approves via pending queue, approved lesson commits to `~/.claude`; e2e verified by retro script
- [x] **Phase 4: Heavy Retrieval (CONDITIONAL)** - Vector/hybrid index over failure-lib; only built if Phase 3 trace proves grep retrieval is a measurable bottleneck (completed 2026-06-24)

## Phase Details

### Phase 0: Skeleton + Giavico PoC
**Goal**: Establish a verified hook enforcement skeleton at `~/.claude` and prove it drives a real product (Giavico PoC) end-to-end with one clean human-verified run.
**Depends on**: Nothing (first phase)
**Requirements**: SKEL-01, SKEL-02, SKEL-03, SKEL-04, SKEL-05, SKEL-06, SKEL-07, PLAN-01, LOOP-01, LOOP-02, ONBD-01, ONBD-02, GIAV-01, GIAV-02, GIAV-03, GIAV-04, GIAV-05

**Sub-goal A — Harness skeleton:**
All 7 preflight checks pass: exit-code-2 hook test, stderr-not-stdout template test, chmod +x on all hooks, PROGRESS file schema in place, stub-reject hook fires on `pass$`/`TODO`/`NotImplemented`, progress-after-edit hook fires on Write/Edit, minimal trace hook writes tool name + target + exit code + timestamp.

**Sub-goal B — Giavico PoC:**
All three modules (Excel ingestion + schema detection, auto normalization, AI analysis + recommendation) build and run end-to-end, driven by the harness, verified by human.

**Success Criteria** (what must be TRUE — binary, externally checkable):
  1. `./preflight.sh` exits 0 — all 7 harness checks pass without manual intervention
  2. A hook using `exit 1` is confirmed non-blocking; the same hook with `exit 2` is confirmed blocking (validated by SKEL-03/SKEL-07)
  3. `cd ~/Work/mine/giavico && python -m pytest tests/ -x -q` exits 0 — all 3 Giavico modules callable end-to-end producing real output
  4. Human owner manually starts the Giavico app and confirms all 3 modules are accessible (binary pass/fail sign-off recorded in PROGRESS as GIAV-05: PASS)
  5. A one-step install command places all harness assets into `~/.claude` on a fresh path and global hooks fire immediately in the next Claude Code session (ONBD-01/ONBD-02)
  6. `./scripts/no-verify-cmd-test.sh` exits 0 — a task submitted with no runnable verify command is refused execution (PLAN-01 enforcement confirmed)
  7. `./scripts/force-loop-test.sh` exits 0 — a deliberately-failing task causes the Stop hook to exit 2 and Claude is forced to continue (LOOP-01 proven)
  8. `./scripts/force-loop-test.sh` also confirms the bound: after the iteration ceiling (2–3), the task is marked `BLOCKED: <reason>` in PROGRESS and looping stops (LOOP-02 proven, same script)

**Done command:**
```
bash preflight.sh \
  && bash scripts/no-verify-cmd-test.sh \
  && bash scripts/force-loop-test.sh \
  && cd ~/Work/mine/giavico && source .venv/bin/activate && python -m pytest tests/ -x -q
# Then: human runs `python main.py fixtures/sample.xlsx`, verifies all 3 modules produce output,
# records GIAV-05: PASS in .progress/PROGRESS.md
```
**Plans**: 3 plans

Plans:
- [ ] 00-01-PLAN.md — Harness foundation: directory layout, common.sh, verifier.md, CLAUDE.md, settings.json, PROGRESS schema, install.sh
- [ ] 00-02-PLAN.md — Enforcement hooks + preflight: stub-reject, progress-after-edit, trace, stop-hook, preflight.sh, 7 test scripts, no-verify-cmd-test.sh, force-loop-test.sh
- [ ] 00-03-PLAN.md — Giavico PoC: 3 Python modules, pytest suite, fixtures, main.py, GIAV-05 human checkpoint

### Phase 1: Enforcement Hardening
**Goal**: Convert every failure category exposed during the Phase 0 Giavico run into a hook, linter rule, skill, or verifier check tagged with the correct rule type, so that re-running the same build automatically blocks all prior failures before they reach the verifier.
**Depends on**: Phase 0
**Requirements**: ENFC-01, ENFC-02, ENFC-03, ENFC-04, ENFC-05

**Success Criteria** (what must be TRUE — binary, externally checkable):
  1. `./scripts/replay-giavico-failures.sh` exits 0 — the script replays every failure scenario captured from Phase 0 and confirms each is blocked (exit 2) before reaching the verifier
  2. Every enforcement rule in `~/.claude/hooks/` and `~/.claude/failure-lib/` carries a `# tag: architecture` or `# tag: model-crutch` annotation; `grep -rL 'tag:' ~/.claude/hooks/` returns empty
  3. Every hook block message emitted to stderr contains both a failure description and an explicit self-fix instruction (grep-verifiable pattern: "How to fix:" in block messages)
  4. Every hook script passes a language-agnostic test: no `node`, `python`, `java`, `kotlin` binary invocations in hook bodies — grep-verifiable

**Done command:**
```
./scripts/replay-giavico-failures.sh
```
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — Failure-lib entries: 6 .md files documenting all Phase 0 failure categories (eval-subshell, openpyxl-engine, dotenv-module-scope, mock-import-boundary, static-test-fixture, home-scope)
- [ ] 01-02-PLAN.md — Hook annotations + verifier update: add # tag: architecture to all 5 hooks, add How-to-fix to stop-hook.sh, update verifier.md with failure-lib runtime scan
- [ ] 01-03-PLAN.md — replay-giavico-failures.sh: Phase 1 done command proving ENFC-01..04 + human checkpoint

### Phase 2: Context Plane
**Goal**: Add the files hub, structured handoff note, and context pull skills so that a long multi-session task survives context reset without losing coherence — reconstructable from PROGRESS + handoff note alone.
**Depends on**: Phase 1

**Pre-existing infrastructure (from post-Phase-1 improvements):**
- `bootstrap-project.sh` (SessionStart) — auto-creates PROGRESS.md; sessions start with context guaranteed
- `load-lessons.sh` (SessionStart) — lesson index already injected at session start
- `lessons-post-write.sh` / `lessons-on-error.sh` — failure-lib surfaced contextually; `search` skill focuses on docs/ and PROGRESS, not failure-lib
**Requirements**: CTXP-01, CTXP-02, CTXP-03, CTXP-04

**Success Criteria** (what must be TRUE — binary, externally checkable):
  1. `./scripts/context-reset-test.sh` exits 0 — the script simulates a context reset mid-task and verifies the next session reconstructs exact task state (current task, last 3 edits, open blockers, next action) from PROGRESS + handoff note alone
  2. `grep -n '.' ~/.claude/CLAUDE.md | head -50` contains zero dynamic content (no timestamps, no PROGRESS tail, no current-task note) — stable reference content only
  3. Three context pull operations are callable as skills: `search`, `get-file`, `expand-summary` — each exits 0 and returns content when invoked against a seeded context fixture
  4. A structured handoff note written by the Stop hook (or `/handoff` skill) contains all four required fields: current task, last 3 edits, open blockers, next action — verified by schema check in the test script

**Done command:**
```
./scripts/context-reset-test.sh
```
**Plans**: 3 plans

Plans:
- [ ] 02-01-PLAN.md — CLAUDE.md audit hook: hooks/claude-md-audit.sh (PreToolUse, blocks dynamic content) + settings.json PreToolUse registration
- [ ] 02-02-PLAN.md — Handoff + skills: hooks/stop-hook.sh HANDOFF.md write extension + skills/context-pull/SKILL.md + skills/handoff/SKILL.md
- [ ] 02-03-PLAN.md — Done command + install: scripts/context-reset-test.sh (Phase 2 gate) + install.sh skills copy step

### Phase 3: Self-Improve Loop
**Goal**: Close the compounding loop — threshold-triggered auto-distill drafts candidate lessons from trace evidence, human approves via pending queue, approved lessons are committed to failure-lib and surfaced automatically by existing hooks.
**Depends on**: Phase 2

**Key design constraints (from post-Phase-1 improvements):**
- Lesson format: `id`/`tags`/`when`/`error-match` frontmatter (NOT the old `enforcement-type`/`verifier-check` format — that tier is gone)
- `load-lessons.sh` is the SessionStart hook to extend for SELF-04 pending queue notice
- Approved lessons are committed to `failure-lib/` in the current format; hooks pick them up automatically — no separate "convert to enforcement" step needed
**Requirements**: SELF-01, SELF-02, SELF-03, SELF-04, SELF-05, SELF-06, SELF-07, SELF-08, SELF-09

**Success Criteria** (what must be TRUE — binary, externally checkable):
  1. `./scripts/retro-e2e-test.sh` exits 0 — the script: (a) injects a synthetic repeated failure into failure-lib, (b) triggers the auto-distill threshold, (c) verifies a candidate lesson appears in the pending queue, (d) approves it, (e) verifies the lesson is committed to `~/.claude`
  2. Running auto-distill or `/retro` without a trace file input exits non-zero with a message containing "trace required" — SELF-01 enforced mechanically
  3. Every candidate lesson in the pending queue contains an `evidence:` field citing at least one trace entry (tool name, file, exit code, timestamp) — grep-verifiable in pending-lessons queue files
  4. Duplicate suppression: injecting a lesson already present in failure-lib does not add it to the pending queue — verified by the retro e2e test script (step c)
  5. `model-crutch` rules carry the Claude model version string (e.g., `claude-sonnet-4-6`) — `grep -rL 'claude-' ~/.claude/failure-lib/` on model-crutch-tagged files returns empty after prune step

**Done command:**
```
./scripts/retro-e2e-test.sh
```
**Plans**: 4 plans

Plans:
- [ ] 03-01-PLAN.md — auto-distill.sh engine + pending/ queue scaffold (SELF-01/02/03/05/09)
- [ ] 03-02-PLAN.md — hook extensions: hit tracking, Stop-hook triggers, pending notice (SELF-03/04)
- [ ] 03-03-PLAN.md — /retro skill (approve/run/prune) + install.sh skill install (SELF-06/07/08/09)
- [ ] 03-04-PLAN.md — retro-e2e-test.sh done command + human verification checkpoint (SELF-01..09)

### Phase 4: Heavy Retrieval (CONDITIONAL)
**Goal**: Replace grep-based retrieval in the context pull skill with a vector/hybrid index over failure-lib + docs/, eliminating the miss-rate or latency bottleneck proven by Phase 3 traces.

**GATE: Build only if Phase 3 trace proves grep retrieval is the bottleneck.** If the gate does not open (no measurable miss-rate or latency problem in Phase 3 traces), Phase 4 is deferred indefinitely.

**Depends on**: Phase 3 (and gate must open)
**Requirements**: RETR-01, RETR-02

**Success Criteria** (conditional on gate opening — binary, externally checkable):
  1. RETR-01 gate check: a Phase 3 trace document exists at an agreed path and contains at minimum one entry showing grep miss-rate > threshold or latency > threshold — verified by `./scripts/check-retrieval-gate.sh` before any Phase 4 work begins
  2. The context pull `search` skill uses the vector/hybrid index and returns at least one result for a query that the grep-based search provably missed (regression test fixture required)
  3. Retrieval latency for a 100-entry failure-lib query is below the measured Phase 3 grep baseline — benchmarked and logged by the done script

**Done command (conditional):**
```
# Only run after gate is confirmed open:
./scripts/check-retrieval-gate.sh && ./scripts/retrieval-e2e-test.sh
```
**Plans**: 3 plans

Plans:
- [ ] 04-01-PLAN.md — RETR-01 gate: check-retrieval-gate.sh fresh benchmark + benchmark.py; writes gate-evidence.md only when miss-rate>10% (corpus>=20) OR latency>100ms
- [ ] 04-02-PLAN.md — RETR-02 backend: chromadb build_index.py + hybrid search.py + build-retrieval-index.sh; wire context-pull search (API unchanged) + /retro approve rebuild
- [ ] 04-03-PLAN.md — RETR-02 done command: retrieval-e2e-test.sh + regression fixtures + gate-gated chromadb note in install.sh + human checkpoint

## Progress

**Execution Order:** 0 → 1 → 2 → 3 → 4 (Phase 4 conditional on gate)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. Skeleton + Giavico PoC | 3/3 | Complete | 2026-06-22 |
| 1. Enforcement Hardening | 3/3 | Complete   | 2026-06-22 |
| 2. Context Plane | 2/3 | Complete    | 2026-06-23 |
| 3. Self-Improve Loop | 0/TBD | Not started | - |
| 4. Heavy Retrieval (CONDITIONAL) | 0/TBD | Complete    | 2026-06-24 |
