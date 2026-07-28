"""Integration test for the DELETE /analytics/events endpoint.

Covers:
1. Delete all events (no filters)
2. Delete by age (older_than_days)
3. Delete by event name
4. Combined filters (age + name)
5. Operator auth rejection (no X-Operator-Token → 403)
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


def _delete_events(
    client: TestClient,
    token: str,
    older_than_days: int | None = None,
    event_name: str | None = None,
) -> dict:
    """Call DELETE /analytics/events with optional filters."""
    params = {}
    if older_than_days is not None:
        params["older_than_days"] = older_than_days
    if event_name is not None:
        params["event_name"] = event_name
    response = client.delete(
        "/analytics/events",
        params=params,
        headers={
            "Authorization": f"Bearer {token}",
            "X-Operator-Token": "test-operator-secret",
        },
    )
    return response


def _count_events() -> int:
    """Direct SQLite count of all analytics_events rows."""
    import src.api.analytics as analytics_module
    conn = sqlite3.connect(analytics_module.DB_PATH)
    row = conn.execute("SELECT COUNT(*) FROM analytics_events").fetchone()
    conn.close()
    return row[0] if row else 0


@pytest.fixture(autouse=True)
def setup_test_db(tmp_path, monkeypatch):
    """Set up a temporary database and operator token for each test."""
    monkeypatch.setenv("OPERATOR_DASHBOARD_TOKEN", "test-operator-secret")
    import src.api.analytics as analytics_module
    original_db_path = analytics_module.DB_PATH
    test_db = str(tmp_path / "test_analytics_delete.db")
    analytics_module.DB_PATH = test_db
    _init_analytics_table()
    yield
    analytics_module.DB_PATH = original_db_path


class TestAnalyticsDeleteEvents:
    """Test suite for the DELETE /analytics/events endpoint."""

    # ── 1. Delete all (no filters) ─────────────────────────────────

    def test_delete_all_removes_everything(self):
        """DELETE /analytics/events without filters removes all rows."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            _ingest_events(client, token, [
                {"event": "app_opened", "ts": now.isoformat(), "uid": "u1", "props": {}},
                {"event": "question_submitted", "ts": now.isoformat(), "uid": "u1", "props": {}},
                {"event": "global_error", "ts": now.isoformat(), "uid": "u2", "props": {"error_type": "E"}},
            ])
            assert _count_events() == 3

            result = _delete_events(client, token)
            assert result.status_code == 200
            body = result.json()
            assert body["status"] == "success"
            assert body["deleted"] == 3
            assert _count_events() == 0

    def test_delete_all_on_empty_db_returns_zero(self):
        """DELETE /analytics/events on an empty database returns deleted=0."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            result = _delete_events(client, token)
            assert result.status_code == 200
            assert result.json()["deleted"] == 0

    # ── 2. Delete by age (older_than_days) ─────────────────────────

    def test_delete_older_than_days_removes_old_events(self):
        """Events older than older_than_days are removed; recent events remain."""
        import src.api.analytics as analytics_module

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            # Insert events with controlled received_at timestamps
            conn = sqlite3.connect(analytics_module.DB_PATH)
            old_ts = (now - timedelta(days=10)).isoformat()
            recent_ts = now.isoformat()
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("app_opened", old_ts, "u1", None, old_ts),
            )
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("question_submitted", recent_ts, "u1", None, recent_ts),
            )
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("global_error", old_ts, "u2", '{"error_type":"E"}', old_ts),
            )
            conn.commit()
            conn.close()

            assert _count_events() == 3

            # Delete events older than 5 days
            result = _delete_events(client, token, older_than_days=5)
            assert result.status_code == 200
            assert result.json()["deleted"] == 2
            assert _count_events() == 1

    def test_delete_older_than_days_keeps_all_when_none_old(self):
        """No events are deleted when none are older than the threshold."""
        import src.api.analytics as analytics_module

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            conn = sqlite3.connect(analytics_module.DB_PATH)
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("app_opened", now.isoformat(), "u1", None, now.isoformat()),
            )
            conn.commit()
            conn.close()

            # Delete events older than 30 days — none fit
            result = _delete_events(client, token, older_than_days=30)
            assert result.status_code == 200
            assert result.json()["deleted"] == 0
            assert _count_events() == 1

    # ── 3. Delete by event name ────────────────────────────────────

    def test_delete_by_event_name_removes_only_matching(self):
        """Only events with the matching event_name are deleted."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            _ingest_events(client, token, [
                {"event": "app_opened", "ts": now.isoformat(), "uid": "u1", "props": {}},
                {"event": "global_error", "ts": now.isoformat(), "uid": "u1", "props": {"error_type": "E"}},
                {"event": "global_error", "ts": now.isoformat(), "uid": "u2", "props": {"error_type": "T"}},
                {"event": "question_submitted", "ts": now.isoformat(), "uid": "u3", "props": {}},
            ])
            import src.api.analytics as analytics_module
            assert _count_events() == 4

            result = _delete_events(client, token, event_name="global_error")
            assert result.status_code == 200
            assert result.json()["deleted"] == 2
            assert _count_events() == 2

    def test_delete_by_nonexistent_event_name_returns_zero(self):
        """Deleting by a non-existent event name returns deleted=0."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            _ingest_events(client, token, [
                {"event": "app_opened", "ts": now.isoformat(), "uid": "u1", "props": {}},
            ])

            result = _delete_events(client, token, event_name="nonexistent_event")
            assert result.status_code == 200
            assert result.json()["deleted"] == 0

    # ── 4. Combined filters ────────────────────────────────────────

    def test_delete_with_combined_filters_is_additive(self):
        """Both older_than_days AND event_name must match for deletion."""
        import src.api.analytics as analytics_module

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)
            old_ts = (now - timedelta(days=10)).isoformat()
            recent_ts = now.isoformat()

            conn = sqlite3.connect(analytics_module.DB_PATH)
            # Old global_error — should be deleted (matches both conditions)
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("global_error", old_ts, "u1", None, old_ts),
            )
            # Recent global_error — should NOT be deleted (not old enough)
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("global_error", recent_ts, "u1", None, recent_ts),
            )
            # Old app_opened — should NOT be deleted (wrong event name)
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("app_opened", old_ts, "u2", None, old_ts),
            )
            conn.commit()
            conn.close()

            assert _count_events() == 3

            # Delete global_error events older than 5 days
            result = _delete_events(client, token, older_than_days=5, event_name="global_error")
            assert result.status_code == 200
            assert result.json()["deleted"] == 1
            assert _count_events() == 2

    def test_delete_with_combined_filters_removes_nothing_when_no_match(self):
        """When combined filters match no rows, deleted=0 and no rows are removed."""
        import src.api.analytics as analytics_module

        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            conn = sqlite3.connect(analytics_module.DB_PATH)
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                ("app_opened", now.isoformat(), "u1", None, now.isoformat()),
            )
            conn.commit()
            conn.close()

            # Try to delete global_error events older than 1 day — none match
            result = _delete_events(client, token, older_than_days=1, event_name="global_error")
            assert result.status_code == 200
            assert result.json()["deleted"] == 0
            assert _count_events() == 1

    # ── 5. Operator auth rejection ─────────────────────────────────

    def test_delete_without_operator_token_returns_403(self):
        """DELETE without X-Operator-Token header returns 403."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            response = client.delete(
                "/analytics/events",
                headers={"Authorization": f"Bearer {token}"},
            )
            assert response.status_code == 403

    def test_delete_with_wrong_operator_token_returns_403(self):
        """DELETE with wrong X-Operator-Token header returns 403."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            response = client.delete(
                "/analytics/events",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Operator-Token": "not-the-real-secret",
                },
            )
            assert response.status_code == 403

    def test_delete_without_bearer_token_returns_401(self):
        """DELETE without any bearer token returns 401 (no auth provided)."""
        app = _create_test_app()
        with TestClient(app) as client:
            response = client.delete(
                "/analytics/events",
                headers={"X-Operator-Token": "test-operator-secret"},
            )
            assert response.status_code == 401


class TestAnalyticsDeleteDoesNotAffectOtherEndpoints:
    """Verify that DELETE does not break the health or summary endpoints."""

    def test_health_still_works_after_delete_all(self):
        """The /analytics/health endpoint still works after a delete-all."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            _ingest_events(client, token, [
                {"event": "app_opened", "ts": now.isoformat(), "uid": "u1", "props": {}},
            ])

            # Delete all
            _delete_events(client, token)

            # Health should still work
            response = client.get(
                "/analytics/health",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Operator-Token": "test-operator-secret",
                },
            )
            assert response.status_code == 200
            assert response.json()["row_count"] == 0

    def test_summary_still_works_after_delete_all(self):
        """The /analytics/summary endpoint still works after a delete-all."""
        app = _create_test_app()
        with TestClient(app) as client:
            token = _get_auth_token(client)
            now = datetime.now(timezone.utc)

            _ingest_events(client, token, [
                {"event": "app_opened", "ts": now.isoformat(), "uid": "u1", "props": {}},
            ])

            # Delete all
            _delete_events(client, token)

            # Summary should still work
            response = client.get(
                "/analytics/summary",
                headers={
                    "Authorization": f"Bearer {token}",
                    "X-Operator-Token": "test-operator-secret",
                },
            )
            assert response.status_code == 200
            assert response.json()["total_events"] == 0
