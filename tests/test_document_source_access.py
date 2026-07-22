from datetime import datetime

import pytest
from fastapi import HTTPException

from src.api import document as document_api
from src.models.document import Document
from src.models.user import User
from src.services.document_repository import SQLiteDocumentRepository
from src.services.document_object_store import LocalDocumentObjectStore


OWNER_A = User(uid="anon:source-a", identity_type="anonymous", email=None, phone=None, display_name=None)
OWNER_B = User(uid="anon:source-b", identity_type="anonymous", email=None, phone=None, display_name=None)


class SignedLocalStore(LocalDocumentObjectStore):
    def create_download_url(self, object_reference: str, expires_seconds: int = 900):
        return "https://storage.example.test/signed-source"


@pytest.fixture(autouse=True)
def isolated_documents(tmp_path):
    document_api.set_document_repository(
        SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    )
    document_api.set_document_object_store(SignedLocalStore(str(tmp_path / "files")))


@pytest.mark.asyncio
async def test_source_url_is_owner_scoped_and_does_not_expose_object_reference():
    document = Document(
        id="source-doc", filename="policy.pdf", size=42,
        upload_date=datetime.utcnow(), user_uid=OWNER_A.uid,
        file_path="/private/source-doc_policy.pdf",
    )
    document_api.document_repository.create(document)

    payload = await document_api.get_document_source_url("source-doc", OWNER_A)
    assert payload == {
        "document_id": "source-doc", "filename": "policy.pdf", "size": 42,
        "url": "https://storage.example.test/signed-source",
        "expires_in_seconds": 900,
    }
    assert "/private/" not in str(payload)

    with pytest.raises(HTTPException) as error:
        await document_api.get_document_source_url("source-doc", OWNER_B)
    assert error.value.status_code == 404


@pytest.mark.asyncio
async def test_source_url_rejects_local_store_without_signed_download_support(tmp_path):
    document_api.set_document_object_store(LocalDocumentObjectStore(str(tmp_path / "files")))
    document = Document(
        id="local-source-doc", filename="policy.pdf", size=42,
        upload_date=datetime.utcnow(), user_uid=OWNER_A.uid,
        file_path="/private/source-doc_policy.pdf",
    )
    document_api.document_repository.create(document)

    with pytest.raises(HTTPException) as error:
        await document_api.get_document_source_url("local-source-doc", OWNER_A)
    assert error.value.status_code == 503
