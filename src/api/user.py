from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from src.utils.anonymous_auth import issue_anonymous_token, verify_anonymous_token
from src.models.user import User

router = APIRouter(prefix="/user", tags=["user"])
bearer_scheme = HTTPBearer(auto_error=False)

def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> User:
    """Return the verified principal for every policy-bearing request."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Bearer authentication is required")
    claims = verify_anonymous_token(credentials.credentials)
    return User(
        uid=claims["sub"],
        identity_type="anonymous",
        email=None,
        phone=None,
        display_name=None,
    )

@router.post("/anonymous")
def create_anonymous_identity():
    token, claims = issue_anonymous_token()
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_at": datetime.fromtimestamp(int(claims["exp"]), tz=timezone.utc).isoformat(),
        "user": {"uid": claims["sub"], "identity_type": "anonymous"},
    }


@router.post("/refresh")
def refresh_anonymous_identity(current_user: User = Depends(get_current_user)):
    """Rotate a still-valid device credential without changing ownership."""
    token, claims = issue_anonymous_token(current_user.uid)
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_at": datetime.fromtimestamp(int(claims["exp"]), tz=timezone.utc).isoformat(),
        "user": {"uid": claims["sub"], "identity_type": "anonymous"},
    }

@router.get("/profile", response_model=User)
def get_profile(current_user: User = Depends(get_current_user)):
    return current_user
