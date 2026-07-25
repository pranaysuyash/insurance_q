from html import unescape
from hashlib import sha256
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
import src.frontend.app as frontend_app
from src.frontend.app import app


ROOT = Path(__file__).resolve().parents[1]
client = TestClient(app)

def test_home_page():
    """Test that the home page loads successfully."""
    response = client.get("/")
    assert response.status_code == 200
    assert "CoverWise" in response.text
    assert 'href="/privacy"' in response.text
    assert 'href="/terms"' in response.text


def test_openapi_description_uses_the_product_boundary():
    response = client.get("/openapi.json")

    assert response.status_code == 200
    schema = response.json()
    description = schema["info"]["description"].lower()
    assert "plain-language summaries" in description
    assert "launch-ready marketing" not in description
    assert "/favicon.ico" not in schema["paths"]


@pytest.mark.parametrize(
    ("path", "filename", "title"),
    [
        ("/privacy", "privacy_policy.md", "Privacy Policy"),
        ("/terms", "terms_of_service.md", "Terms of Service"),
    ],
)
def test_public_legal_pages_render_the_canonical_source(path, filename, title):
    document = (ROOT / "docs/legal" / filename).read_text(encoding="utf-8")

    response = client.get(path)

    assert response.status_code == 200
    assert f"<title>{title} | CoverWise</title>" in response.text
    assert document in unescape(response.text)
    assert response.headers["cache-control"] == "no-store"
    assert "default-src 'self'" in response.headers["content-security-policy"]
    assert response.headers["referrer-policy"] == "no-referrer"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-coverwise-legal-sha256"] == sha256(
        document.encode("utf-8")
    ).hexdigest()


def test_public_legal_page_escapes_source_markup(monkeypatch, tmp_path):
    hostile_document = "# Privacy Policy\n\n<script>window.evil = true</script>\n"
    source_path = tmp_path / "privacy_policy.md"
    source_path.write_text(hostile_document, encoding="utf-8")
    monkeypatch.setitem(
        frontend_app.LEGAL_DOCUMENTS,
        "privacy",
        ("Privacy Policy", source_path),
    )

    response = client.get("/privacy")

    assert response.status_code == 200
    assert hostile_document not in response.text
    assert "&lt;script&gt;window.evil = true&lt;/script&gt;" in response.text


def test_sitemap_includes_the_public_legal_pages():
    response = client.get("/sitemap.xml")

    assert response.status_code == 200
    assert "http://testserver/privacy" in response.text
    assert "http://testserver/terms" in response.text

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

    # Create a minimal valid PDF
    minimal_pdf = (
        b"%PDF-1.4\n"
        b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
        b"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
        b"3 0 obj<</Type/Page/MediaBox[0 0 612 792]/Parent 2 0 R>>endobj\n"
        b"xref\n0 4\n"
        b"0000000000 65535 f \n"
        b"0000000009 00000 n \n"
        b"0000000058 00000 n \n"
        b"0000000115 00000 n \n"
        b"trailer<</Size 4/Root 1 0 R>>\n"
        b"startxref\n190\n%%EOF"
    )
    files = {
        "file": ("test.pdf", minimal_pdf, "application/pdf")
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
