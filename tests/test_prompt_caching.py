"""Contracts for application response caching and provider cache telemetry."""

def test_rag_cache_requires_owner_or_document_scope():
    from src.rag.cache_policy import private_cache_scope

    assert not private_cache_scope(None)
    assert not private_cache_scope({})
    assert private_cache_scope({"owner_id": "owner-1"})
    assert private_cache_scope({"document_id": "doc-1"})


def test_cost_tracker_records_provider_cached_tokens():
    from src.llm.client import CostTracker

    tracker = CostTracker()
    tracker.record("gpt-4.1-nano", 1200, 100, cached_input_tokens=900)

    assert tracker.summary["cached_input_tokens"] == 900
    assert tracker.summary["total_calls"] == 1
