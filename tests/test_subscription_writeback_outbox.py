from unittest.mock import patch

import pytest

from src.models.job_outbox import JobType, OutboxJob
from src.workers.subscription_writeback_handler import handle_subscription_writeback


def test_subscription_writeback_requires_identity():
    job = OutboxJob.model_construct(job_type=JobType.SUBSCRIPTION_WRITEBACK, payload={}, id="j")
    with pytest.raises(ValueError, match="user_uid"):
        import asyncio
        asyncio.run(handle_subscription_writeback(job))


def test_subscription_writeback_uses_server_ledger():
    job = OutboxJob.model_construct(job_type=JobType.SUBSCRIPTION_WRITEBACK, payload={
        "user_uid": "user-1", "plan_tier": "plus", "is_active": True,
        "synced_at": "2026-07-21T00:00:00+00:00",
    }, id="j")
    ledger = type("Ledger", (), {"record_client_sync": lambda self, **kwargs: kwargs})()
    with patch("src.workers.subscription_writeback_handler.BillingLedger.from_env", return_value=ledger):
        import asyncio
        asyncio.run(handle_subscription_writeback(job))


def test_subscription_writeback_does_not_activate_for_false_string():
    job = OutboxJob.model_construct(job_type=JobType.SUBSCRIPTION_WRITEBACK, payload={
        "user_uid": "user-1", "plan_tier": "free", "is_active": "false",
        "synced_at": "2026-07-21T00:00:00+00:00",
    }, id="j")
    calls = []
    ledger = type("Ledger", (), {
        "record_client_sync": lambda self, **kwargs: calls.append(kwargs),
    })()
    with patch("src.workers.subscription_writeback_handler.BillingLedger.from_env", return_value=ledger):
        import asyncio
        asyncio.run(handle_subscription_writeback(job))
    assert calls[0]["is_active"] is False
