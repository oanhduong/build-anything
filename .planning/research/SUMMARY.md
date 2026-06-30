# Project Research Summary

**Project:** Signature Harness Kit
**Domain:** Claude Code global enforcement layer / agent harness
**Researched:** 2026-06-22
**Confidence:** HIGH

## Executive Summary

The Signature Harness Kit is a two-layer enforcement system for Claude Code: a global signature layer at `~/.claude/` (versioned as a git repo) and a thin project layer (`repo/CLAUDE.md` + `.claude/`). The central insight from all four research files is that CLAUDE.md is advisory context, not an enforcement primitive. Hooks are the only reliable enforcement mechanism in Claude Code, and they have specific, non-obvious semantics that must be validated before any real work starts. The architecture maps cleanly to Claude Code's native loading order — no symlinks, no copy-paste, no abstraction layer needed.

The recommended build order is evidence-first: establish the minimal hook skeleton and run one real task (Giavico PoC) before adding anything. Phase 0 has seven mandatory safety checks that must exist before the PoC run — exit-code tests, chmod preflight, PROGRESS schema, trace hook, stop-hook loop guard, read-only protection on the feature requirements file, and CLAUDE.md stable-top ordering. Skipping any of these produces silent failures that are extremely difficult to diagnose after the fact, because the hooks appear to work in isolation while failing inside Claude Code.

The compounding value of the kit depends entirely on three structural commitments: (1) the verifier is always a separate subagent with `disallowedTools: Write, Edit` so it cannot rationalize broken output; (2) every lesson from `/retro` passes a human gate before becoming an enforcement rule — never auto-applied; (3) the failure library is the authoritative state, not CLAUDE.md prose. Any lesson not encoded as a hook, linter rule, or verifier check will be forgotten within two builds.

---

## Key Findings

### Recommended Stack

The harness is built entirely on Claude Code's five native primitives. No external framework needed.

**Core primitives:**
- **Hooks API** (`command` type, `PreToolUse`/`PostToolUse`/`Stop`): the only reliable enforcement layer; shell scripts reading JSON from stdin
- **Skills** (`~/.claude/skills/<name>/SKILL.md`): the current canonical format; supersedes `.claude/commands/`; supports hot-reload, frontmatter control, and forked subagent context
- **Settings merge** (`~/.claude/settings.json` + `.claude/settings.json`): array keys combine additively; scalar keys project-wins; global hooks apply to all projects automatically
- **Subagents** (`~/.claude/agents/verifier.md`): user-scope; available in every project without project-side declaration; runs in isolated context window
- **CLAUDE.md loading order**: `~/.claude/CLAUDE.md` first, then project root; stable content is prefix-cached at >98% hit rate when top content does not change

**Critical version note:** The `agent` hook handler type is experimental. Use `command` type for all Phase 0 enforcement hooks.

### Expected Features

**Must have (table stakes):**
- CLAUDE.md as ~100-line TOC with stable content at top (KV-cache requirement)
- `PreToolUse`/`PostToolUse`/`Stop` hooks with correct exit codes and stderr messaging
- Verifier subagent structurally separated from generator (separate context window, read-only tools)
- PROGRESS file updated by `PostToolUse` hook after every edit (hook-enforced, not advisory)
- File-based failure library (`~/.claude/failure-lib/`) with INDEX.md for grep retrieval
- Skills as numbered procedures with explicit stop conditions (`~/.claude/skills/<name>/SKILL.md` format)

**Should have (differentiators):**
- Compounding loop: lesson → human approval → enforcement rule → committed to signature repo
- Rule tagging: `architecture` (permanent) vs `model-crutch` (prune on model upgrade)
- KV-cache optimized CLAUDE.md structure (stable first, dynamic excluded entirely)
- Language-agnostic hooks (text patterns and exit codes only, no language runtime imports)
- Human gate on every self-improvement step (agent proposes; human commits)

**Defer to Phase 3+:**
- `/retro` command (needs a body of PROGRESS + failure entries to be useful)
- Prune step for model-crutch rules (needs tagged rules to exist first)
- Context plane pull tools (conditional on trace proving retrieval is the bottleneck)
- Vector/semantic search on failure library (Phase 4, conditional on evidence)

### Architecture Approach

Two layers, no abstraction in between. The project layer never copies signature assets — it uses them via Claude Code's native loading order. Updating `~/.claude/` propagates to every project on next session start automatically.

**Major components:**
1. `~/.claude/hooks/` + `lib/common.sh` — enforcement scripts; thin event-specific wrappers calling shared `write_progress()`, `write_failure()`, `get_project_root()` functions
2. `~/.claude/agents/verifier.md` — read-only subagent (`disallowedTools: Write, Edit`); plain-text verdict format (`VERDICT: PASS|FAIL|PARTIAL`) not JSON
3. `~/.claude/failure-lib/failures/<YYYY-MM-DD>-<project>-<slug>.md` + `INDEX.md` — flat-file database; INDEX is what verifier and `/retro` read for discovery; individual files hold full context
4. `<project>/.progress/PROGRESS.md` — two sections: `CURRENT STATE` (overwritten each session) and `HISTORY LOG` (append-only one-liners); new sessions read `CURRENT STATE` only
5. `~/.claude/skills/` — `/handoff`, `/retro`, `/start-project`; all human-written; SKILL.md format

### Critical Pitfalls

1. **Exit code 1 is not blocking** — Only `exit 2` blocks in Claude Code. Hooks using `exit 1` appear to work in isolation but silently let actions proceed inside the tool chain. Validate every hook with an exit-code test before the first run.
2. **stdout/stderr inversion corrupts the protocol** — Hooks must write human-readable messages to stderr (`>&2`), never to stdout. stdout is the JSON machine-readable channel. Any non-JSON on stdout causes silent protocol failure.
3. **PROGRESS content in CLAUDE.md invalidates the prefix cache** — PROGRESS changes every edit. One dynamic line at the top of CLAUDE.md forces full re-tokenization every turn. Inject PROGRESS in skills via backtick syntax only.
4. **Generator grading its own output produces grade inflation** — LLM self-verification error rates above 50% in 2025-2026 audits. The verifier must be a separate subagent with read-only tools and deterministic checks first.
5. **Stop hook infinite loop** — If the condition a Stop hook checks is never cleared, the session loops forever with no human signal. Every Stop hook needs a max retry counter and must return `decision: allow` when `stop_hook_active: true` in its input.

---

## Top 7 Watch-Outs That Affect Phase Design

Cross-cutting findings that appear across all four research files. These affect phase sequencing and acceptance criteria.

**1. The enforcement triad must be verified atomically.** Exit code 2 (not 1), stderr (not stdout), and chmod +x are three separate silent failure modes. Any one of them makes enforcement look operational while being completely inactive. All three must be verified with a test suite before any real work starts.

**2. CLAUDE.md is advisory; hooks are guarantees.** The formula is firm: dangerous actions go in `PreToolUse` hooks (exit 2); repeatable workflows go in Skills; style preferences go in CLAUDE.md. Document the rule in CLAUDE.md; enforce it in the hook. Never rely on CLAUDE.md alone for anything that must not be violated.

**3. SKILL.md format supersedes `.claude/commands/`.** New skills go in `~/.claude/skills/<name>/SKILL.md`. The slash command name comes from the directory name. Skills support `context: fork`, `agent: verifier`, `disallowed-tools`, `paths` scoping, and hot-reload. Legacy `.claude/commands/` files continue to work but are not the path for new work.

**4. The verifier must be structurally incapable of writing.** `disallowedTools: Write, Edit` in `~/.claude/agents/verifier.md` enforces this at the platform level. Check priority: (1) deterministic checks (compile, tests, stub grep) → (2) failure-lib domain rule checks → (3) LLM-as-judge last. A >90% first-attempt pass rate is a red flag — the eval is not hard enough.

**5. PROGRESS must not be in CLAUDE.md.** PROGRESS changes every edit. Inlining it breaks the KV-cache prefix for the entire CLAUDE.md every turn. PROGRESS lives in `.progress/PROGRESS.md`, updated by the `PostToolUse` hook, and injected into skill prompts via backtick shell execution syntax when needed.

**6. Phase 0 has 7 mandatory preflight checks.** All seven must exist and be verified before the Giavico PoC run: (a) exit-code tests on every hook; (b) chmod verified on all hook scripts; (c) PROGRESS file schema defined (CURRENT STATE + HISTORY LOG); (d) minimal PostToolUse trace hook; (e) Stop hook loop guard with max retry counter; (f) read-only PreToolUse hook on feature requirements file; (g) CLAUDE.md stable-top ordering with no timestamps or dynamic content in first 50 lines.

**7. The two-layer architecture uses Claude Code's native loading — no symlinks needed.** `~/.claude/settings.json` hook arrays combine additively with project `.claude/settings.json`. `~/.claude/agents/verifier.md` is available in every project automatically. `~/.claude/skills/` skills are available everywhere. The project CLAUDE.md does not need to declare the signature layer — it is already loaded.

---

## Implications for Roadmap

### Phase 0: Skeleton + Enforcement Preflight
**Rationale:** Nothing else is trustworthy until the hook enforcement triad is verified. All seven mandatory preflight checks must pass before the Giavico PoC run.
**Delivers:** `~/.claude/` git repo initialized; `common.sh` with shared functions; `write-progress.sh` and `grep-stubs-reject.sh` hooks wired in `settings.json`; `verifier.md` with `disallowedTools: Write, Edit`; `/handoff` skill; failure-lib skeleton; PROGRESS schema; minimal trace hook; read-only guard on requirements file; CLAUDE.md stable-top ordering. One clean end-to-end Giavico run producing the first failure-lib entries.
**Must avoid:** Exit-code confusion, stdout/stderr confusion, chmod omission, PROGRESS content in CLAUDE.md, Stop hook infinite loop, verifier grading its own output, feature requirements file modified by agent.
**Research flag:** No additional research needed — all primitives documented at HIGH confidence. Giavico domain (Excel ingestion, schema detection) may need domain research during execution.

### Phase 1: Enforcement Hardening
**Rationale:** Phase 0 leaks become Phase 1 enforcement rules. No rule is added without a named failure case that motivated it.
**Delivers:** All Phase 0 failure records converted to hooks or verifier checks; rule tagging (`architecture` vs `model-crutch`) applied to every rule; language-agnostic test applied to every rule before approval; conflict check added to approval workflow; grep retrieval wired from `/retro` into failure-lib INDEX.
**Must avoid:** Language-specific rules in global signature repo; lessons in CLAUDE.md prose without a mechanical enforcer; failure library growing without a retrieval path.
**Research flag:** Standard patterns. No additional research needed.

### Phase 2: Context Plane
**Rationale:** Build only after Phase 1 trace shows context loss is a real bottleneck — not a hypothesis.
**Delivers:** `/retro` skill reading PROGRESS + failure-lib; KV-cache ordering formally documented and enforced by CI; `/handoff` skill upgraded to structured schema (current file, last command exact, last error exact, next command exact — no prose allowed); `PreCompact` hook archiving transcript before compaction; `# Summary instructions` section in CLAUDE.md for compactor guidance.
**Must avoid:** Building context machinery before trace proves the leak; CLAUDE.md growing past 40KB (add CI check); mid-session CLAUDE.md edits mistaken for live enforcement.
**Research flag:** KV-cache prefix invalidation boundary — verify empirically if cache costs are not decreasing as expected.

### Phase 3: Self-Improvement Loop
**Rationale:** Requires a real corpus of PROGRESS entries and failure records from Phases 0-2. A `/retro` run without trace input produces speculative lessons that cannot be converted to hooks.
**Delivers:** `/retro` upgraded to propose candidate lessons with required `evidence` field (specific trace event) and `lesson` field; human approval gate with conflict check as mandatory step; new failure records committed to signature repo; periodic prune step for model-crutch rules annotated with motivating model version.
**Must avoid:** Retro running without a trace input file; lessons approved without evidence; auto-mutation of enforcement layer; model-crutch rules accumulating past 10 without a prune event.
**Research flag:** Review Trace2Skill (arxiv 2603.25158) and EvolveR patterns before designing the `/retro` lesson-proposal output schema.

### Phase 4: Heavy Retrieval (Conditional)
**Rationale:** Only if Phase 3 trace proves grep-based retrieval is the actual bottleneck. Do not build speculatively.
**Delivers:** Semantic/vector retrieval on failure library; context plane pull tools for long-task resumption.
**Gate:** Trace evidence required — not a hypothesis.
**Research flag:** Needs research if gate opens. Vector DB selection, embedding model dependency, index maintenance tradeoffs, "lost in the middle" retrieval failure mitigation.

### Phase Ordering Rationale

- Enforcement correctness (Phase 0-1) must precede self-improvement (Phase 3) because lessons learned from a broken harness are garbage-in lessons.
- Context machinery (Phase 2) comes after enforcement hardening (Phase 1) because it depends on the PROGRESS file and trace being reliable — neither is reliable until Phase 1 enforcement is complete.
- Vector retrieval (Phase 4) is explicitly conditional and evidence-gated to prevent the most common harness failure mode: building complexity before the actual bottleneck is known.
- The Giavico PoC in Phase 0 is the evidence-collection event that determines what Phases 1-4 need to build. It is not a demo.

### Research Flags

Needs deeper research during planning:
- **Phase 3:** Lesson distillation prompt format — review Trace2Skill (arxiv 2603.25158) before designing `/retro` output schema
- **Phase 4 (if gate opens):** Vector index selection for failure library at scale

Standard patterns (skip research-phase):
- **Phase 0:** All primitives documented at HIGH confidence from official Claude Code docs
- **Phase 1:** Enforcement rule management follows standard patterns established in Phase 0
- **Phase 2:** CLAUDE.md structure and KV-cache behavior well-documented; context plane follows PROGRESS schema designed in Phase 0

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All five primitives fetched directly from official Claude Code docs 2026-06-22 |
| Features | HIGH | Table stakes verified in official docs; differentiators from multiple consistent practitioner sources |
| Architecture | HIGH | Two-layer model maps directly to Claude Code's documented loading order and settings merge behavior |
| Pitfalls | HIGH (hooks, KV cache, verifier) / MEDIUM (self-improvement) | Hook exit codes, stdout/stderr, chmod verified in official docs and confirmed by multiple community post-mortems |

**Overall confidence:** HIGH

### Gaps to Address

- **`additionalContext` injection format for self-fix:** What format in PostToolUse JSON output produces best model self-correction? Validate empirically during Phase 1 hook refinement.
- **KV-cache invalidation boundary:** Exact token boundary not fully documented. Validate empirically during Phase 2 by monitoring cache hit behavior.
- **Stop hook `stop_hook_active` field:** Exact field name and behavior when a Stop hook has already blocked once. Verify against live platform before writing the Phase 0 stop hook.
- **Subagent session restart requirement:** Whether `~/.claude/agents/` user-scope agents require session restart after edits (unlike skills which hot-reload). Confirm before designing Phase 0 install flow.

---

## Sources

### Primary (HIGH confidence — official Claude Code docs, fetched live 2026-06-22)
- `https://code.claude.com/docs/en/hooks` — hook events, exit codes, stdin/stdout protocol, timeout constraints
- `https://code.claude.com/docs/en/skills` — SKILL.md format, frontmatter fields, slash command naming
- `https://code.claude.com/docs/en/sub-agents` — subagent definition format, disallowedTools, permissionMode, memory field
- `https://code.claude.com/docs/en/memory` — CLAUDE.md loading order, KV-cache behavior, auto memory
- `https://code.claude.com/docs/en/settings` — settings merge order, permissions syntax, env injection
- `https://code.claude.com/docs/en/best-practices` — CLAUDE.md size limits, skill design patterns

### Secondary (MEDIUM-HIGH confidence — multiple consistent practitioner sources)
- Konishi harness engineering guide — hook design, common failure modes
- Blake Crosley 95-hook autopsy — over-hooking consequences, per-hook overhead benchmarks
- sd0x-dev-flow reference harness — dual-reviewer architecture, PROGRESS state pattern
- ShipWithAI five-layer harness guide — six configurations that defeat a harness

### Tertiary (MEDIUM confidence — research / academic)
- Trace2Skill (arxiv 2603.25158) — skill distillation from trajectories; relevant for Phase 3 /retro design
- VerifiAgent (arxiv 2504.00406) — verifier architecture patterns
- InfiAgent (arxiv 2601.03204) — workspace state pattern (PROGRESS file design)

---
*Research completed: 2026-06-22*
*Ready for roadmap: yes*
