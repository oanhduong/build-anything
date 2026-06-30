---
name: handoff
description: Write a fresh .progress/HANDOFF.md now with current session state. Use when checkpointing mid-session, before a risky operation, or when you want to ensure continuity before a context-heavy operation.
disable-model-invocation: true
---

Write `.progress/HANDOFF.md` immediately with current session state.

1. Read `.progress/PROGRESS.md`
2. Extract:
   - `CURRENT_TASK:` field value
   - Last 3 lines from HISTORY LOG that start with a timestamp (format: YYYY-MM-DDTHH:MM:SSZ)
   - Any `BLOCKED:` lines (if none, use "none")
3. Write `.progress/HANDOFF.md` with exactly these four sections:
   - `## Current Task` — CURRENT_TASK value
   - `## Last 3 Edits` — last 3 HISTORY LOG timestamp entries, each prefixed with `  - `
   - `## Open Blockers` — BLOCKED: lines or "none"
   - `## Next Action` — one-line description: "Resume CURRENT_TASK: <task>. Run VERIFY_CMD to check state."
4. Confirm: "HANDOFF.md written to .progress/HANDOFF.md"
