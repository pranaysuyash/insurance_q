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
import hmac
import logging
import os
import sqlite3
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
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
            raw_customer_info TEXT,
            source TEXT NOT NULL DEFAULT 'client_sync'
        )
    """)
    try:
        conn.execute("ALTER TABLE subscription_sync ADD COLUMN source TEXT NOT NULL DEFAULT 'client_sync'")
    except sqlite3.OperationalError:
        pass
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
    conn.execute("""
        CREATE TABLE IF NOT EXISTS revenuecat_webhook_events (
            event_id TEXT PRIMARY KEY,
            event_type TEXT NOT NULL,
            app_user_id TEXT NOT NULL,
            received_at TEXT NOT NULL,
            processed_at TEXT,
            processing_result TEXT NOT NULL,
            error_class TEXT
        )
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

    # Security: log a warning when a non-free plan is synced. The client
    # is the source of truth for RevenueCat state (no server-side webhook
    # verification yet — Security Phase 2). Until then, operator monitoring
    # of these warnings detects client-side plan spoofing.
    _valid_tiers = ('free', 'plus', 'family')
    plan_tier = request.plan_tier
    if plan_tier not in _valid_tiers:
        logger.warning(
            "SPOOFING_ATTEMPT user=%s claimed_plan=%s — unknown tier rejected, forced to free",
            current_user.uid[:8], plan_tier,
        )
        plan_tier = 'free'
    elif plan_tier != 'free':
        logger.warning(
            "NON_FREE_PLAN_SYNC user=%s plan=%s product=%s — "
            "verify against RevenueCat webhook when available",
            current_user.uid[:8], plan_tier, request.product_id or 'none',
        )

    server_now = datetime.now(timezone.utc).isoformat()

    # A client sync can reconcile a verified record, but it must not replace a
    # paid state established by a RevenueCat webhook.
    conn = sqlite3.connect(DB_PATH)
    try:
        verified = conn.execute(
            "SELECT plan_tier, product_id, expires_at, is_active, synced_at "
            "FROM subscription_sync WHERE user_uid = ? AND source = 'revenuecat_webhook' "
            "AND is_active = 1 ORDER BY synced_at DESC LIMIT 1",
            (current_user.uid,),
        ).fetchone()
        if verified is not None and plan_tier == "free":
            return {
                "status": "verified_state_preserved",
                "plan_tier": verified[0],
                "is_active": bool(verified[3]),
                "synced_at": verified[4],
            }

        # Deactivate any existing active client sync for this user.
        conn.execute(
            "UPDATE subscription_sync SET is_active = 0 WHERE user_uid = ? "
            "AND is_active = 1 AND source = 'client_sync'",
            (current_user.uid,),
        )

        # Insert new sync record
        raw_info = request.raw_customer_info
        if raw_info and len(raw_info) > 4096:
            logger.warning(
                "raw_customer_info truncated from %d to 4096 bytes for user %s",
                len(raw_info), current_user.uid[:8],
            )
            raw_info = raw_info[:4096]  # Truncate to prevent storage abuse

        conn.execute(
            """
            INSERT INTO subscription_sync
              (user_uid, plan_tier, product_id, expires_at, is_active,
               revenuecat_app_user_id, synced_at, raw_customer_info, source)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'client_sync')
            """,
            (
                current_user.uid,
                plan_tier,
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
            plan_tier,
            request.product_id or "none",
            request.is_active,
        )

        return {
            "status": "synced",
            # Return the normalized value that was actually persisted. This
            # keeps the response from echoing an untrusted client claim.
            "plan_tier": plan_tier,
            "is_active": request.is_active,
            "synced_at": server_now,
        }
    except Exception as e:
        logger.warning("Subscription sync failed for user %s: %s", current_user.uid[:8], e)
        raise HTTPException(status_code=500, detail="Subscription sync failed")
    finally:
        conn.close()


def _require_revenuecat_webhook(
    authorization: str | None,
) -> None:
    expected = os.getenv("REVENUECAT_WEBHOOK_AUTHORIZATION", "").strip()
    if not expected:
        raise HTTPException(status_code=503, detail="RevenueCat webhook authorization is not configured")
    if not authorization or not hmac.compare_digest(authorization, expected):
        raise HTTPException(status_code=401, detail="Unauthorized webhook")


def _webhook_plan(product_id: str | None) -> str:
    product = (product_id or "").lower()
    if "family" in product:
        return "family"
    if "plus" in product:
        return "plus"
    return "free"


def _webhook_expiry(event: dict) -> str | None:
    raw = event.get("expiration_at_ms")
    if raw in (None, ""):
        return None
    try:
        return datetime.fromtimestamp(float(raw) / 1000, tz=timezone.utc).isoformat()
    except (TypeError, ValueError, OverflowError):
        return None


@router.post("/webhook")
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(default=None),
):
    """Accept authenticated, idempotent RevenueCat subscription events.

    RevenueCat retries non-200 deliveries. The event ID is therefore the
    idempotency key; duplicate deliveries return 200 without reapplying state.
    Cancellation preserves access until expiration, while expiration/revoked
    events remove the verified active entitlement.
    """
    _require_revenuecat_webhook(authorization)
    try:
        payload = await request.json()
        event = payload.get("event") if isinstance(payload, dict) else None
        if not isinstance(event, dict):
            raise ValueError("missing event")
        event_id = str(event.get("id") or "").strip()
        event_type = str(event.get("type") or "").upper().strip()
        app_user_id = str(event.get("app_user_id") or "").strip()
        if not event_id or not event_type or not app_user_id:
            raise ValueError("missing event identity")
    except (ValueError, TypeError, json.JSONDecodeError) as error:
        raise HTTPException(status_code=400, detail="Invalid RevenueCat webhook payload") from error

    now = datetime.now(timezone.utc).isoformat()
    expiry = _webhook_expiry(event)
    product_id = event.get("product_id")
    plan_tier = _webhook_plan(product_id)
    active_events = {
        "INITIAL_PURCHASE",
        "RENEWAL",
        "UNCANCELLATION",
        "PRODUCT_CHANGE",
        "SUBSCRIPTION_EXTENDED",
        "NON_RENEWING_PURCHASE",
    }
    revoke_events = {"EXPIRATION", "REFUND_REVERSED"}
    if event_type not in active_events | revoke_events | {"CANCELLATION", "BILLING_ISSUE", "TRANSFER"}:
        # Unknown event types are acknowledged safely. RevenueCat may add
        # event types without making old deployments retry forever.
        return {"status": "ignored", "event_id": event_id, "event_type": event_type}

    conn = sqlite3.connect(DB_PATH)
    try:
        _init_subscription_table()
        inserted = conn.execute(
            "INSERT OR IGNORE INTO revenuecat_webhook_events "
            "(event_id, event_type, app_user_id, received_at, processing_result) "
            "VALUES (?, ?, ?, ?, 'received')",
            (event_id, event_type, app_user_id, now),
        ).rowcount
        if not inserted:
            return {"status": "duplicate", "event_id": event_id}

        current_active = event_type in active_events or (
            event_type in {"CANCELLATION", "BILLING_ISSUE"}
            and expiry is not None
            and datetime.fromisoformat(expiry) > datetime.now(timezone.utc)
        )
        if event_type == "TRANSFER":
            current_active = True

        conn.execute(
            "UPDATE subscription_sync SET is_active = 0 WHERE user_uid = ? "
            "AND is_active = 1 AND source = 'revenuecat_webhook'",
            (app_user_id,),
        )
        conn.execute(
            "INSERT INTO subscription_sync "
            "(user_uid, plan_tier, product_id, expires_at, is_active, "
            "revenuecat_app_user_id, synced_at, raw_customer_info, source) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 'revenuecat_webhook')",
            (
                app_user_id,
                plan_tier if current_active else "free",
                product_id,
                expiry,
                1 if current_active else 0,
                app_user_id,
                now,
            ),
        )
        conn.execute(
            "UPDATE revenuecat_webhook_events SET processed_at=?, processing_result='processed' "
            "WHERE event_id=?",
            (now, event_id),
        )
        conn.commit()
        return {
            "status": "processed",
            "event_id": event_id,
            "event_type": event_type,
            "plan_tier": plan_tier if current_active else "free",
            "is_active": current_active,
        }
    except Exception as error:
        conn.rollback()
        conn.execute(
            "UPDATE revenuecat_webhook_events SET processed_at=?, processing_result='failed', error_class=? "
            "WHERE event_id=?",
            (now, type(error).__name__, event_id),
        )
        conn.commit()
        raise HTTPException(status_code=500, detail="RevenueCat webhook processing failed") from error
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
        verified_row = conn.execute(
            """
            SELECT plan_tier, product_id, expires_at, is_active, synced_at
            FROM subscription_sync
            WHERE user_uid = ? AND source = 'revenuecat_webhook'
            ORDER BY synced_at DESC
            LIMIT 1
            """,
            (current_user.uid,),
        ).fetchone()
        # A verified webhook record always wins over client reconciliation,
        # including a verified expiration/revocation.
        if verified_row is not None:
            return {
                "plan_tier": verified_row["plan_tier"],
                "is_active": bool(verified_row["is_active"]),
                "product_id": verified_row["product_id"],
                "expires_at": verified_row["expires_at"],
                "synced_at": verified_row["synced_at"],
                "is_expired": not bool(verified_row["is_active"]),
                "source": "revenuecat_webhook",
            }

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
