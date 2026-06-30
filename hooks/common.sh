#!/usr/bin/env bash
# common.sh — shared hook library for Signature Harness Kit
# Usage: source "$(dirname "$0")/common.sh" at top of every hook script
# SKEL-06: canonical exit-2 blocking, stderr emission, trace writing
# tag: architecture

set -euo pipefail

# block(reason, fix_instruction)
# Emits to stderr, exits 2 (BLOCKING per Claude Code hook semantics)
# SKEL-07: exit 2 is the ONLY blocking exit code; exit 1 is non-blocking
block() {
  local reason="${1:-unspecified}"
  local fix="${2:-no fix instruction provided}"
  echo "BLOCK: ${reason}" >&2
  echo "How to fix: ${fix}" >&2
  exit 2
}

# emit(message)
# Non-blocking stderr message (does not exit)
emit() {
  echo "${1}" >&2
}

# trace_write(tool_name, target, exit_code)
# Appends one line to ~/.claude/trace.log
# Format: TIMESTAMP TOOL exit=N TARGET
# exit=N comes before TARGET so the exit code is never ambiguous with numeric target content.
# SKEL-04 / trace hook support
trace_write() {
  local tool="${1:-unknown}"
  local target="${2:--}"
  local exit_code="${3:-0}"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "${timestamp} ${tool} exit=${exit_code} ${target}" >> "${HOME}/.claude/trace.log"
}
