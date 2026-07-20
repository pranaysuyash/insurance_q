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
    store = SupabaseVectorStore("http://fake.url", "fake-key")
    store._client = mock_supabase_client
    return store

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
