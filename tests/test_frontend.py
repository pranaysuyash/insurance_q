import pytest
from fastapi.testclient import TestClient
from src.frontend.app import app
import json
from unittest.mock import patch

client = TestClient(app)

def test_home_page():
    """Test that the home page loads successfully."""
    response = client.get("/")
    assert response.status_code == 200
    assert "Insurance Policy Parser & QA" in response.text

@pytest.mark.asyncio
async def test_upload_document(aioresponses):
    """Test document upload endpoint."""
    with aioresponses() as m:
        # Mock OCR service response
        m.post("http://localhost:8001/process", payload={
            "message": "Document processed successfully",
            "doc_key": "test123"
        })
        m.get("http://localhost:8001/text/test123", payload={
            "text": "Sample extracted text"
        })

        # Create test file data
        files = {
            "file": ("test.pdf", b"test content", "application/pdf")
        }
        
        response = client.post("/upload", files=files)
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "Document processed successfully"
        assert "text" in data
        assert data["text"] == "Sample extracted text"

@pytest.mark.asyncio
async def test_query_document(aioresponses):
    """Test document query endpoint."""
    with aioresponses() as m:
        # Mock RAG service response
        m.post("http://localhost:8000/query", payload={
            "answer": "Test answer",
            "sources": ["page 1", "page 2"]
        })

        response = client.post(
            "/query",
            json={"query": "test question"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "answer" in data
        assert "sources" in data
        assert data["answer"] == "Test answer"

def test_health_check():
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"} 