from pathlib import Path
from io import BytesIO

import fitz
import pytest
from fastapi import BackgroundTasks, HTTPException
from starlette.datastructures import UploadFile
from starlette.requests import Request

from src.api import document as document_api
from src.models.user import User
from src.utils.pdf_access import PdfPasswordError, unlock_pdf


def _encrypted_fixture(path: Path) -> None:
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), "Private policy fixture: POLICY-LOCAL-001")
    document.save(
        path,
        encryption=fitz.PDF_ENCRYPT_AES_256,
        owner_pw="fixture-owner-password",
        user_pw="fixture-user-password",
    )
    document.close()


def test_password_protected_pdf_requires_a_password(tmp_path: Path):
    path = tmp_path / "locked-policy.pdf"
    _encrypted_fixture(path)
    document = fitz.open(path)

    with pytest.raises(PdfPasswordError) as error:
        unlock_pdf(document, None)

    document.close()
    assert error.value.code == "pdf_password_required"


def test_password_protected_pdf_rejects_wrong_password(tmp_path: Path):
    path = tmp_path / "locked-policy.pdf"
    _encrypted_fixture(path)
    document = fitz.open(path)

    with pytest.raises(PdfPasswordError) as error:
        unlock_pdf(document, "wrong-password")

    document.close()
    assert error.value.code == "pdf_password_invalid"


def test_password_protected_pdf_unlocks_in_memory_only(tmp_path: Path):
    path = tmp_path / "locked-policy.pdf"
    _encrypted_fixture(path)
    document = fitz.open(path)

    unlock_pdf(document, "fixture-user-password")

    assert "POLICY-LOCAL-001" in document[0].get_text()
    document.close()


@pytest.mark.asyncio
async def test_upload_rejects_locked_pdf_before_creating_document(tmp_path: Path, monkeypatch):
    path = tmp_path / "locked-policy.pdf"
    _encrypted_fixture(path)
    monkeypatch.setattr(document_api, "processing_service", None)
    monkeypatch.setattr(
        document_api, "check_all_rate_limits", lambda **_: (True, "accepted")
    )
    monkeypatch.setattr(document_api, "log_usage_attempt", lambda **_: None)
    repository_calls = []
    object_store_calls = []

    class Repository:
        def create(self, document):
            repository_calls.append(document)

    class ObjectStore:
        def put(self, *args):
            object_store_calls.append(args)
            return "not-used"

    monkeypatch.setattr(document_api, "document_repository", Repository())
    monkeypatch.setattr(document_api, "document_object_store", ObjectStore())
    request = Request(
        {"type": "http", "method": "POST", "headers": [], "client": ("127.0.0.1", 1)}
    )
    upload = UploadFile(filename="locked-policy.pdf", file=BytesIO(path.read_bytes()))
    user = User(
        uid="anon:password-test",
        identity_type="anonymous",
        email=None,
        phone=None,
        display_name=None,
    )

    with pytest.raises(HTTPException) as error:
        await document_api.upload_document(
            request=request,
            background_tasks=BackgroundTasks(),
            files=[upload],
            pdf_password=None,
            current_user=user,
        )

    assert error.value.status_code == 422
    assert error.value.detail["code"] == "pdf_password_required"
    assert repository_calls == []
    assert object_store_calls == []
