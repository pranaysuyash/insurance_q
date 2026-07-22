"""Durable account export and erasure operations."""

from __future__ import annotations

import logging
import os
from datetime import datetime, timezone
from typing import Any

from src.services.document_object_store import create_document_object_store
from src.utils.runtime_config import supabase_server_key

log = logging.getLogger(__name__)


def _supabase():
    from supabase import create_client

    url = os.getenv("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if not url or not key:
        raise RuntimeError("Supabase service-role configuration is required")
    return create_client(url, key)


def create_deletion_request(account_uid: str) -> dict[str, Any]:
    client = _supabase()
    existing = (
        client.table("account_deletion_requests")
        .select("id,account_uid,status,stage_state,requested_at")
        .eq("account_uid", account_uid)
        .in_("status", ["pending", "running"])
        .limit(1)
        .execute()
    )
    if existing.data:
        return existing.data[0]
    try:
        response = (
            client.table("account_deletion_requests")
            .insert({"account_uid": account_uid, "status": "pending"})
            .execute()
        )
    except Exception:
        # A concurrent request may win the active-request unique index. Read
        # the winner and converge both API calls on the same request.
        concurrent = (
            client.table("account_deletion_requests")
            .select("id,account_uid,status,stage_state,requested_at")
            .eq("account_uid", account_uid)
            .in_("status", ["pending", "running"])
            .limit(1)
            .execute()
        )
        if concurrent.data:
            return concurrent.data[0]
        raise
    if not response.data:
        raise RuntimeError("Account deletion request was not persisted")
    return response.data[0]


def get_deletion_status(account_uid: str) -> dict[str, Any]:
    """Return the latest safe, user-facing deletion state for one owner.

    Internal stage checkpoints and error classes stay operator-only. The
    authenticated user needs lifecycle state and timestamps, not deletion
    internals or another account's records.
    """
    client = _supabase()
    response = (
        client.table("account_deletion_requests")
        .select("id,status,requested_at,started_at,completed_at,updated_at")
        .eq("account_uid", account_uid)
        .order("requested_at", desc=True)
        .limit(1)
        .execute()
    )
    if not response.data:
        return {"status": "none", "request_id": None}
    row = response.data[0]
    return {
        "status": row.get("status", "unknown"),
        "request_id": row.get("id"),
        "requested_at": row.get("requested_at"),
        "started_at": row.get("started_at"),
        "completed_at": row.get("completed_at"),
        "updated_at": row.get("updated_at"),
    }


def mark_deletion_failed(request_id: str, error_class: str) -> None:
    client = _supabase()
    client.table("account_deletion_requests").update({
        "status": "failed",
        "last_error_class": error_class[:120],
    }).eq("id", request_id).execute()


def process_deletion(request_id: str, account_uid: str) -> None:
    """Run idempotent erasure stages and only finish after auth deletion."""
    client = _supabase()
    request_lookup = (
        client.table("account_deletion_requests")
        .select("account_uid,status,stage_state")
        .eq("id", request_id)
        .limit(1)
        .execute()
    )
    if not request_lookup.data:
        raise RuntimeError("account deletion request was not found")
    request_row = request_lookup.data[0]
    if request_row.get("account_uid") != account_uid:
        raise PermissionError("account deletion request owner mismatch")

    prior_stage_state: dict[str, Any] = {}
    started = client.table("account_deletion_requests").update({
        "status": "running",
        "started_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", request_id).eq("account_uid", account_uid).eq("status", "pending").execute()
    if not started.data:
        current = (
            client.table("account_deletion_requests")
            .select("status,stage_state")
            .eq("id", request_id)
            .eq("account_uid", account_uid)
            .limit(1)
            .execute()
        )
        if current.data and current.data[0].get("status") == "completed":
            return
        if current.data and current.data[0].get("status") != "failed":
            raise RuntimeError("account deletion request is already being processed")
        if current.data:
            prior_stage_state = dict(current.data[0].get("stage_state") or {})
        client.table("account_deletion_requests").update({
            "status": "running",
            "started_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", request_id).eq("account_uid", account_uid).eq("status", "failed").execute()
    elif started.data:
        prior_stage_state = dict(started.data[0].get("stage_state") or {})
    stage_state: dict[str, Any] = {
        "storage": {"deleted": 0, "failed": 0},
        "documents": 0,
        "auth": False,
        **prior_stage_state,
    }
    # A failed attempt must not poison a retry's storage result. The durable
    # request retains the historical checkpoint, while this attempt records
    # only its own failures.
    stage_state["storage"] = {
        **dict(prior_stage_state.get("storage") or {}),
        "failed": 0,
    }
    try:
        client.table("dataset_items").update({
            "status": "withdrawn",
            "withdrawn_at": datetime.now(timezone.utc).isoformat(),
            "withdrawn_reason": "account_deletion",
        }).eq("owner_id", account_uid).eq("status", "active").execute()
        documents = client.table("documents").select("id,payload").eq("owner_id", account_uid).execute().data or []
        store = create_document_object_store()
        for row in documents:
            path = (row.get("payload") or {}).get("file_path")
            if not path or not path.startswith("supabase://"):
                continue
            try:
                store.delete(path)
                stage_state["storage"]["deleted"] += 1
            except Exception as error:
                stage_state["storage"]["failed"] += 1
                log.warning("account deletion storage stage failed: %s", type(error).__name__)
        if stage_state["storage"]["failed"]:
            raise RuntimeError("storage deletion stage failed")

        from src.services.artifact_registry import delete_owner_artifacts
        stage_state["artifacts"] = delete_owner_artifacts(account_uid)

        client.table("document_chunks").delete().eq("owner_id", account_uid).execute()
        deleted = client.table("documents").delete().eq("owner_id", account_uid).execute()
        stage_state["documents"] = len(deleted.data or [])
        if not stage_state.get("auth"):
            client.auth.admin.delete_user(account_uid)
            stage_state["auth"] = True
        client.table("account_deletion_requests").update({
            "status": "completed", "stage_state": stage_state,
            "completed_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", request_id).eq("account_uid", account_uid).execute()
    except Exception as error:
        # Never leave the durable request stuck in `running` when a stage
        # raises. The outbox may retry the same job, and the persisted stage
        # state gives operators an honest recovery record.
        client.table("account_deletion_requests").update({
            "status": "failed",
            "stage_state": stage_state,
            "last_error_class": type(error).__name__[:120],
        }).eq("id", request_id).eq("account_uid", account_uid).execute()
        raise
