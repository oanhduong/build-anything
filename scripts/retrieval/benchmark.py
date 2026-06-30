#!/usr/bin/env python3
"""benchmark.py — fresh grep-baseline retrieval benchmark (Phase 4 RETR-01 gate).

Runs a FRESH grep benchmark against a corpus directory. It does NOT read
~/.claude/trace.log: per RESEARCH.md Pitfall 1, a 0-match grep pipeline still
exits 0, so the trace cannot record search misses — miss-rate MUST be measured
live. This script measures the CURRENT retrieval command (`grep -rn`) only; it
loads no vector library and no embedding model, so the gate can run
before any heavy-retrieval dependency is installed.

CLI contract (called by check-retrieval-gate.sh):
    python3 benchmark.py --corpus-dir <DIR> --queries-file <FILE>

Output (machine-parseable KEY=VALUE lines to stdout, EXACTLY these keys):
    CORPUS_SIZE=<int>
    QUERY_COUNT=<int>
    MISS_RATE=<float, 4 decimals>
    AVG_LATENCY_MS=<float, 2 decimals>

Pure stdlib only (subprocess, time, pathlib, argparse, statistics).
"""

import argparse
import statistics
import subprocess
import sys
import time
from pathlib import Path


def run_query(query: str, corpus_dir: str) -> tuple[int, float]:
    """Run the CURRENT retrieval command for one query against corpus_dir.

    Mirrors skills/context-pull/SKILL.md's retrieval body: `grep -rn <q> <dir>`.
    We do NOT pipe to head — the true result count is needed to detect misses.

    Returns (result_line_count, latency_ms). result_line_count == 0 is a MISS.
    Timing uses time.perf_counter() for sub-ms precision (RESEARCH.md "Don't
    Hand-Roll": bash `date` lacks the resolution for grep-fast calls).
    """
    start = time.perf_counter()
    proc = subprocess.run(
        ["grep", "-rn", query, corpus_dir],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    end = time.perf_counter()
    latency_ms = (end - start) * 1000.0
    # grep exits 1 on no-match (stdout empty) and 0 on match — count real lines.
    result_lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
    return len(result_lines), latency_ms


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fresh grep-baseline retrieval benchmark (no vector lib)."
    )
    parser.add_argument("--corpus-dir", required=True, help="Directory to grep.")
    parser.add_argument(
        "--queries-file",
        required=True,
        help="Newline-delimited queries, one per line.",
    )
    args = parser.parse_args()

    corpus_dir = Path(args.corpus_dir)
    queries_file = Path(args.queries_file)

    if not corpus_dir.is_dir():
        print(f"error: corpus dir not found: {corpus_dir}", file=sys.stderr)
        return 1
    if not queries_file.is_file():
        print(f"error: queries file not found: {queries_file}", file=sys.stderr)
        return 1

    queries = [
        line.strip()
        for line in queries_file.read_text().splitlines()
        if line.strip()
    ]
    if not queries:
        print("error: queries file contains no queries", file=sys.stderr)
        return 1

    misses = 0
    latencies: list[float] = []
    for query in queries:
        count, latency_ms = run_query(query, str(corpus_dir))
        if count == 0:
            misses += 1
        latencies.append(latency_ms)

    query_count = len(queries)
    miss_rate = misses / query_count
    avg_latency_ms = statistics.mean(latencies)
    # corpus_size = recursive count of *.md files under the corpus dir.
    corpus_size = sum(1 for _ in corpus_dir.rglob("*.md"))

    print(f"CORPUS_SIZE={corpus_size}")
    print(f"QUERY_COUNT={query_count}")
    print(f"MISS_RATE={miss_rate:.4f}")
    print(f"AVG_LATENCY_MS={avg_latency_ms:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
