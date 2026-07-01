---
name: spec
description: Risk-driven spec interview. Asks three risk questions, proposes a draft SPEC.md, waits for explicit human "confirm", then computes a sha256 confirm-token over the acceptance criteria and writes .progress/SPEC.md plus PROGRESS.md VERIFY_CMD.
argument-hint: "<task description>"
---

Gate every code-writing task behind a human-confirmed spec. The /spec skill conducts a
structured risk interview, proposes a draft SPEC.md for human review, and only writes the
final SPEC.md after the human types the literal word "confirm". At confirm time the skill
computes a sha256 confirm-token over the `## Acceptance Criteria` section and embeds it in
the written file. The stub-reject.sh hook re-derives this token on every subsequent Write/Edit
and blocks execution if the criteria text has changed since confirmation — ensuring the
generator cannot quietly modify its own acceptance bar after the human has approved it.

## Flow (implemented in wave 2 / plan 03)

1. Ask 3 risk questions: (1) what can go wrong, (2) what does done look like, (3) what is the
   smallest safe change that proves the core requirement.
2. Propose a draft SPEC.md to the human (display only — do NOT write yet).
3. Wait for the human to type the literal word "confirm" before proceeding; any other response
   prompts a revision cycle.
4. Compute `shasum -a 256` of the `## Acceptance Criteria` section text (awk extraction,
   whitespace-normalised) to produce the confirm-token.
5. Write `.progress/SPEC.md` with frontmatter containing `task:`, `confirm-token:`, and
   `confirmed-at:` fields, followed by `## Risk List`, `## Acceptance Criteria`, and
   `## Verify Command` sections.
6. Derive VERIFY_CMD from the first criterion and update the `VERIFY_CMD:` field in
   `.progress/PROGRESS.md` via `sed -i.bak`.
