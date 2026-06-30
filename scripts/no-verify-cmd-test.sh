#!/usr/bin/env bash
# no-verify-cmd-test.sh — PLAN-01: Write is blocked when VERIFY_CMD is empty in PROGRESS
# Phase 0 success criterion #6: this script exits 0 iff enforcement confirmed
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${HARNESS_DIR}/hooks/stub-reject.sh"

TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/.progress"
# PROGRESS with EMPTY VERIFY_CMD — should trigger PLAN-01 block
cat > "$TMP_DIR/.progress/PROGRESS.md" << 'EOF'
CURRENT_TASK: unverified-task
VERIFY_CMD:
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
EOF

# Write with valid content (no stubs) — only PLAN-01 should trigger
MOCK_JSON='{"tool_name":"Write","tool_input":{"path":"src/real.py","content":"def foo():\n    return 42\n"}}'

cd "$TMP_DIR"
echo "$MOCK_JSON" | "$HOOK" > /dev/null 2>&1
EXIT_CODE=$?
cd - > /dev/null
rm -rf "$TMP_DIR"

if [ "$EXIT_CODE" -eq 2 ]; then
  echo "[PASS] PLAN-01: Write correctly blocked when VERIFY_CMD is empty (exit 2)"
  exit 0
else
  echo "[FAIL] PLAN-01: expected exit 2 (blocked), got ${EXIT_CODE}" >&2
  echo "  VERIFY_CMD enforcement is not working in stub-reject.sh" >&2
  exit 1
fi
