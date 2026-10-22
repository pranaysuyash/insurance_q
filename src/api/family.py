"""Family Workspace API — canonical backend persistence for user family members.

Supports:
- Owner-isolated CRUD for family member profiles
- Synchronization between mobile Hive workspace and Supabase persistence
- Safe cascade on user deletion
"""
from __future__ import annotations

from datetime import datetime, timezone
import logging
from typing import List, Optional
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query

from src.api.user import get_current_user
from src.models.family import (
    FamilyMemberResponse,
    CreateFamilyMemberRequest,
    UpdateFamilyMemberRequest,
)
from src.models.user import User
from src.utils.runtime_config import supabase_server_key

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/family", tags=["family"])


def _get_client():
    """Lazy-init the Supabase client. Fail-loud: missing env = 503."""
    try:
        from src.utils.supabase_client import create_client
    except ImportError as error:
        raise HTTPException(
            status_code=503,
            detail="Family service is not configured on this deployment.",
        ) from error

    import os
    url = os.getenv("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if not url or not key:
        raise HTTPException(
            status_code=503,
            detail="Family service is not configured on this deployment.",
        )
    return create_client(url, key)


@router.get("/members", response_model=List[FamilyMemberResponse])
async def list_family_members(
    current_user: User = Depends(get_current_user),
):
    """List all family members owned by the authenticated user."""
    client = _get_client()
    try:
        result = (
            client.table("family_members")
            .select("*")
            .eq("user_uid", current_user.uid)
            .order("created_at", desc=False)
            .execute()
        )
        return [FamilyMemberResponse(**row) for row in (result.data or [])]
    except Exception as exc:
        logger.error(f"Error fetching family members for {current_user.uid}: {exc}")
        raise HTTPException(status_code=500, detail="Failed to fetch family members") from exc


@router.post("/members", status_code=201, response_model=FamilyMemberResponse)
async def create_family_member(
    body: CreateFamilyMemberRequest,
    current_user: User = Depends(get_current_user),
):
    """Create a new family member profile for the authenticated user."""
    client = _get_client()
    now_iso = datetime.now(timezone.utc).isoformat()
    member_id = str(uuid4())

    row = {
        "id": member_id,
        "user_uid": current_user.uid,
        "name": body.name.strip(),
        "relationship": body.relationship.strip(),
        "dob": body.dob.isoformat() if body.dob else None,
        "phone": body.phone.strip() if body.phone else None,
        "email": body.email.strip() if body.email else None,
        "notes": body.notes.strip() if body.notes else None,
        "created_at": now_iso,
        "updated_at": now_iso,
    }

    try:
        result = client.table("family_members").insert(row).execute()
        if not result.data:
            raise HTTPException(status_code=500, detail="Failed to insert family member")
        return FamilyMemberResponse(**result.data[0])
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(f"Error creating family member for {current_user.uid}: {exc}")
        raise HTTPException(status_code=500, detail="Failed to create family member") from exc


@router.put("/members/{member_id}", response_model=FamilyMemberResponse)
async def update_family_member(
    member_id: str,
    body: UpdateFamilyMemberRequest,
    current_user: User = Depends(get_current_user),
):
    """Update an existing family member belonging to the authenticated user."""
    client = _get_client()
    now_iso = datetime.now(timezone.utc).isoformat()

    updates = {"updated_at": now_iso}
    if body.name is not None:
        updates["name"] = body.name.strip()
    if body.relationship is not None:
        updates["relationship"] = body.relationship.strip()
    if body.dob is not None:
        updates["dob"] = body.dob.isoformat()
    if body.phone is not None:
        updates["phone"] = body.phone.strip() if body.phone else None
    if body.email is not None:
        updates["email"] = body.email.strip() if body.email else None
    if body.notes is not None:
        updates["notes"] = body.notes.strip() if body.notes else None

    try:
        result = (
            client.table("family_members")
            .update(updates)
            .eq("id", member_id)
            .eq("user_uid", current_user.uid)
            .execute()
        )
        if not result.data:
            raise HTTPException(status_code=404, detail="Family member not found")
        return FamilyMemberResponse(**result.data[0])
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(f"Error updating family member {member_id}: {exc}")
        raise HTTPException(status_code=500, detail="Failed to update family member") from exc


@router.delete("/members/{member_id}", status_code=204)
async def delete_family_member(
    member_id: str,
    current_user: User = Depends(get_current_user),
):
    """Delete a family member belonging to the authenticated user."""
    client = _get_client()
    try:
        result = (
            client.table("family_members")
            .delete()
            .eq("id", member_id)
            .eq("user_uid", current_user.uid)
            .execute()
        )
        if not result.data:
            # Idempotent: if already deleted or does not exist, return 204
            pass
        return None
    except Exception as exc:
        logger.error(f"Error deleting family member {member_id}: {exc}")
        raise HTTPException(status_code=500, detail="Failed to delete family member") from exc

