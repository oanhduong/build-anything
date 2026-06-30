#!/usr/bin/env bash
# test-trace-hook.sh — SKEL-03g: trace.sh writes TIMESTAMP TOOL TARGET EXIT_CODE to trace.log
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${HARNESS_DIR}/hooks/trace.sh"

# Temporarily override HOME to redirect trace.log away from real ~/.claude/trace.log
TMP_HOME=$(mktemp -d)
mkdir -p "$TMP_HOME/.claude"
touch "$TMP_HOME/.claude/trace.log"

MOCK_JSON='{"tool_name":"Write","tool_input":{"path":"src/test.py"},"tool_response":{"exit_code":"0"}}'

# Use bash -c to scope HOME to both sides of the pipeline
HOME="$TMP_HOME" bash -c 'echo '"'"'{"tool_name":"Write","tool_input":{"path":"src/test.py"},"tool_response":{"exit_code":"0"}}'"'"' | '"$HOOK"'' > /dev/null 2>&1
EXIT_CODE=$?

# Check trace.log has a new entry with expected format
TRACE_ENTRY=$(grep "Write" "$TMP_HOME/.claude/trace.log" || echo "")
rm -rf "$TMP_HOME"

if [ "$EXIT_CODE" -eq 0 ] && [ -n "$TRACE_ENTRY" ]; then
  echo "[PASS] SKEL-03g: trace.sh wrote entry to trace.log: ${TRACE_ENTRY}"
  exit 0
else
  echo "[FAIL] SKEL-03g: exit=$EXIT_CODE trace_entry='${TRACE_ENTRY}'" >&2
  exit 1
fi
