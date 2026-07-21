from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from src.utils.anonymous_auth import issue_anonymous_token, verify_anonymous_token
from src.utils.supabase_auth import verify_supabase_token
from src.models.user import User
from src.services.identity_link_service import begin as begin_identity_link
from src.services.identity_link_service import complete as complete_identity_link
from src.services.identity_link_service import fail as fail_identity_link

router = APIRouter(prefix="/user", tags=["user"])
bearer_scheme = HTTPBearer(auto_error=False)


def _document_api():
    """Load the canonical document module, respecting test/runtime injection."""
    import importlib

    return importlib.import_module("src.api.document")


class AnonymousClaimRequest(BaseModel):
    anonymous_token: str


def _account_export(current_user: User):
    document_api = _document_api()
    from src.services.document_object_store import create_document_object_store

    documents = document_api.document_repository.list_for_owner(current_user.uid)
    object_store = create_document_object_store()
    source_downloads = []
    for doc in documents:
        if not doc.file_path:
            continue
        try:
            url = object_store.create_download_url(doc.file_path, expires_seconds=900)
        except Exception:
            url = None
        if url:
            source_downloads.append({
                "document_id": doc.id,
                "url": url,
                "expires_in_seconds": 900,
            })
    return {
        "export_format_version": "v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "account": {"uid": current_user.uid, "email": current_user.email},
        "documents": [
            {
                "id": doc.id,
                "filename": doc.filename,
                "size": doc.size,
                "upload_date": doc.upload_date.isoformat(),
                "status": doc.status,
                "source_hash": doc.source_hash,
            }
            for doc in documents
        ],
        "source_files": "Source files remain private and are exposed only through short-lived download links.",
        "source_downloads": source_downloads,
    }

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
    try:
        link = begin_identity_link(anonymous_owner, current_user.uid)
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail="Identity linking is temporarily unavailable") from error

    # A completed link is the idempotency record. Returning it makes retries
    # safe after a client timeout or a duplicated account-submit action.
    if link.status == "completed":
        return {
            "transferred_documents": link.transferred_documents,
            "owner_id": current_user.uid,
            "identity_link_status": "completed",
        }
    document_api = _document_api()

    try:
        transferred = document_api.document_repository.transfer_owner(
            anonymous_owner, current_user.uid
        )
        complete_identity_link(anonymous_owner, current_user.uid, transferred)
    except Exception as error:
        try:
            fail_identity_link(anonymous_owner, current_user.uid, type(error).__name__)
        except Exception:
            pass
        raise HTTPException(status_code=503, detail="Anonymous workspace transfer did not complete") from error
    return {
        "transferred_documents": transferred,
        "owner_id": current_user.uid,
        "identity_link_status": "completed",
    }

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


@router.get("/account/export")
def export_account(current_user: User = Depends(get_current_user)):
    """Export account metadata without exposing private source contents."""
    if not current_user.is_account:
        raise HTTPException(status_code=403, detail="Only account users can export their account")
    return _account_export(current_user)


@router.delete("/account", status_code=202)
def delete_account(current_user: User = Depends(get_current_user)):
    """Request deletion of the user's account and all associated data.

    Security audit P0-04 (2026-07-18): the previous implementation
    returned 200 and a 'permanently deleted' message even when source
    files or the Supabase auth user remained. The audit says:
    'return 202 deletion_requested; use a durable deletion job with
    retryable stages and verification.' The full durable-deletion job
    is Security Phase 3 (data inventory + durable erasure). The Phase 0
    minimum is honest copy: return 202 and a per-stage status, never
    claim 'permanently deleted' when any stage failed.

    Local device data is NOT affected — the client handles that separately.
    """
    if not current_user.is_account:
        raise HTTPException(status_code=403, detail="Only account users can delete their account")

    import os
    if os.getenv("ENVIRONMENT", "development").lower() == "production":
        from src.services.account_lifecycle_service import create_deletion_request
        from src.services.job_outbox_service import JobOutboxService
        from src.models.job_outbox import EnqueueRequest, JobType

        try:
            request = create_deletion_request(current_user.uid)
            outbox = JobOutboxService.from_env()
            import asyncio
            existing_job = asyncio.run(outbox.find_by_payload_field(
                JobType.ACCOUNT_DELETION, "request_id", request["id"]
            ))
            if existing_job is None:
                try:
                    asyncio.run(outbox.enqueue(EnqueueRequest(
                        job_type=JobType.ACCOUNT_DELETION,
                        payload={"request_id": request["id"], "account_uid": current_user.uid},
                    )))
                except Exception:
                    # Concurrent retries are converged by the unique payload
                    # index; re-read before treating the request as failed.
                    existing_job = asyncio.run(outbox.find_by_payload_field(
                        JobType.ACCOUNT_DELETION, "request_id", request["id"]
                    ))
                    if existing_job is None:
                        raise
        except Exception as error:
            raise HTTPException(status_code=503, detail="Account deletion queue is temporarily unavailable") from error
        return {
            "status": "deletion_requested",
            "request_id": request["id"],
            "message": "Deletion was queued. The account remains active until all server erasure stages are verified.",
        }

    import logging
    document_api = _document_api()

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
    auth_error = None
    try:
        from supabase import create_client

        supabase_url = os.getenv("SUPABASE_URL", "")
        service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

        if supabase_url and service_role_key:
            admin_client = create_client(supabase_url, service_role_key)
            admin_client.auth.admin.delete_user(current_user.uid)
            auth_deleted = True
    except Exception as e:
        auth_error = str(e)
        logger.warning("Failed to delete Supabase auth user %s: %s", current_user.uid[:12], e)

    # Security audit P0-04: per-stage status, never a false completion
    # claim. The phase-0 minimum is honest reporting; the durable
    # deletion job (with retries, tombstone, and verification) is
    # Security Phase 3.
    all_stages_clean = (
        storage_errors == 0
        and deleted_docs == len(documents)
        and auth_deleted
    )
    failed_stages = []
    if storage_errors > 0:
        failed_stages.append("storage_object_deletion")
    if deleted_docs != len(documents):
        failed_stages.append("document_metadata_deletion")
    if not auth_deleted:
        failed_stages.append("auth_user_deletion")

    if all_stages_clean:
        status = "deletion_succeeded"
        message = (
            "Account and all associated server data have been permanently "
            "deleted. Local data on this device was not affected and can be "
            "cleared from the privacy screen."
        )
    else:
        status = "deletion_partial"
        message = (
            "Deletion request received, but some server stages could not be "
            "completed. The remaining stages are: "
            f"{', '.join(failed_stages)}. Do not assume server deletion is "
            "complete. Local data on this device was not affected and can "
            "be cleared from the privacy screen."
        )

    return {
        "status": status,
        "deleted_documents": deleted_docs,
        "deleted_storage_files": storage_files_deleted,
        "storage_errors": storage_errors,
        "auth_user_deleted": auth_deleted,
        "auth_error": auth_error,
        "failed_stages": failed_stages,
        "message": message,
    }
