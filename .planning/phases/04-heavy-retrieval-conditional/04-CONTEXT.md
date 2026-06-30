# Phase 4: Heavy Retrieval (CONDITIONAL) - Context

**Gathered:** 2026-06-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace grep-based retrieval in the `context-pull search` skill with a vector/hybrid index over `failure-lib/` + `docs/`, eliminating the miss-rate or latency bottleneck proven by Phase 3 traces.

**This phase is CONDITIONAL.** Work begins only if `check-retrieval-gate.sh` confirms Phase 3 traces meet the measurable bottleneck threshold. If the gate does not open, Phase 4 is deferred indefinitely. No planning artifacts are created until the gate opens.

Pre-existing infrastructure Phase 4 builds on:
- `skills/context-pull/SKILL.md` — grep-based `search` subcommand; Phase 4 replaces this with vector/hybrid retrieval
- `failure-lib/` — the corpus to be indexed (currently 6+ entries, grows via `/retro approve`)
- `docs/` — additional retrieval corpus
- `hooks/trace.sh` — writes `~/.claude/trace.log`; Phase 3 traces feed the gate check
- `scripts/auto-distill.sh` — distill engine that generates trace evidence; `/retro approve` commits new lessons that the index must stay in sync with

</domain>

<decisions>
## Implementation Decisions

### Gate evaluation mechanics
- Gate opens only if Phase 3 `~/.claude/trace.log` meets AT LEAST ONE of:
  - **Miss-rate > 10%**: grep returns 0 results for ≥10% of observed context-pull queries AND corpus size ≥ 20 entries
  - **Latency > 100ms**: average grep latency exceeds 100ms on a 10-query benchmark against the current failure-lib
- `scripts/check-retrieval-gate.sh` reads `~/.claude/trace.log`, computes both metrics, and writes a `gate-evidence.md` file if threshold is met
- If `gate-evidence.md` is absent, Phase 4 MUST NOT proceed — even if research or planning artifacts exist
- Gate evidence file lives at `.planning/phases/04-heavy-retrieval-conditional/gate-evidence.md`

### Vector index technology (if gate opens)
- Embedded Python **chromadb** — local-only, no server, no API key required
- Consistent with Python stack already present (auto-distill.sh, Giavico PoC)
- No external dependencies beyond a `pip install chromadb` step added to setup/install path
- Index stored at `~/.claude/.retrieval/` (sibling to `failure-lib/`)

### Embedding model
- **sentence-transformers all-MiniLM-L6-v2** — offline, no API cost, fast for small corpora (<200 entries)
- Claude Discretion: if sentence-transformers proves heavy for the target environment, substitute `chromadb`'s default embedding function (also offline)

### Retrieval strategy
- **Hybrid**: vector similarity search as primary, grep fallback for exact ID matches
- Single interface: `context-pull search <query>` — unchanged API, upgraded backend
- Hybrid scoring: if vector search returns ≥1 result with similarity > 0.7, return those; else fall back to grep (preserves exact-match precision, adds semantic recall)
- Failure-lib entries and docs/ pages are indexed together; metadata field `source` distinguishes them in results

### Index maintenance
- On-demand rebuild via `scripts/build-retrieval-index.sh` — standalone script, callable independently
- Auto-rebuild trigger: `/retro approve` calls `build-retrieval-index.sh` after committing new lessons to `failure-lib/`
- `context-pull search` detects stale index (mtime of index < mtime of any failure-lib/*.md) and emits a warning; does NOT auto-rebuild mid-session (avoids latency spike)
- Index rebuild is idempotent: full rebuild from scratch each time (corpus is small enough that incremental adds no value)

### Done command structure
- Two scripts:
  - `scripts/check-retrieval-gate.sh` — gate check; exits 0 only if threshold met AND writes gate-evidence.md
  - `scripts/retrieval-e2e-test.sh` — e2e test; verifies vector search returns results that grep missed
- Done command: `./scripts/check-retrieval-gate.sh && ./scripts/retrieval-e2e-test.sh`

### Claude's Discretion
- Exact chromadb collection configuration (distance function, HNSW parameters)
- How to handle docs/ subdirectory structure during indexing (flat vs. recursive walk)
- Whether build-retrieval-index.sh is called from install.sh (likely skip — only needed after gate opens)
- Warning message format when stale index is detected in context-pull

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 4 gate and requirements
- `.planning/REQUIREMENTS.md` — RETR-01 (gate condition), RETR-02 (vector/hybrid index spec). Both must be satisfied. RETR-01 is the hard gate: no work proceeds without it.
- `.planning/PROJECT.md` — "Evidence-first" constraint + "Phase 4 conditional" decision in Key Decisions table. Confirms that building Phase 4 without trace evidence violates a core architectural constraint.
- `.planning/ROADMAP.md` §Phase 4 — Done command (`check-retrieval-gate.sh && retrieval-e2e-test.sh`), 3 binary success criteria, gate statement. Ground truth for what Phase 4 means.

### Code being upgraded
- `skills/context-pull/SKILL.md` — the `search` subcommand Phase 4 replaces. Read this to understand the current grep-based interface and preserve the unchanged API contract.

### Prior phase patterns to follow
- `.planning/phases/03-self-improve-loop/03-CONTEXT.md` — auto-distill.sh architecture, pending/ queue, install.sh patterns. Phase 4 extends the same `/retro approve` flow to trigger index rebuild.
- `.planning/phases/02-context-plane/02-CONTEXT.md` — context-pull skill design decisions; Phase 4 must not change the external interface, only the retrieval backend.
- `scripts/retro-e2e-test.sh` — [PASS]/[FAIL] test script style; `retrieval-e2e-test.sh` follows this exactly.
- `scripts/replay-giavico-failures.sh` — reference for test script structure (pre-step, per-check assertions, summary).

### Trace source (feeds gate check)
- `hooks/trace.sh` — writes one line per tool invocation to `~/.claude/trace.log`; the gate check parses this file. Read to understand the trace format before writing check-retrieval-gate.sh.
- `hooks/lessons-on-error.sh` — writes `.progress/lesson-hit-counts.json`; also relevant to understanding what Phase 3 trace evidence looks like.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `skills/context-pull/SKILL.md` — Phase 4 replaces the grep body of the `search` subcommand; `get-file` and `expand-summary` subcommands are unchanged
- `scripts/auto-distill.sh` — standalone script pattern to follow for `build-retrieval-index.sh` (called from hook + skill, both shell out to it)
- `skills/retro/SKILL.md` — Phase 4 extends `retro approve` to call `build-retrieval-index.sh` after committing lessons
- `hooks/common.sh` — `emit()` for stderr output; new scripts source this

### Established Patterns
- Standalone scripts called from both hooks and skills (auto-distill.sh pattern): Phase 4 follows this for `build-retrieval-index.sh`
- Test scripts: [PASS]/[FAIL] per-check, final summary, exit non-zero if any fail — `retrieval-e2e-test.sh` mirrors `retro-e2e-test.sh`
- Gate check script pattern: `check-retrieval-gate.sh` mirrors `force-loop-test.sh` — synthetic fixture injection, assertion, summary
- Index stored under `~/.claude/` — consistent with `~/.claude/trace.log`, `~/.claude/failure-lib/`; Phase 4 adds `~/.claude/.retrieval/`

### Integration Points
- `skills/context-pull/SKILL.md` — replace grep body in `search` subcommand; keep external interface identical
- `skills/retro/SKILL.md` — extend `approve` subcommand to call `scripts/build-retrieval-index.sh` after commit
- `install.sh` — may need `pip install chromadb sentence-transformers` step; add conditionally (only if `.retrieval/` setup is needed)
- `scripts/` — add `check-retrieval-gate.sh`, `build-retrieval-index.sh`, `retrieval-e2e-test.sh`
- `~/.claude/.retrieval/` — new index directory; created by `build-retrieval-index.sh` on first run

</code_context>

<specifics>
## Specific Ideas

- Gate evidence file path is deterministic: `.planning/phases/04-heavy-retrieval-conditional/gate-evidence.md` — planner and executor can grep for it to verify gate state before proceeding
- `context-pull search` API is unchanged externally — same argument, same output format. Only the retrieval backend changes. This means no downstream skill callers need updating.
- The hybrid fallback to grep is a safety net: if the vector index is stale or missing, `context-pull search` must still work (degraded to grep, not broken)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Phase 4 itself is the deferred idea from Phases 0–3 (file-based failure library is file-based in v1; vector DB deferred until proven needed).

</deferred>

---

*Phase: 04-heavy-retrieval-conditional*
*Context gathered: 2026-06-24*
