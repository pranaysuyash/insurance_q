from unittest.mock import MagicMock, patch

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
