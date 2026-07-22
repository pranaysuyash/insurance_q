from types import SimpleNamespace

import pytest

from src.services.billing_ledger_service import BillingLedger, use_remote_billing
from pathlib import Path


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


def test_remote_client_sync_is_not_an_entitlement_grant():
    client = _Client([{
        "plan_tier": "family",
        "is_active": True,
        "source": "client_sync",
        "synced_at": "now",
    }])

    result = BillingLedger(client).get_status("account-1")

    assert result["plan_tier"] == "free"
    assert result["is_active"] is True
    assert result["verified"] is False
    assert result["source"] == "client_sync"


def test_remote_webhook_state_is_authoritative_for_entitlement():
    client = _Client([{
        "plan_tier": "family",
        "is_active": True,
        "source": "revenuecat_webhook",
        "synced_at": "now",
    }])

    result = BillingLedger(client).get_status("account-1")

    assert result["plan_tier"] == "family"
    assert result["is_active"] is True
    assert result["verified"] is True


def test_remote_qa_pack_balance_uses_server_rpc():
    client = _Client()
    client.rpc = lambda name, params: SimpleNamespace(
        execute=lambda: SimpleNamespace(data={
            "packs": [{"product_id": "coverwise_qa_starter", "questions_remaining": 5}],
            "pack_questions_remaining": 5,
        })
    )

    result = BillingLedger(client).get_qa_pack_balance("account-1")

    assert result["pack_questions_remaining"] == 5


def test_pack_balance_migration_is_server_only_and_expiry_filtered():
    sql = Path("supabase/migrations/20260721260200_qa_pack_balance_readback.sql").read_text()

    assert "security definer" in sql
    assert "questions_remaining > 0" in sql
    assert "expires_at > now()" in sql
    assert "grant execute on function public.get_qa_pack_balance(text) to service_role" in sql


def test_identity_claim_migration_moves_pack_grants_with_documents():
    sql = Path(
        "supabase/migrations/20260721260300_identity_pack_transfer.sql"
    ).read_text()

    assert "update public.qa_pack_grants" in sql
    assert "where owner_id = p_anonymous_owner" in sql
    assert "set owner_id = p_account_owner" in sql
    assert "grant execute on function public.claim_anonymous_documents(text, text)" in sql


def test_production_migration_fences_unknown_consumable_products():
    sql = Path(
        "supabase/migrations/20260721200000_revenuecat_unknown_consumable_fence.sql"
    ).read_text()

    assert "'unsupported_product'" in sql
    assert "if p_event_type = 'NON_RENEWING_PURCHASE'" in sql
    assert "grant execute on function public.process_revenuecat_webhook" in sql


def test_pack_ordering_migration_handles_consumables_before_stale_state_check():
    sql = Path(
        "supabase/migrations/20260721260100_revenuecat_pack_event_ordering.sql"
    ).read_text()

    pack_branch = sql.index("if p_event_type = 'NON_RENEWING_PURCHASE'")
    stale_check = sql.index("if p_event_timestamp_ms is not null")
    assert pack_branch < stale_check
    assert "on conflict (provider_event_id) do nothing" in sql
