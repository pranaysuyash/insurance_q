"""Consent ledger service (Security Phase 2 access layer).

Per ADR-2026-07-19-07, the consent ledger is server-side and
append-only. The database enforces append-only via a Postgres
trigger; the service is the typed Python access layer.

Per motto v3 §0.1 (no parallel paths), this is the only
module that writes to public.consent_ledger. The Flutter
app's local Hive box is a cache, not the source of truth.
The FastAPI route in src/api/consent.py is the only path
that calls this service from a request.
"""
from __future__ import annotations

import logging
import os
from typing import Optional
from uuid import UUID

from src.models.consent import (
    ConsentRecord,
    ConsentType,
    CurrentConsent,
    RecordConsentRequest,
)

log = logging.getLogger(__name__)


class ConsentLedgerError(Exception):
    """Base for all consent ledger service errors."""


class ConsentLedgerUnavailable(ConsentLedgerError):
    """The consent ledger is not configured on this deployment.
    Fail-loud: missing env means the API returns 503, not a
    silent empty list. The Flutter app's consent UI handles
    the 503 by keeping the local cache and showing a
    'last verified at' timestamp."""


class ConsentAppendOnlyViolation(ConsentLedgerError):
    """An UPDATE or DELETE was attempted on the consent ledger.
    The trigger raises this at the database level; the
    service translates it to a Python exception so the
    caller can log + alert. This is a security event: the
    ledger must never be modified."""


class ConsentLedgerService:
    """Typed access layer for the consent_ledger table.

    Append-only by intent. The constructor accepts an
    optional pre-built client for testability; production
    uses from_env().
    """

    def __init__(
        self,
        supabase_url: str,
        service_role_key: str,
        client: Optional[object] = None,
    ):
        if client is not None:
            self._client = client
            return
        if not supabase_url or not service_role_key:
            raise ConsentLedgerUnavailable(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for the consent ledger"
            )
        try:
            from supabase import create_client
        except ImportError as error:  # pragma: no cover
            raise ConsentLedgerUnavailable(
                "supabase package is required for the consent ledger"
            ) from error
        self._client = create_client(supabase_url, service_role_key)

    @staticmethod
    def from_env() -> "ConsentLedgerService":
        url = os.getenv("SUPABASE_URL", "").strip()
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not url or not key:
            raise ConsentLedgerUnavailable(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set"
            )
        return ConsentLedgerService(url, key)

    # --- write ---

    async def record_consent(
        self,
        user_id: str,
        request: RecordConsentRequest,
    ) -> UUID:
        """Record a consent event. Appends a row to consent_ledger.
        The row is never updated or deleted (enforced at the
        database level)."""
        if not user_id:
            raise ConsentLedgerError("user_id must not be empty")
        row = {
            "user_id": user_id,
            "consent_type": request.consent_type.value,
            "granted": request.granted,
            "policy_version": request.policy_version,
            "ip_address": request.ip_address,
            "user_agent": request.user_agent,
        }
        try:
            response = (
                self._client.table("consent_ledger").insert(row).execute()
            )
        except Exception as error:
            error_str = str(error).lower()
            if "append-only" in error_str or "update is not allowed" in error_str:
                raise ConsentAppendOnlyViolation(
                    f"consent_ledger UPDATE attempted: {error}"
                ) from error
            raise
        if not response.data:
            raise ConsentLedgerError(
                f"consent_ledger insert returned no row for user {user_id}"
            )
        return UUID(response.data[0]["id"])

    # --- read ---

    async def get_current_consent(
        self, user_id: str, consent_type: ConsentType
    ) -> Optional[CurrentConsent]:
        """Read the most recent consent record for a (user_id,
        consent_type). Returns None if no record exists.
        Uses v_current_consent (the operator view) which
        already filters to the most recent row."""
        try:
            response = (
                self._client.table("v_current_consent")
                .select("*")
                .eq("user_id", user_id)
                .eq("consent_type", consent_type.value)
                .limit(1)
                .execute()
            )
        except Exception as error:
            log.warning("v_current_consent read failed: %s", error)
            return None
        if not response.data:
            return None
        try:
            return CurrentConsent.model_validate(response.data[0])
        except Exception as error:
            log.error("v_current_consent row failed to validate: %s", error)
            return None

    async def get_current_consent_all(
        self, user_id: str
    ) -> list[CurrentConsent]:
        """Read the most recent consent record for each
        consent_type for a user. Returns an empty list if
        the user has no consent records."""
        try:
            response = (
                self._client.table("v_current_consent")
                .select("*")
                .eq("user_id", user_id)
                .execute()
            )
        except Exception as error:
            log.warning("v_current_consent read failed: %s", error)
            return []
        if not response.data:
            return []
        return [
            CurrentConsent.model_validate(row) for row in response.data
        ]

    async def get_history(
        self, user_id: str, limit: int = 100
    ) -> list[ConsentRecord]:
        """Read the user's full consent history (for the
        operator dashboard's audit view). Newest first."""
        try:
            response = (
                self._client.table("consent_ledger")
                .select("*")
                .eq("user_id", user_id)
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )
        except Exception as error:
            log.warning("consent_ledger read failed: %s", error)
            return []
        if not response.data:
            return []
        return [
            ConsentRecord.model_validate(row) for row in response.data
        ]
