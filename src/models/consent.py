"""Typed Pydantic models for the consent ledger (Security Phase 2).

Per ADR-2026-07-19-07, the consent ledger is server-side and
append-only. The Flutter app's existing local Hive box becomes
a cache; the server is the source of truth.

The schema has a fixed enum for consent_type (privacy_policy,
document_processing, analytics, marketing_emails, camera_access,
evaluation_dataset, model_improvement). Adding a new type requires:
  1. Adding the new value to the ConsentType enum here.
  2. Adding the new value to the SQL CHECK in
     supabase/migrations/2026_07_19_consent_ledger.sql.
  3. The Flutter app's UI handles the new type.
"""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class ConsentType(str, Enum):
    """The 5 consent types v1 supports. The enum must match
    the SQL CHECK exactly; a drift here means a write that
    the DB rejects."""

    PRIVACY_POLICY = "privacy_policy"
    DOCUMENT_PROCESSING = "document_processing"
    ANALYTICS = "analytics"
    MARKETING_EMAILS = "marketing_emails"
    CAMERA_ACCESS = "camera_access"
    EVALUATION_DATASET = "evaluation_dataset"
    MODEL_IMPROVEMENT = "model_improvement"


class ConsentRecord(BaseModel):
    """One row in public.consent_ledger. Inserted; never updated;
    never deleted (enforced by the trigger)."""

    id: str
    user_id: str
    consent_type: ConsentType
    granted: bool
    policy_version: str = Field(min_length=1)
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime


class RecordConsentRequest(BaseModel):
    """Caller-supplied shape for `ConsentLedgerService.record_consent`.
    The user_id is NOT in the request — it is extracted from the
    Supabase Auth token at the API boundary, to prevent
    spoofing."""

    consent_type: ConsentType
    granted: bool
    policy_version: str = Field(min_length=1)
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None


class CurrentConsent(BaseModel):
    """One row from v_current_consent: the most recent consent
    record for a (user_id, consent_type)."""

    id: str
    user_id: str
    consent_type: ConsentType
    granted: bool
    policy_version: str
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime
