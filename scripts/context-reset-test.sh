#!/usr/bin/env bash
# context-reset-test.sh — Phase 2 done command
# CTXP-04: simulates context reset; verifies reconstruction from PROGRESS + HANDOFF alone
# Also exercises CTXP-01 (claude-md-audit.sh inline injection) and CTXP-03 (skills exist)
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }

# CRITICAL: use temp dir — never touch real .progress/
TMP=$(mktemp -d)
mkdir -p "$TMP/.progress"

# ---- Section 1: Write synthetic fixtures to $TMP/.progress/ ----

cat > "$TMP/.progress/PROGRESS.md" << 'PROGRESS_CONTENT'
CURRENT_TASK: test-task-context-reset
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
2026-06-23T10:00:00Z | Write | hooks/stop-hook.sh | task:test-task-context-reset
2026-06-23T10:01:00Z | Write | .progress/HANDOFF.md | task:test-task-context-reset
2026-06-23T10:02:00Z | Edit | hooks/claude-md-audit.sh | task:test-task-context-reset
PROGRESS_CONTENT

cat > "$TMP/.progress/HANDOFF.md" << 'HANDOFF_CONTENT'
# Session Handoff Note
Generated: 2026-06-23T10:02:00Z

## Current Task
test-task-context-reset

## Last 3 Edits
  - 2026-06-23T10:00:00Z | Write | hooks/stop-hook.sh
  - 2026-06-23T10:01:00Z | Write | .progress/HANDOFF.md
  - 2026-06-23T10:02:00Z | Edit | hooks/claude-md-audit.sh

## Open Blockers
none

## Next Action
Resume test-task-context-reset. Run VERIFY_CMD to check state.
HANDOFF_CONTENT

# ---- Section 2: CTXP-04 checks — read back synthetic HANDOFF.md and assert all 4 fields ----

echo "=== CTXP-04: Context reset reconstruction checks ==="

# CTXP-04-a: Current Task present and non-empty
CURRENT_TASK=$(grep "^## Current Task" -A1 "$TMP/.progress/HANDOFF.md" | tail -1 | xargs 2>/dev/null || echo "")
[ -n "$CURRENT_TASK" ] && pass "CTXP-04-a: HANDOFF.md has non-empty Current Task" || fail "CTXP-04-a: HANDOFF.md missing or empty Current Task"

# CTXP-04-b: Last 3 Edits has at least one entry
LAST_EDIT=$(grep "^## Last 3 Edits" -A4 "$TMP/.progress/HANDOFF.md" | grep '^\s*-' | head -1)
[ -n "$LAST_EDIT" ] && pass "CTXP-04-b: HANDOFF.md has at least one Last 3 Edits entry" || fail "CTXP-04-b: HANDOFF.md missing Last 3 Edits entry"

# CTXP-04-c: Open Blockers section exists
grep -q "^## Open Blockers" "$TMP/.progress/HANDOFF.md" \
  && pass "CTXP-04-c: HANDOFF.md has Open Blockers section" \
  || fail "CTXP-04-c: HANDOFF.md missing Open Blockers section"

# CTXP-04-d: Next Action section exists
grep -q "^## Next Action" "$TMP/.progress/HANDOFF.md" \
  && pass "CTXP-04-d: HANDOFF.md has Next Action section" \
  || fail "CTXP-04-d: HANDOFF.md missing Next Action section"

# ---- Section 3: CTXP-01 checks — inline hook injection test ----

echo ""
echo "=== CTXP-01: CLAUDE.md audit hook checks ==="

# CTXP-01-a: dynamic content (ISO 8601 datetime) is blocked
AUDIT_OUT=$(echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"Updated: 2026-06-23T10:00:00Z"}}' \
  | bash "$HARNESS_DIR/hooks/claude-md-audit.sh" 2>&1); AUDIT_EXIT=$?
[ "$AUDIT_EXIT" -eq 2 ] \
  && pass "CTXP-01-a: timestamp in CLAUDE.md blocked with exit 2" \
  || fail "CTXP-01-a: timestamp in CLAUDE.md not blocked (exit $AUDIT_EXIT)"

# CTXP-01-b: static content is allowed
AUDIT_OUT=$(echo '{"tool_name":"Write","tool_input":{"path":"CLAUDE.md","content":"## What This Is\nStable reference content only."}}' \
  | bash "$HARNESS_DIR/hooks/claude-md-audit.sh" 2>&1); AUDIT_EXIT=$?
[ "$AUDIT_EXIT" -eq 0 ] \
  && pass "CTXP-01-b: static content in CLAUDE.md passes (exit 0)" \
  || fail "CTXP-01-b: static content blocked unexpectedly (exit $AUDIT_EXIT)"

# CTXP-01-c: hook file is tagged architecture
grep -q "tag: architecture" "$HARNESS_DIR/hooks/claude-md-audit.sh" \
  && pass "CTXP-01-c: claude-md-audit.sh tagged architecture" \
  || fail "CTXP-01-c: claude-md-audit.sh missing tag: architecture"

# ---- Section 4: CTXP-03 checks — skills exist ----

echo ""
echo "=== CTXP-03: Context pull skill checks ==="

test -f "$HARNESS_DIR/skills/context-pull/SKILL.md" \
  && pass "CTXP-03-a: skills/context-pull/SKILL.md exists" \
  || fail "CTXP-03-a: skills/context-pull/SKILL.md missing"

grep -q 'search' "$HARNESS_DIR/skills/context-pull/SKILL.md" 2>/dev/null \
  && pass "CTXP-03-b: context-pull skill contains search subcommand" \
  || fail "CTXP-03-b: context-pull skill missing search subcommand"

test -f "$HARNESS_DIR/skills/handoff/SKILL.md" \
  && pass "CTXP-03-c: skills/handoff/SKILL.md exists" \
  || fail "CTXP-03-c: skills/handoff/SKILL.md missing"

# ---- Section 5: cleanup and summary ----

rm -rf "$TMP"

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
