#!/usr/bin/env bash
# stop-hook.sh — Stop hook
# LOOP-01: runs VERIFY_CMD on session stop; exit 2 if fails → Claude must continue
# LOOP-02: bounded by BLOCKED_COUNT in PROGRESS; ceiling = 3; writes BLOCKED on ceiling
# CRITICAL: stop_hook_active guard — MUST check this first to prevent session wedge
# tag: architecture
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DISTILL_DIR="$(dirname "${BASH_SOURCE[0]}")/../scripts"
TRACE_LOG="${HOME}/.claude/trace.log"
LIB_DIR="${HOME}/.claude/failure-lib"

INPUT=$(cat)

# CRITICAL GUARD (prevents infinite wedge):
# When Claude is already in forced continuation from a prior exit-2 block,
# stop_hook_active = true. In that case we MUST exit 0 (allow stop) to avoid wedge.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Locate PROGRESS file — use cwd from hook input, fallback to PWD
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
CWD="${CWD:-$PWD}"
PROGRESS_FILE="${CWD}/.progress/PROGRESS.md"

# If no PROGRESS file, allow stop (not in a harness-driven task context)
if [ ! -f "$PROGRESS_FILE" ]; then
  exit 0
fi

# --- SELF-03 (b) repeated-failure trigger ---
HIT_FILE="${CWD}/.progress/lesson-hit-counts.json"
if [ -f "$HIT_FILE" ]; then
  MAX_HITS=$(jq -r '[.[]] | max // 0' "$HIT_FILE" 2>/dev/null || echo 0)
  if [ "${MAX_HITS:-0}" -ge 3 ]; then
    bash "$DISTILL_DIR/auto-distill.sh" "$TRACE_LOG" "$PROGRESS_FILE" "$LIB_DIR" >&2 || true
    # Reset the triggering counts so distill does not re-fire every Stop (Pitfall 4)
    TMP=$(mktemp)
    if jq 'map_values(if . >= 3 then 0 else . end)' "$HIT_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$HIT_FILE"
    else
      rm -f "$TMP"
    fi
  fi
fi
# --- end SELF-03 (b) ---

# ---- CTXP-02: Write HANDOFF.md unconditionally on every session stop ----
# This block runs BEFORE the VERIFY_CMD check so exploratory sessions (no VERIFY_CMD)
# and blocked tasks still produce a handoff note for the next session.
HANDOFF_FILE="${CWD}/.progress/HANDOFF.md"
HANDOFF_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CURRENT_TASK_VAL=$(grep "^CURRENT_TASK:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "none")
# Last 3 edits from HISTORY LOG (lines starting with a timestamp — format: YYYY-MM-DDTHH:MM:SSZ)
LAST_3_EDITS=$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$PROGRESS_FILE" 2>/dev/null | tail -3 | sed 's/^/  - /' || echo "  - (none)")
[ -z "$LAST_3_EDITS" ] && LAST_3_EDITS="  - (none)"
OPEN_BLOCKERS=$(grep "^BLOCKED:" "$PROGRESS_FILE" 2>/dev/null | tail -1 | cut -d: -f2- | xargs 2>/dev/null || echo "none")
[ -z "$OPEN_BLOCKERS" ] && OPEN_BLOCKERS="none"
NEXT_ACTION="Resume CURRENT_TASK: ${CURRENT_TASK_VAL}. Run VERIFY_CMD to check state."

TMP_HANDOFF=$(mktemp)
cat > "$TMP_HANDOFF" << HANDOFF_CONTENT
# Session Handoff Note
Generated: ${HANDOFF_TIMESTAMP}

## Current Task
${CURRENT_TASK_VAL}

## Last 3 Edits
${LAST_3_EDITS}

## Open Blockers
${OPEN_BLOCKERS}

## Next Action
${NEXT_ACTION}
HANDOFF_CONTENT
mv "$TMP_HANDOFF" "$HANDOFF_FILE"
emit "CTXP-02: HANDOFF.md written to ${HANDOFF_FILE}"
# ---- end CTXP-02 ----

# Read VERIFY_CMD — if empty, allow stop (no active task with verify requirement)
VERIFY_CMD=$(grep "^VERIFY_CMD:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "")
if [ -z "$VERIFY_CMD" ]; then
  exit 0
fi

# Read BLOCKED_COUNT
BLOCKED_COUNT=$(grep "^BLOCKED_COUNT:" "$PROGRESS_FILE" 2>/dev/null | cut -d: -f2- | xargs 2>/dev/null || echo "0")
BLOCKED_COUNT=${BLOCKED_COUNT:-0}

# LOOP-02: ceiling check — if at or above ceiling, write BLOCKED and allow stop
CEILING=3
if [ "$BLOCKED_COUNT" -ge "$CEILING" ]; then
  # Update CURRENT STATE to show BLOCKED status
  TMP=$(mktemp)
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  awk -v ts="$TIMESTAMP" -v cmd="$VERIFY_CMD" -v count="$BLOCKED_COUNT" '
    /^## CURRENT STATE$/ {
      print
      print ""
      print "BLOCKED: ceiling reached (" count "/" count " attempts)"
      print "Verify command: " cmd
      print "Timestamp: " ts
      print "Action required: Human or stronger model must resolve this task."
      print ""
      in_current=1
      next
    }
    /^## HISTORY LOG$/ { in_current=0 }
    in_current { next }
    { print }
  ' "$PROGRESS_FILE" > "$TMP"
  mv "$TMP" "$PROGRESS_FILE"
  # Append BLOCKED entry to HISTORY LOG
  echo "${TIMESTAMP} | BLOCKED | ceiling-reached | verify:${VERIFY_CMD}" >> "$PROGRESS_FILE"
  emit "LOOP-02: iteration ceiling reached (${BLOCKED_COUNT}/${CEILING}). Task marked BLOCKED in PROGRESS. Escalate to human."
  exit 0  # Allow stop — human must intervene
fi

# LOOP-01: run the verify command as Gate 1 pre-filter (subshell prevents eval exit N from exiting hook)
# tag: architecture — VERIFY_CMD is a mechanical pre-filter only, not a correctness oracle
if ( eval "$VERIFY_CMD" ) > /tmp/verify-stdout.txt 2> /tmp/verify-stderr.txt; then
  emit "Verify passed (Gate 1): ${VERIFY_CMD}"

  # --- VERIF-03: Gate 2 — criterion check via SPEC.md + VERDICTS.md ---
  # Only activates if SPEC.md exists with ## Acceptance Criteria section.
  # If SPEC.md absent: VERIFY_CMD alone is sufficient (Phase 5 fallback; Phase 6 will gate SPEC.md presence).
  SPEC_FILE="${CWD}/.progress/SPEC.md"
  if [ ! -f "$SPEC_FILE" ] || ! grep -q "^## Acceptance Criteria$" "$SPEC_FILE"; then
    # No SPEC.md or no criteria section — current behavior (allow stop on VERIFY_CMD pass)
    sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: 0/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
    # --- SELF-03 (a) feature-complete trigger: distill on successful completion ---
    bash "$DISTILL_DIR/auto-distill.sh" "$TRACE_LOG" "$PROGRESS_FILE" "$LIB_DIR" >&2 || true
    # --- end SELF-03 (a) ---
    exit 0
  fi

  # SPEC.md present with ## Acceptance Criteria section — read criterion list
  # Strips blank lines, ## section headers, and markdown list prefix (- or *)
  # Result: bare criterion text that matches what verifier received and what's in VERDICTS.md
  CRITERIA=()
  while IFS= read -r line; do
    [ -n "$line" ] && CRITERIA+=("$line")
  done < <(awk '/^## Acceptance Criteria$/ { in_sec=1; next } in_sec && /^## / { exit } in_sec { print }' \
             "$SPEC_FILE" \
           | sed 's/^[[:space:]]*[-*][[:space:]]*//' \
           | sed 's/^[[:space:]]*//' \
           | sed 's/[[:space:]]*$//' \
           || true)

  # Empty criteria section: treat as no criteria (exit 0 — graceful)
  if [ "${#CRITERIA[@]}" -eq 0 ]; then
    sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: 0/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
    bash "$DISTILL_DIR/auto-distill.sh" "$TRACE_LOG" "$PROGRESS_FILE" "$LIB_DIR" >&2 || true
    exit 0
  fi

  VERDICTS_FILE="${CWD}/.progress/VERDICTS.md"
  ALL_PASS=1
  STATUS_LINES=""

  for criterion in "${CRITERIA[@]}"; do
    [ -z "$criterion" ] && continue
    # Check VERDICTS.md for this criterion — last-match semantics (most recent verdict wins)
    # If verifier was run twice for same criterion, last run's verdict is authoritative
    VERDICT_STATUS=$(awk -v crit="CRITERION: ${criterion}" '
      BEGIN { in_block=0; last_verdict="not yet verified" }
      /^--- / { in_block=0 }
      $0 == crit { in_block=1; next }
      in_block && /^VERDICT: PASS$/ { last_verdict="PASS"; in_block=0; next }
      in_block && /^VERDICT: FAIL$/ { last_verdict="FAIL"; in_block=0; next }
      END { print last_verdict }
    ' "$VERDICTS_FILE" 2>/dev/null || echo "not yet verified")

    STATUS_LINES="${STATUS_LINES}  [${VERDICT_STATUS}] ${criterion}\n"
    if [ "$VERDICT_STATUS" != "PASS" ]; then
      ALL_PASS=0
    fi
  done

  if [ "$ALL_PASS" -eq 0 ]; then
    echo "Criterion gate (Gate 2): not all acceptance criteria have VERDICT: PASS in VERDICTS.md" >&2
    echo "Per-criterion status:" >&2
    printf "%b" "$STATUS_LINES" >&2
    echo "How to fix: invoke the verifier subagent for each criterion marked 'not yet verified' or 'FAIL'." >&2
    echo "  The verifier is at ~/.claude/agents/verifier.md — invoke it synchronously (no run_in_background)." >&2
    echo "  Example: Task the verifier: \"Run criterion: <criterion text>\"" >&2
    echo "  After verifier runs, verdicts-capture.sh appends VERDICT to .progress/VERDICTS.md automatically." >&2
    NEW_COUNT=$((BLOCKED_COUNT + 1))
    sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: ${NEW_COUNT}/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
    exit 2
  fi

  # Gate 2 passed: all criteria have VERDICT: PASS
  emit "Criterion gate (Gate 2): all ${#CRITERIA[@]} criteria PASS"
  sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: 0/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
  # --- SELF-03 (a) feature-complete trigger: distill on successful completion (both gates passed) ---
  bash "$DISTILL_DIR/auto-distill.sh" "$TRACE_LOG" "$PROGRESS_FILE" "$LIB_DIR" >&2 || true
  # --- end SELF-03 (a) ---
  exit 0
  # --- end VERIF-03 two-gate flow ---

else
  # Gate 1 failed: VERIFY_CMD pre-filter failed — increment counter, block stopping (UNCHANGED)
  NEW_COUNT=$((BLOCKED_COUNT + 1))
  sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: ${NEW_COUNT}/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
  VERIFY_OUTPUT=$(cat /tmp/verify-stderr.txt /tmp/verify-stdout.txt | head -20)
  echo "Verify failed (attempt ${NEW_COUNT}/${CEILING}): ${VERIFY_CMD}" >&2
  echo "Output: ${VERIFY_OUTPUT}" >&2
  echo "How to fix: examine the verify output above, correct the failing condition, then attempt the task again." >&2
  exit 2
fi
