#!/usr/bin/env bash
# claude-md-audit.sh — PreToolUse hook
# CTXP-01: blocks dynamic content in CLAUDE.md to preserve KV-cache prefix stability
# tag: architecture
# blocking: block() → exit 2 (SKEL-07: exit 2 is the only blocking exit code)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

INPUT=$(cat)

# Only fire on Write, Edit, or MultiEdit tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "MultiEdit" ]]; then
  exit 0
fi

# Only fire when the target file is CLAUDE.md (including nested paths like docs/CLAUDE.md)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
if ! echo "$FILE_PATH" | grep -qE '(^|/)CLAUDE\.md$'; then
  exit 0
fi

# Read the content being written
FILE_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_content // empty')
[ -z "$FILE_CONTENT" ] && exit 0

# Pattern check 1 — ISO 8601 datetime: anchored to T[0-9]{2} to avoid false-positives on
# version numbers like v1.2-04 which have date-like segments but no time component
# How to fix: Move timestamps to .progress/PROGRESS.md; keep CLAUDE.md static (CTXP-01)
if echo "$FILE_CONTENT" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}'; then
  block "Dynamic content detected in CLAUDE.md: ISO 8601 timestamp found" \
    "Move timestamps to .progress/PROGRESS.md or a session-specific file. CLAUDE.md must be static reference content only (CTXP-01 — KV-cache stability)."
fi

# Pattern check 2 — PROGRESS state fields and live-state lines
# How to fix: Remove live-state fields from CLAUDE.md; put them in .progress/PROGRESS.md (CTXP-01)
if echo "$FILE_CONTENT" | grep -qE '^(CURRENT_TASK:|VERIFY_CMD:|BLOCKED_COUNT:|## CURRENT STATE|Last updated:|Current task:)'; then
  block "Dynamic content detected in CLAUDE.md: live-state line found (CURRENT_TASK/VERIFY_CMD/BLOCKED_COUNT/Last updated)" \
    "Remove live-state fields from CLAUDE.md. Dynamic task state belongs in .progress/PROGRESS.md only (CTXP-01)."
fi

exit 0
