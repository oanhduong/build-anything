#!/usr/bin/env bash
# test-spec-gate.sh — Phase 6 spec gate binary exit criterion validation
# Covers: Binary A (SPEC.md absent → blocked), Binary B (SPEC.md unconfirmed → blocked),
#         Binary C (SPEC.md token invalid → blocked), Binary D (valid spec → passes),
#         Binary E (self-write exemption → passes)
# Wave 0: tests start RED (A/B/C fail against unmodified stub-reject) — Wave 1 makes them GREEN
# Exit 0 iff all tests pass
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STUB_REJECT="${HARNESS_DIR}/hooks/stub-reject.sh"

PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }

# ============================================================
# BINARY A: SPEC.md absent → Write blocked "SPEC.md absent"
# GATE-02: any Write/Edit without .progress/SPEC.md must exit 2 with this message
# ============================================================
TMP=$(mktemp -d); mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: spec-gate-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
# Do NOT create $TMP/.progress/SPEC.md — gate must fire on absent file
MOCK='{"tool_name":"Write","tool_input":{"path":"src/foo.sh","content":"echo hi\n"}}'
ERRFILE=$(mktemp)
cd "$TMP"; echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"; EXITCODE=$?; cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"; rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ] && echo "$ERRTXT" | grep -qF "SPEC.md absent"; then
  pass "Binary A: Write blocked 'SPEC.md absent' when .progress/SPEC.md does not exist"
else
  fail "Binary A: exit=$EXITCODE; stderr must contain 'SPEC.md absent'. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
# BINARY B: SPEC.md present with criteria but no confirm-token → blocked "SPEC.md unconfirmed"
# GATE-03: malformed spec (missing token) treated as unconfirmed
# ============================================================
TMP=$(mktemp -d); mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: spec-gate-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
cat > "$TMP/.progress/SPEC.md" << 'SPEC'
---
task: b-test
---

## Acceptance Criteria
1. test -f src/foo.sh
SPEC
MOCK='{"tool_name":"Write","tool_input":{"path":"src/foo.sh","content":"echo hi\n"}}'
ERRFILE=$(mktemp)
cd "$TMP"; echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"; EXITCODE=$?; cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"; rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ] && echo "$ERRTXT" | grep -qF "SPEC.md unconfirmed"; then
  pass "Binary B: Write blocked 'SPEC.md unconfirmed' when confirm-token field absent"
else
  fail "Binary B: exit=$EXITCODE; stderr must contain 'SPEC.md unconfirmed'. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
# BINARY C: valid token present, criteria then tampered → blocked "SPEC.md token invalid"
# GATE-02/03: criteria modification after confirmation must be detected
# ============================================================
TMP=$(mktemp -d); mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: spec-gate-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
SPEC_FILE="$TMP/.progress/SPEC.md"
cat > "$SPEC_FILE" << 'SPEC'
---
task: c-test
confirm-token: PENDING
---

## Acceptance Criteria
1. test -f src/foo.sh
SPEC
# Compute token via CANONICAL pipeline (must match stub-reject's re-derivation in Wave 1)
TOKEN=$(awk '/^## Acceptance Criteria$/{in_sec=1;next} in_sec && /^## /{exit} in_sec{print}' "$SPEC_FILE" \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | shasum -a 256 | cut -d' ' -f1)
# Patch PENDING placeholder with computed token
sed -i.bak "s|^confirm-token: PENDING|confirm-token: ${TOKEN}|" "$SPEC_FILE" && rm -f "${SPEC_FILE}.bak"
# Tamper: alter criteria text WITHOUT recomputing token → hash mismatch
sed -i.bak "s|test -f src/foo.sh|test -f src/CHANGED.sh|" "$SPEC_FILE" && rm -f "${SPEC_FILE}.bak"
MOCK='{"tool_name":"Write","tool_input":{"path":"src/foo.sh","content":"echo hi\n"}}'
ERRFILE=$(mktemp)
cd "$TMP"; echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"; EXITCODE=$?; cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"; rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ] && echo "$ERRTXT" | grep -qF "SPEC.md token invalid"; then
  pass "Binary C: Write blocked 'SPEC.md token invalid' when criteria modified after confirmation"
else
  fail "Binary C: exit=$EXITCODE; stderr must contain 'SPEC.md token invalid'. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
# BINARY D: valid confirmed SPEC.md → Write NOT blocked (happy-path / normalization-consistency guard)
# Guards Pitfall 2: confirms CANONICAL pipeline produces a token stub-reject will accept in Wave 1
# ============================================================
TMP=$(mktemp -d); mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: spec-gate-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
SPEC_FILE="$TMP/.progress/SPEC.md"
cat > "$SPEC_FILE" << 'SPEC'
---
task: d-test
confirm-token: PENDING
---

## Acceptance Criteria
1. test -f src/foo.sh
SPEC
# Compute token via CANONICAL pipeline and patch in (no tampering)
TOKEN=$(awk '/^## Acceptance Criteria$/{in_sec=1;next} in_sec && /^## /{exit} in_sec{print}' "$SPEC_FILE" \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | shasum -a 256 | cut -d' ' -f1)
sed -i.bak "s|^confirm-token: PENDING|confirm-token: ${TOKEN}|" "$SPEC_FILE" && rm -f "${SPEC_FILE}.bak"
# Content: plain echo, no stub markers — only spec gate (or lack thereof) determines outcome
MOCK='{"tool_name":"Write","tool_input":{"path":"src/foo.sh","content":"echo hi\n"}}'
ERRFILE=$(mktemp)
cd "$TMP"; echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"; EXITCODE=$?; cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"; rm -rf "$TMP"

if [ "$EXITCODE" -eq 0 ]; then
  pass "Binary D: Write passes through when SPEC.md has valid confirmed token (happy path)"
else
  fail "Binary D: exit=$EXITCODE; expected exit 0 for valid confirmed spec. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
# BINARY E: Write targeting .progress/SPEC.md itself is exempt from spec gate
# Guards Pitfall 1: /spec must be able to write SPEC.md even when no SPEC.md exists yet
# ============================================================
TMP=$(mktemp -d); mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: spec-gate-test
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG
# Do NOT create SPEC.md — exemption must hold even when the target file is absent
MOCK='{"tool_name":"Write","tool_input":{"path":".progress/SPEC.md","content":"## Acceptance Criteria\n1. x\n"}}'
ERRFILE=$(mktemp)
cd "$TMP"; echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"; EXITCODE=$?; cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"; rm -rf "$TMP"

if [ "$EXITCODE" -eq 0 ]; then
  pass "Binary E: Write to .progress/SPEC.md itself is exempt from spec gate (self-write exemption)"
else
  fail "Binary E: exit=$EXITCODE; expected exit 0 for self-write to .progress/SPEC.md. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
# BINARY F: Multi-section SPEC.md skill-shaped round-trip
# Reproduces skill STEP 4-5 write-then-patch procedure exactly.
# Exercises the awk /^## /{exit} boundary: ## Acceptance Criteria is followed by
# ## Verify Command, so the token must cover only the criteria section.
# ============================================================
TMP=$(mktemp -d); mkdir -p "$TMP/.progress"
cat > "$TMP/.progress/PROGRESS.md" << 'PROG'
CURRENT_TASK: roundtrip
VERIFY_CMD: exit 0
BLOCKED_COUNT: 0

## CURRENT STATE

## HISTORY LOG
PROG

# Step 1: Write SPEC.md with confirm-token: PENDING (skill STEP 4 procedure)
SPEC_FILE_F="$TMP/.progress/SPEC.md"
cat > "$SPEC_FILE_F" << 'SPEC'
---
task: roundtrip-test
confirm-token: PENDING
confirmed-at: 2026-07-01T00:00:00Z
---

## Risk List
- something could go wrong

## Acceptance Criteria
1. test -f src/foo.sh
2. bash scripts/test-spec-gate.sh

## Verify Command
bash scripts/test-spec-gate.sh — exits 0 when all binary tests pass
SPEC

# Step 2: Compute token via CANONICAL pipeline (skill STEP 5 procedure)
# The awk /^## /{exit} boundary stops extraction at "## Verify Command"
TOKEN_F=$(awk '/^## Acceptance Criteria$/{in_sec=1;next} in_sec && /^## /{exit} in_sec{print}' "$SPEC_FILE_F" \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | shasum -a 256 | cut -d' ' -f1)
sed -i.bak "s|^confirm-token: PENDING|confirm-token: ${TOKEN_F}|" "$SPEC_FILE_F" && rm -f "${SPEC_FILE_F}.bak"

# Step 3: Assert Write passes (gate open — valid multi-section SPEC.md with patched token)
MOCK='{"tool_name":"Write","tool_input":{"path":"src/foo.sh","content":"echo hi\n"}}'
ERRFILE=$(mktemp)
cd "$TMP"; echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"; EXITCODE=$?; cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"

if [ "$EXITCODE" -eq 0 ]; then
  pass "Binary F (round-trip accept): multi-section SPEC.md with patched token passes Write gate"
else
  fail "Binary F (round-trip accept): exit=$EXITCODE; expected exit 0 for valid skill-shaped SPEC.md. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# Step 4: Tamper with criteria and assert Write is blocked
sed -i.bak "s|test -f src/foo.sh|test -f src/TAMPERED.sh|" "$SPEC_FILE_F" && rm -f "${SPEC_FILE_F}.bak"
ERRFILE=$(mktemp)
cd "$TMP"; echo "$MOCK" | "$STUB_REJECT" >/dev/null 2>"$ERRFILE"; EXITCODE=$?; cd - >/dev/null
ERRTXT=$(cat "$ERRFILE"); rm -f "$ERRFILE"; rm -rf "$TMP"

if [ "$EXITCODE" -eq 2 ] && echo "$ERRTXT" | grep -qF "SPEC.md token invalid"; then
  pass "Binary F (tamper detect): Write blocked after criteria tampering in multi-section SPEC.md"
else
  fail "Binary F (tamper detect): exit=$EXITCODE; expected exit 2 with 'SPEC.md token invalid'. Got: '$(echo "$ERRTXT" | head -3)'"
fi

# ============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
