"""Lightweight fast_path latency benchmark (#47).

No runnable fast_path benchmark existed in the repo (grep of tools/ + tests/ for
"benchmark"/"fast_path" found only the regression tests in
tests/test_fast_path_augmentation.py). This file ADDS the missing benchmark.

Scope / honesty (motto_v5 Confidence Honesty Standard):
- The headline, DEFENSIBLE claim is that fast_path makes FEWER chat completions
  (0 discretionary vs 2). That is asserted and is network-free.
- End-to-end query latency also depends on the embedding model + answer LLM,
  which require a network/local embedder we cannot run offline here. So this
  benchmark times ONLY the retrieval-augmentation ORCHESTRATION step
  (_augment_query_augmentation) with instant stub generators, and reports p50 for
  fast_path vs default as an ORCHESTRATION-level micro-benchmark -- NOT as
  end-to-end query latency. The numbers are real for that scope and are
  documented as such; they are NOT faked to look like full query latency.

Run:
    python -m pytest tests/bench_fast_path.py -q -s
"""

from __future__ import annotations

import asyncio
import statistics
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from unittest.mock import AsyncMock

import pytest

from src.rag.pipeline import RAGPipeline

ITER = 300
QUERY = "Is maternity cover included in the Health Shield 360 plan?"


def _stub_pipeline():
    """A RAGPipeline whose discretionary generators + LLM are instrumented.

    Mirrors tests/test_fast_path_augmentation.py's stub (bypass __init__ so no
    clients/vectors are created). The discretionary generators run instantly so
    the timed section measures orchestration overhead, not model latency.
    """
    p = RAGPipeline.__new__(RAGPipeline)
    calls = {"fusion": 0, "hyde": 0, "answer": 0}

    async def fake_fusion(q):
        calls["fusion"] += 1
        return [q, q + " variant a", q + " variant b"]

    async def fake_hyde(q):
        calls["hyde"] += 1
        return "hypothetical answer for: " + q

    async def fake_generate_structured(*args, **kwargs):
        calls["answer"] += 1
        return None

    p._generate_query_variants = fake_fusion
    p._generate_hyde_query = fake_hyde
    p.llm = AsyncMock()
    p.llm.generate_structured = fake_generate_structured
    return p, calls


@pytest.mark.asyncio
async def test_fast_path_benchmark():
    fast_times, default_times = [], []
    # Warm up (JIT / import caches) so the measured iterations are representative.
    warm, _ = _stub_pipeline()
    await warm._augment_query_augmentation(QUERY, fast_path=True)
    warm2, _ = _stub_pipeline()
    await warm2._augment_query_augmentation(QUERY, fast_path=False)

    for _ in range(ITER):
        p, _ = _stub_pipeline()
        t0 = time.perf_counter()
        await p._augment_query_augmentation(QUERY, fast_path=True)
        fast_times.append(time.perf_counter() - t0)

        p, _ = _stub_pipeline()
        t0 = time.perf_counter()
        await p._augment_query_augmentation(QUERY, fast_path=False)
        default_times.append(time.perf_counter() - t0)

    fast_p50 = statistics.median(fast_times)
    default_p50 = statistics.median(default_times)

    # Chat-completion-count difference (the robust, network-free headline).
    pf, cf = _stub_pipeline()
    await pf._augment_query_augmentation(QUERY, fast_path=True)
    pd, cd = _stub_pipeline()
    await pd._augment_query_augmentation(QUERY, fast_path=False)
    fast_calls = cf["fusion"] + cf["hyde"]
    default_calls = cd["fusion"] + cd["hyde"]

    assert fast_calls == 0, "fast_path must skip both discretionary chat completions"
    assert default_calls == 2, "default path must run Fusion + HyDE"
    assert fast_calls < default_calls

    # Orchestration-only latency: fast_path does strictly less work, so its
    # median must be <= the default median (single-tail, robust to noise).
    assert fast_p50 <= default_p50, (fast_p50, default_p50)

    print("\n=== fast_path benchmark (orchestration-only, offline) ===")
    print(f"iterations/side      : {ITER}")
    print(f"chat completions      : fast_path={fast_calls}  default={default_calls}  (diff={default_calls - fast_calls})")
    print(f"p50 augment latency   : fast_path={fast_p50*1e3:.3f} ms  default={default_p50*1e3:.3f} ms")
    print("NOTE: p50 is augmentation-orchestration time with instant stub generators.")
    print("      End-to-end query latency needs an offline embedder + answer LLM.")


if __name__ == "__main__":
    raise SystemExit(asyncio.run(test_fast_path_benchmark()))
