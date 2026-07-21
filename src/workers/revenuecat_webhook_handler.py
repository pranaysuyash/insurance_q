"""Durable RevenueCat webhook reconciliation handler."""

from __future__ import annotations

import logging

from src.models.job_outbox import OutboxJob
from src.services.billing_ledger_service import BillingLedger

log = logging.getLogger(__name__)


async def handle_revenuecat_webhook(job: OutboxJob) -> None:
    """Apply one queued RevenueCat event through the transactional ledger RPC."""
    payload = job.payload
    required = (
        "event_id", "event_type", "app_user_id", "event_timestamp_ms",
        "product_id", "expires_at",
    )
    missing = [key for key in required if key not in payload]
    if missing:
        raise ValueError(f"webhook_reconciliation job missing fields: {','.join(missing)}")

    result = BillingLedger.from_env().process_revenuecat_webhook(
        event_id=str(payload["event_id"]),
        event_type=str(payload["event_type"]),
        app_user_id=str(payload["app_user_id"]),
        event_timestamp_ms=payload["event_timestamp_ms"],
        product_id=payload["product_id"],
        expires_at=payload["expires_at"],
    )
    log.info(
        "revenuecat_webhook_reconciled job_id=%s event_id=%s status=%s",
        job.id,
        payload["event_id"],
        result.get("status"),
    )
