from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import pytest

from src.services.analytics_retention_service import AnalyticsRetentionError, AnalyticsRetentionService


def test_purge_before_calls_canonical_rpc():
    client = MagicMock()
    client.rpc.return_value.execute.return_value.data = 4
    service = AnalyticsRetentionService(client)
    assert service.purge_before(datetime.now(timezone.utc) - timedelta(days=30)) == 4
    assert client.rpc.call_args.args[0] == "purge_analytics_events"


def test_retention_rejects_naive_or_future_cutoff():
    service = AnalyticsRetentionService(MagicMock())
    with pytest.raises(AnalyticsRetentionError, match="timezone-aware"):
        service.purge_before(datetime(2026, 1, 1))
    with pytest.raises(AnalyticsRetentionError, match="past"):
        service.purge_before(datetime.now(timezone.utc) + timedelta(minutes=1))
