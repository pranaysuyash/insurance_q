"""Self-reported claim-log model for the claims API.

Mirrors the Supabase claims table schema. The mobile-side
ClaimRecord (mobile/lib/models/claim_record.dart) serializes
to/from JSON in the same shape so the two sides are compatible.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class StatusUpdate(BaseModel):
    """A single status change event in a claim's lifecycle."""

    status: str = Field(..., pattern=r"^(filed|in_review|approved|rejected|paid)$")
    timestamp: datetime


class ClaimRecord(BaseModel):
    """One user-maintained claim-log record, matching the table schema."""

    id: UUID
    owner_id: str = Field(min_length=1)
    document_id: Optional[str] = None
    policy_type: str = "Unknown"
    insurer: str = "Unknown"
    incident_type: str = "Other"
    description: str = ""
    filed_date: datetime
    reference_number: Optional[str] = None
    status: str = Field(default="filed", pattern=r"^(filed|in_review|approved|rejected|paid)$")
    notes: Optional[str] = None
    photo_paths: list[str] = Field(default_factory=list)
    status_history: list[StatusUpdate] = Field(default_factory=list)
    initiated_by: str = "user"
    agent_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# --- Request/response schemas ---


class CreateClaimRequest(BaseModel):
    """Request body for POST /claims."""

    document_id: Optional[str] = None
    policy_type: str = "Unknown"
    insurer: str = "Unknown"
    incident_type: str = "Other"
    description: str = ""
    reference_number: Optional[str] = None
    notes: Optional[str] = None
    photo_paths: list[str] = Field(default_factory=list)

    model_config = {"extra": "forbid"}


class UpdateClaimRequest(BaseModel):
    """Request body for PATCH /claims/{claim_id}."""

    status: Optional[str] = Field(
        default=None, pattern=r"^(filed|in_review|approved|rejected|paid)$"
    )
    reference_number: Optional[str] = None
    notes: Optional[str] = None


class ClaimResponse(BaseModel):
    """Response shape for a single claim."""

    id: str
    owner_id: str
    document_id: Optional[str] = None
    policy_type: str
    insurer: str
    incident_type: str
    description: str
    filed_date: str
    reference_number: Optional[str] = None
    status: str
    notes: Optional[str] = None
    photo_paths: list[str]
    status_history: list[dict[str, Any]]
    initiated_by: str = "user"
    agent_id: Optional[str] = None
    created_at: str
    updated_at: str
