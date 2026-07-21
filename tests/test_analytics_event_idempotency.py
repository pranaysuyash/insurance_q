from src.api.analytics import AnalyticsEvent, analytics_event_id


def test_event_identity_is_stable_across_property_order_and_retries():
    first = AnalyticsEvent(
        event="question_submitted",
        ts="2026-07-21T10:00:00Z",
        uid="client-uid",
        props={"document_id": "d1", "mode": "full"},
        install_id="install-1",
        session_id="session-1",
    )
    reordered = AnalyticsEvent(
        event="question_submitted",
        ts="2026-07-21T10:00:00Z",
        uid="different-client-uid",
        props={"mode": "full", "document_id": "d1"},
        install_id="install-1",
        session_id="session-1",
    )

    assert analytics_event_id(first, "server-user-1") == analytics_event_id(
        reordered, "server-user-1"
    )
    assert analytics_event_id(first, "server-user-1") != analytics_event_id(
        first, "server-user-2"
    )
