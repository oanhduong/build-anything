---
phase: 06-spec-gate
verified: 2026-07-01T00:00:00Z
status: human_needed
score: 12/13 must-haves verified
re_verification: false
human_verification:
  - test: "Invoke /spec add a hello function to greet.sh in a scratch directory with .progress/PROGRESS.md present"
    expected: |
      1. Skill asks exactly these three questions in one message: "What can go wrong with this task?",
         "What does 'done' look like — how will you know it is working?", "What is the smallest safe change
         that proves the core requirement?"
      2. Skill proposes a draft SPEC.md inline. Replying "looks good" or "yes" does NOT write any file.
      3. Typing the literal word confirm causes .progress/SPEC.md to be written with a non-PENDING
         confirm-token sha256 hex value.
      4. grep '^VERIFY_CMD:' .progress/PROGRESS.md returns a non-empty value derived from the first criterion.
      5. A subsequent Write to any code file passes the gate (exit 0).
      6. Manually editing a criterion in .progress/SPEC.md causes the next Write to be blocked with
         "SPEC.md token invalid".
    why_human: |
      Plan 04 Task 2 was auto-approved ("auto-approve checkpoint:human-verify" per SUMMARY). No live /spec
      invocation was recorded. The confirm gate in SKILL.md is instructional prose — it cannot be verified by
      grep alone. Binary F round-trip proves the token math is correct, but that is not equivalent to running
      the skill interactively through its 3-question interview, confirm gate, and VERIFY_CMD derivation
      flow end to end.
---

# Phase 6: Spec Gate Verification Report

**Phase Goal:** Write/Edit is blocked until `.progress/SPEC.md` exists with a valid `confirm-token:` — a sha256 hash of the acceptance criteria text computed at human-confirm time by the /spec skill. Generator cannot write a token stub-reject accepts without going through /spec and human confirmation.
**Verified:** 2026-07-01T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Write/Edit with no .progress/SPEC.md is blocked exit 2 "SPEC.md absent" | VERIFIED | Binary A PASS; block string confirmed in stub-reject.sh line 33 |
| 2 | Write/Edit when SPEC.md has criteria but no confirm-token is blocked exit 2 "SPEC.md unconfirmed" | VERIFIED | Binary B PASS; block string confirmed in stub-reject.sh line 39 |
| 3 | Write/Edit when SPEC.md criteria modified after confirmation is blocked exit 2 "SPEC.md token invalid" | VERIFIED | Binary C PASS; block string confirmed in stub-reject.sh line 47 |
| 4 | Write targeting .progress/SPEC.md itself is exempt from all three gate checks | VERIFIED | Binary E PASS; exemption guard at stub-reject.sh line 29 |
| 5 | Write/Edit with valid confirmed SPEC.md passes the gate (exit 0) | VERIFIED | Binary D PASS |
| 6 | Token in stub-reject and token in /spec skill are identical pipelines (byte-identical awk+sed+shasum) | VERIFIED | Binary F round-trip PASS (7/7); both files contain identical awk+sed+shasum -a 256 pipeline |
| 7 | Multi-section SPEC.md with ## Verify Command after ## Acceptance Criteria does not bleed into token | VERIFIED | Binary F exercises the awk /^## /{exit} boundary with ## Verify Command section present; PASS |
| 8 | sha256sum (Linux-only) never appears; shasum -a 256 (portable) is used throughout | VERIFIED | grep -c sha256sum returns 0 in stub-reject.sh, SKILL.md, and test-spec-gate.sh |
| 9 | /spec skill contains all three fixed risk questions | VERIFIED | All three present in skills/spec/SKILL.md: "What can go wrong", "What does 'done' look like", "smallest safe change" |
| 10 | /spec skill has literal-confirm gate — only the string "confirm" proceeds; other responses do not | VERIFIED | grep -qF 'literal word confirm' SKILL.md PASS; STEP 3 prose states requirement explicitly |
| 11 | On confirm, /spec derives VERIFY_CMD from first criterion and updates PROGRESS.md via sed (not Edit tool) | VERIFIED | STEP 6 in SKILL.md present; VERIFY_CMD: and sed -i.bak both confirmed |
| 12 | PROGRESS.md-missing guard fires before any file is written | VERIFIED | grep -qF 'PROGRESS.md missing' SKILL.md PASS; guard block in STEP 4 |
| 13 | Live interactive /spec flow: 3-question interview, no write before literal "confirm", SPEC.md written with real token, VERIFY_CMD derived | NEEDS HUMAN | Plan 04 Task 2 was auto-approved, not live-run interactively |

**Score:** 12/13 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `hooks/stub-reject.sh` | 3 SPEC-gate checks after VERDICTS block, before PROGRESS_FILE | VERIFIED | Lines 25-50: exempt guard + 3 checks; ordering invariant confirmed by awk |
| `skills/spec/SKILL.md` | Full /spec skill: 3 questions, confirm gate, token, SPEC.md write, VERIFY_CMD derivation | VERIFIED | 148 lines; all acceptance criteria from plan 03 pass |
| `scripts/test-spec-gate.sh` | Binary A/B/C/D/E/F — all green | VERIFIED | 7/7 pass; executable; 255 lines |
| `~/.claude/hooks/stub-reject.sh` | Deployed with SPEC gate active | VERIFIED | grep -qF "SPEC.md absent" $HOME/.claude/hooks/stub-reject.sh PASS |
| `~/.claude/skills/spec/SKILL.md` | Skill deployed via install.sh glob | VERIFIED | test -f $HOME/.claude/skills/spec/SKILL.md PASS |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `hooks/stub-reject.sh` | `.progress/SPEC.md` | awk+sed+shasum -a 256 re-derives token from ## Acceptance Criteria, compares to stored confirm-token | VERIFIED | Lines 44-45: pipeline present verbatim; COMPUTED_TOKEN vs STORED_TOKEN at line 46 |
| `skills/spec/SKILL.md` | `.progress/SPEC.md` | Write tool (exempt path) with confirm-token computed from written file via canonical pipeline | VERIFIED | STEP 4 Write + STEP 5 token patch; confirm-token pattern confirmed |
| `skills/spec/SKILL.md` | `.progress/PROGRESS.md` | sed -i.bak in-place VERIFY_CMD update using pipe delimiter | VERIFIED | STEP 6 sed pipeline confirmed; pipe delimiter present |
| `scripts/test-spec-gate.sh` | `hooks/stub-reject.sh` | pipe MOCK_JSON to STUB_REJECT, capture exit code + stderr | VERIFIED | STUB_REJECT variable + cd+echo+pipe pattern; 7/7 PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| GATE-01 | 06-03, 06-04 | /spec skill produces .progress/SPEC.md via risk-driven interview; skill proposes draft, human must confirm before spec is written | STRUCTURALLY VERIFIED; interactive path needs human | 3 questions in SKILL.md, literal-confirm gate in STEP 3, no Write before confirm; live test was auto-approved not human-run |
| GATE-02 | 06-01, 06-02 | PreToolUse hook blocks any Write/Edit when .progress/SPEC.md absent | VERIFIED | Binary A PASS; stub-reject.sh Check 1 lines 31-34 |
| GATE-03 | 06-01, 06-02 | PreToolUse hook blocks when SPEC.md has no ## Acceptance Criteria section (malformed spec) | VERIFIED | Check 2 (unconfirmed) subsumes this: without criteria section no valid confirm-token can exist; Binary B tests SPEC.md-with-criteria-but-no-token |
| GATE-04 | 06-03, 06-04 | VERIFY_CMD in PROGRESS.md is derived from and matches criteria in SPEC.md | STRUCTURALLY VERIFIED; interactive path needs human | STEP 6 sed pipeline in SKILL.md; VERIFY_CMD: pattern confirmed; live derivation not human-confirmed |

Note on GATE-03: The REQUIREMENTS.md text says "blocks when SPEC.md has no ## Acceptance Criteria section". The implementation achieves this via the confirm-token requirement — the /spec skill never writes a token without a criteria section, and Check 3 would invalidate any manually-crafted token against an empty-criteria hash. The plan explicitly documents this subsumption.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `hooks/stub-reject.sh` | 63, 70 | Stub marker strings appear in grep pattern and error message text | Info | These lines describe what stub-reject is searching for — not actual stub code; no implementation risk |
| `scripts/test-spec-gate.sh` | 103 | "placeholder" in comment "Patch PENDING placeholder with computed token" | Info | Comment only; no implementation risk |

No blocker anti-patterns found in any phase 6 file.

### Human Verification Required

#### 1. Live /spec Interactive Happy Path

**Test:** In a scratch directory with `.progress/PROGRESS.md` present (run bootstrap-project.sh if needed), invoke `/spec add a hello function to greet.sh`.

**Expected:**
1. Skill asks exactly these three questions in one message: "What can go wrong with this task?", "What does 'done' look like — how will you know it is working?", "What is the smallest safe change that proves the core requirement?"
2. Skill proposes a draft SPEC.md inline and writes nothing. Replying "looks good" does NOT write the file.
3. Typing the literal word `confirm` causes `.progress/SPEC.md` to be written.
4. `grep '^confirm-token:' .progress/SPEC.md` returns a non-empty sha256 hex string (not the string PENDING).
5. `grep '^VERIFY_CMD:' .progress/PROGRESS.md` returns a non-empty value derived from the first criterion.
6. A subsequent Write to any code file passes (no SPEC gate block).
7. Manually editing a criterion line in `.progress/SPEC.md` causes the next Write to be blocked with "SPEC.md token invalid".

**Why human:** Plan 04 Task 2 was marked complete via auto-approve — no live /spec invocation was recorded. The confirm gate in SKILL.md is instructional prose (not a hook), so it cannot be verified by static analysis alone. Binary F round-trip proves the token math is correct, but that is not equivalent to a live skill invocation going through the 3-question interview, confirm gate, and VERIFY_CMD derivation end to end.

### Gaps Summary

No implementation gaps found. The sole outstanding item is a live interactive verification of the /spec skill, which plan 04 bypassed via auto-approve. All automated binary tests (A/B/C/D/E/F), regression suites (32/32 enforcement, 6/6 verifier independence), and preflight (7/7) are green. The hook enforcement is complete and deployed to `~/.claude`. The human verification item is confirmatory, not remedial.

---

_Verified: 2026-07-01T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
