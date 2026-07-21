from datetime import datetime

import pytest

from src.models.document import Document
from src.services.document_processing_job import run_document_processing_job
from src.services.document_repository import SQLiteDocumentRepository


class _Service:
    rag_pipeline = None

    async def process_document_full(self, **_kwargs):
        return {
            "status": "completed",
            "stages": {"file_storage": {"status": "completed"}},
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
