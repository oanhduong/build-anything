#!/usr/bin/env bash
# progress-after-edit.sh — PostToolUse hook
# SKEL-04: updates PROGRESS file after every Write/Edit
# tag: architecture
# How to fix: N/A — this hook is non-blocking (PostToolUse, no exit 2 calls); uses emit() only
# Sections: CURRENT STATE (overwritten, capped at 20 lines), HISTORY LOG (append-only)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

INPUT=$(cat)

# Only fire on Write or Edit tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
  exit 0
fi

PROGRESS_FILE="${PWD}/.progress/PROGRESS.md"

# If no PROGRESS file, emit warning and exit (non-blocking — PostToolUse exit 2 is non-blocking anyway)
if [ ! -f "$PROGRESS_FILE" ]; then
  emit "WARNING: .progress/PROGRESS.md not found; PROGRESS not updated"
  exit 0
fi

# Parse tool details for history line
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // "unknown"' 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CURRENT_TASK=$(grep "^CURRENT_TASK:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "none")

# Append to HISTORY LOG (append-only; never modify existing entries)
HISTORY_LINE="${TIMESTAMP} | ${TOOL_NAME} | ${FILE_PATH} | task:${CURRENT_TASK}"
echo "$HISTORY_LINE" >> "$PROGRESS_FILE"

# Update CURRENT STATE section (overwrite between markers; cap at 20 lines)
# Strategy: Replace the content between ## CURRENT STATE and ## HISTORY LOG
# Use a temp file to avoid in-place sed issues
TMP=$(mktemp)
awk -v ts="$TIMESTAMP" -v tool="$TOOL_NAME" -v file="$FILE_PATH" -v task="$CURRENT_TASK" '
  /^## CURRENT STATE$/ {
    print
    print ""
    print "Last updated: " ts
    print "Last edit: " tool " → " file
    print "Active task: " task
    print ""
    in_current=1
    next
  }
  /^## HISTORY LOG$/ {
    in_current=0
  }
  in_current { next }
  { print }
' "$PROGRESS_FILE" > "$TMP"
mv "$TMP" "$PROGRESS_FILE"

exit 0
