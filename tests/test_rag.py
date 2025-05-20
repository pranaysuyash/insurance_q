"""
Tests for the RAG pipeline.
"""
import pytest
import asyncio
from src.rag.pipeline import RAGPipeline
import torch
import numpy as np

@pytest.fixture
def rag_pipeline():
    """Create RAG pipeline instance for testing."""
    return RAGPipeline(
        embedding_model="sentence-transformers/all-MiniLM-L6-v2",  # Smaller model for testing
        collection_name="test_collection"
    )

@pytest.fixture
def sample_document():
    """Create a sample insurance policy document for testing."""
    return """
    INSURANCE POLICY DOCUMENT
    Policy Number: TEST-123
    
    COVERAGE DETAILS
    This policy provides coverage for the following:
    1. Property Damage
    2. Personal Liability
    3. Medical Payments
    
    LIMITS OF LIABILITY
    - Property Damage: $500,000
    - Personal Liability: $1,000,000
    - Medical Payments: $5,000 per person
    
    EXCLUSIONS
    This policy does not cover:
    1. Intentional acts
    2. War or military action
    3. Nuclear hazards
    """

@pytest.mark.asyncio
async def test_process_document(rag_pipeline, sample_document):
    """Test document processing."""
    result = await rag_pipeline.process_document(
        text=sample_document,
        metadata={
            "policy_number": "TEST-123",
            "document_type": "policy"
        }
    )
    
    assert result["status"] == "success"
    assert "document_id" in result
    assert "vector_count" in result
    assert result["vector_count"] > 0

@pytest.mark.asyncio
async def test_query_document(rag_pipeline, sample_document):
    """Test document querying."""
    # First process the document
    process_result = await rag_pipeline.process_document(
        text=sample_document
    )
    
    # Then query it
    query_result = await rag_pipeline.query(
        query="What is the limit for property damage?",
        filters={"doc_id": process_result["document_id"]}
    )
    
    assert "answer" in query_result
    assert "sources" in query_result
    assert len(query_result["sources"]) > 0

@pytest.mark.asyncio
async def test_generate_embeddings(rag_pipeline):
    """Test embedding generation."""
    text = "This is a test document"
    embeddings = await rag_pipeline._generate_embeddings(text, is_query=True)
    
    assert isinstance(embeddings, list)
    assert len(embeddings) == 1
    assert len(embeddings[0]) > 0  # Should have non-zero embedding dimension

@pytest.mark.asyncio
async def test_search_vectors(rag_pipeline):
    """Test vector similarity search."""
    # Create a mock query vector
    query_vector = np.random.rand(384).tolist()  # Adjust dimension based on model
    
    search_results = await rag_pipeline._search_vectors(
        query_vector=query_vector,
        filters=None,
        limit=5
    )
    
    assert isinstance(search_results, list)
    for result in search_results:
        assert "text" in result
        assert "score" in result
        assert "metadata" in result

@pytest.mark.asyncio
async def test_generate_response(rag_pipeline):
    """Test response generation."""
    query = "What is the coverage limit?"
    search_results = [
        {
            "text": "Property Damage: $500,000",
            "score": 0.95,
            "metadata": {}
        },
        {
            "text": "Personal Liability: $1,000,000",
            "score": 0.90,
            "metadata": {}
        }
    ]
    
    response = await rag_pipeline._generate_response(query, search_results)
    
    assert "answer" in response
    assert "sources" in response
    assert "query" in response
    assert response["query"] == query

@pytest.mark.asyncio
async def test_empty_query(rag_pipeline):
    """Test handling of empty query."""
    result = await rag_pipeline.query(
        query="",
        filters=None
    )
    
    assert result["status"] == "error"
    assert "error" in result

@pytest.mark.asyncio
async def test_invalid_filters(rag_pipeline):
    """Test handling of invalid filters."""
    result = await rag_pipeline.query(
        query="test query",
        filters={"invalid_key": "invalid_value"}
    )
    
    assert result["status"] == "error"
    assert "error" in result

def test_chunk_text(rag_pipeline):
    """Test text chunking functionality."""
    text = "First sentence. Second sentence. Third sentence. Fourth sentence."
    chunks = rag_pipeline._chunk_text(text, chunk_size=2)
    
    assert isinstance(chunks, list)
    assert len(chunks) > 1
    assert all(isinstance(chunk, str) for chunk in chunks)

@pytest.mark.asyncio
async def test_cache_functionality(rag_pipeline):
    """Test caching functionality."""
    query = "test query"
    filters = {"test": "value"}
    
    # First query should hit the database
    first_result = await rag_pipeline.query(query, filters)
    
    # Second query should hit the cache
    second_result = await rag_pipeline.query(query, filters)
    
    assert first_result == second_result  # Results should be identical

@pytest.mark.asyncio
async def test_process_document_with_metadata(rag_pipeline):
    """Test document processing with metadata."""
    metadata = {
        "policy_number": "TEST-123",
        "policy_type": "home",
        "issuer": "Test Insurance Co",
        "effective_date": "2024-01-01"
    }
    
    result = await rag_pipeline.process_document(
        text="Test document content",
        metadata=metadata
    )
    
    assert result["status"] == "success"
    assert "document_id" in result
    
    # Query with metadata filter
    query_result = await rag_pipeline.query(
        query="test query",
        filters={"policy_number": "TEST-123"}
    )
    
    assert query_result["status"] != "error" 