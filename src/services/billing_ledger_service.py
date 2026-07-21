"""Server-authoritative billing ledger adapters.

Production uses the Supabase ledger and its transactional RevenueCat RPC.
SQLite remains available for isolated development/tests only.
"""

from __future__ import annotations

import os
from typing import Any


def use_remote_billing() -> bool:
    environment = os.getenv("ENVIRONMENT", "development").lower()
    backend = os.getenv(
        "BILLING_LEDGER_BACKEND",
        "supabase" if environment == "production" else "sqlite",
    ).lower()
    if backend == "supabase":
        return True
    if backend == "sqlite" and environment != "production":
        return False
    raise RuntimeError("SQLite billing ledger is not allowed in production")


class BillingLedger:
    def __init__(self, client: Any):
        self._client = client

    @classmethod
    def from_env(cls) -> "BillingLedger":
        url = os.getenv("SUPABASE_URL", "").strip()
        key = (
            os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
            or os.getenv("SUPABASE_SECRET_KEY", "").strip()
        )
        if not url or not key:
            raise RuntimeError("Supabase billing ledger requires server credentials")
        from supabase import create_client

        return cls(create_client(url, key))

    def record_client_sync(
        self,
        *,
        user_uid: str,
        plan_tier: str,
        product_id: str | None,
        expires_at: str | None,
        is_active: bool,
        revenuecat_app_user_id: str | None,
        synced_at: str,
    ) -> dict[str, Any]:
        verified = (
            self._client.table("billing_subscription_states")
            .select("plan_tier,is_active,synced_at")
            .eq("user_uid", user_uid)
            .eq("source", "revenuecat_webhook")
            .limit(1)
            .execute()
        )
        if verified.data:
            row = verified.data[0]
            return {
                "status": "verified_state_preserved",
                "plan_tier": row.get("plan_tier", "free"),
                "is_active": bool(row.get("is_active")),
                "synced_at": row.get("synced_at"),
            }

        response = (
            self._client.table("billing_subscription_states")
            .upsert(
                {
                    "user_uid": user_uid,
                    "plan_tier": plan_tier,
                    "product_id": product_id,
                    "expires_at": expires_at,
                    "is_active": is_active,
                    "revenuecat_app_user_id": revenuecat_app_user_id,
                    "synced_at": synced_at,
                    "source": "client_sync",
                    "updated_at": synced_at,
                },
                on_conflict="user_uid",
            )
            .execute()
        )
        if not response.data:
            raise RuntimeError("Supabase billing client sync was not persisted")
        return {
            "status": "synced",
            "plan_tier": plan_tier,
            "is_active": is_active,
            "synced_at": synced_at,
        }

    def process_revenuecat_webhook(
        self,
        *,
        event_id: str,
        event_type: str,
        app_user_id: str,
        event_timestamp_ms: int | None,
        product_id: str | None,
        expires_at: str | None,
    ) -> dict[str, Any]:
        response = self._client.rpc(
            "process_revenuecat_webhook",
            {
                "p_event_id": event_id,
                "p_event_type": event_type,
                "p_app_user_id": app_user_id,
                "p_event_timestamp_ms": event_timestamp_ms,
                "p_product_id": product_id,
                "p_expires_at": expires_at,
            },
        ).execute()
        data = response.data
        if isinstance(data, list):
            data = data[0] if data else None
        if not isinstance(data, dict):
            raise RuntimeError("Supabase billing webhook returned no result")
        return data

    def get_status(self, user_uid: str) -> dict[str, Any] | None:
        response = (
            self._client.table("billing_subscription_states")
            .select("plan_tier,product_id,expires_at,is_active,synced_at,source")
            .eq("user_uid", user_uid)
            .limit(1)
            .execute()
        )
        return response.data[0] if response.data else None
