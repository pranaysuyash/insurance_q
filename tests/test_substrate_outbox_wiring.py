from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from src.services.document_processing_service import DocumentProcessingService
from src.workers.substrate_extraction_handler import handle_substrate_extraction


@pytest.mark.asyncio
async def test_production_evidence_uses_outbox_without_raw_page_text(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    outbox = MagicMock()
    outbox.enqueue = AsyncMock()
    service = DocumentProcessingService(job_outbox_service=outbox)
    service.policy_extraction_service = None
    service._evidence_pipeline_enabled = lambda: True
    service._extract_text = AsyncMock(return_value={
        "full_text": "private policy text",
        "page_texts": {1: "private policy text"},
        "page_images": {},
    })

    result = await service.process_document_full(
        b"source", "policy.pdf", document_id="doc-1", owner_id="owner-1"
    )

    request = outbox.enqueue.await_args.args[0]
    assert request.payload == {"document_id": "doc-1", "owner_id": "owner-1"}
    assert "private policy text" not in str(request.payload)
    assert result["stages"]["evidence_extraction"]["status"] == "queued"


@pytest.mark.asyncio
async def test_substrate_handler_requires_owner_scoped_document(monkeypatch):
    repository = MagicMock()
    repository.get.return_value = None
    monkeypatch.setattr(
        "src.services.document_repository.create_document_repository",
        lambda: repository,
    )
    job = SimpleNamespace(
        id="job-1",
        payload={"document_id": "doc-1", "owner_id": "owner-1"},
    )

    with pytest.raises(ValueError, match="not owned"):
        await handle_substrate_extraction(job)
    repository.get.assert_called_once_with("doc-1", "owner-1")
