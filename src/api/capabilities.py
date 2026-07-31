"""Capabilities endpoint — server-enforced limits for the mobile client.

The mobile client fetches this on startup to obtain authoritative upload,
usage, and timeout limits instead of relying on static AppConfig defaults.
The endpoint requires no authentication so the first startup warm-up can
succeed before any session is established.

A1-P1b: This is the server-side counterpart to the mobile client's
CapabilitiesService, CapabilitiesProvider, and CapabilitiesResponse model.
All values are imported from their canonical sources so the endpoint is
the single source of truth — no client constant overrides a server limit.
"""

from __future__ import annotations

import os

from fastapi import APIRouter

from src.utils.upload_validation import MAX_UPLOAD_BYTES
from src.utils.anti_abuse import RATE_LIMITS

router = APIRouter(tags=["capabilities"])

# Session duration — configurable via environment, defaults to 24 hours.
_SESSION_DURATION_SECONDS: int = int(
    os.getenv("SESSION_DURATION_SECONDS", "86400")
)

# Network timeouts — configurable via environment.
_CONNECT_TIMEOUT_SECONDS: int = int(os.getenv("CONNECT_TIMEOUT_SECONDS", "10"))
_RECEIVE_TIMEOUT_SECONDS: int = int(os.getenv("RECEIVE_TIMEOUT_SECONDS", "90"))


@router.get("/capabilities")
def get_capabilities():
    """Return server-enforced limits for the mobile client.

    All six fields are required. The client uses these to override its
    static AppConfig defaults during the startup warm-up.

    Values are imported from canonical sources:
    - max_upload_file_size_bytes ← upload_validation.MAX_UPLOAD_BYTES
    - default_session_limit ← anti_abuse.RATE_LIMITS['session_daily']
    - default_ip_limit ← anti_abuse.RATE_LIMITS['ip_daily']
    """
    return {
        "max_upload_file_size_bytes": MAX_UPLOAD_BYTES,
        "default_session_limit": RATE_LIMITS["session_daily"],
        "default_ip_limit": RATE_LIMITS["ip_daily"],
        "session_duration_seconds": _SESSION_DURATION_SECONDS,
        "connect_timeout_seconds": _CONNECT_TIMEOUT_SECONDS,
        "receive_timeout_seconds": _RECEIVE_TIMEOUT_SECONDS,
    }
