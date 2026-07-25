"""Claims API — a user's private, self-reported claim log.

Per docs/planning/product/TODO_app_improvements.md, this is the
backend endpoint for a personal claim record. CoverWise does not submit a
claim, obtain insurer status, make a decision, or act as an insurer/agent.
An authenticated user can create and read only their own records.

The Supabase `public.claims` table schema mirrors the mobile-side
ClaimRecord model (mobile/lib/models/claim_record.dart). The two
sides are kept in sync by the mobile ClaimsSyncService.
"""
from __future__ import annotations

from datetime import datetime
import logging
from typing import Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query

from src.api.user import get_current_user
from src.models.claim import (
    ClaimResponse,
    CreateClaimRequest,
    UpdateClaimRequest,
)
from src.models.user import User
from src.utils.runtime_config import supabase_server_key

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/claims", tags=["claims"])


def _get_client():
    """Lazy-init the Supabase client. Fail-loud: missing env = 503."""
    try:
        from src.utils.supabase_client import create_client
    except ImportError as error:
        raise HTTPException(
            status_code=503,
            detail="Claims service is not configured on this deployment.",
        ) from error

    import os
    url = os.getenv("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if not url or not key:
        raise HTTPException(
            status_code=503,
            detail="Claims service is not configured on this deployment.",
        )
    return create_client(url, key)


@router.post("", status_code=201, response_model=ClaimResponse)
async def create_claim(
    body: CreateClaimRequest,
    current_user: User = Depends(get_current_user),
):
    """Create a self-reported claim-log record.

    The owner is always extracted from the authenticated principal; request
    data cannot set a different owner or an adviser/agent provenance.
    """
    client = _get_client()
    now_str = "now()"

    row = {
        "id": str(uuid4()),
        "owner_id": current_user.uid,
        "document_id": body.document_id,
        "policy_type": body.policy_type,
        "insurer": body.insurer,
        "incident_type": body.incident_type,
        "description": body.description,
        "filed_date": now_str,
        "reference_number": body.reference_number,
        "status": "filed",
        "notes": body.notes,
        "photo_paths": body.photo_paths,
        "status_history": [
            {"status": "filed", "timestamp": datetime.utcnow().isoformat()}
        ],
        "initiated_by": "user",
        "agent_id": None,
        "created_at": now_str,
        "updated_at": now_str,
    }

    try:
        response = client.table("claims").insert(row).execute()
    except Exception as error:
        logger.error("claims_create_failed error_type=%s", type(error).__name__)
        raise HTTPException(
            status_code=500,
            detail="Failed to create claim record.",
        ) from error

    if not response.data:
        raise HTTPException(
            status_code=500,
            detail="Claim creation returned no data.",
        )

    created = response.data[0]
    return _row_to_response(created)


@router.get("", response_model=list[ClaimResponse])
async def list_claims(
    current_user: User = Depends(get_current_user),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    status: Optional[str] = Query(default=None, pattern=r"^(filed|in_review|approved|rejected|paid)$"),
):
    """List claims for the authenticated user.

    Returns claims ordered by filed_date descending (newest first).
    Optional status filter and pagination.
    """
    client = _get_client()
    query = (
        client.table("claims")
        .select("*")
        .eq("owner_id", current_user.uid)
        .order("filed_date", desc=True)
        .limit(limit)
        .offset(offset)
    )
    if status:
        query = query.eq("status", status)

    try:
        response = query.execute()
    except Exception as error:
        logger.error("claims_list_failed error_type=%s", type(error).__name__)
        raise HTTPException(
            status_code=500,
            detail="Failed to list claims.",
        ) from error

    rows = getattr(response, "data", None)
    if not rows:
        return []

    return [_row_to_response(row) for row in rows]


@router.get("/{claim_id}", response_model=ClaimResponse)
async def get_claim(
    claim_id: UUID,
    current_user: User = Depends(get_current_user),
):
    """Get a single claim by ID, owner-scoped."""
    client = _get_client()

    try:
        response = (
            client.table("claims")
            .select("*")
            .eq("id", str(claim_id))
            .eq("owner_id", current_user.uid)
            .limit(1)
            .execute()
        )
    except Exception as error:
        logger.error("claims_get_failed error_type=%s", type(error).__name__)
        raise HTTPException(
            status_code=500,
            detail="Failed to retrieve claim.",
        ) from error

    rows = getattr(response, "data", None)
    if not rows:
        raise HTTPException(status_code=404, detail="Claim not found.")

    return _row_to_response(rows[0])


@router.patch("/{claim_id}", response_model=ClaimResponse)
async def update_claim(
    claim_id: UUID,
    body: UpdateClaimRequest,
    current_user: User = Depends(get_current_user),
):
    """Update a user-reported status, reference number, or note.

    The status is a personal record, not insurer-sourced claim truth. The
    API appends a timestamped entry when it changes and scopes all writes to
    the authenticated owner.
    """
    client = _get_client()

    # Fetch current state first
    try:
        current = (
            client.table("claims")
            .select("*")
            .eq("id", str(claim_id))
            .eq("owner_id", current_user.uid)
            .limit(1)
            .execute()
        )
    except Exception as error:
        logger.error("claims_update_fetch_failed error_type=%s", type(error).__name__)
        raise HTTPException(
            status_code=500,
            detail="Failed to fetch claim for update.",
        ) from error

    rows = getattr(current, "data", None)
    if not rows:
        raise HTTPException(status_code=404, detail="Claim not found.")

    existing = rows[0]

    update_data: dict = {}

    if body.status is not None and body.status != existing.get("status"):
        update_data["status"] = body.status
        # Append to status_history
        history = existing.get("status_history") or []
        update_data["status_history"] = history + [
                {"status": body.status, "timestamp": datetime.utcnow().isoformat()}
            ]

    if body.reference_number is not None:
        update_data["reference_number"] = body.reference_number
    if body.notes is not None:
        update_data["notes"] = body.notes

    update_data["updated_at"] = datetime.utcnow().isoformat()

    if update_data.keys() == {"updated_at"}:
        return _row_to_response(existing)

    try:
        response = (
            client.table("claims")
            .update(update_data)
            .eq("id", str(claim_id))
            .eq("owner_id", current_user.uid)
            .execute()
        )
    except Exception as error:
        logger.error("claims_update_failed error_type=%s", type(error).__name__)
        raise HTTPException(
            status_code=500,
            detail="Failed to update claim.",
        ) from error

    updated_rows = getattr(response, "data", None)
    if not updated_rows:
        raise HTTPException(status_code=500, detail="Claim update returned no data.")

    return _row_to_response(updated_rows[0])


@router.delete("/{claim_id}", status_code=204)
async def delete_claim(
    claim_id: UUID,
    current_user: User = Depends(get_current_user),
):
    """Delete a claim. Owner-scoped."""
    client = _get_client()

    try:
        response = (
            client.table("claims")
            .delete()
            .eq("id", str(claim_id))
            .eq("owner_id", current_user.uid)
            .execute()
        )
    except Exception as error:
        logger.error("claims_delete_failed error_type=%s", type(error).__name__)
        raise HTTPException(
            status_code=500,
            detail="Failed to delete claim.",
        ) from error

    rows = getattr(response, "data", None)
    if not rows:
        raise HTTPException(status_code=404, detail="Claim not found.")


def _row_to_response(row: dict) -> ClaimResponse:
    """Convert a Supabase row dict to a ClaimResponse."""
    history = row.get("status_history") or []
    if isinstance(history, list):
        parsed_history = []
        for entry in history:
            if isinstance(entry, dict):
                parsed_history.append({
                    "status": entry.get("status", "filed"),
                    "timestamp": entry.get("timestamp", ""),
                })
    else:
        parsed_history = []

    photo_paths = row.get("photo_paths") or []
    if isinstance(photo_paths, list):
        parsed_photos = [str(p) for p in photo_paths]
    else:
        parsed_photos = []

    return ClaimResponse(
        id=str(row.get("id", "")),
        owner_id=str(row.get("owner_id", "")),
        document_id=row.get("document_id"),
        policy_type=str(row.get("policy_type", "Unknown")),
        insurer=str(row.get("insurer", "Unknown")),
        incident_type=str(row.get("incident_type", "Other")),
        description=str(row.get("description", "")),
        filed_date=_safe_isoformat(row.get("filed_date")),
        reference_number=row.get("reference_number"),
        status=str(row.get("status", "filed")),
        notes=row.get("notes"),
        photo_paths=parsed_photos,
        status_history=parsed_history,
        # Historical rows may contain the retired agent fields. They are not
        # part of the public product contract and must never be surfaced as
        # CoverWise acting for an insurer or adviser.
        initiated_by="user",
        agent_id=None,
        created_at=_safe_isoformat(row.get("created_at")),
        updated_at=_safe_isoformat(row.get("updated_at")),
    )


def _safe_isoformat(val) -> str:
    """Return an ISO-formatted string from a datetime or string."""
    if val is None:
        return ""
    if hasattr(val, "isoformat"):
        return val.isoformat()
    return str(val)
