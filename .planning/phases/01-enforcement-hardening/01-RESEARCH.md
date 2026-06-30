# Phase 1: Enforcement Hardening - Research

**Researched:** 2026-06-22
**Domain:** Claude Code hook enforcement, failure-lib design, bash scripting patterns
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Failure identification:**
- Source of truth: mine trace.log, STATE.md decisions, and phase SUMMARY files (key-decisions + patterns-established fields), PLUS the git history of Phase 0 to find fix-on-fix commits (corrections mid-build reveal what the model got wrong the first time)
- The researcher identifies candidate failures autonomously using heuristics: repeated pattern, clear rule, grep-verifiable — no human approval gate at the identification stage
- The final enforcement rules (hooks written, failure-lib entries committed) are what the human approves at the git commit review stage, not a separate pre-commit gate

**Failure-lib entry format:**
- One file per failure in `failure-lib/` — each entry is its own `.md` file (easy to retire individual entries, Phase 3 can grep per-file)
- Format: YAML frontmatter + markdown body
- Required YAML frontmatter fields: `id` (unique slug), `tag` (architecture|model-crutch), `enforcement-type` (hook|skill|verifier-check|linter), `model-version` (e.g. `claude-sonnet-4-6` — required for model-crutch entries, omit for architecture)
- Human-readable body: what failed, why, the self-fix instruction, and the grep pattern or verifier instruction

**replay-giavico-failures.sh design:**
- Prove method: inject known-bad patterns → invoke hook directly → assert exit 2 (same injection idiom as Phase 0 test scripts: test-stub-reject.sh, test-trace-hook.sh, etc.)
- Scope: one script proves all ENFC-01..04 in a single run:
  - ENFC-01: per-failure injection tests (assert hook fires with exit 2 on bad pattern)
  - ENFC-02: grep all hooks + failure-lib for `tag:` annotation — `grep -rL 'tag:' ~/.claude/hooks/` must return empty
  - ENFC-03: grep all hook block messages for `"How to fix:"` pattern
  - ENFC-04: grep hook bodies for language-specific binary invocations (`node`, `python`, `java`, `kotlin`) — must find none
- Output format: per-entry report — each test line prints `[PASS]` or `[FAIL]` with the failure id; summary at end: `N passed, M failed` — same style as Phase 0 test scripts

**Language-specific findings → enforcement:**
- Python-specific patterns from Phase 0 (openpyxl engine, dotenv module-level scope, mock at import boundary, etc.) CANNOT become language-agnostic grep-based hooks (ENFC-04)
- They go into failure-lib as documented entries with `enforcement-type: verifier-check` (not hook)
- Tag: `model-crutch` (model-version-specific language-weakness) with the Claude model version
- Verifier agent reads failure-lib at runtime — verifier.md instructions tell it to scan `failure-lib/` for entries with `enforcement-type: verifier-check` and apply them as part of its universal kit checks. No static entries added to verifier.md per finding — scalable as failure-lib grows.

### Claude's Discretion
- Exact set of failures identified from Phase 0 (researcher mines these from trace + git + SUMMARY files)
- Order of tests in replay-giavico-failures.sh
- Precise grep patterns for each failure-lib hook entry
- Whether any borderline finding is architecture vs model-crutch

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ENFC-01 | Every failure exposed in the Phase 0 Giavico run is converted to a hook, linter rule, skill, or verifier check | Failure catalogue mined from Phase 0 SUMMARY files, git log, and STATE.md documented below |
| ENFC-02 | Every enforcement rule is tagged `architecture` or `model-crutch`; model-crutch rules carry Claude model version | Tag annotation format defined; existing hook update pattern identified |
| ENFC-03 | Every enforcement hook block message teaches self-fix (explains what failed and how to correct it) | `How to fix:` pattern already exists in common.sh block() function; existing stub-reject.sh confirms pattern |
| ENFC-04 | Hooks are language-agnostic: no per-stack adapters; grep-based detection only | Confirmed existing hooks are language-agnostic; Python-specific findings go to failure-lib as verifier-check entries |
| ENFC-05 | Done check: replay-giavico-failures.sh exits 0 — every failure category from Phase 0 is automatically blocked | replay-giavico-failures.sh design fully specified in CONTEXT.md; injection test idiom confirmed from Phase 0 scripts |
</phase_requirements>

---

## Summary

Phase 1 is a hardening phase, not a feature phase. It converts the lessons that leaked through the Phase 0 Giavico build into machine-enforced rules before those same mistakes recur in Phase 2 and beyond. The phase has three work streams: (A) mine Phase 0 failures and classify them, (B) convert hook-enforceable failures into new hooks and update existing hooks with tag annotations, and (C) write failure-lib entries for Python-specific failures that cannot be grep-enforced and update verifier.md to scan them at runtime.

The critical insight from Phase 0 is that **three classes of failures emerged**: (1) infrastructure bugs that were caught and fixed mid-build (eval subshell, HOME scoping, How-to-fix literal), (2) Python-specific patterns that required explicit knowledge to get right (openpyxl engine, module-level dotenv, mock at import boundary), and (3) structural gaps where enforcement was missing (no tag annotations on existing hooks, How-to-fix not grep-verifiable in hook files directly). Phase 1 must address all three classes.

The done command is `./scripts/replay-giavico-failures.sh`. This script is both the acceptance test AND the design spec for Phase 1. Every task in Phase 1 maps to something this script will test. The planner must design tasks so that after each task, a specific assertion in replay-giavico-failures.sh passes.

**Primary recommendation:** Design Phase 1 as three tasks in order: (1) mine failures and write all failure-lib entries, (2) update existing hooks with tag/How-to-fix annotations + write new hooks for hookable failures, (3) write replay-giavico-failures.sh and update verifier.md. Task 3's done command is the phase done command.

---

## Failure Catalogue (Mined from Phase 0)

This is the core Phase 1 input. Mined from: 00-01-SUMMARY.md, 00-02-SUMMARY.md, 00-03-SUMMARY.md, STATE.md decisions, git log fix-on-fix commits.

### Infrastructure Bugs (fix-on-fix commits in Phase 0 — HIGH confidence)

These were caught and corrected mid-build. Each one is evidence of a model failure that needs enforcement.

| ID | What Failed | Where Caught | Fix Applied | Enforcement Type | Tag |
|----|------------|--------------|-------------|-----------------|-----|
| F-EVAL-SUBSHELL | `eval VERIFY_CMD` in stop-hook.sh exited hook with code 1 instead of 2; set -e propagated eval's exit into parent shell | force-loop-test.sh LOOP-01 returned exit 1 | Wrapped in `( eval VERIFY_CMD )` subshell | hook annotation + failure-lib | architecture |
| F-HOME-SCOPE | `HOME=tmp echo ... \| hook` only set HOME for echo, not for hook process | test-trace-hook.sh printed [FAIL] | Changed to `HOME=tmp bash -c '...'` to scope HOME to both sides of pipeline | failure-lib verifier-check | model-crutch |
| F-HOW-TO-FIX-LITERAL | "How to fix:" string lived in common.sh block() not stub-reject.sh; grep check on stub-reject.sh returned non-zero | Task 1 verification of stub-reject.sh acceptance criteria | Added inline comment `# How to fix:` adjacent to block() call | hook update | architecture |

### Python-Specific Patterns (documented in 00-03-SUMMARY.md — HIGH confidence)

These cannot be grep-enforced (ENFC-04). They go into failure-lib as verifier-check entries.

| ID | What Failed / Pattern | Why It Matters | Enforcement Type | Tag |
|----|----------------------|----------------|-----------------|-----|
| F-OPENPYXL-ENGINE | `pd.read_excel()` without `engine='openpyxl'` fails on .xlsx in pandas 1.2+ | xlrd dropped .xlsx support; silent wrong parsing or ImportError | verifier-check | model-crutch |
| F-DOTENV-SCOPE | `load_dotenv()` called only in main.py; pytest imports fail to resolve ANTHROPIC_API_KEY | load_dotenv() must be at module level in any module that reads env vars at import time | verifier-check | model-crutch |
| F-MOCK-IMPORT-BOUNDARY | Mocking anthropic.Anthropic at global namespace; doesn't intercept already-imported module reference | Must patch at `modules.recommend.anthropic.Anthropic` (the import location) | verifier-check | model-crutch |
| F-STATIC-FIXTURE | Generating test fixture at test time; introduces race condition and non-reproducibility | Commit fixture files as static resources | verifier-check | architecture |

### Structural Gaps (identified from acceptance criteria analysis — HIGH confidence)

These are gaps in the existing harness that Phase 1 must close to satisfy ENFC-02, ENFC-03, ENFC-04.

| ID | Gap | Where It Exists | Fix Required | Tag |
|----|-----|----------------|--------------|-----|
| F-NO-TAG-HOOK | Existing hooks have no `# tag: architecture` or `# tag: model-crutch` annotation | All hooks: common.sh, stub-reject.sh, progress-after-edit.sh, trace.sh, stop-hook.sh | Add `# tag:` comment line to each hook | architecture |
| F-HOW-TO-FIX-GREP | Only stub-reject.sh has `How to fix:` literal; stop-hook.sh block messages don't have this pattern | hooks/stop-hook.sh stderr messages | Add "How to fix:" to stop-hook.sh block messages | architecture |

---

## Standard Stack

### Core (no new dependencies introduced in Phase 1)

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | system | All hook scripts and replay script | Established in Phase 0; language-agnostic per ENFC-04 |
| jq | system | Parse JSON hook input in bash scripts | Established in Phase 0; no alternative |
| grep | system | Pattern detection in hook bodies; annotation checks | POSIX standard; used in all replay-giavico-failures.sh verification steps |

Phase 1 adds no new runtime dependencies. All work is bash scripting and markdown file creation.

### New Artifacts (Phase 1 produces these)

| Artifact | Type | Purpose |
|----------|------|---------|
| `failure-lib/F-*.md` | Markdown files | One file per identified failure; YAML frontmatter + body |
| `hooks/new-hook.sh` | Bash scripts | New PreToolUse/PostToolUse hooks for hookable failures |
| `scripts/replay-giavico-failures.sh` | Bash script | Phase 1 done command; tests all ENFC-01..04 |
| Updated `agents/verifier.md` | Markdown | Adds runtime failure-lib scan instruction |
| Updated existing hooks | Bash scripts | Tag annotations, How-to-fix additions |

---

## Architecture Patterns

### Pattern 1: failure-lib Entry Format

**What:** One `.md` file per failure. YAML frontmatter carries machine-readable fields; body is human-readable explanation.

**When to use:** Every identified failure, whether the enforcement is a hook or a verifier-check.

```markdown
---
id: eval-subshell
tag: architecture
enforcement-type: hook
---

## What Failed

`eval VERIFY_CMD` inside a `set -euo pipefail` shell causes the eval's exit code to propagate
into the parent shell via `-e`. If VERIFY_CMD exits 1, the hook exits 1 (non-blocking), not 2.

## Why It Happens

`set -e` treats a non-zero exit from eval as a fatal error and exits the shell with that code.
The surrounding `if eval; then ... else ... fi` pattern does NOT protect against this —
the `if` construct only suppresses `-e` for the overall condition, not for nested eval.

## How to Fix

Wrap eval in a subshell: `( eval "$VERIFY_CMD" )`. The subshell captures the exit code
without propagating it into the parent shell's `-e` context.

## Grep Pattern / Verifier Instruction

grep-verifiable: `grep -n 'eval.*VERIFY_CMD' hooks/stop-hook.sh` — should only match lines
that use the subshell pattern `( eval`.
```

For `model-crutch` entries, the YAML frontmatter includes the model version:

```markdown
---
id: openpyxl-engine
tag: model-crutch
enforcement-type: verifier-check
model-version: claude-sonnet-4-6
---
```

**Key constraint from CONTEXT.md:** `model-version` field is REQUIRED for model-crutch entries, OMITTED for architecture entries.

### Pattern 2: Tag Annotation in Hook Files

**What:** Every hook script carries a `# tag:` comment line identifying the rule type. This is what ENFC-02 grep checks.

**When to use:** All existing hooks AND every new Phase 1 hook.

```bash
#!/usr/bin/env bash
# stub-reject.sh — PreToolUse hook
# tag: architecture
# SKEL-07: exit 2 blocks; stderr only; chmod +x
# PLAN-01: also blocks Write/Edit if VERIFY_CMD is empty in PROGRESS
```

**Grep verification (ENFC-02 done check):**
```bash
# This must return empty (no files missing tag:)
grep -rL 'tag:' ~/.claude/hooks/
```

The tag comment can appear anywhere in the script header block. Convention: place it as the second or third comment line, after the shebang and hook type description.

### Pattern 3: How-to-fix in Block Messages (ENFC-03)

**What:** Every `block()` call (and every direct `>&2` exit-2 message) must include a "How to fix:" literal string. The common.sh `block(reason, fix)` function already emits this — the fix is to always pass a meaningful second argument.

**When to use:** All blocking hook messages.

**Current state (Phase 0 baseline):**
- `common.sh` block() function emits `How to fix: ${fix}` — already compliant
- `stub-reject.sh` has `# How to fix:` as inline comment — grep-verifiable
- `stop-hook.sh` stop messages are raw `echo "..." >&2` calls that do NOT contain "How to fix:" — must be fixed

**Pattern for new hooks:**
```bash
# ENFC-03 compliant: block() from common.sh already emits "How to fix:"
block "Pattern detected in ${FILE_PATH}" \
  "Describe the concrete fix action here. How to fix: <specific action>"
```

**Pattern for stop-hook.sh fix (raw echo calls):**
```bash
# Before (non-compliant):
echo "Verify failed (attempt ${NEW_COUNT}/${CEILING}): ${VERIFY_CMD} failed." >&2

# After (ENFC-03 compliant):
echo "Verify failed (attempt ${NEW_COUNT}/${CEILING}): ${VERIFY_CMD}" >&2
echo "How to fix: examine verify output above, fix the failing condition, then continue." >&2
```

**Grep verification (ENFC-03 done check):**
```bash
# Every hook block must have "How to fix:" — check all hooks for this pattern
for hook in ~/.claude/hooks/*.sh; do
  grep -q 'How to fix:' "$hook" || echo "[FAIL] Missing 'How to fix:' in $hook"
done
```

### Pattern 4: replay-giavico-failures.sh Structure

**What:** Single script that proves all ENFC-01..04. Follows the Phase 0 test script idiom: `[PASS]`/`[FAIL]` per entry, summary at end.

**When to use:** Phase 1 done command.

```bash
#!/usr/bin/env bash
# replay-giavico-failures.sh — Phase 1 done command
# Proves ENFC-01..04: all Phase 0 failure categories are blocked
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

pass() { echo "[PASS] $1"; ((PASS++)); }
fail() { echo "[FAIL] $1" >&2; ((FAIL++)); }

# ---- ENFC-01: Per-failure injection tests ----
# For each hookable failure: inject bad pattern → invoke hook → assert exit 2

# F-EVAL-SUBSHELL: stop-hook uses subshell eval (architecture)
# (test: force-loop-test.sh already covers this; can be re-invoked here)
bash "$HARNESS_DIR/scripts/force-loop-test.sh" > /dev/null 2>&1 \
  && pass "F-EVAL-SUBSHELL: subshell eval pattern works" \
  || fail "F-EVAL-SUBSHELL: stop-hook eval-subshell fix not effective"

# Additional ENFC-01 injection tests go here...

# ---- ENFC-02: Tag annotation check ----
MISSING=$(grep -rL 'tag:' "$HOME/.claude/hooks/" 2>/dev/null || true)
if [ -z "$MISSING" ]; then
  pass "ENFC-02: all hooks have tag: annotation"
else
  fail "ENFC-02: hooks missing tag: annotation: $MISSING"
fi

# ---- ENFC-03: How-to-fix in all block messages ----
for hook in "$HOME/.claude/hooks/"*.sh; do
  if grep -q 'How to fix:' "$hook"; then
    pass "ENFC-03: How to fix: present in $(basename $hook)"
  else
    fail "ENFC-03: How to fix: MISSING in $(basename $hook)"
  fi
done

# ---- ENFC-04: No language-specific binary invocations ----
for hook in "$HOME/.claude/hooks/"*.sh; do
  if grep -qE '\b(node|python|python3|java|kotlin)\b' "$hook"; then
    fail "ENFC-04: language-specific binary found in $(basename $hook)"
  else
    pass "ENFC-04: no language-specific binaries in $(basename $hook)"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

### Pattern 5: verifier.md Runtime Scan Instruction

**What:** Update verifier.md to scan failure-lib at runtime for `enforcement-type: verifier-check` entries and apply them. No static entries added per finding — the instruction is generic.

**Instruction to add to verifier.md:**

```markdown
3. Failure-lib verifier checks:
   - Scan `~/.claude/failure-lib/` for all `.md` files where YAML frontmatter contains `enforcement-type: verifier-check`
   - For each such file, read the body section "## Verifier Instruction" and apply the described check to the current code
   - Report each check as PASS or FAIL with the specific file ID in the REASON field
```

**Why this is the right approach:** Adding static entries to verifier.md per failure would make the file grow unboundedly and require re-editing for every new failure. The runtime scan approach scales to any number of failure-lib entries and is consistent with Phase 3 self-improve (new lessons auto-added to failure-lib, not verifier.md).

### Pattern 6: Injection Test Idiom for New Hook Behaviors

**What:** The Phase 0 test script pattern, applied to Phase 1 failures. Create temp dir, write bad pattern to file, pipe through hook, assert exit code.

**When to use:** replay-giavico-failures.sh ENFC-01 injection tests.

```bash
# Template for each injection test
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/.progress"
cat > "$TMP_DIR/.progress/PROGRESS.md" << 'EOF'
CURRENT_TASK: test-task
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE
## HISTORY LOG
EOF

# Write the "bad" content that the hook should catch
MOCK_JSON='{"tool_name":"Write","tool_input":{"path":"test.py","content":"BAD PATTERN HERE"}}'

cd "$TMP_DIR"
echo "$MOCK_JSON" | "$HOOK" > /dev/null 2>&1
EXIT_CODE=$?
cd - > /dev/null
rm -rf "$TMP_DIR"

if [ "$EXIT_CODE" -eq 2 ]; then
  pass "F-MYID: hook correctly blocks pattern (exit 2)"
else
  fail "F-MYID: expected exit 2, got ${EXIT_CODE}"
fi
```

### Anti-Patterns to Avoid

- **Adding Python-specific grep patterns to hook scripts:** Violates ENFC-04. Python patterns go to failure-lib as verifier-check entries.
- **Hardcoding failure-lib entry IDs in verifier.md:** Defeats scalability. Use the runtime scan instruction pattern.
- **Testing replay-giavico-failures.sh against the source hooks (not installed hooks):** ENFC-02 grep must check `~/.claude/hooks/` (installed path), not `hooks/` (source path). Run `bash install.sh` before running the replay script.
- **Using `grep -rL 'tag:'` on source hooks before install:** The ENFC-02 check is for installed hooks; source hooks and installed hooks should be identical but the test must target the installed path.
- **Putting `model-version` field on architecture-tagged entries:** Architecture rules are permanent and apply regardless of model. Only model-crutch entries need the model-version field.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Failure classification logic | Custom classification script | Claude's judgment + documented criteria in CONTEXT.md | architecture vs model-crutch is a human judgment call; the criteria are clear (permanent rule = architecture, model-specific weakness = model-crutch) |
| verifier.md dynamic injection | Script that reads failure-lib and writes entries into verifier.md | Runtime scan instruction in verifier.md | Static injection means re-editing verifier.md for every new failure; runtime scan scales |
| YAML frontmatter parser in bash | Custom bash YAML parser | `grep -m1 '^enforcement-type:' file.md \| cut -d: -f2` | bash grep/cut is sufficient for single-field YAML extraction; full parser is over-engineering |
| Hook injection test framework | pytest or custom framework | Direct bash scripts following Phase 0 test idiom | Phase 0 test idiom already proven; adding pytest for bash hook tests adds Node/Python dependency |

**Key insight:** Phase 1 is classification + annotation + scripting, not feature development. The "tools" are grep, sed, and carefully structured markdown. Complexity should be zero.

---

## Common Pitfalls

### Pitfall 1: Testing Installed Hooks, Not Source Hooks

**What goes wrong:** replay-giavico-failures.sh grepping for `tag:` in `hooks/` (source) instead of `~/.claude/hooks/` (installed); source passes but installed fails; ENFC-02 gives false green.

**Why it happens:** It's easier to test the local source files. But ENFC-02 requirement explicitly says "every enforcement rule in `~/.claude/hooks/`".

**How to avoid:** replay-giavico-failures.sh ENFC-02 check must use `grep -rL 'tag:' "$HOME/.claude/hooks/"`. The script must run AFTER `bash install.sh` has been called.

**Warning signs:** ENFC-02 check passes locally but fails on a fresh install.

### Pitfall 2: Python Failures Becoming Hook Patterns

**What goes wrong:** F-OPENPYXL-ENGINE becomes a PreToolUse hook that greps for `pd.read_excel` without `engine=`; immediately violates ENFC-04.

**Why it happens:** Natural instinct is to block the pattern at write time.

**How to avoid:** Check ENFC-04 first: if enforcement requires matching Python-specific constructs (pd., anthropic., import), it goes to failure-lib as verifier-check, not a hook.

**Warning signs:** Any hook grep pattern containing Python library names (`pandas`, `pd\.`, `anthropic`, `pytest`).

### Pitfall 3: Missing How-to-fix in stop-hook.sh

**What goes wrong:** stop-hook.sh uses raw `echo "..." >&2` for its failure messages instead of common.sh `block()`. Raw echo messages don't include "How to fix:" — ENFC-03 grep check fails for stop-hook.sh.

**Why it happens:** stop-hook.sh's failure path uses direct echo statements because it doesn't call `block()` (it does its own exit 2 at the end). The How-to-fix literal is in common.sh's block() function output, but stop-hook.sh bypasses block().

**How to avoid:** In Phase 1, update stop-hook.sh's verify-failure echo block to include `"How to fix: ..."`. Alternatively, refactor to call `block()` from common.sh where appropriate.

**Warning signs:** `grep -q 'How to fix:' ~/.claude/hooks/stop-hook.sh` returns non-zero.

### Pitfall 4: Tag Annotation Only in failure-lib, Not in Hook Files

**What goes wrong:** failure-lib entries have `tag:` in YAML frontmatter but hook scripts themselves lack `# tag:` comment. ENFC-02 checks `~/.claude/hooks/` for `tag:` annotation — hook files without the comment fail the check.

**Why it happens:** Confusion between the failure-lib entry format (YAML frontmatter with `tag:`) and the hook annotation requirement (shell comment `# tag:`).

**How to avoid:** ENFC-02 check is specifically on hook files (`grep -rL 'tag:' ~/.claude/hooks/`). Every `.sh` file in hooks/ must contain a `# tag: architecture` or `# tag: model-crutch` line. failure-lib entries also use tag, but those are not what ENFC-02 checks.

**Warning signs:** replay-giavico-failures.sh ENFC-02 test passes for failure-lib files but `grep -rL 'tag:' ~/.claude/hooks/` returns hook files.

### Pitfall 5: install.sh Not Run Before replay-giavico-failures.sh

**What goes wrong:** Phase 1 artifacts exist in source repo (`hooks/`, `failure-lib/`) but not installed to `~/.claude/`. ENFC-02/ENFC-03/ENFC-04 checks on installed path fail.

**Why it happens:** replay-giavico-failures.sh is a done command; it may be run directly without re-running install.sh.

**How to avoid:** replay-giavico-failures.sh should either (a) call `bash install.sh` at the top, or (b) document as a prerequisite. Safest: include `bash install.sh` as the first step.

**Warning signs:** ENFC-02 grep returns empty in source but non-empty for installed hooks.

---

## Code Examples

### failure-lib Entry: Architecture Tag (F-EVAL-SUBSHELL)

```markdown
---
id: eval-subshell
tag: architecture
enforcement-type: hook
---

## What Failed

`eval VERIFY_CMD` inside `set -euo pipefail` causes the eval's exit code to propagate into
the parent shell via `set -e`. If VERIFY_CMD exits 1, the hook exits 1 (non-blocking), not 2.
The `if eval ...; then` construct does NOT protect against this.

## Why It Happens

`set -e` treats a non-zero exit from eval as a fatal error. The if-condition suppresses -e for
the overall conditional test, but inside the conditional body, -e is still active.

## How to Fix

Wrap eval in a subshell: `( eval "$VERIFY_CMD" )`. The subshell exit code is captured by the
parent as a variable, without triggering -e in the parent shell.

## Grep Pattern

`grep -n 'eval.*VERIFY_CMD' hooks/stop-hook.sh` — confirm match is `( eval` not bare `eval`.
```

### failure-lib Entry: Model-Crutch (F-OPENPYXL-ENGINE)

```markdown
---
id: openpyxl-engine
tag: model-crutch
enforcement-type: verifier-check
model-version: claude-sonnet-4-6
---

## What Failed

`pd.read_excel(path)` without `engine='openpyxl'` fails on .xlsx files in pandas 1.2+.
xlrd dropped .xlsx support; the correct engine must be specified explicitly.

## Why It Happens

Model training data may include older pandas examples (pre-1.2) where engine defaulted to xlrd.
The model generates the older pattern because it appears frequently in training data.

## How to Fix

Always use `pd.read_excel(path, engine='openpyxl')` for .xlsx files.
For .xls files (legacy), use `engine='xlrd'`.

## Verifier Instruction

When reviewing Python code that reads Excel files: check that every `pd.read_excel()` call
for `.xlsx` files includes `engine='openpyxl'`. Flag any call missing this argument.
```

### failure-lib Entry: Model-Crutch (F-DOTENV-SCOPE)

```markdown
---
id: dotenv-module-scope
tag: model-crutch
enforcement-type: verifier-check
model-version: claude-sonnet-4-6
---

## What Failed

`load_dotenv()` called only in `main.py` entrypoint. When pytest imports the module directly,
env vars from .env are not loaded, causing `anthropic.AuthenticationError` in tests.

## Why It Happens

Model places `load_dotenv()` at the script entrypoint only. Modules that reference env vars at
import time (e.g., `client = anthropic.Anthropic()` at module scope) require load_dotenv() in
the module itself, not just in the calling script.

## How to Fix

Call `load_dotenv()` at module level in every module that reads env vars at import time.
Not just in main.py — in the module where the env var is first used.

## Verifier Instruction

When reviewing Python modules that use env vars (os.getenv, os.environ): check that
`load_dotenv()` is called at module level (not just inside a function or in main.py).
Specifically check any module that creates an API client at module scope.
```

### failure-lib Entry: Model-Crutch (F-MOCK-IMPORT-BOUNDARY)

```markdown
---
id: mock-import-boundary
tag: model-crutch
enforcement-type: verifier-check
model-version: claude-sonnet-4-6
---

## What Failed

Mocking `anthropic.Anthropic` at the global namespace (`@patch('anthropic.Anthropic')`) does
not intercept a module that has already imported and bound the name at import time.

## Why It Happens

Python's unittest.mock patches the name binding in a specific namespace. If `recommend.py`
does `import anthropic` and then `client = anthropic.Anthropic()`, patching the global
`anthropic.Anthropic` may not affect the already-bound reference in recommend.py's namespace.

## How to Fix

Patch at the import location: `@patch('modules.recommend.anthropic.Anthropic')`.
The patch target must be where the name is looked up, not where it is defined.

## Verifier Instruction

When reviewing Python test files that mock external SDK clients: verify the patch target uses
the importing module's path (e.g., `modules.recommend.anthropic.Anthropic`), not the SDK's
global namespace (e.g., `anthropic.Anthropic`). Specifically check conftest.py fixtures.
```

### failure-lib Entry: Architecture (F-STATIC-FIXTURE)

```markdown
---
id: static-test-fixture
tag: architecture
enforcement-type: verifier-check
---

## What Failed

Generating test fixture files at test time (e.g., creating sample.xlsx in a fixture function)
introduces race conditions and non-reproducibility. Tests may fail due to file creation order.

## Why It Happens

Natural instinct is to generate fixtures programmatically. But test-time generation depends on
the test environment's write access, timing, and teardown order.

## How to Fix

Commit static fixture files (e.g., fixtures/sample.xlsx) to the repository. Never generate
them at test time. The fixture file is version-controlled and always reproducible.

## Verifier Instruction

When reviewing test files: check that any fixture files referenced in tests (Excel, CSV, JSON,
images) are committed to the repository, not generated by test code. Flag any conftest.py
fixture that creates files rather than pointing to committed files.
```

### Updated stub-reject.sh with Tag Annotation

```bash
#!/usr/bin/env bash
# stub-reject.sh — PreToolUse hook
# tag: architecture
# SKEL-07: exit 2 blocks; stderr only; chmod +x
# PLAN-01: also blocks Write/Edit if VERIFY_CMD is empty in PROGRESS
```

(No other changes to stub-reject.sh body — the `# How to fix:` comment added in Phase 0 already satisfies ENFC-03.)

### Updated stop-hook.sh How-to-fix Addition

The stop-hook.sh verify-failure block currently uses:
```bash
echo "Verify failed (attempt ${NEW_COUNT}/${CEILING}): ${VERIFY_CMD}" >&2
echo "Output: ${VERIFY_OUTPUT}" >&2
echo "Fix the failure and try again. If stuck, the task will be BLOCKED after ${CEILING} attempts." >&2
exit 2
```

Phase 1 update adds "How to fix:" literal:
```bash
echo "Verify failed (attempt ${NEW_COUNT}/${CEILING}): ${VERIFY_CMD}" >&2
echo "Output: ${VERIFY_OUTPUT}" >&2
echo "How to fix: examine the verify output above, correct the failing condition, then attempt the task again." >&2
exit 2
```

### verifier.md Addition

The current verifier.md has two check tiers. Phase 1 adds a third:

```markdown
3. Failure-lib verifier checks:
   - Scan `~/.claude/failure-lib/` for all `.md` files
   - For each file where YAML frontmatter line `enforcement-type: verifier-check` exists:
     read the "## Verifier Instruction" section body
     apply the described check to the current modified files
   - Report each check as PASS or FAIL with the failure id (from `id:` frontmatter field) in REASON
   - If failure-lib/ is empty or no verifier-check entries exist, skip this step and note "No failure-lib checks applicable"
```

---

## What Requires Hook Updates (ENFC-04 Boundary)

**Hookable (grep-enforceable, language-agnostic):**

All of the following can be detected with grep on any file content, regardless of language:

| Pattern | Grep | New or Update? |
|---------|------|----------------|
| Tag annotation missing from hook file | `grep -rL 'tag:'` | Update existing hooks |
| How-to-fix missing from hook block message | `grep -q 'How to fix:'` | Update stop-hook.sh |
| Language-specific binary in hook body | `grep -E '\b(node\|python\|java\|kotlin)\b'` | Verification only (no current violations) |

**Not hookable (Python-specific, goes to failure-lib as verifier-check):**

| Pattern | Why Not Hookable |
|---------|-----------------|
| `pd.read_excel()` without engine arg | Python-specific syntax; violates ENFC-04 if in a hook |
| `load_dotenv()` only in main | Python-specific module pattern; requires AST analysis |
| Mock patch at wrong namespace | Python-specific test pattern; grep would false-positive non-Python files |
| Test fixture generated at runtime | Language-neutral concept but detection requires understanding test framework semantics |

---

## State of the Art

| Phase 0 State | Phase 1 Target | Impact |
|---------------|----------------|--------|
| Hooks have no `# tag:` annotation | All hooks tagged architecture or model-crutch | ENFC-02 grep check passes |
| `How to fix:` only in stub-reject.sh (as comment) | All hooks have this literal in block messages | ENFC-03 grep check passes |
| failure-lib is empty (.gitkeep only) | failure-lib populated with one .md per Phase 0 failure | ENFC-01 satisfied |
| verifier.md has two check tiers | verifier.md has three tiers (adds failure-lib runtime scan) | Python-specific failures enforced by verifier |
| No replay script exists | `scripts/replay-giavico-failures.sh` exits 0 | ENFC-05 satisfied |
| Python failures documented only in SUMMARY | Python failures encoded as verifier-check entries in failure-lib | Failures enforced mechanically |

---

## Open Questions

1. **How many new hooks does Phase 1 actually need?**
   - What we know: All identified hookable failures are either infrastructure fixes (eval-subshell: already fixed in stop-hook.sh) or tag/how-to-fix annotation gaps (update existing hooks, no new hooks)
   - What's unclear: Whether there are additional hookable failure categories not visible from SUMMARY files (e.g., patterns from the git history of giavico repo)
   - Recommendation: Check `git log --oneline ~/Work/mine/giavico` for fix-on-fix commits before finalizing the failure catalogue; the current catalogue is based on Phase 0 build-anything history only

2. **Should replay-giavico-failures.sh call install.sh at the top?**
   - What we know: The script checks installed hooks at `~/.claude/hooks/`; installed hooks may be stale if source was updated without re-running install
   - What's unclear: Whether calling install.sh inside the done script is idempotent enough to be safe
   - Recommendation: Prefix replay-giavico-failures.sh with `bash "$HARNESS_DIR/install.sh" --quiet 2>/dev/null || true` and document the install step clearly; install.sh should be idempotent (re-running it just re-copies files)

3. **Is F-HOME-SCOPE hookable?**
   - What we know: HOME scoping issue was in a test script, not in production hook code; the pattern is test-specific bash idiom
   - What's unclear: Whether this warrants a failure-lib entry (it affected test writing) or is too low-level
   - Recommendation: Include it as a failure-lib entry with `enforcement-type: verifier-check`; verifier instruction tells it to check test scripts that pipe commands and set HOME, confirming they use `bash -c` form

---

## Validation Architecture

`nyquist_validation: true` in `.planning/config.json` — Validation Architecture section is included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash scripts (no test framework — consistent with Phase 0 approach) |
| Config file | none |
| Quick run command | `bash scripts/replay-giavico-failures.sh` |
| Full suite command | `bash scripts/replay-giavico-failures.sh` (single script covers all ENFC-01..04) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ENFC-01 | All Phase 0 failures have enforcement | injection | `bash scripts/replay-giavico-failures.sh` (ENFC-01 section) | ❌ Wave 0 |
| ENFC-02 | All hooks tagged architecture or model-crutch | grep | `grep -rL 'tag:' ~/.claude/hooks/` returns empty | ❌ Wave 0 (existing hooks lack tag) |
| ENFC-03 | All hook block messages contain "How to fix:" | grep | `for f in ~/.claude/hooks/*.sh; do grep -q 'How to fix:' "$f" || echo FAIL; done` | ❌ Wave 0 (stop-hook.sh missing) |
| ENFC-04 | No language-specific binaries in hook bodies | grep | `grep -rE '\b(node\|python\|java\|kotlin)\b' ~/.claude/hooks/` returns empty | ❌ Wave 0 (verify no violations exist) |
| ENFC-05 | replay-giavico-failures.sh exits 0 | integration | `bash scripts/replay-giavico-failures.sh` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bash scripts/replay-giavico-failures.sh` (once it exists)
- **Per wave merge:** `bash scripts/replay-giavico-failures.sh`
- **Phase gate:** `bash scripts/replay-giavico-failures.sh` exits 0 before phase complete

### Wave 0 Gaps

- [ ] `failure-lib/eval-subshell.md` — covers ENFC-01 (F-EVAL-SUBSHELL)
- [ ] `failure-lib/openpyxl-engine.md` — covers ENFC-01 (F-OPENPYXL-ENGINE)
- [ ] `failure-lib/dotenv-module-scope.md` — covers ENFC-01 (F-DOTENV-SCOPE)
- [ ] `failure-lib/mock-import-boundary.md` — covers ENFC-01 (F-MOCK-IMPORT-BOUNDARY)
- [ ] `failure-lib/static-test-fixture.md` — covers ENFC-01 (F-STATIC-FIXTURE)
- [ ] `failure-lib/home-scope.md` — covers ENFC-01 (F-HOME-SCOPE)
- [ ] Updated `hooks/stub-reject.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `hooks/progress-after-edit.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `hooks/trace.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `hooks/stop-hook.sh` — add `# tag: architecture` + add "How to fix:" to block messages (ENFC-02, ENFC-03)
- [ ] Updated `hooks/common.sh` — add `# tag: architecture` (ENFC-02)
- [ ] Updated `agents/verifier.md` — add failure-lib runtime scan instruction (ENFC-01 verifier-check path)
- [ ] `scripts/replay-giavico-failures.sh` — phase done command (ENFC-05)

---

## Sources

### Primary (HIGH confidence)
- `00-02-SUMMARY.md` — Phase 0 Plan 02 SUMMARY; documents three auto-fixed bugs with root cause analysis; direct source for F-EVAL-SUBSHELL, F-HOME-SCOPE, F-HOW-TO-FIX-LITERAL
- `00-03-SUMMARY.md` — Phase 0 Plan 03 SUMMARY; documents Python-specific patterns in key-decisions and patterns-established fields; direct source for F-OPENPYXL-ENGINE, F-DOTENV-SCOPE, F-MOCK-IMPORT-BOUNDARY, F-STATIC-FIXTURE
- `STATE.md §Decisions` — corroborates all key decisions from Phase 0; confirms eval-subshell fix and HOME override
- `git log 72bb1ac` — fix-on-fix commit; confirms which Phase 0 bugs were corrections vs first-pass
- `hooks/common.sh`, `hooks/stub-reject.sh`, `hooks/stop-hook.sh` — read directly; confirms which hooks already have "How to fix:" and which don't; confirms no `# tag:` annotations exist yet

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` ENFC-01..04 — defines exact grep patterns for ENFC-02, ENFC-03, ENFC-04 acceptance criteria; used to determine what replay-giavico-failures.sh must check

### Tertiary (LOW confidence)
- None — all findings derived from first-party project artifacts

---

## Metadata

**Confidence breakdown:**
- Failure catalogue: HIGH — sourced directly from SUMMARY files and git log; all entries have concrete evidence
- Architecture patterns: HIGH — failure-lib format and tag annotation patterns derived from CONTEXT.md locked decisions
- Hook update requirements: HIGH — read existing hook files directly; confirmed which lack tag and How-to-fix
- replay-giavico-failures.sh design: HIGH — derived from CONTEXT.md locked decision (injection idiom, output format)
- verifier.md update pattern: HIGH — derived from CONTEXT.md locked decision (runtime scan, no static entries)

**Research date:** 2026-06-22
**Valid until:** 2026-07-22 (harness design is stable; re-verify if Claude Code hook API changes)
