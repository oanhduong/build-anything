#!/usr/bin/env bash
# test-claude-md-audit.sh — TDD tests for hooks/claude-md-audit.sh
# CTXP-01: verifies dynamic content blocking in CLAUDE.md
# Output: [PASS]/[FAIL] per check; "N passed, M failed" summary; exits 0 iff all pass

set -uo pipefail

PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL+1)); }

HOOK="$(dirname "$0")/../hooks/claude-md-audit.sh"

# Test 1: ISO 8601 datetime in CLAUDE.md must be blocked (exit 2)
echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"Updated: 2026-06-23T10:00:00Z"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 2 ] && pass "Test 1: ISO 8601 timestamp in CLAUDE.md blocked (exit 2)" \
  || fail "Test 1: ISO 8601 timestamp in CLAUDE.md NOT blocked (got exit $CODE, expected 2)"

# Test 2: CURRENT_TASK state field in CLAUDE.md must be blocked (exit 2)
echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"CURRENT_TASK: my-task"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 2 ] && pass "Test 2: CURRENT_TASK field in CLAUDE.md blocked (exit 2)" \
  || fail "Test 2: CURRENT_TASK field in CLAUDE.md NOT blocked (got exit $CODE, expected 2)"

# Test 3: Static reference content in CLAUDE.md must pass (exit 0)
echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"## What This Is\nStable reference content only."}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 0 ] && pass "Test 3: Static content in CLAUDE.md allowed (exit 0)" \
  || fail "Test 3: Static content in CLAUDE.md NOT allowed (got exit $CODE, expected 0)"

# Test 4: Dynamic content in non-CLAUDE.md file must pass through (exit 0)
echo '{"tool_name":"Write","tool_input":{"path":"src/app.ts","content":"Updated: 2026-06-23T10:00:00Z"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 0 ] && pass "Test 4: Dynamic content in non-CLAUDE.md file passes through (exit 0)" \
  || fail "Test 4: Dynamic content in non-CLAUDE.md file BLOCKED (got exit $CODE, expected 0)"

# Test 5: Non-Write tool must pass through (exit 0)
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 0 ] && pass "Test 5: Non-Write tool passes through (exit 0)" \
  || fail "Test 5: Non-Write tool BLOCKED (got exit $CODE, expected 0)"

# Test 6: VERIFY_CMD state field in CLAUDE.md must be blocked (exit 2)
echo '{"tool_name":"Edit","tool_input":{"path":"CLAUDE.md","new_content":"VERIFY_CMD: exit 0"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 2 ] && pass "Test 6: VERIFY_CMD field in CLAUDE.md blocked (exit 2)" \
  || fail "Test 6: VERIFY_CMD field in CLAUDE.md NOT blocked (got exit $CODE, expected 2)"

# Test 7: ## CURRENT STATE section header in CLAUDE.md must be blocked (exit 2)
echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"## CURRENT STATE\nsome state"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 2 ] && pass "Test 7: ## CURRENT STATE header in CLAUDE.md blocked (exit 2)" \
  || fail "Test 7: ## CURRENT STATE header in CLAUDE.md NOT blocked (got exit $CODE, expected 2)"

# Test 8: Version number like v1.2-04 must NOT be blocked (exit 0) — Pitfall 2
echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"| v1.2-04 | some component |"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 0 ] && pass "Test 8: Version number v1.2-04 in CLAUDE.md not false-positive blocked (exit 0)" \
  || fail "Test 8: Version number v1.2-04 in CLAUDE.md false-positive blocked (got exit $CODE, expected 0)"

# Test 9: Path like docs/CLAUDE.md (nested) must also be caught (exit 2 on dynamic content)
echo '{"tool_name":"Write","tool_input":{"path":"docs/CLAUDE.md","content":"CURRENT_TASK: test"}}' \
  | bash "$HOOK" 2>/dev/null
CODE=$?
[ "$CODE" -eq 2 ] && pass "Test 9: Nested docs/CLAUDE.md dynamic content blocked (exit 2)" \
  || fail "Test 9: Nested docs/CLAUDE.md dynamic content NOT blocked (got exit $CODE, expected 2)"

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
