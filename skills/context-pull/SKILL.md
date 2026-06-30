---
name: context-pull
description: Pull context from docs/ and .progress/ files. Use when resuming a task after context reset, when you need to find a specific file, or when a CLAUDE.md table entry needs expansion. Does NOT search failure-lib — that is surfaced automatically at session start.
argument-hint: "search <query> | get-file <path> | expand-summary <section>"
disable-model-invocation: false
---

Pull context from project files. Parse the first word of `$ARGUMENTS` as the subcommand:

## search <query>

Grep `docs/` and `.progress/` for the query. Do NOT search `failure-lib/` (already surfaced by `load-lessons.sh` at session start).

Run this command and return the output:
```
grep -rn "$ARGUMENTS" docs/ .progress/ 2>/dev/null | head -40
```
(Strip the leading subcommand word before passing the remaining text as the query.)

## get-file <path>

Read the file at the path given in `$ARGUMENTS` (after stripping the `get-file` prefix) and return its full contents.

## expand-summary <section>

Look up the section name from `$ARGUMENTS` (after stripping `expand-summary`) in `CLAUDE.md`'s reference table. Find the file path it points to, then read and return that file's full content. If the file does not exist, return: "File not found: <path> — the referenced document has not been created yet."

---

Return all output as plain markdown. One operation per invocation.
