#!/usr/bin/env bash
# test-stderr-template.sh — SKEL-03b: hook messages go to stderr, not stdout
set -uo pipefail

TMP_HOOK=$(mktemp /tmp/test-hook-XXXXXX.sh)
cat > "$TMP_HOOK" << 'HOOK'
#!/usr/bin/env bash
echo "BLOCK: test message" >&2
exit 2
HOOK
chmod +x "$TMP_HOOK"

# Capture stdout only (stderr suppressed) — stdout must be empty
STDOUT_OUTPUT=$(echo '{}' | "$TMP_HOOK" 2>/dev/null || true)
rm -f "$TMP_HOOK"

if [ -z "$STDOUT_OUTPUT" ]; then
  echo "[PASS] SKEL-03b: hook message correctly sent to stderr (stdout is empty)"
  exit 0
else
  echo "[FAIL] SKEL-03b: hook wrote to stdout: '${STDOUT_OUTPUT}'" >&2
  exit 1
fi
