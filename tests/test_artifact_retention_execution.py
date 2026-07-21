from unittest.mock import MagicMock, patch

from src.services.artifact_lifecycle_service import delete_pending


def test_delete_pending_deletes_fenced_objects_and_reports_counts():
    client = MagicMock()
    client.table.return_value.select.return_value.in_.return_value.order.return_value.limit.return_value.execute.return_value.data = [
        {"id": "a1", "object_reference": "supabase://bucket/path", "state": "deleting"}
    ]
    store = MagicMock()
    with patch("src.services.artifact_lifecycle_service._client", return_value=client), \
         patch("src.services.document_object_store.create_document_object_store", return_value=store), \
         patch("src.services.artifact_lifecycle_service._transition", return_value=True):
        result = delete_pending()
    store.delete.assert_called_once_with("supabase://bucket/path")
    assert result == {"attempted": 1, "deleted": 1, "failed": 0}
