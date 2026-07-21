from unittest.mock import MagicMock

from src.services.policy_extraction_service import PolicyExtractionService


def test_production_summary_store_uses_supabase_not_disk(monkeypatch):
    client = MagicMock()
    client.table.return_value.upsert.return_value.execute.return_value.data = [{"document_id": "d1"}]
    service = PolicyExtractionService(MagicMock(), redis_client=None)
    service._supabase = client
    service._store_summary("d1", {"policy_number": "P-1"})
    row = client.table.return_value.upsert.call_args.args[0]
    assert row["document_id"] == "d1"
    assert row["summary"]["policy_number"] == "P-1"
