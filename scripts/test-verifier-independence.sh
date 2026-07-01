#!/usr/bin/env bash
# test-verifier-independence.sh — Phase 5 binary exit criterion validation
# Covers: Binary A (ROADMAP binary exit A), Binary B (ROADMAP binary exit B),
#         VERIF-01 (pass case), VERIF-01 (fail case), VERIF-02, VERIF-03
# Wave 0: tests start RED — Wave 1/2 implementations make them GREEN
# Exit 0 iff all tests pass
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOP_HOOK="${HARNESS_DIR}/hooks/stop-hook.sh"
STUB_REJECT="${HARNESS_DIR}/hooks/stub-reject.sh"
VERDICTS_CAPTURE="${HARNESS_DIR}/hooks/verdicts-capture.sh"

PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }

# ============================================================
# BINARY A: SPEC.md present + VERDICTS.md absent → stop-hook exit 2 + both criterion strings in stderr
# ROADMAP.md Phase 5 binary exit criterion A
# ============================================================
TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: binary-a-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
cat > "$TMP/.progress/SPEC.md" << 'SPEC'
## Acceptance Criteria
- test -f hooks/stop-hook.sh
- grep -q VERIFIER-VERDICT hooks/verdicts-capture.sh
SPEC

MOCK=$(jq -n --arg cwd "$TMP" \
  '{"session_id":"test","stop_hook_active":false,"transcript_path":"/tmp/t.jsonl","cwd":$cwd,"hook_event_name":"Stop"}')
ERRFILE=$(mktemp)
echo "$MOCK" | "$STOP_HOOK" >/dev/null 2>"$ERRFILE"
EXITCODE=$?
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"
rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ] \
  && echo "$ERRTXT" | grep -qF 'test -f hooks/stop-hook.sh' \
  && echo "$ERRTXT" | grep -qF 'grep -q VERIFIER-VERDICT hooks/verdicts-capture.sh'; then
  pass "Binary A: stop-hook exits 2 with both criterion strings in stderr when VERDICTS.md absent"
else
  fail "Binary A: exit=$EXITCODE; stderr must contain both criterion strings verbatim. stderr='$(echo "$ERRTXT" | head -6)'"
fi

# ============================================================
# BINARY B: Write to .progress/VERDICTS.md → stub-reject exit 2 "VERDICTS.md is hook-written"
# ROADMAP.md Phase 5 binary exit criterion B
# ============================================================
TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"
MOCK='{"tool_name":"Write","tool_input":{"path":".progress/VERDICTS.md","content":"VERDICT: PASS\n"}}'
ERRFILE=$(mktemp)
cd "$TMP"
echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"
EXITCODE=$?
cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"
rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ] && echo "$ERRTXT" | grep -q "VERDICTS.md is hook-written"; then
  pass "Binary B: stub-reject exits 2 with 'VERDICTS.md is hook-written' on Write to .progress/VERDICTS.md"
else
  fail "Binary B: exit=$EXITCODE; stderr must contain 'VERDICTS.md is hook-written'. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
# VERIF-02: verdicts-capture.sh captures VERIFIER-VERDICT: block from mock tool_response (string format)
# Requirement VERIF-02: verifier subagent returns structured VERDICT: PASS|FAIL with evidence
# ============================================================
TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"
RESP=$(printf 'VERIFIER-VERDICT:\nCRITERION: test -f hooks/stop-hook.sh\nVERDICT: PASS\nEVIDENCE: file exists exit 0\n')
MOCK=$(jq -n --arg resp "$RESP" '{"tool_name":"Task","tool_response":$resp}')
cd "$TMP"
echo "$MOCK" | "$VERDICTS_CAPTURE" >/dev/null 2>&1
cd - >/dev/null
VFILE="$TMP/.progress/VERDICTS.md"

if [ -f "$VFILE" ] \
  && grep -q "CRITERION: test -f hooks/stop-hook.sh" "$VFILE" \
  && grep -q "VERDICT: PASS" "$VFILE" \
  && grep -q "EVIDENCE:" "$VFILE"; then
  pass "VERIF-02: verdicts-capture.sh captured VERIFIER-VERDICT: block into VERDICTS.md"
else
  fail "VERIF-02: VERDICTS.md missing or incomplete. Exists=$(test -f "$VFILE" && echo yes || echo no)"
fi
rm -rf "$TMP"

# ============================================================
# VERIF-01 (pass): stop-hook exits 0 when SPEC.md criteria all have VERDICT: PASS in VERDICTS.md
# Requirement VERIF-01: stop-hook uses independent verifier verdict, not self-grading
# ============================================================
TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: verif-01-pass-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
cat > "$TMP/.progress/SPEC.md" << 'SPEC'
## Acceptance Criteria
- test -f hooks/stop-hook.sh
SPEC
printf -- '--- 2026-01-01T00:00:00Z\nCRITERION: test -f hooks/stop-hook.sh\nVERDICT: PASS\nEVIDENCE: file exists\n\n' \
  > "$TMP/.progress/VERDICTS.md"

MOCK=$(jq -n --arg cwd "$TMP" \
  '{"session_id":"test","stop_hook_active":false,"transcript_path":"/tmp/t.jsonl","cwd":$cwd,"hook_event_name":"Stop"}')
echo "$MOCK" | "$STOP_HOOK" >/dev/null 2>&1
EXITCODE=$?
rm -rf "$TMP"

if [ "$EXITCODE" -eq 0 ]; then
  pass "VERIF-01 (pass): stop-hook exits 0 when all criteria have VERDICT: PASS in VERDICTS.md"
else
  fail "VERIF-01 (pass): expected exit 0, got exit=$EXITCODE"
fi

# ============================================================
# VERIF-01 (fail): stop-hook exits 2 when a criterion has VERDICT: FAIL in VERDICTS.md
# This is RED at Wave 0 — current stop-hook exits 0 on VERIFY_CMD pass regardless of VERDICTS.md
# ============================================================
TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: verif-01-fail-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
cat > "$TMP/.progress/SPEC.md" << 'SPEC'
## Acceptance Criteria
- test -f hooks/stop-hook.sh
SPEC
printf -- '--- 2026-01-01T00:00:00Z\nCRITERION: test -f hooks/stop-hook.sh\nVERDICT: FAIL\nEVIDENCE: file not found\n\n' \
  > "$TMP/.progress/VERDICTS.md"

MOCK=$(jq -n --arg cwd "$TMP" \
  '{"session_id":"test","stop_hook_active":false,"transcript_path":"/tmp/t.jsonl","cwd":$cwd,"hook_event_name":"Stop"}')
echo "$MOCK" | "$STOP_HOOK" >/dev/null 2>&1
EXITCODE=$?
rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ]; then
  pass "VERIF-01 (fail): stop-hook exits 2 when a criterion has VERDICT: FAIL in VERDICTS.md"
else
  fail "VERIF-01 (fail): expected exit 2 (FAIL verdict in VERDICTS.md), got exit=$EXITCODE"
fi

# ============================================================
# VERIF-03: stop-hook reads criterion text from SPEC.md and reports it verbatim in stderr
# Uses a unique sentinel string to prove the text comes from SPEC.md, not hardcoded
# ============================================================
TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: verif-03-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
UNIQUE="grep -qF SENTINEL_TOKEN_XYZ_99 output.txt"
printf '## Acceptance Criteria\n- %s\n' "$UNIQUE" > "$TMP/.progress/SPEC.md"

MOCK=$(jq -n --arg cwd "$TMP" \
  '{"session_id":"test","stop_hook_active":false,"transcript_path":"/tmp/t.jsonl","cwd":$cwd,"hook_event_name":"Stop"}')
ERRFILE=$(mktemp)
echo "$MOCK" | "$STOP_HOOK" >/dev/null 2>"$ERRFILE"
EXITCODE=$?
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"
rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ] && echo "$ERRTXT" | grep -qF "$UNIQUE"; then
  pass "VERIF-03: stop-hook reads criterion from SPEC.md and reports it verbatim in stderr"
else
  fail "VERIF-03: exit=$EXITCODE; stderr must contain criterion text verbatim. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
