import pytest
from fastapi import HTTPException
from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.api.user import router as user_router
from src.utils import anonymous_auth


def test_issued_anonymous_token_round_trips(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "test-signing-key")

    token, issued = anonymous_auth.issue_anonymous_token()
    verified = anonymous_auth.verify_anonymous_token(token)

    assert verified["sub"] == issued["sub"]
    assert verified["identity_type"] == "anonymous"


def test_refresh_token_preserves_anonymous_owner(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "test-signing-key")

    original, claims = anonymous_auth.issue_anonymous_token()
    refreshed, refreshed_claims = anonymous_auth.issue_anonymous_token(claims["sub"])

    assert refreshed != original
    assert anonymous_auth.verify_anonymous_token(refreshed)["sub"] == claims["sub"]
    assert refreshed_claims["sub"] == claims["sub"]


def test_rotated_signing_key_accepts_still_valid_previous_token(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "old-test-signing-key")
    token, claims = anonymous_auth.issue_anonymous_token()

    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "new-test-signing-key")
    monkeypatch.setenv("ANONYMOUS_AUTH_PREVIOUS_SIGNING_KEYS", "old-test-signing-key")

    assert anonymous_auth.verify_anonymous_token(token)["sub"] == claims["sub"]


def test_rotated_signing_key_rejects_token_after_previous_key_is_removed(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "old-test-signing-key")
    token, _ = anonymous_auth.issue_anonymous_token()

    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "new-test-signing-key")
    monkeypatch.delenv("ANONYMOUS_AUTH_PREVIOUS_SIGNING_KEYS", raising=False)

    with pytest.raises(HTTPException) as error:
        anonymous_auth.verify_anonymous_token(token)
    assert error.value.status_code == 401


def test_invalid_anonymous_token_is_rejected(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "test-signing-key")

    with pytest.raises(HTTPException) as error:
        anonymous_auth.verify_anonymous_token("not-a-jwt")

    assert error.value.status_code == 401


def test_production_requires_explicit_signing_key(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.delenv("ANONYMOUS_AUTH_SIGNING_KEY", raising=False)

    with pytest.raises(RuntimeError, match="ANONYMOUS_AUTH_SIGNING_KEY"):
        anonymous_auth.issue_anonymous_token()


def test_anonymous_identity_can_access_its_profile(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "test-signing-key")
    app = FastAPI()
    app.include_router(user_router)

    with TestClient(app) as client:
        identity = client.post("/user/anonymous")
        assert identity.status_code == 200
        token = identity.json()["access_token"]
        profile = client.get("/user/profile", headers={"Authorization": f"Bearer {token}"})

    assert profile.status_code == 200
    assert profile.json()["identity_type"] == "anonymous"


def test_anonymous_identity_refresh_keeps_the_same_profile(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.setenv("ANONYMOUS_AUTH_SIGNING_KEY", "test-signing-key")
    app = FastAPI()
    app.include_router(user_router)

    with TestClient(app) as client:
        identity = client.post("/user/anonymous")
        token = identity.json()["access_token"]
        refreshed = client.post("/user/refresh", headers={"Authorization": f"Bearer {token}"})

    assert refreshed.status_code == 200
    assert refreshed.json()["user"]["uid"] == identity.json()["user"]["uid"]


def test_openapi_declares_bearer_auth_for_profile():
    app = FastAPI()
    app.include_router(user_router)

    schema = app.openapi()

    assert schema["components"]["securitySchemes"]["HTTPBearer"]["scheme"] == "bearer"
    assert schema["paths"]["/user/profile"]["get"]["security"] == [{"HTTPBearer": []}]


def test_account_principal_can_access_profile(monkeypatch):
    from src.api import user as user_api

    monkeypatch.setattr(
        user_api,
        "verify_supabase_token",
        lambda token: {
            "sub": "account-user-1",
            "email": "person@example.com",
            "display_name": "Person",
            "identity_type": "account",
        },
    )
    app = FastAPI()
    app.include_router(user_router)

    with TestClient(app) as client:
        response = client.get(
            "/user/profile", headers={"Authorization": "Bearer account-token"}
        )

    assert response.status_code == 200
    assert response.json()["uid"] == "account-user-1"
    assert response.json()["identity_type"] == "account"
