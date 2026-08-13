"""Regression tests for anti-abuse rate limiting (H-06).

Guards two findings:
- RATE LIMIT MUST FAIL CLOSED: a Redis error must deny the request, not silently
  allow unlimited traffic (previously returned ``True`` -> abuse protection off).
- ``rate_limiter_backend()`` must report the active backend for health checks.
"""
from unittest.mock import MagicMock

from src.utils import anti_abuse as ab


def test_redis_error_fails_closed(monkeypatch):
    """When Redis errors mid-request, rate limiting must DENY, not allow."""
    failing = MagicMock()
    failing.zcard.side_effect = RuntimeError("redis down")
    failing.zadd.side_effect = RuntimeError("redis down")
    monkeypatch.setattr(ab, "redis_client", failing)

    allowed, reason = ab._check_redis_rate_limit("ip", "1.2.3.4", 10, 24)
    assert allowed is False
    assert "unavailable" in reason.lower()


def test_rate_limiter_backend_redis_when_configured(monkeypatch):
    monkeypatch.setattr(ab, "redis_client", MagicMock())
    assert ab.rate_limiter_backend() == "redis"


def test_rate_limiter_backend_memory_when_absent(monkeypatch):
    monkeypatch.setattr(ab, "redis_client", None)
    assert ab.rate_limiter_backend() == "memory"
