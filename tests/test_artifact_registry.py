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
