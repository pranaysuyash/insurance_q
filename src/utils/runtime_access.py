"""Runtime access guards shared by public API routers.

Diagnostic routes must never become an accidental production control plane.
Keeping this guard outside ``src.app.main`` avoids router-to-app import cycles.
"""

from __future__ import annotations

import os

from fastapi import HTTPException


def require_nonproduction() -> None:
    """Hide diagnostics and retired compatibility endpoints in production."""
    if os.environ.get("ENVIRONMENT", "development").lower() == "production":
        raise HTTPException(status_code=404, detail="Not found")
