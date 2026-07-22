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


def run_retention_pass(
    *,
    analytics_retention_days: int,
    artifact_limit: int = 100,
    now: datetime | None = None,
) -> dict[str, object]:
    """Run one bounded retention pass and return its operator report."""
    if analytics_retention_days < 1:
        raise ValueError("analytics_retention_days must be positive")
    if artifact_limit < 1 or artifact_limit > 1000:
        raise ValueError("artifact_limit must be between 1 and 1000")
    moment = now or datetime.now(timezone.utc)
    if moment.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    analytics_deleted = AnalyticsRetentionService.from_env().purge_before(
        moment - timedelta(days=analytics_retention_days)
    )
    return {
        "ran_at": moment.isoformat(),
        "analytics_deleted": analytics_deleted,
        "artifacts_marked_deleting": mark_expired(now=moment),
        "artifact_cleanup": delete_pending(limit=artifact_limit),
    }


def main() -> None:
    normalize_supabase_environment()
    parser = argparse.ArgumentParser()
    parser.add_argument("--analytics-retention-days", type=int, default=int(os.getenv("ANALYTICS_RETENTION_DAYS", "365")))
    parser.add_argument("--artifact-limit", type=int, default=100)
    args = parser.parse_args()
    try:
        result = run_retention_pass(
            analytics_retention_days=args.analytics_retention_days,
            artifact_limit=args.artifact_limit,
        )
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
