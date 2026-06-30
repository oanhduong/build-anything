# Signature Harness Kit — Project Context

> Stable reference. No dynamic content. Dynamic state lives in .progress/PROGRESS.md.

## What This Is

A versioned global enforcement layer for Claude Code. Installed at `~/.claude`.
- Skills, enforcement hooks, verifier subagent, file-based failure library
- Compounds knowledge: lessons from one build become rules for the next
- Source repo: `build-anything`; installed into `~/.claude` via `./install.sh`

## Directory Layout (source: build-anything/)

| Path | Purpose |
|------|---------|
| `hooks/common.sh` | Shared library: block(), emit(), trace_write() |
| `hooks/stub-reject.sh` | PreToolUse: rejects stubs before Write/Edit |
| `hooks/progress-after-edit.sh` | PostToolUse: updates PROGRESS after Write/Edit |
| `hooks/trace.sh` | PostToolUse: writes trace line to ~/.claude/trace.log |
| `hooks/stop-hook.sh` | Stop: runs verify command; exit 2 on fail; ceiling at 3 |
| `agents/verifier.md` | Verifier subagent (read-only; executes criteria, never invents) |
| `docs/` | Per-project docs stub (populated at project bootstrap — Phase 1) |
| `skills/` | Skill definitions (populated Phase 2+) |
| `hooks/bootstrap-project.sh` | SessionStart: creates .progress/PROGRESS.md if missing |
| `hooks/load-lessons.sh` | SessionStart: injects compact lesson index into context |
| `hooks/lessons-post-write.sh` | PostToolUse Write/Edit: hints relevant pre-write lessons by file type |
| `hooks/lessons-on-error.sh` | PostToolUse Bash: surfaces matching on-error lessons when exit≠0 |
| `failure-lib/` | Lesson library: plain .md files with when/error-match frontmatter |
| `CLAUDE.md` | This file (template; drop into target project at bootstrap) |
| `settings.json` | Harness-only baseline settings (used on fresh machines) |
| `install.sh` | One-step install: merges harness into ~/.claude; git-inits ~/.claude |
| `preflight.sh` | 7 preflight checks; exits 0 iff all pass |
| `.progress/PROGRESS.md` | Runtime state: CURRENT STATE + HISTORY LOG |

## Hook Enforcement Triad (CRITICAL)

Three rules that must hold or enforcement silently fails:
1. **exit 2** (not 1) for blocking — exit 1 is non-blocking in Claude Code
2. **stderr** (not stdout) for human messages — stdout is the JSON machine channel
3. **chmod +x** on all hook scripts — unhookable scripts fail silently

## PROGRESS File Contract

Location: `.progress/PROGRESS.md`
Fields (machine-readable prefix lines):
- `CURRENT_TASK: <name>` — current task name or "none"
- `VERIFY_CMD: <command>` — runnable verify command or empty
- `BLOCKED_COUNT: <n>` — Stop hook iteration counter (reset each task)

Sections:
- `## CURRENT STATE` — overwritten each session, capped at 20 lines
- `## HISTORY LOG` — append-only, one-liners per edit

## Enforcement Hooks

| Hook | Type | Trigger | Action |
|------|------|---------|--------|
| bootstrap-project.sh | SessionStart | session start | create .progress/PROGRESS.md if missing |
| stub-reject.sh | PreToolUse | Write/Edit | grep for pass$, TODO, NotImplemented → block if found |
| progress-after-edit.sh | PostToolUse | Write/Edit | append to HISTORY LOG; update CURRENT STATE |
| trace.sh | PostToolUse | all tools | write TIMESTAMP TOOL TARGET EXIT_CODE to trace.log |
| stop-hook.sh | Stop | session end | run VERIFY_CMD; exit 2 if fails; count iterations |
| load-lessons.sh | SessionStart | session start | inject compact lesson index |
| lessons-post-write.sh | PostToolUse | Write/Edit | hint pre-write lessons by file extension |
| lessons-on-error.sh | PostToolUse | Bash (exit≠0) | surface on-error lessons matching error text |

## Key Constraints

- No per-stack adapters — hooks are language-agnostic (grep-based only)
- No dynamic content in CLAUDE.md — breaks KV-cache prefix
- Verifier subagent must have disallowedTools: Write, Edit — prevents rationalizing broken output
- stop_hook_active guard in stop-hook.sh — prevents session wedge
- Session restart required after adding agents via direct file write
- ~/.claude is a versioned git repo — changes to harness are tracked (SKEL-01)

## Phase Map

| Phase | Goal | Key Deliverable |
|-------|------|-----------------|
| 0 | Skeleton + Giavico PoC | preflight.sh exits 0; Giavico runs end-to-end |
| 1 | Enforcement Hardening | All Phase 0 failures auto-blocked; per-project bootstrap (SKEL-02) |
| 2 | Context Plane | Long tasks survive context reset |
| 3 | Self-Improve Loop | Lessons distilled and committed automatically |
| 4 | Heavy Retrieval (conditional) | Vector index if grep proves bottleneck |

## References

- Requirements: `.planning/REQUIREMENTS.md`
- Roadmap: `.planning/ROADMAP.md`
- Phase 0 context: `.planning/phases/00-skeleton-giavico-poc/00-CONTEXT.md`
- Research: `.planning/phases/00-skeleton-giavico-poc/00-RESEARCH.md`
