from __future__ import annotations

import json
from types import SimpleNamespace
import sqlite3
from unittest.mock import AsyncMock, MagicMock

import pytest


def _make_hit(hit_id: str, score: float, text: str, **payload):
    return SimpleNamespace(
        id=hit_id,
        score=score,
        payload={"text_content": text, **payload},
    )


def test_build_qdrant_filter_supports_document_and_list_filters():
    from src.rag.pipeline import RAGPipeline

    pipeline = RAGPipeline.__new__(RAGPipeline)
    qfilter = pipeline._build_qdrant_filter(
        {
            "document_id": "doc-123",
            "section": ["coverage", "benefits"],
            "filename": {"equals": "policy.pdf"},
        }
    )

    assert qfilter is not None
    assert len(qfilter.must) == 3
    keys = {condition.key for condition in qfilter.must}
    assert keys == {"document_id", "section", "filename"}


def test_local_hybrid_index_returns_exact_match_candidates(tmp_path):
    from src.rag.pipeline import RAGPipeline

    db_path = tmp_path / "rag_hybrid_index.db"
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE rag_chunks (
            lex_id INTEGER PRIMARY KEY AUTOINCREMENT,
            point_id TEXT UNIQUE,
            document_id TEXT,
            filename TEXT,
            page_number INTEGER,
            section TEXT,
            text_content TEXT NOT NULL,
            embedding_model TEXT,
            updated_at TEXT
        )
        """
    )
    conn.execute(
        """
        CREATE VIRTUAL TABLE rag_chunks_fts USING fts5(
            point_id UNINDEXED,
            search_text
        )
        """
    )
    conn.commit()

    pipeline = RAGPipeline.__new__(RAGPipeline)
    pipeline.hybrid_index_enabled = True
    pipeline.hybrid_index = conn

    pipeline._upsert_hybrid_index(
        "chunk-1",
        {
            "document_id": "doc-1",
            "filename": "policy.pdf",
            "page_number": 2,
            "section": "coverage",
            "text_content": "Policy Number: POL-12345",
            "embedding_model": "text-embedding-3-small",
            "embedding_timestamp": "2026-07-10T00:00:00Z",
        },
    )

    candidates = pipeline._query_hybrid_index("What is policy number POL-12345?", limit=5)

    assert candidates
    assert candidates[0].id == "chunk-1"
    assert "POL-12345" in candidates[0].payload["text_content"]


@pytest.mark.asyncio
async def test_query_rag_reranks_sources_and_returns_structured_answer(monkeypatch):
    from src.models.rag import RAGAnswer, RAGCitation
    from src.rag.pipeline import RAGPipeline

    import sqlite3

    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("CREATE TABLE IF NOT EXISTS rag_chunks (lex_id INTEGER PRIMARY KEY AUTOINCREMENT, point_id TEXT UNIQUE, document_id TEXT, filename TEXT, page_number INTEGER, section TEXT, text_content TEXT NOT NULL, embedding_model TEXT, updated_at TEXT)")
    conn.execute("CREATE VIRTUAL TABLE IF NOT EXISTS rag_chunks_fts USING fts5(point_id UNINDEXED, search_text)")
    conn.commit()

    pipeline = RAGPipeline.__new__(RAGPipeline)
    pipeline.collection_name = "insurance_documents_v2"
    pipeline.active_embedding_model = "text-embedding-3-small"
    pipeline.embedding_dimensions = 1536
    pipeline.hybrid_index_enabled = True
    pipeline.hybrid_index = conn
    pipeline.vector_backend = "qdrant"
    pipeline.qdrant_client = MagicMock()
    pipeline.qdrant_client.search = MagicMock()
    pipeline.redis = MagicMock()
    pipeline.cache = False
    pipeline.openai_chat_model = "gpt-4o"
    for hit_data in [
        {"document_id": "doc-1", "filename": "policy.pdf", "page_number": 2, "section": "coverage", "text_content": "Policy Number: POL-12345", "embedding_model": "text-embedding-3-small", "embedding_timestamp": "2026-07-10T00:00:00Z"},
        {"document_id": "doc-1", "filename": "policy.pdf", "page_number": 1, "section": "overview", "text_content": "General policy overview", "embedding_model": "text-embedding-3-small", "embedding_timestamp": "2026-07-10T00:00:00Z"},
        {"document_id": "doc-1", "filename": "policy.pdf", "page_number": 3, "section": "deductible", "text_content": "Deductible is 5000", "embedding_model": "text-embedding-3-small", "embedding_timestamp": "2026-07-10T00:00:00Z"},
    ]:
        pipeline._upsert_hybrid_index(f"chunk-{hit_data['page_number']}", hit_data)
    pipeline.llm = MagicMock()
    pipeline.llm.generate_structured = AsyncMock(
        return_value=RAGAnswer(
            answer="Policy number is POL-12345.",
            citations=[RAGCitation(source_index=1, quote="Policy Number: POL-12345")],
            confidence=0.65,
            missing_information=[],
            follow_up_questions=[],
        )
    )
    pipeline._generate_embeddings_with_fallback = AsyncMock(return_value=[[0.1, 0.2, 0.3]])
    pipeline._build_qdrant_filter = MagicMock(return_value=None)

    search_hits = [
        _make_hit("1", 0.92, "Policy Number: POL-12345", document_id="doc-1", page_number=2),
        _make_hit("2", 0.87, "General policy overview", document_id="doc-1", page_number=1),
        _make_hit("3", 0.72, "Deductible is 5000", document_id="doc-1", page_number=3),
    ]
    search_mock = MagicMock(return_value=search_hits)
    pipeline.qdrant_client.search = search_mock

    result = await RAGPipeline.query_rag(
        pipeline,
        "Summarize the policy coverage",
        top_k=2,
        filters={"document_id": "doc-1"},
    )

    assert result["status"] == "success"
    assert result["result"]["answer"] == "Policy number is POL-12345."
    assert result["result"]["citations"] == [
        {"source_index": 1, "quote": "Policy Number: POL-12345", "quote_source": "source_text", "document_id": None, "page_number": None, "citation_status": "verified"}
    ]
    assert result["result"]["retrieval_strategy"] == "dense_plus_local_fts"
    assert result["result"]["sources"][0]["text"] == "Policy Number: POL-12345"
    pipeline.qdrant_client.search.assert_called_once()
    assert pipeline.qdrant_client.search.call_args.kwargs["query_filter"] is None
    assert pipeline.qdrant_client.search.call_args.kwargs["limit"] == 6


@pytest.mark.asyncio
async def test_query_rag_uses_cached_response_when_available():
    from src.rag.pipeline import RAGPipeline

    cached_response = {
        "status": "success",
        "result": {
            "answer": "Cached policy number is POL-12345.",
            "sources": [{"text": "Policy Number: POL-12345"}],
            "query": "What is the policy number?",
            "embedding_model_used": "text-embedding-3-small",
            "llm_used": True,
            "confidence": 0.88,
            "retrieval_confidence": 0.91,
            "citations": [{"source_index": 1, "quote": "Policy Number: POL-12345"}],
            "missing_information": [],
            "follow_up_questions": [],
            "retrieval_strategy": "dense_plus_local_fts",
        },
    }

    pipeline = RAGPipeline.__new__(RAGPipeline)
    pipeline.collection_name = "insurance_documents_v2"
    pipeline.active_embedding_model = "text-embedding-3-small"
    pipeline.openai_chat_model = "gpt-5-nano"
    pipeline.cache = MagicMock()
    pipeline.cache.get.side_effect = lambda key: "3" if key == pipeline.CACHE_VERSION_KEY else json.dumps(cached_response)

    result = await RAGPipeline.query_rag(
        pipeline,
        "What is the policy number?",
        top_k=2,
        filters={"document_id": "doc-1"},
    )

    assert result == cached_response
    assert pipeline.cache.get.call_count == 2
    pipeline.cache.get.assert_any_call(pipeline.CACHE_VERSION_KEY)


@pytest.mark.asyncio
async def test_ingest_document_data_bumps_query_cache_version():
    from src.rag.pipeline import RAGPipeline

    pipeline = RAGPipeline.__new__(RAGPipeline)
    pipeline.active_embedding_model = "text-embedding-3-small"
    pipeline._generate_embeddings_with_fallback = AsyncMock(return_value=[[0.1, 0.2, 0.3]])
    pipeline._upsert_hybrid_index = MagicMock()
    pipeline.cache = MagicMock()
    pipeline.qdrant_client = MagicMock()
    pipeline.collection_name = "insurance_documents_v2"

    pipeline.qdrant_client.upsert = MagicMock()

    result = await RAGPipeline.ingest_document_data(
        pipeline,
        document_id="doc-123",
        text_blocks=[{"id": "chunk-1", "text": "Policy Number: POL-12345", "page": 1}],
        document_metadata={"filename": "policy.pdf"},
    )

    assert result["status"] == "success"
    pipeline.cache.incr.assert_called_once_with(pipeline.CACHE_VERSION_KEY)


@pytest.mark.asyncio
async def test_service_health_uses_live_pipeline_attributes(monkeypatch):
    from src.rag import service

    fake_pipeline = SimpleNamespace(
        openai_embedding_model="text-embedding-3-small",
        hf_embedding_model="sentence-transformers/all-MiniLM-L6-v2",
        ollama_embedding_model="nomic-embed-text",
        active_embedding_model="nomic-embed-text",
        openai_chat_model="gpt-5-nano",
        embedding_dimensions=768,
        openai_failure_count=2,
        hf_failure_count=1,
    )
    monkeypatch.setattr(service, "rag_pipeline", fake_pipeline)

    response = await service.health_check()

    assert response.status == "success"
    models = response.result["models"]
    assert models["primary_embedding"] == "text-embedding-3-small"
    assert models["fallback_embedding"] == "nomic-embed-text"
    assert models["active_embedding"] == "nomic-embed-text"
    assert models["embedding_dimensions"] == 768
