#!/usr/bin/env bash
# auto-distill.sh — trace-grounded lesson distiller (Phase 3 engine)
# Single source of truth for distillation logic. Both callers (the Stop hook
# threshold path in Plan 02, and /retro run in Plan 03) shell out to this script.
#
# Usage: auto-distill.sh <trace-file> [progress-file] [failure-lib-dir]
#
# SELF-01: blocks (exit 2) if no readable trace file is given ("trace required").
# SELF-02: every drafted candidate carries an evidence: line (verbatim trace entry).
# SELF-03: threshold-callable; draws candidates directly from trace evidence.
# SELF-05: suppresses ids already present in failure-lib/ (and pending/).
# SELF-09: candidates land in pending/ ONLY, always model-crutch, NEVER architecture.
# ENFC-04: language-agnostic — no per-stack interpreter/runtime invocations.
#
# This script is permanent infra, not a model-crutch.
# tag: architecture

# NOTE: NOT set -e — grep/find no-match returns 1 and must not abort the run
# (Pitfall 2 in RESEARCH.md).
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../hooks/common.sh"

# --- Argument contract ---
TRACE_FILE="${1:-}"

# SELF-01: a readable trace file is mandatory. Message MUST contain "trace required".
if [ -z "$TRACE_FILE" ] || [ ! -f "$TRACE_FILE" ]; then
  block "auto-distill requires a trace file" "pass a readable trace.log path as argument 1 — trace required"
fi

PROGRESS_FILE="${2:-$PWD/.progress/PROGRESS.md}"
LIB_DIR="${3:-$HOME/.claude/failure-lib}"
PENDING_DIR="${LIB_DIR}/pending"
mkdir -p "$PENDING_DIR"

# Model-version token for model-crutch tagging (SELF-09).
MODEL_VERSION="${CLAUDE_MODEL:-claude-sonnet-4-6}"

# --- Step 1: extract candidate error lines ---
# New trace format (written by trace.sh): TIMESTAMP TOOL exit=N TARGET
# The exit=N token is at position 3 (index 2), making it unambiguous.
# Old-format lines (TIMESTAMP TOOL TARGET, no exit= token) are silently skipped.
ERROR_LINES=$(grep -n ' exit=[1-9]' "$TRACE_FILE" 2>/dev/null || true)

if [ -z "$ERROR_LINES" ]; then
  emit "0 new candidates — no non-zero exit lines in trace"
  exit 0
fi

N=0
while IFS= read -r numbered_line; do
  [ -n "$numbered_line" ] || continue

  # Strip the "lineno:" prefix added by grep -n.
  raw_line="${numbered_line#*:}"

  # Tokenize: TIMESTAMP TOOL exit=N TARGET...
  # token[0]=timestamp, token[1]=tool, token[2]=exit=N, token[3..]=target
  read -r -a toks <<< "$raw_line"
  tok_count=${#toks[@]}
  [ "$tok_count" -ge 3 ] || continue

  TOOL="${toks[1]}"
  EXIT_FIELD="${toks[2]}"  # "exit=N"

  # Skip old-format lines that lack the exit=N token.
  [[ "$EXIT_FIELD" =~ ^exit=[0-9]+$ ]] || continue
  EXIT_CODE="${EXIT_FIELD#exit=}"
  # Only process non-zero exits (belt-and-suspenders — grep above already filters).
  [ "$EXIT_CODE" != "0" ] || continue

  # TARGET = everything after the exit=N token.
  TARGET=""
  for ((i = 3; i < tok_count; i++)); do
    if [ -z "$TARGET" ]; then
      TARGET="${toks[$i]}"
    else
      TARGET="${TARGET} ${toks[$i]}"
    fi
  done
  [ -n "$TARGET" ] || TARGET="-"

  # --- Step 2: derive a stable candidate id from TOOL + TARGET ---
  # lowercase, collapse non-alphanumerics to single dashes, trim, cap ~50 chars.
  id_src="${TOOL} ${TARGET}"
  candidate_id=$(printf '%s' "$id_src" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  candidate_id="auto-${candidate_id}"
  candidate_id="${candidate_id:0:50}"
  candidate_id=$(printf '%s' "$candidate_id" | sed -E 's/-+$//')

  # --- Step 3: SELF-05 duplicate suppression ---
  # Grep failure-lib/ ONLY (never pending/) for an existing committed id.
  if grep -rlq "^id: ${candidate_id}\$" "${LIB_DIR}"/*.md 2>/dev/null; then
    emit "skip ${candidate_id}: already in failure-lib"
    continue
  fi
  # Also skip if already queued in pending/ (avoid stacking within/across runs).
  [ -f "${PENDING_DIR}/${candidate_id}.md" ] && continue

  # --- Step 4: SELF-02 + SELF-09 — draft the candidate ---
  # SELF-09: candidates go to pending/ ONLY — never failure-lib/ directly,
  # never architecture-tagged. Tag is ALWAYS model-crutch <model-version>.
  ERROR_MATCH=$(printf '%s' "$TARGET" | tr '[:upper:]' '[:lower:]')
  DRAFTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  cat > "${PENDING_DIR}/${candidate_id}.md" <<EOF
---
id: ${candidate_id}
tags: [model-crutch ${MODEL_VERSION}, auto-distilled]
when: on-error
error-match: ${ERROR_MATCH}
evidence: ${raw_line}
---

## What happened
Command via ${TOOL} on ${TARGET} exited ${EXIT_CODE} (non-zero). Auto-distilled from trace evidence on ${DRAFTED_AT}.

## How to avoid
Review the failing command before retrying; confirm the fix removes the non-zero exit. (Candidate — refine before approving via /retro approve.)
EOF

  N=$((N + 1))
done <<< "$ERROR_LINES"

# --- Step 6: report ---
if [ "$N" -gt 0 ]; then
  emit "${N} candidate(s) drafted to ${PENDING_DIR}"
else
  emit "0 new candidates — all patterns already in failure-lib"
fi
exit 0
