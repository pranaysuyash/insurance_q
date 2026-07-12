from datetime import datetime

import pytest
from fastapi import HTTPException

from src.api import document as document_api
from src.app import main as main_app
from src.models.document import Document
from src.models.user import User
from src.services.document_repository import SQLiteDocumentRepository


OWNER_A = User(uid="anon:owner-a", identity_type="anonymous", email=None, phone=None, display_name=None)
OWNER_B = User(uid="anon:owner-b", identity_type="anonymous", email=None, phone=None, display_name=None)


@pytest.fixture(autouse=True)
def isolated_documents(tmp_path, monkeypatch):
    document_api.set_document_repository(
        SQLiteDocumentRepository(str(tmp_path / "document-metadata.db"))
    )
    monkeypatch.setattr(document_api, "processing_service", None)


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
