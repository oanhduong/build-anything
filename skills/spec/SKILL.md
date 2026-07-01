---
name: spec
description: Risk-driven spec interview. Asks three risk questions, proposes a draft SPEC.md, waits for explicit human "confirm", then computes a sha256 confirm-token over the acceptance criteria and writes .progress/SPEC.md plus updates PROGRESS.md VERIFY_CMD.
argument-hint: "<task description>"
---

Gate every code-writing task behind a human-confirmed spec. The /spec skill runs a fixed
3-question risk interview, proposes a draft SPEC.md for human review, and only writes
`.progress/SPEC.md` after the human types the literal word "confirm". At confirm time the
skill computes a sha256 confirm-token over the `## Acceptance Criteria` section text and
embeds it in the written file. The stub-reject.sh hook re-derives this token on every
subsequent Write/Edit and blocks execution if the criteria text has changed since
confirmation.

Use `$ARGUMENTS` as the task description context in the interview.

## STEP 1 — Interview

Ask exactly these three questions in a single message and wait for the human to answer all
three before proceeding:

1. "What can go wrong with this task?"
2. "What does 'done' look like — how will you know it is working?"
3. "What is the smallest safe change that proves the core requirement?"

Do not skip, reorder, or collapse these questions. Do not propose a draft until you have
received answers.

## STEP 2 — Propose draft

Using the answers, compose a draft SPEC.md in the following exact format and display it
INLINE in your reply. Do NOT write any file at this point.

```
---
task: <task name derived from $ARGUMENTS>
confirm-token: PENDING
confirmed-at: <will be set at confirm time>
---

## Risk List
- <risk from Q1 answer>

## Acceptance Criteria
1. <criterion from Q2/Q3 answer>
2. <additional criterion if needed>

## Verify Command
<prose note: what VERIFY_CMD checks and why it is the done criterion>
```

In the draft frontmatter, show `confirm-token: PENDING` — the real token is computed only
at confirm time from the written file. Also show the derived VERIFY_CMD (from STEP 6) so
the human sees it before confirming.

## STEP 3 — Confirm gate

After displaying the draft, state explicitly:

"Type the literal word confirm to write this spec. Any other response — edits, 'yes',
'ok', 'looks good', 'approved' — will NOT write it; I will incorporate your changes and
re-propose."

If the human types anything other than exactly the string `confirm` (case-sensitive,
trimmed, no surrounding punctuation), incorporate their feedback and return to STEP 2.
Only the literal string `confirm` proceeds to STEP 4. Auto-confirm is prohibited.

## STEP 4 — Guard and prepare

When the human types `confirm`, run this guard block in Bash:

```bash
PROGRESS_FILE="${PWD}/.progress/PROGRESS.md"
SPEC_FILE="${PWD}/.progress/SPEC.md"
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "PROGRESS.md missing — run the SessionStart bootstrap or create .progress/PROGRESS.md first" >&2
  exit 1
fi
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

Then write `.progress/SPEC.md` using the Write tool. This path is exempt from the spec gate
in stub-reject.sh so the write succeeds even before SPEC.md exists. Use the confirmed
criteria from the draft. Write `confirm-token: PENDING` in the frontmatter — the real token
is computed from the WRITTEN file in STEP 5.

Example content for the Write tool:

```
---
task: <task name>
confirm-token: PENDING
confirmed-at: <TIMESTAMP>
---

## Risk List
- <risks from Q1>

## Acceptance Criteria
1. <criterion>
2. <criterion>

## Verify Command
<prose note>
```

## STEP 5 — Compute token from the written file and patch it in

Run exactly this pipeline in Bash — it MUST be byte-identical to the one in stub-reject.sh
so the two sides hash identical bytes. Always use `shasum -a 256` — it is portable across
macOS and Linux. The Linux-only variant is not available on macOS and must not be used:

```bash
TOKEN=$(awk '/^## Acceptance Criteria$/{in_sec=1;next} in_sec && /^## /{exit} in_sec{print}' "$SPEC_FILE" \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | shasum -a 256 | cut -d' ' -f1)
sed -i.bak "s|^confirm-token: PENDING|confirm-token: ${TOKEN}|" "$SPEC_FILE" && rm -f "${SPEC_FILE}.bak"
```

Patching `confirm-token: PENDING` to the real token in the frontmatter does NOT alter the
`## Acceptance Criteria` section text, so the token remains valid when stub-reject
re-derives it on the next Write/Edit.

## STEP 6 — Derive VERIFY_CMD and update PROGRESS.md

Derive VERIFY_CMD from the FIRST numbered criterion in the written SPEC.md, then update
PROGRESS.md in place via `sed` in Bash (not the Edit tool — Edit would go through the
Write/Edit hook path; sed via Bash bypasses it). Write SPEC.md BEFORE this step (Pitfall 5).

Use `|` as the sed delimiter to avoid conflicts with path separators in VERIFY_CMD values:

```bash
FIRST_CRITERION=$(awk '/^## Acceptance Criteria$/{in_sec=1;next} in_sec && /^## /{exit} in_sec && NF{print; exit}' "$SPEC_FILE" \
  | sed 's/^[[:space:]]*[0-9]*[.)]*[[:space:]]*//;s/^[[:space:]]*[-*][[:space:]]*//;s/^[[:space:]]*//;s/[[:space:]]*$//')
DERIVED_CMD="$FIRST_CRITERION"
sed -i.bak "s|^VERIFY_CMD:.*|VERIFY_CMD: ${DERIVED_CMD}|" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
```

Note: if the first criterion is not directly runnable as a shell command, the human may
hand-edit `PROGRESS.md VERIFY_CMD` afterward to a runnable command equivalent.

## STEP 7 — Report

Tell the human:
- The path `.progress/SPEC.md` was written successfully
- The confirm-token value (sha256 hash)
- The new VERIFY_CMD now active in PROGRESS.md
- "The spec gate is now open for this task. Subsequent Write/Edit calls will be validated
  against the criteria you confirmed."
