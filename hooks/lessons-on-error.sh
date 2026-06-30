#!/usr/bin/env bash
# lessons-on-error.sh — PostToolUse hook (Bash)
# When a Bash command exits non-zero, surfaces relevant 'when: on-error' lessons.
# Matches using 'error-match' pattern if set, otherwise falls back to tags.
# Output goes to Claude as inline context with the full lesson.
set -euo pipefail

LESSONS_DIR="$HOME/.claude/failure-lib"
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL_NAME" = "Bash" ] || exit 0

EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_response.exit_code // 0')
[ "$EXIT_CODE" != "0" ] || exit 0

# Combine stderr + stdout for pattern matching (lowercased)
ERROR_TEXT=$(echo "$INPUT" | jq -r '(.tool_response.stderr // "") + " " + (.tool_response.stdout // "")' | tr '[:upper:]' '[:lower:]')

MATCHES=""
while IFS= read -r f; do
  WHEN=$(grep "^when:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)
  [ "$WHEN" = "on-error" ] || continue

  # Prefer explicit error-match pattern; fall back to tags
  ERROR_MATCH=$(grep "^error-match:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)

  MATCHED=false
  if [ -n "$ERROR_MATCH" ]; then
    echo "$ERROR_TEXT" | grep -qiE "$ERROR_MATCH" && MATCHED=true
  else
    TAGS=$(grep "^tags:" "$f" 2>/dev/null | head -1 | sed 's/^tags: //' | tr -d '[]' | tr ',' ' ')
    for tag in $TAGS; do
      tag=$(echo "$tag" | xargs)
      if echo "$ERROR_TEXT" | grep -qw "$tag"; then
        MATCHED=true
        break
      fi
    done
  fi
  [ "$MATCHED" = "true" ] || continue

  # --- SELF-03 repeated-failure hit tracking ---
  ID=$(grep "^id:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)
  if [ -n "$ID" ]; then
    HIT_FILE="$PWD/.progress/lesson-hit-counts.json"
    mkdir -p "$PWD/.progress"
    [ -f "$HIT_FILE" ] || echo '{}' > "$HIT_FILE"
    TMP=$(mktemp)
    if jq --arg id "$ID" '.[$id] = ((.[$id] // 0) + 1)' "$HIT_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$HIT_FILE"
    else
      rm -f "$TMP"
    fi
  fi
  # --- end SELF-03 hit tracking ---

  MATCHES+="$(cat "$f")"$'\n\n---\n\n'
done < <(find "$LESSONS_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null | sort)

if [ -n "$MATCHES" ]; then
  printf 'Lesson matched for this error — apply before retrying:\n\n%s' "$MATCHES"
fi
exit 0
