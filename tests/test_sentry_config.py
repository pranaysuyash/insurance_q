"""Tests for Sentry configuration (src/utils/sentry_config.py).

Verifies:
  - has_sentry_config() parsing for valid/missing/malformed DSNs
  - init_sentry() skips when DSN is empty (safe for dev)
  - shutdown_sentry() is safe when not active
  - structlog JSON output in production mode produces valid JSON with
    expected keys (event, level, timestamp, logger, service)
"""

import json
import os
import io
import logging

import pytest


# ── has_sentry_config ─────────────────────────────────────────────


def test_has_sentry_config_empty_dsn(monkeypatch):
    from src.utils.sentry_config import has_sentry_config

    monkeypatch.delenv("SENTRY_DSN", raising=False)
    assert has_sentry_config() is False


def test_has_sentry_config_empty_after_unset(monkeypatch):
    from src.utils.sentry_config import has_sentry_config

    monkeypatch.setenv("SENTRY_DSN", "https://key@o123.ingest.us.sentry.io/1234567")
    assert has_sentry_config() is True
    monkeypatch.delenv("SENTRY_DSN")
    assert has_sentry_config() is False


def test_has_sentry_config_valid_dsn(monkeypatch):
    from src.utils.sentry_config import has_sentry_config

    monkeypatch.setenv(
        "SENTRY_DSN",
        "https://key@o123456.ingest.us.sentry.io/1234567",
    )
    assert has_sentry_config() is True


def test_has_sentry_config_missing_domain(monkeypatch):
    from src.utils.sentry_config import has_sentry_config

    monkeypatch.setenv("SENTRY_DSN", "not-a-dsn")
    assert has_sentry_config() is False


def test_has_sentry_config_whitespace_only(monkeypatch):
    from src.utils.sentry_config import has_sentry_config

    monkeypatch.setenv("SENTRY_DSN", "   ")
    assert has_sentry_config() is False


# ── init_sentry (skips when DSN empty) ────────────────────────────


@pytest.mark.parametrize(
    "env_dsn,expected_calls",
    [
        ("", 0),
        ("   ", 0),
        ("https://key@o123.ingest.us.sentry.io/1234567", 1),
    ],
)
def test_init_sentry_skips_when_dsn_empty(
    monkeypatch, env_dsn, expected_calls
):
    from src.utils.sentry_config import init_sentry

    calls: list[str] = []

    def fake_init(**kwargs):
        calls.append("init")
        # Return a minimal mock client
        import sentry_sdk
        class MockClient:
            def is_active(self): return False
        sentry_sdk.get_client = lambda: MockClient()

    monkeypatch.setenv("SENTRY_DSN", env_dsn)
    monkeypatch.setattr("sentry_sdk.init", fake_init)

    init_sentry(service_name="test", app_version="0.0.0")

    assert len(calls) == expected_calls


# ── shutdown_sentry ───────────────────────────────────────────────


def test_shutdown_sentry_safe_when_not_active():
    """shutdown_sentry must not throw when Sentry was never initialized."""
    from src.utils.sentry_config import shutdown_sentry

    # No crash, no exception
    shutdown_sentry()


# ── Structlog JSON output ─────────────────────────────────────────


@pytest.fixture(autouse=True)
def _reset_structlog(request):
    """Reset structlog configuration after each test that configures it."""
    def reset():
        import structlog
        structlog.configure(
            processors=[structlog.stdlib.ProcessorFormatter.wrap_for_formatter],
        )
    request.addfinalizer(reset)


def test_structlog_produces_valid_json():
    """Structlog in production mode emits valid JSON with required keys."""
    import structlog

    captured = io.StringIO()
    handler = logging.StreamHandler(captured)
    handler.setFormatter(logging.Formatter("%(message)s"))
    root = logging.getLogger()
    root.addHandler(handler)
    root.setLevel(logging.INFO)

    try:
        structlog.configure(
            processors=[
                structlog.stdlib.filter_by_level,
                structlog.stdlib.add_logger_name,
                structlog.stdlib.add_log_level,
                structlog.stdlib.PositionalArgumentsFormatter(),
                structlog.processors.TimeStamper(fmt="iso"),
                structlog.processors.StackInfoRenderer(),
                structlog.processors.format_exc_info,
                structlog.processors.UnicodeDecoder(),
                structlog.processors.JSONRenderer(),
            ],
            wrapper_class=structlog.stdlib.BoundLogger,
            context_class=dict,
            logger_factory=structlog.stdlib.LoggerFactory(),
            cache_logger_on_first_use=True,
        )

        log = structlog.get_logger()
        log.info("test_event", service="api", status="ok")

        output = captured.getvalue()
        line = output.strip().split("\n")[0]
        parsed = json.loads(line)

        assert parsed["event"] == "test_event"
        assert parsed["level"] == "info"
        assert parsed["service"] == "api"
        assert parsed["status"] == "ok"
        assert "timestamp" in parsed
        assert parsed["timestamp"].endswith("Z") or "+" in parsed["timestamp"]
        assert "logger" in parsed
    finally:
        root.removeHandler(handler)
