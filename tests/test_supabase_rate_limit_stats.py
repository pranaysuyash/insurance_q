from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

from src.utils.anti_abuse import get_supabase_rate_limit_stats


def test_expired_windows_are_reported_as_zero_usage(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")
    client = MagicMock()
    expired = (datetime.now(timezone.utc) - timedelta(days=1, seconds=1)).isoformat()
    client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"request_count": 9, "window_started_at": expired}
    ]

    with patch("supabase.create_client", return_value=client):
        stats = get_supabase_rate_limit_stats("203.0.113.10", "session-1")

    assert stats["ip_usage"] == 0
    assert stats["session_usage"] == 0


def test_current_windows_preserve_usage_count(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")
    client = MagicMock()
    current = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    client.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"request_count": 3, "window_started_at": current}
    ]

    with patch("supabase.create_client", return_value=client):
        stats = get_supabase_rate_limit_stats("203.0.113.10", "session-1")

    assert stats["ip_usage"] == 3
    assert stats["session_usage"] == 3
