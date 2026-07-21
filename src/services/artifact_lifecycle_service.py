"""Explicit retention/orphan transitions for document artifacts."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Optional, Sequence


def _client() -> Optional[Any]:
    url = os.getenv("SUPABASE_URL", "").strip()
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url or not key:
        if os.getenv("ENVIRONMENT", "development").lower() == "production":
            raise RuntimeError("Supabase artifact lifecycle is required in production")
        return None
    from supabase import create_client
    return create_client(url, key)


def _transition(artifact_id: str, to_state: str, reason: str, actor: str) -> bool:
    client = _client()
    if client is None:
        return False
    current = client.table("document_artifacts").select("id,state").eq("id", artifact_id).limit(1).execute()
    if not current.data or current.data[0].get("state") == to_state:
        return False
    from_state = current.data[0].get("state")
    updated = client.table("document_artifacts").update({
        "state": to_state,
        "deleted_at": datetime.now(timezone.utc).isoformat() if to_state == "deleted" else None,
    }).eq("id", artifact_id).eq("state", from_state).select("id").execute()
    if not updated.data:
        # Another worker won the transition race. Do not emit a false audit
        # event for a state change that this worker did not make.
        return False
    client.table("artifact_lifecycle_events").insert({
        "artifact_id": artifact_id, "from_state": from_state,
        "to_state": to_state, "reason": reason, "actor": actor,
    }).execute()
    return True


def mark_expired(*, now: Optional[datetime] = None, actor: str = "retention_worker") -> int:
    """Mark due active artifacts as deleting; a worker deletes objects next."""
    client = _client()
    if client is None:
        return 0
    moment = (now or datetime.now(timezone.utc)).isoformat()
    rows = client.table("document_artifacts").select("id").eq("state", "active").not_.is_("retention_until", "null").lte("retention_until", moment).execute().data or []
    transitioned = 0
    for row in rows:
        transitioned += int(_transition(row["id"], "deleting", "retention_expired", actor))
    return transitioned


def mark_orphans(*, present_object_references: Sequence[str], actor: str = "orphan_scan") -> int:
    """Mark active inventory entries absent from a completed object listing."""
    client = _client()
    if client is None:
        return 0
    present = set(present_object_references)
    rows = client.table("document_artifacts").select("id,object_reference").eq("state", "active").execute().data or []
    missing = [row for row in rows if row.get("object_reference") not in present]
    transitioned = 0
    for row in missing:
        transitioned += int(_transition(row["id"], "orphaned", "missing_from_storage_listing", actor))
    return transitioned


def mark_deleted(artifact_id: str, *, actor: str = "storage_worker") -> None:
    _transition(artifact_id, "deleted", "object_deleted", actor)
