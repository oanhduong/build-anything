#!/usr/bin/env bash
# load-lessons.sh — SessionStart hook
# Injects a compact lesson index into session context.
# Full lessons at ~/.claude/failure-lib/<id>.md — read them when the index hints at relevance.
# Non-blocking: always exits 0
# tag: context
set -euo pipefail

LESSONS_DIR="$HOME/.claude/failure-lib"

LESSON_COUNT=$(find "$LESSONS_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null | wc -l | xargs)
if [ "$LESSON_COUNT" -eq 0 ]; then
  exit 0
fi

INDEX="## Accumulated lessons (failure-lib)

When you hit an error, get stuck, or recognize a familiar pattern — scan this index and read the full lesson file if one applies. Full detail at: ~/.claude/failure-lib/<id>.md

"

while IFS= read -r f; do
  ID=$(grep "^id:" "$f" 2>/dev/null | head -1 | cut -d: -f2- | xargs || true)
  TAGS=$(grep "^tags:" "$f" 2>/dev/null | head -1 | sed 's/^tags: //' | tr -d '[]' | xargs || true)
  # First non-blank, non-heading line after "## What happened"
  SUMMARY=$(awk '/^## What happened/{f=1;next} f && /^[^#[:space:]]/{print;exit}' "$f" 2>/dev/null | cut -c1-120 || true)

  [ -z "$ID" ] && continue
  [ -z "$SUMMARY" ] && continue

  LINE="- **${ID}**"
  [ -n "$TAGS" ] && LINE+=" [${TAGS}]"
  LINE+=": ${SUMMARY}"
  INDEX+="${LINE}"$'\n'
done < <(find "$LESSONS_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null | sort)

PENDING_COUNT=$(find "$LESSONS_DIR/pending" -name "*.md" -not -name ".gitkeep" 2>/dev/null | wc -l | xargs)
if [ "${PENDING_COUNT:-0}" -gt 0 ]; then
  INDEX+=$'\n'"_${PENDING_COUNT} lesson(s) pending — run \`/retro approve\` to review._"$'\n'
fi

jq -n --arg prompt "$INDEX" '{"prompt": $prompt}'
exit 0
