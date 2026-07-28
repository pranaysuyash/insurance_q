"""Tests for the shared structured logging configuration (src/utils/log_config.py).

Verifies:
  - ``configure_structlog()`` produces valid JSON output
  - The ``service`` field is bound to every log entry
  - Event, level, and timestamp fields are present
  - Subsequent log calls also carry the ``service`` field
"""

import io
import json
from collections.abc import Callable

import pytest


def _capture_after_setup(
    service_name: str = "api",
    environment: str = "development",
) -> tuple[io.StringIO, Callable[[], None]]:
    """Run configure_structlog, then redirect the root handler to a StringIO.

    Returns ``(captured, cleanup)`` where ``captured`` is the StringIO that
    will receive future log output, and ``cleanup()`` restores the original
    handler stream.

    The startup log line emitted by ``configure_structlog()`` itself goes to
    the **original** stream (not the StringIO), because the swap happens
    after the routine has finished.  Tests that need the startup line should
    call ``configure_structlog()`` directly and inject the StringIO
    beforehand.
    """
    from src.utils.log_config import configure_structlog

    configure_structlog(service_name=service_name, environment=environment)

    import logging

    root = logging.getLogger()
    assert len(root.handlers) == 1
    handler = root.handlers[0]
    assert isinstance(handler, logging.StreamHandler)

    captured = io.StringIO()
    old_stream = handler.stream
    handler.stream = captured

    def cleanup() -> None:
        handler.stream = old_stream

    return captured, cleanup


@pytest.fixture
def captured_logs():
    """Set up structlog and return a ``(StringIO, cleanup)`` pair."""
    captured, cleanup = _capture_after_setup(
        service_name="test-svc", environment="test"
    )
    yield captured
    cleanup()


# ------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------


def test_configure_structlog_produces_json(captured_logs):
    """After configure_structlog, a log.info call emits valid JSON."""
    import logging

    log = logging.getLogger(__name__)
    log.info("test_event")

    output = captured_logs.getvalue()
    lines = [line for line in output.split("\n") if line.strip()]
    assert lines, f"No log output captured. Got: {output[:200]!r}"
    parsed = json.loads(lines[-1])

    assert parsed["event"] == "test_event"
    assert parsed["level"] == "info"
    assert parsed["service"] == "test-svc"
    assert "timestamp" in parsed
    assert "logger" in parsed


def test_service_field_on_every_log_line(captured_logs):
    """Every log line should carry the configured service name.

    Note: the startup line from ``configure_structlog()`` is written to the
    original handler stream, so only the test-event lines appear in the
    captured StringIO.
    """
    import logging

    log = logging.getLogger(__name__)
    log.info("second_event")
    log.warning("third_event")

    output = captured_logs.getvalue()
    lines = [line for line in output.split("\n") if line.strip()]

    # 2 lines from the test (startup line went to the original stream)
    assert len(lines) >= 2, (
        f"Expected at least 2 log lines (2 test events), got {len(lines)}"
    )
    for line in lines:
        parsed = json.loads(line)
        assert parsed.get("service") == "test-svc", (
            f"Missing or wrong service in: {line[:120]}"
        )


def test_event_level_fields_present(captured_logs):
    """Every log line must have event, level, and timestamp fields."""
    import logging

    log = logging.getLogger(__name__)
    log.info("check_fields")

    output = captured_logs.getvalue()
    lines = [line for line in output.split("\n") if line.strip()]
    assert lines, f"No log output captured. Got: {output[:200]!r}"
    parsed = json.loads(lines[-1])

    assert parsed["event"] == "check_fields"
    assert parsed["level"] == "info"
    assert "timestamp" in parsed
    assert "logger" in parsed
    assert parsed["service"] == "test-svc"


def test_configure_structlog_accepts_environment_override(capsys):
    """The environment parameter should override ENVIRONMENT env var.

    Uses pytest's ``capsys`` fixture to read the startup log line that
    ``configure_structlog()`` writes as part of its initialization.  This
    line contains the ``environment`` and ``service`` fields.
    """
    from src.utils.log_config import configure_structlog

    configure_structlog(service_name="test", environment="staging")

    captured = capsys.readouterr()
    lines = [l for l in captured.out.split("\n") if l.strip()]
    assert lines, f"No log output captured. Got: {captured.out[:200]!r}"

    # First line is the startup log with environment + service
    parsed = json.loads(lines[0])
    assert parsed["environment"] == "staging"
    assert parsed["service"] == "test"
