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
