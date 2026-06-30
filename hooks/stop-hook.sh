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

# LOOP-01: run the verify command (subshell prevents eval "exit N" from exiting hook directly)
if ( eval "$VERIFY_CMD" ) > /tmp/verify-stdout.txt 2> /tmp/verify-stderr.txt; then
  # Verify passed — allow Claude to stop
  emit "Verify passed: ${VERIFY_CMD}"
  # Reset BLOCKED_COUNT on success
  sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: 0/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
  # --- SELF-03 (a) feature-complete trigger: distill on successful completion ---
  bash "$DISTILL_DIR/auto-distill.sh" "$TRACE_LOG" "$PROGRESS_FILE" "$LIB_DIR" >&2 || true
  # --- end SELF-03 (a) ---
  exit 0
else
  # Verify failed — increment counter, block stopping
  NEW_COUNT=$((BLOCKED_COUNT + 1))
  sed -i.bak "s/^BLOCKED_COUNT: .*/BLOCKED_COUNT: ${NEW_COUNT}/" "$PROGRESS_FILE" && rm -f "${PROGRESS_FILE}.bak"
  VERIFY_OUTPUT=$(cat /tmp/verify-stderr.txt /tmp/verify-stdout.txt | head -20)
  echo "Verify failed (attempt ${NEW_COUNT}/${CEILING}): ${VERIFY_CMD}" >&2
  echo "Output: ${VERIFY_OUTPUT}" >&2
  echo "How to fix: examine the verify output above, correct the failing condition, then attempt the task again." >&2
  exit 2
fi
