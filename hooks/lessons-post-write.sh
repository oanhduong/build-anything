#!/usr/bin/env bash
# lessons-post-write.sh — PostToolUse hook (Write|Edit)
# After writing a file, surfaces relevant 'when: pre-write' lessons by file type.
# Output goes to Claude as inline context — non-blocking, Claude applies if relevant.
# tag: context
set -euo pipefail

LESSONS_DIR="$HOME/.claude/failure-lib"
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
case "$TOOL_NAME" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")
EXT="${BASENAME##*.}"

# Map extension to primary language tag
case "$EXT" in
  py)       LANG="python" ;;
  sh|bash)  LANG="bash"   ;;
  ts|tsx)   LANG="typescript" ;;
  js|jsx)   LANG="javascript" ;;
  *)        exit 0 ;;
esac

# Build the tag set for this file: language + "testing" if it's a test file
FILE_TAGS="$LANG"
case "$BASENAME" in
  test_*|conftest.py|*_test.py|*_test.ts|*.test.ts|*.test.js|*.spec.ts|*.spec.js)
    FILE_TAGS="$FILE_TAGS testing" ;;
esac

HINTS=""
while IFS= read -r f; do
  WHEN=$(grep "^when:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)
  [ "$WHEN" = "pre-write" ] || continue

  LESSON_TAGS=$(grep "^tags:" "$f" 2>/dev/null | head -1 | sed 's/^tags: //' | tr -d '[]' | tr ',' ' ')

  # Check if any lesson tag matches the file's tag set
  MATCHED=false
  for tag in $LESSON_TAGS; do
    tag=$(echo "$tag" | xargs)  # trim whitespace
    if echo " $FILE_TAGS " | grep -qw "$tag"; then
      MATCHED=true
      break
    fi
  done
  [ "$MATCHED" = "true" ] || continue

  ID=$(grep "^id:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)
  SUMMARY=$(awk '/^## What happened/{f=1;next} f && /^[^#[:space:]]/{print;exit}' "$f" 2>/dev/null | cut -c1-100 || true)
  [ -z "$ID" ] && continue

  HINTS+="- ${ID}: ${SUMMARY}"$'\n'
done < <(find "$LESSONS_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null | sort)

if [ -n "$HINTS" ]; then
  printf 'lesson-hints [%s] — check and apply if relevant, or ignore:\n%s' "$FILE_TAGS" "$HINTS"
fi
exit 0
