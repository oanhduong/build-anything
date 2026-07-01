#!/usr/bin/env bash
# stub-reject.sh — PreToolUse hook
# SKEL-07: exit 2 blocks; stderr only; chmod +x
# tag: architecture
# PLAN-01: also blocks Write/Edit if VERIFY_CMD is empty in PROGRESS
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

INPUT=$(cat)

# Only fire on Write or Edit tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
  exit 0
fi

# VERIF-03 integrity: VERDICTS.md is exclusively written by verdicts-capture.sh hook
# Any direct Write/Edit to .progress/VERDICTS.md is a self-grading attempt — block unconditionally
FILE_PATH_EARLY=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.file_path // empty' 2>/dev/null || echo "")
if [[ "$FILE_PATH_EARLY" == *".progress/VERDICTS.md"* ]]; then
  block "VERDICTS.md is hook-written; do not write manually" \
    "Verdicts must originate from verifier subagent output captured by verdicts-capture.sh. Invoke the verifier subagent per criterion instead."
fi

# GATE-02/GATE-03: Block Write/Edit until a human-confirmed .progress/SPEC.md exists with a valid confirm-token.
# EXEMPTION (Pitfall 1 — self-blocking): writes targeting .progress/SPEC.md ARE the authorized creation
# path (same reasoning as verdicts-capture.sh owning VERDICTS.md). Skip all three gate checks for that path.
SPEC_FILE="${PWD}/.progress/SPEC.md"
if [[ "$FILE_PATH_EARLY" != *".progress/SPEC.md"* ]]; then
  # Check 1 (GATE-02): SPEC.md absent
  if [ ! -f "$SPEC_FILE" ]; then
    block "SPEC.md absent" \
      "Run /spec to create a human-confirmed spec before writing code"
  fi
  # Check 2 (GATE-03): SPEC.md present but no confirm-token field (a malformed/criteria-less spec
  # cannot have a valid token, so this check subsumes 'no ## Acceptance Criteria section')
  STORED_TOKEN=$(grep '^confirm-token:' "$SPEC_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "")
  if [ -z "$STORED_TOKEN" ]; then
    block "SPEC.md unconfirmed" \
      "Run /spec and type 'confirm' to generate the confirm-token"
  fi
  # Check 3 (GATE-02 integrity): confirm-token present but criteria text changed after confirmation.
  # Re-derive token with the SAME awk+sed+shasum pipeline the /spec skill uses.
  COMPUTED_TOKEN=$(awk '/^## Acceptance Criteria$/{in_sec=1;next} in_sec && /^## /{exit} in_sec{print}' "$SPEC_FILE" \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | shasum -a 256 | cut -d' ' -f1)
  if [ "$STORED_TOKEN" != "$COMPUTED_TOKEN" ]; then
    block "SPEC.md token invalid — criteria modified after confirmation" \
      "Re-run /spec to confirm the updated criteria"
  fi
fi

# PLAN-01: Block Write/Edit if no verify command is declared in PROGRESS
PROGRESS_FILE="${PWD}/.progress/PROGRESS.md"
if [ -f "$PROGRESS_FILE" ]; then
  VERIFY_CMD=$(grep "^VERIFY_CMD:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "")
  if [ -z "$VERIFY_CMD" ]; then
    # How to fix: Add VERIFY_CMD: <runnable command> to .progress/PROGRESS.md
    block "No verify command declared for current task" \
      "Add VERIFY_CMD: <runnable command> to .progress/PROGRESS.md before writing code. A task without a binary done-criterion is blocked from execution (PLAN-01)."
  fi
fi

# SKEL-03e: Reject stubs — grep for pass$, TODO, NotImplemented in file content
FILE_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_content // empty' 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || echo "")

if [ -n "$FILE_CONTENT" ]; then
  # Check for stub patterns in the content being written
  if echo "$FILE_CONTENT" | grep -qE '^\s*pass\s*$|TODO|NotImplemented'; then
    block "Stub code detected in ${FILE_PATH}: found pass/TODO/NotImplemented" \
      "Replace all stub bodies with real implementations before writing. grep -n 'pass\$\|TODO\|NotImplemented' to find them."
  fi
fi

exit 0
