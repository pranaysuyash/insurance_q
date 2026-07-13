import pytest

from src.app import main
from src.models.user import User


@pytest.mark.asyncio
async def test_liveness_does_not_depend_on_external_services():
    assert await main.liveness_check() == {"status": "live", "version": "2.0.0"}


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
