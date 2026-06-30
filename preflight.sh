#!/usr/bin/env bash
# preflight.sh — SKEL-03: 7 preflight checks before any real build work begins
# SKEL-07: validates enforcement triad (exit 2, stderr, chmod +x)
# Exit 0 = all 7 checks pass; non-zero = at least one failed (prints [FAIL] for each)
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0

check() {
  local name="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "[PASS] ${name}"
    ((PASS++))
  else
    echo "[FAIL] ${name}" >&2
    ((FAIL++))
  fi
}

# (a) SKEL-03a / SKEL-07: exit-code-2 hook test
check "SKEL-03a: exit-code-2 hook test" bash "${HARNESS_DIR}/scripts/test-exit-code-2.sh"

# (b) SKEL-03b / SKEL-07: stderr-not-stdout template test
check "SKEL-03b: stderr-not-stdout template" bash "${HARNESS_DIR}/scripts/test-stderr-template.sh"

# (c) SKEL-03c / SKEL-07: chmod +x on all hooks installed in ~/.claude/hooks/
check "SKEL-03c: chmod +x on all installed hooks" bash -c 'for f in ~/.claude/hooks/*.sh; do [ -x "$f" ] || { echo "Not executable: $f" >&2; exit 1; }; done; [ -f ~/.claude/hooks/common.sh ]'

# (d) SKEL-03d: bootstrap hook creates PROGRESS.md with correct schema
check "SKEL-03d: PROGRESS schema in place" bash -c '
  TMPPROJECT=$(mktemp -d)
  trap "rm -rf \"$TMPPROJECT\"" EXIT
  (cd "$TMPPROJECT" && bash ~/.claude/hooks/bootstrap-project.sh >/dev/null 2>&1)
  grep -q "CURRENT STATE"  "$TMPPROJECT/.progress/PROGRESS.md" &&
  grep -q "HISTORY LOG"    "$TMPPROJECT/.progress/PROGRESS.md" &&
  grep -q "BLOCKED_COUNT"  "$TMPPROJECT/.progress/PROGRESS.md" &&
  grep -q "VERIFY_CMD"     "$TMPPROJECT/.progress/PROGRESS.md"
'

# (e) SKEL-03e: stub-reject hook fires on pass$/TODO/NotImplemented
check "SKEL-03e: stub-reject hook fires on stubs" bash "${HARNESS_DIR}/scripts/test-stub-reject.sh"

# (f) SKEL-03f: progress-after-edit hook fires on Write/Edit
check "SKEL-03f: progress-after-edit hook fires" bash "${HARNESS_DIR}/scripts/test-progress-hook.sh"

# (g) SKEL-03g: trace hook writes tool name + target + exit code + timestamp
check "SKEL-03g: trace hook writes entry" bash "${HARNESS_DIR}/scripts/test-trace-hook.sh"

echo ""
echo "=== Preflight Results: ${PASS} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
  echo "Fix the [FAIL] items above before proceeding." >&2
  exit 1
fi

echo "All checks passed. Harness is ready."
exit 0
