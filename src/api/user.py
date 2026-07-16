from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from src.utils.anonymous_auth import issue_anonymous_token, verify_anonymous_token
from src.utils.supabase_auth import verify_supabase_token
from src.models.user import User

router = APIRouter(prefix="/user", tags=["user"])
bearer_scheme = HTTPBearer(auto_error=False)


class AnonymousClaimRequest(BaseModel):
    anonymous_token: str

def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> User:
    """Return the verified principal for every policy-bearing request."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(status_code=401, detail="Bearer authentication is required")
    token = credentials.credentials
    if token.count(".") == 2:
        try:
            claims = verify_anonymous_token(token)
        except (HTTPException, RuntimeError):
            claims = verify_supabase_token(token)
    else:
        claims = verify_supabase_token(token)
    return User(
        uid=claims["sub"],
        identity_type=claims.get("identity_type", "account"),
        email=claims.get("email"),
        phone=None,
        display_name=claims.get("display_name"),
    )


@router.post("/claim-anonymous")
def claim_anonymous_documents(
    request: AnonymousClaimRequest,
    current_user: User = Depends(get_current_user),
):
    """Move this device's anonymous documents to the signed-in account once."""
    if not current_user.is_account:
        raise HTTPException(status_code=403, detail="An account is required to claim data")
    anonymous_claims = verify_anonymous_token(request.anonymous_token)
    anonymous_owner = anonymous_claims["sub"]
    from src.api import document as document_api

    transferred = document_api.document_repository.transfer_owner(
        anonymous_owner, current_user.uid
    )
    return {"transferred_documents": transferred, "owner_id": current_user.uid}

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
