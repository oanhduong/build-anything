# Build Anything

A global enforcement layer for [Claude Code](https://claude.ai/code) that gets smarter with every project you build.

Installs once into `~/.claude`. Fires automatically on every session, every project.

---

## The problem it solves

Claude Code is powerful but stateless. It forgets what went wrong last time. It ships stubs when it's stuck. Long sessions lose context. Every new project starts from zero.

**Build Anything makes Claude's mistakes non-repeatable.**

Errors are distilled into lessons. Lessons are enforced as hooks. Hooks run before Claude can write bad code. Each project builds on the failure memory of every project before it.

---

## Quick Start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/oanhduong/build-anything/main/get.sh)
```

Start a Claude Code session — hooks fire automatically.

---

## What you get

### Enforcement hooks

Claude can't ship stub placeholders, break your `CLAUDE.md` cache, or exit a task without verifying its own work.

| Hook | When | What It Does |
|------|------|--------------|
| `stub-reject.sh` | Before any write | Blocks stub placeholders before they land in code |
| `claude-md-audit.sh` | Before any write | Blocks dynamic content in `CLAUDE.md` (breaks KV-cache prefix) |
| `stop-hook.sh` | End of session | Exits 2 when `VERIFY_CMD` fails; retries up to 3× |
| `load-lessons.sh` | Session start | Injects the full lesson index so Claude reads it first |
| `bootstrap-project.sh` | Session start | Creates `.progress/PROGRESS.md` if missing |
| `progress-after-edit.sh` | After every write | Appends to history log automatically |
| `lessons-on-error.sh` | After Bash error | Surfaces matching lessons when a command fails |
| `lessons-post-write.sh` | After every write | Hints relevant lessons by file type |
| `trace.sh` | After every tool | Writes tool + target + exit code to `trace.log` |

### Skills

| Skill | What It Does |
|-------|--------------|
| `/context-pull` | Recover full task context after a context reset |
| `/handoff` | Write a structured handoff note before pausing work |
| `/retro` | Review, approve, and commit distilled lessons |

### Failure library

Plain `.md` files in `failure-lib/` with `when` / `error-match` frontmatter. Claude reads the index at session start. New lessons are drafted automatically and committed via `/retro approve`.

---

## The self-improve loop

Every error Claude makes is a candidate lesson. Hit it enough times and the harness distills it automatically.

```
Bash error
  → lessons-on-error.sh  (surface matching lessons, increment hit count)
  → stop-hook.sh         (auto-distill when hit count ≥ 3)
  → failure-lib/pending/ (candidate lesson, awaits review)
  → /retro approve       (committed to failure-lib/)
  → load-lessons.sh      (surfaces it on every future session)
```

The next time Claude hits that error — on any project — it already knows what to do.

---

## How it installs

```
build-anything/   ← this repo (source)
      │
      └─ install.sh ──► ~/.claude/   ← active harness
```

`install.sh` merges hooks, skills, and the failure library into `~/.claude` and git-inits it so your installed harness is version-controlled too.

**Want to contribute lessons back?** Fork first, then install from your fork:

```bash
# 1. Fork https://github.com/oanhduong/build-anything on GitHub
git clone https://github.com/<YOUR_USERNAME>/build-anything.git
cd build-anything
bash install.sh
```

After `/retro approve` commits a lesson locally, `retro` will offer to push it back to your fork as a PR.

---

## Verify the install

```bash
bash preflight.sh
```

Runs 7 checks: exit-code-2 blocking, stderr routing, chmod+x on all hooks, PROGRESS schema, stub-reject, progress-after-edit, and trace format. Exits 0 only when all checks clear.

---

## Phase Map

| Phase | Goal | Status |
|-------|------|--------|
| 0 | Skeleton & Foundation | Complete |
| 1 | Enforcement Hardening | Complete |
| 2 | Context Plane | Complete |
| 3 | Self-Improve Loop | Complete |
| 4 | Heavy Retrieval (conditional) | Gate closed — no bottleneck yet |

Phase 4 (vector index over failure-lib) only opens when `bash scripts/check-retrieval-gate.sh` detects miss-rate > 10% or grep latency > 100ms on a corpus of 20+ lessons.
