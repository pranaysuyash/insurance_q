from src.services.analytics_identity import stable_event_id


def test_analytics_event_identity_is_stable_and_receive_time_independent():
    row = {
        "event_name": "question_submitted",
        "timestamp": "2026-07-21T10:00:00Z",
        "user_uid": "user-1",
        "properties": {"screen": "qa"},
        "install_id": "install-1",
        "session_id": "session-1",
        "is_reinstall": False,
        "received_at": "2026-07-21T10:01:00Z",
    }
    first = stable_event_id(row)
    row["received_at"] = "2026-07-21T10:02:00Z"
    assert stable_event_id(row) == first
    row["properties"] = {"screen": "documents"}
    assert stable_event_id(row) != first
