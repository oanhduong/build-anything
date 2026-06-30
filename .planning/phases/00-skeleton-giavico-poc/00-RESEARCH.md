# Phase 0: Skeleton + Giavico PoC - Research

**Researched:** 2026-06-22
**Domain:** Claude Code hook enforcement skeleton + Python Excel/AI PoC
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Harness repo strategy:**
- `build-anything` (this repo) is the harness source — hooks/, agents/, skills/, failure-lib/, CLAUDE.md live here and are installed into `~/.claude`
- Install script merges harness assets into `~/.claude` — never clobbers existing GSD files
- Install appends new hooks to existing settings.json arrays (GSD hooks stay, harness hooks appended after)
- Repo ships a harness-only baseline `settings.json`; on a fresh machine (no GSD) this is written as-is; on the current machine the install script merges it
- `~/.claude` stays as the active GSD install; harness files are added alongside, not replacing

**Giavico PoC:**
- Runtime: Python (pandas + openpyxl for Excel ingestion; Anthropic Python SDK for AI recommendations)
- Location: standalone repo at `~/Work/mine/giavico` — separate from build-anything
- Module 3 AI backend: Claude API via Anthropic Python SDK; specific model TBD at plan time (Haiku or Sonnet)
- Done command uses `cd giavico && ...`

**Hook coexistence with GSD:**
- Three new harness hooks appended to existing settings.json arrays: progress-after-edit and trace → PostToolUse; stub-reject → PreToolUse
- GSD hooks execute first (existing array order preserved); harness hooks appended
- Shared library: `common.sh` (bash) — canonical exit-2 blocking, stderr emission, trace writing; every harness hook sources it
- No per-stack adapters; grep-based detection only
- Trace entry format: one-line plain text — `TIMESTAMP TOOL TARGET EXIT_CODE` — appended to `~/.claude/trace.log`

**Stop hook + verification loop:**
- Phase researcher must confirm exact Stop hook API (field names, exit code behavior, `stop_hook_active` semantics) — THIS IS RESOLVED BELOW
- LOOP-02 iteration counter lives in the PROGRESS file (a BLOCKED_COUNT field)
- PLAN-01 enforcement: both preflight check AND runtime enforcement (PreToolUse hook blocks Write/Edit if no verify command in PROGRESS)

### Claude's Discretion
- Exact PROGRESS file schema fields (beyond: CURRENT STATE + HISTORY LOG + BLOCKED_COUNT)
- Specific Claude model for Giavico module 3 (Haiku vs Sonnet)
- Trace log rotation policy (if any)
- Preflight check ordering within `preflight.sh`

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SKEL-01 | Harness global layer installs at `~/.claude` as versioned git repo with defined directory layout | Directory layout design in Architecture Patterns; git init strategy documented |
| SKEL-02 | Project bootstrap drops ~100-line CLAUDE.md + docs/ into any target repo | CLAUDE.md format and KV-cache constraints documented in Architecture Patterns |
| SKEL-03 | 7 preflight checks verified before any real build work | All 7 checks mapped to specific test patterns in Validation Architecture |
| SKEL-04 | PostToolUse hook updates PROGRESS file after every Write/Edit; two sections: CURRENT STATE + HISTORY LOG | Hook stdin/stdout protocol fully documented; PostToolUse behavior confirmed |
| SKEL-05 | Verifier subagent at `~/.claude/agents/verifier.md` with disallowedTools: Write, Edit and permissionMode: dontAsk | Subagent frontmatter fields confirmed from official docs; session restart requirement resolved |
| SKEL-06 | `common.sh` shared library with canonical hook-response functions | Shell patterns documented in Code Examples |
| SKEL-07 | All enforcement hooks use exit code 2 for blocking; stderr not stdout; all chmod +x | Exit code semantics verified from official docs; confirmed exit 1 is non-blocking |
| PLAN-01 | Every task carries a machine-runnable verify command; tasks without one are BLOCKED from execution | PreToolUse hook blocking pattern documented; PROGRESS schema includes verify-command field |
| LOOP-01 | Stop hook runs task's verify command when Claude tries to end turn; fail → exit 2 → Claude must continue | Stop hook JSON input fully documented; `stop_hook_active` field confirmed and semantics resolved |
| LOOP-02 | Stop hook bounded: at ceiling of 2–3 iterations writes BLOCKED to PROGRESS and stops forcing | BLOCKED_COUNT in PROGRESS pattern documented; ceiling logic in Code Examples |
| ONBD-01 | Kit ships a one-step install path placing hooks, agents, commands, skills, settings.json into `~/.claude` | Install script strategy documented; JSON merge pattern for settings.json arrays |
| ONBD-02 | Kit runs without GSD; global hooks fire on any Claude Code session | settings.json merge behavior confirmed; GSD independence pattern documented |
| GIAV-01 | Giavico module 1: read arbitrary Excel file, detect and infer schema | pandas 3.0.3 + openpyxl 3.1.5 pattern documented; schema detection pattern in Code Examples |
| GIAV-02 | Giavico module 2: map detected schema into normalized structure | Normalization pattern documented; no external library needed beyond pandas |
| GIAV-03 | Giavico module 3: analyze normalized data, output AI recommendations | Anthropic Python SDK 0.111.0 documented; model selection guidance (Haiku vs Sonnet) |
| GIAV-04 | All 3 modules callable end-to-end in a single run producing real output | Entry-point pattern documented; pytest integration for verification |
| GIAV-05 | Human owner verifies: app starts, all 3 modules callable (binary pass/fail, recorded in PROGRESS) | Human-verify PASS pattern documented; PROGRESS recording format specified |
</phase_requirements>

---

## Summary

Phase 0 builds two things: (A) a verified Claude Code hook enforcement skeleton installed at `~/.claude`, and (B) a Python PoC (Giavico) that runs three modules end-to-end under that enforcement. The two sub-goals are tightly coupled — the harness must be proven functional before the PoC run, because the PoC run is the evidence-collection event for all future phases.

The most critical research finding is the **hook enforcement triad**: exit code 2 (not 1) for blocking, stderr (not stdout) for messages, and chmod +x on all hook scripts. These three are independent silent failure modes — any one of them makes enforcement appear operational while being completely inactive. All prior project research confirmed this; this phase research verifies it from current official docs (code.claude.com/docs/en/hooks, fetched 2026-06-22).

The two confirmed research gaps from STATE.md are now resolved: (1) `stop_hook_active` IS a real field in the Stop hook JSON input — confirmed from official issue tracker (anthropics/claude-code#10412) and practitioner documentation; (2) adding a `.md` file directly to `~/.claude/agents/` DOES require a session restart — confirmed from official Claude Code subagents documentation ("Subagents are loaded at session start. If you add or edit a subagent file directly on disk, restart your session to load it.").

**Primary recommendation:** Build the harness skeleton first (preflight.sh + three hooks + common.sh + install.sh), verify all 7 preflight checks pass, THEN build the Giavico PoC. Do not start Giavico until preflight exits 0.

---

## Standard Stack

### Core — Harness

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | system (zsh compat) | Hook scripts, install script, preflight.sh | Language-agnostic; no runtime dependency; Claude Code hook `command` type executes shell directly |
| Claude Code hooks API | current (2026-06-22) | PreToolUse, PostToolUse, Stop lifecycle events | Native platform primitive; only reliable enforcement mechanism |
| `jq` | system | Parse JSON hook input in bash scripts | Standard JSON tool in all hook scripts; no alternative needed |
| `settings.json` merge | native | Combine global + project hook arrays additively | Array keys merge additively; scalar keys project-wins; no tooling needed |

### Core — Giavico PoC

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python | 3.12.4 (installed) | Runtime for all 3 Giavico modules | Locked decision; pandas + anthropic SDK require Python |
| pandas | 3.0.3 (latest) | Excel ingestion, schema detection, normalization | Standard for DataFrame-based Excel work; openpyxl backend for .xlsx |
| openpyxl | 3.1.5 (latest) | `.xlsx` read engine for pandas.read_excel | Default engine for modern Excel files; required by pandas |
| anthropic | 0.111.0 (latest, 0.105.0 installed) | Claude API calls for module 3 AI recommendations | Locked decision; official Python SDK |
| pytest | 7.4.3 (installed) | Module test runner; maps to `python -m pytest` in done command | Already installed; standard Python test framework |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `python3 -m venv` | stdlib | Isolate Giavico dependencies | Always — keeps system Python clean; install in `giavico/.venv/` |
| `python-dotenv` | latest | Load `ANTHROPIC_API_KEY` from `.env` | Giavico module 3 only; avoids hardcoding API key |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bash for hooks | Node.js | Node.js is what GSD uses; bash avoids Node.js version dependency, starts faster, no package.json needed in `~/.claude/` |
| pandas for schema detection | polars | pandas is locked decision; polars would be faster but introduces another dependency |
| pytest | unittest | pytest already installed; better output, parametrize support |

**Installation:**
```bash
# Giavico dependencies only (harness uses system bash + jq)
cd ~/Work/mine/giavico
python3 -m venv .venv
source .venv/bin/activate
pip install pandas==3.0.3 openpyxl==3.1.5 anthropic python-dotenv pytest
```

**Version verification (confirmed 2026-06-22):**
- pandas: `pip3 install pandas --dry-run` → 3.0.3 is current
- anthropic: `pip3 install anthropic --dry-run` → 0.111.0 is current (0.105.0 installed locally)
- openpyxl: 3.1.5 per PyPI (confirmed via search)
- pytest: 7.4.3 installed, sufficient for this phase

---

## Architecture Patterns

### Recommended Project Structure — Harness Repo (`build-anything`)

```
build-anything/                    # harness SOURCE repo
├── hooks/
│   ├── common.sh                  # shared: block(), emit(), trace_write()
│   ├── progress-after-edit.sh     # PostToolUse: Write/Edit → update PROGRESS
│   ├── stub-reject.sh             # PreToolUse: Write/Edit → grep for pass$/TODO/NotImplemented
│   ├── trace.sh                   # PostToolUse: write TIMESTAMP TOOL TARGET EXIT_CODE to trace.log
│   └── stop-hook.sh               # Stop: run verify command; exit 2 on fail; check BLOCKED_COUNT
├── agents/
│   └── verifier.md                # disallowedTools: Write, Edit; permissionMode: dontAsk
├── skills/                        # (empty in Phase 0; populated in later phases)
├── failure-lib/                   # (empty in Phase 0; populated from Giavico run)
├── CLAUDE.md                      # ~100-line TOC; stable content at top
├── settings.json                  # harness-only baseline (GSD-free machines)
├── preflight.sh                   # 7 checks; exits 0 iff all pass
├── install.sh                     # merges harness into ~/.claude; appends to arrays
└── scripts/
    ├── no-verify-cmd-test.sh      # validates PLAN-01 enforcement (exit 0 iff enforced)
    └── force-loop-test.sh         # validates LOOP-01/LOOP-02 (exit 0 iff loop + ceiling work)
```

### Recommended Project Structure — Giavico PoC (`~/Work/mine/giavico`)

```
giavico/
├── modules/
│   ├── ingest.py                  # module 1: pd.read_excel + schema detection
│   ├── normalize.py               # module 2: detected schema → normalized structure
│   └── recommend.py               # module 3: anthropic client.messages.create()
├── main.py                        # entry point: chains all 3 modules
├── tests/
│   ├── test_ingest.py             # pytest for module 1
│   ├── test_normalize.py          # pytest for module 2
│   └── test_recommend.py          # pytest for module 3 (can use fixture; no live API needed)
├── fixtures/
│   └── sample.xlsx                # minimal Excel file for testing (commit to repo)
├── .venv/                         # gitignored
├── .env                           # gitignored; ANTHROPIC_API_KEY=...
├── .env.example                   # committed; shows required vars
├── requirements.txt               # pinned versions
└── pytest.ini                     # testpaths = tests; needed for `cd giavico && python -m pytest`
```

### Pattern 1: Hook JSON Input/Output Protocol

**What:** All Claude Code hooks receive a JSON object on stdin. They return decisions via stdout JSON or stderr (for blocking).

**When to use:** Every hook script follows this protocol.

```bash
# Source: https://code.claude.com/docs/en/hooks (fetched 2026-06-22)
#!/usr/bin/env bash
set -euo pipefail

# Read JSON from stdin
INPUT=$(cat)

# Parse fields with jq
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')

# Block with exit 2 — message MUST go to stderr, never stdout
if some_condition; then
  echo "BLOCK: reason — How to fix: do X instead" >&2
  exit 2
fi

# Exit 0 = allow / no decision
exit 0
```

**Exit code semantics (official docs, verified):**

| Event | Exit 0 | Exit 2 | Exit 1 (or other) |
|-------|--------|--------|-------------------|
| PreToolUse | Allow tool call (no decision) | BLOCK tool call | Non-blocking error (tool runs anyway) |
| PostToolUse | Success | Non-blocking (tool already ran; shows stderr to Claude) | Non-blocking error |
| Stop | Allow Claude to finish | BLOCK stopping — Claude must continue | Non-blocking error |

**Key:** Exit 1 is NEVER blocking. Only exit 2 blocks. This is the most common silent failure mode.

### Pattern 2: Stop Hook with Loop Guard

**What:** Stop hook runs the task's verify command. On failure → exit 2 with reason → Claude continues. Bounded by BLOCKED_COUNT in PROGRESS.

**When to use:** LOOP-01 and LOOP-02 implementation.

```bash
# Source: https://code.claude.com/docs/en/hooks + anthropics/claude-code#10412
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

# CRITICAL: check stop_hook_active to prevent infinite loop
# When Claude is already in "forced continuation" from a prior block,
# stop_hook_active is true — MUST exit 0 in that case
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  # Already blocked once; do not block again — prevents wedge
  exit 0
fi

# Read verify command and blocked count from PROGRESS
PROGRESS_FILE="${CWD:-$PWD}/.progress/PROGRESS.md"
VERIFY_CMD=$(grep "^VERIFY_CMD:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs)
BLOCKED_COUNT=$(grep "^BLOCKED_COUNT:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs)
BLOCKED_COUNT=${BLOCKED_COUNT:-0}

# No verify command = not in a task context; allow stop
if [ -z "$VERIFY_CMD" ]; then
  exit 0
fi

# Ceiling check (LOOP-02): 2–3 iterations max
CEILING=3
if [ "$BLOCKED_COUNT" -ge "$CEILING" ]; then
  # Write BLOCKED to PROGRESS and allow stop (escalate to human)
  # ... update PROGRESS BLOCKED_COUNT and CURRENT STATE ...
  exit 0
fi

# Run the verify command
if eval "$VERIFY_CMD" 2>/dev/null; then
  # Verify passed — allow Claude to stop
  exit 0
else
  # Verify failed — increment counter, block stopping
  NEW_COUNT=$((BLOCKED_COUNT + 1))
  # ... update BLOCKED_COUNT in PROGRESS ...
  echo "Verify failed (attempt $NEW_COUNT/$CEILING): $VERIFY_CMD failed. Fix the failure and try again." >&2
  exit 2
fi
```

**Stop hook JSON input (confirmed from official docs + issue #10412):**
```json
{
  "session_id": "uuid-string",
  "stop_hook_active": false,
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/directory",
  "hook_event_name": "Stop",
  "permission_mode": "default"
}
```

### Pattern 3: settings.json Hook Array Merge

**What:** `~/.claude/settings.json` hook arrays combine additively with `.claude/settings.json`. Appending to the array is the established pattern.

**When to use:** Install script and baseline settings.json.

```json
// ~/.claude/settings.json — after install (GSD hooks stay first, harness appended)
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [{ "type": "command", "command": "node ~/.claude/hooks/gsd-existing.js" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/stub-reject.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [{ "type": "command", "command": "node ~/.claude/hooks/gsd-context-monitor.js" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/progress-after-edit.sh" }]
      },
      {
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/trace.sh" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/stop-hook.sh" }]
      }
    ]
  }
}
```

**Merge behavior (verified from official docs):**
- Array keys (like `hooks.PostToolUse`) combine additively — global + project hooks both run
- Scalar keys (like `model`) — project value wins
- No tool needed; Claude Code handles the merge automatically at session start

### Pattern 4: Subagent Definition (SKEL-05)

**What:** Verifier subagent defined as a Markdown file with YAML frontmatter. User-scope = available in every project.

**When to use:** verifier.md at `~/.claude/agents/verifier.md`.

```markdown
---
name: verifier
description: Runs verification checks against the current task. Use when a task's verify command needs to be executed to confirm completion. Executes criteria — never invents them.
disallowedTools: Write, Edit
permissionMode: dontAsk
model: haiku
---

You are a read-only verifier. You execute the verification criteria provided to you. You NEVER invent criteria.

Your check order:
1. Universal kit checks: no stubs (grep for `pass$`/`TODO`/`NotImplemented` in modified files), real run not just compile, every declared function is called
2. Phase-specific verify command from PROGRESS (VERIFY_CMD field)

Output format:
VERDICT: PASS | FAIL | PARTIAL
REASON: [what was checked and result]
```

**Session restart requirement (CRITICAL — confirmed from official docs):**
"Subagents are loaded at session start. If you add or edit a subagent file directly on disk, restart your session to load it. Subagents created through the /agents interface take effect immediately without a restart."

**Implication for install flow:** The install script writes `verifier.md` to `~/.claude/agents/verifier.md`, but it only becomes available after the NEXT Claude Code session start. The install script or preflight.sh must document this clearly. The ONBD-01 done check must therefore be performed in a fresh session after install.

### Pattern 5: Excel Ingestion + Schema Detection (GIAV-01)

**What:** Read arbitrary Excel file with pandas, infer column types, detect header row, produce schema dict.

**When to use:** Giavico module 1 (`ingest.py`).

```python
# Source: pandas 3.0.3 docs + openpyxl 3.1.5 docs
import pandas as pd
from pathlib import Path

def ingest_excel(path: str | Path) -> dict:
    """Read Excel file and detect schema."""
    df = pd.read_excel(path, engine="openpyxl")  # engine required for .xlsx

    schema = {
        "row_count": len(df),
        "columns": {
            col: {
                "dtype": str(df[col].dtype),
                "null_count": int(df[col].isna().sum()),
                "sample": df[col].dropna().iloc[:3].tolist() if not df[col].dropna().empty else []
            }
            for col in df.columns
        }
    }
    return schema, df
```

**Key notes:**
- `engine="openpyxl"` is required for .xlsx files — without it, pandas may warn or fail
- pandas 3.0.3 requires Python >= 3.11 (Python 3.12.4 is installed — compatible)
- Use `pd.ExcelFile` for multi-sheet detection if needed

### Pattern 6: Anthropic SDK for AI Recommendations (GIAV-03)

**What:** Send normalized data to Claude API and return recommendations.

**When to use:** Giavico module 3 (`recommend.py`).

```python
# Source: Anthropic Python SDK 0.111.0
import anthropic
from dotenv import load_dotenv

load_dotenv()  # reads ANTHROPIC_API_KEY from .env

def get_recommendations(normalized_data: dict) -> str:
    """Analyze normalized data and return AI recommendations."""
    client = anthropic.Anthropic()  # uses ANTHROPIC_API_KEY env var

    message = client.messages.create(
        model="claude-haiku-4-5",  # Haiku: fast + cheap for PoC
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": f"Analyze this dataset schema and provide 3 recommendations:\n{normalized_data}"
        }]
    )
    return message.content[0].text
```

**Model selection (Claude's Discretion):**
- Use `claude-haiku-4-5` for Phase 0 PoC (faster, cheaper, sufficient for schema analysis)
- Upgrade to Sonnet only if Haiku output quality is insufficient (this is a PoC, not production)
- Check available model IDs at plan time via `anthropic.models.list()` if needed

### Anti-Patterns to Avoid

- **Exit 1 for blocking:** Use only exit 2. Exit 1 is silently non-blocking in all hook types.
- **stdout for error messages:** All human-readable output MUST go to stderr (`>&2`). stdout is the JSON machine-readable channel — any non-JSON there causes silent protocol failure.
- **Dynamic content in CLAUDE.md:** No timestamps, no PROGRESS tail, no current-task notes. Breaks KV-cache prefix. PROGRESS content belongs in `.progress/PROGRESS.md` only.
- **Verifier that can write:** The verifier subagent MUST have `disallowedTools: Write, Edit`. Without it, the verifier can rationalize broken output.
- **Stop hook without stop_hook_active guard:** A Stop hook that always exits 2 wedges the session permanently. Always check `stop_hook_active` and exit 0 when it is true.
- **Adding verifier.md then testing immediately:** New agents require a session restart after direct file creation. Plan time must account for this.
- **Hardcoding ANTHROPIC_API_KEY:** Use `.env` + `python-dotenv`. The key must not appear in committed code.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash hooks | Custom string parsing / sed/awk | `jq` | jq handles escaping, null, nested fields; string parsing breaks on whitespace and special chars |
| Excel file reading | Custom xlrd/zipfile parsing | `pandas.read_excel(engine="openpyxl")` | Handles merged cells, dates, multiple types, encoding; xlrd dropped .xlsx support |
| settings.json merge during install | Write the whole file from scratch | Read → jq merge → write back | Overwriting clobbers GSD hooks; jq's `*` operator merges arrays correctly |
| HTTP client for Anthropic API | requests + manual retry/backoff | `anthropic` SDK | SDK handles auth, retries, streaming, model validation, error types |
| Test sample Excel file generation | Complex Excel builder | Static `fixtures/sample.xlsx` committed to repo | Reproducible; no dependency on generation; works offline |
| PROGRESS file locking | Custom lockfile mechanism | Append-only writes + grep | Hooks are sequential per event; concurrent writes are not a concern in Phase 0 |

**Key insight:** The harness hooks run sequentially (one at a time per event); multi-process contention on PROGRESS is not a Phase 0 concern. Keep the PROGRESS update logic simple: grep + sed for the CURRENT STATE section, `>>` append for HISTORY LOG.

---

## Common Pitfalls

### Pitfall 1: Exit Code 1 Silently Not Blocking
**What goes wrong:** Hook uses `exit 1` expecting to block; the action proceeds silently.
**Why it happens:** Only exit 2 is "blocking error" in Claude Code. Exit 1 is "non-blocking error" — Claude sees the stderr but continues anyway.
**How to avoid:** All blocking hooks use `exit 2`. preflight check (a) validates this explicitly.
**Warning signs:** Hook appears to fire (stderr message shows) but action is not blocked.

### Pitfall 2: stdout/stderr Inversion
**What goes wrong:** Hook writes human message to stdout; Claude receives garbled JSON; silent protocol failure.
**Why it happens:** stdout is the machine-readable JSON channel. Any non-JSON text corrupts the output.
**How to avoid:** All human messages: `echo "message" >&2`. preflight check (b) validates this.
**Warning signs:** Hook appears to run but produces no visible effect; no error reported.

### Pitfall 3: Stop Hook Infinite Loop
**What goes wrong:** Session wedges in an infinite continuation loop because Stop hook always exits 2.
**Why it happens:** The verify condition is never satisfied (or never checked); the hook keeps blocking.
**How to avoid:** Always check `stop_hook_active` at the top of the Stop hook. If `true`, exit 0 immediately. Also implement BLOCKED_COUNT ceiling (LOOP-02).
**Warning signs:** Claude keeps saying "I need to fix this" repeatedly; session never ends; BLOCKED_COUNT grows without bound.

### Pitfall 4: Subagent Not Available After Install
**What goes wrong:** Install script writes `verifier.md` to `~/.claude/agents/`; user immediately tries to invoke verifier; fails.
**Why it happens:** Direct file writes to `~/.claude/agents/` require a session restart. Only `/agents` UI edits are live.
**How to avoid:** Install script or onboarding doc must state: "restart Claude Code after install for agents to load." Preflight check for SKEL-05 must be run in a new session.
**Warning signs:** "Agent not found" or Claude not delegating to verifier when asked.

### Pitfall 5: pandas.read_excel Without engine Argument
**What goes wrong:** `pd.read_excel("file.xlsx")` raises openpyxl import error or falls back to xlrd.
**Why it happens:** pandas deprecated xlrd for .xlsx in pandas 1.2+; must explicitly use `engine="openpyxl"`.
**How to avoid:** Always pass `engine="openpyxl"` when reading .xlsx files.
**Warning signs:** `ImportError: Missing optional dependency 'xlrd'` or silent incorrect parsing.

### Pitfall 6: ANTHROPIC_API_KEY Not Set in Subprocess
**What goes wrong:** Giavico module 3 runs fine from terminal but fails in pytest because env var not loaded.
**Why it happens:** `python-dotenv`'s `load_dotenv()` only loads for the current process; pytest subprocess may not inherit it.
**How to avoid:** Call `load_dotenv()` at module init in `recommend.py`, not just in `main.py`. In pytest, use `pytest-dotenv` or `conftest.py` with `load_dotenv()`.
**Warning signs:** `anthropic.AuthenticationError` in pytest but not in direct run.

### Pitfall 7: Install Script Overwrites settings.json
**What goes wrong:** Install script writes a fresh settings.json, deleting GSD hooks.
**Why it happens:** Simple `cp settings.json ~/.claude/settings.json` overwrites the target.
**How to avoid:** Read existing `~/.claude/settings.json`, use `jq` to merge arrays, write back. Never overwrite; always merge.
**Warning signs:** GSD hooks stop firing after install; `gsd-context-monitor.js` not in PostToolUse array.

---

## Code Examples

### common.sh — Shared Library

```bash
# ~/.claude/hooks/common.sh
# Source: design from project research + official hook docs
# Usage: source "$(dirname "$0")/common.sh" in every hook

# Block with exit 2 — message to stderr
block() {
  echo "BLOCK: $1" >&2
  echo "How to fix: $2" >&2
  exit 2
}

# Emit non-blocking message to stderr
emit() {
  echo "$1" >&2
}

# Write one trace line to ~/.claude/trace.log
# Format: TIMESTAMP TOOL TARGET EXIT_CODE
trace_write() {
  local tool="$1"
  local target="$2"
  local exit_code="$3"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "$timestamp $tool $target $exit_code" >> ~/.claude/trace.log
}
```

### preflight.sh — 7 Checks

```bash
#!/usr/bin/env bash
# preflight.sh — all 7 SKEL-03 checks; exits 0 iff all pass
# Run: ./preflight.sh

set -euo pipefail
PASS=0; FAIL=0

check() {
  local name="$1"; shift
  if "$@"; then
    echo "[PASS] $name"
    ((PASS++))
  else
    echo "[FAIL] $name"
    ((FAIL++))
  fi
}

# (a) exit-code-2 hook test: a test hook exits 2 → verify it blocks
check "exit-code-2 hook test" bash scripts/test-exit-code-2.sh

# (b) stderr-not-stdout template test: hook message goes to stderr not stdout
check "stderr-not-stdout template" bash scripts/test-stderr-template.sh

# (c) chmod +x on all hooks
check "chmod +x all hooks" bash -c 'for f in ~/.claude/hooks/*.sh; do [ -x "$f" ] || exit 1; done'

# (d) PROGRESS file schema in place
PROGRESS_FILE="${PWD}/.progress/PROGRESS.md"
check "PROGRESS schema in place" bash -c "grep -q 'CURRENT STATE' '$PROGRESS_FILE' && grep -q 'HISTORY LOG' '$PROGRESS_FILE'"

# (e) stub-reject hook fires on pass$/TODO/NotImplemented
check "stub-reject hook fires" bash scripts/test-stub-reject.sh

# (f) progress-after-edit hook fires on Write/Edit
check "progress-after-edit hook fires" bash scripts/test-progress-hook.sh

# (g) trace hook writes tool name + target + exit code + timestamp
check "trace hook writes entry" bash scripts/test-trace-hook.sh

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

### install.sh — settings.json Merge

```bash
#!/usr/bin/env bash
# install.sh — merges harness into ~/.claude without clobbering GSD
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

# Copy hook scripts
mkdir -p "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/agents"
cp "$HARNESS_DIR/hooks/"*.sh "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/"*.sh

# Copy agents (requires session restart to take effect)
cp "$HARNESS_DIR/agents/verifier.md" "$CLAUDE_DIR/agents/"

# Merge settings.json — append harness hooks, preserve existing
if [ -f "$SETTINGS" ]; then
  # Use jq to merge: existing arrays + harness arrays
  HARNESS_SETTINGS="$HARNESS_DIR/settings.json"
  jq -s '.[0] * .[1]' "$SETTINGS" "$HARNESS_SETTINGS" > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"
else
  cp "$HARNESS_DIR/settings.json" "$SETTINGS"
fi

echo "Install complete. RESTART Claude Code for agents to load."
```

**Note:** `jq -s '.[0] * .[1]'` deep-merges two JSON objects using `*` operator. For hook arrays, this replaces rather than appends. The install script needs more careful array-append logic using `jq '[.[0], .[1]] | add'` for array fields specifically. This is a nuance to handle in the plan.

### force-loop-test.sh — LOOP-01/LOOP-02 Validation

```bash
#!/usr/bin/env bash
# scripts/force-loop-test.sh — validates LOOP-01 and LOOP-02
# Simulates Stop hook behavior without live Claude; exits 0 iff both proofs pass
set -euo pipefail

# Proof of LOOP-01: exit 2 blocks stopping
# Create a test scenario: synthetic PROGRESS with a failing verify command
# Then call stop-hook.sh directly with mock input and confirm it exits 2

MOCK_INPUT='{"session_id":"test","stop_hook_active":false,"transcript_path":"/tmp/test.jsonl","cwd":"'"$PWD"'","hook_event_name":"Stop"}'
# ... (inject VERIFY_CMD that always fails) ...
# assert: hook exits 2

# Proof of LOOP-02: ceiling reached → BLOCKED in PROGRESS, hook exits 0
# Set BLOCKED_COUNT to CEILING in PROGRESS
# Call stop-hook.sh again
# assert: hook exits 0 AND PROGRESS contains "BLOCKED:"

echo "LOOP-01 and LOOP-02 validated"
exit 0
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `exit 1` for hook blocking | `exit 2` for blocking, `exit 1` for non-blocking | Claude Code from early design | Fundamental — exit 1 never blocks; all blocking hooks must use exit 2 |
| `.claude/commands/` for slash commands | `~/.claude/skills/<name>/SKILL.md` | 2025 (current) | Skills support hot-reload, forked subagent context, frontmatter control; commands still work but not the new path |
| `xlrd` engine for .xlsx in pandas | `openpyxl` engine | pandas 1.2+ | xlrd dropped .xlsx support; always specify `engine="openpyxl"` |
| Global subagents always available | Subagents require session restart after direct file write | Current docs (2026) | Install flow must include "restart session" step for agents to load |
| `agent` hook handler type | `command` type only for Phase 0 | Still experimental (2026) | `agent` hook type is experimental; use `command` type for all enforcement hooks |

**Deprecated/outdated:**
- `xlrd` for .xlsx reading: use `openpyxl`
- `.claude/commands/` for new skills: use `~/.claude/skills/<name>/SKILL.md`
- `agent` hook handler type in Phase 0: experimental, defer to Phase 1+

---

## Open Questions

1. **jq array merge in install.sh**
   - What we know: `jq -s '.[0] * .[1]'` deep-merges objects using `*`; for arrays, `*` replaces rather than appends
   - What's unclear: The exact jq expression needed to append harness hooks to existing PostToolUse/PreToolUse arrays without clobbering
   - Recommendation: Plan task for install.sh should include explicit jq test for array append; use `.[0].hooks.PostToolUse + .[1].hooks.PostToolUse` pattern

2. **PLAN-01 runtime enforcement scope**
   - What we know: PreToolUse hook must check PROGRESS for a verify command before Write/Edit
   - What's unclear: How does the hook know which task is "current" — must the PROGRESS schema include a CURRENT_TASK field that the stub-reject hook reads?
   - Recommendation: PROGRESS schema should include CURRENT_TASK and VERIFY_CMD fields; PreToolUse hook reads both; block if VERIFY_CMD is empty

3. **pytest vs `npm test` in done command**
   - What we know: Done command in ROADMAP.md says `cd giavico && npm test` but runtime is Python
   - What's unclear: Is `npm test` a placeholder, or does Giavico need a package.json wrapper around pytest?
   - Recommendation: Done command should be `cd ~/Work/mine/giavico && python -m pytest`; ROADMAP.md was drafted before Python was locked as the runtime; planner should correct this

4. **Anthropic API key for CI-style test runs**
   - What we know: Module 3 requires `ANTHROPIC_API_KEY`; live API calls in pytest are slow and cost money
   - What's unclear: Should test_recommend.py mock the API or make live calls?
   - Recommendation: Use a pytest fixture that mocks `anthropic.Anthropic.messages.create` for unit tests; reserve live API calls for the manual GIAV-05 human verification step

---

## Validation Architecture

`workflow.nyquist_validation` is `true` in `.planning/config.json` — Validation Architecture section is included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest 7.4.3 |
| Config file | `giavico/pytest.ini` — Wave 0 gap (does not exist yet) |
| Quick run command | `cd ~/Work/mine/giavico && python -m pytest tests/ -x -q` |
| Full suite command | `cd ~/Work/mine/giavico && python -m pytest tests/ -v` |
| Harness scripts | `bash preflight.sh`, `bash scripts/no-verify-cmd-test.sh`, `bash scripts/force-loop-test.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SKEL-03a | exit-code-2 hook test | smoke | `bash scripts/test-exit-code-2.sh` | ❌ Wave 0 |
| SKEL-03b | stderr-not-stdout template test | smoke | `bash scripts/test-stderr-template.sh` | ❌ Wave 0 |
| SKEL-03c | chmod +x all hooks | smoke | `bash -c 'for f in ~/.claude/hooks/*.sh; do [ -x "$f" ] \|\| exit 1; done'` | ❌ Wave 0 (hooks not yet written) |
| SKEL-03d | PROGRESS schema in place | smoke | `grep -q 'CURRENT STATE' .progress/PROGRESS.md && grep -q 'HISTORY LOG' .progress/PROGRESS.md` | ❌ Wave 0 |
| SKEL-03e | stub-reject hook fires | smoke | `bash scripts/test-stub-reject.sh` | ❌ Wave 0 |
| SKEL-03f | progress-after-edit hook fires | smoke | `bash scripts/test-progress-hook.sh` | ❌ Wave 0 |
| SKEL-03g | trace hook writes entry | smoke | `bash scripts/test-trace-hook.sh` | ❌ Wave 0 |
| SKEL-07 | preflight.sh exits 0 | integration | `bash preflight.sh` | ❌ Wave 0 |
| PLAN-01 | no-verify task is refused | integration | `bash scripts/no-verify-cmd-test.sh` | ❌ Wave 0 |
| LOOP-01 | exit 2 on failing verify | integration | `bash scripts/force-loop-test.sh` (part 1) | ❌ Wave 0 |
| LOOP-02 | ceiling → BLOCKED in PROGRESS | integration | `bash scripts/force-loop-test.sh` (part 2) | ❌ Wave 0 |
| ONBD-01 | one-step install places all assets | smoke | `bash install.sh && ls ~/.claude/hooks/*.sh` | ❌ Wave 0 |
| GIAV-01 | ingest Excel + detect schema | unit | `python -m pytest tests/test_ingest.py -x` | ❌ Wave 0 |
| GIAV-02 | normalize detected schema | unit | `python -m pytest tests/test_normalize.py -x` | ❌ Wave 0 |
| GIAV-03 | AI recommendations (mocked) | unit | `python -m pytest tests/test_recommend.py -x` | ❌ Wave 0 |
| GIAV-04 | all 3 modules callable end-to-end | integration | `python -m pytest tests/ -x` | ❌ Wave 0 |
| GIAV-05 | human verifies app starts | manual | Human sign-off in PROGRESS | manual-only |
| SKEL-05 | verifier.md in place with correct frontmatter | smoke | `grep 'disallowedTools: Write, Edit' ~/.claude/agents/verifier.md` | ❌ Wave 0 |
| SKEL-06 | common.sh exists with required functions | smoke | `grep -q 'block()' ~/.claude/hooks/common.sh && grep -q 'emit()' ~/.claude/hooks/common.sh` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bash preflight.sh` (exits 0 or shows which check failed)
- **Per wave merge:** `bash preflight.sh && bash scripts/no-verify-cmd-test.sh && bash scripts/force-loop-test.sh && cd ~/Work/mine/giavico && python -m pytest tests/ -v`
- **Phase gate:** Full suite green + GIAV-05 human sign-off recorded in PROGRESS before phase complete

### Wave 0 Gaps

All test infrastructure must be created as part of Phase 0 implementation. None exists yet.

**Harness (in `build-anything/`):**
- [ ] `scripts/test-exit-code-2.sh` — covers SKEL-03a
- [ ] `scripts/test-stderr-template.sh` — covers SKEL-03b
- [ ] `scripts/test-stub-reject.sh` — covers SKEL-03e
- [ ] `scripts/test-progress-hook.sh` — covers SKEL-03f
- [ ] `scripts/test-trace-hook.sh` — covers SKEL-03g
- [ ] `scripts/no-verify-cmd-test.sh` — covers PLAN-01
- [ ] `scripts/force-loop-test.sh` — covers LOOP-01, LOOP-02
- [ ] `preflight.sh` — covers SKEL-03 (all 7) + SKEL-07

**Giavico (in `~/Work/mine/giavico/`):**
- [ ] `giavico/pytest.ini` — test configuration
- [ ] `giavico/tests/conftest.py` — shared fixtures (mocked Anthropic client)
- [ ] `giavico/tests/test_ingest.py` — covers GIAV-01
- [ ] `giavico/tests/test_normalize.py` — covers GIAV-02
- [ ] `giavico/tests/test_recommend.py` — covers GIAV-03 (mocked API)
- [ ] `giavico/fixtures/sample.xlsx` — test fixture Excel file
- [ ] Framework install: `pip install pandas openpyxl anthropic python-dotenv pytest` in venv

---

## Sources

### Primary (HIGH confidence)
- `https://code.claude.com/docs/en/hooks` — hook types, exit code semantics, JSON input/output protocol, settings.json format, matcher syntax (fetched 2026-06-22)
- `https://code.claude.com/docs/en/sub-agents` — subagent frontmatter fields (disallowedTools, permissionMode, model), session restart requirement, scope table (fetched 2026-06-22)
- `anthropics/claude-code#10412` — confirms `stop_hook_active` field in Stop hook JSON input; confirms exit 2 behavior; documents plugin vs direct hook difference
- `.planning/research/SUMMARY.md` — project-level research; all findings cross-validated with current official docs
- Python 3.12.4 (installed), pytest 7.4.3 (installed) — confirmed via `python3 --version` and `pip3 show pytest`

### Secondary (MEDIUM confidence)
- `https://amitkoth.com/claude-code-stop-hooks/` — confirms `stop_hook_active` field name and semantics; aligns with official docs
- `https://www.morphllm.com/claude-code-hooks` — Stop hook JSON input fields; cross-validated against official docs
- PyPI search (2026-06-22) — pandas 3.0.3, openpyxl 3.1.5, anthropic 0.111.0 current versions confirmed

### Tertiary (LOW confidence — not needed; all critical claims verified at higher levels)
- None

---

## Metadata

**Confidence breakdown:**
- Stop hook API (stop_hook_active field): HIGH — confirmed from official issue tracker + multiple practitioner docs + official docs
- Hook exit code semantics: HIGH — verified from official docs (code.claude.com/docs/en/hooks)
- Subagent session restart requirement: HIGH — verbatim quote from official subagent docs
- Python stack (pandas/openpyxl/anthropic): HIGH — version numbers verified via pip dry-run and PyPI
- settings.json array merge behavior: HIGH — confirmed from official docs
- jq merge expression for array append: MEDIUM — conceptually correct; exact expression needs validation in plan task

**Research date:** 2026-06-22
**Valid until:** 2026-07-22 (stable Claude Code primitives; check hook API if regenerating after this date)
