# Phase 3: Self-Improve Loop - Research

**Researched:** 2026-06-23
**Domain:** Bash/shell tooling, Claude Code hooks, file-based lesson distillation (self-contained — no external libraries)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Threshold trigger mechanics**
- Two triggers for auto-distill; both checked by `stop-hook.sh`:
  - (a) Feature-complete: Stop hook fires after verify exits 0 (successful task completion) → run auto-distill
  - (b) Repeated-failure: same failure-lib `id` matched ≥3 times → run auto-distill
- Hit counts for repeated-failure tracked in `.progress/lesson-hit-counts.json`
- `lessons-on-error.sh` extended to increment the hit count for each matched failure-lib entry; writes to `.progress/lesson-hit-counts.json`
- `stop-hook.sh` checks hit counts on each invocation; if any entry ≥3, trigger auto-distill

**Pending queue storage**
- Candidate lessons live in `failure-lib/pending/` directory as individual `.md` files
- Each candidate file uses the final failure-lib format (`id`/`tags`/`when`/`error-match` frontmatter) plus a required `evidence:` field citing at least one trace entry (tool name, file, exit code, timestamp)
- Candidates are NEVER auto-moved to `failure-lib/` — they stay in `pending/` until human approves or rejects
- Duplicate suppression: auto-distill greps `failure-lib/` (NOT `pending/`) before proposing any lesson; a candidate whose `id` already exists is silently dropped
- `architecture`-tagged rules are never auto-generated; only `model-crutch` rules and low-risk procedural skills go through auto-draft path

**`/retro` skill structure** — single skill at `skills/retro/SKILL.md` with 3 subcommands:
- `approve` — batch-review all files in `failure-lib/pending/`; show each candidate with evidence; human types `y/n` per candidate or `all`; approved committed to `failure-lib/`; rejected deleted from `pending/`
- `run <trace-file>` — manual distill override; calls `scripts/auto-distill.sh` with explicit trace file; errors with "trace required" if no arg given (SELF-01)
- `prune` — review all `model-crutch`-tagged rules in `failure-lib/`; show which carry a model version older than current; human confirms which to retire; retired entries deleted and committed
- `load-lessons.sh` extended to count files in `failure-lib/pending/` at SessionStart; if count > 0, emit one-line notice: "N lessons pending — run `/retro approve` to review"

**Auto-distill script design** — lives at `scripts/auto-distill.sh` (standalone, NOT embedded in stop-hook.sh)
- `stop-hook.sh` calls it when threshold met, passing trace.log path, PROGRESS.md path, failure-lib path
- `/retro run <trace-file>` also calls it with explicit trace file
- Logic: parse trace.log + PROGRESS.md for error patterns/repeated failures → grep failure-lib for dedup → for each novel pattern draft candidate `.md` in `failure-lib/pending/` with evidence field → emit count of candidates written (or "0 new candidates — all patterns already in failure-lib")
- Never proposes `architecture`-tagged rules — only `model-crutch` and procedural skill candidates

**Done command and e2e test** — `./scripts/retro-e2e-test.sh` is the Phase 3 done command. Sequence:
1. Inject synthetic repeated-failure hit into `.progress/lesson-hit-counts.json` (≥3 for a known id)
2. Inject synthetic trace entry into a temp trace file
3. Call `auto-distill.sh` with the temp trace file
4. Verify a candidate appears in `failure-lib/pending/`
5. Verify the candidate has an `evidence:` field
6. Verify duplicate suppression: run auto-distill again — same candidate NOT re-added
7. Run `retro approve` (or equivalent approval script) on the candidate
8. Verify approved lesson appears in `failure-lib/` and was committed to `~/.claude`
- Uses `[PASS] <id>: <description>` / `[FAIL]` style consistent with Phase 0/1 scripts

### Claude's Discretion
- Exact format of `lesson-hit-counts.json` (key structure, versioning)
- How auto-distill handles partial trace files or empty `trace.log`
- Whether `retro-e2e-test.sh` calls `install.sh` as a pre-step (like `replay-giavico-failures.sh` does)
- Exact prose in the pending-queue notice emitted by `load-lessons.sh`

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. Phase 4 (heavy retrieval / vector index) explicitly out of scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SELF-01 | Auto-distill and `/retro` both blocked without a trace file as input | `auto-distill.sh` arg-1 = trace path; missing/empty → `block()` exit 2 with "trace required". `/retro run` forwards arg; errors if absent. Pattern: stub-reject.sh exit-2 + stderr. |
| SELF-02 | Candidate lessons grounded in trace evidence (tool, file, exit code, timestamp) — each cites ≥1 trace entry | Trace format is `TIMESTAMP TOOL TARGET EXIT_CODE` (see trace.sh / common.sh `trace_write`). Candidate `.md` carries `evidence:` frontmatter field copying one trace line verbatim. |
| SELF-03 | Auto-distill fires on threshold trigger (feature-complete OR repeated-failure N≥3), not every session; Stop hook checks threshold, reads trace+PROGRESS+failure-lib, drafts candidates to pending queue, no human action at distill time | Extend `stop-hook.sh`: (a) verify-pass branch (line 106) calls auto-distill; (b) new pre-loop check of `.progress/lesson-hit-counts.json` for any value ≥3. |
| SELF-04 | SessionStart hook surfaces pending queue as one-line notice; extend `load-lessons.sh` (not new hook) | `load-lessons.sh` ends with `jq -n` prompt emission — append pending count line into INDEX or emit second prompt. Count = `find failure-lib/pending -name '*.md'`. |
| SELF-05 | Auto-distill greps failure-lib before proposing; duplicates suppressed, not added to queue | `grep -l "^id: <candidate-id>" failure-lib/*.md` before write; if match, skip. Grep `failure-lib/` only, never `pending/`. |
| SELF-06 | Approved lesson committed to failure-lib in current format (`id`/`tags`/`when`/`error-match`); existing hooks surface it automatically — no separate conversion. Rejected discarded. Old `enforcement-type: verifier-check` tier is gone. | Live failure-lib entries already use the new format (verified: no `enforcement-type` in any live `.md`). `approve` moves file `pending/X.md → failure-lib/X.md` + `git commit` in `~/.claude`. |
| SELF-07 | Prune fires on model version upgrade; reviews `model-crutch`-tagged rules, retires rules current model no longer needs | `/retro prune` reads `tags:` for `model-crutch`, parses model version token, compares to current model, human confirms deletions, commits. (No model-crutch entries exist yet — design must tolerate empty set.) |
| SELF-08 | `/retro` is manual override only (not primary path); accepts explicit trace file, runs same grounded-lesson logic as auto-distill, outputs candidate list for human review | `/retro run <trace>` calls the SAME `scripts/auto-distill.sh` — single source of truth. No duplicated distill logic in the skill. |
| SELF-09 | Skills may be auto-drafted as candidates but never auto-activated without human gate; `architecture` rules never auto-generated unattended — only `model-crutch` + low-risk procedural skills | auto-distill writes ONLY to `pending/`, never `failure-lib/`. Tag whitelist enforced in `auto-distill.sh`: emit only `model-crutch`/procedural candidates, never `architecture`. |
</phase_requirements>

## Summary

Phase 3 is a pure shell-tooling phase inside an existing, well-established harness. There are **no external libraries to research** — the entire surface is Bash, `jq`, `grep`, `find`, `git`, and the Claude Code hook protocol already proven in Phases 0–2. The job is to close the compounding loop by adding two new scripts (`scripts/auto-distill.sh`, `scripts/retro-e2e-test.sh`), one new skill (`skills/retro/SKILL.md`), one new state file (`.progress/lesson-hit-counts.json`), one new directory (`failure-lib/pending/`), and surgical extensions to three existing hooks (`stop-hook.sh`, `load-lessons.sh`, `lessons-on-error.sh`).

The critical research finding is the **live failure-lib format is already the target format**. All six live entries (`dotenv-module-scope`, `eval-subshell`, `home-scope`, `mock-import-boundary`, `openpyxl-engine`, `static-test-fixture`) use `id`/`tags`/`when`/`error-match` frontmatter — none carry `enforcement-type: verifier-check`. (Note: `replay-giavico-failures.sh` still greps for that literal, but the live `.md` files do not have it — this is a latent inconsistency in the Phase 1 test, not a blocker for Phase 3.) This means SELF-06 requires **no format conversion**: an approved candidate is just moved from `pending/` to `failure-lib/` and committed. Existing hooks (`load-lessons.sh`, `lessons-post-write.sh`, `lessons-on-error.sh`) pick it up automatically because they `find failure-lib -name '*.md'`.

The hardest design problems are not technical-novelty but **scoping correctness**: (1) auto-distill must write ONLY to `pending/` (human gate, SELF-09); (2) the tag whitelist must exclude `architecture` (SELF-09); (3) duplicate suppression must grep `failure-lib/` not `pending/` (SELF-05, so re-running does not stack duplicates); (4) `stop-hook.sh` extension must preserve the existing `stop_hook_active` guard and verify-loop exit-code logic exactly (LOOP-01/LOOP-02 regression risk).

**Primary recommendation:** Build `auto-distill.sh` as the single source of truth for distillation logic, called by both `stop-hook.sh` (threshold path) and `/retro run` (manual path). Keep it heuristic and pattern-based (grep trace for repeated `EXIT_CODE != 0` lines + read PROGRESS HISTORY LOG), draft conservatively to `pending/`, and never touch `failure-lib/` directly. Mirror `replay-giavico-failures.sh` for the e2e test harness.

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | system (`/usr/bin/env bash`) | All hook + script logic | Project hard constraint: language-agnostic, grep-based hooks only |
| `jq` | system (already a dependency) | Parse hook JSON stdin; build/read `lesson-hit-counts.json` | Already used in every hook (stop-hook, load-lessons, lessons-on-error, install.sh) |
| `grep` / `find` / `awk` / `sed` | system | Pattern detection, frontmatter parsing, dedup, file enumeration | Established Phase 0–2 idiom; no new dependency |
| `git` | system | Commit approved lessons / pruned rules to `~/.claude` | SELF-06 commit-to-failure-lib; install.sh already git-commits `~/.claude` |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `mktemp` / `mktemp -d` | system | Isolated temp dirs for e2e test fixtures | Mirror `context-reset-test.sh` (uses `mktemp -d`) so real `.progress/` and `failure-lib/` are never touched during test |
| `date -u +"%Y-%m-%dT%H:%M:%SZ"` | system | ISO-8601 UTC timestamps in candidate evidence / commit messages | Matches existing `trace_write` and HANDOFF timestamp format exactly |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `jq`-managed `lesson-hit-counts.json` | Flat `id count` text file | jq gives atomic structured read/write and matches existing tooling; flat file is simpler but inconsistent with project conventions. **Recommend jq.** |
| Embedding distill logic in `stop-hook.sh` | Standalone `scripts/auto-distill.sh` | CONTEXT.md locks standalone script (independently testable, shared by `/retro run`). Embedding would duplicate logic and break SELF-08. **Locked: standalone.** |

**Installation:** None. No package installs. All tools are system-provided and already in use across the harness.

**Version verification:** N/A — no third-party packages. The only "versions" relevant are the Claude **model** versions referenced in `model-crutch` tags (e.g. `claude-sonnet-4-6`), used by `/retro prune` for staleness comparison.

## Architecture Patterns

### File/Directory Layout (additions only)
```
build-anything/
├── hooks/
│   ├── stop-hook.sh          # EXTEND: add threshold check + auto-distill call
│   ├── load-lessons.sh       # EXTEND: append pending-queue notice
│   └── lessons-on-error.sh   # EXTEND: increment hit counts on match
├── scripts/
│   ├── auto-distill.sh       # NEW: standalone distiller (single source of truth)
│   └── retro-e2e-test.sh     # NEW: Phase 3 done command
├── skills/
│   └── retro/
│       └── SKILL.md          # NEW: /retro approve|run|prune
├── failure-lib/
│   └── pending/              # NEW: candidate queue (created by auto-distill on first run)
│       └── .gitkeep          # keep dir tracked when empty
└── .progress/
    └── lesson-hit-counts.json # NEW: runtime hit-count state (gitignored? see Open Q)
```

### Pattern 1: Standalone script as single source of truth (SELF-08)
**What:** `auto-distill.sh` contains ALL distillation logic. Both callers (stop-hook threshold path, `/retro run`) invoke it with a trace-file argument.
**When to use:** Always — never inline distill logic anywhere else.
**Example:**
```bash
# scripts/auto-distill.sh — invoked as: auto-distill.sh <trace-file> [progress-file] [failure-lib-dir]
#!/usr/bin/env bash
# tag: architecture
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../hooks/common.sh"

TRACE_FILE="${1:-}"
# SELF-01: trace file is mandatory
if [ -z "$TRACE_FILE" ] || [ ! -f "$TRACE_FILE" ]; then
  block "auto-distill requires a trace file" "pass a readable trace.log path as argument 1"
fi
PROGRESS_FILE="${2:-$PWD/.progress/PROGRESS.md}"
LIB_DIR="${3:-$HOME/.claude/failure-lib}"
PENDING_DIR="${LIB_DIR}/pending"
mkdir -p "$PENDING_DIR"
# ... pattern detection + dedup + draft ...
```

### Pattern 2: Hook extension preserving existing control flow (SELF-03, SELF-04)
**What:** Add new behavior to existing hooks WITHOUT altering proven exit-code logic.
**When to use:** Editing `stop-hook.sh`, `load-lessons.sh`, `lessons-on-error.sh`.
**`stop-hook.sh` — verify-pass branch (existing line ~106):**
```bash
if ( eval "$VERIFY_CMD" ) > /tmp/verify-stdout.txt 2> /tmp/verify-stderr.txt; then
  emit "Verify passed: ${VERIFY_CMD}"
  sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: 0/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
  # --- SELF-03 (a) feature-complete trigger: distill on successful completion ---
  bash "$(dirname "${BASH_SOURCE[0]}")/../scripts/auto-distill.sh" \
    "${HOME}/.claude/trace.log" "$PROGRESS_FILE" "${HOME}/.claude/failure-lib" >&2 || true
  exit 0
fi
```
**`stop-hook.sh` — repeated-failure trigger (add BEFORE verify loop, after PROGRESS located ~line 28):**
```bash
# --- SELF-03 (b) repeated-failure trigger ---
HIT_FILE="${CWD}/.progress/lesson-hit-counts.json"
if [ -f "$HIT_FILE" ]; then
  MAX_HITS=$(jq -r '[.[]] | max // 0' "$HIT_FILE" 2>/dev/null || echo 0)
  if [ "${MAX_HITS:-0}" -ge 3 ]; then
    bash "$(dirname "${BASH_SOURCE[0]}")/../scripts/auto-distill.sh" \
      "${HOME}/.claude/trace.log" "$PROGRESS_FILE" "${HOME}/.claude/failure-lib" >&2 || true
  fi
fi
```
> CRITICAL: Wrap auto-distill call with `|| true` so a distill error NEVER changes the Stop hook's exit code. The Stop hook's contract (LOOP-01/02) must be untouched. Distillation is best-effort side work, never a gate.

**`load-lessons.sh` — pending notice (append before final `jq -n` ~line 36):**
```bash
PENDING_COUNT=$(find "$LESSONS_DIR/pending" -name "*.md" -not -name ".gitkeep" 2>/dev/null | wc -l | xargs)
if [ "${PENDING_COUNT:-0}" -gt 0 ]; then
  INDEX+=$'\n'"_${PENDING_COUNT} lesson(s) pending — run \`/retro approve\` to review._"$'\n'
fi
jq -n --arg prompt "$INDEX" '{"prompt": $prompt}'
```

**`lessons-on-error.sh` — increment hit count (inside the matched branch ~line 41):**
```bash
[ "$MATCHED" = "true" ] || continue
# --- SELF-03 hit tracking ---
ID=$(grep "^id:" "$f" | head -1 | cut -d: -f2- | xargs)
HIT_FILE="$PWD/.progress/lesson-hit-counts.json"
[ -f "$HIT_FILE" ] || echo '{}' > "$HIT_FILE"
TMP=$(mktemp)
jq --arg id "$ID" '.[$id] = ((.[$id] // 0) + 1)' "$HIT_FILE" > "$TMP" && mv "$TMP" "$HIT_FILE"
MATCHES+="$(cat "$f")"$'\n\n---\n\n'
```

### Pattern 3: Candidate lesson file format (SELF-02, SELF-06)
**What:** A pending candidate is a real failure-lib file plus an `evidence:` field.
**Example (`failure-lib/pending/<id>.md`):**
```markdown
---
id: <kebab-id>
tags: [model-crutch claude-sonnet-4-6, bash]
when: on-error
error-match: <lowercased regex fragment from trace>
evidence: 2026-06-23T14:02:11Z Bash npm-test 1
---

## What happened
<one-line factual summary derived from trace + PROGRESS, no speculation>

## How to avoid
<conservative remediation>
```
> On approval, the file is moved to `failure-lib/<id>.md`. The `evidence:` line MAY be retained (harmless extra frontmatter — hooks only read `id`/`tags`/`when`/`error-match`) or stripped. Recommend retaining for provenance.

### Pattern 4: `/retro` skill as orchestrator, not logic (SELF-08)
**What:** SKILL.md is markdown instructions for Claude; it shells out to scripts, holding no distill logic itself. Mirror `skills/handoff/SKILL.md` style (numbered procedural steps, `disable-model-invocation` where it is a direct action).
**When to use:** `/retro run` → call `scripts/auto-distill.sh`. `/retro approve` and `/retro prune` are interactive review loops (model reads candidates, prompts human y/n, then moves/deletes files + commits).

### Anti-Patterns to Avoid
- **Auto-distill writing to `failure-lib/`:** Violates SELF-09 human gate. Auto-distill writes to `pending/` ONLY.
- **Distilling `architecture`-tagged rules:** Violates SELF-09 / PROJECT.md hard constraint. Tag whitelist must exclude `architecture`.
- **Dedup grep against `pending/`:** Would let re-runs append nothing but also miss true dedup; CONTEXT.md locks grep against `failure-lib/` only (SELF-05).
- **Letting auto-distill change Stop hook exit code:** Breaks LOOP-01/02. Always `|| true` the call.
- **Duplicating distill logic in SKILL.md:** Breaks SELF-08 single-source-of-truth. SKILL calls the script.
- **Per-stack pattern detection:** Violates ENFC-04 language-agnostic constraint. Detect from trace `EXIT_CODE` + generic error text, not stack-specific parsers.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON read/modify for hit counts | Custom sed/awk JSON munging | `jq '.[$id] = ((.[$id] // 0)+1)'` | jq is already a dependency; hand-rolled JSON editing is fragile and inconsistent with the codebase |
| Frontmatter field extraction | Custom YAML parser | `grep "^id:" f | cut -d: -f2- | xargs` | Exact idiom used in load-lessons.sh / lessons-on-error.sh — reuse it |
| Test isolation | Writing into real `.progress/` | `mktemp -d` fixtures | `context-reset-test.sh` proves the pattern; avoids corrupting real state |
| Hook response semantics | New echo/exit conventions | `block()`/`emit()` from `common.sh` | SKEL-06/07 canonical exit-2-on-stderr; source common.sh |
| Committing approved lesson | New git wrapper | `git -C "$HOME/.claude" add/commit` | install.sh already does exactly this for `~/.claude` |

**Key insight:** Phase 3 introduces zero new primitives. Every operation has an existing idiom in the codebase — the work is composition and correct scoping, not invention.

## Common Pitfalls

### Pitfall 1: Source vs installed path divergence
**What goes wrong:** Hooks/scripts run from `~/.claude/` (installed), but you edit `build-anything/` (source). Changes don't take effect until `install.sh` runs. The e2e test asserts on installed state.
**Why it happens:** Two copies — source repo and `~/.claude`. install.sh copies hooks (overwrite), skills (overwrite), failure-lib (never-overwrite).
**How to avoid:** `retro-e2e-test.sh` should call `install.sh` as a pre-step (like `replay-giavico-failures.sh` line 16) OR test against the source tree explicitly via `mktemp -d` fixtures. Note `failure-lib` is **never-overwritten** by install.sh — new committed lessons in source won't propagate to an existing `~/.claude/failure-lib`. For the e2e test, prefer `mktemp -d` isolation so this asymmetry is irrelevant.
**Warning signs:** Test passes on source edit without reinstall (false positive), or fails because `~/.claude` has a stale hook.

### Pitfall 2: `set -euo pipefail` killing the hook on a benign non-zero
**What goes wrong:** `find ... | wc -l` or a `grep` returning no matches (exit 1) aborts the script under `set -e`.
**Why it happens:** `set -e` treats any non-zero as fatal; `grep` returns 1 on no-match. This is the same class as the `eval-subshell` lesson already in failure-lib.
**How to avoid:** Append `|| true` / `|| echo 0` to grep/find expressions, or guard with `if`. The existing hooks already do this (`|| true`, `|| echo ""`). Reuse the pattern.
**Warning signs:** Hook silently exits early; pending notice or hit increment never happens.

### Pitfall 3: Stop hook exit-code regression (LOOP-01/02)
**What goes wrong:** Adding the auto-distill call changes the Stop hook's exit code, breaking the verify loop or the `stop_hook_active` wedge guard.
**Why it happens:** Auto-distill internally exits non-zero (e.g. its own SELF-01 `block` exits 2), and that propagates.
**How to avoid:** ALWAYS call as `bash auto-distill.sh ... >&2 || true`. Place the feature-complete call AFTER `BLOCKED_COUNT` reset and BEFORE `exit 0`. Place the repeated-failure check after PROGRESS-located but it must not early-return. Preserve the `stop_hook_active` guard at the very top untouched.
**Warning signs:** `force-loop-test.sh` or `no-verify-cmd-test.sh` regress; session wedges.

### Pitfall 4: Hit-count file location and lifecycle
**What goes wrong:** Hit counts written to wrong CWD, or never reset, causing perpetual re-distill.
**Why it happens:** `lessons-on-error.sh` runs in project CWD; `stop-hook.sh` uses `cwd` from JSON input. They must agree on `.progress/lesson-hit-counts.json` location.
**How to avoid:** Use `$PWD/.progress/lesson-hit-counts.json` in `lessons-on-error.sh` and `${CWD}/.progress/lesson-hit-counts.json` in `stop-hook.sh` (CWD already derived there). After a successful distill from the repeated-failure trigger, reset the triggering id's count to 0 (so it doesn't re-fire every Stop). This reset behavior is Claude's discretion but recommended.
**Warning signs:** Auto-distill fires every session after first threshold breach; duplicate candidates suppressed only by SELF-05 grep (works, but noisy).

### Pitfall 5: Empty / malformed trace handling
**What goes wrong:** `auto-distill.sh` chokes on an empty `trace.log` or a partial line.
**Why it happens:** Real trace.log lines can contain embedded newlines (observed: multi-line Bash commands span lines in trace.log — see the sample where a `Bash` entry spans 4 physical lines).
**How to avoid:** Match on the structured tail of each trace line (`EXIT_CODE` is the last whitespace token); tolerate multi-line command bodies. On empty trace, emit "0 new candidates" and exit 0 (Claude's discretion confirms graceful handling). Do NOT `block` on empty trace — only `block` when the trace ARG is missing/unreadable (SELF-01).
**Warning signs:** Distill crashes mid-Stop-hook; candidates with garbled evidence.

### Pitfall 6: Prune over an empty model-crutch set (SELF-07)
**What goes wrong:** `/retro prune` errors when no `model-crutch` rules exist (current live failure-lib has none).
**Why it happens:** All 6 live entries are tagged with stack/topic tags (`python`, `bash`, etc.), none are `model-crutch <version>`. Verified via grep: zero `model-crutch` occurrences in `failure-lib/`.
**How to avoid:** Design prune to handle the empty set gracefully ("no model-crutch rules to prune"). The e2e test does not need to exercise prune against a real stale rule unless one is injected as a fixture.
**Warning signs:** Prune subcommand throws on a clean library.

## Code Examples

### Trace line format (the evidence source — SELF-02)
```
# Source: hooks/common.sh trace_write() + ~/.claude/trace.log (verified live)
# Format: TIMESTAMP TOOL TARGET EXIT_CODE
2026-06-22T09:52:32Z Write src/test.py 0
2026-06-22T09:53:53Z Bash bash .../preflight.sh 2>&1 0
# Note: Bash TARGET may span multiple physical lines (multi-line commands).
# EXIT_CODE is the final whitespace-delimited token on the (logical) entry.
```

### Live failure-lib frontmatter (the target format — SELF-06, verified)
```markdown
# Source: failure-lib/openpyxl-engine.md (live)
---
id: openpyxl-engine
tags: [python, pandas, testing]
when: on-error
error-match: xlrd
---
## What happened
...
## How to avoid
...
```
> CONFIRMED: No live entry contains `enforcement-type:`. SELF-06 needs no conversion.

### Duplicate suppression (SELF-05)
```bash
# Source: pattern derived from load-lessons.sh frontmatter idiom
candidate_id="some-new-id"
if grep -rlq "^id: ${candidate_id}\$" "${LIB_DIR}"/*.md 2>/dev/null; then
  emit "skip ${candidate_id}: already in failure-lib"
else
  # draft to pending/
  :
fi
# Grep targets LIB_DIR (failure-lib/), NEVER pending/ — re-runs won't stack duplicates.
```

### Test harness skeleton (mirror replay-giavico-failures.sh)
```bash
# Source: scripts/replay-giavico-failures.sh (structure)
#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL+1)); }
WORK=$(mktemp -d)   # isolated fixtures — never touch real .progress/ or failure-lib/
# ... inject hit counts, synthetic trace, run auto-distill, assert pending candidate ...
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Lessons tagged `enforcement-type: verifier-check`; verifier greps failure-lib | `id`/`tags`/`when`/`error-match` only; hooks surface lessons (`load-lessons`, `lessons-post-write`, `lessons-on-error`); verifier no longer greps failure-lib | Phase 1→2 transition (REQUIREMENTS.md SELF-06 note, 2026-06-23) | SELF-06 = move file + commit; no conversion step |
| Manual lesson authoring only | Threshold-triggered auto-distill drafts candidates; human approves in batch | Phase 3 (this phase) | Closes compounding loop |

**Deprecated/outdated:**
- `enforcement-type: verifier-check` frontmatter — gone from live entries; do NOT generate it in candidates. (Caveat: `replay-giavico-failures.sh` still greps for it — that Phase 1 test is now inconsistent with live data; out of scope to fix here but worth noting in the plan.)
- Distilling on every session — replaced by threshold trigger (SELF-03).

## Open Questions

1. **`lesson-hit-counts.json` schema and reset policy**
   - What we know: Claude's discretion (CONTEXT.md). Must be jq-friendly.
   - What's unclear: flat `{ "<id>": <count> }` vs versioned `{ "version": 1, "counts": {...} }`; whether counts reset after distill or persist.
   - Recommendation: flat `{ "<id>": <count> }` (simplest, jq-trivial). Reset the triggering id to 0 after a repeated-failure distill to prevent re-fire. Document this in the plan.

2. **Should `.progress/lesson-hit-counts.json` be gitignored?**
   - What we know: it is runtime state, like PROGRESS.md (which IS tracked) — but PROGRESS is intentionally committed for handoff.
   - What's unclear: project convention for runtime JSON.
   - Recommendation: gitignore it (pure ephemeral counter, not handoff-relevant). Confirm with planner against `.gitignore`.

3. **e2e test: install.sh pre-step vs mktemp isolation**
   - What we know: Claude's discretion. `replay-giavico-failures.sh` uses install pre-step; `context-reset-test.sh` uses `mktemp -d`.
   - What's unclear: which the Phase 3 done command should use.
   - Recommendation: `mktemp -d` isolation for distill/approve assertions (avoids `~/.claude` mutation and the never-overwrite failure-lib asymmetry), with an optional install pre-step only if asserting on installed hook behavior. Lean mktemp.

4. **Multi-line trace entries breaking evidence extraction**
   - What we know: live trace.log has Bash entries spanning multiple physical lines.
   - What's unclear: robustness of naive line-based parsing.
   - Recommendation: parse by extracting the final token as EXIT_CODE and the leading ISO-timestamp+TOOL as the anchor; tolerate body sprawl. Flag for plan-time test coverage.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash assertion scripts (`[PASS]`/`[FAIL]` convention) — no unit framework |
| Config file | none — scripts are self-contained, run directly |
| Quick run command | `bash scripts/auto-distill.sh <fixture-trace>` (smoke) |
| Full suite command | `bash scripts/retro-e2e-test.sh` (Phase 3 done command) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SELF-01 | Distill blocked without trace arg | smoke | `bash scripts/auto-distill.sh; echo $?` (expect 2) | ❌ Wave 0 |
| SELF-02 | Candidate has `evidence:` field | e2e step 5 | `grep "^evidence:" failure-lib/pending/*.md` | ❌ Wave 0 |
| SELF-03 | Threshold triggers distill (hit≥3 / verify-pass) | e2e steps 1-4 | inject hit-count, run distill, assert pending file | ❌ Wave 0 |
| SELF-04 | SessionStart emits pending notice | smoke | run `load-lessons.sh` with stdin, grep "pending" in output | ❌ Wave 0 |
| SELF-05 | Duplicate suppressed on re-run | e2e step 6 | run distill twice, assert no second candidate | ❌ Wave 0 |
| SELF-06 | Approved lesson lands in failure-lib (current format) + committed | e2e steps 7-8 | run approve, assert `failure-lib/<id>.md` + `git log` | ❌ Wave 0 |
| SELF-07 | Prune reviews model-crutch rules (tolerates empty set) | manual + smoke | `/retro prune` against fixture lib | ❌ Wave 0 |
| SELF-08 | `/retro run` uses same auto-distill.sh | structural | grep SKILL.md calls `auto-distill.sh`; no duplicated logic | ❌ Wave 0 |
| SELF-09 | Auto-distill writes only to pending/, never architecture | structural + e2e | assert no write to `failure-lib/*.md`; assert no `architecture` candidate | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bash scripts/auto-distill.sh <fixture-trace>` smoke (script runs, drafts to pending, no crash)
- **Per wave merge:** `bash scripts/retro-e2e-test.sh` (full Phase 3 sequence)
- **Phase gate:** `retro-e2e-test.sh` exits 0 (all `[PASS]`) before `/gsd:verify-work`; plus regression check `force-loop-test.sh` + `no-verify-cmd-test.sh` still pass (Stop hook untouched)

### Wave 0 Gaps
- [ ] `scripts/auto-distill.sh` — implements SELF-01/02/03/05/09 distill logic (the unit under test)
- [ ] `scripts/retro-e2e-test.sh` — Phase 3 done command, 8-step sequence per CONTEXT.md
- [ ] `failure-lib/pending/.gitkeep` — keep empty pending dir tracked
- [ ] Synthetic fixtures: temp trace file + seeded `lesson-hit-counts.json` (built inline in e2e test via `mktemp -d`)
- [ ] Regression guard: confirm `force-loop-test.sh` + `no-verify-cmd-test.sh` still pass after `stop-hook.sh` edits

## Sources

### Primary (HIGH confidence)
- `hooks/stop-hook.sh` — Stop hook control flow, `stop_hook_active` guard, verify loop, BLOCKED_COUNT (read live)
- `hooks/load-lessons.sh` — SessionStart index injection, `jq -n` prompt emission (read live)
- `hooks/lessons-on-error.sh` — error-match logic, frontmatter parsing idiom (read live)
- `hooks/common.sh` — `block()`/`emit()`/`trace_write()` canonical functions + trace format (read live)
- `failure-lib/*.md` (6 entries) — verified live format is `id`/`tags`/`when`/`error-match`; no `enforcement-type` present
- `install.sh` — failure-lib never-overwrite seeding, skills overwrite, `~/.claude` git commit (read live)
- `scripts/replay-giavico-failures.sh` — `[PASS]`/`[FAIL]` test harness style, install pre-step pattern (read live)
- `skills/handoff/SKILL.md` — skill structure, `disable-model-invocation` (read live)
- `~/.claude/trace.log` — live trace format incl. multi-line Bash entries (read live)
- `.planning/REQUIREMENTS.md` SELF-01..09 — acceptance criteria (read live)
- `.planning/phases/03-self-improve-loop/03-CONTEXT.md` — locked decisions (read live)
- `.planning/config.json` — `nyquist_validation: true` (validation section required)

### Secondary (MEDIUM confidence)
- None — phase is self-contained; no external sources needed.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external deps; all tools verified in live codebase
- Architecture: HIGH — every extension point read directly from live source files
- Pitfalls: HIGH — derived from live code behavior (`set -e`, trace multi-line, never-overwrite seeding) and existing failure-lib lessons
- Format/SELF-06: HIGH — verified live failure-lib carries the target format already

**Research date:** 2026-06-23
**Valid until:** 2026-07-23 (stable — internal shell tooling, no fast-moving deps; only invalidated by changes to the harness itself)
