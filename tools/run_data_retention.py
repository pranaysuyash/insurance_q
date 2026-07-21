"""Run the scheduled Supabase retention and artifact cleanup pass.

This is intentionally a small operator entry point so deployment can invoke it
from Cloud Scheduler, a cron job, or a one-shot maintenance task without
creating a second retention implementation.
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timedelta, timezone

from src.services.analytics_retention_service import AnalyticsRetentionService
from src.services.artifact_lifecycle_service import delete_pending, mark_expired
from src.utils.runtime_config import normalize_supabase_environment


def main() -> None:
    normalize_supabase_environment()
    parser = argparse.ArgumentParser()
    parser.add_argument("--analytics-retention-days", type=int, default=int(os.getenv("ANALYTICS_RETENTION_DAYS", "365")))
    parser.add_argument("--artifact-limit", type=int, default=100)
    args = parser.parse_args()
    if args.analytics_retention_days < 1:
        raise SystemExit("--analytics-retention-days must be positive")
    now = datetime.now(timezone.utc)
    analytics_deleted = AnalyticsRetentionService.from_env().purge_before(
        now - timedelta(days=args.analytics_retention_days)
    )
    result = {
        "ran_at": now.isoformat(),
        "analytics_deleted": analytics_deleted,
        "artifacts_marked_deleting": mark_expired(now=now),
        "artifact_cleanup": delete_pending(limit=args.artifact_limit),
    }
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
