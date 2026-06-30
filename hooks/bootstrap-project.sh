#!/usr/bin/env bash
# bootstrap-project.sh — SessionStart hook
# Auto-creates .progress/PROGRESS.md if missing so the harness works on first use
# Non-blocking: always exits 0
# tag: architecture
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

PROGRESS_DIR="${PWD}/.progress"
PROGRESS_FILE="${PROGRESS_DIR}/PROGRESS.md"

if [ -f "$PROGRESS_FILE" ]; then
  exit 0
fi

mkdir -p "$PROGRESS_DIR"
cat > "$PROGRESS_FILE" << 'EOF'
CURRENT_TASK: none
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

Not started.

## HISTORY LOG

<!-- Append-only: one line per edit -->
<!-- Format: TIMESTAMP | TOOL | FILE | task:TASK_NAME -->
EOF

emit "Harness: created .progress/PROGRESS.md — set VERIFY_CMD to your task's done criterion before writing code"
exit 0
