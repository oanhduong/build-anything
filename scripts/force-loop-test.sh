#!/usr/bin/env bash
# force-loop-test.sh — LOOP-01 + LOOP-02 validation
# Phase 0 success criterion #7 and #8: exit 0 iff both proofs pass
# Tests stop-hook.sh directly with mock JSON input (no live Claude session required)
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${HARNESS_DIR}/hooks/stop-hook.sh"

PASS=0; FAIL=0

# ---- LOOP-01 PROOF ----
# Scenario: VERIFY_CMD is a failing command; stop_hook_active=false; BLOCKED_COUNT=0
# Expected: hook exits 2 (blocks stop)
TMP_DIR_1=$(mktemp -d)
mkdir -p "$TMP_DIR_1/.progress"
cat > "$TMP_DIR_1/.progress/PROGRESS.md" << 'EOF'
CURRENT_TASK: test-loop-01
VERIFY_CMD: exit 1
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
EOF

MOCK_STOP='{"session_id":"test","stop_hook_active":false,"transcript_path":"/tmp/test.jsonl","cwd":"'"$TMP_DIR_1"'","hook_event_name":"Stop"}'

echo "$MOCK_STOP" | "$HOOK" > /dev/null 2>&1
EXIT_CODE=$?
rm -rf "$TMP_DIR_1"

if [ "$EXIT_CODE" -eq 2 ]; then
  echo "[PASS] LOOP-01: stop-hook.sh exited 2 (blocked stop) on failing verify command"
  ((PASS++))
else
  echo "[FAIL] LOOP-01: expected exit 2, got ${EXIT_CODE}" >&2
  ((FAIL++))
fi

# ---- LOOP-02 PROOF ----
# Scenario: BLOCKED_COUNT = 3 (at ceiling); VERIFY_CMD still failing
# Expected: hook exits 0 (allows stop after escalation) AND writes BLOCKED to PROGRESS
TMP_DIR_2=$(mktemp -d)
mkdir -p "$TMP_DIR_2/.progress"
cat > "$TMP_DIR_2/.progress/PROGRESS.md" << 'EOF'
CURRENT_TASK: test-loop-02
VERIFY_CMD: exit 1
BLOCKED_COUNT: 3

## CURRENT STATE

## HISTORY LOG
EOF

MOCK_STOP_2='{"session_id":"test","stop_hook_active":false,"transcript_path":"/tmp/test.jsonl","cwd":"'"$TMP_DIR_2"'","hook_event_name":"Stop"}'

echo "$MOCK_STOP_2" | "$HOOK" > /dev/null 2>&1
EXIT_CODE_2=$?
BLOCKED_LINE=$(grep "BLOCKED" "$TMP_DIR_2/.progress/PROGRESS.md" || echo "")
rm -rf "$TMP_DIR_2"

if [ "$EXIT_CODE_2" -eq 0 ] && [ -n "$BLOCKED_LINE" ]; then
  echo "[PASS] LOOP-02: stop-hook.sh exited 0 at ceiling and wrote BLOCKED to PROGRESS"
  ((PASS++))
else
  echo "[FAIL] LOOP-02: exit=$EXIT_CODE_2, BLOCKED_in_PROGRESS='${BLOCKED_LINE}' (need exit 0 + BLOCKED present)" >&2
  ((FAIL++))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
