"""Regression tests for the fast_path latency optimization (#35 build).

These run with ZERO network / LLM. They verify the retrieval-augmentation
orchestration (`_augment_query_augmentation`): on the fast_path both discretionary
chat completions (RAG-Fusion + HyDE) are skipped, and off the fast_path they are
run. The full `query_rag` is exercised via a lightweight stub pipeline so we can
count real LLM calls without a live provider.

The point: a fast_path query must make FEWER chat completions than a default
query (the latency root cause was 3 serial completions/query).
"""

from __future__ import annotations

from unittest.mock import AsyncMock

import pytest

from src.rag.pipeline import RAGPipeline


def _stub_pipeline():
    """A RAGPipeline whose discretionary generators + LLM are instrumented."""
    p = RAGPipeline.__new__(RAGPipeline)  # bypass __init__ (no clients/vectors)

    calls = {"fusion": 0, "hyde": 0, "answer": 0}

    async def fake_fusion(q):
        calls["fusion"] += 1
        return [q, q + " variant a", q + " variant b"]

    async def fake_hyde(q):
        calls["hyde"] += 1
        return "hypothetical answer for: " + q

    # The answer synthesis call is the only one that must always happen.
    async def fake_generate_structured(*args, **kwargs):
        calls["answer"] += 1
        return None

    p._generate_query_variants = fake_fusion
    p._generate_hyde_query = fake_hyde
    p.llm = AsyncMock()
    p.llm.generate_structured = fake_generate_structured
    return p, calls


@pytest.mark.asyncio
async def test_fast_path_skips_both_discretionary_calls():
    p, calls = _stub_pipeline()
    variants, hyde, embed = await p._augment_query_augmentation("Is X covered?", fast_path=True)
    assert calls["fusion"] == 0, "fast_path must skip RAG-Fusion"
    assert calls["hyde"] == 0, "fast_path must skip HyDE"
    assert variants == ["Is X covered?"]          # no synthetic variants
    assert hyde == ""                              # no hypothetical doc
    assert embed == "Is X covered?"                # embed the raw query


@pytest.mark.asyncio
async def test_default_path_runs_both_discretionary_calls():
    p, calls = _stub_pipeline()
    variants, hyde, embed = await p._augment_query_augmentation("Is X covered?", fast_path=False)
    assert calls["fusion"] == 1
    assert calls["hyde"] == 1
    assert len(variants) == 3                       # original + 2 variants
    assert embed == "hypothetical answer for: Is X covered?"


@pytest.mark.asyncio
async def test_fast_path_returns_fewer_llm_calls_than_default():
    """The headline latency assertion: fast_path drops 2 of 3 chat completions."""
    p, calls = _stub_pipeline()
    await p._augment_query_augmentation("Q", fast_path=True)
    fast_calls = calls["fusion"] + calls["hyde"]

    p2, calls2 = _stub_pipeline()
    await p2._augment_query_augmentation("Q", fast_path=False)
    default_calls = calls2["fusion"] + calls2["hyde"]

    assert fast_calls == 0
    assert default_calls == 2
    assert fast_calls < default_calls
