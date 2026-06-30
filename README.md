# Signature Harness Kit

A versioned global enforcement layer for [Claude Code](https://claude.ai/code) that compounds knowledge across projects. Lessons distilled from one build become auto-enforced rules for the next.

Installs into `~/.claude` and fires on every Claude Code session.

## How It Works

```
build-anything/   ← this repo (source)
      │
      └─ install.sh ──► ~/.claude/   ← active harness (hooks, skills, failure-lib)
```

Every hook, skill, and lesson lives here. `install.sh` merges everything into `~/.claude` and git-inits it so the installed harness is also version-controlled.

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/oanhduong/build-anything/master/get.sh)
```

Then start a Claude Code session — hooks fire automatically.

**Want to contribute lessons back?** Fork first, then install from your fork so the remote is wired up automatically:

```bash
# 1. Fork https://github.com/oanhduong/build-anything on GitHub
git clone https://github.com/<YOUR_USERNAME>/build-anything.git
cd build-anything
bash install.sh
```

## What's Installed

### Hooks

| Hook | Type | What It Does |
|------|------|--------------|
| `bootstrap-project.sh` | SessionStart | Creates `.progress/PROGRESS.md` if missing |
| `load-lessons.sh` | SessionStart | Injects compact lesson index into context |
| `stub-reject.sh` | PreToolUse | Blocks stub placeholders and missing verify commands before any Write/Edit |
| `claude-md-audit.sh` | PreToolUse | Blocks dynamic content in `CLAUDE.md` (breaks KV-cache) |
| `progress-after-edit.sh` | PostToolUse | Appends to HISTORY LOG on every Write/Edit |
| `trace.sh` | PostToolUse | Writes tool + target + exit code + timestamp to `trace.log` |
| `lessons-post-write.sh` | PostToolUse | Hints relevant lessons by file extension before write |
| `lessons-on-error.sh` | PostToolUse | Surfaces matching lessons when a Bash command exits non-zero |
| `stop-hook.sh` | Stop | Runs `VERIFY_CMD`; exits 2 on fail; writes handoff note; triggers auto-distill |

### Skills

| Skill | Subcommands | What It Does |
|-------|-------------|--------------|
| `context-pull` | `search`, `get-file`, `expand-summary` | Pull context from docs and progress files after a context reset |
| `handoff` | — | Write a structured handoff note (current task, last edits, blockers, next action) |
| `retro` | `approve`, `run`, `prune` | Review and commit distilled lessons from the pending queue |

### Failure Library

Plain `.md` files in `failure-lib/` with `when` / `error-match` frontmatter. Loaded at session start by `load-lessons.sh`. New lessons are drafted to `failure-lib/pending/` by `auto-distill.sh` and committed via `/retro approve`.

## The Self-Improve Loop

```
Bash error → lessons-on-error.sh → hit count++
                                         │
                              threshold (≥3 hits)
                                         │
                              stop-hook.sh → auto-distill.sh
                                         │
                              failure-lib/pending/ (candidate)
                                         │
                              /retro approve → failure-lib/ (committed)
                                         │
                              load-lessons.sh surfaces it next session
```

## Hook Enforcement Triad

Three rules that must hold or enforcement silently fails:

1. **`exit 2`** (not 1) for blocking — `exit 1` is non-blocking in Claude Code
2. **stderr** (not stdout) for human messages — stdout is the JSON machine channel
3. **`chmod +x`** on all hook scripts — un-executable scripts fail silently

## Preflight

```bash
bash preflight.sh
```

Runs 7 checks: exit-code-2 blocking, stderr-not-stdout, chmod+x on all hooks, PROGRESS schema, stub-reject fires, progress-after-edit fires, trace hook writes correct format. Exits 0 only when all pass.

## Phase Map

| Phase | Goal | Status |
|-------|------|--------|
| 0 | Skeleton + Giavico PoC | Complete |
| 1 | Enforcement Hardening | Complete |
| 2 | Context Plane | Complete |
| 3 | Self-Improve Loop | Complete |
| 4 | Heavy Retrieval (conditional) | Gate closed — no bottleneck yet |

Phase 4 (vector index over failure-lib) only opens when `bash scripts/check-retrieval-gate.sh` detects miss-rate > 10% or grep latency > 100ms on a corpus of 20+ lessons.
