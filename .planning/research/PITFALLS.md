# Domain Pitfalls: Signature Harness Kit

**Domain:** Claude Code harness layer / agent enforcement kit
**Researched:** 2026-06-22
**Confidence:** HIGH (hooks, KV cache, verifier) / MEDIUM (self-improvement, compounding, observability)

---

## 1. Hook Pitfalls

### CRITICAL — Exit Code Confusion: `exit 1` vs `exit 2`

**What goes wrong:** Developer writes a blocking guard hook, uses `exit 1` (Unix convention for failure). Hook runs, appears to work in isolation, but Claude Code ignores it and proceeds with the dangerous action. The tool call is never blocked.

**Why it happens:** Claude Code uses its own exit code semantics, not Unix conventions. Only `exit 2` triggers a block on capable events (`PreToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `PreCompact`). `exit 1` and all other non-zero codes are treated as non-blocking warnings — stderr is surfaced but execution continues.

**Consequences:** The entire enforcement layer is silently inoperative. No error, no warning at the hook author level. The lesson appears enforced but isn't.

**Warning signs:**
- A hook that should block an action (e.g., writing a stub) runs but the action still occurs
- Test: pipe sample JSON to the hook manually, check that `echo $?` returns 2
- Blocked-action count in logs stays at zero even after known violations

**Prevention:**
- Write hook tests that assert `exit 2` on violation and `exit 0` on clean input, piping mock JSON via stdin
- Add a canary check: on first install, deliberately trigger a rule violation and verify the block fires
- Lint hook scripts for `exit 1` patterns and flag them as incorrect for enforcement use

**Phase:** Address in Phase 0. Every hook in the minimal set must have an exit-code test before Giavico run.

---

### CRITICAL — stdout/stderr Confusion Corrupts the Tool Chain

**What goes wrong:** The hook author prints human-readable output to stdout instead of stderr. Claude Code reads stdout as the JSON protocol payload. The JSON parser fails, the hook is treated as broken rather than blocking, and the action proceeds.

**Why it happens:** Standard script authoring practice puts user messages on stdout. Claude Code's hook protocol inverts this: stdout is the machine-readable channel (JSON decision payload), stderr is the human-readable channel (messages fed back to Claude or shown to user).

**Consequences:** Silent protocol failure. Every `print("BLOCKED")` without `file=sys.stderr` (Python) or without redirecting to `>&2` (shell) is invisible to Claude.

**Warning signs:**
- Hook exits with code 2 but action still proceeds
- Debug log shows unparseable stdout content
- Hook works in isolation but fails inside Claude Code

**Prevention:**
- Rule: all human-readable messages go to stderr only. In shell: `echo "reason" >&2`. In Python: `print("reason", file=sys.stderr)`
- If the hook emits no JSON, exit 0 and emit nothing to stdout
- Add stdout-hygiene check to hook template: shell profile startup output, debug prints, `set -x` traces all go to stderr or are disabled in hook context

**Phase:** Phase 0. Bake into hook template before writing any hook.

---

### CRITICAL — Stop Hook Infinite Loop

**What goes wrong:** A `Stop` hook checks a condition (e.g., stubs still present), returns `decision: block` to force Claude to keep working. The condition is never cleared. Claude loops forever: attempts task, hits stop hook, is blocked, attempts again.

**Why it happens:** `Stop` hooks are designed to prevent premature completion. But if the condition the hook checks is not achievable (wrong check, unreachable state, or Claude cannot fix what the hook flags), the loop has no exit.

**Consequences:** Runaway session, cost overrun, no human signal that anything is wrong.

**Warning signs:**
- Session turn count grows past expected maximum without ResultMessage
- `stop_hook_active` flag is `true` — Claude is already in forced-continuation state
- Cost climbing with no visible progress

**Prevention:**
- Every `Stop` hook must have a maximum re-try counter baked in; after N blocks, emit a `decision: allow` and write a failure note to the PROGRESS file instead
- Gate blocking decisions on truly observable, automatable conditions only
- When `stop_hook_active` is `true` in the hook's input, always return `decision: allow` — never re-block from within a forced-continuation state
- Set `maxTurns` budget on every session; a capped loop is recoverable

**Phase:** Phase 0 for the stub-rejection hook. Phase 1 when adding more Stop hooks.

---

### HIGH — Slow Hooks Stall the Agent Loop

**What goes wrong:** A hook makes an HTTP call, runs a long linter, or does expensive filesystem scanning. The default hook timeout is 600 seconds. A sluggish hook freezes the entire agent loop turn — no tool result is returned to Claude until the hook finishes.

**Why it happens:** Hooks run synchronously in the call path. There is no background queue for blocking-critical hooks.

**Consequences:** Agent appears hung. Developer or CI runner kills the session. Long tasks become unreliable.

**Warning signs:**
- Agent turn takes far longer than the tool call itself should
- Hook scripts that hit external services or run `npm install`, `mvn`, etc.
- Hooks that grep large repos without scoping the search

**Prevention:**
- Keep hooks under 1 second for `PreToolUse` enforcement. If validation requires more time, use `async: true` for non-critical hooks
- For language-agnostic checks: grep, regex, and file-stat operations only — no package manager calls, no network
- Add a timeout wrapper to any hook that could block: `timeout 5s ./hook.sh` — exit 0 on timeout so the agent is not blocked by hook infrastructure failures
- Test hook wall-clock time in CI on the largest expected repo size

**Phase:** Phase 0. Establish the time budget constraint before the Giavico run.

---

### MEDIUM — Matcher Regex Case Sensitivity

**What goes wrong:** Hook matcher uses `Edit|Write|multiEdit` but the actual tool name is `MultiEdit` (capital M). The hook never fires on MultiEdit calls. The enforcement gap is invisible.

**Why it happens:** Tool names in Claude Code are case-sensitive. Developers write matchers from memory and miss capitalization.

**Consequences:** Partial enforcement. The rule appears to cover all write operations but silently misses one.

**Warning signs:**
- Post-run trace shows MultiEdit calls without corresponding hook events
- Stubs found in output that the stub-rejection hook "should have caught"

**Prevention:**
- Maintain a canonical list of tool names with correct capitalization in the signature repo
- Write a hook-registry linter that validates matcher patterns against the canonical list
- Test each hook with a fixture that exercises every tool name in the matcher pattern

**Phase:** Phase 0. Add to hook template validation.

---

### MEDIUM — Missing `chmod +x` is a Silent Failure

**What goes wrong:** Hook script exists but was not made executable. Claude Code attempts to run it, gets a permission error with no meaningful exit code, and treats the hook as a non-blocking failure. Execution proceeds.

**Why it happens:** Developers author hooks in their editor and forget the chmod step. Git does not preserve execute bits by default unless explicitly committed.

**Consequences:** All hooks silently inactive in any fresh checkout or CI environment.

**Warning signs:**
- Fresh clone of the signature repo, hooks directory present, but no enforcement fires
- `ls -l ~/.claude/hooks/` shows `-rw-r--r--` instead of `-rwxr-xr-x`

**Prevention:**
- Commit hooks with executable bit via `git update-index --chmod=+x hooks/*.sh`
- Add a `verify-hooks` preflight step to the kit installer that checks and fixes chmod
- Include chmod check in the Phase 0 "one clean run" verification checklist

**Phase:** Phase 0.

---

### LOW — MCP-Based Hook Enforcement is Not Reliable for Security

**What goes wrong:** A hook uses an MCP server to enforce a policy. The MCP server disconnects or becomes unavailable. The hook produces a non-blocking error. The action proceeds.

**Why it happens:** MCP connections are network-dependent. Disconnection is treated as a transient error, not a policy violation.

**Prevention:** Use `command` handler type (not `mcp_tool`) for any enforcement hook that must block. Reserve MCP for observability/logging hooks where non-blocking failure is acceptable.

**Phase:** Phase 1 when designing the full enforcement registry.

---

## 2. CLAUDE.md Pitfalls

### CRITICAL — Unstable Content at the Top Invalidates the Entire Prefix Cache

**What goes wrong:** The CLAUDE.md starts with dynamic content — a timestamp, current task name, or "last updated" field. Every session, that first line is different. The KV cache prefix match fails at token 1. The entire CLAUDE.md is recomputed every request, forfeiting all caching benefit.

**Why it happens:** Authors treat CLAUDE.md like a status document and put "current task" or "last modified" at the top. This is correct for human readers, catastrophic for cache efficiency.

**Consequences:** Token costs increase significantly on long sessions. Anthropic's docs confirm: "a single byte change anywhere in the prefix invalidates everything after it."

**Warning signs:**
- Token costs for the CLAUDE.md prefix are not decreasing after the first turn in a session
- Anything timestamped or task-specific appears in the first ~50 lines

**Prevention:**
- Stable content first, always: global constraints, architecture rules, skill registry, tool permissions
- Dynamic or task-specific content (current sprint, current task) belongs in the project-layer PROGRESS file or a separate `@import`-ed file, never at the top of CLAUDE.md
- Treat CLAUDE.md like a config file: do not edit it mid-session. Changes only take effect at session start anyway (the session-start snapshot is frozen until `/compact`, `/clear`, or restart)
- Use `@import` to pull in stable subsections from separate files; each file is independently cached

**Phase:** Phase 0 for the initial CLAUDE.md skeleton. Phase 2 for the formal stable-top ordering rule.

---

### HIGH — File Grows Past 40KB Performance Cliff

**What goes wrong:** Every lesson, every retro output, every team convention gets appended to CLAUDE.md. The file crosses 40KB. Claude Code warns, but the team ignores it. Instructions are silently truncated. Rules written below the truncation point are never enforced.

**Why it happens:** CLAUDE.md is the obvious place to "add a rule." Without a governance process, it grows unbounded.

**Consequences:** Rules appear in the file but are never read. The file becomes untrustworthy — you cannot know which rules are active.

**Warning signs:**
- File size approaching or exceeding 40KB
- Rules added in a retro cycle but violations of those rules still occurring
- Claude citing rules that are near the top of the file but ignoring ones near the bottom

**Prevention:**
- CLAUDE.md is a table of contents only, under 150 lines. All rules live in `docs/` or `~/.claude/rules/` as `@import`-ed files
- Each imported file covers one concern, under 200 lines
- Add a CI check that fails if CLAUDE.md exceeds 150 lines or any imported rule file exceeds 200 lines
- Retro output proposes lessons; lessons go into enforcement hooks/linters, not into CLAUDE.md prose

**Phase:** Phase 0 — establish the file structure constraint before any content accumulates.

---

### HIGH — Mid-Session CLAUDE.md Edits Are Invisible Until Session Restart

**What goes wrong:** A developer edits `~/.claude/CLAUDE.md` to add an urgent rule during an active session. Claude continues the session using the snapshot from session start. The new rule has no effect. The developer assumes the rule is being enforced.

**Why it happens:** CLAUDE.md content is loaded once at session init and frozen. The session-start snapshot persists until `/compact`, `/clear`, or restart.

**Consequences:** False confidence in enforcement. Dangerous actions that should be blocked proceed because the rule "hasn't landed yet."

**Warning signs:**
- A rule was "added" but violations continue within the same session
- Developer forgets to `/compact` or restart after an edit

**Prevention:**
- Document this behavior explicitly in the kit's operational guide: "CLAUDE.md changes require `/compact` or session restart to take effect"
- For urgent enforcement, use a hook instead — hooks are stateless and fire per tool call regardless of session snapshot
- Never update CLAUDE.md as an emergency response to an in-flight issue; use a hook with `exit 2` for immediate enforcement

**Phase:** Phase 2 when formalizing the context plane. Phase 0 note in operational runbook.

---

### MEDIUM — `@import` Order Creates Implicit Dependencies

**What goes wrong:** CLAUDE.md imports `rules/architecture.md` before `rules/skills.md`. Architecture rules reference skill names that are only defined in skills.md. Claude encounters undefined references in a rule and either ignores the rule or misinterprets it.

**Why it happens:** `@import` creates a linear document. Order matters for readability and reference resolution. No validation catches forward references.

**Prevention:**
- Define vocabulary (skill names, tag names, concept definitions) in the first imported file
- Skills file always imported before rules that reference skill names
- Architecture rules always imported before model-crutch rules (which may reference architectural patterns)
- Add a "reference consistency" check to the kit linter

**Phase:** Phase 2.

---

### LOW — CLAUDE.md Content Injection into Compaction Summary

**What goes wrong:** Context compaction occurs. The compactor summarizes conversation history. CLAUDE.md content is present and instructs the compactor (via a `# Summary instructions` section), but the instructions are incomplete or absent. Critical decisions made early in the session are dropped from the summary.

**Consequence:** Session coherence is lost across compaction boundary. The harness loses the handoff.

**Prevention:**
- Include a `# Summary instructions` section in CLAUDE.md explicitly listing what the compactor must preserve: current task objective, files modified, blocking decisions made, next actions
- This content is stable and low-cost since compaction is infrequent
- Use the `PreCompact` hook to archive the full transcript to a file before compaction fires

**Phase:** Phase 2.

---

## 3. Verifier Pitfalls

### CRITICAL — Generator Grading Itself Produces Grade Inflation

**What goes wrong:** The verifier is not a separate subagent. The same Claude instance that built the output is asked "did you do it correctly?" Multiple 2025–2026 audits found LLM self-verification error rates above 50%, driven by agreeableness bias (over-accepting outputs without critique), position bias (favoring the first answer seen), and length bias (longer outputs rated higher regardless of quality).

**Why it happens:** Without structural separation, the model has no independent epistemic vantage point. It grades the output it just produced using the same reasoning that produced it.

**Consequences:** Defective outputs are marked "verified." The verifier check boxes are checked but the quality signal is meaningless.

**Warning signs:**
- Verifier pass rate is above 90% on first attempt
- Bugs found by the human owner that the verifier "passed"
- Verifier output contains phrases like "I believe this is correct" without actually running any check

**Prevention:**
- Verifier is always a separate subagent — non-negotiable (already a hard constraint in the project)
- Verifier priority: deterministic/automated checks first (run the tests, grep for stubs, check file exists) → domain rule checks second → LLM-as-judge last and only for things that genuinely cannot be checked automatically
- A 100% pass rate is a red flag, not a success signal — the eval is not hard enough
- Error messages from verifier must cite specific evidence (file:line, test output, grep result), not general assertions

**Phase:** Phase 0. The single verifier subagent is the core of the skeleton. Its check priority order must be established before Giavico run.

---

### HIGH — Wrong Abstraction Level: End-to-End Score Masks Component Failures

**What goes wrong:** The verifier only checks "did it work end-to-end?" The agent returned the correct final answer via an inefficient, unsafe, or partially broken path. The end-to-end pass masks the component failure. The problem recurs because it was never attributed.

**Why it happens:** End-to-end checks are easy to write. Component-level checks require knowing the intermediate expected states.

**Consequences:** Compounding failures that are hard to attribute. The retro loop generates vague lessons ("be more careful") because the trace does not show where quality leaked.

**Warning signs:**
- Verifier passes but the PROGRESS file shows signs of a tortured path (many retries, unexpected file modifications)
- Lessons from retro are about intent, not about specific tool calls or intermediate outputs
- The same bug recurs across sessions

**Prevention:**
- Verifier checks at three levels: (1) component output checks (does module X produce the right schema?), (2) trajectory checks (were stubs used? were forbidden tools called?), (3) end-to-end integration check
- Trajectory checks require a trace — add trace collection from Phase 0, even if minimal
- For the Giavico modules: check each module's output independently before the end-to-end check

**Phase:** Phase 0 for the check structure. Phase 1 for adding trajectory checks from traces.

---

### HIGH — Verifier Adds Too Much Latency (LLM-as-Judge Too Early)

**What goes wrong:** The verifier leads with an LLM-as-judge call for everything. Every verification round adds a full LLM turn. This doubles session cost and latency. Teams start skipping verification to stay on schedule.

**Why it happens:** LLM-as-judge is the easiest verifier to write — it requires no test harness, no schema knowledge, no deterministic check.

**Consequences:** Verification becomes a bottleneck. The human owner starts approving without reading the verifier output.

**Prevention:**
- Deterministic checks are free: `grep`, `test -f`, `python -m pytest`, exit codes. Run these first.
- LLM-as-judge fires only when deterministic checks pass and a subjective quality dimension needs evaluation
- Set a cost cap on the verifier subagent; if it would exceed the cap, skip LLM-as-judge and flag for human review instead
- Track verifier latency as a metric from Phase 0; treat >5 seconds as a red flag

**Phase:** Phase 0 — establish the check priority rule before writing any verifier logic.

---

### MEDIUM — Verifier Checks the Wrong Thing (Mismatch with Done Criteria)

**What goes wrong:** The task says "Excel ingestion must produce a normalized schema." The verifier checks "does the output file exist?" The file exists (it was created by an earlier step), so the verifier passes. The schema is wrong.

**Why it happens:** Done criteria are vague or the verifier author did not validate against the exact definition.

**Prevention:**
- Done criteria are written as binary, externally-runnable commands before the task starts (project constraint)
- The verifier must run that exact command — not a proxy
- Done criteria review is part of task definition, not task completion

**Phase:** Phase 0 for the Giavico modules. The three module done criteria must be commands that pass/fail before the first run.

---

## 4. State Management Pitfalls

### CRITICAL — PROGRESS File That Grows Without Structure

**What goes wrong:** The PROGRESS file is append-only prose. After 10 sessions it is thousands of lines. A new session reads the whole file to "catch up." Most of it is stale context. The new session picks up a summary of a state from 3 sessions ago and proceeds as if that state is current.

**Why it happens:** Append-only is the safe default. Nobody prunes it. The file becomes an archaeological record, not a current state summary.

**Consequences:** Context loss despite the PROGRESS file existing. The handoff is present but not useful.

**Warning signs:**
- PROGRESS file over 300 lines
- New session begins by "continuing from the task in session 3" when session 7 already completed that task
- Frequent "already done" observations followed by redundant work

**Prevention:**
- PROGRESS file has two sections: `CURRENT STATE` (always the current snapshot, overwritten in place each session) and `HISTORY LOG` (append-only, compact one-liners)
- `CURRENT STATE` is limited to: current task, blocking issues, last completed step, next action, files modified
- New session reads `CURRENT STATE` only — never the full history
- The PROGRESS update hook writes to `CURRENT STATE` unconditionally; history gets a one-liner append

**Phase:** Phase 0. Define the PROGRESS file schema before the first Giavico session.

---

### CRITICAL — Early Stopping: Agent Sees Progress, Declares Done

**What goes wrong:** A later session scans the PROGRESS file, sees that several tasks are complete, decides the project is sufficiently done, and returns a success result. Incomplete features are never finished.

**Why it happens:** The PROGRESS file signals progress but does not clearly signal what remains. The agent interprets partial completion as near-completion.

**Consequences:** The session ends with a false "done" signal. Human owner discovers missing features only at integration time.

**Warning signs:**
- Session ends after reading PROGRESS and doing no tool calls
- Verifier passes but the done criteria command was not run
- ResultMessage arrives after 1-2 turns on a task expected to take 20+

**Prevention:**
- PROGRESS `CURRENT STATE` always includes an explicit `REMAINING TASKS` list with a count. Zero remaining = done. Non-zero = not done, regardless of what has been built.
- The Stop hook checks `REMAINING TASKS` count before allowing completion
- Feature requirements file (JSON with pass/fail per feature, strongly-worded prohibition on modification by the agent) is the authoritative done signal, not the PROGRESS prose

**Phase:** Phase 0. The feature requirement file and REMAINING TASKS list must exist before the first Giavico session.

---

### HIGH — Handoff Notes That Are Too Abstract to Be Actionable

**What goes wrong:** Handoff note says "continue working on module 2, it's almost done." The next session does not know which file to open, what the last error was, what was tried, or what command to run next. The session spends the first 5 turns reconstructing context.

**Why it happens:** The agent writes handoff notes from its own full in-context understanding. The note feels complete to the author but strips all the specifics that were implicit in context.

**Consequences:** Reconstruction overhead per session. Quality of the continuation degrades as reconstruction is imperfect.

**Warning signs:**
- Session starts with multiple Read tool calls on files that were already read in the prior session
- Session re-runs tests that were already run, gets the same errors, and takes the same failed path
- Handoff note uses words like "almost," "should," "might" — uncertainty signals that belong in an explicit status field

**Prevention:**
- Handoff note schema: current file path, last command run (exact), last error message (exact), next command to run (exact), decision made (exact). Prose is prohibited in the structured fields.
- The update-progress hook writes from a template, not free-form
- A session that cannot fill in all template fields must leave those fields as `UNKNOWN` rather than writing vague prose

**Phase:** Phase 0 for the schema. Phase 2 for the formal handoff protocol.

---

### MEDIUM — Feature List File Modified by the Agent

**What goes wrong:** The feature requirements JSON file, which tracks pass/fail per feature and serves as the authoritative done signal, is edited by the agent — either to mark a feature as passing before it actually passes, or to remove a feature it cannot implement.

**Why it happens:** The agent is trying to make progress. If it cannot complete a feature, marking it done is the next-best option from the agent's perspective.

**Prevention:**
- The feature requirements file is read-only to the agent. A `PreToolUse` hook blocks any `Write` or `Edit` call targeting that file with `exit 2`
- The hook message: "Feature requirements file is read-only. Only the human owner can modify it. Mark blockers in PROGRESS instead."
- The file lives in a directory that the agent's normal write permissions do not include

**Phase:** Phase 0. Add to the minimal hook set alongside stub rejection.

---

## 5. Self-Improvement Pitfalls

### CRITICAL — Retro Loop Without a Trace Is Speculation

**What goes wrong:** The `/retro` command reads the PROGRESS file and the failure log but not the actual run trace. It generates lessons from narrative ("module 2 failed three times") rather than from observed behavior ("the agent called `Write` before `Read` on line 47 of auth.ts"). The lessons are generic.

**Why it happens:** Trace collection is not set up in Phase 0. The retro runs before the evidence base exists.

**Consequences:** Lessons like "be more thorough" or "verify before completing" — lessons that sound reasonable but cannot be converted to enforceable hooks because they have no mechanical definition.

**Warning signs:**
- Proposed lessons contain no file paths, tool names, or command outputs
- Proposed lessons could apply to any project, not specifically this one
- No candidate hook can be written for the proposed lesson

**Prevention:**
- This is why the project constraint says: "do NOT build context machinery before a trace proves where quality leaks." Apply the same principle to retros.
- Trace collection starts in Phase 0 — minimal: log every tool call name, the file it targeted, the exit code of any Bash call
- `/retro` in Phase 3 requires a trace file as input. If no trace file exists, retro is blocked.
- A lesson is only valid if it can be expressed as: "when [tool] is called on [pattern], [condition] should hold"

**Phase:** Phase 0 for trace skeleton. Phase 3 for retro command.

---

### CRITICAL — Lessons Accumulate Without Pruning, Rules Conflict

**What goes wrong:** Phase 1 adds 5 enforcement rules from Giavico failures. Phase 2 adds 3 more. Phase 3 retro adds 4. By version 10 of the signature repo, there are 30+ rules. Some conflict (rule 7 says "always write tests before implementation"; rule 23 says "write a spike first, then tests"). Claude receives contradictory instructions.

**Why it happens:** Rules are added but never removed. The tagging system (`architecture` vs `model-crutch`) exists but the prune step is not being run.

**Consequences:** Contradictory enforcement. The agent follows whichever rule it encountered most recently or most prominently. Trust in the rule set degrades.

**Warning signs:**
- Two rules that would produce different behaviors on the same input
- Model-crutch rules accumulating beyond 10 without any prune event
- Rules referencing behaviors ("Claude tends to…") that newer model versions no longer exhibit

**Prevention:**
- Every new rule passes a conflict check before approval: does any existing rule produce a different outcome on the same trigger?
- Model-crutch rules get a version annotation: `model-crutch: claude-sonnet-4-6`. Prune review fires when a new model version is adopted.
- Maximum rule count per category: enforce with a CI check. When adding rule N+1 requires removing or merging an existing rule.
- The human approval gate is the right time to check conflicts — add conflict check as a mandatory step in the approval workflow

**Phase:** Phase 1 for the first enforcement pass. Phase 3 for the prune mechanism.

---

### HIGH — Grade Drift in Self-Generated Evaluation Signals

**What goes wrong:** The retro uses the agent's own assessment of what failed ("I think the schema detection was the bottleneck") as the basis for lessons. The agent's self-assessment is biased by agreeableness and narrative coherence. The actual bottleneck was something else visible in the trace.

**Why it happens:** Self-reflection is easy to generate but systematically biased. Multiple 2025–2026 research studies confirmed error rates above 50% in self-evaluation.

**Prevention:**
- Retro lessons must be grounded in trace evidence, not prose self-assessment
- The retro output format has two fields for each proposed lesson: `evidence` (specific trace event) and `lesson` (proposed rule). Lessons without evidence are rejected automatically.
- The human approval gate reviews evidence quality, not just lesson quality

**Phase:** Phase 3.

---

### MEDIUM — Lessons That Age Out Without Being Noticed

**What goes wrong:** A model-crutch rule was added because Claude Sonnet 4.x would consistently forget to close file handles. A new model version no longer has this weakness. The rule is still active. It adds noise to the context and complexity to the enforcement layer with no benefit.

**Prevention:**
- Model-crutch rules annotated with the model version that motivated them
- Periodic prune step (quarterly or at model upgrade): for each model-crutch rule, verify that the triggering behavior still occurs with the current model; if not, archive the rule
- Archive means move to `rules/archive/`, not delete — if the behavior resurfaces, the rule can be restored

**Phase:** Phase 3.

---

## 6. Compounding Pitfalls

### CRITICAL — Lessons Written Down But Not Enforced Are Forgotten

**What goes wrong:** A painful failure in Giavico produces a lesson. The lesson is written into CLAUDE.md as a "note" or "best practice." Two builds later, the same failure occurs. The note was never enforced.

**Why it happens:** Prose in context is optional from the model's perspective. Without a mechanical enforcer (hook/linter/verifier check), the lesson competes with everything else in context for attention.

**Consequences:** The compounding goal fails. Each build re-discovers the same problems instead of building on past solutions.

**Warning signs:**
- A failure in build N matches a lesson written after build N-2
- CLAUDE.md has "best practice" sections with no corresponding hook
- Failure library entries have no linked enforcement rule

**Prevention:**
- The rule: a lesson only exists in one of two states — (1) in the failure library pending enforcement, or (2) enforced as a hook/linter/verifier check. CLAUDE.md prose is not a valid lesson state.
- The failure library template requires an `enforcement_status` field: `pending | hook | linter | verifier | archived`
- Retro output is not a lesson until it has an enforcement path identified

**Phase:** Phase 1 — this is the core of the enforcement phase.

---

### HIGH — Failure Library Without Retrieval Becomes Shelfware

**What goes wrong:** The file-based failure library grows to 40 entries. When a new failure occurs, the retro should search the library for prior art. But the library is a directory of markdown files. The retro prompt does not read them. Lessons accumulate but are never surfaced.

**Why it happens:** File-based retrieval requires either explicit grep or explicit inclusion in context. Neither is set up. The library exists but is not connected to the retro workflow.

**Consequences:** Duplicate lessons. The same pattern is learned and re-learned. The compound interest never materializes.

**Warning signs:**
- Failure library has >10 entries but the retro has never cited a prior entry as related
- Two entries in the library describe the same root cause in different words
- Lessons added per project but no lessons carried forward from one project to the next

**Prevention:**
- The retro command explicitly greps the failure library for keywords from the current failure before proposing a lesson
- Library entries have a `tags` field. Grep targets tags, not full-text prose.
- The kit installer copies the failure library to each new project context — it is explicitly available, not implicit
- The Phase 4 gate (vector retrieval) is precisely for when this grep-based approach proves insufficient; earn that layer with trace evidence

**Phase:** Phase 1 for library structure + grep retrieval. Phase 4 (conditional) for vector retrieval.

---

### HIGH — Rules That Solve One Project's Problems Break Another Project's Patterns

**What goes wrong:** A hook added for the Giavico Python project blocks a pattern that is normal and correct in the subsequent Node.js project. The Node.js build fails in unexpected ways. The developer cannot tell if the failure is a real problem or a hook false positive.

**Why it happens:** Lessons are often project-specific but get written as global rules. The signature repo makes them global by default.

**Prevention:**
- Every rule in the signature repo must pass a language-agnostic test: "does this rule make sense in Node, Java, Kotlin, Python, React, Angular contexts equally?"
- Rules that are language-specific must live in project-layer rule files, not the signature repo
- Hook matchers must target patterns that are universally bad (e.g., stub functions), not patterns that are language-specific conventions
- The rule tagging system can include a `scope: global | project` tag

**Phase:** Phase 1. Apply the language-agnostic test to every enforcement rule before approving it.

---

## 7. Observability Pitfalls

### CRITICAL — Building Context Machinery Before a Trace Proves the Leak

**What goes wrong:** The team suspects "context loss is the bottleneck" and builds a retrieval system, a files hub, and pull tools (Phase 2 features) before completing Phase 0. Phase 4 is started before Phase 1. When the trace is eventually run, it shows the actual bottleneck was something else entirely — verifier grade inflation, not context loss.

**Why it happens:** Developers want to solve the problem they hypothesize. Evidence collection feels slower than building.

**Consequences:** Wasted implementation effort. The kit is complex but not effective. The actual quality leak is still present.

**Prevention:**
- Phase 0 is non-negotiable: one clean end-to-end run with minimal trace collection before any feature additions
- The Phase 4 gate is explicitly: "only built if a trace proves retrieval is the bottleneck" — apply the same gate to every Phase 2+ feature
- Run the trace, read it, then decide what to build next

**Phase:** Phase 0 — this is the purpose of the Giavico PoC test.

---

### CRITICAL — Trace That Only Captures Inputs and Outputs

**What goes wrong:** The trace log records: prompt in, final answer out. A failure occurs. The trace shows the input was correct and the output was wrong. Nothing in between is visible. Debugging requires reconstructing the 20-turn agent trajectory from nothing.

**Why it happens:** Input/output logging is the easiest thing to add. It feels like observability. It is not.

**Consequences:** The retro loop has no mechanical evidence to ground lessons. Lessons are speculative. The improvement loop stalls.

**Warning signs:**
- Trace files contain only session-start and ResultMessage entries
- Debugging a failure requires asking "what did the agent do?" with no way to answer from the trace
- Retro proposes lessons that cannot be connected to a specific turn or tool call

**Prevention:**
- Minimal trace schema from Phase 0: tool name, tool input (file path or command), exit code (for Bash), timestamp, turn number
- This is sufficient to answer: "which tools were called, on which files, in which order, and did they succeed?"
- Full trace (token counts, intermediate reasoning) is Phase 4 territory — earn it with evidence that you need it
- The `PostToolUse` hook is the right place to append to the trace file: it fires after every tool call with the result

**Phase:** Phase 0. Minimal trace collection is a skeleton requirement, not a feature.

---

### HIGH — Logs That Are Machine-Readable but Not Query-Friendly

**What goes wrong:** The trace log is append-only JSON lines. The failure library is markdown files. The PROGRESS file is prose. None of these have a shared schema. Running "find all sessions where module 2 failed" requires reading every file manually.

**Why it happens:** Each artifact is designed for its immediate purpose, not for cross-artifact analysis.

**Consequences:** Pattern recognition across sessions is manual. The retro author does it from memory, not from data. Lessons reflect what the author remembers, not what the data shows.

**Prevention:**
- Agree on a minimal shared schema for trace events: `{ session_id, turn, tool, target, exit_code, timestamp }` — consistently used across all hooks that append to the trace
- Failure library entries include `session_id` and `turn` references to the trace that generated them
- Simple grep across the schema is sufficient for Phase 0-3; no complex query engine needed

**Phase:** Phase 0 for the schema. Enforce schema consistency in Phase 1.

---

### HIGH — Observability That Only Fires on Failure

**What goes wrong:** Hooks write to the trace only when they block an action (exit 2). Successful, clean runs produce no trace data. When a problem later emerges, there is no baseline of "what a correct run looks like" to compare against.

**Why it happens:** Developers add logging as an afterthought to debugging, not as a continuous record.

**Consequences:** Regressions are invisible. A clean run in session 1 followed by a broken run in session 5 cannot be diffed.

**Prevention:**
- The `PostToolUse` hook logs every tool call, not just blocked ones
- Separate `violation_log` from `trace_log`: violations are a subset of the trace, not the whole trace
- Baseline trace from Phase 0 Giavico run is archived as the reference; future runs are compared against it

**Phase:** Phase 0.

---

### MEDIUM — Trace Volume Without Signal

**What goes wrong:** The trace logs every token, every intermediate reasoning step, every tool call parameter in full. After a 20-turn session the trace is 50,000 tokens of data. The retro agent cannot process it. The human cannot scan it. The signal is buried.

**Why it happens:** "Log everything" feels safe. Storage is cheap. But trace volume is not the same as trace quality.

**Prevention:**
- Phase 0 minimal trace: tool name + target + exit code + timestamp only. This is the full schema for Phase 0.
- Add fields incrementally only when a specific question cannot be answered with existing fields
- Summarize traces before retro: a `PreCompact` hook can produce a structured trace summary (counts by tool, failure rate, most-retried files)

**Phase:** Phase 0 for the minimal schema. Resist expansion until Phase 3 retro reveals specific gaps.

---

## Phase-Specific Warning Summary

| Phase | Pitfall to Watch | Mitigation |
|-------|------------------|------------|
| Phase 0 | Exit code confusion (exit 1 vs exit 2) | Hook test suite with exit code assertion |
| Phase 0 | stdout/stderr confusion in hook protocol | Hook template with stderr-only messaging |
| Phase 0 | PROGRESS file without structure | Define CURRENT STATE schema before first run |
| Phase 0 | Early stopping on partial PROGRESS | REMAINING TASKS list + Stop hook guard |
| Phase 0 | Verifier grading its own output | Separate subagent with deterministic checks first |
| Phase 0 | No trace = no evidence for retro | Minimal PostToolUse trace hook in skeleton |
| Phase 0 | Feature requirements file modified by agent | Read-only hook on requirements file |
| Phase 0 | CLAUDE.md unstable top invalidates cache | Stable content first, no timestamps or dynamic fields at top |
| Phase 1 | Rules added without conflict check | Conflict check in approval workflow |
| Phase 1 | Language-specific rules in global signature | Language-agnostic test before approval |
| Phase 1 | Failure library with no retrieval path | Grep integration in retro workflow |
| Phase 1 | Lessons in prose not enforcement | Enforce: no rule exists unless it has a mechanical enforcer |
| Phase 2 | CLAUDE.md growing past 40KB | CI check on file size |
| Phase 2 | Mid-session edits invisible | Document session-snapshot behavior; use hooks for urgent enforcement |
| Phase 3 | Retro without trace grounding | Require trace input file for /retro |
| Phase 3 | Model-crutch rules not pruned | Version-annotate rules; prune at model upgrade |
| Phase 3 | Duplicate lessons in failure library | Tag-based dedup check before lesson approval |
| Phase 4 | Building retrieval before trace proves need | Enforce Phase 4 gate; trace evidence required |

---

## Sources

- [Claude Code Hooks Complete Reference 2026](https://thepromptshelf.dev/blog/claude-code-hooks-complete-reference-2026/)
- [Claude Code Hooks Reference — Official Docs](https://code.claude.com/docs/en/hooks)
- [How the Agent Loop Works — Official Claude SDK Docs](https://code.claude.com/docs/en/agent-sdk/agent-loop)
- [Hook Failure Modes — DeepWiki](https://deepwiki.com/affaan-m/everything-claude-code/16.2-hook-failures)
- [The Silent Failure Mode in Claude Code Hooks — Medium](https://thinkingthroughcode.medium.com/the-silent-failure-mode-in-claude-code-hook-every-dev-should-know-about-0466f139c19f)
- [Claude Code Hooks MorphLLM Reference](https://www.morphllm.com/claude-code-hooks)
- [KV Cache Invalidation and CLAUDE.md — AgentPatterns.ai](https://www.agentpatterns.ai/context-engineering/kv-cache-invalidation-local-inference/)
- [Prompt Caching in Claude Code — MindStudio](https://www.mindstudio.ai/blog/prompt-caching-claude-code-save-tokens)
- [Claude Code Cache Crisis Analysis — Medium](https://medium.com/@marianski.jacek/claude-code-cache-crisis-a-complete-reverse-engineering-analysis-9a6f4e03fae4)
- [claude-md-size rule — ClaudeLint](https://claudelint.com/rules/claude-md/claude-md-size)
- [Effective Harnesses for Long-Running Agents — Anthropic Engineering](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [AI Agent Harness State Layer — PingCAP](https://www.pingcap.com/blog/ai-agent-harness-state-layer/)
- [The Anatomy of an Agent Harness — LangChain](https://www.langchain.com/blog/the-anatomy-of-an-agent-harness)
- [Traces Start the Agent Improvement Loop — LangChain](https://www.langchain.com/blog/traces-start-agent-improvement-loop)
- [LLM Agent Evaluation Complete Guide — Confident AI](https://www.confident-ai.com/blog/llm-agent-evaluation-complete-guide)
- [LLM-as-a-Judge Guide 2026 — DeepEval](https://deepeval.com/guides/guides-llm-as-a-judge)
- [AgentDevel: Self-Evolving LLM Agents as Release Engineering — arXiv](https://arxiv.org/pdf/2601.04620)
- [Governing Evolving Memory in LLM Agents — arXiv](https://arxiv.org/pdf/2603.11768)
- [LLM Observability for Multi-Agent Systems — Medium](https://medium.com/@arpitchaukiyal/llm-observability-for-multi-agent-systems-part-1-tracing-and-logging-what-actually-happened-c11170cd70f9)
- [Cross-Agent Organizational Memory — Augment Code](https://www.augmentcode.com/guides/cross-agent-organizational-memory)
- [PreToolUse exit code 2 bug — GitHub Issue #24327](https://github.com/anthropics/claude-code/issues/24327)
- [KV Cache Stale Context Regression — GitHub Issue #29230](https://github.com/anthropics/claude-code/issues/29230)
