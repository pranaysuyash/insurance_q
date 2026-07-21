from unittest.mock import MagicMock

from src.services.processing_event_service import ProcessingEventService


def test_processing_event_maps_progress_to_state_and_redacts_error():
    client = MagicMock()
    service = ProcessingEventService(client=client)
    service.append("doc-1", "owner-1", "failed", 0, error_class="SecretInternalError" * 20)
    row = client.table.return_value.insert.call_args.args[0]
    assert row["state"] == "failed"
    assert row["error_class"] == ("SecretInternalError" * 20)[:120]
