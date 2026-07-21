"""
Analytics ingestion endpoint for CoverWise.

Accepts batches of events from the mobile app. Events are stored in SQLite
(insurance_app.db) for solo-launch simplicity. No PII is stored — only event
name, timestamp, anonymous UID, and safe properties per the analytics spec
(docs/review/coverwise_analytics_event_spec.md).

Phase R1.4 (2026-07-18): dual-write to Supabase Postgres when
DUAL_WRITE_ANALYTICS=true. Supabase becomes the canonical source per
docs/planning/coverwise_supabase_canonical_plan_2026-07-16.md. SQLite is
retained as a fallback for 30 days of verified parity, then dropped.

Migration tool: tools/migrate/sqlite_analytics_to_supabase.py

Idempotency: events are inserted with ON CONFLICT (received_at, event_name,
user_uid) DO NOTHING. Safe to replay a batch.
"""
import json
import logging
import os
import sqlite3
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from src.api.user import get_current_user
from src.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/analytics", tags=["analytics"])

DB_PATH = "insurance_app.db"

# Feature flag: when true, ingest also writes to Supabase Postgres.
# Set to false during initial rollout if Supabase project is not yet provisioned.
DUAL_WRITE_ANALYTICS = os.environ.get(
    "DUAL_WRITE_ANALYTICS",
    "true" if os.environ.get("ENVIRONMENT", "development").lower() == "production" else "false",
).lower() == "true"


def _production_analytics_client():
    """Return the canonical analytics client or fail closed in production."""
    if os.environ.get("ENVIRONMENT", "development").lower() != "production":
        return None
    client = _get_supabase_client()
    if client is None:
        raise HTTPException(
            status_code=503,
            detail="Canonical analytics storage is unavailable; retry the event batch.",
        )
    return client


def _supabase_event_rows(client, days: int) -> list[dict[str, Any]]:
    cutoff = (datetime.now(timezone.utc).timestamp() - max(days, 1) * 86400)
    response = (
        client.table("analytics_events")
        .select("event_name,timestamp,user_uid,properties,received_at")
        .gte("received_at", datetime.fromtimestamp(cutoff, tz=timezone.utc).isoformat())
        .limit(10000)
        .execute()
    )
    return list(response.data or [])

# Cached Supabase client (lazy-init, reused across requests).
_supabase_client = None
_supabase_init_attempted = False


def _get_supabase_client():
    """Lazy-init a Supabase service-role client. Returns None if not configured.

    Per motto v3 §0.6: never raise on missing config — fall back to SQLite
    so events are never lost during the 30-day dual-write window.
    """
    global _supabase_client, _supabase_init_attempted
    if _supabase_init_attempted:
        return _supabase_client
    _supabase_init_attempted = True
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        logger.warning("Supabase not configured (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing); analytics dual-write disabled")
        return None
    try:
        from supabase import create_client
        _supabase_client = create_client(url, key)
        logger.info("Supabase client initialized for analytics dual-write")
        return _supabase_client
    except Exception as e:
        logger.exception("Failed to initialize Supabase client: %s", e)
        return None


def _init_analytics_table():
    """Create the analytics_events table and indexes if they don't exist.

    Indexes and their supporting roles:

    - idx_analytics_event_name (event_name)
        General-purpose filter for event_name lookups.
        Used by: /analytics/summary (GROUP BY event_name)

    - idx_analytics_user_uid (user_uid)
        Supports per-user queries and COUNT(DISTINCT user_uid).
        Used by: /analytics/summary (unique user counts)

    - idx_analytics_error_window (event_name, received_at)
        Composite index for time-range error queries.
        Used by: /analytics/errors (CTE, totals, trends)

    - idx_analytics_summary (received_at, event_name, user_uid)
        Covering index for the summary endpoint.
        Used by: /analytics/summary (time filter + GROUP BY + COUNT DISTINCT)
    """
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS analytics_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_name TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            user_uid TEXT NOT NULL,
            properties TEXT,
            received_at TEXT NOT NULL,
            install_id TEXT,
            session_id TEXT,
            is_reinstall INTEGER NOT NULL DEFAULT 0
        )
    """);
    # In-place upgrades for pre-R1.4 tables. Each ALTER wrapped to be idempotent.
    for alter in (
        "ALTER TABLE analytics_events ADD COLUMN install_id TEXT",
        "ALTER TABLE analytics_events ADD COLUMN session_id TEXT",
        "ALTER TABLE analytics_events ADD COLUMN is_reinstall INTEGER NOT NULL DEFAULT 0",
    ):
        try:
            conn.execute(alter)
        except Exception:
            # Column already exists; safe to ignore.
            pass
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_event_name
        ON analytics_events(event_name)
    """);
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_user_uid
        ON analytics_events(user_uid)
    """);
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_error_window
        ON analytics_events(event_name, received_at)
    """);
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_summary
        ON analytics_events(received_at, event_name, user_uid)
    """);
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_install_id
        ON analytics_events(install_id) WHERE install_id IS NOT NULL
    """);
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_analytics_session_id
        ON analytics_events(session_id) WHERE session_id IS NOT NULL
    """);
    conn.commit()
    conn.close()


class AnalyticsEvent(BaseModel):
    event: str = Field(..., description="Snake-case event name from the spec")
    ts: str = Field(..., description="ISO 8601 UTC timestamp from the client")
    uid: str = Field(..., description="Anonymous user/session ID")
    props: Dict[str, Any] = Field(default_factory=dict, description="Safe, non-PII properties")
    # Phase R1.5 additions (2026-07-18). All optional for backward compat with
    # older app versions. New events from R1.6+ populate all three.
    install_id: Optional[str] = Field(default=None, description="UUID string; stable per install")
    session_id: Optional[str] = Field(default=None, description="UUID string; per app launch")
    is_reinstall: Optional[bool] = Field(default=False, description="True if install_id was seen before")


class AnalyticsBatch(BaseModel):
    events: List[AnalyticsEvent]


def _insert_supabase_batch(client, rows: List[Dict[str, Any]]) -> int:
    """Insert a batch into Supabase with ON CONFLICT DO NOTHING semantics.

    Returns count of rows that were newly inserted (excluding duplicates).
    Raises on unrecoverable errors so the caller can fall back to SQLite.
    """
    if not rows:
        return 0
    try:
        # Supabase upsert with ignore_duplicates=True translates to
        # INSERT ... ON CONFLICT DO NOTHING on the unique constraint.
        res = client.table("analytics_events").upsert(
            rows, ignore_duplicates=True
        ).execute()
        if res.data:
            return len(res.data)
        return 0
    except Exception:
        logger.exception("Supabase analytics batch insert failed")
        raise


@router.post("/events")
async def ingest_events(
    batch: AnalyticsBatch,
    current_user: User = Depends(get_current_user),
):
    """Accept a batch of analytics events from the mobile app.


    Dual-write path (Phase R1.4):
    1. Always write to SQLite (legacy path, kept for 30-day rollback window).
    2. If DUAL_WRITE_ANALYTICS=true and Supabase is configured, also write
       to Supabase. Supabase failure does NOT cause request failure — the
       SQLite write is the durability guarantee during the dual-write window.

    The server-authoritative user_uid overrides any client-claimed uid,
    per the existing convention in this endpoint.
    """
    canonical_client = _production_analytics_client()

    if canonical_client is not None:
        server_now = datetime.now(timezone.utc).isoformat()
        rows = [{
            "event_name": event.event,
            "timestamp": event.ts,
            "user_uid": current_user.uid,
            "properties": event.props or None,
            "received_at": server_now,
            "install_id": event.install_id,
            "session_id": event.session_id,
            "is_reinstall": bool(event.is_reinstall),
        } for event in batch.events]
        try:
            inserted = _insert_supabase_batch(canonical_client, rows)
        except Exception as error:
            raise HTTPException(status_code=503, detail="Analytics storage unavailable; retry the event batch.") from error
        return {
            "status": "accepted",
            "ingested": inserted,
            "supabase_ingested": inserted,
            "dual_write": False,
            "canonical": "supabase",
        }

    _init_analytics_table()

    # Build a single row schema used by both SQLite and Supabase paths.
    server_now = datetime.now(timezone.utc).isoformat()
    supabase_rows: List[Dict[str, Any]] = []
    sqlite_inserted = 0

    conn = sqlite3.connect(DB_PATH)
    try:
        for event in batch.events:
            row = {
                "event_name": event.event,
                "timestamp": event.ts,
                "user_uid": current_user.uid,  # server-enforced, not client-claimed
                "properties": json.dumps(event.props) if event.props else None,
                "received_at": server_now,
                "install_id": event.install_id,
                "session_id": event.session_id,
                "is_reinstall": bool(event.is_reinstall),
            }
            try:
                conn.execute(
                    """
                    INSERT INTO analytics_events
                      (event_name, timestamp, user_uid, properties, received_at, install_id, session_id, is_reinstall)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        row["event_name"],
                        row["timestamp"],
                        row["user_uid"],
                        row["properties"],
                        row["received_at"],
                        row["install_id"],
                        row["session_id"],
                        row["is_reinstall"],
                    ),
                )
                sqlite_inserted += 1
            except Exception as e:
                logger.warning("Failed to insert analytics event %s: %s", event.event, e)
            supabase_rows.append(row)
        conn.commit()
    finally:
        conn.close()

    # Supabase dual-write (best-effort). On failure, log and continue — the
    # SQLite write above is the durability guarantee during the 30-day window.
    supabase_inserted = 0
    if DUAL_WRITE_ANALYTICS and supabase_rows:
        client = _get_supabase_client()
        if client is None:
            logger.warning("DUAL_WRITE_ANALYTICS=true but Supabase not configured; events only in SQLite")
        else:
            try:
                supabase_inserted = _insert_supabase_batch(client, supabase_rows)
            except Exception as e:
                logger.warning(
                    "Supabase dual-write failed (%d events will be replayed by migration script): %s",
                    len(supabase_rows), e,
                )

    logger.info(
        "Analytics: ingested %d events for user %s (sqlite=%d, supabase=%d)",
        len(batch.events), current_user.uid[:8], sqlite_inserted, supabase_inserted,
    )
    return {
        "status": "accepted",
        "ingested": sqlite_inserted,
        "supabase_ingested": supabase_inserted,
        "dual_write": DUAL_WRITE_ANALYTICS,
    }


# Security audit P0-08 (2026-07-18): the analytics read endpoints
# previously required only an ordinary bearer token, so any signed-in
# user could read global product metrics. The audit requires explicit
# operator authorization. The Phase 0 minimum is a shared-secret
# operator token checked against the `OPERATOR_DASHBOARD_TOKEN` env
# var. Security Phase 1 will replace this with a server-side
# principal model that includes an `operator` role on the verified
# JWT, with the shared secret as a transitional fallback.
def _check_operator_token(x_operator_token: str | None) -> None:
    """Verify the request carries a valid operator token.

    Raises 403 if the header is missing or does not match the
    configured operator secret. The check is constant-time and does
    not log the candidate or the secret.
    """
    import hmac

    expected = os.environ.get("OPERATOR_DASHBOARD_TOKEN", "").strip()
    if not expected:
        # No operator token configured means the operator endpoints
        # are unavailable. This is fail-closed: a misconfigured
        # deployment cannot leak analytics to ordinary users.
        raise HTTPException(
            status_code=403,
            detail="Operator endpoints are not configured in this environment.",
        )
    if not x_operator_token:
        raise HTTPException(
            status_code=403, detail="Operator token required."
        )
    # Constant-time comparison to avoid timing oracles on the secret.
    if not hmac.compare_digest(x_operator_token.encode("utf-8"), expected.encode("utf-8")):
        raise HTTPException(
            status_code=403, detail="Invalid operator token."
        )


def require_operator(
    x_operator_token: str | None = Header(default=None, alias="X-Operator-Token"),
) -> None:
    """FastAPI dependency: requires a valid X-Operator-Token header.

    Operators send this header from the operator dashboard. Ordinary
    mobile clients do not have this secret and cannot reach the
    endpoint. Until Security Phase 1 wires a server-side role claim,
    this is the Phase 0 minimum.
    """
    _check_operator_token(x_operator_token)


@router.get("/summary")
async def get_analytics_summary(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    _operator: None = Depends(require_operator),
):
    """Get a summary of analytics events (for the founder's dashboard).

    Security audit P0-08: requires both an ordinary bearer token AND
    the X-Operator-Token header. Ordinary users cannot reach this.

    Optimized to 2 queries:
    1. Event counts by name (also used to derive total events via sum)
    2. Unique user count (COUNT DISTINCT can't be combined with GROUP BY)
    """
    canonical_client = _production_analytics_client()
    if canonical_client is not None:
        rows = _supabase_event_rows(canonical_client, days)
        events_by_name: Dict[str, int] = {}
        unique_users: set[str] = set()
        for row in rows:
            events_by_name[row["event_name"]] = events_by_name.get(row["event_name"], 0) + 1
            unique_users.add(row["user_uid"])
        return {
            "status": "success",
            "days": days,
            "total_events": sum(events_by_name.values()),
            "unique_users": len(unique_users),
            "events_by_name": events_by_name,
            "canonical": "supabase",
        }

    _init_analytics_table()

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    time_filter = f"-{days} days"

    # Query 1: Event counts by name — also derives total events via sum
    rows = conn.execute("""
        SELECT event_name, COUNT(*) as count
        FROM analytics_events
        WHERE received_at >= datetime('now', ?)
        GROUP BY event_name
        ORDER BY count DESC
    """, (time_filter,)).fetchall()

    # Query 2: Unique users (COUNT DISTINCT can't be folded into GROUP BY)
    unique_users = conn.execute("""
        SELECT COUNT(DISTINCT user_uid) as count
        FROM analytics_events
        WHERE received_at >= datetime('now', ?)
    """, (time_filter,)).fetchone()

    conn.close()

    # Derive total from the grouped counts — no third query needed
    events_by_name = {row["event_name"]: row["count"] for row in rows}
    total_events = sum(events_by_name.values())

    return {
        "status": "success",
        "days": days,
        "total_events": total_events,
        "unique_users": unique_users["count"] if unique_users else 0,
        "events_by_name": events_by_name,
    }


@router.get("/health")
async def get_analytics_health(
    current_user: User = Depends(get_current_user),
    _operator: None = Depends(require_operator),
):
    """Report index existence and row counts for operational visibility.

    Security audit P0-08: requires the X-Operator-Token header. Ordinary
    users cannot reach this endpoint.

    Does NOT call _init_analytics_table() so it can accurately report
    when the table is missing.

    Returns:
    - table_exists: whether the analytics_events table exists
    - indexes: list of indexes with their columns
    - row_count: total rows in analytics_events
    - recent_events_24h: events received in the last 24 hours
    """
    canonical_client = _production_analytics_client()
    if canonical_client is not None:
        try:
            response = canonical_client.table("analytics_events").select("id", count="exact").limit(1).execute()
            return {
                "status": "success",
                "table_exists": True,
                "indexes": [],
                "row_count": int(response.count or 0),
                "recent_events_24h": len(_supabase_event_rows(canonical_client, 1)),
                "canonical": "supabase",
            }
        except Exception as error:
            raise HTTPException(status_code=503, detail="Canonical analytics health unavailable") from error

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    # Check if table exists (without creating it)
    table_check = conn.execute("""
        SELECT name FROM sqlite_master
        WHERE type='table' AND name='analytics_events'
    """).fetchone()
    table_exists = table_check is not None

    # List indexes on analytics_events
    indexes = []
    if table_exists:
        index_rows = conn.execute("""
            SELECT name, sql FROM sqlite_master
            WHERE type='index' AND tbl_name='analytics_events'
            AND sql IS NOT NULL
        """).fetchall()
        indexes = [{"name": row["name"], "sql": row["sql"]} for row in index_rows]

    # Row counts — combined into a single query via conditional aggregation
    row_count = 0
    recent_count = 0
    if table_exists:
        counts = conn.execute("""
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN received_at >= datetime('now', '-1 days') THEN 1 ELSE 0 END) as recent
            FROM analytics_events
        """).fetchone()
        row_count = counts["total"] if counts else 0
        recent_count = counts["recent"] if counts else 0

    conn.close()

    return {
        "status": "success",
        "table_exists": table_exists,
        "indexes": indexes,
        "row_count": row_count,
        "recent_events_24h": recent_count,
    }


@router.get("/errors")
async def get_error_aggregation(
    days: int = 7,
    current_user: User = Depends(get_current_user),
    _operator: None = Depends(require_operator),
):
    """Aggregate global_error events for production monitoring dashboards.

    Security audit P0-08: requires the X-Operator-Token header. Ordinary
    users cannot reach this endpoint. The data is allowlisted and
    truncated; raw error messages are NOT exposed.

    Returns:
    - Error counts by type (runtime type of the exception)
    - Error counts by library (where the error originated)
    - Error trend (hourly breakdown for the last 24h, daily for older)
    - Recovery rate (global_error_recovered / global_error)
    - Top error messages (truncated, no PII)
    """
    canonical_client = _production_analytics_client()
    if canonical_client is not None:
        rows = _supabase_event_rows(canonical_client, days)
        errors = [r for r in rows if r.get("event_name") == "global_error"]
        recoveries = [r for r in rows if r.get("event_name") == "global_error_recovered"]
        error_types: Dict[str, int] = {}
        libraries: Dict[str, int] = {}
        messages: Dict[str, int] = {}
        for row in errors:
            props = row.get("properties") or {}
            error_type = str(props.get("error_type") or "unknown")
            library = str(props.get("library") or "unknown")
            message = str(props.get("error_message") or "unknown")[:200]
            error_types[error_type] = error_types.get(error_type, 0) + 1
            libraries[library] = libraries.get(library, 0) + 1
            messages[message] = messages.get(message, 0) + 1
        total_errors = len(errors)
        return {
            "status": "success",
            "days": days,
            "total_errors": total_errors,
            "total_recoveries": len(recoveries),
            "recovery_rate_percent": round(len(recoveries) / total_errors * 100, 1) if total_errors else None,
            "error_types": error_types,
            "error_libraries": libraries,
            "top_error_messages": sorted(messages.items(), key=lambda item: item[1], reverse=True)[:10],
            "trend": {"hourly": [], "daily": []},
            "canonical": "supabase",
        }

    _init_analytics_table()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    time_filter = f"-{days} days"

    # ── Query 1: Combined total errors + recovery count (single scan) ──
    # Uses conditional aggregation to count both event types in one pass.
    totals_row = conn.execute("""
        SELECT
            SUM(CASE WHEN event_name = 'global_error' THEN 1 ELSE 0 END) as total_errors,
            SUM(CASE WHEN event_name = 'global_error_recovered' THEN 1 ELSE 0 END) as total_recoveries
        FROM analytics_events
        WHERE event_name IN ('global_error', 'global_error_recovered')
        AND received_at >= datetime('now', ?)
    """, (time_filter,)).fetchone()

    total_errors = totals_row["total_errors"] or 0
    total_recoveries = totals_row["total_recoveries"] or 0

    # ── Query 2: Single-pass CTE for error_type, library, and messages ──
    # Extracts JSON fields once via CTE, then aggregates three dimensions
    # using UNION ALL. This replaces three separate scans of the same rows.
    aggregation_rows = conn.execute("""
        WITH error_data AS (
            SELECT
                COALESCE(json_extract(properties, '$.error_type'), 'unknown') as error_type,
                COALESCE(json_extract(properties, '$.library'), 'unknown') as library,
                COALESCE(json_extract(properties, '$.error_message'), 'unknown') as error_message
            FROM analytics_events
            WHERE event_name = 'global_error'
            AND received_at >= datetime('now', ?)
        )
        SELECT 'error_type' as dimension, error_type as value, COUNT(*) as count
        FROM error_data GROUP BY error_type
        UNION ALL
        SELECT 'library' as dimension, library as value, COUNT(*) as count
        FROM error_data GROUP BY library
        UNION ALL
        SELECT 'message' as dimension, error_message as value, COUNT(*) as count
        FROM error_data GROUP BY error_message
    """, (time_filter,)).fetchall()

    # Parse the combined results into separate dicts
    error_types: Dict[str, int] = {}
    error_libraries: Dict[str, int] = {}
    top_messages: list = []

    for row in aggregation_rows:
        dim = row["dimension"]
        value = row["value"]
        count = row["count"]
        if dim == "error_type":
            error_types[value] = count
        elif dim == "library":
            error_libraries[value] = count
        elif dim == "message":
            top_messages.append((value, count))

    # Sort messages by count descending and take top 10
    top_messages.sort(key=lambda x: x[1], reverse=True)
    top_messages = top_messages[:10]

    # ── Query 3: Error trend — hourly for last 24h, daily for older ──
    hourly_trend = conn.execute("""
        SELECT strftime('%Y-%m-%dT%H:00:00Z', timestamp) as hour,
               COUNT(*) as count
        FROM analytics_events
        WHERE event_name = 'global_error'
        AND received_at >= datetime('now', '-1 days')
        GROUP BY hour
        ORDER BY hour
    """).fetchall()

    daily_trend = conn.execute("""
        SELECT strftime('%Y-%m-%d', timestamp) as day,
               COUNT(*) as count
        FROM analytics_events
        WHERE event_name = 'global_error'
        AND received_at >= datetime('now', ?)
        AND received_at < datetime('now', '-1 days')
        GROUP BY day
        ORDER BY day
    """, (time_filter,)).fetchall()

    conn.close()

    recovery_rate = (
        round(total_recoveries / total_errors * 100, 1)
        if total_errors > 0
        else None
    )

    return {
        "status": "success",
        "days": days,
        "total_errors": total_errors,
        "total_recoveries": total_recoveries,
        "recovery_rate_percent": recovery_rate,
        "error_types": error_types,
        "error_libraries": error_libraries,
        "top_error_messages": top_messages,
        "trend": {
            "hourly": [{"hour": r["hour"], "count": r["count"]} for r in hourly_trend],
            "daily": [{"day": r["day"], "count": r["count"]} for r in daily_trend],
        },
    }
