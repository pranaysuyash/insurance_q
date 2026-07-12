"""Anonymous, bearer-token identity for the no-login CoverWise flow.

This is intentionally an identity layer, not an account system. A device gets a
random opaque subject signed by the server; every policy-bearing request must
present the signed credential. Production never starts this mechanism without
an explicit signing key.
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import HTTPException
from jose import JWTError, jwt

ALGORITHM = "HS256"
ISSUER = "coverwise-api"
AUDIENCE = "coverwise-mobile"


def _signing_key() -> str:
    key = os.getenv("ANONYMOUS_AUTH_SIGNING_KEY", "")
    environment = os.getenv("ENVIRONMENT", "development").lower()
    if key:
        return key
    if environment == "production":
        raise RuntimeError(
            "ANONYMOUS_AUTH_SIGNING_KEY is required when ENVIRONMENT=production"
        )
    # Deliberately local-only. Tokens naturally stop working after a source
    # change/restart, preventing this fallback from ever being production-safe.
    return "coverwise-development-only-signing-key-change-me"


def issue_anonymous_token(subject: str | None = None) -> tuple[str, dict[str, Any]]:
    """Issue a bearer token, preserving an existing anonymous subject on refresh."""
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=30)
    claims: dict[str, Any] = {
        "sub": subject or f"anon:{uuid.uuid4()}",
        "jti": str(uuid.uuid4()),
        "iss": ISSUER,
        "aud": AUDIENCE,
        "iat": now,
        "exp": expires_at,
        "identity_type": "anonymous",
    }
    return jwt.encode(claims, _signing_key(), algorithm=ALGORITHM), claims


def verify_anonymous_token(token: str) -> dict[str, Any]:
    try:
        claims = jwt.decode(
            token,
            _signing_key(),
            algorithms=[ALGORITHM],
            issuer=ISSUER,
            audience=AUDIENCE,
        )
    except JWTError as error:
        raise HTTPException(status_code=401, detail="Invalid or expired access token") from error
    if claims.get("identity_type") != "anonymous" or not str(claims.get("sub", "")).startswith("anon:"):
        raise HTTPException(status_code=401, detail="Invalid anonymous identity")
    return claims
