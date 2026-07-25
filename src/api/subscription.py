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
from src.services.billing_ledger_service import BillingLedger, use_remote_billing
from src.models.job_outbox import EnqueueRequest, JobType
from src.services.job_outbox_service import JobOutboxService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/subscription", tags=["subscription"])

DB_PATH = "insurance_app.db"


def _ensure_subscription_schema(conn: sqlite3.Connection) -> None:
    """Create the local development billing schema on an existing connection.

    Keeping schema initialization on the caller's connection avoids opening a
    second SQLite connection while a webhook transaction is in progress. The
    production billing authority is still expected to be moved to the remote
    ledger before launch; this schema is the explicit non-production fallback.

    Indexes:
    - idx_sub_sync_user (user_uid): per-user subscription lookups
    - idx_sub_sync_expires (expires_at): renewal reminder queries
    """
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
        conn.execute(
            "ALTER TABLE subscription_sync ADD COLUMN source TEXT NOT NULL DEFAULT 'client_sync'"
        )
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
            event_timestamp_ms INTEGER,
            received_at TEXT NOT NULL,
            processed_at TEXT,
            processing_result TEXT NOT NULL,
            error_class TEXT
        )
    """)
    try:
        conn.execute(
            "ALTER TABLE revenuecat_webhook_events ADD COLUMN event_timestamp_ms INTEGER"
        )
    except sqlite3.OperationalError:
        pass
    conn.commit()


def _init_subscription_table() -> None:
    """Initialize the local fallback billing schema."""
    conn = sqlite3.connect(DB_PATH)
    try:
        _ensure_subscription_schema(conn)
    finally:
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

    Client sync is reconciliation telemetry. A verified RevenueCat webhook
    state always takes precedence over it.
    """
    # Security: log a warning when a non-free plan is synced. Client sync is
    # reconciliation telemetry; verified webhook state remains authoritative.
    _valid_tiers = ("free", "plus", "family")
    plan_tier = request.plan_tier
    if plan_tier not in _valid_tiers:
        logger.warning(
            "SPOOFING_ATTEMPT user=%s claimed_plan=%s — unknown tier rejected, forced to free",
            current_user.uid[:8],
            plan_tier,
        )
        plan_tier = "free"
    elif plan_tier != "free":
        logger.warning(
            "NON_FREE_PLAN_SYNC user=%s plan=%s product=%s — "
            "reconcile against RevenueCat webhook state",
            current_user.uid[:8],
            plan_tier,
            request.product_id or "none",
        )

    server_now = datetime.now(timezone.utc).isoformat()

    if use_remote_billing():
        try:
            return BillingLedger.from_env().record_client_sync(
                user_uid=current_user.uid,
                plan_tier=plan_tier,
                product_id=request.product_id,
                expires_at=request.expires_at,
                is_active=request.is_active,
                revenuecat_app_user_id=request.revenuecat_app_user_id,
                synced_at=server_now,
            )
        except Exception as error:
            logger.error(
                "Supabase billing client sync unavailable: %s", type(error).__name__
            )
            raise HTTPException(
                status_code=503, detail="Subscription ledger unavailable"
            ) from error

    _init_subscription_table()

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
                len(raw_info),
                current_user.uid[:8],
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
        logger.warning(
            "Subscription sync failed for user %s: %s", current_user.uid[:8], e
        )
        raise HTTPException(status_code=500, detail="Subscription sync failed")
    finally:
        conn.close()


def _require_revenuecat_webhook(
    authorization: str | None,
) -> None:
    expected = os.getenv("REVENUECAT_WEBHOOK_AUTHORIZATION", "").strip()
    if not expected:
        raise HTTPException(
            status_code=503, detail="RevenueCat webhook authorization is not configured"
        )
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


def _webhook_timestamp_ms(event: dict) -> int | None:
    raw = event.get("event_timestamp_ms")
    if raw in (None, ""):
        return None
    try:
        value = int(raw)
        return value if value >= 0 else None
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
    Cancellation preserves access until expiration, while expiration removes
    the verified active entitlement. A provider refund reversal can restore
    access only through the provider-reported expiration.
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
        raise HTTPException(
            status_code=400, detail="Invalid RevenueCat webhook payload"
        ) from error

    now = datetime.now(timezone.utc).isoformat()
    expiry = _webhook_expiry(event)
    event_timestamp_ms = _webhook_timestamp_ms(event)
    product_id = event.get("product_id")
    plan_tier = _webhook_plan(product_id)
    active_events = {
        "INITIAL_PURCHASE",
        "RENEWAL",
        "UNCANCELLATION",
        "PRODUCT_CHANGE",
        "SUBSCRIPTION_EXTENDED",
        "NON_RENEWING_PURCHASE",
        "REFUND_REVERSED",
    }
    revoke_events = {"EXPIRATION"}
    if event_type not in active_events | revoke_events | {
        "CANCELLATION",
        "BILLING_ISSUE",
        "TRANSFER",
    }:
        # Unknown event types are acknowledged safely. RevenueCat may add
        # event types without making old deployments retry forever.
        return {"status": "ignored", "event_id": event_id, "event_type": event_type}

    # Consumable purchases are handled only by the server-owned pack
    # catalogue. An unknown non-renewing product must not fall through to
    # subscription reconciliation and downgrade an existing subscription.
    if event_type == "NON_RENEWING_PURCHASE" and plan_tier == "free":
        return {
            "status": "unsupported_product",
            "event_id": event_id,
            "event_type": event_type,
        }

    if use_remote_billing():
        try:
            outbox = JobOutboxService.from_env()
            await outbox.enqueue(
                EnqueueRequest(
                    job_type=JobType.WEBHOOK_RECONCILIATION,
                    payload={
                        "event_id": event_id,
                        "event_type": event_type,
                        "app_user_id": app_user_id,
                        "event_timestamp_ms": event_timestamp_ms,
                        "product_id": product_id,
                        "expires_at": expiry,
                    },
                    max_attempts=8,
                )
            )
            return {"status": "accepted", "event_id": event_id, "queued": True}
        except Exception as error:
            logger.error(
                "RevenueCat webhook could not be queued: %s", type(error).__name__
            )
            raise HTTPException(
                status_code=503, detail="Webhook queue unavailable"
            ) from error

    conn = sqlite3.connect(DB_PATH)
    try:
        _ensure_subscription_schema(conn)
        inserted = conn.execute(
            "INSERT OR IGNORE INTO revenuecat_webhook_events "
            "(event_id, event_type, app_user_id, event_timestamp_ms, received_at, processing_result) "
            "VALUES (?, ?, ?, ?, ?, 'received')",
            (event_id, event_type, app_user_id, event_timestamp_ms, now),
        ).rowcount
        if not inserted:
            return {"status": "duplicate", "event_id": event_id}

        # RevenueCat retries and delivery reordering are expected. Never let
        # an older event overwrite a newer verified state for the same app
        # user. Events without a provider timestamp retain arrival-order
        # compatibility because there is no safe ordering signal.
        if event_timestamp_ms is not None:
            latest = conn.execute(
                "SELECT MAX(event_timestamp_ms) FROM revenuecat_webhook_events "
                "WHERE app_user_id = ? AND event_id <> ? AND event_timestamp_ms IS NOT NULL",
                (app_user_id, event_id),
            ).fetchone()
            if (
                latest
                and latest[0] is not None
                and event_timestamp_ms <= int(latest[0])
            ):
                conn.execute(
                    "UPDATE revenuecat_webhook_events SET processed_at=?, processing_result='stale_ignored' WHERE event_id=?",
                    (now, event_id),
                )
                conn.commit()
                return {
                    "status": "stale_ignored",
                    "event_id": event_id,
                    "event_type": event_type,
                }

        current_active = (
            event_type in active_events
            and (
                expiry is None
                or datetime.fromisoformat(expiry) > datetime.now(timezone.utc)
            )
        ) or (
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
        raise HTTPException(
            status_code=500, detail="RevenueCat webhook processing failed"
        ) from error
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
    if use_remote_billing():
        try:
            row = BillingLedger.from_env().get_status(current_user.uid)
        except Exception as error:
            logger.error(
                "Supabase billing status unavailable: %s", type(error).__name__
            )
            raise HTTPException(
                status_code=503, detail="Subscription ledger unavailable"
            ) from error
        if row is None:
            return {
                "plan_tier": "free",
                "is_active": True,
                "product_id": None,
                "expires_at": None,
                "synced_at": None,
                "source": "default",
                "verified": False,
            }
        return {
            "plan_tier": row.get("plan_tier", "free"),
            "is_active": bool(row.get("is_active")),
            "product_id": row.get("product_id"),
            "expires_at": row.get("expires_at"),
            "synced_at": row.get("synced_at"),
            "source": row.get("source", "client_sync"),
            "verified": bool(row.get("verified", False)),
            "is_expired": not bool(row.get("is_active")),
        }

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

        # Client-sync rows are intentionally not an entitlement grant. They
        # remain available for reconciliation/diagnostics, but server gates
        # use the verified webhook row above or the free-tier default.
        return {
            "plan_tier": "free",
            "is_active": True,
            "product_id": None,
            "expires_at": None,
            "synced_at": None,
            "source": "default_unverified",
            "verified": False,
            "is_expired": False,
        }
    finally:
        conn.close()


@router.get("/qa-balance")
def get_qa_pack_balance(
    current_user: User = Depends(get_current_user),
):
    """Return the authenticated user's server-authoritative active pack balance."""
    if use_remote_billing():
        try:
            balance = BillingLedger.from_env().get_qa_pack_balance(current_user.uid)
        except Exception as error:
            logger.error(
                "Supabase Q&A pack balance unavailable: %s", type(error).__name__
            )
            raise HTTPException(
                status_code=503, detail="Q&A pack ledger unavailable"
            ) from error
        return {
            "packs": balance.get("packs", []),
            "pack_questions_remaining": int(balance.get("pack_questions_remaining", 0)),
            "source": "qa_pack_grants",
            "verified": True,
        }

    # Local development has no equivalent durable consumable ledger. Returning
    # an explicitly unverified empty balance prevents it from masquerading as
    # proof that a remote purchase was absent.
    return {
        "packs": [],
        "pack_questions_remaining": 0,
        "source": "local_unavailable",
        "verified": False,
    }
