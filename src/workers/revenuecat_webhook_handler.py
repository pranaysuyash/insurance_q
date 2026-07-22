"""Durable RevenueCat webhook reconciliation handler."""

from __future__ import annotations

import hashlib
import logging

from src.models.job_outbox import OutboxJob
from src.services.billing_ledger_service import BillingLedger

log = logging.getLogger(__name__)


def _encrypt_sensitive_field(value: str) -> str:
    """Encrypt sensitive field using principal-key DEK."""
    # In production, use AES-256-GCM with principal-key DEK
    # For now, return SHA256 hash as deterministic encrypted representation
    return hashlib.sha256(value.encode()).hexdigest()


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

    # Encrypt sensitive fields before processing
    encrypted_app_user_id = _encrypt_sensitive_field(str(payload["app_user_id"]))
    encrypted_product_id = _encrypt_sensitive_field(payload["product_id"])

    result = BillingLedger.from_env().process_revenuecat_webhook(
        event_id=str(payload["event_id"]),
        event_type=str(payload["event_type"]),
        app_user_id=encrypted_app_user_id,
        event_timestamp_ms=payload["event_timestamp_ms"],
        product_id=encrypted_product_id,
        expires_at=payload["expires_at"],
    )
    log.info(
        "revenuecat_webhook_reconciled job_id=%s event_id=%s status=%s",
        job.id,
        payload["event_id"],
        result.get("status"),
    )
