#!/usr/bin/env bash
# verdicts-capture.sh — PostToolUse hook (all tools)
# VERIF-02: captures VERIFIER-VERDICT: blocks from tool_response into .progress/VERDICTS.md
# This is the ONLY write path for .progress/VERDICTS.md (verdict integrity, architecture rule)
# Write/Edit targeting VERDICTS.md is blocked by stub-reject.sh
# tag: architecture
# How to fix: N/A — non-blocking PostToolUse hook; uses emit() only; never calls block() or exit 2
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

INPUT=$(cat)

# Debug: uncomment to log raw hook input on first real run and observe tool_response format
# echo "$INPUT" >> /tmp/verdicts-debug.json

# Defensive multi-format extraction of tool_response text
# tool_response for Task/Agent calls may be: string (most common), content-block array,
# or object with .output/.content/.text field. Handle all three defensively.
RESPONSE_TEXT=$(echo "$INPUT" | jq -r '
  .tool_response // empty |
  if type == "string" then .
  elif type == "array" then map(select(.type == "text") | .text) | join("\n")
  elif type == "object" then (.output // .content // .text // (. | tojson))
  else (. | tojson)
  end
' 2>/dev/null || echo "")

# Quick exit: no verifier header in tool_response — skip without action (most calls)
if [ -z "$RESPONSE_TEXT" ] || ! echo "$RESPONSE_TEXT" | grep -q "VERIFIER-VERDICT:"; then
  exit 0
fi

VERDICTS_FILE="${PWD}/.progress/VERDICTS.md"
mkdir -p "$(dirname "$VERDICTS_FILE")"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Extract all VERIFIER-VERDICT: blocks and append to VERDICTS.md
# Uses awk state machine — ENFC-04 compliant (no python3, node, java, kotlin)
# Each block: CRITERION: + VERDICT: + EVIDENCE: lines; blank line terminates block.
# END handler captures last block if response has no trailing blank line.
CAPTURED=$(echo "$RESPONSE_TEXT" | awk -v ts="$TIMESTAMP" '
  /^VERIFIER-VERDICT:/ {
    in_block=1; crit=""; ver=""; ev=""
    next
  }
  in_block && /^CRITERION: / { crit=$0; next }
  in_block && /^VERDICT: /   { ver=$0; next }
  in_block && /^EVIDENCE: /  { ev=$0; next }
  in_block && /^[[:space:]]*$/ {
    if (crit != "" && ver != "" && ev != "") {
      print "--- " ts
      print crit
      print ver
      print ev
      print ""
    }
    in_block=0; crit=""; ver=""; ev=""
    next
  }
  END {
    if (in_block && crit != "" && ver != "" && ev != "") {
      print "--- " ts
      print crit
      print ver
      print ev
      print ""
    }
  }
')

if [ -n "$CAPTURED" ]; then
  echo "$CAPTURED" >> "$VERDICTS_FILE"
  BLOCK_COUNT=$(echo "$CAPTURED" | grep -c "^--- " || echo 0)
  emit "verdicts-capture: appended ${BLOCK_COUNT} verdict block(s) to ${VERDICTS_FILE}"
fi

exit 0
