"""Capabilities endpoint — server-enforced limits for the mobile client.

The mobile client fetches this on startup to obtain authoritative upload,
usage, and timeout limits instead of relying on static AppConfig defaults.
The endpoint requires no authentication so the first startup warm-up can
succeed before any session is established.

A1-P1b: This is the server-side counterpart to the mobile client's
CapabilitiesService, CapabilitiesProvider, and CapabilitiesResponse model.
"""

from __future__ import annotations

from fastapi import APIRouter

# Server-enforced maximum upload size (50 MiB). The mobile client's
# conservative default is 20 MiB; the authoritative backend limit is
# defined here and in src/utils/upload_validation.MAX_UPLOAD_BYTES.
_CAPABILITIES_MAX_UPLOAD_BYTES: int = 50 * 1024 * 1024

router = APIRouter(tags=["capabilities"])


@router.get("/capabilities")
def get_capabilities():
    """Return server-enforced limits for the mobile client.

    All six fields are required. The client uses these to override its
    static AppConfig defaults during the startup warm-up.
    """
    return {
        "max_upload_file_size_bytes": _CAPABILITIES_MAX_UPLOAD_BYTES,
        "default_session_limit": 5,
        "default_ip_limit": 10,
        "session_duration_seconds": 86400,  # 24 hours
        "connect_timeout_seconds": 10,
        "receive_timeout_seconds": 90,
    }
