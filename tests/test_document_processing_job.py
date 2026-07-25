from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from src.models.document import Document
from src.services.document_processing_job import _apply_classification, run_document_processing_job
from src.services.document_repository import SQLiteDocumentRepository
from src.services.document_processing_service import DocumentProcessingService


class _Service:
    rag_pipeline = None

    async def process_document_full(self, **_kwargs):
        return {
            "status": "completed",
            "stages": {"file_storage": {"status": "completed"}},
        }


class _FailOnceService:
    rag_pipeline = None

    def __init__(self):
        self.calls = 0

    async def process_document_full(self, **_kwargs):
        self.calls += 1
        if self.calls == 1:
            raise RuntimeError("temporary processor outage")
        return {
            "status": "completed",
            "stages": {"file_storage": {"status": "completed"}},
        }


def test_processing_status_exposes_metadata_not_document_content(tmp_path):
    repository = SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    service = DocumentProcessingService(document_repository=repository)
    service.processing_status["doc-1"] = {
        "status": "processing",
        "owner_id": "owner-1",
        "stages": {
            "ocr": {
                "status": "completed",
                "full_text": "private policy text",
                "page_images": {1: b"\x89PNG"},
                "native_text_pages": [1],
            }
        },
    }

    snapshot = service.get_processing_status("doc-1", "owner-1")

    assert snapshot["stages"] == {
        "ocr": {"status": "completed", "native_text_pages": [1]}
    }


@pytest.mark.asyncio
async def test_runner_claims_and_persists_terminal_state(tmp_path):
    repository = SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    repository.create(
        Document(
            id="doc-1",
            filename="policy.pdf",
            size=3,
            upload_date=datetime.utcnow(),
            user_uid="owner-1",
            file_path="supabase://bucket/doc-1/policy.pdf",
        )
    )

    result = await run_document_processing_job(
        service=_Service(),
        repository=repository,
        document_id="doc-1",
        filename="policy.pdf",
        processing_mode="full",
        owner_id="owner-1",
        file_content=b"pdf",
    )

    assert result["status"] == "completed"
    persisted = repository.get("doc-1", "owner-1")
    assert persisted.status == "completed"
    assert persisted.processing_lease_expires_at is None
    assert persisted.processing_completed_at is not None


@pytest.mark.asyncio
async def test_runner_does_not_process_a_live_duplicate_claim(tmp_path):
    repository = SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    repository.create(
        Document(
            id="doc-2",
            filename="policy.pdf",
            size=3,
            upload_date=datetime.utcnow(),
            status="processing",
            user_uid="owner-1",
            file_path="supabase://bucket/doc-2/policy.pdf",
        )
    )

    result = await run_document_processing_job(
        service=_Service(),
        repository=repository,
        document_id="doc-2",
        filename="policy.pdf",
        processing_mode="full",
        owner_id="owner-1",
        file_content=b"pdf",
    )

    assert result is None
    assert repository.get("doc-2", "owner-1").status == "processing"


@pytest.mark.asyncio
async def test_runner_does_not_claim_a_document_marked_for_deletion(tmp_path):
    repository = SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    repository.create(
        Document(
            id="doc-deleting",
            filename="policy.pdf",
            size=3,
            upload_date=datetime.utcnow(),
            status="deleting",
            user_uid="owner-1",
            file_path="supabase://bucket/doc-deleting/policy.pdf",
        )
    )

    result = await run_document_processing_job(
        service=_Service(),
        repository=repository,
        document_id="doc-deleting",
        filename="policy.pdf",
        processing_mode="full",
        owner_id="owner-1",
        file_content=b"pdf",
    )

    assert result is None
    assert repository.get("doc-deleting", "owner-1").status == "deleting"


@pytest.mark.asyncio
async def test_retryable_worker_failure_returns_document_to_received(tmp_path):
    repository = SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    repository.create(
        Document(
            id="doc-retry",
            filename="policy.pdf",
            size=3,
            upload_date=datetime.utcnow(),
            user_uid="owner-1",
            file_path="supabase://bucket/doc-retry/policy.pdf",
        )
    )
    service = _FailOnceService()

    with pytest.raises(RuntimeError, match="temporary processor outage"):
        await run_document_processing_job(
            service=service,
            repository=repository,
            document_id="doc-retry",
            filename="policy.pdf",
            processing_mode="full",
            owner_id="owner-1",
            file_content=b"pdf",
            terminal_failure_on_exception=False,
        )

    retryable = repository.get("doc-retry", "owner-1")
    assert retryable.status == "received"
    assert retryable.processing_lease_expires_at is None
    assert retryable.error_message is None

    result = await run_document_processing_job(
        service=service,
        repository=repository,
        document_id="doc-retry",
        filename="policy.pdf",
        processing_mode="full",
        owner_id="owner-1",
        file_content=b"pdf",
        terminal_failure_on_exception=True,
    )
    assert result["status"] == "completed"
    assert repository.get("doc-retry", "owner-1").status == "completed"


@pytest.mark.asyncio
async def test_policy_projection_failure_is_recorded_separately_from_classification():
    document = Document(
        id="doc-3",
        filename="policy.pdf",
        size=3,
        upload_date=datetime.utcnow(),
        user_uid="owner-1",
        file_path="supabase://bucket/doc-3/policy.pdf",
    )
    classifier = MagicMock()
    classifier.classify_document = AsyncMock(return_value={
        "document_type": "Health Insurance",
        "insurer": "Acme",
        "policy_number": "P-12345",
        "confidence": 0.9,
    })
    service = SimpleNamespace(rag_pipeline=None)
    result = {
        "status": "completed",
        "stages": {
            "ocr": {"full_text": "health insurance policy text"},
            "rag_ingestion": {"sections": []},
        },
    }

    with (
        patch("src.utils.document_classifier.get_document_classifier", return_value=classifier),
        patch(
            "src.services.policy_domain_service.sync_document",
            side_effect=RuntimeError("projection unavailable"),
        ),
    ):
        await _apply_classification(document, result, service, "doc-3")

    assert document.document_type == "Health Insurance"
    assert result["stages"]["policy_domain_projection"]["status"] == "failed"
    assert document.metadata["policy_domain_projection_error_type"] == "RuntimeError"
