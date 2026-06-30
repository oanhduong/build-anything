#!/usr/bin/env bash
# retro-e2e-test.sh — Phase 3 done command
# Runs the full self-improve loop end-to-end against isolated mktemp -d fixtures
# (never touches real .progress/ or ~/.claude/failure-lib), asserting the locked
# 8-step sequence from 03-CONTEXT.md, then gate-checks the Stop-hook regression suite.
#
# Covers SELF-01..09:
#   SELF-01 distill blocked without trace (exit 2 + "trace required")
#   SELF-02 candidate carries an evidence: line
#   SELF-03 candidate drafted to pending/ on distill
#   SELF-04 load-lessons surfaces pending notice (structural)
#   SELF-05 duplicate suppression on re-run
#   SELF-06 approved lesson lands in failure-lib + committed
#   SELF-07 prune empty-set (human-verified at Task 2 checkpoint)
#   SELF-08 /retro skill shells out to auto-distill.sh (structural)
#   SELF-09 candidate model-crutch, never architecture
# Plus Stop-hook regression guards (force-loop-test.sh, no-verify-cmd-test.sh).
#
# This is permanent test infra, not a model-crutch.
# tag: architecture

# NOTE: NOT set -e — grep/find no-match returns 1 and must not abort the run.
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }

# CRITICAL: mktemp -d isolation — never touch real .progress/ or ~/.claude/failure-lib.
WORK=$(mktemp -d)

# Isolated failure-lib fixture so dedup (SELF-05) has a real lesson to grep against.
LIB="$WORK/failure-lib"
mkdir -p "$LIB/pending"
cp "$HARNESS_DIR/failure-lib/openpyxl-engine.md" "$LIB/" 2>/dev/null || true

# Isolated progress dir.
PROG="$WORK/.progress"
mkdir -p "$PROG"

echo "=== Phase 3 self-improve loop e2e (isolated: $WORK) ==="

# ---- Step 1: SELF-01 guard — distill blocked without a trace ----
DISTILL_OUT=$(bash "$HARNESS_DIR/scripts/auto-distill.sh" 2>&1); DISTILL_EXIT=$?
if [ "$DISTILL_EXIT" -eq 2 ] && printf '%s' "$DISTILL_OUT" | grep -q 'trace required'; then
  pass "SELF-01: distill blocked without trace (exit 2 + 'trace required')"
else
  fail "SELF-01: expected exit 2 + 'trace required', got exit $DISTILL_EXIT: $DISTILL_OUT"
fi

# ---- Step 2: inject a synthetic hit count (proves >=3 threshold value well-formed) ----
echo '{"openpyxl-engine": 3}' > "$PROG/lesson-hit-counts.json"
HIT=$(jq '."openpyxl-engine"' "$PROG/lesson-hit-counts.json" 2>/dev/null || echo "")
if [ "$HIT" = "3" ]; then
  pass "SELF-03-pre: synthetic hit count well-formed (openpyxl-engine == 3)"
else
  fail "SELF-03-pre: hit count not 3 (got '$HIT')"
fi

# ---- Step 3: inject a synthetic trace with one NEW non-zero error line ----
# New trace format: TIMESTAMP TOOL exit=N TARGET (exit= token before target prevents ambiguity)
printf '%s Bash exit=1 npm-test\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$WORK/trace.log"

# ---- Step 4: SELF-03 — run distill against the fixture, candidate drafted to pending/ ----
bash "$HARNESS_DIR/scripts/auto-distill.sh" "$WORK/trace.log" "$PROG/PROGRESS.md" "$LIB" >/dev/null 2>&1
CAND_COUNT=$(find "$LIB/pending" -name '*.md' -not -name '.gitkeep' 2>/dev/null | wc -l | xargs)
if [ "${CAND_COUNT:-0}" -ge 1 ]; then
  pass "SELF-03: candidate drafted to pending on distill ($CAND_COUNT)"
else
  fail "SELF-03: no candidate drafted to pending/ (count=$CAND_COUNT)"
fi

# Resolve the drafted candidate id for later steps.
CAND_FILE=$(find "$LIB/pending" -name '*.md' -not -name '.gitkeep' 2>/dev/null | head -1)
CAND_ID=$(basename "${CAND_FILE:-}" .md 2>/dev/null || echo "")

# ---- Step 5: SELF-02 — drafted candidate carries an evidence: line ----
if [ -n "$CAND_FILE" ] && grep -q '^evidence:' "$CAND_FILE"; then
  pass "SELF-02: candidate carries evidence"
else
  fail "SELF-02: candidate missing ^evidence: line ($CAND_FILE)"
fi

# ---- Step 6: SELF-05 — duplicate suppression on re-run with the same trace ----
bash "$HARNESS_DIR/scripts/auto-distill.sh" "$WORK/trace.log" "$PROG/PROGRESS.md" "$LIB" >/dev/null 2>&1
CAND_COUNT2=$(find "$LIB/pending" -name '*.md' -not -name '.gitkeep' 2>/dev/null | wc -l | xargs)
if [ "${CAND_COUNT2:-0}" -eq "${CAND_COUNT:-0}" ]; then
  pass "SELF-05: duplicate suppressed on re-run (still $CAND_COUNT2)"
else
  fail "SELF-05: re-run added candidates ($CAND_COUNT -> $CAND_COUNT2)"
fi

# ---- Step 7: SELF-06 — approve simulation (reproduces /retro approve against fixture) ----
# Move pending/<id>.md -> failure-lib/<id>.md, init throwaway git, commit, assert tracked.
APPROVE_OK=0
if [ -n "$CAND_ID" ] && [ -f "$LIB/pending/$CAND_ID.md" ]; then
  mv "$LIB/pending/$CAND_ID.md" "$LIB/$CAND_ID.md"
  git -C "$WORK" init -q 2>/dev/null
  git -C "$WORK" config user.email "test@example.com" 2>/dev/null
  git -C "$WORK" config user.name "retro-e2e" 2>/dev/null
  git -C "$WORK" add -A 2>/dev/null
  git -C "$WORK" commit -qm "test approve" 2>/dev/null || true
  if [ -f "$LIB/$CAND_ID.md" ] && git -C "$WORK" ls-files --error-unmatch "failure-lib/$CAND_ID.md" >/dev/null 2>&1; then
    APPROVE_OK=1
  fi
fi
if [ "$APPROVE_OK" -eq 1 ]; then
  pass "SELF-06: approved lesson lands in failure-lib + committed"
else
  fail "SELF-06: approved lesson not in failure-lib or not tracked ($CAND_ID)"
fi

# ---- Step 8: SELF-09 — candidate model-crutch, never architecture ----
# The approved lesson must be model-crutch tagged; no pending file may carry tag: architecture.
SELF09_OK=1
if [ -n "$CAND_ID" ] && [ -f "$LIB/$CAND_ID.md" ]; then
  grep -q 'model-crutch' "$LIB/$CAND_ID.md" || SELF09_OK=0
else
  SELF09_OK=0
fi
# Any remaining pending file must NOT be architecture-tagged (no pending files left is also fine).
if grep -q 'tag: architecture' "$LIB"/pending/*.md 2>/dev/null; then
  SELF09_OK=0
fi
if [ "$SELF09_OK" -eq 1 ]; then
  pass "SELF-09: candidate model-crutch, never architecture"
else
  fail "SELF-09: candidate not model-crutch or an architecture-tagged candidate exists"
fi

# ---- Structural checks: SELF-04 + SELF-08 ----
if grep -q '/retro approve' "$HARNESS_DIR/hooks/load-lessons.sh"; then
  pass "SELF-04: load-lessons.sh surfaces pending '/retro approve' notice"
else
  fail "SELF-04: load-lessons.sh missing pending '/retro approve' notice"
fi

if grep -q 'auto-distill.sh' "$HARNESS_DIR/skills/retro/SKILL.md"; then
  pass "SELF-08: /retro skill shells out to auto-distill.sh"
else
  fail "SELF-08: skills/retro/SKILL.md does not reference auto-distill.sh"
fi

# ---- Regression guard: Stop hook untouched (VALIDATION.md "Before /gsd:verify-work") ----
echo ""
echo "=== Stop-hook regression guards ==="
if bash "$HARNESS_DIR/scripts/force-loop-test.sh" >/dev/null 2>&1; then
  pass "LOOP regression: force-loop-test.sh green (exit-2 loop enforced)"
else
  fail "LOOP regression: force-loop-test.sh failed — Stop hook may be broken"
fi

if bash "$HARNESS_DIR/scripts/no-verify-cmd-test.sh" >/dev/null 2>&1; then
  pass "PLAN-01 regression: no-verify-cmd-test.sh green (Write blocked without VERIFY_CMD)"
else
  fail "PLAN-01 regression: no-verify-cmd-test.sh failed — VERIFY_CMD enforcement may be broken"
fi

# ---- Cleanup + summary ----
rm -rf "$WORK"

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
