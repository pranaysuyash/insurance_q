import pytest
from src.rag.pipeline import RAGPipeline

@pytest.fixture
def pipeline():
    # Use mock to avoid actual initializing LLM/OpenAI
    return RAGPipeline.__new__(RAGPipeline)

def test_split_into_sentences(pipeline):
    text = "This is a test paragraph. It has three sentences! Here is the third one."
    sentences = pipeline._split_into_sentences(text)
    
    assert len(sentences) == 3
    assert sentences[0]["source_text"] == "This is a test paragraph."
    assert sentences[0]["chunk_type"] == "sentence"
    assert sentences[0]["sentence_index"] == 0
    assert "id" in sentences[0]
    
    assert sentences[1]["source_text"] == "It has three sentences!"
    assert sentences[1]["chunk_type"] == "sentence"
    assert sentences[1]["sentence_index"] == 1

    assert sentences[2]["source_text"] == "Here is the third one."
    assert sentences[2]["chunk_type"] == "sentence"
    assert sentences[2]["sentence_index"] == 2

@pytest.mark.asyncio
async def test_ingestion_multi_granularity_payload(monkeypatch):
    """
    Test that ingest_document_data produces both paragraph and sentence chunks
    """
    pipeline = RAGPipeline.__new__(RAGPipeline)
    pipeline._contextual_retrieval_enabled = False
    pipeline.active_embedding_model = "test-model"
    pipeline.vector_backend = "qdrant"
    pipeline.qdrant_client = type("MockQdrant", (), {"upsert": lambda *args, **kwargs: None})()
    pipeline.collection_name = "test_col"
    
    # Mock embeddings to just return zeros
    async def mock_embed(texts, *a, **kw):
        return [[0.0] * 1536 for _ in texts]
    
    pipeline._generate_embeddings_with_fallback = mock_embed
    pipeline._bump_query_cache_version = lambda: None
    pipeline._upsert_hybrid_index = lambda **kw: None
    pipeline._classify_section_type = lambda t: "general"
    
    text_blocks = [
        {"id": "block1", "text": "Sentence one is here. Sentence two is here as well, and it is a bit longer.", "page": 1}
    ]
    
    # Run ingestion
    result = await pipeline.ingest_document_data("doc1", text_blocks)
    
    assert result["status"] == "success"
    # Should produce 1 paragraph + 2 sentence chunks = 3 points
    assert result["points_added"] == 3
