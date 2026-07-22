from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.api.user import router as user_router


def _account_claims(_token):
    return {
        "sub": "account-user-1",
        "email": "person@example.com",
        "identity_type": "account",
    }


def _app():
    app = FastAPI()
    app.include_router(user_router)
    return app


def test_deletion_status_backend_failure_is_not_silently_reported(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    from src.api import user as user_api

    monkeypatch.setattr(user_api, "verify_supabase_token", _account_claims)
    with TestClient(_app()) as client:
        response = client.get(
            "/user/account/deletion-status",
            headers={"Authorization": "Bearer account-token"},
        )
    assert response.status_code == 503


def test_deletion_status_rejects_anonymous_identity(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    from src.api import user as user_api

    monkeypatch.setattr(
        user_api,
        "verify_anonymous_token",
        lambda _token: {"sub": "anon-1", "identity_type": "anonymous"},
    )
    with TestClient(_app()) as client:
        response = client.get(
            "/user/account/deletion-status",
            headers={"Authorization": "Bearer a.b.c"},
        )
    assert response.status_code == 403
    assert "Only account users" in response.json()["detail"]


def test_deletion_status_projects_only_owner_safe_fields(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    from src.api import user as user_api

    monkeypatch.setattr(user_api, "verify_supabase_token", _account_claims)
    with patch(
        "src.services.account_lifecycle_service.get_deletion_status",
        return_value={
            "status": "running",
            "request_id": "request-1",
            "requested_at": "2026-07-21T10:00:00+00:00",
            "started_at": "2026-07-21T10:01:00+00:00",
            "completed_at": None,
            "updated_at": "2026-07-21T10:02:00+00:00",
        },
    ) as get_status:
        with TestClient(_app()) as client:
            response = client.get(
                "/user/account/deletion-status",
                headers={"Authorization": "Bearer account-token"},
            )

    assert response.status_code == 200
    assert response.json()["status"] == "running"
    assert "stage_state" not in response.json()
    assert "last_error_class" not in response.json()
    get_status.assert_called_once_with("account-user-1")


def test_deletion_status_is_none_in_development(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    from src.api import user as user_api

    monkeypatch.setattr(user_api, "verify_supabase_token", _account_claims)
    with TestClient(_app()) as client:
        response = client.get(
            "/user/account/deletion-status",
            headers={"Authorization": "Bearer account-token"},
        )
    assert response.status_code == 200
    assert response.json() == {"status": "none", "request_id": None}
