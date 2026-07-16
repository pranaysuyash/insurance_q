"""
Analytics ingestion endpoint for CoverWise.

Accepts batches of events from the mobile app. Events are stored in SQLite
(insurance_app.db) for solo-launch simplicity. No PII is stored — only event
name, timestamp, anonymous UID, and safe properties per the analytics spec
(docs/review/coverwise_analytics_event_spec.md).
"""
import json
import sqlite3
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from src.api.user import get_current_user
from src.models.user import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/analytics", tags=["analytics"])

DB_PATH = "insurance_app.db"


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
            received_at TEXT NOT NULL
        )
    """);
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
    conn.commit()
    conn.close()


class AnalyticsEvent(BaseModel):
    event: str = Field(..., description="Snake-case event name from the spec")
    ts: str = Field(..., description="ISO 8601 UTC timestamp from the client")
    uid: str = Field(..., description="Anonymous user/session ID")
    props: Dict[str, Any] = Field(default_factory=dict, description="Safe, non-PII properties")


class AnalyticsBatch(BaseModel):
    events: List[AnalyticsEvent]


@router.post("/events")
async def ingest_events(
    batch: AnalyticsBatch,
    current_user: User = Depends(get_current_user),
):
    """Accept a batch of analytics events from the mobile app."""
    _init_analytics_table()

    conn = sqlite3.connect(DB_PATH)
    now = datetime.now(timezone.utc).isoformat()
    inserted = 0

    for event in batch.events:
        # Enforce the UID from the auth token, not the client claim
        try:
            conn.execute(
                "INSERT INTO analytics_events (event_name, timestamp, user_uid, properties, received_at) VALUES (?, ?, ?, ?, ?)",
                (
                    event.event,
                    event.ts,
                    current_user.uid,
                    json.dumps(event.props) if event.props else None,
                    now,
                ),
            )
            inserted += 1
        except Exception as e:
            logger.warning("Failed to insert analytics event %s: %s", event.event, e)

    conn.commit()
    conn.close()

    logger.info("Analytics: ingested %d/%d events for user %s", inserted, len(batch.events), current_user.uid[:8])
    return {"status": "accepted", "ingested": inserted}


@router.get("/summary")
async def get_analytics_summary(
    days: int = 7,
    current_user: User = Depends(get_current_user),
):
    """Get a summary of analytics events (for the founder's dashboard).

    Optimized to 2 queries:
    1. Event counts by name (also used to derive total events via sum)
    2. Unique user count (COUNT DISTINCT can't be combined with GROUP BY)
    """
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
):
    """Report index existence and row counts for operational visibility.

    Does NOT call _init_analytics_table() so it can accurately report
    when the table is missing.

    Returns:
    - table_exists: whether the analytics_events table exists
    - indexes: list of indexes with their columns
    - row_count: total rows in analytics_events
    - recent_events_24h: events received in the last 24 hours
    """
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
):
    """Aggregate global_error events for production monitoring dashboards.

    Returns:
    - Error counts by type (runtime type of the exception)
    - Error counts by library (where the error originated)
    - Error trend (hourly breakdown for the last 24h, daily for older)
    - Recovery rate (global_error_recovered / global_error)
    - Top error messages (truncated, no PII)
    """
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
