from unittest.mock import MagicMock, patch

from src.services import policy_domain_service


def test_sync_document_is_idempotent_projection_and_does_not_write_source_text():
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [{"id": "p1"}]
    with patch.object(policy_domain_service, "_client", return_value=client):
        policy_domain_service.sync_document(
            document_id="d1", owner_id="u1", source_hash="sha",
            metadata={"classification": {"policy_number": "P-1", "insurer": "Acme", "document_type": "health"}},
            sections=[{"section_type": "coverage", "page": 2, "title": "Coverage"}],
        )
    calls = [call.args[0] for call in client.table.return_value.upsert.call_args_list]
    assert calls[0]["document_id"] == "d1"
    assert calls[0]["source_hash"] == "sha"
    assert "source_text" not in calls[0]
    assert calls[1]["section_type"] == "coverage"


def test_policy_numberless_document_does_not_query_or_merge_owner_policy():
    client = MagicMock()
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = []
    client.table.return_value.insert.return_value.execute.return_value.data = [{"id": "new-policy"}]
    with patch.object(policy_domain_service, "_client", return_value=client):
        policy_domain_service.sync_document(
            document_id="d2", owner_id="u1", source_hash="sha-2",
            metadata={"classification": {"insurer": "Acme", "document_type": "health"}},
        )

    inserted_policy = client.table.return_value.insert.call_args_list[0].args[0]
    assert inserted_policy["owner_id"] == "u1"
    assert inserted_policy["policy_number"] is None
