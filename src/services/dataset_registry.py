"""Canonical consent-aware evaluation/training dataset registry."""

from __future__ import annotations

import os
import hashlib
import json
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import UUID

from src.utils.runtime_config import supabase_server_key


class DatasetRegistryError(Exception):
    """Dataset registry configuration or contract error."""


_PURPOSE_CONSENT_TYPE = {
    "evaluation": "evaluation_dataset",
    "benchmark": "evaluation_dataset",
    "training": "model_improvement",
}


class DatasetRegistry:
    def __init__(self, url: str, service_role_key: str, client: Optional[object] = None):
        if client is not None:
            self._client = client
            return
        if not url or not service_role_key:
            raise DatasetRegistryError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        try:
            from supabase import create_client
        except ImportError as error:  # pragma: no cover
            raise DatasetRegistryError("supabase package is required") from error
        self._client = create_client(url, service_role_key)

    @classmethod
    def from_env(cls) -> "DatasetRegistry":
        return cls(os.getenv("SUPABASE_URL", ""), supabase_server_key())

    async def create_release(
        self,
        name: str,
        version: str,
        purpose: str,
        created_by: str,
        consent_policy_version: Optional[str] = None,
    ) -> UUID:
        if purpose not in {"evaluation", "training", "benchmark"}:
            raise DatasetRegistryError("invalid dataset purpose")
        response = self._client.table("dataset_releases").insert({
            "name": name,
            "version": version,
            "purpose": purpose,
            "created_by": created_by,
            "consent_policy_version": consent_policy_version,
        }).execute()
        if not response.data:
            raise DatasetRegistryError("dataset release insert returned no row")
        return UUID(response.data[0]["id"])

    async def add_item(
        self,
        release_id: UUID,
        prompt: str,
        inclusion_basis: str,
        *,
        owner_id: Optional[str] = None,
        source_document_id: Optional[str] = None,
        source_chunk_id: Optional[int] = None,
        consent_record_id: Optional[str] = None,
        expected_answer: Optional[str] = None,
        expected_citations: Optional[list[Any]] = None,
        source_snapshot: Optional[dict[str, Any]] = None,
    ) -> UUID:
        if not prompt.strip() or not inclusion_basis.strip():
            raise DatasetRegistryError("prompt and inclusion_basis are required")
        if owner_id and not consent_record_id:
            raise DatasetRegistryError(
                "customer-derived dataset items require consent_record_id"
            )
        if source_document_id and (not owner_id or not consent_record_id):
            raise DatasetRegistryError(
                "source-document dataset items require owner_id and consent_record_id"
            )
        if source_chunk_id is not None and not source_document_id:
            raise DatasetRegistryError(
                "source_chunk_id requires source_document_id"
            )
        if source_document_id:
            source = (
                self._client.table("documents")
                .select("owner_id")
                .eq("id", source_document_id)
                .limit(1)
                .execute()
            )
            if not source.data or source.data[0].get("owner_id") != owner_id:
                raise DatasetRegistryError(
                    "source document is missing or owned by a different principal"
                )
        release = (
            self._client.table("dataset_releases")
            .select("status,purpose,consent_policy_version")
            .eq("id", str(release_id))
            .limit(1)
            .execute()
        )
        if not release.data:
            raise DatasetRegistryError("dataset release does not exist")
        release_header = release.data[0]
        if release_header["status"] != "draft":
            raise DatasetRegistryError("dataset items can only be added to draft releases")

        if owner_id:
            expected_consent_type = _PURPOSE_CONSENT_TYPE[release_header["purpose"]]
            consent_policy_version = release_header.get("consent_policy_version")
            if not consent_policy_version:
                raise DatasetRegistryError(
                    "customer-derived releases require consent_policy_version"
                )
            consent = (
                self._client.table("v_current_consent")
                .select("id,user_id,consent_type,granted,policy_version")
                .eq("user_id", owner_id)
                .eq("consent_type", expected_consent_type)
                .limit(1)
                .execute()
            )
            if (
                not consent.data
                or consent.data[0].get("id") != consent_record_id
                or consent.data[0].get("user_id") != owner_id
                or consent.data[0].get("consent_type") != expected_consent_type
                or consent.data[0].get("granted") is not True
                or consent.data[0].get("policy_version") != consent_policy_version
            ):
                raise DatasetRegistryError(
                    "current consent does not authorize this dataset purpose"
                )
        response = self._client.table("dataset_items").insert({
            "release_id": str(release_id),
            "owner_id": owner_id,
            "source_document_id": source_document_id,
            "source_chunk_id": source_chunk_id,
            "consent_record_id": consent_record_id,
            "prompt": prompt,
            "expected_answer": expected_answer,
            "expected_citations": expected_citations or [],
            "source_snapshot": source_snapshot or {},
            "inclusion_basis": inclusion_basis,
        }).execute()
        if not response.data:
            raise DatasetRegistryError("dataset item insert returned no row")
        return UUID(response.data[0]["id"])

    async def withdraw_item(self, item_id: UUID, reason: str) -> None:
        if not reason.strip():
            raise DatasetRegistryError("withdrawal reason is required")
        response = self._client.table("dataset_items").update({
            "status": "withdrawn",
            "withdrawn_at": datetime.now(timezone.utc).isoformat(),
            "withdrawn_reason": reason,
        }).eq("id", str(item_id)).eq("status", "active").select("id").execute()
        if not response.data:
            raise DatasetRegistryError("dataset item was not active or does not exist")

    async def approve_release(self, release_id: UUID) -> None:
        response = self._client.table("dataset_releases").update({
            "status": "approved",
            "approved_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", str(release_id)).eq("status", "draft").select("id").execute()
        if not response.data:
            raise DatasetRegistryError("dataset release was not draft or does not exist")

    async def materialize_manifest(self, release_id: UUID) -> dict[str, Any]:
        """Read an approved release into a stable, hashable execution manifest."""
        release = (
            self._client.table("dataset_releases")
            .select("id,name,version,purpose,status,manifest_hash")
            .eq("id", str(release_id)).limit(1).execute()
        )
        if not release.data or release.data[0]["status"] != "approved":
            raise DatasetRegistryError("only approved releases can be materialized")
        header = release.data[0]
        items = (
            self._client.table("dataset_items")
            .select("id,prompt,expected_answer,expected_citations,source_snapshot,source_document_id,source_chunk_id")
            .eq("release_id", str(release_id)).eq("status", "active")
            .order("id").execute().data or []
        )
        manifest = {"release": header, "items": items}
        encoded = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
        manifest["manifest_hash"] = hashlib.sha256(encoded).hexdigest()
        return manifest

    async def revoke_release(self, release_id: UUID, reason: str) -> None:
        if not reason.strip():
            raise DatasetRegistryError("revocation reason is required")
        response = self._client.table("dataset_releases").update({
            "status": "revoked",
            "revoked_at": datetime.now(timezone.utc).isoformat(),
            "revoked_reason": reason,
        }).eq("id", str(release_id)).in_("status", ["draft", "approved"]).select("id").execute()
        if not response.data:
            raise DatasetRegistryError("dataset release was already revoked or does not exist")

    async def withdraw_owner_items(self, owner_id: str, reason: str) -> int:
        if not owner_id or not reason.strip():
            raise DatasetRegistryError("owner_id and withdrawal reason are required")
        response = self._client.table("dataset_items").update({
            "status": "withdrawn",
            "withdrawn_at": datetime.now(timezone.utc).isoformat(),
            "withdrawn_reason": reason,
        }).eq("owner_id", owner_id).eq("status", "active").select("id").execute()
        return len(response.data or [])
