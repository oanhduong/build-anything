#!/usr/bin/env bash
# test-stub-reject.sh — SKEL-03e: stub-reject.sh exits 2 when content contains stubs
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${HARNESS_DIR}/hooks/stub-reject.sh"

# Create a temp dir with PROGRESS file (VERIFY_CMD set so PLAN-01 check passes)
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/.progress"
cat > "$TMP_DIR/.progress/PROGRESS.md" << 'EOF'
CURRENT_TASK: test-task
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE
Test state

## HISTORY LOG
EOF

# Mock JSON: Write tool with stub content containing "pass" on its own line
MOCK_JSON='{"tool_name":"Write","tool_input":{"path":"test.py","content":"def foo():\n    pass\n"}}'

cd "$TMP_DIR"
echo "$MOCK_JSON" | "$HOOK" > /dev/null 2>&1
EXIT_CODE=$?
cd - > /dev/null
rm -rf "$TMP_DIR"

if [ "$EXIT_CODE" -eq 2 ]; then
  echo "[PASS] SKEL-03e: stub-reject.sh correctly blocks on 'pass' stub (exit 2)"
  exit 0
else
  echo "[FAIL] SKEL-03e: expected exit 2 on stub content, got ${EXIT_CODE}" >&2
  exit 1
fi
