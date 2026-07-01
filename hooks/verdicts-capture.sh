#!/usr/bin/env bash
# verdicts-capture.sh — PostToolUse hook (all tools)
# VERIF-02: captures VERIFIER-VERDICT: blocks from tool_response into .progress/VERDICTS.md
# This is the ONLY write path for .progress/VERDICTS.md (verdict integrity, architecture rule)
# Write/Edit targeting VERDICTS.md is blocked by stub-reject.sh
# tag: architecture
# How to fix: N/A — non-blocking PostToolUse hook; uses emit() only; never calls block() or exit 2
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Full implementation in Wave 1 (05-02-PLAN.md Task 1)
# Scaffold exits 0 so ENFC-02/03/04 checks pass before Wave 1 implementation
exit 0
