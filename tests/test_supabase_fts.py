import pytest
from unittest.mock import Mock, AsyncMock, MagicMock
from src.services.supabase_vector_store import SupabaseVectorStore
from types import SimpleNamespace

@pytest.fixture
def mock_supabase_client():
    client = MagicMock()
    return client

@pytest.fixture
def vector_store(mock_supabase_client):
    # supabase-py validates the key shape before the client is replaced with
    # the test double; use a structurally valid JWT-shaped fixture.
    return SupabaseVectorStore("", "", client=mock_supabase_client)

@pytest.mark.asyncio
async def test_search_fts_no_owner_id(vector_store):
    with pytest.raises(ValueError, match="Supabase FTS search requires an owner_id filter"):
        await vector_store.search_fts("test query", 10, filters={})

@pytest.mark.asyncio
async def test_search_fts_calls_rpc(vector_store, mock_supabase_client):
    mock_rpc = MagicMock()
    mock_supabase_client.rpc.return_value = mock_rpc
    mock_execute = MagicMock()
    mock_rpc.execute.return_value = mock_execute
    
    mock_execute.data = [
        {"id": "test-id", "document_id": "doc1", "content": "text", "similarity": 0.9, "metadata": {"key": "val"}}
    ]

    results = await vector_store.search_fts(
        "test query", 
        10, 
        filters={"owner_id": "user1"}
    )

    mock_supabase_client.rpc.assert_called_once_with(
        "match_document_chunks_fts",
        {
            "query_text": "test query",
            "match_owner_id": "user1",
            "match_count": 10,
            "match_document_ids": None,
        }
    )
    
    assert len(results) == 1
    assert isinstance(results[0], SimpleNamespace)
    assert results[0].id == "test-id"
    assert results[0].score == 0.9
    assert results[0].payload["document_id"] == "doc1"
    assert results[0].payload["text_content"] == "text"

@pytest.mark.asyncio
async def test_search_fts_document_ids_filter(vector_store, mock_supabase_client):
    mock_rpc = MagicMock()
    mock_supabase_client.rpc.return_value = mock_rpc
    mock_execute = MagicMock()
    mock_rpc.execute.return_value = mock_execute
    
    # Return two documents, one of which should be filtered out
    mock_execute.data = [
        {"id": "id1", "document_id": "doc1", "content": "text1", "similarity": 0.9, "metadata": {}},
        {"id": "id2", "document_id": "doc2", "content": "text2", "similarity": 0.8, "metadata": {}}
    ]

    results = await vector_store.search_fts(
        "test query", 
        10, 
        filters={"owner_id": "user1", "document_ids": ["doc2"]}
    )

    # Should only return doc2
    assert len(results) == 1
    assert results[0].id == "id2"
    assert results[0].payload["document_id"] == "doc2"


@pytest.mark.asyncio
async def test_upsert_requires_owner_scope(vector_store):
    with pytest.raises(ValueError, match="Supabase upsert requires an owner_id"):
        await vector_store.upsert(
            "doc-1",
            [{"source_text": "policy text", "embedding_model": "test-model"}],
            [[0.1] * 1536],
        )


@pytest.mark.asyncio
async def test_upsert_rejects_noncanonical_embedding_dimension(vector_store):
    with pytest.raises(ValueError, match="1536-dimensional"):
        await vector_store.upsert(
            "doc-1",
            [{"source_text": "policy text", "embedding_model": "test-model"}],
            [[0.1, 0.2]],
            owner_id="owner-1",
        )


@pytest.mark.asyncio
async def test_dense_search_rejects_noncanonical_embedding_dimension(vector_store):
    with pytest.raises(ValueError, match="1536-dimensional"):
        await vector_store.search(
            [0.1, 0.2],
            10,
            filters={"owner_id": "user-1"},
        )


@pytest.mark.asyncio
async def test_adjacent_chunks_require_owner_scope(vector_store):
    with pytest.raises(ValueError, match="owner_id filter"):
        await vector_store.get_adjacent_chunks(["1"], owner_id="")


@pytest.mark.asyncio
async def test_adjacent_chunks_filter_targets_by_owner(vector_store, mock_supabase_client):
    table = mock_supabase_client.table.return_value
    table.select.return_value.eq.return_value.in_.return_value.execute.return_value.data = [
        {"target_chunk_id": 2}
    ]
    table.select.return_value.in_.return_value.eq.return_value.execute.return_value.data = [
        {
            "id": 2,
            "content": "safe",
            "metadata": {},
            "section_type": "general",
            "document_id": "doc-1",
        }
    ]

    await vector_store.get_adjacent_chunks(["1"], owner_id="owner-1")

    table.select.return_value.in_.return_value.eq.assert_called_with(
        "owner_id", "owner-1"
    )


@pytest.mark.asyncio
async def test_adjacent_chunks_falls_back_to_owner_scoped_chunk_order(vector_store):
    class Query:
        def __init__(self, rows, filters=None):
            self.rows = rows
            self.filters = filters or {}

        def select(self, _columns):
            return self

        def in_(self, key, values):
            self.filters[key] = set(values)
            return self

        def eq(self, key, value):
            self.filters[key] = value
            return self

        def execute(self):
            rows = []
            for row in self.rows:
                if "id" in self.filters and not any(
                    str(row.get("id")) == str(value) for value in self.filters["id"]
                ):
                    continue
                if "owner_id" in self.filters and row.get("owner_id") != self.filters["owner_id"]:
                    continue
                if "document_id" in self.filters and row.get("document_id") != self.filters["document_id"]:
                    continue
                if "chunk_index" in self.filters and row.get("chunk_index") not in self.filters["chunk_index"]:
                    continue
                rows.append(row)
            return SimpleNamespace(data=rows)

    rows = [
        {"id": 1, "owner_id": "owner-1", "document_id": "doc-1", "chunk_index": 1,
         "source_text": "source one", "retrieval_text": "context one", "metadata": {},
         "section_type": "general"},
        {"id": 2, "owner_id": "owner-1", "document_id": "doc-1", "chunk_index": 2,
         "source_text": "source two", "retrieval_text": "context two", "metadata": {},
         "section_type": "benefit"},
    ]

    class Client:
        def table(self, name):
            if name == "chunk_links":
                return Query([])
            return Query(rows)

    vector_store._client = Client()
    result = await vector_store.get_adjacent_chunks(["1"], owner_id="owner-1")

    assert [hit.id for hit in result] == ["2"]
    assert result[0].payload["text_content"] == "context two"
    assert result[0].payload["source_text"] == "source two"
