"""Tests for the account-auth boundary (``get_current_user``).

``get_current_user`` is the gate in front of nearly every policy-bearing
endpoint. Until now it had zero dedicated tests (only ``anonymous_auth`` was
covered). These tests pin the 401/403 boundaries, the anonymous -> Supabase
fallback, and a regression for the previously-latent "3-segment token +
unconfigured Supabase -> 500" failure mode.

The Supabase verifier is mocked where we are asserting routing/branching, and
exercised for real (against an unconfigured client) where we assert that an
unconfigured backend degrades to a clean 401, never a 500.
"""

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.testclient import TestClient

from src.api import user as user_api
from src.api.user import get_current_user, router as user_router
from src.utils.supabase_auth import clear_auth_client_cache


def _creds(token: str, scheme: str = "bearer") -> HTTPAuthorizationCredentials:
    return HTTPAuthorizationCredentials(scheme=scheme, credentials=token)


@pytest.fixture(autouse=True)
def _clear_auth_cache():
    """Ensure the lru-cached Supabase auth client never leaks across tests."""
    yield
    clear_auth_client_cache()


# ---------------------------------------------------------------------------
# Unit tests against get_current_user directly
# ---------------------------------------------------------------------------

def test_missing_credentials_returns_401():
    with pytest.raises(HTTPException) as exc:
        get_current_user(credentials=None)
    assert exc.value.status_code == 401


def test_non_bearer_scheme_returns_401():
    with pytest.raises(HTTPException) as exc:
        get_current_user(credentials=_creds("x", scheme="Basic"))
    assert exc.value.status_code == 401


def test_valid_supabase_token_yields_account_user(monkeypatch):
    monkeypatch.setattr(
        user_api,
        "verify_supabase_token",
        lambda tok: {
            "sub": "acct-123",
            "email": "person@example.com",
            "display_name": "Person",
            "identity_type": "account",
        },
    )
    # 2-segment token bypasses the anonymous branch entirely.
    user = get_current_user(credentials=_creds("not.a-jwt"))
    assert user.uid == "acct-123"
    assert user.identity_type == "account"
    assert user.email == "person@example.com"
    assert user.is_account is True


def test_valid_anonymous_token_yields_anonymous_user(monkeypatch):
    monkeypatch.setattr(
        user_api,
        "verify_anonymous_token",
        lambda tok: {"sub": "anon:xyz", "identity_type": "anonymous"},
    )
    user = get_current_user(credentials=_creds("a.b.c"))
    assert user.uid == "anon:xyz"
    assert user.identity_type == "anonymous"
    assert user.is_account is False


def test_three_segment_token_falls_back_to_supabase(monkeypatch):
    # Anonymous verification fails -> must fall back to the Supabase verifier.
    def _anon_fails(token):
        raise HTTPException(status_code=401, detail="not anonymous")

    monkeypatch.setattr(user_api, "verify_anonymous_token", _anon_fails)
    monkeypatch.setattr(
        user_api,
        "verify_supabase_token",
        lambda tok: {"sub": "acct-fb", "email": "fb@example.com", "identity_type": "account"},
    )
    user = get_current_user(credentials=_creds("a.b.c"))
    assert user.uid == "acct-fb"
    assert user.identity_type == "account"


def test_missing_sub_claim_returns_401_not_500(monkeypatch):
    # A verifier that returns a claim set without a ``sub`` must be rejected at
    # the boundary with a 401, never propagate a KeyError as a 500.
    monkeypatch.setattr(
        user_api,
        "verify_supabase_token",
        lambda tok: {"email": "a@b.com", "identity_type": "account"},  # no sub
    )
    with pytest.raises(HTTPException) as exc:
        get_current_user(credentials=_creds("not.a-jwt"))
    assert exc.value.status_code == 401


# ---------------------------------------------------------------------------
# Regression: unconfigured Supabase must never surface as a 500
# ---------------------------------------------------------------------------

def test_three_segment_token_with_unconfigured_supabase_returns_401(monkeypatch):
    # Conftest clears SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY, but be explicit.
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    monkeypatch.setenv("ENVIRONMENT", "development")
    clear_auth_client_cache()

    # "a.b.c" is a 3-segment token: anonymous verify fails (dev key), then the
    # Supabase fallback runs against an unconfigured client. The boundary must
    # convert that into a clean 401, not an uncaught RuntimeError (500).
    with pytest.raises(HTTPException) as exc:
        get_current_user(credentials=_creds("a.b.c"))
    assert exc.value.status_code == 401


def test_two_segment_token_with_unconfigured_supabase_returns_401(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    clear_auth_client_cache()

    # 0 dots -> goes straight to verify_supabase_token (real impl) which must
    # raise 401, not 500, when the backend is unconfigured.
    with pytest.raises(HTTPException) as exc:
        get_current_user(credentials=_creds("not-a-jwt-no-dots"))
    assert exc.value.status_code == 401


# ---------------------------------------------------------------------------
# Wire-level regression (full HTTP, real verifiers, unconfigured Supabase)
# ---------------------------------------------------------------------------

def test_invalid_token_over_http_returns_401_not_500(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    monkeypatch.setenv("ENVIRONMENT", "development")
    clear_auth_client_cache()

    app = FastAPI()
    app.include_router(user_router)
    with TestClient(app) as client:
        resp = client.get(
            "/user/profile", headers={"Authorization": "Bearer a.b.c"}
        )
    assert resp.status_code == 401


def test_valid_account_token_over_http_reaches_profile(monkeypatch):
    monkeypatch.setattr(
        user_api,
        "verify_supabase_token",
        lambda tok: {
            "sub": "acct-wire",
            "email": "wire@example.com",
            "identity_type": "account",
        },
    )
    app = FastAPI()
    app.include_router(user_router)
    with TestClient(app) as client:
        resp = client.get(
            "/user/profile", headers={"Authorization": "Bearer account-token"}
        )
    assert resp.status_code == 200
    assert resp.json()["uid"] == "acct-wire"
    assert resp.json()["identity_type"] == "account"
