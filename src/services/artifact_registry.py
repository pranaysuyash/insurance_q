"""Canonical document-object inventory boundary."""

from __future__ import annotations

import hashlib
import os
from datetime import datetime, timezone
from typing import Any, Optional

from src.utils.runtime_config import supabase_server_key


def _client() -> Optional[Any]:
    url = os.getenv("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if not url or not key:
        if os.getenv("ENVIRONMENT", "development").lower() == "production":
            raise RuntimeError("Supabase artifact inventory is required in production")
        return None
    from src.utils.supabase_client import create_client
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


def _delete_inventory_rows(rows: list[dict[str, Any]], *, store: Any) -> dict[str, int]:
    """Delete registered objects before their inventory rows can cascade.

    Object deletion is intentionally attempted before the inventory transition.
    Storage adapters are idempotent, so retrying after a worker crash is safe.
    A row is marked deleted only after the adapter returns successfully.
    """
    from src.services.artifact_lifecycle_service import _transition

    deleted = 0
    for row in rows:
        store.delete(row["object_reference"])
        if _transition(row["id"], "deleted", "object_deleted", "erasure_worker"):
            deleted += 1
    return {"attempted": len(rows), "deleted": deleted}


def delete_document_artifacts(document_id: str, owner_id: str) -> dict[str, int]:
    """Physically delete all registered objects for one owner-scoped document."""
    client = _client()
    if client is None:
        return {"attempted": 0, "deleted": 0}
    rows = client.table("document_artifacts").select(
        "id,object_reference,state"
    ).eq("document_id", document_id).eq("owner_id", owner_id).neq("state", "deleted").execute().data or []
    from src.services.document_object_store import create_document_object_store
    return _delete_inventory_rows(rows, store=create_document_object_store())


def delete_owner_artifacts(owner_id: str) -> dict[str, int]:
    """Physically delete every registered object owned by an account."""
    client = _client()
    if client is None:
        return {"attempted": 0, "deleted": 0}
    rows = client.table("document_artifacts").select(
        "id,object_reference,state"
    ).eq("owner_id", owner_id).neq("state", "deleted").execute().data or []
    from src.services.document_object_store import create_document_object_store
    return _delete_inventory_rows(rows, store=create_document_object_store())


def delete_owner_derived_objects(owner_id: str) -> dict[str, int]:
    """Compatibility alias for the canonical account artifact deletion path."""
    return delete_owner_artifacts(owner_id)
