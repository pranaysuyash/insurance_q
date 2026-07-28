"""Shared structured logging configuration for all backend services.

Provides a single ``configure_structlog()`` call that sets up structlog with
JSON output across all environments (not just production). This ensures Cloud
Run can parse and index all log output automatically.

Call this once at process startup (typically in the module-level setup of
main.py or each service entry point). After calling it, every
``logging.getLogger(__name__).info(...)`` call in the codebase produces
structured JSON output.

Usage::

    # At the top of your service entry point:
    from src.utils.log_config import configure_structlog
    configure_structlog(service_name="api", environment="production")

    # Then use standard Python logging as usual:
    import logging
    logger = logging.getLogger(__name__)
    logger.info("event_name", extra={"key": "value"})
"""

from __future__ import annotations

import logging
import os
import sys
from typing import Optional


def configure_structlog(
    *,
    service_name: str = "api",
    environment: Optional[str] = None,
    log_level: Optional[str] = None,
) -> None:
    """Configure structlog for JSON-structured logging.

    Sets up:
      - JSON rendering via ``structlog.processors.JSONRenderer``
      - ISO-8601 timestamps
      - Logger name and level
      - Exception info (formatted, not raw)
      - ``service`` field added to every log entry

    After calling this, all ``logging.getLogger(...)`` calls in the process
    produce structured JSON output that Cloud Run / Google Cloud Logging can
    parse automatically.

    Uses ``structlog.stdlib.ProcessorFormatter`` with
    ``wrap_for_formatter`` so that both structlog-native loggers
    (``structlog.get_logger()``) and plain stdlib loggers produce
    identical JSON output without double-wrapping.

    Parameters
    ----------
    service_name:
        Logical service name (e.g. ``api``, ``frontend``, ``worker``).
        Added as a ``service`` field to every log entry.
    environment:
        Deployment environment. Defaults to ``ENVIRONMENT`` env var or
        ``"development"``.
    log_level:
        Minimum log level. Defaults to ``LOG_LEVEL`` env var or ``"INFO"``.
    """
    import structlog
    from structlog.stdlib import ProcessorFormatter

    env = (environment or os.environ.get("ENVIRONMENT", "development")).lower()
    level = (log_level or os.environ.get("LOG_LEVEL", "INFO")).upper()
    numeric_level = getattr(logging, level.upper(), logging.INFO)

    # ── Structlog processor chain (structlog-native) ──────────────────
    #
    # ``wrap_for_formatter`` stores the event dict inside the stdlib
    # LogRecord without rendering to a string.  The ``ProcessorFormatter``
    # (set on the handler below) picks this up and runs
    # ``processor=JSONRenderer()`` once – no double-wrapping.
    structlog.configure(
        processors=[
            # Must be first: merges bind_contextvars(svc=...) into every event.
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    # ── Root-logger handler with ProcessorFormatter ───────────────────
    #
    # ``processor`` (singular) handles *both* structlog-native log entries
    # (which arrive via ``wrap_for_formatter``) and plain stdlib log entries.
    #
    # ``foreign_pre_chain`` enriches plain stdlib records with level,
    # logger name, and timestamp before the final renderer runs.
    formatter = ProcessorFormatter(
        processor=structlog.processors.JSONRenderer(),
        foreign_pre_chain=[
            # Must be first: merges bind_contextvars(svc=...) into every log line,
            # even from plain stdlib loggers (logging.getLogger().info(...)).
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
        ],
    )

    # Replace all root-logger handlers with a single structlog handler.
    handler = logging.StreamHandler(stream=sys.stdout)
    handler.setFormatter(formatter)

    root = logging.getLogger()
    for h in root.handlers[:]:
        root.removeHandler(h)
    root.addHandler(handler)
    root.setLevel(numeric_level)

    # Bind ``service`` to the global contextvars so every log line carries
    # the service name without callers needing to pass it manually.
    structlog.contextvars.bind_contextvars(service=service_name)

    _log = structlog.get_logger()
    _log.info(
        "structured_logging_initialized",
        environment=env,
        log_level=level,
    )
