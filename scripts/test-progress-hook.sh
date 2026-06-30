#!/usr/bin/env bash
# test-progress-hook.sh — SKEL-03f: progress-after-edit.sh appends to HISTORY LOG
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${HARNESS_DIR}/hooks/progress-after-edit.sh"

TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/.progress"
cat > "$TMP_DIR/.progress/PROGRESS.md" << 'EOF'
CURRENT_TASK: test-task
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
EOF

MOCK_JSON='{"tool_name":"Write","tool_input":{"path":"src/test.py","content":"x=1"}}'

cd "$TMP_DIR"
echo "$MOCK_JSON" | "$HOOK" > /dev/null 2>&1
EXIT_CODE=$?
# Check that HISTORY LOG has a new entry
HISTORY_ENTRY=$(grep -c "Write\|Edit" "$TMP_DIR/.progress/PROGRESS.md" || echo "0")
cd - > /dev/null
rm -rf "$TMP_DIR"

if [ "$EXIT_CODE" -eq 0 ] && [ "$HISTORY_ENTRY" -gt 0 ]; then
  echo "[PASS] SKEL-03f: progress-after-edit.sh appended to HISTORY LOG on Write"
  exit 0
else
  echo "[FAIL] SKEL-03f: exit=$EXIT_CODE history_entries=$HISTORY_ENTRY (expected exit 0 and >=1 entry)" >&2
  exit 1
fi
