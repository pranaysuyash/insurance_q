"""Tests for DELETE /user/account endpoint.

Security audit P0-04 (2026-07-18): the previous test set codified that the
endpoint returned 200 + 'permanently deleted' even when storage
cleanup or auth-user deletion failed. The audit says this is a false
claim and the response must be 202 with per-stage status. This test
file enforces the new contract:

- 202 on success AND on partial failure (the work is async / best-effort)
- response includes `status` ('deletion_succeeded' | 'deletion_partial')
- response includes `failed_stages` so the durable deletion job
  (Security Phase 3) knows what to retry
- the mobile client must not show 'permanently deleted' if
  `status == 'deletion_partial'`
"""

from unittest.mock import MagicMock, patch
from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.api.user import router as user_router
from src.models.document import Document
from datetime import datetime, timezone


def _make_account_token_verifier():
    """Return a mock that verifies account tokens."""
    def verify(token):
        return {
            "sub": "account-user-1",
            "email": "person@example.com",
            "display_name": "Person",
            "identity_type": "account",
        }
    return verify


def _make_document(doc_id="doc-1", owner_id="account-user-1", file_path="supabase://coverwise-documents/documents/doc-1/policy.pdf"):
    """Create a test document with storage reference."""
    return Document(
        id=doc_id,
        filename="policy.pdf",
        size=1024,
        upload_date=datetime.now(timezone.utc),
        status="completed",
        user_uid=owner_id,
        file_path=file_path,
        source_hash="abc123",
    )


class TestDeleteAccountAnonymousRejection:
    """Anonymous users cannot delete their account."""

    def test_anonymous_user_gets_403(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "test")
        monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "test-key")

        app = FastAPI()
        app.include_router(user_router)

        with TestClient(app) as client:
            identity = client.post("/user/anonymous")
            token = identity.json()["access_token"]
            response = client.delete("/user/account", headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 403
        assert "Only account users" in response.json()["detail"]


class TestDeleteAccountStorageCleanup:
    """Storage files are cleaned up before metadata deletion."""

    def test_storage_files_are_deleted(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "test")
        monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")

        from src.api import user as user_api
        from src.services.document_repository import SQLiteDocumentRepository

        # Mock token verification for account user
        monkeypatch.setattr(user_api, "verify_supabase_token", _make_account_token_verifier())

        # Set up a real SQLite repository with test documents
        repo = SQLiteDocumentRepository(":memory:")
        doc1 = _make_document("doc-1", "account-user-1", "supabase://bucket/documents/doc-1/policy.pdf")
        doc2 = _make_document("doc-2", "account-user-1", "supabase://bucket/documents/doc-2/claim.pdf")
        repo.create(doc1)
        repo.create(doc2)

        # Mock the document_api module to use our repo
        mock_doc_api = MagicMock()
        mock_doc_api.document_repository = repo

        # Mock object store to track deletions
        mock_store = MagicMock()
        deleted_files = []
        mock_store.delete.side_effect = lambda ref: deleted_files.append(ref)

        # Mock create_document_object_store (imported locally in delete_account)
        with patch("src.services.document_object_store.create_document_object_store", return_value=mock_store), \
             patch.dict("sys.modules", {"src.api.document": mock_doc_api}):
            app = FastAPI()
            app.include_router(user_router)

            with TestClient(app) as client:
                response = client.delete("/user/account", headers={"Authorization": "Bearer account-token"})

        # Security audit P0-04: 202 on success, not 200.
        assert response.status_code == 202
        data = response.json()
        # In test environment without real Supabase, auth_user_deleted will be False,
        # leading to deletion_partial status. This is expected behavior.
        assert data["status"] in ["deletion_succeeded", "deletion_partial"]
        assert data["deleted_documents"] == 2
        assert data["deleted_storage_files"] == 2
        assert data["storage_errors"] == 0
        assert data["failed_stages"] == [] or data["failed_stages"] == ["auth_user_deletion"]
        assert len(deleted_files) == 2
        assert "supabase://bucket/documents/doc-1/policy.pdf" in deleted_files
        assert "supabase://bucket/documents/doc-2/claim.pdf" in deleted_files

    def test_storage_error_yields_partial_deletion(self, monkeypatch):
        """Security audit P0-04: when storage cleanup fails, the endpoint
        MUST return 202 + `deletion_partial` and list the failed stage.
        The mobile client must NOT show 'permanently deleted' in this
        case. The durable deletion job (Security Phase 3) picks up the
        retry from `failed_stages`.

        Previous test name was `test_storage_error_does_not_block_deletion`
        — that was the wrong contract. It has been replaced.
        """
        monkeypatch.setenv("ENVIRONMENT", "test")
        monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")

        from src.api import user as user_api
        from src.services.document_repository import SQLiteDocumentRepository

        monkeypatch.setattr(user_api, "verify_supabase_token", _make_account_token_verifier())

        repo = SQLiteDocumentRepository(":memory:")
        doc = _make_document("doc-1", "account-user-1", "supabase://bucket/documents/doc-1/policy.pdf")
        repo.create(doc)

        mock_doc_api = MagicMock()
        mock_doc_api.document_repository = repo

        # Mock object store that raises on delete
        mock_store = MagicMock()
        mock_store.delete.side_effect = RuntimeError("Storage unavailable")

        with patch("src.services.document_object_store.create_document_object_store", return_value=mock_store), \
             patch.dict("sys.modules", {"src.api.document": mock_doc_api}):
            app = FastAPI()
            app.include_router(user_router)

            with TestClient(app) as client:
                response = client.delete("/user/account", headers={"Authorization": "Bearer account-token"})

        # Security audit P0-04: 202 even on partial failure, NEVER 200
        # on a partial completion.
        assert response.status_code == 202
        data = response.json()
        assert data["status"] == "deletion_partial"
        assert data["deleted_documents"] == 1
        assert data["deleted_storage_files"] == 0
        assert data["storage_errors"] == 1
        assert "storage_object_deletion" in data["failed_stages"]
        # The message must NOT claim 'permanently deleted' on partial
        # failure.
        assert "permanently deleted" not in data["message"].lower()
        assert "remaining" in data["message"].lower() or "partial" in data["message"].lower()

    def test_non_supabase_file_path_skips_storage_cleanup(self, monkeypatch):
        """Documents with local file paths (not supabase://) skip storage cleanup."""
        monkeypatch.setenv("ENVIRONMENT", "test")
        monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")

        from src.api import user as user_api
        from src.services.document_repository import SQLiteDocumentRepository

        monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "test-key")
        monkeypatch.setattr(user_api, "verify_supabase_token", _make_account_token_verifier())

        repo = SQLiteDocumentRepository(":memory:")
        doc = _make_document("doc-1", "account-user-1", "/storage/documents/doc-1.pdf")
        repo.create(doc)

        mock_doc_api = MagicMock()
        mock_doc_api.document_repository = repo

        mock_store = MagicMock()

        with patch("src.services.document_object_store.create_document_object_store", return_value=mock_store), \
             patch.dict("sys.modules", {"src.api.document": mock_doc_api}):
            app = FastAPI()
            app.include_router(user_router)

            with TestClient(app) as client:
                response = client.delete("/user/account", headers={"Authorization": "Bearer account-token"})

        assert response.status_code == 202
        data = response.json()
        assert data["deleted_storage_files"] == 0
        mock_store.delete.assert_not_called()


class TestDeleteAccountResponse:
    """Response format is correct."""

    def test_response_includes_all_fields(self, monkeypatch):
        monkeypatch.setenv("ENVIRONMENT", "test")
        monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")

        from src.api import user as user_api
        from src.services.document_repository import SQLiteDocumentRepository

        monkeypatch.setattr(user_api, "verify_supabase_token", _make_account_token_verifier())

        repo = SQLiteDocumentRepository(":memory:")
        mock_doc_api = MagicMock()
        mock_doc_api.document_repository = repo

        mock_store = MagicMock()

        with patch("src.services.document_object_store.create_document_object_store", return_value=mock_store), \
             patch.dict("sys.modules", {"src.api.document": mock_doc_api}):
            app = FastAPI()
            app.include_router(user_router)

            with TestClient(app) as client:
                response = client.delete("/user/account", headers={"Authorization": "Bearer account-token"})

        # Security audit P0-04: 202 not 200.
        assert response.status_code == 202
        data = response.json()
        assert "status" in data
        assert "deleted_documents" in data
        assert "deleted_storage_files" in data
        assert "storage_errors" in data
        assert "auth_user_deleted" in data
        assert "failed_stages" in data
        assert "message" in data
        assert isinstance(data["deleted_documents"], int)
        assert isinstance(data["deleted_storage_files"], int)
        assert isinstance(data["storage_errors"], int)
        assert isinstance(data["auth_user_deleted"], bool)


def test_account_export_returns_metadata_without_source_contents(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("DOCUMENT_REPOSITORY_BACKEND", "sqlite")
    from src.api import user as user_api
    from src.services.document_repository import SQLiteDocumentRepository

    monkeypatch.setattr(user_api, "verify_supabase_token", _make_account_token_verifier())
    repo = SQLiteDocumentRepository(":memory:")
    repo.create(_make_document())
    mock_doc_api = MagicMock()
    mock_doc_api.document_repository = repo
    with patch.dict("sys.modules", {"src.api.document": mock_doc_api}):
        app = FastAPI()
        app.include_router(user_router)
        with TestClient(app) as client:
            response = client.get("/user/account/export", headers={"Authorization": "Bearer account-token"})

    assert response.status_code == 200
    data = response.json()
    assert data["export_format_version"] == "v1"
    assert data["documents"][0]["id"] == "doc-1"
    assert "file_path" not in data["documents"][0]
    assert "source_files" in data
    assert data["source_downloads"] == []


def test_production_deletion_ignores_dead_lettered_job_history(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    from src.api import user as user_api

    monkeypatch.setattr(user_api, "verify_supabase_token", _make_account_token_verifier())
    monkeypatch.setattr(
        "src.services.account_lifecycle_service.create_deletion_request",
        lambda _uid: {"id": "request-1"},
    )

    class FakeOutbox:
        calls = []

        async def find_by_payload_field(self, *args, **kwargs):
            self.calls.append((args, kwargs))
            return None

        async def enqueue(self, request):
            self.calls.append(("enqueue", request.payload))

    fake = FakeOutbox()
    monkeypatch.setattr(
        "src.services.job_outbox_service.JobOutboxService.from_env",
        classmethod(lambda cls: fake),
    )

    app = FastAPI()
    app.include_router(user_router)
    with TestClient(app) as client:
        response = client.delete(
            "/user/account", headers={"Authorization": "Bearer account-token"}
        )

    assert response.status_code == 202
    assert response.json()["status"] == "deletion_requested"
    assert fake.calls[0][1] == {"active_only": True}
    assert fake.calls[1][0] == "enqueue"
