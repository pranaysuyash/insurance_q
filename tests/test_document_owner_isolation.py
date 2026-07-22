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
async def test_root_query_preserves_safe_source_navigation_metadata(monkeypatch):
    class FakeProcessor:
        async def query_documents(self, query, filters):
            return {
                "result": {
                    "answer": "grounded",
                    "sources": [{
                        "index": 1,
                        "id": "chunk-1",
                        "document_id": "document-a",
                        "page_number": 4,
                        "page_artifact_id": "page-4",
                        "text": "The deductible is 5000.",
                        "source_text": "private verifier text",
                        "retrieval_text": "private generated context",
                    }],
                    "citations": [{
                        "source_index": 1,
                        "quote": "The deductible is 5000.",
                        "document_id": "document-a",
                        "page_number": 4,
                    }],
                }
            }

    monkeypatch.setattr(main_app, "document_processing_service", FakeProcessor())
    response = await main_app.query_documents(
        main_app.QueryRequest(query="What is the deductible?"), OWNER_A
    )

    assert response.sources == [{
        "index": 1,
        "id": "chunk-1",
        "document_id": "document-a",
        "page_number": 4,
        "page_artifact_id": "page-4",
        "text": "The deductible is 5000.",
    }]


@pytest.mark.asyncio
async def test_form_query_surface_is_explicitly_deprecated(monkeypatch, caplog):
    class FakeProcessor:
        async def query_documents(self, query, filters):
            return {"answer": "grounded", "sources": []}

    monkeypatch.setattr(document_api, "processing_service", FakeProcessor())
    with caplog.at_level("WARNING", logger="src.api.document"):
        result = await document_api.query_documents(
            Request({"type": "http"}),
            query="What is covered?",
            document_ids=None,
            current_user=OWNER_A,
        )

    assert result["answer"] == "grounded"
    assert "deprecated_query_route_used" in caplog.text


@pytest.mark.asyncio
async def test_delete_traverses_artifact_inventory_after_source_delete(monkeypatch):
    document = _document(OWNER_A)
    document.file_path = document_api.document_object_store.put(
        document.id, OWNER_A.uid, document.filename, b"policy bytes"
    )
    document_api.document_repository.create(document)
    traversed = []
    monkeypatch.setattr(
        "src.services.artifact_registry.delete_document_artifacts",
        lambda document_id, owner_id: traversed.append((document_id, owner_id)) or {"attempted": 0, "deleted": 0},
    )

    response = await document_api.delete_document(document.id, OWNER_A)

    assert response["id"] == document.id
    assert traversed == [(document.id, OWNER_A.uid)]
    assert document_api.document_repository.get(document.id, OWNER_A.uid) is None


@pytest.mark.asyncio
async def test_delete_fences_processing_before_source_cleanup(monkeypatch):
    document = _document(OWNER_A)
    document.file_path = document_api.document_object_store.put(
        document.id, OWNER_A.uid, document.filename, b"policy bytes"
    )
    document_api.document_repository.create(document)
    observed = []
    original_delete = document_api.document_object_store.delete

    def observe_delete(path):
        observed.append(document_api.document_repository.get(document.id, OWNER_A.uid).status)
        return original_delete(path)

    monkeypatch.setattr(document_api.document_object_store, "delete", observe_delete)
    monkeypatch.setattr("src.services.artifact_registry.delete_document_artifacts", lambda *_args: {"attempted": 0, "deleted": 0})

    await document_api.delete_document(document.id, OWNER_A)

    assert observed == ["deleting"]


@pytest.mark.asyncio
async def test_delete_keeps_metadata_when_artifact_inventory_delete_fails(monkeypatch):
    document = _document(OWNER_A)
    document.file_path = document_api.document_object_store.put(
        document.id, OWNER_A.uid, document.filename, b"policy bytes"
    )
    document_api.document_repository.create(document)
    def fail_inventory(_document_id, _owner_id):
        raise RuntimeError("inventory down")

    monkeypatch.setattr(
        "src.services.artifact_registry.delete_document_artifacts", fail_inventory
    )

    with pytest.raises(HTTPException) as error:
        await document_api.delete_document(document.id, OWNER_A)

    assert error.value.status_code == 503
    assert document_api.document_repository.get(document.id, OWNER_A.uid) is not None


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
async def test_upload_in_progress_reservation_returns_retryable_conflict(monkeypatch):
    class InProgressReservation:
        def reserve(self, **_kwargs):
            return {
                "allowed": False,
                "reason": "upload_in_progress",
                "reservation_id": "reservation-1",
            }

    monkeypatch.setattr(
        document_api,
        "production_policy_slot_reservations_enabled",
        lambda: True,
    )
    monkeypatch.setattr(
        document_api.PolicySlotReservationService,
        "from_env",
        classmethod(lambda cls: InProgressReservation()),
    )
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

    with pytest.raises(HTTPException) as error:
        await document_api.upload_document(
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

    assert error.value.status_code == 409
    assert error.value.detail["code"] == "upload_in_progress"


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


@pytest.mark.asyncio
async def test_upload_encrypts_sensitive_processing_inputs_in_outbox_payload(monkeypatch):
    class FakeOutbox:
        def __init__(self):
            self.requests = []

        async def enqueue(self, request):
            self.requests.append(request)

    outbox = FakeOutbox()
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("PROCESSING_PAYLOAD_ENCRYPTION_KEY", "k" * 32)
    monkeypatch.setattr(document_api, "job_outbox_service", outbox)
    monkeypatch.setattr(
        "src.utils.anti_abuse.check_supabase_rate_limits",
        lambda *_: (True, "ok"),
    )
    monkeypatch.setattr(document_api, "check_all_rate_limits", lambda **_: (True, "ok"))
    monkeypatch.setattr(document_api, "log_usage_attempt", lambda **_: None)
    request = Request({
        "type": "http", "method": "POST", "path": "/documents/upload",
        "headers": [], "client": ("127.0.0.1", 5000),
    })

    await document_api.upload_document(
        request,
        BackgroundTasks(),
        [UploadFile(filename="locked.png", file=BytesIO(_png_bytes()))],
        processing_mode="full",
        pdf_password="private-password",
        processing_consent=True,
        processing_consent_version="test-policy-v1",
        on_device_ocr_text="private OCR text",
        metadata=None,
        user_email=None,
        user_phone=None,
        consent=False,
        current_user=OWNER_A,
    )

    payload = outbox.requests[0].payload
    assert "pdf_password" not in payload
    assert "on_device_ocr_text" not in payload
    assert "processing_inputs_envelope" in payload
    assert "private-password" not in str(payload)
    assert "private OCR text" not in str(payload)


@pytest.mark.asyncio
async def test_production_upload_without_outbox_rolls_back_persisted_source(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setattr(document_api, "job_outbox_service", None)
    monkeypatch.setattr(document_api, "processing_service", object())
    monkeypatch.setattr(
        "src.utils.anti_abuse.check_supabase_rate_limits",
        lambda *_: (True, "ok"),
    )
    monkeypatch.setattr("src.services.artifact_registry.record_source", lambda *args: None)
    monkeypatch.setattr(document_api, "log_usage_attempt", lambda **_: None)
    marked = []
    monkeypatch.setattr(
        "src.services.artifact_registry.mark_document_deleted",
        lambda document_id: marked.append(document_id),
    )
    request = Request({
        "type": "http",
        "method": "POST",
        "path": "/documents/upload",
        "headers": [],
        "client": ("127.0.0.1", 5000),
    })

    with pytest.raises(HTTPException) as error:
        await document_api.upload_document(
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

    assert error.value.status_code == 503
    assert marked
    assert document_api.document_repository.list_for_owner(OWNER_A.uid) == []
