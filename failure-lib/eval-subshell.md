---
id: eval-subshell
tags: [bash, hooks, shell]
when: pre-write
---

## What happened
`eval VERIFY_CMD` inside `set -euo pipefail` causes the eval's exit code to propagate into the parent shell via `set -e`. If VERIFY_CMD exits 1, the hook exits 1 (non-blocking), not 2. Even wrapping in `if eval ...; then` does NOT protect against this.

## Why
`set -e` treats a non-zero exit from eval as fatal. The if-condition suppresses `-e` for the test expression, but not inside the then/else branches.

## How to avoid
Wrap eval in a subshell: `( eval "$VERIFY_CMD" )`. The subshell exit code is captured by the parent without triggering `-e` in the parent shell.
