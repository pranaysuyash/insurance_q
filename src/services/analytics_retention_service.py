"""Service-role boundary for canonical analytics retention."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any


class AnalyticsRetentionError(RuntimeError):
    pass


class AnalyticsRetentionService:
    def __init__(self, client: Any):
        self._client = client

    @classmethod
    def from_env(cls) -> "AnalyticsRetentionService":
        import os
        url = os.getenv("SUPABASE_URL", "").strip()
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not url or not key:
            raise AnalyticsRetentionError("Supabase analytics retention requires server credentials")
        from supabase import create_client
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
