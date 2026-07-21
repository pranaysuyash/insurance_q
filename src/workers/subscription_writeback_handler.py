"""Durable client-sync entitlement writeback handler."""

from __future__ import annotations

from src.models.job_outbox import OutboxJob
from src.services.billing_ledger_service import BillingLedger


async def handle_subscription_writeback(job: OutboxJob) -> None:
    payload = job.payload
    required = (
        "user_uid", "plan_tier", "is_active", "synced_at",
    )
    missing = [key for key in required if key not in payload]
    if missing:
        raise ValueError(f"subscription_writeback job missing fields: {','.join(missing)}")
    raw_active = payload["is_active"]
    if isinstance(raw_active, bool):
        is_active = raw_active
    elif isinstance(raw_active, str) and raw_active.strip().lower() in {"true", "false"}:
        is_active = raw_active.strip().lower() == "true"
    else:
        raise ValueError("subscription_writeback job is_active must be a boolean")
    BillingLedger.from_env().record_client_sync(
        user_uid=str(payload["user_uid"]),
        plan_tier=str(payload["plan_tier"]),
        product_id=payload.get("product_id"),
        expires_at=payload.get("expires_at"),
        is_active=is_active,
        revenuecat_app_user_id=payload.get("revenuecat_app_user_id"),
        synced_at=str(payload["synced_at"]),
    )
