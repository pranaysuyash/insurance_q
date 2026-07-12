from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from src.utils.anonymous_auth import issue_anonymous_token, verify_anonymous_token
from src.models.user import User

router = APIRouter(prefix="/user", tags=["user"])

def get_current_user(authorization: str = Header(...)) -> User:
    """Return the verified principal for every policy-bearing request."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Bearer authentication is required")
    claims = verify_anonymous_token(authorization.removeprefix("Bearer "))
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

@router.get("/profile", response_model=User)
def get_profile(current_user: User = Depends(get_current_user)):
    return current_user
