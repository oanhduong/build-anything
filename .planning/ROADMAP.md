# Roadmap: build-anything

## Overview

build-anything is a versioned global enforcement harness for Claude Code. Phases 0–3 (skeleton, enforcement hardening, context plane, self-improve loop) are complete and verified. Milestone v1.0 — Integrity Layer — closes the two root causes of silent failure: generator self-grading, and execution without a human-confirmed spec. Phases 5–8 deliver independent verification with proof of verifier invocation, a hard spec gate with confirm-token, criterion-aware failure distillation, and structured escalation on retry ceiling.

Phase 4 (heavy retrieval) gate remains closed pending a measured grep bottleneck.

## Milestones

- Previous: v0 Baseline (Phases 0–3) — SHIPPED
- Active: v1.0 Integrity Layer (Phases 5–8) — In progress

## Phases

<details>
<summary>v0 Baseline (Phases 0–3) — SHIPPED</summary>

### Phase 0: Skeleton and Foundation
**Goal**: Preflight passes; all hooks installed, wired, and verified.

### Phase 1: Enforcement Hardening
**Goal**: All enforcement failures auto-blocked; per-project bootstrap live.

### Phase 2: Context Plane
**Goal**: Long tasks survive context reset via PROGRESS.md contract and HANDOFF.md.

### Phase 3: Self-Improve Loop
**Goal**: Lessons distilled from trace evidence and committed via /retro.

</details>

### v1.0 Integrity Layer (Active)

**Milestone goal:** Eliminate generator self-grading and unconstrained execution — every verdict is written by a hook from verifier output, every spec is confirmed by a human-computed token.

- [ ] **Phase 5: Verifier Independence** — stop-hook uses VERIFY_CMD as cheap pre-filter, then delegates per-criterion semantic check to independent verifier subagent; VERDICTS.md written by PostToolUse hook, blocked for manual Write/Edit
- [ ] **Phase 6: Spec Gate** — Write/Edit blocked until human-confirmed SPEC.md with valid sha256 confirm-token exists; generator cannot write a token that stub-reject accepts without going through /spec
- [ ] **Phase 7: Intent-Aware Failure Library** — verifier criterion failures are distilled with criterion tag so lessons link to what was semantically violated, not just what exited non-zero
- [ ] **Phase 8: Structured BLOCKED Exit** — retry ceiling writes BLOCKED-REPORT.md with verdicts; WRITE_COUNT proxy meter enforces COST_CEILING before retries are exhausted

---

## Phase Details

### Phase 5: Verifier Independence

**Goal**: stop-hook runs VERIFY_CMD as a cheap mechanical pre-filter, then invokes independent verifier subagent per criterion; verdicts are captured by a PostToolUse hook into VERDICTS.md, which is blocked for manual Write/Edit — generator cannot self-grade.

**Depends on**: Phases 0–3 (stop-hook, verifier subagent, PROGRESS contract, trace.sh)

**Requirements**: VERIF-01, VERIF-02, VERIF-03

**Decision — VERIFY_CMD fate (resolves LỖ 3):**
VERIFY_CMD is kept as a mechanical pre-filter only. It is NOT a correctness oracle. Flow: (1) VERIFY_CMD fails → exit 2 immediately, no subagent cost; (2) VERIFY_CMD passes → stop-hook invokes verifier subagent per criterion in SPEC.md; (3) all criterion verdicts PASS → stop-hook exits 0. Both gates must pass. Neither gate alone is sufficient. This role is explicit and documented in both Phase 5 and Phase 6.

**Scope IN**:
- `hooks/verdicts-capture.sh` — NEW PostToolUse hook, fires on all tools; scans `tool_response` for the pattern `VERIFIER-VERDICT:` header (unique to verifier.md output format); extracts CRITERION, VERDICT, EVIDENCE lines; appends to `.progress/VERDICTS.md` with timestamp; this is the ONLY write path for VERDICTS.md
- `hooks/stub-reject.sh` — extend PreToolUse: add block if tool target path is `.progress/VERDICTS.md` (message: "VERDICTS.md is hook-written; do not write manually — verdicts must originate from verifier subagent output captured by verdicts-capture.sh")
- `agents/verifier.md` — update output format: response MUST begin with `VERIFIER-VERDICT:` header, followed by `CRITERION: <criterion text>`, `VERDICT: PASS|FAIL`, `EVIDENCE: <what was checked>` on separate lines; remove PARTIAL verdict; one response block per criterion invocation
- `hooks/stop-hook.sh` — replace eval-only block with: (1) run VERIFY_CMD as pre-filter; (2) if pre-filter passes, read criteria list from `.progress/SPEC.md ## Acceptance Criteria`; (3) check `.progress/VERDICTS.md` for a VERDICT: PASS line matching each criterion; (4) if any criterion missing or FAIL → exit 2 with instructions to invoke verifier subagent per criterion; (5) if all PASS → exit 0
- `settings.json` — wire verdicts-capture.sh as PostToolUse hook (all tools matcher)

**Scope OUT**:
- Creating or blocking on SPEC.md (Phase 6)
- confirm-token mechanism (Phase 6)
- Distilling from verifier failures into failure-lib (Phase 7)
- BLOCKED-REPORT.md structure (Phase 8)
- COST_CEILING and WRITE_COUNT (Phase 8)

**Binary exit criterion A (main gate)**: `.progress/SPEC.md` has two criteria, `.progress/VERDICTS.md` is absent → stop-hook exits 2 and stderr contains both criterion strings verbatim. TRUE or FALSE, no partial.

**Binary exit criterion B (verdict integrity)**: Any Write or Edit tool call targeting `.progress/VERDICTS.md` → stub-reject exits 2 with "VERDICTS.md is hook-written" in stderr. TRUE or FALSE, no partial.

**Real run proof — criterion A**:
1. Toy project: PROGRESS.md with CURRENT_TASK and VERIFY_CMD set; SPEC.md with `## Acceptance Criteria` listing two criteria
2. Ensure `.progress/VERDICTS.md` does not exist
3. Run stop-hook: `echo '{"stop_hook_active":false,"cwd":"<path>"}' | bash ~/.claude/hooks/stop-hook.sh`
4. Observe: exit code 2; stderr contains both criterion strings

**Real run proof — criterion B (negative test)**:
1. Attempt Write to `.progress/VERDICTS.md` with valid VERDICT content
2. stub-reject fires: exit 2, stderr contains "VERDICTS.md is hook-written"
3. Confirm: verdicts-capture hook writes VERDICTS.md only when verifier output (with `VERIFIER-VERDICT:` header) is detected in tool response

**Real run proof — full happy path**:
1. VERIFY_CMD passes (pre-filter: `exit 0`)
2. stop-hook checks VERDICTS.md: absent → exit 2, instructs Claude to invoke verifier subagent per criterion
3. Claude invokes verifier subagent for criterion 1 → verifier outputs `VERIFIER-VERDICT:` block → verdicts-capture hook fires → appends to VERDICTS.md
4. Claude invokes verifier for criterion 2 → same hook fires → appends second verdict
5. stop-hook runs again: VERDICTS.md has PASS for both criteria → exit 0

**New rules**:
- `architecture` — VERDICTS.md is exclusively written by verdicts-capture.sh hook; Write/Edit to VERDICTS.md is blocked by stub-reject; this path cannot be bypassed without modifying the hook (which requires an Edit that is logged and out-of-band)
- `architecture` — stop-hook must run VERIFY_CMD as pre-filter before invoking verifier subagent; VERIFY_CMD fail is a fast-exit with no subagent cost; VERIFY_CMD pass is a necessary but not sufficient condition for session stop
- `architecture` — verifier output MUST begin with `VERIFIER-VERDICT:` header; any output without this header is ignored by verdicts-capture; this prevents other subagents from accidentally writing verdicts

**Platform-replaceable**: NO — verdicts-capture.sh depends on PostToolUse hook receiving `tool_response` content from subagent invocations. If Claude Code changes how hook inputs are structured or removes tool_response from PostToolUse, the capture mechanism must be redesigned. The VERDICTS.md format and stop-hook logic are portable; the capture step is not.

**Plans:** 4 plans
Plans:
- [ ] 05-01-PLAN.md — Wave 0: test scaffold (test-verifier-independence.sh, verdicts-capture.sh scaffold, NON_BLOCKING exemption)
- [ ] 05-02-PLAN.md — Wave 1: capture pipeline (verdicts-capture.sh impl, verifier.md schema, stub-reject.sh VERDICTS.md block)
- [ ] 05-03-PLAN.md — Wave 2: stop-hook two-gate flow (VERIFY_CMD pre-filter + per-criterion VERDICTS.md check)
- [ ] 05-04-PLAN.md — Wave 3: settings.json wire + install + full test suite validation

---

### Phase 6: Spec Gate

**Goal**: Write/Edit is blocked until `.progress/SPEC.md` exists with a valid `confirm-token:` — a sha256 hash of the acceptance criteria text computed at human-confirm time by the /spec skill. Generator cannot write a token stub-reject accepts without going through /spec and human confirmation.

**Depends on**: Phase 5 (verifier reads criteria from SPEC.md; SPEC.md format must be stable before gate is built on top of it)

**Requirements**: GATE-01, GATE-02, GATE-03, GATE-04

**Decision — VERIFY_CMD role (resolves LỖ 3, Phase 6 side)**:
VERIFY_CMD in PROGRESS.md functions as the mechanical pre-filter described in Phase 5. It is derived from criteria text in SPEC.md so it is fast and cheap to evaluate. Its role is explicitly NOT semantic correctness — it is a cost-reduction mechanism that skips subagent invocation on obvious failures. Phase 6 removes the Phase 5-era "warn if VERIFY_CMD doesn't match criteria" task and replaces it with a requirement that VERIFY_CMD be derived from criteria at /spec time.

**Confirm-token mechanism (resolves LỖ 2)**:
`confirm-token: <sha256>` where sha256 = `sha256sum` of the exact text content of the `## Acceptance Criteria` section. The /spec skill computes this at confirm time (after human types "confirm") and writes it to SPEC.md header. stub-reject re-derives the sha256 from current criteria content and compares — mismatch means criteria were modified after confirmation, or SPEC.md was written without going through /spec.

**Scope IN**:
- `skills/spec.md` — NEW `/spec` skill: (1) open risk-driven interview — ask only ambiguous/risky parts (what can go wrong, what done looks like, smallest safe change); (2) PROPOSE draft SPEC.md to human — do NOT write yet; (3) wait for explicit "confirm" from human; (4) compute `confirm-token:` = sha256 of `## Acceptance Criteria` section text; (5) write `.progress/SPEC.md` with confirm-token in header; (6) derive VERIFY_CMD from first criterion (cheapest mechanical check) and update PROGRESS.md VERIFY_CMD field
- `hooks/stub-reject.sh` — extend PreToolUse with three new checks (in order): (1) `.progress/SPEC.md` absent → block "SPEC.md absent"; (2) SPEC.md present, no `confirm-token:` field → block "SPEC.md unconfirmed — run /spec and confirm with human"; (3) SPEC.md present, confirm-token field exists but sha256 of current `## Acceptance Criteria` content does not match → block "SPEC.md token invalid — criteria modified after confirmation, re-run /spec"
- `.progress/SPEC.md` — format: frontmatter with `task:`, `confirm-token:`, `confirmed-at:` fields; `## Risk List` section; `## Acceptance Criteria` section (at least one criterion); `## Verify Command` note

**Scope OUT**:
- Verifier subagent invocation per criterion (Phase 5)
- Distillation from verifier failures (Phase 7)
- BLOCKED-REPORT.md (Phase 8)
- Auto-generating SPEC.md without human confirmation — hard architectural invariant, never in scope
- Enforcing criteria quality beyond structural presence (human responsibility)

**Binary exit criterion A (gate — absent)**: Write tool call when `.progress/SPEC.md` does not exist → stub-reject exits 2 with "SPEC.md absent" in stderr. TRUE or FALSE.

**Binary exit criterion B (gate — unconfirmed)**: Write tool call when `.progress/SPEC.md` exists with `## Acceptance Criteria` but no `confirm-token:` field → stub-reject exits 2 with "SPEC.md unconfirmed" in stderr. TRUE or FALSE.

**Binary exit criterion C (gate — tampered)**: Write tool call when SPEC.md has `confirm-token:` but criteria text was modified after confirmation → stub-reject exits 2 with "SPEC.md token invalid" in stderr. TRUE or FALSE.

**Real run proof — criteria A + B + C (negative tests)**:
1. Remove SPEC.md → attempt Write → blocked "absent" ✓
2. Write SPEC.md with `## Acceptance Criteria` section but no `confirm-token:` field → attempt Write → blocked "unconfirmed" ✓
3. Write SPEC.md with valid confirm-token, then edit criteria text → attempt Write → blocked "token invalid" ✓

**Real run proof — happy path**:
1. Run `/spec` on toy task
2. /spec asks 3 risk-driven questions about the task
3. /spec proposes draft SPEC.md for review
4. Human types "confirm"
5. /spec computes sha256 of criteria text, writes `.progress/SPEC.md` with `confirm-token:` field, updates PROGRESS.md VERIFY_CMD
6. Attempt Write → passes through (SPEC.md present, token valid)
7. Verifier in Phase 5 reads criteria from this SPEC.md ✓

**New rules**:
- `architecture` — Write/Edit is unconditionally blocked without a human-confirmed SPEC.md with valid confirm-token; no bypass, no override, no fallback to VERIFY_CMD alone
- `architecture` — `/spec` skill must propose draft and receive explicit human "confirm" before computing token and writing SPEC.md; auto-confirm is structurally prohibited
- `architecture` — confirm-token is sha256 of `## Acceptance Criteria` section text; any modification to criteria after confirmation invalidates the token and blocks execution
- `model-crutch claude-sonnet-4-6` — risk-driven interview questions in spec.md skill may need tuning as model risk-assessment behavior changes; the confirm-token mechanism is architecture and must not be pruned with model upgrades

**Platform-replaceable**: PARTIAL — stub-reject.sh token check is pure shell (sha256 via shasum -a 256, available on macOS/Linux), platform-independent. The `/spec` skill depends on Claude Code skill invocation format; if slash command primitive changes, skill file must be updated. Token mechanism itself is portable.

---

### Phase 7: Intent-Aware Failure Library

**Goal**: Failures that originate from verifier criterion verdicts are distilled into pending lessons tagged with the violated criterion, so future sessions surface lessons relevant to the specific acceptance criterion that failed — not just what shell command exited non-zero.

**Depends on**: Phase 5 (verifier produces VERDICT: FAIL per criterion before distill path triggers); Phase 6 (criteria exist in SPEC.md before lessons can be tagged against them)

**Requirements**: DIST-01, DIST-02, DIST-03

**Scope IN**:
- `scripts/auto-distill.sh` — add optional `--criterion "<text>"` argument; when provided, drafted lesson frontmatter includes `criterion: <text>` field; when absent, criterion field is empty string (backwards compatible with existing Bash-error distill path)
- `failure-lib/*.md` schema — document `criterion:` as a valid optional frontmatter field alongside `when:`, `error-match:`, `evidence:`, `tags:`; non-empty criterion means lesson was distilled from a semantic verification failure, not a shell exit
- `hooks/stop-hook.sh` — after reading VERDICTS.md, for each `VERDICT: FAIL` line, call `auto-distill.sh --criterion "<criterion text>"` with trace log; this fires BEFORE the exit 2 that sends Claude back to fix

**Scope OUT**:
- Retroactive criterion-tagging of existing failure-lib entries (only new entries from verifier failures get criterion field)
- Semantic search or filtering by criterion tag (Phase 4 gate still closed)
- Changing /retro approve/reject flow (Phase 3 shipped, unchanged)
- Any lesson auto-approval (human must still run /retro)

**Binary exit criterion**: After stop-hook processes a `VERDICT: FAIL` for criterion "grep -q 'function foo' main.sh" in VERDICTS.md → `grep -rl 'criterion: grep' ~/.claude/failure-lib/pending/` returns at least one file. TRUE or FALSE.

**Real run proof**:
1. Toy project: VERDICTS.md with `VERDICT: FAIL` for criterion "grep -q 'function foo' main.sh"
2. Run stop-hook (BLOCKED_COUNT below ceiling)
3. stop-hook reads FAIL verdict, calls `auto-distill.sh --criterion "grep -q 'function foo' main.sh"` with trace log
4. `grep -rl 'criterion:' ~/.claude/failure-lib/pending/` → new file present
5. `grep 'criterion:' ~/.claude/failure-lib/pending/<new-file>.md` shows `criterion: grep -q 'function foo' main.sh`
6. Confirm backwards compat: existing Bash-exit lessons have empty `criterion:` field

**New rules**:
- `architecture` — failure-lib entries sourced from verifier criterion failures MUST carry non-empty `criterion:` field; empty criterion means lesson was distilled from a shell exit, not a semantic check
- `model-crutch claude-sonnet-4-6` — prose in lesson body drafted by auto-distill may need refinement as model summarization changes; `criterion:` field is the stable contract, not the prose

**Platform-replaceable**: YES — auto-distill.sh is pure bash with no Claude Code API dependency. sha256 not needed here. Criterion argument is a string passed through shell. Fully portable.

---

### Phase 8: Structured BLOCKED Exit

**Goal**: When retry ceiling is reached, stop-hook writes `.progress/BLOCKED-REPORT.md` with per-criterion verdicts and escalation guidance. WRITE_COUNT proxy meter (incremented by existing progress-after-edit.sh on every Write/Edit) enforces optional COST_CEILING before retries are exhausted.

**Depends on**: Phases 5–7 (core verification and distillation loops must work before robustness layer is added)

**Requirements**: BLOCK-01, BLOCK-02

**Decision — cost meter (resolves LỖ 4)**:
`WRITE_COUNT:` field in PROGRESS.md, incremented by `progress-after-edit.sh` on each Write/Edit (hook already runs, minimal addition). `COST_CEILING:` field in PROGRESS.md = max allowed Write/Edit operations before early BLOCKED. stop-hook checks: if WRITE_COUNT >= COST_CEILING, write BLOCKED-REPORT.md and exit 0 before attempting retry. Cost unit is explicitly "write/edit operations" — a rough but measurable proxy. Documented as proxy, not exact token count.

**Scope IN**:
- `hooks/progress-after-edit.sh` — add one line: increment `WRITE_COUNT:` in PROGRESS.md on each Write/Edit (same hook that already appends HISTORY LOG)
- `hooks/stop-hook.sh` — two additions: (1) on BLOCKED_COUNT >= CEILING: write `.progress/BLOCKED-REPORT.md` with task name, BLOCKED_COUNT, each criterion from SPEC.md, per-criterion verdict from VERDICTS.md (or "no verdict recorded" if absent), recommended escalation step; exit 0; (2) on WRITE_COUNT >= COST_CEILING (if field present): write BLOCKED-REPORT.md and exit 0 early
- `hooks/bootstrap-project.sh` — add `WRITE_COUNT: 0` to PROGRESS.md template so field is always present
- `.progress/BLOCKED-REPORT.md` — new artifact with fixed schema: `## Task`, `## Attempts`, `## Criteria Attempted`, `## Verdicts`, `## Recommended Escalation`

**Scope OUT**:
- Automated escalation to external systems (report is for human reading only)
- Exact token counting (WRITE_COUNT is a proxy; precise accounting is out of scope)
- Changing BLOCKED_COUNT increment logic (Phase 0–1 behavior unchanged)
- Modifying verifier or spec gate (Phases 5–6)
- Criterion distillation (Phase 7)

**Binary exit criterion A (ceiling)**: PROGRESS.md has BLOCKED_COUNT: 3 and CEILING is 3 → stop-hook exits 0 AND `.progress/BLOCKED-REPORT.md` exists with string "VERDICT" in it. TRUE or FALSE.

**Binary exit criterion B (cost ceiling)**: PROGRESS.md has COST_CEILING: 1 and WRITE_COUNT: 1 → stop-hook writes BLOCKED-REPORT.md and exits 0 without incrementing BLOCKED_COUNT. TRUE or FALSE.

**Real run proof — criterion A**:
1. Toy project: BLOCKED_COUNT: 3, CURRENT_TASK set, SPEC.md with two criteria, VERDICTS.md with one PASS and one FAIL
2. Run stop-hook
3. Ceiling detected: BLOCKED-REPORT.md written; exit 0
4. `cat .progress/BLOCKED-REPORT.md` shows task, both criteria, one PASS, one FAIL, escalation note with string "VERDICT"

**Real run proof — criterion B**:
1. PROGRESS.md with COST_CEILING: 1, WRITE_COUNT: 1, BLOCKED_COUNT: 0
2. Run stop-hook
3. WRITE_COUNT >= COST_CEILING detected: BLOCKED-REPORT.md written; exit 0; BLOCKED_COUNT unchanged (early exit, not a retry failure)

**New rules**:
- `architecture` — hitting BLOCKED ceiling MUST produce BLOCKED-REPORT.md before allowing stop; silent ceiling exit is prohibited
- `architecture` — WRITE_COUNT proxy is incremented by progress-after-edit.sh; stop-hook reads it for COST_CEILING comparison; no other hook may increment WRITE_COUNT
- `model-crutch claude-sonnet-4-6` — prose in BLOCKED-REPORT.md escalation step may need tuning; structured fields (task, criteria, verdicts) are the stable contract

**Platform-replaceable**: YES — pure bash; no Claude Code API dependency. BLOCKED-REPORT.md is plain markdown with fixed schema. Fully portable.

---

## Progress

**Execution order:** 5 → 6 → 7 → 8

**Ordering rationale:**
- Phase 5 first: verdict integrity (hook-written VERDICTS.md) gates correctness of all downstream phases — if Phase 6/7/8 artifacts are wrong, Phase 5 catches it
- Phase 6 second: confirm-token gate prevents bad tasks from starting; requires working verifier (Phase 5) to validate spec artifacts
- Phase 7 third: depends on Phase 5 (verifier generates FAIL verdicts to distill from) and Phase 6 (criteria exist to tag violations against)
- Phase 8 last: polish and robustness; core loops 5/6/7 must work first; WRITE_COUNT meter is a minor hook addition

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 0. Skeleton | v0 Baseline | Complete | Complete | 2026-06-29 |
| 1. Enforcement Hardening | v0 Baseline | Complete | Complete | 2026-06-29 |
| 2. Context Plane | v0 Baseline | Complete | Complete | 2026-06-29 |
| 3. Self-Improve Loop | v0 Baseline | Complete | Complete | 2026-06-29 |
| 5. Verifier Independence | v1.0 Integrity Layer | 4 plans | In progress | — |
| 6. Spec Gate | v1.0 Integrity Layer | 0/TBD | Not started | — |
| 7. Intent-Aware Library | v1.0 Integrity Layer | 0/TBD | Not started | — |
| 8. Structured BLOCKED Exit | v1.0 Integrity Layer | 0/TBD | Not started | — |

---
*Roadmap updated: 2026-06-30 — v2 after integrity gap review*
*Milestone v1.0 — Integrity Layer: 12/12 requirements mapped, 0 orphaned*
