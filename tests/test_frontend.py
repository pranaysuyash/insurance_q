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
    assert "CoverWise" in response.text

@pytest.mark.asyncio
async def test_upload_document(mocker):
    """Test document upload endpoint."""
    # Mock the global http_client variable with AsyncMock
    mock_client = mocker.AsyncMock()
    # Mock OCR service /process_and_ingest response
    mock_client.post.return_value = mocker.Mock(
        status_code=200,
        json=lambda: {
            "message": "Document processed successfully",
            "filename": "test.pdf",
            "ocr_doc_key": "test.pdf",
            "rag_ingestion_status": "success",
            "rag_ingestion_detail": "Ingested successfully",
            "ocr_metadata": {"page_count": 1}
        }
    )
    # Mock OCR service /cached_ocr_data/{doc_id} response
    mock_client.get.return_value = mocker.Mock(
        status_code=200,
        json=lambda: {
            "doc_id": "test.pdf",
            "cached_ocr_result": {
                "result": {
                    "full_text": "Sample extracted text",
                    "layout_elements": []
                }
            }
        }
    )
    mocker.patch("src.frontend.app.http_client", mock_client)

    # Create test file data
    files = {
        "file": ("test.pdf", b"test content", "application/pdf")
    }
    
    response = client.post("/upload", files=files)
    assert response.status_code == 200
    data = response.json()
    assert data["message"].startswith("OCR processing for")
    assert "text" in data
    assert data["text"] == "Sample extracted text"

@pytest.mark.asyncio
async def test_query_document(mocker):
    """Test document query endpoint."""
    # Mock the global http_client variable with AsyncMock
    mock_client = mocker.AsyncMock()
    # Mock RAG service response (if needed)
    mock_client.post.return_value = mocker.Mock(
        status_code=200,
        json=lambda: {
            "answer": "Test answer",
            "sources": ["page 1", "page 2"]
        }
    )
    mocker.patch("src.frontend.app.http_client", mock_client)

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
    data = response.json()
    assert data["status"] == "healthy"
    assert "ocr_service_target" in data
    assert "rag_service_target" in data 
