import asyncio
import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from src.rag.pipeline import RAGPipeline, RAGCitation

@pytest.mark.asyncio
async def test_query_rag_stream_yields_completion_payload():
    pipeline = RAGPipeline()
    pipeline.vector_store = MagicMock()
    pipeline._load_cached_query_result = MagicMock(return_value=None)
    pipeline._classify_query = MagicMock(return_value="general")
    pipeline._augment_query_augmentation = AsyncMock(return_value=([], "query", "query"))
    pipeline._generate_embeddings_with_fallback = AsyncMock(return_value=[[0.1] * 384])
    
    mock_hit = MagicMock()
    mock_hit.id = 1
    mock_hit.score = 0.95
    mock_hit.payload = {
        "text_content": "Hospitalization expenses are covered up to sum insured.",
        "page_number": 4,
        "document_id": "doc-123",
        "metadata": {"title": "Test Policy"},
    }
    pipeline._search_qdrant = MagicMock(return_value=[mock_hit])
    pipeline._query_hybrid_index = MagicMock(return_value=[mock_hit])
    pipeline._merge_hybrid_results = MagicMock(return_value=[mock_hit])
    pipeline._rank_results = MagicMock(return_value=[mock_hit])
    pipeline._expand_with_adjacent_chunks = AsyncMock(return_value=[mock_hit])
    pipeline._evaluate_retrieval_quality = MagicMock(return_value=True)
    pipeline._estimate_retrieval_confidence = MagicMock(return_value=0.85)

    sample_sources = [
        {
            "id": 1,
            "document_id": "doc-123",
            "page_number": 4,
            "text": "Hospitalization expenses are covered up to sum insured.",
            "source_text": "Hospitalization expenses are covered up to sum insured.",
            "metadata": {"title": "Test Policy"},
        }
    ]
    pipeline._hybrid_rerank = MagicMock(return_value=sample_sources)

    # Mock generate_stream on pipeline.llm
    async def mock_stream(*args, **kwargs):
        yield "Hospitalization "
        yield "covered."

    pipeline.llm = MagicMock()
    pipeline.llm.generate_stream = mock_stream

    tokens = []
    completion_payload = None

    async for chunk in pipeline.query_rag_stream(
        user_query="Is hospitalization covered?",
        top_k=3,
        lob="health",
    ):
        parsed = json.loads(chunk)
        if "token" in parsed:
            tokens.append(parsed["token"])
        if parsed.get("done") is True:
            completion_payload = parsed

    assert len(tokens) == 2
    assert completion_payload is not None
    assert completion_payload["done"] is True
    assert "verification_status" in completion_payload
    assert "confidence" in completion_payload
    assert "sources" in completion_payload
    assert len(completion_payload["sources"]) == 1
    assert completion_payload["sources"][0]["page_number"] == 4
