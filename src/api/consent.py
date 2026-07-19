"""Security Phase 2: consent ledger API.

Per docs/decisions/ADR-2026-07-19-07-...md, the consent
ledger is server-side and append-only. The Flutter app
calls these endpoints to record consent events and to
read the current consent state. The local Hive box is a
cache; the server is the source of truth.

This is the ONLY path that exposes the consent ledger to
the mobile app. Per motto v3 §0.1 (no parallel paths), no
other route returns consent data.
"""
from __future__ import annotations

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request

from src.api.user import get_current_user
from src.models.consent import (
    ConsentType,
    CurrentConsent,
    RecordConsentRequest,
)
from src.models.user import User
from src.services.consent_ledger_service import (
    ConsentAppendOnlyViolation,
    ConsentLedgerService,
    ConsentLedgerUnavailable,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/consent", tags=["consent"])


def _get_service() -> ConsentLedgerService:
    """Construct a fresh service. In production this would be
    injected; for now it reads from env. The construction
    is fail-loud: missing env means the route returns 503."""
    try:
        return ConsentLedgerService.from_env()
    except ConsentLedgerUnavailable as error:
        raise HTTPException(
            status_code=503,
            detail="Consent ledger is not configured on this deployment.",
        ) from error


@router.post("", status_code=201)
async def record_consent(
    request_body: RecordConsentRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    """Record a consent event. The user_id is extracted from
    the Supabase Auth token (not from the body) to prevent
    spoofing. The ip_address and user_agent are extracted
    from the request headers (overridable by the body for
    testability)."""
    ip_address = (
        request_body.ip_address
        or (request.client.host if request.client else None)
    )
    user_agent = (
        request_body.user_agent
        or request.headers.get("user-agent")
    )
    service = _get_service()
    try:
        new_id = await service.record_consent(
            user_id=current_user.id,
            request=RecordConsentRequest(
                consent_type=request_body.consent_type,
                granted=request_body.granted,
                policy_version=request_body.policy_version,
                ip_address=ip_address,
                user_agent=user_agent,
            ),
        )
    except ConsentAppendOnlyViolation as error:
        # This is a security event. The append-only contract
        # was violated; the database raised an exception.
        # We return 500 and log loudly. The operator must
        # investigate.
        logger.error(
            "consent_ledger append-only violation: %s", error
        )
        raise HTTPException(
            status_code=500,
            detail="Consent ledger append-only contract violated.",
        ) from error
    return {"id": str(new_id)}


@router.get("/current", response_model=list[dict])
async def get_current_consent_all(
    current_user: User = Depends(get_current_user),
):
    """Return the current consent state for the authenticated
    user. One row per consent_type (the most recent record).
    The Flutter app reads this on app start to populate the
    local cache."""
    service = _get_service()
    rows = await service.get_current_consent_all(current_user.id)
    return [_current_consent_to_dict(r) for r in rows]


@router.get("/history", response_model=list[dict])
async def get_consent_history(
    current_user: User = Depends(get_current_user),
    limit: int = 100,
):
    """Return the user's full consent history (newest first).
    For the Flutter app's "show me what I consented to" UI.
    The operator dashboard reads v_consent_history for the
    audit view; this endpoint is the user-facing read."""
    service = _get_service()
    rows = await service.get_history(current_user.id, limit=limit)
    return [_consent_record_to_dict(r) for r in rows]


def _current_consent_to_dict(c: CurrentConsent) -> dict:
    return {
        "id": c.id,
        "user_id": c.user_id,
        "consent_type": c.consent_type.value,
        "granted": c.granted,
        "policy_version": c.policy_version,
        "ip_address": c.ip_address,
        "user_agent": c.user_agent,
        "created_at": c.created_at.isoformat(),
    }


def _consent_record_to_dict(r) -> dict:
    return {
        "id": r.id,
        "user_id": r.user_id,
        "consent_type": r.consent_type.value,
        "granted": r.granted,
        "policy_version": r.policy_version,
        "ip_address": r.ip_address,
        "user_agent": r.user_agent,
        "created_at": r.created_at.isoformat(),
    }
