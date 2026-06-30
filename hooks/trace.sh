#!/usr/bin/env bash
# trace.sh — PostToolUse hook
# SKEL-03g: writes TIMESTAMP TOOL TARGET EXIT_CODE to ~/.claude/trace.log on every tool use
# tag: architecture
# How to fix: N/A — this hook is non-blocking (PostToolUse, no exit 2 calls); trace only
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
# Extract target: path for Write/Edit, command for Bash, url for WebFetch, else "-"
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.command // .tool_input.url // "-"')
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // "0"')

trace_write "$TOOL_NAME" "$FILE_PATH" "$EXIT_CODE"

exit 0
