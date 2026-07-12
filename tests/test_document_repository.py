from datetime import datetime

from src.models.document import Document
from src.services.document_repository import SQLiteDocumentRepository, create_document_repository


def _document(document_id: str, owner_id: str) -> Document:
    return Document(
        id=document_id,
        filename="policy.pdf",
        size=12,
        upload_date=datetime.utcnow(),
        user_uid=owner_id,
        file_path=f"storage/documents/{document_id}.pdf",
    )


def test_sqlite_repository_survives_reopen_and_enforces_owner_scope(tmp_path):
    database_path = tmp_path / "documents.db"
    owner_a = "anon:owner-a"
    owner_b = "anon:owner-b"
    repository = SQLiteDocumentRepository(str(database_path))
    document = _document("document-a", owner_a)
    repository.create(document)
    document.status = "completed"
    repository.update(document)

    reopened = SQLiteDocumentRepository(str(database_path))
    assert reopened.get("document-a", owner_a).status == "completed"
    assert reopened.get("document-a", owner_b) is None
    assert reopened.list_for_owner(owner_a)[0].id == "document-a"
    assert reopened.delete("document-a", owner_b) is False
    assert reopened.delete("document-a", owner_a) is True


def test_production_rejects_sqlite_metadata(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")

    try:
        create_document_repository()
    except RuntimeError as error:
        assert "not allowed" in str(error)
    else:
        raise AssertionError("production accepted SQLite document metadata")


def test_production_requires_a_dynamodb_table(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.delenv("DOCUMENT_REPOSITORY_BACKEND", raising=False)
    monkeypatch.delenv("DOCUMENT_METADATA_TABLE", raising=False)

    try:
        create_document_repository()
    except RuntimeError as error:
        assert "DOCUMENT_METADATA_TABLE" in str(error)
    else:
        raise AssertionError("production accepted missing DynamoDB configuration")
