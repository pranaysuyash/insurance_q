import pytest
import httpx
import os
import logging
import pytest_asyncio

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Integration tests must name the deployment they exercise. The historical
# Azure hostnames were retired, and silently probing them made the normal test
# suite report unrelated DNS failures. Production is now a unified API, so
# callers supply the one target explicitly when they intend to run this suite.
BASE_URL = os.getenv("COVERWISE_INTEGRATION_BASE_URL", "").rstrip("/")
RUN_MUTATING = os.getenv("COVERWISE_RUN_MUTATING_INTEGRATION") == "1"

if not BASE_URL:
    pytest.skip(
        "Set COVERWISE_INTEGRATION_BASE_URL to run deployed-service integration tests.",
        allow_module_level=True,
    )

@pytest_asyncio.fixture
async def http_client():
    """Create an async HTTP client for testing."""
    async with httpx.AsyncClient(timeout=30.0) as client:
        yield client

@pytest.mark.asyncio
async def test_frontend_health(http_client):
    """A deliberately selected unified deployment exposes healthy RAG service."""
    response = await http_client.get(f"{BASE_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["rag_status"] == "available"
    logger.info("Unified API health check passed")

@pytest.mark.asyncio
async def test_document_upload_and_query(http_client):
    """Test the deployed upload/query flow only when mutation is explicitly allowed."""
    if not RUN_MUTATING:
        pytest.skip("Set COVERWISE_RUN_MUTATING_INTEGRATION=1 to upload test data.")
    # 1. Upload a test document
    test_file_path = "tests/test_data/sample_insurance.pdf"
    if not os.path.exists(test_file_path):
        pytest.skip(f"Test file not found: {test_file_path}")
    
    with open(test_file_path, "rb") as f:
        files = {"files": ("sample_insurance.pdf", f, "application/pdf")}
        response = await http_client.post(f"{BASE_URL}/documents/upload", files=files)
    
    assert response.status_code == 200
    upload_data = response.json()
    assert "documents" in upload_data
    assert upload_data["documents"]
    logger.info("Document upload successful")

    # 2. Query the uploaded document
    query_data = {"query": "What is the policy number?"}
    response = await http_client.post(f"{BASE_URL}/query", json=query_data)
    
    assert response.status_code == 200
    query_result = response.json()
    assert "answer" in query_result
    assert "sources" in query_result
    logger.info("Document query successful")
