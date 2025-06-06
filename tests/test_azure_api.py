import pytest
import httpx
import os
from datetime import datetime
import logging
import pytest_asyncio

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Azure API endpoints
FRONTEND_URL = "https://insurance-frontend-app.azurewebsites.net"
OCR_URL = "https://insurance-ocr-app.azurewebsites.net"
RAG_URL = "https://insurance-rag-app.azurewebsites.net"

@pytest_asyncio.fixture
async def http_client():
    """Create an async HTTP client for testing."""
    async with httpx.AsyncClient(timeout=30.0) as client:
        yield client

@pytest.mark.asyncio
async def test_frontend_health(http_client):
    """Test the frontend service health endpoint."""
    response = await http_client.get(f"{FRONTEND_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "ocr_service_target" in data
    assert "rag_service_target" in data
    logger.info("Frontend health check passed")

@pytest.mark.asyncio
async def test_ocr_health(http_client):
    """Test the OCR service health endpoint."""
    response = await http_client.get(f"{OCR_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    logger.info("OCR health check passed")

@pytest.mark.asyncio
async def test_rag_health(http_client):
    """Test the RAG service health endpoint."""
    response = await http_client.get(f"{RAG_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    logger.info("RAG health check passed")

@pytest.mark.asyncio
async def test_document_upload_and_query(http_client):
    """Test the complete document upload and query flow."""
    # 1. Upload a test document
    test_file_path = "tests/test_data/sample_insurance.pdf"
    if not os.path.exists(test_file_path):
        pytest.skip(f"Test file not found: {test_file_path}")
    
    with open(test_file_path, "rb") as f:
        files = {"file": ("sample_insurance.pdf", f, "application/pdf")}
        response = await http_client.post(f"{FRONTEND_URL}/upload", files=files)
    
    assert response.status_code == 200
    upload_data = response.json()
    assert "message" in upload_data
    assert "doc_key" in upload_data
    assert "text" in upload_data
    logger.info("Document upload successful")

    # 2. Query the uploaded document
    query_data = {"query": "What is the policy number?"}
    response = await http_client.post(f"{FRONTEND_URL}/query", json=query_data)
    
    assert response.status_code == 200
    query_result = response.json()
    assert "answer" in query_result
    assert "sources" in query_result
    logger.info("Document query successful")

@pytest.mark.asyncio
async def test_ocr_service_endpoints(http_client):
    """Test OCR service specific endpoints."""
    # 1. Test process_and_ingest endpoint
    test_file_path = "tests/test_data/sample_insurance.pdf"
    if not os.path.exists(test_file_path):
        pytest.skip(f"Test file not found: {test_file_path}")
    
    with open(test_file_path, "rb") as f:
        files = {"file": ("sample_insurance.pdf", f, "application/pdf")}
        response = await http_client.post(f"{OCR_URL}/process_and_ingest", files=files)
    
    assert response.status_code == 200
    ocr_data = response.json()
    assert "message" in ocr_data
    assert "ocr_doc_key" in ocr_data
    assert "rag_ingestion_status" in ocr_data
    logger.info("OCR process_and_ingest successful")

    # 2. Test cached_ocr_data endpoint
    doc_key = ocr_data["ocr_doc_key"]
    response = await http_client.get(f"{OCR_URL}/cached_ocr_data/{doc_key}")
    assert response.status_code == 200
    cached_data = response.json()
    assert "doc_id" in cached_data
    assert "cached_ocr_result" in cached_data
    logger.info("OCR cached data retrieval successful")

@pytest.mark.asyncio
async def test_rag_service_endpoints(http_client):
    """Test RAG service specific endpoints."""
    # 1. Test ingest endpoint
    test_data = {
        "document_id": f"test_doc_{datetime.now().isoformat()}",
        "text_blocks": [
            {
                "text": "Sample insurance policy text",
                "page_number": 1,
                "block_id": "1"
            }
        ],
        "document_metadata": {
            "filename": "test_doc.pdf",
            "processed_at": datetime.now().isoformat()
        }
    }
    
    response = await http_client.post(f"{RAG_URL}/ingest", json=test_data)
    assert response.status_code == 200
    ingest_data = response.json()
    assert "message" in ingest_data
    logger.info("RAG ingestion successful")

    # 2. Test query endpoint
    query_data = {"query": "What is the sample text?"}
    response = await http_client.post(f"{RAG_URL}/query", json=query_data)
    assert response.status_code == 200
    query_result = response.json()
    assert "answer" in query_result
    assert "sources" in query_result
    logger.info("RAG query successful")

@pytest.mark.asyncio
async def test_error_handling(http_client):
    """Test error handling for various scenarios."""
    # 1. Test invalid file upload
    files = {"file": ("invalid.txt", b"invalid content", "text/plain")}
    response = await http_client.post(f"{FRONTEND_URL}/upload", files=files)
    assert response.status_code == 400
    logger.info("Invalid file upload error handling successful")

    # 2. Test invalid query format
    response = await http_client.post(f"{FRONTEND_URL}/query", json={})
    assert response.status_code == 422
    logger.info("Invalid query format error handling successful")

    # 3. Test non-existent document query
    response = await http_client.post(
        f"{FRONTEND_URL}/query",
        json={"query": "test query", "doc_id": "non_existent_doc"}
    )
    assert response.status_code in [404, 400]
    logger.info("Non-existent document error handling successful") 