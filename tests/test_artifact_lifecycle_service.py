from datetime import datetime, timezone
from unittest.mock import MagicMock, patch

from src.services import artifact_lifecycle_service


def test_mark_expired_transitions_each_due_artifact():
    client = MagicMock()
    query = client.table.return_value.select.return_value.eq.return_value.not_.is_.return_value.lte.return_value
    query.execute.return_value.data = [{"id": "a1"}]
    current = client.table.return_value.select.return_value.eq.return_value.limit.return_value
    current.execute.return_value.data = [{"id": "a1", "state": "active"}]
    with patch.object(artifact_lifecycle_service, "_client", return_value=client):
        assert artifact_lifecycle_service.mark_expired(now=datetime(2026, 7, 21, tzinfo=timezone.utc)) == 1
    assert any("retention_expired" in str(call) for call in client.table.return_value.insert.call_args_list)
