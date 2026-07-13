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
    """Create the analytics_events table if it doesn't exist."""
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
    """Get a summary of analytics events (for the founder's dashboard)."""
    _init_analytics_table()

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    # Event counts by name
    rows = conn.execute("""
        SELECT event_name, COUNT(*) as count
        FROM analytics_events
        WHERE received_at >= datetime('now', ?)
        GROUP BY event_name
        ORDER BY count DESC
    """, (f"-{days} days",)).fetchall()

    # Unique users
    unique_users = conn.execute("""
        SELECT COUNT(DISTINCT user_uid) as count
        FROM analytics_events
        WHERE received_at >= datetime('now', ?)
    """, (f"-{days} days",)).fetchone()

    # Total events
    total = conn.execute("""
        SELECT COUNT(*) as count
        FROM analytics_events
        WHERE received_at >= datetime('now', ?)
    """, (f"-{days} days",)).fetchone()

    conn.close()

    return {
        "status": "success",
        "days": days,
        "total_events": total["count"] if total else 0,
        "unique_users": unique_users["count"] if unique_users else 0,
        "events_by_name": {row["event_name"]: row["count"] for row in rows},
    }
