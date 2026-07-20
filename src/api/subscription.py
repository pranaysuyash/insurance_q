"""
Subscription sync endpoint for CoverWise.

Receives RevenueCat customer info from the mobile app and records the
subscription state server-side. This enables:
- Server-side entitlement verification (prevents client-side spoofing)
- Cost attribution (which users are on which plan, for unit economics)
- Operator monitoring (subscription health dashboard)
- Future: webhook from RevenueCat for real-time subscription events

Phase: M17 (subscription sync endpoint)
"""

import json
import logging
import os
import sqlite3
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from src.api.user import get_current_user
from src.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/subscription", tags=["subscription"])

DB_PATH = "insurance_app.db"


def _init_subscription_table():
    """Create the subscription_sync table if it doesn't exist.

    Indexes:
    - idx_sub_sync_user (user_uid): per-user subscription lookups
    - idx_sub_sync_expires (expires_at): renewal reminder queries
    """
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS subscription_sync (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_uid TEXT NOT NULL,
            plan_tier TEXT NOT NULL DEFAULT 'free',
            product_id TEXT,
            expires_at TEXT,
            is_active INTEGER NOT NULL DEFAULT 0,
            revenuecat_app_user_id TEXT,
            synced_at TEXT NOT NULL,
            raw_customer_info TEXT
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_sub_sync_user
        ON subscription_sync(user_uid)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_sub_sync_expires
        ON subscription_sync(expires_at)
    """)
    # Unique constraint: one active sync record per user
    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_sub_sync_user_active
        ON subscription_sync(user_uid, is_active)
        WHERE is_active = 1
    """)
    conn.commit()
    conn.close()


class SubscriptionSyncRequest(BaseModel):
    """Client sends the plan tier and RevenueCat customer info after each
    purchase, restore, or app startup sync."""
    plan_tier: str = Field(
        default="free",
        description="PlanTier name: free, plus, or family",
    )
    product_id: Optional[str] = Field(
        default=None,
        description="RevenueCat product identifier (e.g. coverwise_plus_monthly)",
    )
    expires_at: Optional[str] = Field(
        default=None,
        description="ISO 8601 UTC subscription expiry from RevenueCat",
    )
    is_active: bool = Field(
        default=True,
        description="Whether the subscription is currently active",
    )
    revenuecat_app_user_id: Optional[str] = Field(
        default=None,
        description="RevenueCat app_user_id for cross-reference",
    )
    # Raw CustomerInfo for debugging (truncated to 4KB to prevent abuse)
    raw_customer_info: Optional[str] = Field(
        default=None,
        description="Truncated JSON of RevenueCat CustomerInfo",
    )


@router.post("/sync")
def sync_subscription(
    request: SubscriptionSyncRequest,
    current_user: User = Depends(get_current_user),
):
    """Record subscription state from the client's RevenueCat sync.

    The client calls this after:
    1. App startup (billingInitProvider)
    2. Successful purchase
    3. Restore purchases
    4. Subscription expiry detected

    This is a write-only endpoint — the client is the source of truth for
    RevenueCat state. Server-side verification (RevenueCat webhook) is
    Security Phase 2.
    """
    _init_subscription_table()

    server_now = datetime.now(timezone.utc).isoformat()

    # Deactivate any existing active sync for this user
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute(
            "UPDATE subscription_sync SET is_active = 0 WHERE user_uid = ? AND is_active = 1",
            (current_user.uid,),
        )

        # Insert new sync record
        raw_info = request.raw_customer_info
        if raw_info and len(raw_info) > 4096:
            raw_info = raw_info[:4096]  # Truncate to prevent storage abuse

        conn.execute(
            """
            INSERT INTO subscription_sync
              (user_uid, plan_tier, product_id, expires_at, is_active,
               revenuecat_app_user_id, synced_at, raw_customer_info)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                current_user.uid,
                request.plan_tier,
                request.product_id,
                request.expires_at,
                1 if request.is_active else 0,
                request.revenuecat_app_user_id,
                server_now,
                raw_info,
            ),
        )
        conn.commit()

        logger.info(
            "Subscription sync: user=%s plan=%s product=%s active=%s",
            current_user.uid[:8],
            request.plan_tier,
            request.product_id or "none",
            request.is_active,
        )

        return {
            "status": "synced",
            "plan_tier": request.plan_tier,
            "is_active": request.is_active,
            "synced_at": server_now,
        }
    except Exception as e:
        logger.warning("Subscription sync failed for user %s: %s", current_user.uid[:8], e)
        raise HTTPException(status_code=500, detail="Subscription sync failed")
    finally:
        conn.close()


@router.get("/status")
def get_subscription_status(
    current_user: User = Depends(get_current_user),
):
    """Get the current subscription status for the authenticated user.

    Returns the most recent active sync record, or the free-tier default
    if no sync has been recorded.
    """
    _init_subscription_table()

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        row = conn.execute(
            """
            SELECT plan_tier, product_id, expires_at, is_active, synced_at
            FROM subscription_sync
            WHERE user_uid = ? AND is_active = 1
            ORDER BY synced_at DESC
            LIMIT 1
            """,
            (current_user.uid,),
        ).fetchone()

        if row is None:
            return {
                "plan_tier": "free",
                "is_active": True,
                "product_id": None,
                "expires_at": None,
                "synced_at": None,
            }

        # Check if subscription has expired
        is_expired = False
        if row["expires_at"]:
            try:
                expires = datetime.fromisoformat(row["expires_at"].replace("Z", "+00:00"))
                is_expired = datetime.now(timezone.utc) > expires
            except (ValueError, TypeError):
                pass

        return {
            "plan_tier": row["plan_tier"] if not is_expired else "free",
            "is_active": bool(row["is_active"]) and not is_expired,
            "product_id": row["product_id"],
            "expires_at": row["expires_at"],
            "synced_at": row["synced_at"],
            "is_expired": is_expired,
        }
    finally:
        conn.close()
