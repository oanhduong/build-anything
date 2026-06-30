#!/usr/bin/env bash
# check-retrieval-gate.sh — Phase 4 RETR-01 hard gate.
#
# Runs a FRESH benchmark (NOT a trace.log parse — RESEARCH.md Pitfall 1: a
# 0-match grep pipeline still exits 0, so the trace cannot record search misses;
# miss-rate MUST be measured live). Builds a synthetic 100-entry corpus, runs a
# fixed 10-query grep benchmark via scripts/retrieval/benchmark.py, and writes
# gate-evidence.md ONLY when a threshold is crossed:
#   (a) MISS_RATE > 0.10 AND real-corpus-size >= 20, OR
#   (b) AVG_LATENCY_MS > 100
# Exit 0 (open + evidence written) gates Plans 02-03; exit 1 (closed) blocks them.
#
# This is permanent gate infrastructure, not a model-crutch.
# tag: architecture
#
# NOTE: NOT set -e — grep no-match returns 1 and must not abort the run (Pitfall 5).
set -uo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HARNESS_DIR/hooks/common.sh"

GATE_EVIDENCE="$HARNESS_DIR/.planning/phases/04-heavy-retrieval-conditional/gate-evidence.md"
LIVE_LIB="$HOME/.claude/failure-lib"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- Step 1: synthetic 100-entry fixture corpus ---
# 100 small .md files with distinct words so grep has real content to scan.
# All entries describe "login" — none use the literal term "authentication",
# so the semantic-but-not-literal miss query below is a guaranteed grep miss.
mkdir -p "$WORK/corpus"
for i in $(seq 1 100); do
  n=$(printf '%03d' "$i")
  printf 'entry %s login session token cache index lesson body word-%s\n' "$n" "$n" \
    > "$WORK/corpus/entry-$n.md"
done

# --- Step 2: fixed 10-query benchmark file ---
# Of these 10, three are guaranteed misses (semantic terms absent from the
# corpus, which only contains "login"/"session"/"token"/etc.):
#   - authentication  (corpus says "login", never "authentication")  -> MISS
#   - zzzznomatch      (nonsense literal)                              -> MISS
#   - retrieval        (not present in corpus vocabulary)              -> MISS
# The remaining 7 match real corpus words.
cat > "$WORK/queries.txt" <<'EOF'
login
session
token
cache
index
lesson
word-050
authentication
zzzznomatch
retrieval
EOF

# --- Step 3: run the fresh benchmark over the synthetic corpus ---
BENCH_OUT=$(python3 "$HARNESS_DIR/scripts/retrieval/benchmark.py" \
  --corpus-dir "$WORK/corpus" --queries-file "$WORK/queries.txt" 2>/dev/null)
BENCH_RC=$?
if [ "$BENCH_RC" -ne 0 ] || [ -z "$BENCH_OUT" ]; then
  emit "GATE ERROR — benchmark.py failed (rc=$BENCH_RC)"
  exit 1
fi

MISS_RATE=$(printf '%s\n' "$BENCH_OUT" | grep '^MISS_RATE=' | cut -d= -f2)
AVG_LATENCY_MS=$(printf '%s\n' "$BENCH_OUT" | grep '^AVG_LATENCY_MS=' | cut -d= -f2)
SYNTH_CORPUS=$(printf '%s\n' "$BENCH_OUT" | grep '^CORPUS_SIZE=' | cut -d= -f2)

# --- Step 4: real live corpus size (drives the miss-rate corpus>=20 precondition) ---
# Count *.md under the live failure-lib plus the harness docs/ tree.
REAL_CORPUS=0
if [ -d "$LIVE_LIB" ]; then
  c=$(find "$LIVE_LIB" -name '*.md' 2>/dev/null | wc -l | xargs)
  REAL_CORPUS=$((REAL_CORPUS + ${c:-0}))
fi
if [ -d "$HARNESS_DIR/docs" ]; then
  c=$(find "$HARNESS_DIR/docs" -name '*.md' 2>/dev/null | wc -l | xargs)
  REAL_CORPUS=$((REAL_CORPUS + ${c:-0}))
fi

# --- Step 5: gate decision (awk for float comparison — bash cannot compare floats) ---
GATE_PATH=""
# (a) miss-rate path: MISS_RATE > 0.10 AND real corpus >= 20
if awk -v m="$MISS_RATE" 'BEGIN{exit !(m>0.10)}' && [ "$REAL_CORPUS" -ge 20 ]; then
  GATE_PATH="miss-rate"
# (b) latency path: AVG_LATENCY_MS > 100
elif awk -v l="$AVG_LATENCY_MS" 'BEGIN{exit !(l>100)}'; then
  GATE_PATH="latency"
fi

# --- Step 6/7: write evidence + open, or remove stale evidence + stay closed ---
if [ -n "$GATE_PATH" ]; then
  BENCHED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$GATE_EVIDENCE" <<EOF
# Phase 4 Gate Evidence
gate-path: $GATE_PATH
gate-status: OPEN
measured-miss-rate: $MISS_RATE
measured-avg-latency-ms: $AVG_LATENCY_MS
real-corpus-size: $REAL_CORPUS
synthetic-corpus-size: $SYNTH_CORPUS
benchmarked-at: $BENCHED_AT
EOF
  emit "GATE OPEN — gate-evidence.md written ($GATE_EVIDENCE)"
  exit 0
fi

# Gate closed: remove any stale evidence from a prior run.
[ -f "$GATE_EVIDENCE" ] && rm -f "$GATE_EVIDENCE"
emit "GATE CLOSED — miss-rate=$MISS_RATE latency=${AVG_LATENCY_MS}ms corpus=$REAL_CORPUS — Phase 4 build blocked"
exit 1
