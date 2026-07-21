"""Canonical document-object inventory boundary."""

from __future__ import annotations

import hashlib
import os
from datetime import datetime, timezone
from typing import Any, Optional


def _client() -> Optional[Any]:
    url = os.getenv("SUPABASE_URL", "").strip()
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        if os.getenv("ENVIRONMENT", "development").lower() == "production":
            raise RuntimeError("Supabase artifact inventory is required in production")
        return None
    from supabase import create_client
    return create_client(url, key)


def record_source(
    document_id: str,
    owner_id: str,
    object_reference: str,
    content: bytes,
    content_type: str = "application/pdf",
) -> None:
    client = _client()
    if client is None:
        return
    client.table("document_artifacts").upsert({
        "document_id": document_id,
        "owner_id": owner_id,
        "object_reference": object_reference,
        "artifact_kind": "source",
        "content_type": content_type,
        "byte_size": len(content),
        "checksum_sha256": hashlib.sha256(content).hexdigest(),
        "state": "active",
    }, on_conflict="document_id,object_reference").execute()


def record_derived(
    document_id: str,
    owner_id: str,
    object_reference: str,
    content: bytes,
    *,
    artifact_kind: str = "derived",
    content_type: str = "application/octet-stream",
) -> None:
    """Register a derived object with ownership, size, and checksum."""
    if artifact_kind not in {"page_image", "derived", "embedding_cache"}:
        raise ValueError("invalid derived artifact kind")
    client = _client()
    if client is None:
        return
    client.table("document_artifacts").upsert({
        "document_id": document_id,
        "owner_id": owner_id,
        "object_reference": object_reference,
        "artifact_kind": artifact_kind,
        "content_type": content_type,
        "byte_size": len(content),
        "checksum_sha256": hashlib.sha256(content).hexdigest(),
        "state": "active",
    }, on_conflict="document_id,object_reference").execute()


def mark_owner_deleted(owner_id: str) -> int:
    client = _client()
    if client is None:
        return 0
    response = client.table("document_artifacts").update({
        "state": "deleted",
        "deleted_at": datetime.now(timezone.utc).isoformat(),
    }).eq("owner_id", owner_id).neq("state", "deleted").select("id").execute()
    return len(response.data or [])


def mark_document_deleted(document_id: str) -> int:
    """Record cleanup of a source object after a queue enqueue failure."""
    client = _client()
    if client is None:
        return 0
    response = client.table("document_artifacts").update({
        "state": "deleted",
        "deleted_at": datetime.now(timezone.utc).isoformat(),
    }).eq("document_id", document_id).neq("state", "deleted").select("id").execute()
    return len(response.data or [])
