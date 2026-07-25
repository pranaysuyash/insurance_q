"""Integration test for the analytics error aggregation endpoint.

Sends a batch of global_error events to /analytics/events and verifies
that /analytics/errors returns the correct aggregated data.

Security audit P0-08 (2026-07-18): the operator-only read endpoints
require the X-Operator-Token header. These tests use the test
operator secret 'test-operator-secret' via a fixture.
"""
import json
import sqlite3
from datetime import datetime, timezone, timedelta

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.api.analytics import router as analytics_router, _init_analytics_table
from src.api.user import router as user_router


def _create_test_app() -> FastAPI:
    """Create a test app with analytics and user routers."""
    app = FastAPI()
    app.include_router(user_router)
    app.include_router(analytics_router)
    return app


def _get_auth_token(client: TestClient) -> str:
    """Get an anonymous auth token for testing."""
    response = client.post("/user/anonymous")
    assert response.status_code == 200
    return response.json()["access_token"]


def _ingest_events(client: TestClient, token: str, events: list) -> dict:
    """Ingest a batch of analytics events."""
    response = client.post(
        "/analytics/events",
        json={"events": events},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    return response.json()


def _get_error_aggregation(client: TestClient, token: str, days: int = 7) -> dict:
    """Get error aggregation data.

    Security audit P0-08: this is an operator endpoint. The test
    sends the X-Operator-Token header. Real operator clients do the
    same; ordinary user clients do not have this secret and would
    receive 403.
    """
    response = client.get(
        f"/analytics/errors?days={days}",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Operator-Token": "test-operator-secret",
        },
    )
    assert response.status_code == 200
    return response.json()


@pytest.fixture(autouse=True)
def setup_test_db(tmp_path, monkeypatch):
    """Set up a temporary database and operator token for each test.

    Security audit P0-08: the operator read endpoints require the
    OPERATOR_DASHBOARD_TOKEN env var. The fixture sets it to a test
    value so the tests can exercise the operator path; without this,
    the endpoints would fail-closed with 403.
    """
    monkeypatch.setenv("OPERATOR_DASHBOARD_TOKEN", "test-operator-secret")
    import src.api.analytics as analytics_module
    original_db_path = analytics_module.DB_PATH
    test_db = str(tmp_path / "test_analytics.db")
    analytics_module.DB_PATH = test_db
    _init_analytics_table()
    yield
    analytics_module.DB_PATH = original_db_path


class TestAnalyticsErrorAggregation:
    """Test suite for the /analytics/errors endpoint."""

    def test_empty_database_returns_zero_counts(self):
        """When no errors exist, the endpoint returns zero counts."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_error_aggregation(client, token)

            assert result["status"] == "success"
            assert result["total_errors"] == 0
            assert result["total_recoveries"] == 0
            assert result["recovery_rate_percent"] is None
            assert result["error_types"] == {}
            assert result["error_libraries"] == {}
            assert result["top_error_messages"] == []

    def test_single_error_type_is_counted(self):
        """A single global_error event is counted correctly."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            _ingest_events(client, token, [
                {
                    "event": "global_error",
                    "ts": datetime.now(timezone.utc).isoformat(),
                    "uid": "test-user-1",
                    "props": {
                        "error_type": "Exception",
                        "error_message": "Test error message",
                        "library": "Flutter",
                    },
                },
            ])

            result = _get_error_aggregation(client, token)

            assert result["total_errors"] == 1
            assert result["error_types"] == {"Exception": 1}
            assert result["error_libraries"] == {"Flutter": 1}
            assert len(result["top_error_messages"]) == 1
            assert result["top_error_messages"][0][0] == "Test error message"
            assert result["top_error_messages"][0][1] == 1

    def test_multiple_error_types_are_aggregated(self):
        """Multiple error types are aggregated correctly by count."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            now = datetime.now(timezone.utc)
            _ingest_events(client, token, [
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"error_type": "Exception", "library": "Flutter", "error_message": "Error A"},
                },
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"error_type": "Exception", "library": "Flutter", "error_message": "Error A"},
                },
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-2",
                    "props": {"error_type": "TypeError", "library": "Dart", "error_message": "Error B"},
                },
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-2",
                    "props": {"error_type": "Exception", "library": "Flutter", "error_message": "Error A"},
                },
            ])

            result = _get_error_aggregation(client, token)

            assert result["total_errors"] == 4
            assert result["error_types"]["Exception"] == 3
            assert result["error_types"]["TypeError"] == 1
            assert result["error_libraries"]["Flutter"] == 3
            assert result["error_libraries"]["Dart"] == 1

    def test_recovery_events_are_counted(self):
        """global_error_recovered events are counted for recovery rate."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            now = datetime.now(timezone.utc)
            _ingest_events(client, token, [
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"error_type": "Exception", "library": "Flutter", "error_message": "Error 1"},
                },
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"error_type": "TypeError", "library": "Dart", "error_message": "Error 2"},
                },
                {
                    "event": "global_error_recovered",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"error_type": "Exception"},
                },
            ])

            result = _get_error_aggregation(client, token)

            assert result["total_errors"] == 2
            assert result["total_recoveries"] == 1
            assert result["recovery_rate_percent"] == 50.0

    def test_non_error_events_are_excluded(self):
        """Only global_error events are counted, not other event types."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            now = datetime.now(timezone.utc)
            _ingest_events(client, token, [
                {
                    "event": "question_submitted",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"question_length_bucket": "short"},
                },
                {
                    "event": "document_processing_succeeded",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"file_type": "pdf"},
                },
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"error_type": "Exception", "library": "Flutter", "error_message": "Real error"},
                },
            ])

            result = _get_error_aggregation(client, token)

            assert result["total_errors"] == 1
            assert result["error_types"] == {"Exception": 1}

    def test_top_messages_limit_is_10(self):
        """Top error messages are limited to 10 entries."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            now = datetime.now(timezone.utc)
            events = []
            for i in range(15):
                events.append({
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": f"user-{i}",
                    "props": {
                        "error_type": "Exception",
                        "library": "Flutter",
                        "error_message": f"Unique error message {i}",
                    },
                })

            _ingest_events(client, token, events)

            result = _get_error_aggregation(client, token)

            assert result["total_errors"] == 15
            assert len(result["top_error_messages"]) <= 10

    def test_missing_properties_handled_gracefully(self):
        """Events with missing or malformed properties are handled gracefully."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            now = datetime.now(timezone.utc)
            _ingest_events(client, token, [
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {},
                },
                {
                    "event": "global_error",
                    "ts": now.isoformat(),
                    "uid": "user-1",
                    "props": {"error_type": "Exception"},
                },
            ])

            result = _get_error_aggregation(client, token)

            assert result["total_errors"] == 2
            assert result["error_types"].get("unknown", 0) >= 1

    def test_days_filter_works(self):
        """Events older than the days filter are excluded."""
        import src.api.analytics as analytics_module
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            now = datetime.now(timezone.utc)
            old_received_at = (now - timedelta(days=10)).isoformat()
            recent_received_at = now.isoformat()

            # Insert directly into SQLite with controlled received_at values
            # to properly test the days filter (ingestion always sets received_at to now)
            conn = sqlite3.connect(analytics_module.DB_PATH)
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("global_error", now.isoformat(), "user-1",
                 json.dumps({"error_type": "OldError", "library": "Flutter", "error_message": "Old error"}),
                 old_received_at),
            )
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("global_error", now.isoformat(), "user-1",
                 json.dumps({"error_type": "RecentError", "library": "Flutter", "error_message": "Recent error"}),
                 recent_received_at),
            )
            conn.commit()
            conn.close()

            # Query last 7 days only
            result = _get_error_aggregation(client, token, days=7)

            assert result["total_errors"] == 1
            assert "RecentError" in result["error_types"]
            assert "OldError" not in result["error_types"]


def _get_health(client: TestClient, token: str) -> dict:
    """Get analytics health (operator endpoint).

    Security audit P0-08: requires X-Operator-Token header.
    """
    response = client.get(
        "/analytics/health",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Operator-Token": "test-operator-secret",
        },
    )
    assert response.status_code == 200
    return response.json()


def _get_summary(client: TestClient, token: str, days: int = 7) -> dict:
    """Get analytics summary (operator endpoint).

    Security audit P0-08: requires X-Operator-Token header.
    """
    response = client.get(
        f"/analytics/summary?days={days}",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Operator-Token": "test-operator-secret",
        },
    )
    assert response.status_code == 200
    return response.json()


class TestAnalyticsHealth:
    """Test suite for the /analytics/health endpoint."""

    def test_health_returns_table_exists(self):
        """Health endpoint reports table_exists=true after init."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_health(client, token)
            assert result["status"] == "success"
            assert result["table_exists"] is True

    def test_health_returns_indexes(self):
        """Health endpoint lists all analytics indexes."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_health(client, token)
            index_names = [idx["name"] for idx in result["indexes"]]
            assert "idx_analytics_event_name" in index_names
            assert "idx_analytics_user_uid" in index_names
            assert "idx_analytics_error_window" in index_names
            assert "idx_analytics_summary" in index_names

    def test_health_returns_row_counts(self):
        """Health endpoint returns accurate row_count and recent_events_24h."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)

            # Ingest 3 events
            now = datetime.now(timezone.utc)
            _ingest_events(client, token, [
                {"event": "global_error", "ts": now.isoformat(), "uid": "u1", "props": {"error_type": "E", "library": "L", "error_message": "m"}},
                {"event": "global_error", "ts": now.isoformat(), "uid": "u2", "props": {"error_type": "E", "library": "L", "error_message": "m"}},
                {"event": "question_submitted", "ts": now.isoformat(), "uid": "u3", "props": {}},
            ])

            result = _get_health(client, token)
            assert result["row_count"] == 3
            assert result["recent_events_24h"] == 3

    def test_health_rejects_request_without_operator_token(self):
        """Security audit P0-08: a request without the operator token
        must be rejected with 403, even if the bearer token is valid.
        """
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            response = client.get(
                "/analytics/health",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert response.status_code == 403

    def test_health_rejects_request_with_wrong_operator_token(self):
        """Security audit P0-08: wrong operator token is rejected with 403."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            response = client.get(
                "/analytics/health",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Operator-Token": "not-the-real-secret",
                },
            )
            assert response.status_code == 403

    def test_health_reports_missing_table(self):
        """Health endpoint reports table_exists=false when table is missing."""
        import src.api.analytics as analytics_module
        # Point to a non-existent DB
        original = analytics_module.DB_PATH
        analytics_module.DB_PATH = "/tmp/nonexistent_test_db_98765.db"
        try:
            app = _create_test_app()
            with TestClient(app) as client:
                token = _get_auth_token(client)
                result = _get_health(client, token)
                assert result["table_exists"] is False
                assert result["row_count"] == 0
                assert result["recent_events_24h"] == 0
                assert result["indexes"] == []
        finally:
            analytics_module.DB_PATH = original
