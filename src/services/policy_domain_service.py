"""Supabase boundary for normalized policy identity and document structure."""

from __future__ import annotations

import os
from datetime import datetime
from typing import Any, Optional
from src.utils.runtime_config import supabase_server_key


def _client() -> Optional[Any]:
    url = os.getenv("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if not url or not key:
        if os.getenv("ENVIRONMENT", "development").lower() == "production":
            raise RuntimeError("Supabase policy domain is required in production")
        return None
    from supabase import create_client
    return create_client(url, key)


def _date(value: Any) -> Optional[str]:
    if not value:
        return None
    return str(value)[:10]


def _rows(response: Any) -> list[dict[str, Any]]:
    data = getattr(response, "data", None)
    return data if isinstance(data, list) else []


def sync_document(
    *, document_id: str, owner_id: str, source_hash: Optional[str], metadata: dict[str, Any],
    sections: list[dict[str, Any]] | None = None,
) -> None:
    """Create/update the domain projection after document classification.

    The operation is idempotent for a document. Raw OCR and model output are
    deliberately excluded; only bounded identifiers and typed metadata cross
    this boundary.
    """
    client = _client()
    if client is None:
        return
    classification = metadata.get("classification") if isinstance(metadata.get("classification"), dict) else metadata
    policy_number = classification.get("policy_number")

    # First resolve the document version. This makes retries idempotent and
    # prevents a policy-number-less document from being merged into another
    # owner's/household policy projection.
    existing_version = client.table("policy_versions").select("policy_id").eq(
        "document_id", document_id
    ).limit(1).execute()
    version_rows = [row for row in _rows(existing_version) if row.get("policy_id")]
    if version_rows:
        policy_id = version_rows[0]["policy_id"]
        owner_check = client.table("policies").select("id").eq(
            "id", policy_id
        ).eq("owner_id", owner_id).limit(1).execute()
        if not _rows(owner_check):
            raise RuntimeError("Existing policy version is not owned by the document owner")
    else:
        policy = None
        if policy_number:
            policy = client.table("policies").select("id").eq(
                "owner_id", owner_id
            ).eq("policy_number", str(policy_number)).limit(1).execute()
        policy_rows = _rows(policy)
        if policy_rows:
            policy_id = policy_rows[0]["id"]
        else:
            created = client.table("policies").insert({
                "owner_id": owner_id,
                "family_member_id": classification.get("family_member_id"),
                "policy_number": policy_number,
                "insurer": classification.get("insurer"),
                "policy_type": classification.get("document_type"),
            }).execute()
            created_rows = _rows(created)
            if not created_rows:
                raise RuntimeError("Policy projection insert returned no row")
            policy_id = created_rows[0]["id"]
    client.table("policy_versions").upsert({
        "policy_id": policy_id,
        "document_id": document_id,
        "version_label": str(classification.get("version") or datetime.utcnow().date()),
        "effective_from": _date(classification.get("effective_date")),
        "effective_to": _date(classification.get("expiration_date")),
        "status": "current",
        "source_hash": source_hash,
        "metadata": {"classification_confidence": classification.get("confidence")},
    }, on_conflict="document_id").execute()
    for ordinal, section in enumerate(sections or [{"section_type": "general"}]):
        client.table("document_sections").upsert({
            "document_id": document_id,
            "ordinal": ordinal,
            "title": section.get("title"),
            "section_type": str(section.get("section_type") or "general"),
            "start_page": section.get("page"),
            "end_page": section.get("page"),
        }, on_conflict="document_id,ordinal").execute()
