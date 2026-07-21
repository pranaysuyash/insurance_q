import asyncio
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.api import subscription
from src.workers.revenuecat_webhook_handler import handle_revenuecat_webhook


def test_revenuecat_webhook_is_queued_in_remote_mode(monkeypatch):
    class FakeOutbox:
        requests = []

        async def enqueue(self, request):
            self.requests.append(request)
            return "job-id"

    fake = FakeOutbox()
    monkeypatch.setattr(subscription, "use_remote_billing", lambda: True)
    monkeypatch.setattr(
        subscription.JobOutboxService,
        "from_env",
        classmethod(lambda cls: fake),
    )
    monkeypatch.setenv("REVENUECAT_WEBHOOK_AUTHORIZATION", "Bearer test")
    app = FastAPI()
    app.include_router(subscription.router)

    with TestClient(app) as client:
        response = client.post(
            "/subscription/webhook",
            headers={"Authorization": "Bearer test"},
            json={
                "event": {
                    "id": "queued-event",
                    "type": "INITIAL_PURCHASE",
                    "app_user_id": "account-1",
                    "product_id": "coverwise_plus_monthly",
                }
            },
        )

    assert response.status_code == 200
    assert response.json() == {
        "status": "accepted",
        "event_id": "queued-event",
        "queued": True,
    }
    assert len(fake.requests) == 1
    assert fake.requests[0].payload["event_id"] == "queued-event"


def test_revenuecat_webhook_handler_calls_transactional_ledger(monkeypatch):
    calls = []

    class FakeLedger:
        def process_revenuecat_webhook(self, **kwargs):
            calls.append(kwargs)
            return {"status": "processed"}

    monkeypatch.setattr(
        "src.workers.revenuecat_webhook_handler.BillingLedger.from_env",
        classmethod(lambda cls: FakeLedger()),
    )
    job = SimpleNamespace(
        id="job-id",
        payload={
            "event_id": "event-1",
            "event_type": "RENEWAL",
            "app_user_id": "account-1",
            "event_timestamp_ms": 10,
            "product_id": "coverwise_plus_monthly",
            "expires_at": None,
        },
    )

    asyncio.run(handle_revenuecat_webhook(job))

    assert calls == [{
        "event_id": "event-1",
        "event_type": "RENEWAL",
        "app_user_id": "account-1",
        "event_timestamp_ms": 10,
        "product_id": "coverwise_plus_monthly",
        "expires_at": None,
    }]
