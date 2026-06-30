# Phase 4: Heavy Retrieval (CONDITIONAL) - Research

**Researched:** 2026-06-24
**Domain:** Local vector retrieval (chromadb + embeddings) replacing grep in a shell-driven Claude Code harness
**Confidence:** HIGH for existing-code findings (read directly); MEDIUM for chromadb/sentence-transformers API (verified via PyPI + official docs + WebSearch, but not run locally — neither package installed)

## Summary

Phase 4 swaps the grep body of the `context-pull search` skill for an embedded chromadb vector index over `failure-lib/` + `docs/`, behind an unchanged external interface, with grep as a hybrid fallback. It is **gated**: no implementation proceeds until `scripts/check-retrieval-gate.sh` confirms a measurable grep bottleneck and writes `gate-evidence.md`.

The single most important discovery from reading the existing code: **the trace.log format (`TIMESTAMP TOOL exit=N TARGET`) does NOT record `context-pull search` as its own tool.** The skill is model-invoked and its grep runs as a `Bash` tool call, so a search miss (grep returns 0 results) does not appear as a non-zero exit — `grep` returning no matches exits 1, but `head`/pipe/`2>/dev/null` in the SKILL.md command swallows it. This means the gate check **cannot reliably derive miss-rate from the historical trace alone.** The gate must instead run a fresh benchmark: replay a fixed query set against the current grep command and measure 0-result rate and latency. This is the central planning constraint and is reflected in Open Questions.

Second key discovery: chromadb's `DefaultEmbeddingFunction` **already uses all-MiniLM-L6-v2** (via onnxruntime, no `sentence-transformers` package required). The CONTEXT.md "Claude Discretion" fallback (use chromadb default if sentence-transformers is heavy) is therefore the *lower-friction default*, not a downgrade — same model, ~same vectors, far fewer dependencies. Recommend defaulting to `DefaultEmbeddingFunction` and only adding `sentence-transformers` if a specific need arises.

**Primary recommendation:** Build the gate check as a *fresh benchmark harness* (not a trace parser), default to chromadb `DefaultEmbeddingFunction` (all-MiniLM-L6-v2 via onnxruntime), keep the Python in standalone scripts shelled-out from the skill (mirroring `auto-distill.sh`), and never let the search skill hard-fail — always fall back to grep.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RETR-01 | Phase 4 is only planned/built if Phase 3 traces show grep retrieval causes measurable quality loss (miss-rate or latency bottleneck) | Gate mechanics defined in CONTEXT (miss-rate > 10% with corpus over 20 OR latency > 100ms on 10-query benchmark). **Critical finding:** trace.log does NOT log search misses as non-zero exits (see Pitfall 1) — gate check must run a fresh benchmark, not parse historical trace. `scripts/check-retrieval-gate.sh` writes `gate-evidence.md`; absence of that file means phase blocked. |
| RETR-02 | If gate opens: vector/hybrid index over failure-lib + docs/; replaces grep search in context-pull skill | chromadb PersistentClient at `~/.claude/.retrieval/`, DefaultEmbeddingFunction (all-MiniLM-L6-v2), hybrid scoring (vector if sim > 0.7 else grep fallback). `build-retrieval-index.sh` standalone script (auto-distill.sh pattern), triggered by `/retro approve`. context-pull `search` external API unchanged. |
</phase_requirements>

## Standard Stack

> Both packages are **NOT currently installed** in this environment (`pip3 show chromadb sentence-transformers` returns not found). No Python project file (requirements.txt / pyproject.toml) exists in this repo. Installation is net-new and must be added to the setup path (CONTEXT: only if/when gate opens). The Giavico PoC Python lives in a separate repo (`~/Work/mine/giavico`), not in build-anything — so there is no existing in-repo Python dependency surface to extend.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| chromadb | 1.5.9 (latest on PyPI as of 2026-06-24, verified via `pip3 index versions chromadb`) | Embedded local vector store; `PersistentClient` persists to disk, no server, no API key | Matches CONTEXT decision; de-facto standard embedded vector DB for small local corpora; pure-Python + onnxruntime, offline |
| onnxruntime (transitive via chromadb DefaultEmbeddingFunction) | bundled by chromadb | Runs the bundled all-MiniLM-L6-v2 ONNX model for `DefaultEmbeddingFunction` | Ships with chromadb's default embedder; no separate model download step beyond first-run cache |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| sentence-transformers | latest (could not confirm exact version — PyPI fetch blocked by local SSL cert issue; verify with `pip index versions sentence-transformers` at plan time) | Explicit all-MiniLM-L6-v2 via `SentenceTransformerEmbeddingFunction` | ONLY if `DefaultEmbeddingFunction` proves insufficient. CONTEXT lists this as primary, but see "Alternatives" — the default already IS all-MiniLM-L6-v2 with fewer deps |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `SentenceTransformerEmbeddingFunction(model_name="all-MiniLM-L6-v2")` | `chromadb.utils.embedding_functions.DefaultEmbeddingFunction()` | **Default uses the SAME model (all-MiniLM-L6-v2)** but via onnxruntime instead of the heavyweight `sentence-transformers` + `torch` stack. Far smaller install, no torch. CONTEXT explicitly permits this substitution under "Claude's Discretion." **Recommend default as the actual default.** Caveat: the two are NOT guaranteed bit-identical (see Pitfall 2) — pick ONE and use it for both index build and query. |
| chromadb | Pure-Python cosine over a pickled numpy matrix | chromadb adds HNSW indexing + persistence + metadata filtering for free; hand-rolling these for a corpus under 200 entries is the exact "don't hand-roll" trap. But for a corpus this small, brute-force cosine is genuinely viable and dependency-free — note as a fallback if chromadb install proves fragile in CI/install.sh |

**Installation (add only when gate opens):**
```bash
pip install chromadb            # DefaultEmbeddingFunction (all-MiniLM-L6-v2 via onnxruntime) — recommended default
# pip install sentence-transformers   # ONLY if explicit SentenceTransformerEmbeddingFunction is needed (pulls torch)
```

**Version verification (run at plan time):**
```bash
pip index versions chromadb
pip index versions sentence-transformers
```
chromadb 1.5.9 was confirmed available locally. The sentence-transformers version could not be fetched (local SSL cert error on direct PyPI JSON call) — confirm before pinning.

## Architecture Patterns

### Recommended Structure (extends existing layout)
```
build-anything/
├── scripts/
│   ├── build-retrieval-index.sh    # NEW — standalone, auto-distill.sh pattern; shells to python
│   ├── check-retrieval-gate.sh     # NEW — gate benchmark + gate-evidence.md writer
│   ├── retrieval-e2e-test.sh       # NEW — PASS/FAIL e2e, retro-e2e-test.sh pattern
│   └── retrieval/                  # NEW — Python the shells call (keeps ENFC-04 grep-clean hooks unaffected)
│       ├── build_index.py
│       ├── search.py
│       └── benchmark.py
├── skills/context-pull/SKILL.md    # EDIT — replace grep body of `search` subcommand
└── skills/retro/SKILL.md           # EDIT — `approve` calls build-retrieval-index.sh after commit
~/.claude/.retrieval/               # NEW — chromadb PersistentClient path (created on first build)
```

### Pattern 1: Standalone script shelled-out from skill (auto-distill.sh pattern)
**What:** `build-retrieval-index.sh` is a standalone script. The `/retro approve` skill and any hook call it via `bash ~/.claude/scripts/build-retrieval-index.sh` — single source of truth, exactly as `auto-distill.sh` is called from both the Stop hook and `/retro run`.
**When to use:** Always — this is the established harness pattern (STATE.md: "auto-distill.sh is single source of truth … Stop-hook and /retro both shell out to it").
**Example (call site in retro/SKILL.md `approve`, after the existing git commit):**
```bash
# after: git -C "$HOME/.claude" commit -m "retro: approve lesson <id> ..."
bash "$HOME/.claude/scripts/build-retrieval-index.sh"   # rebuild index so new lesson is searchable
```

### Pattern 2: Shell wraps Python, never inlines it (ENFC-04 boundary)
**What:** Hooks must stay language-agnostic (ENFC-04: `replay-giavico-failures.sh` actively greps hook bodies for `\b(node|python|python3|java|kotlin)\b` and FAILS the build if found). **Therefore the Python invocation must live in `scripts/`, NOT in any `hooks/*.sh`.** Scripts are exempt from the ENFC-04 grep (it scans `~/.claude/hooks/` only), so `build-retrieval-index.sh` calling `python3 scripts/retrieval/build_index.py` is safe.
**When to use:** Always. Confirm no Python token leaks into `hooks/`.
**Anti-pattern:** Calling chromadb from inside a `hooks/*.sh` file trips the ENFC-04 regression in `replay-giavico-failures.sh`.

### Pattern 3: chromadb PersistentClient, idempotent full rebuild
**What:** CONTEXT decides "full rebuild from scratch each time (corpus small enough that incremental adds no value)." Delete + recreate the collection on each build for determinism.
**Example (verified shape from Chroma docs / WebSearch — confirm method names at impl time):**
```python
# Source: https://docs.trychroma.com/reference/python/client + WebSearch 2026-06-24
import chromadb
from chromadb.utils import embedding_functions

client = chromadb.PersistentClient(path="<HOME>/.claude/.retrieval")
ef = embedding_functions.DefaultEmbeddingFunction()  # all-MiniLM-L6-v2 via onnxruntime
# Idempotent rebuild: drop then recreate so stale entries never linger.
try:
    client.delete_collection("harness")
except Exception:
    handle_missing_collection()
col = client.get_or_create_collection(name="harness", embedding_function=ef)
col.add(
    documents=[full_markdown_text],
    ids=["failure-lib/openpyxl-engine"],          # stable, source-relative id
    metadatas=[{"source": "failure-lib", "path": "...", "lesson_id": "openpyxl-engine"}],
)
```

### Pattern 4: Hybrid scoring (vector primary, grep fallback)
**What:** CONTEXT locks the rule: "if vector search returns over 1 result with similarity > 0.7, return those; else fall back to grep." chromadb `query` returns **distances**, not similarities — for cosine space, `similarity ≈ 1 - distance`. Pick the distance/space explicitly so the 0.7 threshold is meaningful.
**Example (query shape — verify at impl time):**
```python
# Source: WebSearch 2026-06-24 (Chroma cookbook / docs)
res = col.query(query_texts=[query], n_results=5)
# res["distances"][0], res["documents"][0], res["metadatas"][0]
# convert distance to similarity per the configured space; if best similarity > 0.7 return,
# else: shell back to the original grep command (degraded path).
```

### Anti-Patterns to Avoid
- **Mixing embedding functions between build and query:** index built with `DefaultEmbeddingFunction` then queried with `SentenceTransformerEmbeddingFunction` (or vice-versa) returns wrong/empty results (Pitfall 2). One function, both paths.
- **Hard-failing search when the index is missing/stale:** breaks the unchanged-API contract. CONTEXT "specifics": search must still work degraded-to-grep, not broken.
- **Auto-rebuilding mid-session inside `search`:** CONTEXT forbids it (latency spike) — detect stale (index mtime < newest failure-lib/*.md mtime), warn, but do NOT rebuild in the search path.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vector similarity index | Custom HNSW / ANN structure | chromadb | Persistence, metadata filtering, ANN all solved; corpus may grow |
| Sentence embeddings | Custom tokenizer/model | DefaultEmbeddingFunction (all-MiniLM-L6-v2) | Bundled, offline, no API key |
| Latency benchmark timing | ad-hoc `date` math in bash | `time` builtin or Python `time.perf_counter()` in benchmark.py | Sub-ms precision needed for the 100ms gate threshold; bash `date` granularity is coarse |
| Gate evidence format | freeform prose | structured markdown with parseable metric lines (mirror gate-evidence path convention) | Downstream verify greps it; keep machine-checkable like PROGRESS contract |

**Key insight:** The corpus is tiny (currently **6 failure-lib entries, docs/ is EMPTY** — only `.gitkeep`). Hand-rolling cosine over 6 to 200 vectors is technically trivial, but chromadb is the locked decision and gives persistence + the stale-detection mtime story for free. The real engineering is in the **gate benchmark and the grep-fallback wiring**, not the vector math.

## Common Pitfalls

### Pitfall 1: trace.log does NOT record search misses (gate cannot be derived from history)
**What goes wrong:** Planning a gate check that parses `~/.claude/trace.log` for context-pull miss-rate. It isn't there.
**Why it happens:** Trace format is `TIMESTAMP TOOL exit=N TARGET` (from `hooks/common.sh::trace_write`). `context-pull search` is a model-invoked Skill; its grep runs as a `Bash` tool whose command is `grep -rn "$ARGUMENTS" docs/ .progress/ 2>/dev/null | head -40`. A grep with **zero matches exits 1, but the pipe to `head` makes the pipeline exit 0**, and the skill doesn't surface "0 results" as a tool error. So a miss leaves no non-zero-exit fingerprint, and the Bash TARGET is the grep command text, not the result count.
**How to avoid:** `check-retrieval-gate.sh` must run a **fresh benchmark**, not parse history: replay a fixed query set against the *current* grep command, count 0-result queries (miss-rate) and time them (latency), against the live failure-lib. Write the measured numbers into `gate-evidence.md`. This is the only reliable evidence source.
**Warning signs:** A gate script that greps trace.log for "context-pull" or "search" finds nothing and silently reports 0% miss-rate.

### Pitfall 2: DefaultEmbeddingFunction vs SentenceTransformerEmbeddingFunction are NOT interchangeable
**What goes wrong:** Index built with one embedder, queried with the other returns empty or garbage results. Verified via chromadb GitHub issue #2748: data embedded with the default function could not be retrieved with the SentenceTransformer variant.
**Why it happens:** Even though both nominally target all-MiniLM-L6-v2, the runtime path (onnxruntime vs torch) and normalization can differ; chromadb persists which embedder a collection used, and a mismatch on query produces wrong vectors.
**How to avoid:** Choose ONE embedding function (recommend `DefaultEmbeddingFunction`). Use it identically in `build_index.py` AND `search.py`. Never let CONTEXT's "primary sentence-transformers / fallback default" wording cause the build and query paths to diverge.
**Warning signs:** Vector search returns 0 results for a query whose terms are literally in an indexed document.

### Pitfall 3: docs/ is empty and corpus under 20 — miss-rate gate path may be unreachable
**What goes wrong:** The miss-rate gate condition requires "corpus size at least 20 entries." Today there are 6 failure-lib entries and 0 docs. The miss-rate path of the gate literally cannot open until the corpus grows.
**Why it happens:** failure-lib grows one lesson at a time via `/retro approve`; docs/ has never been populated.
**How to avoid:** Plan for BOTH gate paths but expect the **latency path** (over 100ms on 10-query benchmark) to be the realistically testable one near-term. Document in gate-evidence.md which path opened. The planner should not assume a 20-entry corpus exists.
**Warning signs:** Gate benchmark reports corpus size 6 and miss-rate path auto-skips — that's correct behavior, not a bug.

### Pitfall 4: First chromadb import / first embed downloads + caches the model (cold-start latency)
**What goes wrong:** First `DefaultEmbeddingFunction()` call fetches/extracts the ONNX model; a cold benchmark run measures download time, not retrieval time, and may need network.
**Why it happens:** Model is lazy-loaded and cached on first use (typically under `~/.cache`).
**How to avoid:** Warm the model once before timing in `benchmark.py` / `retrieval-e2e-test.sh`. For the offline/no-API-key guarantee, confirm the model is cached after first install (install.sh could pre-warm if gate opens). Exclude cold-start from the latency comparison vs the grep baseline.
**Warning signs:** First retrieval-e2e run is multi-second and/or fails with a network error in an offline environment.

### Pitfall 5: Shell scripts must not abort on grep no-match (set -e trap)
**What goes wrong:** `set -e` in the new scripts aborts when grep (fallback path) finds nothing (rc=1).
**Why it happens:** Established harness pitfall — `auto-distill.sh` and `retro-e2e-test.sh` both carry the comment "NOT set -e — grep/find no-match returns 1 and must not abort the run." STATE.md logs it as a recurring decision.
**How to avoid:** Use `set -uo pipefail` (not `set -e`) in `build-retrieval-index.sh`, `check-retrieval-gate.sh`, `retrieval-e2e-test.sh`, mirroring the existing trace scripts.
**Warning signs:** Script exits silently mid-run right after a grep that found nothing.

## Code Examples

### Existing grep search body being replaced (context-pull/SKILL.md)
```
# Source: skills/context-pull/SKILL.md (read 2026-06-24)
grep -rn "$ARGUMENTS" docs/ .progress/ 2>/dev/null | head -40
```
Note: current grep targets `docs/ .progress/` and explicitly does NOT search `failure-lib/` (Phase 2 decision: failure-lib is surfaced by load-lessons.sh at session start). **Phase 4 broadens the corpus to failure-lib + docs/ per CONTEXT** — this is a deliberate scope change for the vector backend; preserve the grep-fallback over its original targets, but index failure-lib + docs/ for the vector path. Flag this corpus mismatch to the planner (Open Question 4).

### Trace format the gate must understand (common.sh)
```bash
# Source: hooks/common.sh::trace_write (read 2026-06-24)
echo "${timestamp} ${tool} exit=${exit_code} ${target}" >> "${HOME}/.claude/trace.log"
# Real line: 2026-06-24T09:21:16Z Bash exit=0 grep -rn "foo" docs/ .progress/ 2>/dev/null | head -40
```

### /retro approve trigger point (retro/SKILL.md, after commit)
```bash
# Source: skills/retro/SKILL.md `approve` step 3 (read 2026-06-24) — insert rebuild AFTER this:
git -C "$HOME/.claude" add "failure-lib/<id>.md" \
  && git -C "$HOME/.claude" commit -m "retro: approve lesson <id> ..."
# NEW Phase 4 line:
bash "$HOME/.claude/scripts/build-retrieval-index.sh"
```

### Test-script skeleton (mirror retro-e2e-test.sh / replay-giavico-failures.sh)
```bash
# Source: scripts/retro-e2e-test.sh (read 2026-06-24)
set -uo pipefail
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }
WORK=$(mktemp -d)              # isolation — never touch real ~/.claude/.retrieval
# ... per-check assertions ...
rm -rf "$WORK"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `chromadb.Client()` ephemeral | `chromadb.PersistentClient(path=...)` | chromadb 0.4.x+ | Use PersistentClient for the on-disk `~/.claude/.retrieval/` store |
| `sentence-transformers` required for all-MiniLM | `DefaultEmbeddingFunction` ships all-MiniLM-L6-v2 via onnxruntime | chromadb bundles it | No torch dependency needed for the locked model |

**Deprecated/outdated:**
- Ephemeral in-memory `Client()` for anything needing persistence — replaced by `PersistentClient`.
- Assuming `sentence-transformers` is mandatory for all-MiniLM — the default embedder already is that model.

## Open Questions

1. **Where does miss-rate evidence come from if trace.log doesn't log search misses?**
   - What we know: trace.log records Bash grep commands but not their result counts; a 0-match grep pipeline still exits 0 (Pitfall 1).
   - What's unclear: whether any historical signal exists, or whether the gate is purely a fresh benchmark.
   - Recommendation: **Gate = fresh benchmark.** `check-retrieval-gate.sh` replays a fixed query set against the live grep command, measuring 0-result rate + latency now. Treat trace.log only as a corpus-size / activity sanity check, not the miss-rate source.

2. **Which gate path is realistically achievable today?**
   - What we know: corpus is 6 entries, docs/ empty; miss-rate path needs at least 20 entries.
   - What's unclear: whether the human intends to grow the corpus before gating, or rely on the latency path.
   - Recommendation: Implement both metric paths; expect the latency path to be the one that can open near-term. gate-evidence.md must state which path opened and the measured numbers.

3. **Exact similarity threshold semantics (distance vs similarity, which space).**
   - What we know: CONTEXT locks "similarity > 0.7"; chromadb returns distances; cosine vs L2 changes the math.
   - What's unclear: which distance space to configure on the collection.
   - Recommendation (Claude Discretion per CONTEXT): configure cosine space explicitly (`metadata={"hnsw:space": "cosine"}` on collection create — verify exact key at impl time) and define similarity = 1 minus distance so 0.7 is meaningful. Validate empirically against a known-good query in retrieval-e2e-test.sh.

4. **Corpus mismatch: grep search currently excludes failure-lib; Phase 4 indexes it.**
   - What we know: current grep targets `docs/ .progress/` and deliberately skips failure-lib (Phase 2 decision). CONTEXT Phase 4 indexes failure-lib + docs/.
   - What's unclear: whether the grep *fallback* should also start searching failure-lib (changing fallback behavior) or stay as-is.
   - Recommendation: Vector path indexes failure-lib + docs/ (per CONTEXT). Grep fallback keeps its original target set to avoid double-surfacing failure-lib (already shown by load-lessons.sh). Confirm with planner; this is a behavioral seam.

5. **Does chromadb belong in install.sh, and is offline guaranteed?**
   - What we know: CONTEXT leans "likely skip install.sh — only needed after gate opens"; model downloads on first use (Pitfall 4).
   - Recommendation: Gate the `pip install` + model pre-warm behind gate-opening, not unconditional install.sh. Document the one-time network requirement for the first model fetch; after caching it is offline.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash PASS/FAIL scripts (project convention — no pytest/jest in build-anything repo) |
| Config file | none — scripts are self-contained, `set -uo pipefail` |
| Quick run command | `bash scripts/check-retrieval-gate.sh` |
| Full suite command | `bash scripts/check-retrieval-gate.sh && bash scripts/retrieval-e2e-test.sh` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RETR-01 | Gate opens only on measured miss-rate over 10% (corpus over 20) OR latency over 100ms; writes gate-evidence.md | gate/benchmark | `bash scripts/check-retrieval-gate.sh` | Wave 0 |
| RETR-01 | gate-evidence.md present at agreed path before any Phase 4 build | smoke | `test -f .planning/phases/04-heavy-retrieval-conditional/gate-evidence.md` | Wave 0 |
| RETR-02 | Vector search returns over 1 result for a query grep provably missed (regression fixture) | e2e | `bash scripts/retrieval-e2e-test.sh` | Wave 0 |
| RETR-02 | 100-entry failure-lib query latency below measured grep baseline | benchmark | `bash scripts/retrieval-e2e-test.sh` (logs latency) | Wave 0 |
| RETR-02 | context-pull `search` external API unchanged | structural | grep SKILL.md argument-hint/interface unchanged in retrieval-e2e-test.sh | Wave 0 |
| RETR-02 | Stale/missing index degrades to grep, never hard-fails | e2e | retrieval-e2e-test.sh: remove index, assert search still returns | Wave 0 |

### Sampling Rate
- **Per task commit:** `bash scripts/check-retrieval-gate.sh` (cheap, gate sanity)
- **Per wave merge:** `bash scripts/retrieval-e2e-test.sh`
- **Phase gate:** `./scripts/check-retrieval-gate.sh && ./scripts/retrieval-e2e-test.sh` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `scripts/check-retrieval-gate.sh` — RETR-01 gate benchmark + gate-evidence.md writer (fresh benchmark, NOT trace parse)
- [ ] `scripts/build-retrieval-index.sh` — RETR-02 index builder (auto-distill.sh standalone pattern)
- [ ] `scripts/retrieval-e2e-test.sh` — RETR-02 e2e (retro-e2e-test.sh PASS/FAIL + mktemp isolation)
- [ ] `scripts/retrieval/build_index.py`, `search.py`, `benchmark.py` — Python the shells call (keeps hooks ENFC-04 clean)
- [ ] **Regression test fixture** — a query that grep provably misses but vector finds (required by success criterion 2). Must be created; no fixtures dir exists today.
- [ ] **Synthetic corpus fixture** — to exercise the 20-plus-entry miss-rate path and the "100-entry" latency benchmark, since real failure-lib has only 6 entries.
- [ ] Dependency install: `pip install chromadb` — neither chromadb nor sentence-transformers is installed; gate this behind gate-opening.

## Sources

### Primary (HIGH confidence)
- `hooks/common.sh`, `hooks/trace.sh` — trace.log format `TIMESTAMP TOOL exit=N TARGET` (read directly)
- `skills/context-pull/SKILL.md` — current grep search body + unchanged-API contract (read directly)
- `skills/retro/SKILL.md` — `/retro approve` flow, exact commit step to hook rebuild onto (read directly)
- `scripts/auto-distill.sh` — standalone-script pattern, `set -uo pipefail` rule (read directly)
- `scripts/retro-e2e-test.sh`, `scripts/replay-giavico-failures.sh`, `scripts/force-loop-test.sh` — test/gate script patterns, mktemp isolation, ENFC-04 grep (read directly)
- `install.sh` — skills/scripts overwrite vs failure-lib never-overwrite install semantics (read directly)
- `pip3 index versions chromadb` returns 1.5.9 latest confirmed locally (2026-06-24)
- Live `~/.claude/trace.log` tail — confirmed real format including Bash command as TARGET

### Secondary (MEDIUM confidence)
- https://docs.trychroma.com/reference/python/client — PersistentClient / get_or_create_collection / query API
- chromadb GitHub issue #2748 — DefaultEmbeddingFunction vs SentenceTransformerEmbeddingFunction incompatibility (Pitfall 2)
- https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2 — model = 384-dim, small, offline
- WebSearch (2026-06-24): chromadb DefaultEmbeddingFunction equals all-MiniLM-L6-v2 via onnxruntime

### Tertiary (LOW confidence — verify at impl)
- Exact chromadb method signatures (`delete_collection`, `hnsw:space` metadata key) — confirm against installed version
- sentence-transformers latest version — PyPI JSON fetch blocked by local SSL cert error; run `pip index versions sentence-transformers`

## Metadata

**Confidence breakdown:**
- Existing code (trace format, skill bodies, patterns, install semantics): HIGH — read directly from source
- Gate mechanics insight (fresh benchmark required): HIGH — derived from confirmed trace format + grep pipeline behavior
- chromadb/sentence-transformers API: MEDIUM — official docs + WebSearch + PyPI, but NOT run locally (packages not installed)
- Exact chromadb method/space names: LOW — verify against installed version at implementation

**Research date:** 2026-06-24
**Valid until:** 2026-07-24 for existing-code findings (stable); approximately 2026-07-08 for chromadb API (fast-moving — 1.x line, frequent releases)
