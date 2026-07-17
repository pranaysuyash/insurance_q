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


@router.delete("/account")
def delete_account(current_user: User = Depends(get_current_user)):
    """Permanently delete the user's account and all associated data.
    
    This removes:
    - All source files from Supabase Storage
    - All document metadata and chunks from the metadata store
    - The user's Supabase auth account
    
    Local device data is NOT affected — the client handles that separately.
    """
    if not current_user.is_account:
        raise HTTPException(status_code=403, detail="Only account users can delete their account")
    
    import logging
    import os
    from src.api import document as document_api
    
    logger = logging.getLogger(__name__)
    
    # Step 1: List all documents to collect storage file references
    documents = document_api.document_repository.list_for_owner(current_user.uid)
    storage_files_deleted = 0
    storage_errors = 0
    
    # Step 2: Delete source files from Supabase Storage (best-effort)
    for doc in documents:
        if doc.file_path and doc.file_path.startswith("supabase://"):
            try:
                from src.services.document_object_store import create_document_object_store
                object_store = create_document_object_store()
                object_store.delete(doc.file_path)
                storage_files_deleted += 1
            except Exception as e:
                storage_errors += 1
                logger.warning(
                    "Failed to delete storage file %s: %s",
                    doc.file_path[:60],
                    e,
                )
    
    # Step 3: Delete all document metadata and chunks
    deleted_docs = document_api.document_repository.delete_all_for_owner(current_user.uid)
    
    # Step 4: Delete the Supabase auth user (requires service_role key)
    auth_deleted = False
    try:
        from supabase import create_client
        
        supabase_url = os.getenv("SUPABASE_URL", "")
        service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
        
        if supabase_url and service_role_key:
            admin_client = create_client(supabase_url, service_role_key)
            admin_client.auth.admin.delete_user(current_user.uid)
            auth_deleted = True
    except Exception as e:
        logger.warning("Failed to delete Supabase auth user %s: %s", current_user.uid[:12], e)
    
    return {
        "deleted_documents": deleted_docs,
        "deleted_storage_files": storage_files_deleted,
        "storage_errors": storage_errors,
        "auth_user_deleted": auth_deleted,
        "message": "Account and all associated data have been permanently deleted."
    }
