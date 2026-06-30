#!/usr/bin/env bash
# install.sh — Signature Harness Kit one-step install
# SKEL-01: initializes ~/.claude as a versioned git repo
# ONBD-01: places hooks/, agents/, settings.json into ~/.claude
# ONBD-02: kit runs without GSD; merges alongside existing GSD hooks (never clobber)
# Usage: bash install.sh (from build-anything repo root)
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
HARNESS_SETTINGS="${HARNESS_DIR}/settings.json"

echo "=== Signature Harness Kit Install ==="
echo "Source: ${HARNESS_DIR}"
echo "Target: ${CLAUDE_DIR}"
echo ""

# 1. Create target directories
mkdir -p "${CLAUDE_DIR}/hooks" "${CLAUDE_DIR}/agents" "${CLAUDE_DIR}/skills" "${CLAUDE_DIR}/failure-lib"

# 2. Copy and chmod hook scripts
cp "${HARNESS_DIR}/hooks/"*.sh "${CLAUDE_DIR}/hooks/"
chmod +x "${CLAUDE_DIR}/hooks/"*.sh
echo "[OK] Hook scripts installed and chmod +x"

# 3. Copy verifier agent
cp "${HARNESS_DIR}/agents/verifier.md" "${CLAUDE_DIR}/agents/"
echo "[OK] verifier.md installed"

# 3b. Seed failure-lib — copy lessons that don't already exist (never overwrite local lessons)
# pending/ is runtime-only — the flat *.md glob intentionally excludes it (no recursion into subdirs)
for f in "${HARNESS_DIR}/failure-lib/"*.md; do
  [ -f "$f" ] || continue
  dest="${CLAUDE_DIR}/failure-lib/$(basename "$f")"
  if [ ! -f "$dest" ]; then
    cp "$f" "$dest"
  fi
done
echo "[OK] failure-lib seeded (existing lessons preserved)"

# 3b-2. Copy scripts — full overwrite (scripts are versioned; auto-distill.sh must match hooks)
mkdir -p "${CLAUDE_DIR}/scripts"
cp "${HARNESS_DIR}/scripts/"*.sh "${CLAUDE_DIR}/scripts/"
chmod +x "${CLAUDE_DIR}/scripts/"*.sh
echo "[OK] scripts installed to ${CLAUDE_DIR}/scripts/"

# 3c. Copy skills — full overwrite (skills are versioned; updates should propagate)
# Globs every skills/*/ dir, so new skills (e.g. retro) are picked up with no edit here
for skill_dir in "${HARNESS_DIR}/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  mkdir -p "${CLAUDE_DIR}/skills/${skill_name}"
  cp -r "${skill_dir}." "${CLAUDE_DIR}/skills/${skill_name}/"
done
echo "[OK] skills installed to ${CLAUDE_DIR}/skills/"

# 4. Merge settings.json — append harness hooks to existing arrays (never clobber GSD hooks)
if [ -f "${SETTINGS}" ]; then
  TMP=$(mktemp)
  jq -s '
    .[0] as $existing |
    .[1] as $harness |
    {
      PreToolUse:   (($existing.hooks.PreToolUse   // []) + ($harness.hooks.PreToolUse   // [])),
      PostToolUse:  (($existing.hooks.PostToolUse  // []) + ($harness.hooks.PostToolUse  // [])),
      Stop:         (($existing.hooks.Stop         // []) + ($harness.hooks.Stop         // [])),
      SessionStart: (($existing.hooks.SessionStart // []) + ($harness.hooks.SessionStart // []))
    } as $merged_hooks |
    $existing * $harness | .hooks = $merged_hooks
  ' "${SETTINGS}" "${HARNESS_SETTINGS}" > "${TMP}"
  mv "${TMP}" "${SETTINGS}"
  echo "[OK] settings.json merged (GSD hooks preserved, harness hooks appended)"
else
  cp "${HARNESS_SETTINGS}" "${SETTINGS}"
  echo "[OK] settings.json installed (fresh machine — no existing settings)"
fi

# 5. Initialize trace.log if not present
touch "${CLAUDE_DIR}/trace.log"
echo "[OK] trace.log initialized"

# 6. SKEL-01: ensure ~/.claude is a versioned git repo
if git -C "${CLAUDE_DIR}" rev-parse --git-dir > /dev/null 2>&1; then
  echo "[OK] ~/.claude is already a git repo — committing harness changes"
  git -C "${CLAUDE_DIR}" add -A
  git -C "${CLAUDE_DIR}" commit -m "Update harness install $(date -u +%Y-%m-%dT%H:%M:%SZ)" || echo "[OK] No changes to commit in ~/.claude git repo"
else
  echo "[OK] Initializing ~/.claude as a versioned git repo (SKEL-01)"
  git -C "${CLAUDE_DIR}" init
  git -C "${CLAUDE_DIR}" add -A
  git -C "${CLAUDE_DIR}" commit -m "Initial harness install"
  echo "[OK] ~/.claude git repo initialized with initial harness commit"
fi

# 7. Propagate fork remote — lets /retro approve detect Case A (contribute-back without tmpdir)
SOURCE_ORIGIN=$(git -C "${HARNESS_DIR}" remote get-url origin 2>/dev/null || true)
if echo "${SOURCE_ORIGIN}" | grep -q "build-anything"; then
  if ! git -C "${CLAUDE_DIR}" remote get-url origin > /dev/null 2>&1; then
    git -C "${CLAUDE_DIR}" remote add origin "${SOURCE_ORIGIN}"
    echo "[OK] ~/.claude remote set to ${SOURCE_ORIGIN} (enables lesson contribute-back)"
  fi
fi

echo ""
echo "=== Install complete ==="
echo ""
echo "IMPORTANT: Restart Claude Code for the verifier agent and new skill directories to load."
echo "(Agents and new skill subdirectories require a session restart on first install.)"
echo "If ~/.claude/skills/ already existed, skills are live immediately — no restart needed."
echo ""

# Run preflight to confirm the install is healthy
echo "=== Running preflight checks ==="
bash "${HARNESS_DIR}/preflight.sh"
