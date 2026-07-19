"""Trust Phase 1: evidence substrate read API.

Exposes the field citations that the evidence pipeline writes
to the substrate. The policy detail screen reads from this
endpoint to render cited fields with page references. This is
the ONLY API surface that exposes substrate data to the mobile
app; per motto v3 §0.1 (no parallel paths), no other route
returns field citations.
"""
from __future__ import annotations

import logging
import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from src.api.user import get_current_user
from src.models.user import User
from src.services.evidence_substrate_service import (
    EvidenceSubstrateService,
    EvidenceSubstrateUnavailable,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/evidence", tags=["evidence"])


def _get_substrate() -> EvidenceSubstrateService:
    """Construct a fresh substrate service. In production this
    would be injected; for now it reads from env. The construction
    is fail-loud: missing env means the route returns 503, not a
    silent empty list. Per Trust Phase 0, the policy detail
    screen handles 503 by keeping the 'Not yet verified' scaffold."""
    try:
        return EvidenceSubstrateService.from_env()
    except EvidenceSubstrateUnavailable as error:
        raise HTTPException(
            status_code=503,
            detail="Evidence substrate is not configured on this deployment.",
        ) from error


def _citation_to_dict(citation) -> dict:
    """Convert a FieldCitation to a JSON-serializable dict for the
    Flutter client. The Flutter side has its own typed model
    (FieldCitation in mobile/lib/models/evidence_citation.dart)
    that mirrors this shape; keep the two in sync."""
    return {
        "document_id": citation.document_id,
        "field_name": citation.field_name,
        "value": {
            "raw": citation.value.raw,
            "normalized": citation.value.normalized,
            "display": citation.value.display,
        },
        "value_type": citation.value_type.value,
        "field_confidence": citation.field_confidence,
        "parser_kind": citation.parser_kind.value,
        "cite_string": citation.cite_string,
        "evidence_strength": citation.evidence_strength,
        "page_number": citation.page_number,
        "image_uri": citation.image_uri,
    }


@router.get("/{document_id}/field-citations", response_model=list[dict])
async def get_field_citations(
    document_id: str,
    field_names: Optional[str] = None,
    current_user: User = Depends(get_current_user),
):
    """Return cited fields for a document, ordered by strongest
    evidence first via the v_field_citations view.

    field_names is an optional comma-separated filter (e.g.
    "sum_insured,room_rent_cap"). If absent, returns every
    cited field for the document.

    The endpoint is owner-scoped: the caller must be the
    document owner. The substrate itself is service-role-only
    with no RLS, so this route enforces owner identity at the
    API boundary per the canonical DocumentRepository pattern.
    """
    # Owner check: the document must belong to the current user.
    # We use the existing DocumentRepository rather than touching
    # the substrate's documents table; the canonical document
    # store is the source of truth for owner identity.
    # NOTE: the User model exposes `uid`, not `id`. Using
    # `current_user.id` here would raise AttributeError at
    # runtime; the test in tests/test_evidence_api_owner_check.py
    # pins this contract.
    try:
        from src.services.document_repository import create_document_repository
        repo = create_document_repository()
        document = repo.get(document_id, current_user.uid)
    except Exception as error:  # pragma: no cover - repo construction
        logger.warning("document lookup failed: %s", error)
        raise HTTPException(
            status_code=503, detail="Document store unavailable"
        ) from error
    if document is None:
        raise HTTPException(
            status_code=404, detail="Document not found"
        )

    substrate = _get_substrate()
    try:
        import uuid
        names = (
            [n.strip() for n in field_names.split(",") if n.strip()]
            if field_names
            else None
        )
        citations = await substrate.get_field_citations(
            document_id=uuid.UUID(document_id),
            field_names=names,
        )
    except EvidenceSubstrateUnavailable as error:
        raise HTTPException(
            status_code=503, detail="Evidence substrate unavailable"
        ) from error
    except ValueError as error:
        raise HTTPException(
            status_code=400, detail=f"Invalid document_id: {error}"
        ) from error
    return [_citation_to_dict(c) for c in citations]
