# Phase 6: Spec Gate - Context

**Gathered:** 2026-07-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Block Write/Edit until `.progress/SPEC.md` exists with a valid `confirm-token:` — a sha256 hash of the `## Acceptance Criteria` section text computed at human-confirm time by the new `/spec` skill. The generator cannot write a token that stub-reject accepts without going through `/spec` and explicit human confirmation.

Two deliverables:
1. `skills/spec.md` — `/spec` skill: risk-driven interview → propose draft → wait for human "confirm" → compute token → write SPEC.md → derive VERIFY_CMD
2. `hooks/stub-reject.sh` — 3 new PreToolUse checks: SPEC absent, SPEC unconfirmed (no token), SPEC tampered (token mismatch)

Scope OUT: verifier subagent invocation (Phase 5), criterion-tagged distillation (Phase 7), BLOCKED-REPORT.md (Phase 8), auto-confirm of any kind.

</domain>

<decisions>
## Implementation Decisions

### /spec skill interview structure
- 3 fixed risk-driven questions (not adaptive):
  1. What can go wrong with this task?
  2. What does "done" look like — how will you know it's working?
  3. What is the smallest safe change that proves the core requirement?
- Claude proposes a draft SPEC.md based on answers (does NOT write it yet)
- User must type the literal word "confirm" before the spec is written
- If user makes edits or asks changes, incorporate and re-propose — still no write until "confirm"

### SPEC.md format
- YAML frontmatter with exactly: `task:`, `confirm-token:`, `confirmed-at:` fields
- `## Risk List` section — bullet list of what can go wrong (from interview Q1)
- `## Acceptance Criteria` section — numbered list, at least one criterion (from interview Q2/Q3)
- `## Verify Command` note — prose line explaining what VERIFY_CMD checks (not the command itself — that goes in PROGRESS.md)
- confirm-token is written only at confirm time, NOT in the draft shown to user

### confirm-token computation
- Algorithm: `shasum -a 256` of the exact text content of the `## Acceptance Criteria` section (from `## Acceptance Criteria\n` to the next `##` heading or EOF)
- Platform: `shasum -a 256` (macOS/Linux compatible; do NOT use `sha256sum` which is Linux-only)
- The /spec skill computes this in bash after human types "confirm"
- stub-reject re-derives the same sha256 at Write/Edit time and compares to stored token
- Any modification to criteria text after confirmation → sha256 mismatch → blocked

### VERIFY_CMD derivation
- At confirm time, /spec derives VERIFY_CMD from the first (or simplest mechanical) criterion in `## Acceptance Criteria`
- Skill proposes the derived VERIFY_CMD to the user as part of the confirm message
- Writes it to PROGRESS.md `VERIFY_CMD:` field — replaces whatever was there
- VERIFY_CMD is a mechanical pre-filter (cheap bash check), NOT a semantic correctness oracle — Phase 5 architecture

### stub-reject check ordering
New checks inserted AFTER the VERDICTS.md path-block and BEFORE PLAN-01:
1. FILE_PATH_EARLY → VERDICTS.md path-specific block (existing — security boundary, cheapest)
2. **NEW** SPEC.md absent → `block "SPEC.md absent" "Run /spec to create a human-confirmed spec before writing code"`
3. **NEW** SPEC.md present, no `confirm-token:` field → `block "SPEC.md unconfirmed" "Run /spec and type 'confirm' to generate the confirm-token"`
4. **NEW** SPEC.md present, confirm-token mismatch → `block "SPEC.md token invalid — criteria modified after confirmation" "Re-run /spec to confirm the updated criteria"`
5. PLAN-01: VERIFY_CMD empty (existing — will rarely fire after Phase 6 since /spec sets it, but kept as belt-and-suspenders)
6. Stub patterns (existing)

### No backward-compat escape
- Gate is unconditional: "no bypass, no override, no fallback to VERIFY_CMD alone" (ROADMAP architecture rule)
- Every Write/Edit in a Phase-6+ session requires SPEC.md with valid token
- Pre-Phase-5 sessions that don't set CURRENT_TASK or SPEC.md will be blocked — this is intentional
- The gate's purpose IS the friction: it forces /spec before execution on every task

### Claude's Discretion
- Exact wording of the 3 interview questions (ROADMAP gives intent, not verbatim text)
- How to extract the `## Acceptance Criteria` section text in bash for sha256 (awk or sed — either works)
- Whether to show the derived VERIFY_CMD inline in the confirm message or separately
- How /spec handles blank PROGRESS.md (create it, or error with instructions)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase specification
- `.planning/ROADMAP.md` §Phase 6 (lines ~109–162) — Full scope IN/OUT, confirm-token mechanism, binary exit criteria A/B/C, real-run proofs, new architecture rules
- `.planning/REQUIREMENTS.md` §Spec + Plan Gate (A2 + B) — GATE-01, GATE-02, GATE-03, GATE-04 requirement text

### Existing code to modify
- `hooks/stub-reject.sh` — current hook; Phase 6 inserts 3 SPEC.md checks after VERDICTS.md path-block; read existing block() call pattern and ordering
- `hooks/common.sh` — `block()` and `emit()` utilities; all new hook logic uses these
- `.progress/PROGRESS.md` — VERIFY_CMD field that /spec will update at confirm time

### Reference implementations for patterns
- `hooks/progress-after-edit.sh` — reference for PostToolUse hook structure (INPUT=$(cat), jq field extraction, file writes)
- `skills/retro` — reference for existing skill file format (how a /skill is structured in this codebase)
- `hooks/verdicts-capture.sh` — reference for the "scan tool_response and write to .progress/ file" pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `hooks/common.sh` `block()`: `block "reason" "fix instruction"` → stderr + exit 2; all 3 new SPEC.md checks use this
- `hooks/common.sh` `emit()`: non-blocking stderr; use to confirm token write in /spec skill
- Existing `FILE_PATH_EARLY` extraction pattern in stub-reject.sh: `$(echo "$INPUT" | jq -r '.tool_input.path // .tool_input.file_path // empty')` — reuse same pattern for SPEC.md path reads

### Established Patterns
- Hook file header: `#!/usr/bin/env bash`, `set -euo pipefail`, `source "$(dirname "${BASH_SOURCE[0]}")/common.sh"`
- PreToolUse blocks: check TOOL_NAME first, exit 0 if not target tool; then check conditions; block() on fail
- PROGRESS.md field extraction: `grep "^FIELDNAME:" "$PROGRESS_FILE" | cut -d: -f2- | xargs`
- In-place PROGRESS.md edit: `sed -i.bak 's/^VERIFY_CMD:.*/VERIFY_CMD: new_val/' "$PROGRESS_FILE" && rm "${PROGRESS_FILE}.bak"`
- Skill format: `.md` file at `skills/<skill-name>` (no extension in directory, open with Read to see retro skill pattern)

### Integration Points
- `stub-reject.sh` line ~20: insert 3 SPEC.md checks AFTER `FILE_PATH_EARLY` + VERDICTS.md block, BEFORE `PROGRESS_FILE` + PLAN-01 block
- `/spec` skill writes `.progress/SPEC.md` (new file, no existing target)
- `/spec` skill updates `.progress/PROGRESS.md` VERIFY_CMD field (modifies existing file in-place)
- `install.sh` must deploy `skills/spec.md` to `~/.claude/skills/spec` (check existing install.sh patterns for skills deployment)

</code_context>

<specifics>
## Specific Ideas

- ROADMAP specifies confirm-token exactly: sha256 of `## Acceptance Criteria` section text. The section boundary is from the `## Acceptance Criteria` line (inclusive) to the next `##` heading line (exclusive) or EOF. Strip leading/trailing whitespace from the extracted block for stable hashing.
- The /spec skill must NOT use any auto-approve path. The literal text "confirm" from the user is the gate. Any other response (including "yes", "ok", "looks good") should not trigger the write.
- Binary exit criterion A: Remove SPEC.md → Write → blocked "SPEC.md absent". Binary exit criterion B: SPEC.md with criteria but no confirm-token → Write → blocked "SPEC.md unconfirmed". Binary exit criterion C: SPEC.md with valid token, then edit criteria → Write → blocked "SPEC.md token invalid".
- Real-run happy path: `/spec` → 3 questions → draft shown → user types "confirm" → skill computes sha256, writes SPEC.md with token, updates PROGRESS.md → Write passes through → Phase 5 verifier reads criteria from this SPEC.md.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. ROADMAP scope OUT items (distillation, BLOCKED-REPORT) are Phase 7/8.

</deferred>

---

*Phase: 06-spec-gate*
*Context gathered: 2026-07-01*
