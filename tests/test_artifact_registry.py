from unittest.mock import MagicMock, patch

import pytest

from src.services import artifact_registry


def test_source_artifact_records_checksum_and_size():
    client = MagicMock()
    with patch.object(artifact_registry, "_client", return_value=client):
        artifact_registry.record_source("doc-1", "user-1", "supabase://bucket/documents/doc-1/a.pdf", b"abc")
    row = client.table.return_value.upsert.call_args.args[0]
    assert row["byte_size"] == 3
    assert row["checksum_sha256"] == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert row["artifact_kind"] == "source"


def test_derived_artifact_records_page_image_checksum():
    client = MagicMock()
    with patch.object(artifact_registry, "_client", return_value=client):
        artifact_registry.record_derived(
            "doc-1", "user-1", "supabase://b/_pages/doc-1/1.png", b"png",
            artifact_kind="page_image", content_type="image/png",
        )
    row = client.table.return_value.upsert.call_args.args[0]
    assert row["artifact_kind"] == "page_image"
    assert row["content_type"] == "image/png"
    assert row["byte_size"] == 3


def test_account_derived_cleanup_deletes_objects_before_inventory_transition(monkeypatch):
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.neq.return_value.execute.return_value.data = [
        {"id": "a1", "object_reference": "supabase://b/_pages/doc-1/1.png", "state": "active"},
        {"id": "a2", "object_reference": "supabase://b/_derived/doc-1/cache.bin", "state": "active"},
    ]
    store = MagicMock()
    monkeypatch.setattr(artifact_registry, "_client", lambda: client)
    monkeypatch.setattr(
        "src.services.document_object_store.create_document_object_store",
        lambda: store,
    )
    monkeypatch.setattr("src.services.artifact_lifecycle_service._transition", lambda *args, **kwargs: True)

    result = artifact_registry.delete_owner_derived_objects("owner-1")

    assert result == {"attempted": 2, "deleted": 2}
    assert [call.args[0] for call in store.delete.call_args_list] == [
        "supabase://b/_pages/doc-1/1.png",
        "supabase://b/_derived/doc-1/cache.bin",
    ]


def test_account_derived_cleanup_preserves_inventory_transition_on_delete_failure(monkeypatch):
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.neq.return_value.execute.return_value.data = [
        {"id": "a1", "object_reference": "supabase://b/_pages/doc-1/1.png", "state": "active"},
    ]
    store = MagicMock()
    store.delete.side_effect = RuntimeError("object store unavailable")
    monkeypatch.setattr(artifact_registry, "_client", lambda: client)
    monkeypatch.setattr(
        "src.services.document_object_store.create_document_object_store",
        lambda: store,
    )
    monkeypatch.setattr(
        artifact_registry,
        "_delete_inventory_rows",
        lambda rows, **_: (_ for _ in ()).throw(RuntimeError("object store unavailable")),
    )

    with pytest.raises(RuntimeError, match="object store unavailable"):
        artifact_registry.delete_owner_derived_objects("owner-1")
