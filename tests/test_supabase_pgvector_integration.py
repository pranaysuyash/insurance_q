"""Integration tests for the canonical prod pgvector adapter (SupabaseVectorStore).

These exercise the real ``src/services/supabase_vector_store.py`` code path --
the one the app uses when ``ENVIRONMENT=production`` -- against an in-memory
fake Supabase client (``tests/fixtures/pgvector_fake_supabase.py``). Previously
this path was never exercised by the suite (dev/QA uses Qdrant/local-SQLite),
so contract guards, owner scoping, and RPC param wiring were untested (debt
entry H-07 / finding E3).

Run with the standard interpreter: ``./venv/bin/python -m pytest tests/test_supabase_pgvector_integration.py``
"""

import asyncio
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "fixtures"))
from pgvector_fake_supabase import FakeSupabaseClient  # noqa: E402

from src.services.supabase_vector_store import SupabaseVectorStore  # noqa: E402


def _vec(dims: int = 1536, hot: int = 0) -> list[float]:
    v = [0.0] * dims
    if 0 <= hot < dims:
        v[hot] = 1.0
    return v


@pytest.fixture
def fake_client() -> FakeSupabaseClient:
    return FakeSupabaseClient()


@pytest.fixture
def store(fake_client: FakeSupabaseClient) -> SupabaseVectorStore:
    # Passing a client short-circuits the real Supabase import/construction.
    return SupabaseVectorStore("http://fake.local", "fake-key", client=fake_client)


def _blocks(texts):
    return [
        {
            "embedding_model": "text-embedding-3-small",
            "embedding_version": "v1",
            "text": t,
            "source_text": t,
            "retrieval_text": t,
            "section_type": "general",
            "section_tags": ["benefit"],
        }
        for t in texts
    ]


def test_upsert_persists_rows_with_expected_shape(fake_client, store):
    blocks = _blocks(["Cancer cover pays up to 5 lakh", "Maternity waiting period 24 months"])
    embeddings = [_vec(hot=0), _vec(hot=1)]
    n = asyncio.run(store.upsert("doc-1", blocks, embeddings, owner_id="owner-1"))
    assert n == 2
    rows = fake_client._tables.get("document_chunks", [])
    assert len(rows) == 2
    assert rows[0]["owner_id"] == "owner-1"
    assert rows[0]["embedding_model"] == "text-embedding-3-small"
    assert rows[0]["embedding_dimensions"] == 1536
    assert "text_content" in rows[0]["metadata"]


def test_fts_search_is_owner_scoped_and_ranked(store, fake_client):
    blocks = _blocks(["Cancer cover pays up to 5 lakh", "Maternity waiting period 24 months"])
    embeddings = [_vec(hot=0), _vec(hot=1)]
    asyncio.run(store.upsert("doc-1", blocks, embeddings, owner_id="owner-1"))

    hits = asyncio.run(
        store.search_fts("maternity waiting period", limit=10, filters={"owner_id": "owner-1"})
    )
    assert hits, "expected at least one lexical hit"
    assert all(h.payload.get("owner_id") == "owner-1" for h in hits)
    assert "maternity" in hits[0].payload["text_content"].lower()


def test_dense_search_ranks_by_cosine_similarity(store, fake_client):
    blocks = _blocks(["Cancer cover pays up to 5 lakh", "Maternity waiting period 24 months"])
    embeddings = [_vec(hot=0), _vec(hot=1)]
    asyncio.run(store.upsert("doc-1", blocks, embeddings, owner_id="owner-1"))

    # Query vector identical to chunk 0's embedding -> highest similarity to it.
    hits = asyncio.run(
        store.search(
            _vec(hot=0),
            limit=5,
            filters={"owner_id": "owner-1", "embedding_model": "text-embedding-3-small"},
        )
    )
    assert hits, "expected at least one dense hit"
    assert hits[0].payload["text_content"] == "Cancer cover pays up to 5 lakh"
    assert hits[0].score > 0.99


def test_owner_isolation_on_search(store, fake_client):
    asyncio.run(store.upsert("doc-1", _blocks(["Owner one secret clause"]), [_vec(hot=0)], owner_id="owner-1"))
    asyncio.run(store.upsert("doc-2", _blocks(["Owner two secret clause"]), [_vec(hot=1)], owner_id="owner-2"))

    hits = asyncio.run(store.search_fts("secret clause", limit=10, filters={"owner_id": "owner-2"}))
    assert hits
    assert all(h.payload["owner_id"] == "owner-2" for h in hits)
    assert all(h.payload["document_id"] == "doc-2" for h in hits)


def test_contract_guard_requires_owner_for_upsert(store):
    with pytest.raises(ValueError):
        asyncio.run(store.upsert("doc-1", _blocks(["x"]), [_vec()], owner_id=""))


def test_contract_guard_rejects_non_1536_embedding(store):
    with pytest.raises(ValueError):
        asyncio.run(
            store.upsert("doc-1", [{"embedding_model": "m", "text": "x"}], [[0.1, 0.2]], owner_id="owner-1")
        )


def test_contract_guard_rejects_missing_embedding_model(store):
    with pytest.raises(ValueError):
        asyncio.run(store.upsert("doc-1", [{"text": "x"}], [_vec()], owner_id="owner-1"))


def test_search_guard_requires_owner(store):
    with pytest.raises(ValueError):
        asyncio.run(store.search(_vec(), limit=5, filters={}))


def test_delete_removes_only_matching_rows(store, fake_client):
    asyncio.run(store.upsert("doc-1", _blocks(["keep me"]), [_vec(hot=0)], owner_id="owner-1"))
    deleted = asyncio.run(store.delete("doc-1", "owner-1"))
    assert deleted == 1
    assert fake_client._tables.get("document_chunks") == []


def test_adjacent_chunks_deterministic_fallback(store, fake_client):
    blocks = _blocks(["first chunk text", "second chunk text"])
    asyncio.run(store.upsert("doc-1", blocks, [_vec(hot=0), _vec(hot=1)], owner_id="owner-1"))
    chunk_id = fake_client._tables["document_chunks"][0]["id"]

    adj = asyncio.run(store.get_adjacent_chunks([chunk_id], "owner-1"))
    assert len(adj) == 1
    assert adj[0].payload["document_id"] == "doc-1"
    assert adj[0].payload["text_content"] == "second chunk text"
