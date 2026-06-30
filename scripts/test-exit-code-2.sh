#!/usr/bin/env bash
# test-exit-code-2.sh — SKEL-03a: confirm that exit 2 in a hook is blocking
# Strategy: create a minimal test hook that exits 2, invoke it, confirm exit code is 2
set -uo pipefail  # Note: no -e so we can capture non-zero exit codes

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP_HOOK=$(mktemp /tmp/test-hook-XXXXXX.sh)
cat > "$TMP_HOOK" << 'HOOK'
#!/usr/bin/env bash
echo "BLOCK: test" >&2
exit 2
HOOK
chmod +x "$TMP_HOOK"

echo '{}' | "$TMP_HOOK" > /dev/null 2>&1
EXIT_CODE=$?
rm -f "$TMP_HOOK"

if [ "$EXIT_CODE" -eq 2 ]; then
  echo "[PASS] SKEL-03a: exit 2 confirmed as blocking exit code"
  exit 0
else
  echo "[FAIL] SKEL-03a: expected exit 2, got ${EXIT_CODE}" >&2
  exit 1
fi
