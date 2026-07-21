from types import SimpleNamespace

import pytest

from src.services.billing_ledger_service import BillingLedger, use_remote_billing


class _Table:
    def __init__(self, rows=None):
        self.rows = rows or []
        self.upserted = None

    def select(self, *_args):
        return self

    def eq(self, *_args):
        return self

    def limit(self, *_args):
        return self

    def upsert(self, row, **_kwargs):
        self.upserted = row
        return self

    def execute(self):
        return SimpleNamespace(data=self.rows or ([self.upserted] if self.upserted else []))


class _Client:
    def __init__(self, rows=None):
        self.table_instance = _Table(rows)
        self.rpc_args = None

    def table(self, _name):
        return self.table_instance

    def rpc(self, _name, params):
        self.rpc_args = params
        return SimpleNamespace(execute=lambda: SimpleNamespace(data={"status": "processed"}))


def test_sqlite_billing_is_not_allowed_in_production(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("BILLING_LEDGER_BACKEND", "sqlite")
    with pytest.raises(RuntimeError, match="not allowed"):
        use_remote_billing()


def test_remote_webhook_uses_transactional_rpc():
    client = _Client()
    result = BillingLedger(client).process_revenuecat_webhook(
        event_id="event-1",
        event_type="RENEWAL",
        app_user_id="account-1",
        event_timestamp_ms=10,
        product_id="coverwise_plus_monthly",
        expires_at="2026-08-20T00:00:00+00:00",
    )
    assert result == {"status": "processed"}
    assert client.rpc_args == {
        "p_event_id": "event-1",
        "p_event_type": "RENEWAL",
        "p_app_user_id": "account-1",
        "p_event_timestamp_ms": 10,
        "p_product_id": "coverwise_plus_monthly",
        "p_expires_at": "2026-08-20T00:00:00+00:00",
    }


def test_verified_remote_state_wins_over_client_sync():
    client = _Client([{"plan_tier": "plus", "is_active": True, "synced_at": "now"}])
    result = BillingLedger(client).record_client_sync(
        user_uid="account-1",
        plan_tier="free",
        product_id=None,
        expires_at=None,
        is_active=True,
        revenuecat_app_user_id="account-1",
        synced_at="later",
    )
    assert result["status"] == "verified_state_preserved"
    assert client.table_instance.upserted is None
