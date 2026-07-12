import pytest

from src.services.document_object_store import (
    LocalDocumentObjectStore,
    create_document_object_store,
)


def test_local_object_store_round_trips_and_deletes_a_document(tmp_path):
    store = LocalDocumentObjectStore(str(tmp_path / "documents"))

    reference = store.put("document-a", "anon:owner-a", "policy 2026.pdf", b"policy")

    assert (tmp_path / "documents" / "document-a_policy_2026.pdf").read_bytes() == b"policy"
    store.delete(reference)
    assert not (tmp_path / "documents" / "document-a_policy_2026.pdf").exists()


def test_production_rejects_local_object_storage(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("DOCUMENT_OBJECT_STORE_BACKEND", "local")

    with pytest.raises(RuntimeError, match="not allowed"):
        create_document_object_store()


def test_s3_requires_bucket_and_kms_key(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.delenv("DOCUMENT_OBJECT_STORE_BACKEND", raising=False)
    monkeypatch.delenv("DOCUMENT_STORAGE_BUCKET", raising=False)
    monkeypatch.delenv("DOCUMENT_STORAGE_KMS_KEY_ID", raising=False)

    with pytest.raises(RuntimeError, match="DOCUMENT_STORAGE_BUCKET"):
        create_document_object_store()
