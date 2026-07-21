from datetime import datetime
from io import BytesIO

import pytest
from fastapi import BackgroundTasks
from starlette.datastructures import UploadFile
from starlette.requests import Request
from fastapi import HTTPException
from PIL import Image

from src.api import document as document_api
from src.app import main as main_app
from src.models.document import Document
from src.models.user import User
from src.services.document_repository import SQLiteDocumentRepository
from src.services.document_object_store import LocalDocumentObjectStore


OWNER_A = User(uid="anon:owner-a", identity_type="anonymous", email=None, phone=None, display_name=None)
OWNER_B = User(uid="anon:owner-b", identity_type="anonymous", email=None, phone=None, display_name=None)


def _png_bytes() -> bytes:
    content = BytesIO()
    Image.new("RGB", (8, 8), color="white").save(content, format="PNG")
    return content.getvalue()


@pytest.fixture(autouse=True)
def isolated_documents(tmp_path, monkeypatch):
    document_api.set_document_repository(
        SQLiteDocumentRepository(str(tmp_path / "document-metadata.db"))
    )
    document_api.set_document_object_store(LocalDocumentObjectStore(str(tmp_path / "documents")))
    monkeypatch.setattr(document_api, "processing_service", None)
    monkeypatch.setattr(document_api, "job_outbox_service", None)


def _document(owner: User) -> Document:
    return Document(
        id="document-a",
        filename="policy.pdf",
        size=100,
        upload_date=datetime.utcnow(),
        user_uid=owner.uid,
        file_path="/nonexistent/policy.pdf",
    )


@pytest.mark.asyncio
async def test_status_is_hidden_from_a_different_anonymous_owner():
    document_api.document_repository.create(_document(OWNER_A))

    owned = await document_api.get_document_processing_status("document-a", OWNER_A)
    assert owned["document_id"] == "document-a"

    with pytest.raises(HTTPException) as error:
        await document_api.get_document_processing_status("document-a", OWNER_B)
    assert error.value.status_code == 404


@pytest.mark.asyncio
async def test_document_responses_do_not_expose_storage_or_owner_internals():
    document_api.document_repository.create(_document(OWNER_A))

    detail = await document_api.get_document("document-a", OWNER_A)
    listing = await document_api.get_documents(page=1, limit=10, current_user=OWNER_A)

    for payload in (detail, listing["documents"][0]):
        assert "file_path" not in payload
        assert "user_uid" not in payload
        assert "source_hash" not in payload
        assert "metadata" not in payload


@pytest.mark.asyncio
async def test_root_query_forces_verified_owner_filter(monkeypatch):
    received = {}

    class FakeProcessor:
        async def query_documents(self, query, filters):
            received["query"] = query
            received["filters"] = filters
            return {"answer": "grounded", "sources": []}

    monkeypatch.setattr(main_app, "document_processing_service", FakeProcessor())
    request = main_app.QueryRequest(
        query="What is covered?",
        filters={"owner_id": "attacker", "document_id": "document-a"},
    )

    response = await main_app.query_documents(request, OWNER_A)

    assert response.answer == "grounded"
    assert received["filters"]["owner_id"] == OWNER_A.uid
    assert received["filters"]["document_ids"] == ["document-a"]


@pytest.mark.asyncio
async def test_restart_recovery_loads_source_from_durable_store(monkeypatch):
    document = _document(OWNER_A)
    document.status = "received"
    document.file_path = document_api.document_object_store.put(
        document.id, OWNER_A.uid, document.filename, b"policy bytes"
    )
    document_api.document_repository.create(document)
    monkeypatch.setattr(document_api, "processing_service", object())
    received = {}

    async def fake_process(document_id, content, filename, processing_mode, owner_id):
        received.update(
            document_id=document_id,
            content=content,
            filename=filename,
            processing_mode=processing_mode,
            owner_id=owner_id,
        )

    monkeypatch.setattr(document_api, "process_document_background", fake_process)

    assert await document_api.recover_interrupted_document_processing() == 1
    assert received == {
        "document_id": document.id,
        "content": b"policy bytes",
        "filename": document.filename,
        "processing_mode": "full",
        "owner_id": OWNER_A.uid,
    }


@pytest.mark.asyncio
async def test_duplicate_source_is_idempotent_before_object_storage(monkeypatch):
    monkeypatch.setattr(document_api, "processing_service", None)
    monkeypatch.setattr(document_api, "check_all_rate_limits", lambda **_: (True, "ok"))
    monkeypatch.setattr(document_api, "log_usage_attempt", lambda **_: None)
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/documents/upload",
            "headers": [],
            "client": ("127.0.0.1", 5000),
        }
    )

    first = await document_api.upload_document(
        request,
        BackgroundTasks(),
        [UploadFile(filename="policy.png", file=BytesIO(_png_bytes()))],
        processing_mode="full",
        pdf_password=None,
        processing_consent=True,
        processing_consent_version="test-policy-v1",
        on_device_ocr_text=None,
        metadata=None,
        user_email=None,
        user_phone=None,
        consent=False,
        current_user=OWNER_A,
    )
    replay = await document_api.upload_document(
        request,
        BackgroundTasks(),
        [UploadFile(filename="renamed.png", file=BytesIO(_png_bytes()))],
        processing_mode="full",
        pdf_password=None,
        processing_consent=True,
        processing_consent_version="test-policy-v1",
        on_device_ocr_text=None,
        metadata=None,
        user_email=None,
        user_phone=None,
        consent=False,
        current_user=OWNER_A,
    )

    assert first["documents"][0]["id"] == replay["documents"][0]["id"]
    assert replay["documents"][0]["idempotent_replay"] is True
    assert len(document_api.document_repository.list_for_owner(OWNER_A.uid)) == 1


@pytest.mark.asyncio
async def test_upload_enqueues_object_reference_without_document_bytes(monkeypatch):
    class FakeOutbox:
        def __init__(self):
            self.requests = []

        async def enqueue(self, request):
            self.requests.append(request)

    outbox = FakeOutbox()
    monkeypatch.setattr(document_api, "job_outbox_service", outbox)
    monkeypatch.setattr(document_api, "check_all_rate_limits", lambda **_: (True, "ok"))
    monkeypatch.setattr(document_api, "log_usage_attempt", lambda **_: None)
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/documents/upload",
            "headers": [],
            "client": ("127.0.0.1", 5000),
        }
    )

    response = await document_api.upload_document(
        request,
        BackgroundTasks(),
        [UploadFile(filename="policy.png", file=BytesIO(_png_bytes()))],
        processing_mode="full",
        pdf_password=None,
        processing_consent=True,
        processing_consent_version="test-policy-v1",
        on_device_ocr_text=None,
        metadata=None,
        user_email=None,
        user_phone=None,
        consent=False,
        current_user=OWNER_A,
    )

    assert response["documents"][0]["status"] == "received"
    payload = outbox.requests[0].payload
    assert "object_reference" in payload
    assert "file_content_b64" not in payload
