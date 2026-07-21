"""Replay identity for canonical analytics events."""

from __future__ import annotations

import hashlib
import json
from typing import Any


def stable_event_id(row: dict[str, Any]) -> str:
    """Derive identity without receive time or client-claimed UID."""
    identity = {
        key: row.get(key)
        for key in (
            "event_name", "timestamp", "user_uid", "properties",
            "install_id", "session_id", "is_reinstall",
        )
    }
    encoded = json.dumps(identity, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()
