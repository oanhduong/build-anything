# Phase 1: Enforcement Hardening - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert every failure category exposed during the Phase 0 Giavico build into machine-enforced rules: hook, linter rule, skill, or verifier check. Every rule is tagged with its type and carries a self-teaching block message. Done when `./scripts/replay-giavico-failures.sh` exits 0 — a single script that proves all ENFC-01..04 requirements are met.

Creating new enforcement primitives (context plane, self-improve loop) is out of scope — Phase 1 hardens what was learned, it does not extend the harness.

</domain>

<decisions>
## Implementation Decisions

### Failure identification
- Source of truth: mine trace.log, STATE.md decisions, and phase SUMMARY files (key-decisions + patterns-established fields), PLUS the git history of Phase 0 to find fix-on-fix commits (corrections mid-build reveal what the model got wrong the first time)
- The researcher identifies candidate failures autonomously using heuristics: repeated pattern, clear rule, grep-verifiable — no human approval gate at the identification stage
- The final enforcement rules (hooks written, failure-lib entries committed) are what the human approves at the git commit review stage, not a separate pre-commit gate

### Failure-lib entry format
- One file per failure in `failure-lib/` — each entry is its own `.md` file (easy to retire individual entries, Phase 3 can grep per-file)
- Format: YAML frontmatter + markdown body
- Required YAML frontmatter fields: `id` (unique slug), `tag` (architecture|model-crutch), `enforcement-type` (hook|skill|verifier-check|linter), `model-version` (e.g. `claude-sonnet-4-6` — required for model-crutch entries, omit for architecture)
- Human-readable body: what failed, why, the self-fix instruction, and the grep pattern or verifier instruction

### replay-giavico-failures.sh design
- Prove method: inject known-bad patterns → invoke hook directly → assert exit 2 (same injection idiom as Phase 0 test scripts: test-stub-reject.sh, test-trace-hook.sh, etc.)
- Scope: one script proves all ENFC-01..04 in a single run:
  - ENFC-01: per-failure injection tests (assert hook fires with exit 2 on bad pattern)
  - ENFC-02: grep all hooks + failure-lib for `tag:` annotation — `grep -rL 'tag:' ~/.claude/hooks/` must return empty
  - ENFC-03: grep all hook block messages for `"How to fix:"` pattern
  - ENFC-04: grep hook bodies for language-specific binary invocations (`node`, `python`, `java`, `kotlin`) — must find none
- Output format: per-entry report — each test line prints `[PASS]` or `[FAIL]` with the failure id; summary at end: `N passed, M failed` — same style as Phase 0 test scripts

### Language-specific findings → enforcement
- Python-specific patterns from Phase 0 (openpyxl engine, dotenv module-level scope, mock at import boundary, etc.) CANNOT become language-agnostic grep-based hooks (ENFC-04)
- They go into failure-lib as documented entries with `enforcement-type: verifier-check` (not hook)
- Tag: `model-crutch` (model-version-specific language-weakness) with the Claude model version
- Verifier agent reads failure-lib at runtime — verifier.md instructions tell it to scan `failure-lib/` for entries with `enforcement-type: verifier-check` and apply them as part of its universal kit checks. No static entries added to verifier.md per finding — scalable as failure-lib grows.

### Claude's Discretion
- Exact set of failures identified from Phase 0 (researcher mines these from trace + git + SUMMARY files)
- Order of tests in replay-giavico-failures.sh
- Precise grep patterns for each failure-lib hook entry
- Whether any borderline finding is architecture vs model-crutch

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Harness requirements
- `.planning/REQUIREMENTS.md` — ENFC-01..05 requirement definitions (the Phase 1 acceptance criteria). Every task must trace to one of these.
- `.planning/PROJECT.md` — Architecture principles, constraints, out-of-scope list. Specifically: language-agnostic hooks constraint, file-based failure library, human gate rules.

### Phase 1 scope
- `.planning/ROADMAP.md` §Phase 1 — Done command, success criteria (4 binary checks), goal statement. The done command is `./scripts/replay-giavico-failures.sh` — ground truth for what Phase 1 means.

### Phase 0 failure sources (researcher must read all three)
- `.planning/STATE.md` §Decisions — key-decisions list from all Phase 0 plans (eval subshell fix, jq merge approach, HOME override, etc.)
- `.planning/phases/00-skeleton-giavico-poc/00-03-SUMMARY.md` — patterns-established and key-decisions from Giavico PoC module work
- `.planning/phases/00-skeleton-giavico-poc/00-02-SUMMARY.md` — hook enforcement patterns from Plan 2
- `.planning/phases/00-skeleton-giavico-poc/00-01-SUMMARY.md` — harness foundation patterns from Plan 1

### Existing enforcement (baseline to extend, not replace)
- `hooks/common.sh` — canonical block()/emit()/trace_write() library; all Phase 1 hooks must source this
- `hooks/stub-reject.sh` — example of existing PreToolUse hook with block message; Phase 1 hooks follow this style
- `agents/verifier.md` — verifier agent; Phase 1 updates its instructions to scan failure-lib for verifier-check entries

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `hooks/common.sh` — block(), emit(), trace_write() shared library; every new Phase 1 hook sources this; provides the correct exit-2 blocking pattern
- `scripts/test-stub-reject.sh` — injection test idiom: create temp file with bad pattern, invoke hook directly, assert exit 2; replay-giavico-failures.sh follows this exact pattern
- `scripts/force-loop-test.sh`, `scripts/no-verify-cmd-test.sh` — additional examples of the Phase 0 test script style ([PASS]/[FAIL] output, summary at end)
- `agents/verifier.md` — needs instructions added to scan failure-lib/ at runtime for verifier-check entries

### Established Patterns
- Hook test idiom (Phase 0): create temp dir, write bad pattern to file, pipe through hook, assert exit code — this is the injection pattern for replay-giavico-failures.sh
- YAML frontmatter + markdown body: used in SUMMARY files (00-01-SUMMARY.md etc.) — failure-lib entries follow the same convention
- `# tag:` annotation in hook comments — ENFC-02 grep check targets this exact pattern

### Integration Points
- `failure-lib/` — empty stub; Phase 1 populates it with one `.md` file per identified failure
- `~/.claude/hooks/` — installed location; new Phase 1 hooks go here via install.sh (same append pattern)
- `agents/verifier.md` — update instructions section to scan failure-lib at runtime
- `scripts/replay-giavico-failures.sh` — new script, Phase 1 done command

</code_context>

<specifics>
## Specific Ideas

- replay-giavico-failures.sh should follow the same output style as Phase 0 test scripts: each test prints `[PASS] <id>: <description>` or `[FAIL] <id>: <description>`, with a summary line at the end. Makes it consistent with the Phase 0 done command style.
- The verifier.md runtime scan pattern: "Scan `failure-lib/` for files with `enforcement-type: verifier-check` in their YAML frontmatter and apply the check described in the body to the current code." — researcher should find the exact phrasing that works cleanly in an agent instruction.
- For model-crutch entries, the `model-version` field should carry the Claude model ID as used in the harness: `claude-sonnet-4-6` (the model that built Phase 0).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-enforcement-hardening*
*Context gathered: 2026-06-22*
