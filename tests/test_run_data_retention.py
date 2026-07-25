from datetime import datetime, timezone
from unittest.mock import MagicMock

import pytest

from tools import run_data_retention


def test_default_retention_matches_published_analytics_period():
    """The deployment fallback must not retain analytics longer than the
    30-day period stated in the in-app privacy policy."""
    assert run_data_retention.DEFAULT_ANALYTICS_RETENTION_DAYS == 30


def test_retention_pass_reports_analytics_fence_and_object_cleanup(monkeypatch):
    analytics = MagicMock()
    analytics.purge_before.return_value = 7
    monkeypatch.setattr(
        run_data_retention.AnalyticsRetentionService,
        "from_env",
        classmethod(lambda cls: analytics),
    )
    monkeypatch.setattr(run_data_retention, "mark_expired", lambda **_: 3)
    monkeypatch.setattr(
        run_data_retention,
        "delete_pending",
        lambda **_: {"attempted": 4, "deleted": 4, "failed": 0},
    )
    now = datetime(2026, 7, 21, 12, tzinfo=timezone.utc)

    result = run_data_retention.run_retention_pass(
        analytics_retention_days=365,
        artifact_limit=25,
        now=now,
    )

    assert result == {
        "ran_at": "2026-07-21T12:00:00+00:00",
        "analytics_deleted": 7,
        "artifacts_marked_deleting": 3,
        "artifact_cleanup": {"attempted": 4, "deleted": 4, "failed": 0},
    }
    analytics.purge_before.assert_called_once()


@pytest.mark.parametrize(
    ("analytics_retention_days", "artifact_limit"),
    [(0, 100), (365, 0), (365, 1001)],
)
def test_retention_pass_rejects_invalid_bounds(analytics_retention_days, artifact_limit):
    with pytest.raises(ValueError):
        run_data_retention.run_retention_pass(
            analytics_retention_days=analytics_retention_days,
            artifact_limit=artifact_limit,
        )
