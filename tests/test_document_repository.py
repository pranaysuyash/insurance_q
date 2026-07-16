from datetime import datetime, timedelta, timezone

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
    document.source_hash = "source-hash-a"
    repository.create(document)
    document.status = "completed"
    repository.update(document)

    reopened = SQLiteDocumentRepository(str(database_path))
    assert reopened.get("document-a", owner_a).status == "completed"
    assert reopened.get("document-a", owner_b) is None
    assert reopened.find_by_source_hash(owner_a, "source-hash-a").id == "document-a"
    assert reopened.find_by_source_hash(owner_b, "source-hash-a") is None
    assert reopened.list_for_owner(owner_a)[0].id == "document-a"
    assert reopened.delete("document-a", owner_b) is False
    assert reopened.delete("document-a", owner_a) is True


def test_sqlite_repository_transfers_anonymous_documents_and_updates_payload(tmp_path):
    repository = SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    document = _document("document-a", "anon:owner-a")
    repository.create(document)

    assert repository.transfer_owner("anon:owner-a", "account-user-1") == 1
    transferred = repository.get("document-a", "account-user-1")
    assert transferred is not None
    assert transferred.user_uid == "account-user-1"
    assert repository.get("document-a", "anon:owner-a") is None


def test_production_rejects_sqlite_metadata(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")

    try:
        create_document_repository()
    except RuntimeError as error:
        assert "not allowed" in str(error)
    else:
        raise AssertionError("production accepted SQLite document metadata")


def test_production_requires_supabase_credentials(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.delenv("DOCUMENT_REPOSITORY_BACKEND", raising=False)
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)

    try:
        create_document_repository()
    except RuntimeError as error:
        assert "SUPABASE_URL" in str(error)
    else:
        raise AssertionError("production accepted missing Supabase configuration")


def test_sqlite_processing_lease_is_atomic_and_recovers_only_when_stale(tmp_path):
    repository = SQLiteDocumentRepository(str(tmp_path / "documents.db"))
    document = _document("document-a", "anon:owner-a")
    repository.create(document)

    assert repository.claim_processing(document.id, document.user_uid, lease_seconds=300)
    claimed = repository.get(document.id, document.user_uid)
    assert claimed.status == "processing"
    assert claimed.processing_attempts == 1
    assert claimed.processing_lease_expires_at is not None
    assert not repository.claim_processing(document.id, document.user_uid, lease_seconds=300)
    assert repository.list_recoverable_processing() == []

    claimed.processing_lease_expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    repository.update(claimed)
    assert [item.id for item in repository.list_recoverable_processing()] == [document.id]
    assert repository.claim_processing(document.id, document.user_uid, lease_seconds=300)
    assert repository.get(document.id, document.user_uid).processing_attempts == 2
