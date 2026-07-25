"""Governed model-run and artifact lineage."""

from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import UUID

from src.utils.runtime_config import supabase_server_key


class ModelLineageError(Exception):
    pass


class ModelLineageService:
    def __init__(self, url: str, service_role_key: str, client: Optional[Any] = None):
        if client is not None:
            self._client = client
            return
        if not url or not service_role_key:
            raise ModelLineageError("Supabase service-role configuration is required")
        from src.utils.supabase_client import create_client
        self._client = create_client(url, service_role_key)

    @classmethod
    def from_env(cls) -> "ModelLineageService":
        return cls(os.getenv("SUPABASE_URL", ""), supabase_server_key())

    async def start_run(
        self,
        dataset_release_id: UUID,
        purpose: str,
        provider: str,
        model_name: str,
        config: dict[str, Any],
        created_by: str,
        model_version: Optional[str] = None,
    ) -> UUID:
        if purpose not in {"evaluation", "training", "benchmark"}:
            raise ModelLineageError("invalid model-run purpose")
        release = self._client.table("dataset_releases").select("status,purpose").eq(
            "id", str(dataset_release_id)
        ).limit(1).execute()
        if not release.data or release.data[0]["status"] != "approved":
            raise ModelLineageError("model runs require an approved dataset release")
        if release.data[0]["purpose"] != purpose:
            raise ModelLineageError("model-run purpose must match the dataset release purpose")
        config_hash = hashlib.sha256(
            json.dumps(config, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
        ).hexdigest()
        response = self._client.table("model_runs").insert({
            "dataset_release_id": str(dataset_release_id),
            "purpose": purpose,
            "provider": provider,
            "model_name": model_name,
            "model_version": model_version,
            "config_hash": config_hash,
            "created_by": created_by,
        }).execute()
        if not response.data:
            raise ModelLineageError("model run insert returned no row")
        return UUID(response.data[0]["id"])

    async def record_artifact(
        self,
        model_run_id: UUID,
        artifact_kind: str,
        object_reference: str,
        content: bytes,
        metrics: Optional[dict[str, Any]] = None,
    ) -> UUID:
        if artifact_kind not in {"checkpoint", "evaluation_report", "manifest", "log"}:
            raise ModelLineageError("invalid model artifact kind")
        response = self._client.table("model_artifacts").upsert({
            "model_run_id": str(model_run_id),
            "artifact_kind": artifact_kind,
            "object_reference": object_reference,
            "checksum_sha256": hashlib.sha256(content).hexdigest(),
            "byte_size": len(content),
            "metrics": metrics or {},
        }, on_conflict="model_run_id,object_reference").execute()
        if not response.data:
            raise ModelLineageError("model artifact insert returned no row")
        return UUID(response.data[0]["id"])

    async def finish_run(self, model_run_id: UUID, status: str, metrics: Optional[dict[str, Any]] = None) -> None:
        if status not in {"completed", "failed", "cancelled"}:
            raise ModelLineageError("invalid terminal model-run status")
        response = self._client.table("model_runs").update({
            "status": status,
            "metrics": metrics or {},
            "completed_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", str(model_run_id)).eq("status", "started").select("id").execute()
        if not response.data:
            raise ModelLineageError("model run was not started or does not exist")
