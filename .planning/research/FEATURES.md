# Feature Landscape: Claude Code Signature Harness Kit

**Domain:** Agent harness layer for Claude Code (Anthropic CLI)
**Researched:** 2026-06-22
**Research mode:** Ecosystem — what patterns exist and which matter

---

## Research Notes

**Confidence levels:**
- HIGH = verified in official Claude Code docs (code.claude.com) or multiple consistent sources
- MEDIUM = verified in at least two community/practitioner sources with consistent findings
- LOW = single source or unverified claim; treat as a hypothesis

**Key sources used:**
- Official Claude Code best practices: https://code.claude.com/docs/en/best-practices
- Official Claude Code hooks reference: https://code.claude.com/docs/en/hooks
- Hidekazu Konishi harness engineering guide (comprehensive practitioner article)
- Blake Crosley's 95-hook autopsy (real lessons from over-engineering)
- sd0x-dev-flow GitHub harness (state machine + dual-review reference impl)
- ShipWithAI harness engineering guide (five-layer model)
- Arize AI agent failure analysis
- Trace2Skill paper (arxiv 2603.25158, skill distillation from trajectories)

---

## Table Stakes

Features without which the kit does not deliver its stated core value. If these are missing, the kit is just a CLAUDE.md template.

---

### 1. CLAUDE.md as Table of Contents, Not Instruction Dump

**Why expected:** Claude Code's official docs and every serious practitioner source agree on one rule — CLAUDE.md must stay under ~150-200 lines or instruction adherence drops. Long files cause rules to be silently ignored. The `@import` mechanism exists precisely to offload detail into separate files that Claude pulls on demand.

**What this means for the kit:**
- Project-layer CLAUDE.md ~100 lines acting as a TOC that imports docs/* files
- Stable, rarely-changing content at the top of the file for KV-cache hit rate (Claude Code achieves >98% cache hits on CLAUDE.md content that doesn't change between sessions; unstable content at the top breaks prefix matching and forces full re-tokenization)
- Separation of: always-loaded rules (what never changes) vs. skill files loaded on demand (domain knowledge, workflow procedures)

**Confidence:** HIGH (official docs + HN thread confirming cache behavior + practitioner consensus)

---

### 2. Enforcement Hooks (PreToolUse / PostToolUse)

**Why expected:** CLAUDE.md is advisory. The model can override any instruction given sufficient context pressure. A PreToolUse hook exiting with code 2 is the only mechanism in Claude Code that unconditionally blocks a tool call — it cannot be talked out of by the model. This distinction (enforcement vs. advice) is the foundational insight of harness engineering.

**What this means for the kit:**
- PreToolUse hooks for blocking: destructive operations, stubs/TODO markers being committed, writes to protected paths
- PostToolUse hooks for teaching: running linters after file edits and injecting error output back as `additionalContext` (the model sees the lint failure and self-corrects)
- Stop hooks for gating: check PROGRESS file was updated before allowing turn to end
- Exit code 2 = block; exit code 0 = allow; exit code 1 = warn only (non-blocking). This is critical — many practitioners accidentally use exit 1 thinking it blocks, but it does not.
- Hook error messages written as teaching text, not bare error codes — this is what converts a rejection into a self-fix

**Confidence:** HIGH (official hooks reference, Blake Crosley 95-hook article, Konishi guide all consistent)

---

### 3. Verifier Subagent Structurally Separated from Generator

**Why expected:** The generator-grading-itself problem produces consistent grade inflation. Fresh context sees only the diff and the criteria — not the reasoning that produced the change — so it evaluates the result on its own terms. This pattern appears in official Claude Code docs, the sd0x-dev-flow dual-reviewer architecture, and in the academic agent evaluation literature (VeriLA, VerifiAgent).

**What this means for the kit:**
- Verifier runs as a `.claude/agents/` subagent in its own context window
- Priority order: deterministic checks (code compiles, tests pass, binary criteria) → domain rule checks → LLM-as-judge last
- LLM-as-judge is the most expensive and least reliable check; use it only for things that cannot be checked deterministically
- Reviewer prompted to find gaps will over-report; instruct it to flag only gaps affecting correctness, not style preferences (official docs warning: "chasing every finding leads to over-engineering")
- The verifier does not fix — it reports. Fixing is the generator's job. Structural separation is non-negotiable.

**Confidence:** HIGH (official Claude Code docs, dual-reviewer pattern in sd0x-dev-flow, academic literature)

---

### 4. PROGRESS File (State Lives in Files, Not Context Window)

**Why expected:** 80% of AI agent production failures are attributed to state management issues rather than prompt quality (Fast.io state management survey). Long-running tasks span context resets. Context compaction is automatic and aggressive. Without external state, every session restart requires reconstructing what happened — which the model cannot do reliably from a compacted transcript.

**What this means for the kit:**
- PROGRESS file updated after every file edit (enforced by PostToolUse hook, not advisory)
- File contains: current phase, last completed step, open stubs, blockers, handoff note
- Structured format that survives `/compact` — the compaction hook preserves file state even when conversation is compressed
- Three-file pattern validated in production: current-task (what's happening now), progress log (what happened), standing rules (what always applies)
- Idempotency: checking PROGRESS before starting a step prevents redundant work when resuming

**Confidence:** HIGH (multiple practitioner sources, InfiAgent workspace pattern, sd0x-dev-flow `[AUTO_LOOP_RESUME]` injection)

---

### 5. File-Based Failure Library

**Why expected:** The insight from Mitchell Hashimoto's Ghostty approach (cited in ShipWithAI guide) is: CLAUDE.md should be an incident log, not an aspirational wishlist. Every constraint in the file should trace to a prior agent failure. Without a structured failure library, lessons from one build evaporate — they never make it into the next project's enforcement layer.

**What this means for the kit:**
- Failure entries stored as structured markdown files in a versioned global directory (~/.claude/failures/ or similar)
- Each entry: what went wrong, what the agent did, what the correct behavior is, what rule prevents recurrence
- Failures are tagged: `architecture` (permanent rule) vs `model-crutch` (current-model weakness, prune when model improves)
- File-based in v1 — no vector DB, no semantic search. The search space is small enough that grep + file structure is sufficient. Premature vector indexing adds operational complexity before the failure corpus is large enough to warrant it.
- Failures feed the `/retro` command input

**Confidence:** MEDIUM (Ghostty/Hashimoto reference in practitioner sources; file-based approach is a design decision for v1, not an established community standard)

---

### 6. Skills as Numbered Procedures with Explicit Stop Conditions

**Why expected:** Official Claude Code docs establish the Skills pattern — SKILL.md files under .claude/skills/ that define reusable workflows. The key failure mode for unbounded agent tasks is the model interpreting "investigate X" as license to read hundreds of files, exhausting context. Numbered procedures with explicit stop conditions bound the task scope.

**What this means for the kit:**
- Each SKILL.md: numbered steps (1, 2, 3...), explicit stop condition per step ("stop if test suite passes"), definition of done
- Skills are human-written — agent-generated skills are excluded from scope (the model can write code that satisfies a spec but cannot reliably write a skill that enforces its own behavior)
- Skills stay under 200 lines; longer skills should be decomposed
- `disable-model-invocation: true` for skills with side effects that require manual trigger
- Skills invoked with `/skill-name` pattern or triggered automatically when relevant

**Confidence:** HIGH (official Claude Code docs, official skills reference)

---

## Differentiators

What makes this kit meaningfully better than a hand-rolled CLAUDE.md. None of these are expected by users — but they compound value over time.

---

### D1. Lessons Become Enforcement (The Compounding Loop)

**What:** Every lesson from `/retro` passes human review and converts directly into a hook, linter rule, or verifier check. The lesson doesn't just live in documentation — it actively gates future behavior.

**Why it differentiates:** Most hand-rolled CLAUDE.md files accumulate advisory text that the model eventually ignores. The conversion pipeline (lesson → human approval → enforcement rule → committed to signature repo) closes the loop. A lesson from project N prevents the same failure in project N+1 automatically.

**How it works:**
- `/retro` reads PROGRESS file + failure log + session trace → proposes candidate lessons
- Human reviews and approves/rejects each candidate
- Approved lessons convert to: hook (if it's about blocking a tool call), linter rule (if it's about code structure), verifier check (if it's about output quality), or SKILL.md addition (if it's about workflow procedure)
- The enforcement rule is tagged with its origin failure for future pruning context

**Confidence:** MEDIUM (pattern synthesized from practitioner sources; the specific pipeline is the kit's design, not an established standard)

---

### D2. Rule Tagging: `architecture` vs `model-crutch`

**What:** Every enforcement rule is tagged at creation time as either `architecture` (a constraint that should last forever, e.g., "never rebuild Claude Code's engine") or `model-crutch` (a workaround for a current model weakness, e.g., "always check for stub functions before committing"). Model-crutch rules are candidates for pruning when model capability improves.

**Why it differentiates:** Without this distinction, enforcement rules accumulate indefinitely. Rules written to work around GPT-4-level weaknesses become noise when applied to more capable models, and noise in enforcement degrades compliance. The tagging system makes the rule corpus auditable and prunable.

**How it works:**
- Every hook, linter rule, and verifier check includes a frontmatter tag: `type: architecture` or `type: model-crutch`
- Periodic prune pass reviews all `model-crutch` rules for continued relevance
- Prune decisions also pass human gate — no auto-mutation

**Confidence:** LOW-MEDIUM (this is a design decision specific to this kit; the concept of distinguishing permanent vs. temporary constraints appears in agent engineering literature but not as a standardized tagging convention)

---

### D3. Context Plane: Files Hub + Pull Tools for Long Tasks

**What:** For tasks that span context resets, a structured files hub (index of project files and their current state) plus two or three pull tools (search, get-file, expand-summary) replaces the model's fallback behavior of re-reading everything from scratch.

**Why it differentiates:** Without this, context reset means the agent either (a) hallucinates what was done, (b) re-reads everything and fills context with redundant file content, or (c) asks the user to re-explain. The files hub provides a fast, cheap way to rebuild working state from the PROGRESS file + index.

**Implementation note (Phase 2):** Only build this after a trace proves retrieval is the bottleneck — the evidence-first constraint from PROJECT.md. Phase 0 and Phase 1 use the PROGRESS file alone.

**Confidence:** MEDIUM (InfiAgent workspace pattern, sd0x-dev-flow `[AUTO_LOOP_RESUME]` injection, InfiAgent paper)

---

### D4. KV-Cache Optimized CLAUDE.md Structure

**What:** Stable, rarely-changing content (project identity, permanent rules, architecture constraints) placed at the top of CLAUDE.md. Frequently-changing content (current task context, session-specific state) excluded from CLAUDE.md entirely or pushed to the bottom.

**Why it differentiates:** Claude Code achieves >98% KV-cache hit rates on CLAUDE.md content when the prefix is stable. A cache miss means full re-tokenization of the file on every turn. For a 100-line CLAUDE.md file this matters for cost and latency in long sessions. For a 200-line file with unstable top content, it means paying full price every turn.

**Practical rule:** If a piece of content changes per-session or per-task, it does not belong in CLAUDE.md — it belongs in PROGRESS or a session-specific file.

**Confidence:** MEDIUM (HN discussion confirms >98% cache hits; official docs recommend stable content; exact cache invalidation boundary not fully documented)

---

### D5. Language-Agnostic Hooks

**What:** All hooks in the kit operate on tool call metadata (command strings, file paths, exit codes) rather than language-specific AST or runtime behavior. They work identically across Node, Java, Kotlin, Python, React, Angular projects.

**Why it differentiates:** Per-stack adapters create a maintenance explosion — each new language requires a new hook variant, and language-specific hooks drift out of sync with project tooling changes. Language-agnostic hooks (grep for forbidden patterns, check file path against denylist, validate exit code) transfer without modification.

**What this means in practice:**
- No language-specific linters invoked directly in hooks — instead, hooks invoke whatever lint command the project has configured (e.g., `npm run lint` or `./gradlew ktlintCheck` pulled from project settings)
- Pattern-matching on command strings (grep-based) rather than language-aware parsing
- File path checks and stub detection work on text content regardless of language

**Confidence:** HIGH (explicit constraint in PROJECT.md; confirmed by Konishi guide's emphasis on command-string pattern matching over semantic understanding)

---

### D6. Human Gate on Every Self-Improvement Step

**What:** No lesson, rule, or enforcement change is applied automatically. Every step in the self-improvement loop passes human review before becoming active.

**Why it differentiates:** Auto-mutation of the enforcement layer creates a runaway feedback risk — a false positive lesson could block valid operations in all future projects. The human gate is slow but makes the compounding loop safe to run on a production kit.

**How it works:**
- `/retro` proposes candidate lessons, does not apply them
- Human reviews the list, approves or rejects each
- Approved lessons are committed to the signature repo by the human, not by the agent
- The agent can suggest the commit message and the hook code, but the commit is a human action

**Confidence:** HIGH (explicit design constraint from PROJECT.md; supported by ByteDance human-in-the-loop self-improvement research)

---

## Anti-Features

Things to deliberately NOT build, with reasons.

---

### A1. Vector DB / Semantic Search on Failure Library

**What it is:** Embedding failures into a vector index for semantic similarity retrieval, so the agent can find "similar past failures" for any new situation.

**Why it sounds good:** Semantic retrieval would theoretically surface more relevant past lessons than filename/tag grep.

**Why to avoid it:** The failure corpus in v1 is too small to benefit from semantic search — a grep over 20-50 markdown files is faster and more reliable than a vector lookup. Vector DBs add operational complexity (index maintenance, embedding model dependency, drift over time). The "lost in the middle" retrieval failure documented in agent production systems means the agent may find the correct document but ignore it anyway. Build this only if a trace proves that retrieval latency or recall quality is the bottleneck. This is Phase 4 and conditional per PROJECT.md.

**Instead:** File-based grep with tag filtering. Simple, auditable, no infrastructure dependency.

**Confidence:** HIGH (explicit PROJECT.md constraint + Arize AI retrieval failure analysis)

---

### A2. Agent-Generated Skills

**What it is:** Letting the agent write its own SKILL.md files based on what it learned during a task.

**Why it sounds good:** Would close the self-improvement loop without human involvement.

**Why to avoid it:** A model cannot reliably write a skill that enforces its own behavior — it produces skills that are plausible but not necessarily sound. Agent-generated skills have no grounding in observed failures; they are hypotheses about what would have worked. Skills that encode wrong procedures compound errors across future tasks. The human gate is the quality filter.

**Instead:** Agent proposes skill content during `/retro`; human writes or approves the final SKILL.md.

**Confidence:** HIGH (explicit PROJECT.md constraint; supported by practitioner consensus that skills encode organizational knowledge that requires human judgment)

---

### A3. Over-Hooking / Hook Count Proliferation

**What it is:** Adding a hook for every possible failure mode, resulting in 20+ hooks running on every tool call.

**Why it sounds good:** More hooks = more enforcement = safer agent.

**Why to avoid it:** Blake Crosley's 95-hook autopsy is the canonical lesson here: 25 hooks in the first month, many redundant, added 200ms total overhead per lifecycle event. PreToolUse hooks run synchronously in the tool-dispatch path — slow hooks degrade every single tool invocation. The practitioner recommendation is: start with 3 hooks, not 25. Add hooks only when a specific failure recurs enough to justify the overhead.

**Threshold rule:** Each hook needs a failure case it was written to prevent. If you cannot name the failure, the hook is aspirational overhead.

**Instead:** Start with the minimal set from Phase 0 (write-progress-after-edit, grep-for-stubs-and-reject, skip-permission-prompts-for-unattended-runs). Add hooks only when Phase 1 converts a Phase 0 leak into enforcement.

**Confidence:** HIGH (Blake Crosley autopsy, Konishi guide's <100ms PreToolUse recommendation, official docs "Use hooks for actions that must happen every time with zero exceptions")

---

### A4. Advisory-Only CLAUDE.md Rules (Without Enforcement Backup)

**What it is:** Adding rules to CLAUDE.md as the primary enforcement mechanism for things that must not be violated.

**Why it sounds good:** CLAUDE.md is the natural place to document rules.

**Why to avoid it:** "Advisory without enforcement" is explicitly listed as one of the six configurations that reliably defeat a harness. Context pressure, long sessions, and model reasoning can override CLAUDE.md instructions. The harness guide formula: dangerous actions → Hooks, repeatable workflows → Skills, style preferences → CLAUDE.md. Permanent constraints must live in hooks, not in text.

**Instead:** Treat CLAUDE.md as a table of contents for context injection, not as an enforcement layer. Any rule in CLAUDE.md that must not be violated under any circumstances gets a corresponding PreToolUse hook.

**Confidence:** HIGH (Konishi guide, ShipWithAI guide, official docs all state this explicitly)

---

### A5. LLM-as-Judge as Primary Verifier

**What it is:** Using the verifier subagent's LLM judgment as the first (or only) check for output quality.

**Why it sounds good:** LLM judgment can catch nuanced errors that deterministic checks miss.

**Why to avoid it:** LLM-as-judge is expensive, variable, and subject to the same grade inflation problem as generator-grades-itself if the same model family is used. Official Claude Code docs recommend the priority order: tests/build checks → domain rule checks → LLM-as-judge last. A reviewer prompted to find gaps will always find some, even when work is sound — "chasing every finding leads to over-engineering."

**Instead:** Check in order: (1) does the code compile and tests pass? (2) do deterministic domain rules hold? (3) only if those pass, invoke LLM-as-judge for judgment-requiring quality checks. Cap LLM-as-judge scope to questions that cannot be answered deterministically.

**Confidence:** HIGH (official Claude Code docs, sd0x-dev-flow severity normalization pattern)

---

### A6. Per-Stack Hook Adapters

**What it is:** Separate hook scripts for each language/framework (node-hooks.sh, python-hooks.sh, kotlin-hooks.sh).

**Why it sounds good:** Language-specific hooks could catch language-specific failure modes.

**Why to avoid it:** Per-stack adapters create a maintenance burden that grows with each new project language. They drift out of sync. They encode assumptions about project tooling that break when tooling changes. Language-specific checks belong in the project's own linting/testing infrastructure, not in the kit's hooks.

**Instead:** Hooks operate on command strings, file paths, and exit codes only. The kit delegates language-specific checking to the project's existing lint/test commands, invoked by hooks via `PostToolUse`.

**Confidence:** HIGH (explicit PROJECT.md constraint)

---

### A7. Real-Time Observability Dashboard / Cost Tracker

**What it is:** A monitoring UI or structured cost-tracking system built into the kit.

**Why it sounds good:** Visibility into what the agent is doing and what it costs is valuable.

**Why to avoid it:** Observability infrastructure is a separate problem from harness correctness. Building it into the kit couples two concerns and adds maintenance overhead before the kit's core loop is validated. Session logs provide sufficient observability for v1. The sd0x-dev-flow harness (which has advanced observability) notes that ~4% of Claude's 200k context window is sufficient for all harness rules + skills — the overhead budget is tight.

**Instead:** Use Claude Code's built-in session logs and transcript for Phase 0-3 observability. Add structured observability only if a trace proves it's needed.

**Confidence:** MEDIUM (inferred from evidence-first constraint in PROJECT.md + practitioner warnings about complexity accumulation)

---

## Feature Dependencies

```
PROGRESS file (Table Stakes 4)
  └── Required by: PostToolUse hook that writes to it (Table Stakes 2)
  └── Required by: /retro command input (Differentiator D1)
  └── Required by: Context plane rebuild on session resume (Differentiator D3)

Failure library (Table Stakes 5)
  └── Required by: /retro command input (Differentiator D1)
  └── Required by: Rule tagging for prune step (Differentiator D2)

Enforcement hooks (Table Stakes 2)
  └── Converts lessons from: failure library (Table Stakes 5)
  └── Gated by: human approval (Differentiator D6)

Verifier subagent (Table Stakes 3)
  └── Feeds into: failure library on quality failures (Table Stakes 5)
  └── Required for: generator-verifier separation (structural, not optional)

CLAUDE.md as TOC (Table Stakes 1)
  └── Enables: KV-cache optimization (Differentiator D4)
  └── Delegates enforcement to: hooks (Table Stakes 2)
  └── Delegates workflow to: skills (Table Stakes 6)
```

---

## MVP Recommendation (Phase 0)

Build these first:

1. **CLAUDE.md TOC structure** — 100 lines, stable content at top, @imports to docs/
2. **PROGRESS file + PostToolUse hook that writes to it** — state survives context reset from day one
3. **Three minimal hooks**: write-progress-after-edit, grep-for-stubs-and-reject, skip-permission-prompts-for-unattended-runs
4. **Verifier subagent** — one agent file in .claude/agents/, runs after generator completes each module
5. **Failure library skeleton** — empty directory structure + entry template, ready to receive first entries from Giavico PoC run

Defer to Phase 1:
- Rule tagging system (no rules exist yet to tag)
- Additional hooks (earn them from Phase 0 leak analysis)

Defer to Phase 3:
- `/retro` command (requires a body of PROGRESS + failure entries to distill)
- Prune step (requires tagged rules to prune)

Defer to Phase 4 (conditional):
- Context plane pull tools (build only if Phase 0-3 trace shows retrieval is the bottleneck)
- Vector/semantic search on failure library

---

## Phase-Specific Research Flags

| Phase | Topic | Flag |
|-------|-------|------|
| Phase 0 | Giavico PoC Excel ingestion | Likely needs domain-specific research: Excel parsing libraries, schema detection patterns |
| Phase 0 | Verifier subagent agent file format | Official .claude/agents/ frontmatter spec — verify current syntax before writing |
| Phase 1 | Hook error message format for self-fix | Research what `additionalContext` injection format produces best model self-correction |
| Phase 2 | KV-cache prefix stability | Verify exact invalidation boundary (what counts as "stable" content for prefix cache) |
| Phase 3 | `/retro` command lesson distillation prompt | Research Trace2Skill and EvolveR patterns for effective lesson compression |
| Phase 4 | Vector index selection | Conditional — only if Phase 0-3 trace proves retrieval bottleneck |

---

## Sources

**Official documentation (HIGH confidence):**
- Claude Code best practices: https://code.claude.com/docs/en/best-practices
- Claude Code hooks reference: https://code.claude.com/docs/en/hooks
- Claude Code skills: https://code.claude.com/docs/en/skills
- Claude Code subagents: https://code.claude.com/docs/en/sub-agents

**Practitioner sources (MEDIUM-HIGH confidence, multiple consistent):**
- Konishi harness engineering guide: https://hidekazu-konishi.com/entry/claude_code_harness_and_environment_engineering_guide.html
- Blake Crosley 95-hook autopsy: https://blakecrosley.com/blog/claude-code-hooks
- sd0x-dev-flow reference harness: https://github.com/sd0xdev/sd0x-dev-flow
- ShipWithAI five-layer harness guide: https://shipwithai.io/blog/claude-code-harness-engineering-guide/

**Research / academic (MEDIUM confidence):**
- Trace2Skill (skill distillation from trajectories): https://arxiv.org/pdf/2603.25158
- VerifiAgent (unified verification): https://arxiv.org/pdf/2504.00406
- InfiAgent (workspace state pattern): https://arxiv.org/pdf/2601.03204
- Agent failure modes analysis: https://arize.com/blog/common-ai-agent-failures/

**Community (LOW-MEDIUM confidence, directional only):**
- Fast.io state persistence: https://fast.io/resources/ai-agent-workflow-state-persistence/
- DEV Community harness engineering: https://dev.to/shipwithaiio/the-complete-claude-code-harness-engineering-guide-5-layers-8-deep-dives-3d4j
