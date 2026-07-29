"""Tests for the onboarding funnel endpoint (/analytics/funnel).

Uses the same test pattern as test_analytics_errors.py:
- tmp_path + monkeypatch fixtures (built-in)
- test app with both user and analytics routers
- events ingested via POST /analytics/events
- funnel queried with Bearer token + X-Operator-Token header
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
    app = FastAPI()
    app.include_router(user_router)
    app.include_router(analytics_router)
    return app


def _get_auth_token(client: TestClient) -> str:
    response = client.post("/user/anonymous")
    assert response.status_code == 200
    return response.json()["access_token"]


def _ingest_events(client: TestClient, token: str, events: list) -> dict:
    response = client.post(
        "/analytics/events",
        json={"events": events},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    return response.json()


def _get_funnel(client: TestClient, token: str, days: int = 30) -> dict:
    response = client.get(
        f"/analytics/funnel?days={days}",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Operator-Token": "test-operator-secret",
        },
    )
    assert response.status_code == 200
    return response.json()


@pytest.fixture(autouse=True)
def setup_test_db(tmp_path, monkeypatch):
    """Set up a temporary database and operator token for each test."""
    monkeypatch.setenv("OPERATOR_DASHBOARD_TOKEN", "test-operator-secret")
    import src.api.analytics as analytics_module
    original_db_path = analytics_module.DB_PATH
    test_db = str(tmp_path / "test_analytics.db")
    analytics_module.DB_PATH = test_db
    _init_analytics_table()
    yield
    analytics_module.DB_PATH = original_db_path


class TestFunnelEndpoint:
    """Test the onboarding funnel computation."""

    def _insert_events_directly(self, analytics_module, events: list):
        """Insert events directly into SQLite for precise control over install_id and received_at."""
        conn = sqlite3.connect(analytics_module.DB_PATH)
        for event in events:
            conn.execute(
                """
                INSERT INTO analytics_events
                  (event_name, timestamp, user_uid, properties, received_at, install_id, session_id, is_reinstall)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    event["event_name"],
                    event.get("timestamp", datetime.now(timezone.utc).isoformat()),
                    event.get("user_uid", f"user_{event.get('install_id', 'unknown')}"),
                    json.dumps(event.get("properties", {})),
                    event.get("received_at", datetime.now(timezone.utc).isoformat()),
                    event.get("install_id"),
                    event.get("session_id", f"session_{event.get('install_id', 'unknown')}"),
                    event.get("is_reinstall", 0),
                ),
            )
        conn.commit()
        conn.close()

    def test_empty_funnel(self):
        """No events in the window → funnel returns zero counts."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_funnel(client, token, days=30)

            assert result["days"] == 30
            assert result["stages"]["install"] == 0
            assert result["stages"]["onboarded"] == 0
            assert result["stages"]["uploaded"] == 0
            assert result["stages"]["first_question"] == 0

    def test_full_funnel_user(self):
        """Simulate a user who completed the full funnel."""
        import src.api.analytics as analytics_module
        install_id = "full-funnel-user-001"
        now = datetime.now(timezone.utc)

        self._insert_events_directly(analytics_module, [
            # Stage 1: First session (days_since_install=0)
            {
                "event_name": "app_session_started",
                "install_id": install_id,
                "properties": {"days_since_install": 0},
            },
            # Stage 2: Onboarding completed
            {
                "event_name": "onboarding_completed",
                "install_id": install_id,
                "properties": {},
            },
            # Stage 3: First upload
            {
                "event_name": "first_upload_started",
                "install_id": install_id,
                "properties": {"file_type": "pdf"},
            },
            # Stage 4: Processing succeeded
            {
                "event_name": "document_processing_succeeded",
                "install_id": install_id,
                "properties": {"file_type": "pdf", "status": "completed"},
            },
            # Stage 5: First question asked
            {
                "event_name": "first_question_asked",
                "install_id": install_id,
                "properties": {"question_length_bucket": "short"},
            },
            # Stage 6: Return session (days_since_install=2)
            {
                "event_name": "app_session_started",
                "install_id": install_id,
                "properties": {"days_since_install": 2},
            },
        ])

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_funnel(client, token, days=30)

            assert result["stages"]["install"] == 1
            assert result["stages"]["onboarded"] == 1
            assert result["stages"]["uploaded"] == 1
            assert result["stages"]["processed"] == 1
            assert result["stages"]["first_question"] == 1
            assert result["stages"]["returned_engaged"] == 1
            # All conversions should be 100% for a single full-funnel user
            assert result["conversion"]["install_to_onboarded_pct"] == 100.0
            assert result["conversion"]["onboarded_to_uploaded_pct"] == 100.0
            assert result["conversion"]["uploaded_to_processed_pct"] == 100.0
            assert result["conversion"]["processed_to_first_question_pct"] == 100.0
            assert result["conversion"]["uploaded_to_returned_pct"] == 100.0

    def test_partial_funnel_multiple_users(self):
        """Simulate 3 users with different drop-off points."""
        import src.api.analytics as analytics_module

        # User A: install only (dropped before onboarding)
        # User B: install + onboarded + uploaded + processed (dropped before asking)
        # User C: full funnel including return

        now = datetime.now(timezone.utc)
        self._insert_events_directly(analytics_module, [
            # User A: install only
            {"event_name": "app_session_started", "install_id": "user-a", "properties": {"days_since_install": 0}},
            # User B: install → onboard → upload → process
            {"event_name": "app_session_started", "install_id": "user-b", "properties": {"days_since_install": 0}},
            {"event_name": "onboarding_completed", "install_id": "user-b", "properties": {}},
            {"event_name": "first_upload_started", "install_id": "user-b", "properties": {"file_type": "pdf"}},
            {"event_name": "document_processing_succeeded", "install_id": "user-b", "properties": {"file_type": "pdf", "status": "completed"}},
            # User C: full funnel
            {"event_name": "app_session_started", "install_id": "user-c", "properties": {"days_since_install": 0}},
            {"event_name": "onboarding_completed", "install_id": "user-c", "properties": {}},
            {"event_name": "first_upload_started", "install_id": "user-c", "properties": {"file_type": "pdf"}},
            {"event_name": "document_processing_succeeded", "install_id": "user-c", "properties": {"file_type": "pdf", "status": "completed"}},
            {"event_name": "first_question_asked", "install_id": "user-c", "properties": {"question_length_bucket": "short"}},
            {"event_name": "app_session_started", "install_id": "user-c", "properties": {"days_since_install": 5}},
        ])

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_funnel(client, token, days=30)

            # 3 users installed
            assert result["stages"]["install"] == 3
            # 2 completed onboarding (user-b, user-c)
            assert result["stages"]["onboarded"] == 2
            # 2 uploaded (user-b, user-c)
            assert result["stages"]["uploaded"] == 2
            # 2 processed (user-b, user-c)
            assert result["stages"]["processed"] == 2
            # 1 asked first question (user-c)
            assert result["stages"]["first_question"] == 1
            # 1 returned engaged (user-c: returned + uploaded)
            assert result["stages"]["returned_engaged"] == 1

            # Conversions
            assert result["conversion"]["install_to_onboarded_pct"] == 66.7  # 2/3
            assert result["conversion"]["onboarded_to_uploaded_pct"] == 100.0  # 2/2
            assert result["conversion"]["uploaded_to_processed_pct"] == 100.0  # 2/2
            assert result["conversion"]["processed_to_first_question_pct"] == 50.0  # 1/2
            assert result["conversion"]["uploaded_to_returned_pct"] == 50.0  # 1/2

    def test_funnel_returns_403_without_operator_token(self):
        """Funnel endpoint requires operator auth."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            # No X-Operator-Token header
            response = client.get(
                "/analytics/funnel?days=30",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert response.status_code == 403

    def test_funnel_excludes_missing_install_ids(self):
        """Events without install_id should be excluded from funnel."""
        import src.api.analytics as analytics_module

        now = datetime.now(timezone.utc)
        self._insert_events_directly(analytics_module, [
            # Event without install_id (NULL)
            {
                "event_name": "app_session_started",
                "install_id": None,
                "user_uid": "user_no_install_id",
                "properties": {"days_since_install": 0},
            },
        ])

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_funnel(client, token, days=30)
            # Event without install_id should not be counted
            assert result["stages"]["install"] == 0

    def test_funnel_respects_days_window(self):
        """Events outside the days window should be excluded."""
        import src.api.analytics as analytics_module

        now = datetime.now(timezone.utc)
        old_ts = (now - timedelta(days=200)).isoformat()

        # Insert event with old received_at
        conn = sqlite3.connect(analytics_module.DB_PATH)
        conn.execute(
            """
            INSERT INTO analytics_events
              (event_name, timestamp, user_uid, properties, received_at, install_id, session_id, is_reinstall)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "app_session_started",
                now.isoformat(),
                "user_old",
                json.dumps({"days_since_install": 0}),
                old_ts,
                "old-user",
                "session_old",
                0,
            ),
        )
        conn.commit()
        conn.close()

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_funnel(client, token, days=30)
            # Old events should be excluded from the 30-day window
            assert result["stages"]["install"] == 0

    def test_returning_user_not_counted_as_new_install(self):
        """A user whose first session was outside the window but who returned
        within the window should NOT be counted as a new install."""
        import src.api.analytics as analytics_module

        now = datetime.now(timezone.utc)
        old_session_ts = (now - timedelta(days=90)).isoformat()

        # User installed 90 days ago (within the data but outside 30-day window)
        conn = sqlite3.connect(analytics_module.DB_PATH)
        conn.execute(
            """
            INSERT INTO analytics_events
              (event_name, timestamp, user_uid, properties, received_at, install_id, session_id, is_reinstall)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "app_session_started",
                now.isoformat(),
                "user_returning",
                json.dumps({"days_since_install": 0}),
                old_session_ts,
                "returning-user",
                "session_90days_ago",
                0,
            ),
        )
        # Return session 5 days ago with days_since_install=90
        return_ts = (now - timedelta(days=5)).isoformat()
        conn.execute(
            """
            INSERT INTO analytics_events
              (event_name, timestamp, user_uid, properties, received_at, install_id, session_id, is_reinstall)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "app_session_started",
                now.isoformat(),
                "user_returning",
                json.dumps({"days_since_install": 90}),
                return_ts,
                "returning-user",
                "session_recent",
                0,
            ),
        )
        conn.commit()
        conn.close()

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _get_funnel(client, token, days=30)

            # Should NOT count as install (first session was 90 days ago, outside window)
            assert result["stages"]["install"] == 0
            # Should NOT count as returned_engaged (no upload)
            assert result["stages"]["returned_engaged"] == 0
