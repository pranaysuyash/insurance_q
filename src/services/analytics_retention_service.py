"""Service-role boundary for canonical analytics retention.

Provides both the legacy Supabase RPC path and a dual-background
auto-cleanup that works with SQLite (dev) and direct Supabase table
deletion (prod).
"""

from __future__ import annotations

import sqlite3
import logging
from datetime import datetime, timezone, timedelta
from typing import Any, Optional

from src.utils.runtime_config import supabase_server_key

logger = logging.getLogger(__name__)


class AnalyticsRetentionError(RuntimeError):
    pass


class AnalyticsRetentionService:
    def __init__(self, client: Any):
        self._client = client

    @classmethod
    def from_env(cls) -> "AnalyticsRetentionService":
        import os
        url = os.getenv("SUPABASE_URL", "").strip()
        key = supabase_server_key()
        if not url or not key:
            raise AnalyticsRetentionError("Supabase analytics retention requires server credentials")
        from src.utils.supabase_client import create_client
        return cls(create_client(url, key))

    def purge_before(self, cutoff: datetime) -> int:
        if cutoff.tzinfo is None:
            raise AnalyticsRetentionError("retention cutoff must be timezone-aware")
        if cutoff >= datetime.now(timezone.utc):
            raise AnalyticsRetentionError("retention cutoff must be in the past")
        response = self._client.rpc(
            "purge_analytics_events", {"p_cutoff": cutoff.astimezone(timezone.utc).isoformat()}
        ).execute()
        try:
            return int(response.data or 0)
        except (TypeError, ValueError) as error:
            raise AnalyticsRetentionError("analytics retention RPC returned invalid count") from error


# ── Direct-deletion auto-cleanup (works with both SQLite and Supabase) ──

def _default_retention_days() -> int:
    """Return the configured retention period, defaulting to 90 days."""
    import os
    try:
        return max(1, int(os.environ.get("ANALYTICS_RETENTION_DAYS", "90")))
    except (ValueError, TypeError):
        return 90


def default_cleanup_interval_seconds() -> int:
    """Return the configured cleanup interval, defaulting to 6 hours."""
    import os
    try:
        return int(os.environ.get("ANALYTICS_CLEANUP_INTERVAL_SECONDS", str(6 * 3600)))
    except (ValueError, TypeError):
        return 6 * 3600


def purge_old_analytics_events(older_than_days: Optional[int] = None) -> int:
    """Delete analytics events older than the retention period.

    Works for both SQLite (development) and Supabase (production) backends
    by detecting the canonical backend from the environment.

    Returns the number of deleted rows.

    Safe to call unconditionally — silently no-ops when neither backend
    is available (e.g. during early startup before Supabase is initialized).
    """
    days = older_than_days or _default_retention_days()

    # ── Supabase path ──
    import os
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if url and key:
        try:
            cutoff = datetime.now(timezone.utc) - timedelta(days=days)
            from src.utils.supabase_client import create_client
            client = create_client(url, key)
            result = (
                client.table("analytics_events")
                .delete()
                .lt("received_at", cutoff.isoformat())
                .execute()
            )
            deleted = len(result.data or [])
            logger.info("analytics_retention_purge_supabase deleted=%d cutoff=%s", deleted, cutoff.isoformat())
            return deleted
        except Exception as error:
            # Supabase may not be fully initialized yet; log and return 0
            # rather than failing the cleanup loop entirely.
            logger.warning("analytics_retention_purge_supabase_failed error_type=%s", type(error).__name__)
            return 0

    # ── SQLite path (development) ──
    # Use the same DB_PATH convention as src.api.analytics.
    db_path = os.environ.get("ANALYTICS_DB_PATH", "insurance_app.db")
    try:
        conn = sqlite3.connect(db_path)
        cutoff_param = f"-{days} days"
        count_row = conn.execute(
            "SELECT COUNT(*) FROM analytics_events WHERE received_at < datetime('now', ?)",
            (cutoff_param,),
        ).fetchone()
        deleted = count_row[0] if count_row else 0
        if deleted > 0:
            conn.execute(
                "DELETE FROM analytics_events WHERE received_at < datetime('now', ?)",
                (cutoff_param,),
            )
            conn.commit()
            conn.execute("VACUUM")
        conn.close()
        logger.info("analytics_retention_purge_sqlite deleted=%d cutoff=%s", deleted, cutoff.isoformat())
        return deleted
    except Exception as error:
        # SQLite file may not exist yet (first startup before any events)
        logger.warning("analytics_retention_purge_sqlite_failed error_type=%s", type(error).__name__)
        return 0
