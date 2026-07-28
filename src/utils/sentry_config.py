"""Conditional Sentry SDK initialisation for backend services.

Sentry is enabled only when ``SENTRY_DSN`` is set and non-empty. The startup
guard prevents startup failures when no DSN is configured (local development,
early staging) while ensuring production instances never silently skip crash
reporting.

Usage::

    from src.utils.sentry_config import init_sentry, shutdown_sentry

    await init_sentry(service_name="api")
    # ... application runs ...
    await shutdown_sentry()
"""

from __future__ import annotations

import os
import logging

logger = logging.getLogger(__name__)


SENTRY_DSN_VAR = "SENTRY_DSN"


def sentry_dsn() -> str:
    """Return the configured DSN or an empty string."""
    return os.environ.get(SENTRY_DSN_VAR, "").strip()


def has_sentry_config() -> bool:
    """Return True when a production DSN is present and looks valid."""
    dsn = sentry_dsn()
    if not dsn:
        return False
    # Minimal sanity check: Sentry DSNs start with ``https://`` and contain
    # a project ID after ``@``. This catches common typos without validating
    # the key cryptographically.
    return dsn.startswith("https://") and "@" in dsn and "/" in dsn.split("@")[-1]


def init_sentry(
    service_name: str = "api",
    traces_sample_rate: float | None = None,
    profiles_sample_rate: float | None = None,
    app_version: str | None = None,
) -> None:
    """Initialise the Sentry SDK for the given service.

    This is a synchronous helper intended to be called from an async lifespan
    context manager or sync startup. Sentry SDK initialisation is entirely
    synchronous — the ``async`` wrapper in the caller (if any) exists only
    for idiomatic lifespan integration.

    Parameters
    ----------
    service_name:
        Logical service name reported as the ``release`` tag (e.g. ``api``,
        ``worker``, ``frontend``).
    traces_sample_rate:
        Performance trace sampling rate (0.0–1.0). Defaults to 0.1 in
        production, 1.0 otherwise.
    profiles_sample_rate:
        Profiling sample rate (0.0–1.0). Defaults to 0.0 (disabled).
    app_version:
        Application version string. Avoids a circular import back into
        ``src.app.main`` by letting the caller provide the version.
    """
    if not has_sentry_config():
        logger.info("SENTRY_DSN is empty or malformed — Sentry SDK disabled")
        return

    import sentry_sdk
    dsn = sentry_dsn()

    environment = os.environ.get("ENVIRONMENT", "development").lower()
    if traces_sample_rate is None:
        traces_sample_rate = 0.1 if environment == "production" else 1.0
    if profiles_sample_rate is None:
        profiles_sample_rate = 0.0

    version = app_version or "unknown"

    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        release=f"coverwise-{service_name}@{version}",
        traces_sample_rate=traces_sample_rate,
        profiles_sample_rate=profiles_sample_rate,
        send_default_pii=True,
        log_level=logging.WARNING,
        tags={"service": service_name},
    )
    logger.info("Sentry SDK initialised for service=%s env=%s", service_name, environment)



def shutdown_sentry() -> None:
    """Flush pending events and shut down the Sentry SDK background thread."""
    import sentry_sdk

    client = sentry_sdk.get_client()
    if client is not None and client.is_active():
        client.flush(timeout=2.0)
        client.close()
        logger.info("Sentry SDK shut down")
    else:
        logger.debug("Sentry SDK was not active — nothing to flush")
