---
name: retro
description: Self-improve loop control. Subcommands — `approve` (batch-review pending candidate lessons, commit approved to failure-lib), `run <trace-file>` (manual distill override), `prune` (retire stale model-crutch rules). Use when reviewing the pending-lessons queue or manually distilling from a trace.
---

Self-improve loop control. This skill is the human approval gate (SELF-09) and the
manual override path (SELF-08). It orchestrates review, commit, and prune — it holds
NO distillation logic of its own. All distillation lives in `scripts/auto-distill.sh`.

Resolve these paths in every subcommand:
- `LIB_DIR="$HOME/.claude/failure-lib"`
- `PENDING_DIR="$LIB_DIR/pending"`

Parse the first word of `$ARGUMENTS` as the subcommand: `run`, `approve`, or `prune`.

## `/retro run <trace-file>` (SELF-08, SELF-01)

1. If no `<trace-file>` argument was given, STOP and tell the user exactly:
   `trace required — usage: /retro run <trace-file>`
   Do NOT call the script with an empty argument.
2. Call the distiller — the SAME script the Stop hook uses (single source of truth):
   ```
   bash ~/.claude/scripts/auto-distill.sh "<trace-file>"
   ```
   (If running from the source repo, `bash scripts/auto-distill.sh "<trace-file>"`.)
   Report the candidate count the script emits.
3. Tell the user to run `/retro approve` to review the drafted candidates.

## `/retro approve` (SELF-06, SELF-09)

1. List all `$PENDING_DIR/*.md` (exclude `.gitkeep`). If none, say
   `No pending candidates.` and stop.
2. For EACH candidate, display: its `id`, `tags`, the `evidence:` line, and the
   "What happened" / "How to avoid" body. Then prompt the human:
   - `y` — approve this candidate
   - `n` — reject this candidate
   - `all` — approve every remaining candidate in one batch
3. For an APPROVED candidate `<id>.md`: move it from `$PENDING_DIR/<id>.md` to
   `$LIB_DIR/<id>.md`. The file is already in the live failure-lib format
   (id / tags / when / error-match); the `evidence:` line MAY be retained for
   provenance — SELF-06 needs NO format conversion. Then commit it to the
   versioned ~/.claude repo:
   ```
   git -C "$HOME/.claude" add "failure-lib/<id>.md" \
     && git -C "$HOME/.claude" commit -m "retro: approve lesson <id> $(date -u +%Y-%m-%dT%H:%M:%SZ)"
   ```
4. For a REJECTED candidate: delete `$PENDING_DIR/<id>.md` (discard — SELF-06:
   "a rejected lesson is discarded").
5. Summarize: N approved (committed), M rejected.
6. **Contribute-back prompt** — if N > 0, ask the human:
   `Contribute these N lesson(s) back to build-anything so others benefit? (y/n)`
   - If **n**: skip. Done.
   - If **y**: run the contribute-back flow below.

Note for the human: approved lessons are surfaced automatically by the existing
hooks (`load-lessons.sh`, `lessons-post-write.sh`, `lessons-on-error.sh`) — there
is NO separate conversion step (SELF-06).

### Contribute-back flow (step 6, y path)

First, detect whether `~/.claude` is already a clone of build-anything:

```bash
ORIGIN=$(git -C "$HOME/.claude" remote get-url origin 2>/dev/null || true)
```

**Case A — `$ORIGIN` contains `build-anything`** (they installed by cloning their fork):

Parse the username and fork URL directly from the remote — no need to ask:
```bash
USERNAME=$(echo "$ORIGIN" | sed 's|.*github\.com[/:]||' | cut -d'/' -f1)
FORK_URL="$ORIGIN"
```

Create the branch inside `~/.claude` itself, push, then return:
```bash
BRANCH="lesson/contrib-$(date -u +%Y%m%d-%H%M%S)"
PREV=$(git -C "$HOME/.claude" rev-parse --abbrev-ref HEAD)

git -C "$HOME/.claude" checkout -b "$BRANCH"

# Copy each approved lesson onto the branch (ids from step 3)
for id in <approved_ids>; do
  git -C "$HOME/.claude" add "failure-lib/$id.md"
done

git -C "$HOME/.claude" commit -m "lesson: contribute $N lesson(s) from community"
git -C "$HOME/.claude" push origin "$BRANCH"

git -C "$HOME/.claude" checkout "$PREV"
```

**Case B — `$ORIGIN` does not contain `build-anything`** (standalone install, no local clone):

Ask the human:
- `Your GitHub username?`
- `Have you forked build-anything yet? If not: https://github.com/oanhduong/build-anything/fork`

Then run:
```bash
UPSTREAM_URL="https://github.com/oanhduong/build-anything.git"
FORK_URL="https://github.com/<USERNAME>/build-anything.git"
BRANCH="lesson/contrib-$(date -u +%Y%m%d-%H%M%S)"
TMPDIR=$(mktemp -d)

git -C "$TMPDIR" init
git -C "$TMPDIR" remote add upstream "$UPSTREAM_URL"
git -C "$TMPDIR" fetch upstream main --depth=1
git -C "$TMPDIR" checkout -b "$BRANCH" upstream/main

for id in <approved_ids>; do
  cp "$LIB_DIR/$id.md" "$TMPDIR/failure-lib/$id.md"
  git -C "$TMPDIR" add "failure-lib/$id.md"
done

git -C "$TMPDIR" commit -m "lesson: contribute $N lesson(s) from community"
git -C "$TMPDIR" remote add fork "$FORK_URL"
git -C "$TMPDIR" push fork "$BRANCH"

rm -rf "$TMPDIR"
```

Both cases end with the same message (substitute real values):
```
Done. Open this URL to submit your PR:

  https://github.com/oanhduong/build-anything/compare/main...<USERNAME>:build-anything:<BRANCH>?expand=1
```

## `/retro prune` (SELF-07)

1. Find all `$LIB_DIR/*.md` whose `tags:` line contains `model-crutch`. If NONE,
   say `No model-crutch rules to prune.` and exit 0 (the live library may have zero
   model-crutch entries — MUST tolerate the empty set gracefully, no error).
2. For each model-crutch rule, parse the model-version token from its tag
   (e.g. `claude-sonnet-4-6`). Compare it against the current model version — ask
   the human what the current model version is, or accept it as an argument. Show
   which rules carry a version OLDER than current.
3. Prompt the human per stale rule: retire (`y`) or keep (`n`).
4. For each retired rule: delete `$LIB_DIR/<id>.md` and commit:
   ```
   git -C "$HOME/.claude" add -A \
     && git -C "$HOME/.claude" commit -m "retro: prune stale model-crutch rule <id> $(date -u +%Y-%m-%dT%H:%M:%SZ)"
   ```
5. Summarize: retired vs kept.

---

All distillation logic lives in `scripts/auto-distill.sh` — this skill only orchestrates review, commit, and prune (SELF-08).
