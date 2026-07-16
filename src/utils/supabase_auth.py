"""Supabase Auth token verification for the API boundary.

The mobile client owns the user-facing Supabase Auth session. The API accepts
the resulting access token and asks Supabase Auth to validate it, so the API
does not create a second password or refresh-token system.
"""

from __future__ import annotations

import os
from functools import lru_cache

from fastapi import HTTPException


@lru_cache(maxsize=1)
def _auth_client():
    url = os.getenv("SUPABASE_URL", "").strip()
    service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not service_role_key:
        raise RuntimeError(
            "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for account auth"
        )
    try:
        from supabase import create_client
    except ImportError as error:  # pragma: no cover - deployment dependency
        raise RuntimeError("supabase is required for account auth") from error
    return create_client(url, service_role_key)


def verify_supabase_token(access_token: str) -> dict:
    """Return the canonical Supabase user claims for an active access token."""
    try:
        response = _auth_client().auth.get_user(access_token)
        user = getattr(response, "user", None)
        if user is None:
            raise ValueError("Supabase returned no user")
        return {
            "sub": str(user.id),
            "email": user.email,
            "display_name": (user.user_metadata or {}).get("display_name"),
            "identity_type": "account",
        }
    except Exception as error:
        raise HTTPException(status_code=401, detail="Invalid or expired account token") from error


def clear_auth_client_cache() -> None:
    """Reset the client for tests or deliberate configuration reloads."""
    _auth_client.cache_clear()
