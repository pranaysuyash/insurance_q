from datetime import datetime, timedelta, timezone

from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.api import subscription


def _app(tmp_path, monkeypatch):
    monkeypatch.setattr(subscription, "DB_PATH", str(tmp_path / "billing.db"))
    monkeypatch.setenv("REVENUECAT_WEBHOOK_AUTHORIZATION", "Bearer rc-test")
    app = FastAPI()
    app.include_router(subscription.router)
    return app


def _event(event_id, event_type, *, expiry=None):
    return {
        "event": {
            "id": event_id,
            "type": event_type,
            "app_user_id": "account-1",
            "product_id": "coverwise_plus_monthly",
            "expiration_at_ms": expiry,
        }
    }


def test_revenuecat_webhook_is_authorized_and_idempotent(tmp_path, monkeypatch):
    app = _app(tmp_path, monkeypatch)
    expiry = int((datetime.now(timezone.utc) + timedelta(days=30)).timestamp() * 1000)
    with TestClient(app) as client:
        unauthorized = client.post("/subscription/webhook", json=_event("e1", "INITIAL_PURCHASE"))
        assert unauthorized.status_code == 401

        headers = {"Authorization": "Bearer rc-test"}
        first = client.post(
            "/subscription/webhook",
            json=_event("e1", "INITIAL_PURCHASE", expiry=expiry),
            headers=headers,
        )
        duplicate = client.post(
            "/subscription/webhook",
            json=_event("e1", "INITIAL_PURCHASE", expiry=expiry),
            headers=headers,
        )

    assert first.status_code == 200
    assert first.json()["plan_tier"] == "plus"
    assert first.json()["is_active"] is True
    assert duplicate.status_code == 200
    assert duplicate.json()["status"] == "duplicate"


def test_expiration_overrides_client_sync(tmp_path, monkeypatch):
    app = _app(tmp_path, monkeypatch)
    expiry = int((datetime.now(timezone.utc) + timedelta(days=30)).timestamp() * 1000)
    with TestClient(app) as client:
        headers = {"Authorization": "Bearer rc-test"}
        purchased = client.post(
            "/subscription/webhook",
            json=_event("e1", "INITIAL_PURCHASE", expiry=expiry),
            headers=headers,
        )
        assert purchased.status_code == 200

        expired = client.post(
            "/subscription/webhook",
            json=_event("e2", "EXPIRATION", expiry=expiry),
            headers=headers,
        )
        assert expired.status_code == 200
        assert expired.json()["is_active"] is False
