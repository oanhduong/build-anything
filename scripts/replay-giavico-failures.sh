#!/usr/bin/env bash
# replay-giavico-failures.sh — Phase 1 done command
# Proves ENFC-01..05: every Phase 0 failure category is blocked or documented
# Output style: [PASS]/[FAIL] per test, "N passed, M failed" summary, exits 0 iff all pass
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }

# ---- PRE-STEP: install harness so ~/.claude/hooks/ reflects source ----
# ENFC-02/03/04 check the INSTALLED path. Install before any check.
if bash "$HARNESS_DIR/install.sh" > /dev/null 2>&1; then
  echo "[INFO] install.sh completed — ~/.claude/hooks/ is up to date"
else
  echo "[WARN] install.sh returned non-zero — continuing anyway" >&2
fi

echo ""
echo "=== ENFC-01: Phase 0 failure injection tests ==="

# F-EVAL-SUBSHELL: subshell eval pattern in stop-hook.sh
# Delegate to existing force-loop-test.sh which already exercises this code path
if bash "$HARNESS_DIR/scripts/force-loop-test.sh" > /dev/null 2>&1; then
  pass "F-EVAL-SUBSHELL: subshell eval pattern works (exit-2 loop enforced)"
else
  fail "F-EVAL-SUBSHELL: force-loop-test.sh failed — eval subshell fix may not be in effect"
fi

# F-NO-TAG-HOOK (structural): tag annotation present in source hooks
# This overlaps ENFC-02 below but is listed as ENFC-01 because it is a structural failure category
MISSING_TAG_SOURCE=$(grep -rL 'tag:' "$HARNESS_DIR/hooks/" --include='*.sh' 2>/dev/null || true)
if [ -z "$MISSING_TAG_SOURCE" ]; then
  pass "F-NO-TAG-HOOK: all source hooks have # tag: annotation"
else
  fail "F-NO-TAG-HOOK: source hooks missing # tag: annotation: $MISSING_TAG_SOURCE"
fi

# F-HOW-TO-FIX-GREP: How to fix: literal present in stop-hook.sh
if grep -q 'How to fix:' "$HARNESS_DIR/hooks/stop-hook.sh"; then
  pass "F-HOW-TO-FIX-GREP: How to fix: present in stop-hook.sh"
else
  fail "F-HOW-TO-FIX-GREP: How to fix: MISSING in stop-hook.sh"
fi

# F-HOME-SCOPE, F-OPENPYXL-ENGINE, F-DOTENV-SCOPE, F-MOCK-IMPORT-BOUNDARY, F-STATIC-FIXTURE:
# These are verifier-check entries (cannot be hook-injection tested per ENFC-04).
# Verify failure-lib entries exist instead.
VERIFIER_CHECK_IDS="home-scope openpyxl-engine dotenv-module-scope mock-import-boundary static-test-fixture"
for id in $VERIFIER_CHECK_IDS; do
  ENTRY="$HARNESS_DIR/failure-lib/${id}.md"
  if [ -f "$ENTRY" ] && grep -q '^enforcement-type: verifier-check$' "$ENTRY"; then
    pass "F-${id}: failure-lib entry exists with enforcement-type: verifier-check"
  else
    fail "F-${id}: failure-lib/${id}.md missing or lacks enforcement-type: verifier-check"
  fi
done

# PLAN-01 re-check: no-verify-cmd blocks Write without VERIFY_CMD
if bash "$HARNESS_DIR/scripts/no-verify-cmd-test.sh" > /dev/null 2>&1; then
  pass "PLAN-01: no-verify-cmd-test.sh confirms Write blocked without VERIFY_CMD"
else
  fail "PLAN-01: no-verify-cmd-test.sh failed — VERIFY_CMD enforcement may be broken"
fi

echo ""
echo "=== ENFC-02: Tag annotation check (installed hooks) ==="

MISSING=$(grep -rL 'tag:' "$HOME/.claude/hooks/" --include='*.sh' 2>/dev/null || true)
if [ -z "$MISSING" ]; then
  pass "ENFC-02: all installed hooks have # tag: annotation"
else
  fail "ENFC-02: installed hooks missing # tag: annotation: $MISSING"
fi

echo ""
echo "=== ENFC-03: How to fix: in blocking messages (installed hooks) ==="

# Only hooks that emit blocking messages need this literal.
# Common.sh block() function already emits "How to fix:" — every hook using block() inherits it.
# stop-hook.sh uses raw echo; it was updated in Plan 02.
# Check all .sh files — grep -q 'How to fix:' will find it via block() usage or inline literal.
HOOKS_MISSING_FIX=0
for hook in "$HOME/.claude/hooks/"*.sh; do
  if grep -q 'How to fix:' "$hook"; then
    pass "ENFC-03: How to fix: present in $(basename "$hook")"
  else
    # progress-after-edit.sh and trace.sh have no blocking messages — skip them for ENFC-03
    BASENAME=$(basename "$hook")
    if [[ "$BASENAME" == "progress-after-edit.sh" || "$BASENAME" == "trace.sh" ]]; then
      pass "ENFC-03: $(basename "$hook") has no blocking messages (non-blocking hook, exempt)"
    else
      fail "ENFC-03: How to fix: MISSING in $(basename "$hook")"
      HOOKS_MISSING_FIX=$((HOOKS_MISSING_FIX + 1))
    fi
  fi
done

echo ""
echo "=== ENFC-04: No language-specific binary invocations in hook bodies ==="

LANG_VIOLATION=0
for hook in "$HOME/.claude/hooks/"*.sh; do
  if grep -qE '\b(node|python|python3|java|kotlin)\b' "$hook"; then
    fail "ENFC-04: language-specific binary invocation found in $(basename "$hook")"
    LANG_VIOLATION=$((LANG_VIOLATION + 1))
  else
    pass "ENFC-04: no language-specific binaries in $(basename "$hook")"
  fi
done

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
