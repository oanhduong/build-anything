---
phase: 00-skeleton-giavico-poc
plan: "01"
subsystem: harness-foundation
tags: [harness, hooks, install, common-sh, verifier, progress, settings]
dependency_graph:
  requires: []
  provides:
    - hooks/common.sh (block/emit/trace_write shared library)
    - agents/verifier.md (verifier subagent definition)
    - CLAUDE.md (project context TOC template)
    - settings.json (harness-only baseline settings)
    - install.sh (one-step install with git-init and jq merge)
    - .progress/PROGRESS.md (PROGRESS schema with all required fields)
    - docs/.gitkeep, skills/.gitkeep, failure-lib/.gitkeep (directory stubs)
  affects:
    - ~/.claude/settings.json (install.sh appends harness hooks; GSD hooks preserved)
    - ~/.claude (git-initialized as versioned repo by install.sh)
    - Plans 00-02, 00-03 (depend on common.sh being sourceable, PROGRESS schema in place)
tech_stack:
  added:
    - bash (common.sh, install.sh — no new runtime dependency)
    - jq (array-append merge in install.sh)
  patterns:
    - exit-2-blocking: all blocking hooks use exit 2, never exit 1
    - stderr-for-messages: all human messages go to stderr; stdout is JSON machine channel
    - append-not-overwrite: install.sh appends harness hooks to existing settings.json arrays
    - no-dynamic-content: CLAUDE.md is stable; all runtime state lives in .progress/PROGRESS.md
key_files:
  created:
    - hooks/common.sh
    - hooks/.gitkeep
    - agents/verifier.md
    - skills/.gitkeep
    - failure-lib/.gitkeep
    - docs/.gitkeep
    - CLAUDE.md
    - settings.json
    - install.sh
    - .progress/PROGRESS.md
  modified: []
decisions:
  - "SKEL-01 git init: install.sh checks rev-parse --git-dir first; branches on git-repo vs not-yet-repo; does not blindly init"
  - "jq merge strategy: explicit named-field array concatenation over jq * operator (which replaces arrays); uses $existing + $harness per array key"
  - "PROGRESS schema: CURRENT_TASK + VERIFY_CMD + BLOCKED_COUNT as machine-readable prefix lines; CURRENT STATE + HISTORY LOG as grep-verifiable section headers"
  - "verifier.md uses model: haiku (fast, cheap, sufficient for read-only verification in Phase 0)"
  - "CLAUDE.md: 83 lines, no timestamps, no dynamic content — stable KV-cache prefix"
metrics:
  duration: "~3 minutes"
  completed_date: "2026-06-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 10
  files_modified: 0
---

# Phase 00 Plan 01: Harness Foundation — Directory Layout, common.sh, Verifier, Install Script

**One-liner:** Bash hook shared library (exit-2 blocking), verifier subagent (disallowedTools: Write,Edit), PROGRESS schema, and jq-merge install script that git-initializes ~/.claude without clobbering GSD.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Harness directory layout + common.sh + verifier.md + docs/ stub | b289886 | hooks/common.sh, agents/verifier.md, skills/.gitkeep, failure-lib/.gitkeep, docs/.gitkeep |
| 2 | CLAUDE.md + settings.json + PROGRESS schema + install.sh | b3b864c | CLAUDE.md, settings.json, install.sh, .progress/PROGRESS.md |

## What Was Built

### Task 1: Harness Directory Layout + Core Files

Created the foundational directory structure and shared library:

- **hooks/common.sh**: Three-function shared library sourced by every enforcement hook
  - `block(reason, fix)`: exits 2 with BLOCK message and fix instruction to stderr
  - `emit(msg)`: non-blocking stderr message
  - `trace_write(tool, target, exit_code)`: appends `TIMESTAMP TOOL TARGET EXIT_CODE` to `~/.claude/trace.log`
  - chmod +x applied; set -euo pipefail for strict mode

- **agents/verifier.md**: Verifier subagent definition with required frontmatter
  - `disallowedTools: Write, Edit` — prevents rationalizing broken output
  - `permissionMode: dontAsk` — no permission prompts during verification
  - `model: haiku` — fast and cheap for Phase 0 read-only verification
  - Two-tier check order: universal kit checks first, then phase-specific VERIFY_CMD

- **Directory stubs**: skills/.gitkeep, failure-lib/.gitkeep, docs/.gitkeep (SKEL-02 Phase 0 artifact; per-project copy is Phase 1 scope)

### Task 2: CLAUDE.md + Settings + PROGRESS Schema + Install Script

- **CLAUDE.md**: 83-line stable TOC with no dynamic content
  - Directory layout table, Hook Enforcement Triad, PROGRESS file contract, enforcement hook table, phase map, references
  - No timestamps, no PROGRESS tail, no current-task notes — KV-cache safe

- **settings.json**: Harness-only baseline for fresh machines (no GSD)
  - PreToolUse: stub-reject.sh (matcher: Write|Edit)
  - PostToolUse: progress-after-edit.sh (matcher: Write|Edit) + trace.sh (all tools)
  - Stop: stop-hook.sh

- **.progress/PROGRESS.md**: PROGRESS schema with all required machine-readable fields
  - `CURRENT_TASK: none`, `VERIFY_CMD:`, `BLOCKED_COUNT: 0`
  - `## CURRENT STATE` section (overwritten each session, capped at 20 lines)
  - `## HISTORY LOG` section (append-only, one-liners per edit)

- **install.sh**: One-step install script (chmod +x)
  - Copies hooks/*.sh and chmod +x in ~/.claude/hooks/
  - Copies agents/verifier.md to ~/.claude/agents/
  - Merges settings.json via jq with explicit array concatenation per key (never clobbers GSD arrays)
  - Initializes ~/.claude as a versioned git repo if not already one (SKEL-01)
  - Commits harness files to ~/.claude git repo (update commit if re-run)
  - Initializes trace.log
  - Prints session-restart reminder for verifier agent to load

## Verification Results

All acceptance criteria passed on first attempt:

**Task 1:**
- `grep -q 'block()' hooks/common.sh` → exit 0
- `grep -q 'emit()' hooks/common.sh` → exit 0
- `grep -q 'trace_write()' hooks/common.sh` → exit 0
- `grep -q 'exit 2' hooks/common.sh` → exit 0
- `[ -x hooks/common.sh ]` → exit 0
- `grep -q 'disallowedTools: Write, Edit' agents/verifier.md` → exit 0
- `grep -q 'permissionMode: dontAsk' agents/verifier.md` → exit 0
- `[ -f docs/.gitkeep ]` → exit 0

**Task 2:**
- All PROGRESS.md field checks → exit 0
- `python3 -c "import json; json.load(open('settings.json'))"` → exit 0
- `[ -x install.sh ]` → exit 0
- `grep -q 'jq' install.sh` → exit 0
- `grep -q 'Restart Claude Code' install.sh` → exit 0
- `grep -q 'rev-parse.*git-dir' install.sh` → exit 0
- `wc -l < CLAUDE.md` → 83 (>= 60)

**SKEL-01 live check (after bash install.sh):**
- `git -C ~/.claude rev-parse --git-dir` → exit 0 (SKEL-01 satisfied)
- GSD hooks preserved in PostToolUse array: confirmed (gsd-context-monitor.js still present)
- Harness hooks appended: progress-after-edit.sh, trace.sh (PostToolUse), stub-reject.sh (PreToolUse), stop-hook.sh (Stop)

## Deviations from Plan

None — plan executed exactly as written.

## Requirements Addressed

| Requirement | Status |
|-------------|--------|
| SKEL-01 | Satisfied — ~/.claude is now a versioned git repo; install.sh committed all harness files |
| SKEL-02 | Phase 0 scope satisfied — CLAUDE.md template + docs/.gitkeep exist in harness source repo |
| SKEL-05 | Satisfied — agents/verifier.md with disallowedTools: Write, Edit and permissionMode: dontAsk |
| SKEL-06 | Satisfied — hooks/common.sh with block()/emit()/trace_write() |
| ONBD-01 | Satisfied — install.sh places all harness assets into ~/.claude in one command |
| ONBD-02 | Satisfied — jq merge preserves GSD hooks; harness appended alongside |

## Next Plan Dependencies

Plans 00-02 and 00-03 depend on:
- `hooks/common.sh` existing and being sourceable — confirmed
- PROGRESS schema in place — confirmed
- `~/.claude` as a git repo — confirmed (SKEL-01)
- `install.sh` working end-to-end — confirmed (ran successfully)

## Self-Check: PASSED

Files verified to exist:
- hooks/common.sh — FOUND
- agents/verifier.md — FOUND
- CLAUDE.md — FOUND
- settings.json — FOUND
- install.sh — FOUND
- .progress/PROGRESS.md — FOUND
- docs/.gitkeep — FOUND
- skills/.gitkeep — FOUND
- failure-lib/.gitkeep — FOUND

Commits verified:
- b289886 (Task 1) — FOUND
- b3b864c (Task 2) — FOUND
