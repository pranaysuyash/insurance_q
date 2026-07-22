import json

import pytest

from src.app import main
from src.models.user import User


@pytest.mark.asyncio
async def test_liveness_does_not_depend_on_external_services():
    assert await main.liveness_check() == {"status": "live", "version": "2.0.0"}


def test_document_capability_registry_is_truthful_without_model_imports(monkeypatch):
    from src.ocr import capability_registry

    monkeypatch.setattr(capability_registry.settings, "docling_enabled", False)
    monkeypatch.setattr(capability_registry.settings, "mineru_enabled", False)
    snapshot = capability_registry.capability_registry_snapshot()

    assert snapshot["registry_version"] == "document-capabilities.v1"
    assert snapshot["capabilities"]["native_text"]["status"] == "available"
    assert snapshot["capabilities"]["figures"]["profiles"]["page_artifact_preservation"]["status"] == "available"
    assert snapshot["capabilities"]["handwriting"]["status"] == "unavailable"
    assert snapshot["capabilities"]["multilingual"]["status"] == "routing_only"
    assert snapshot["capabilities"]["vlm_annotation"]["status"] == "candidate"
    assert snapshot["capabilities"]["sentence_segmentation"]["status"] == "available"
    assert snapshot["capabilities"]["headings_and_sections"]["status"] == "candidate"
    assert snapshot["capabilities"]["selection_marks"]["status"] == "unavailable"
    assert snapshot["capabilities"]["image_understanding"]["status"] == "candidate"
    assert snapshot["capabilities"]["office_and_email_structure"]["status"] == "available"
    assert snapshot["capabilities"]["office_and_email_structure"]["profiles"]["native_html"]["status"] == "available"
    assert snapshot["capabilities"]["office_and_email_structure"]["profiles"]["native_eml"]["status"] == "available"
    assert "OPENAI_API_KEY" not in json.dumps(snapshot)


@pytest.mark.asyncio
async def test_readiness_reports_uninitialized_services(monkeypatch):
    monkeypatch.setattr(main, "rag_pipeline", None)
    monkeypatch.setattr(main, "document_processing_service", None)

    response = await main.readiness_check()

    assert response.status_code == 503
    assert b'"status":"not_ready"' in response.body


@pytest.mark.asyncio
async def test_readiness_reports_initialized_services(monkeypatch):
    monkeypatch.setattr(main, "rag_pipeline", object())
    monkeypatch.setattr(main, "document_processing_service", object())

    response = await main.readiness_check()

    assert response.status_code == 200
    assert b'"status":"ready"' in response.body


@pytest.mark.asyncio
async def test_health_exposes_safe_document_capability_registry(monkeypatch):
    class HealthyRag:
        async def _generate_embeddings_with_fallback(self, values):
            return [[0.0] for _ in values]

    monkeypatch.setattr(main, "rag_pipeline", HealthyRag())
    monkeypatch.setattr(main, "document_processing_service", object())
    monkeypatch.setattr(main, "_embedding_probe_result", None)
    response = await main.health_check()
    payload = json.loads(response.body)

    assert payload["status"] == "ok"
    assert payload["document_capabilities"]["registry_version"] == "document-capabilities.v1"
    assert "OPENAI_API_KEY" not in json.dumps(payload)


@pytest.mark.asyncio
async def test_query_logs_only_safe_metadata_when_processing_fails(monkeypatch, caplog):
    private_question = "My policy number is PRIVATE-12345"

    class FailingProcessor:
        async def query_documents(self, query, filters):
            raise RuntimeError(f"provider rejected {query}")

    monkeypatch.setattr(main, "document_processing_service", FailingProcessor())
    user = User(
        uid="anon:owner-a",
        identity_type="anonymous",
        email=None,
        phone=None,
        display_name=None,
    )

    response = await main.query_documents(main.QueryRequest(query=private_question), user)

    assert response.error == "Document query failed"
    assert private_question not in caplog.text
