"""Canonical consent-aware evaluation/training dataset registry."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Optional
from uuid import UUID


class DatasetRegistryError(Exception):
    """Dataset registry configuration or contract error."""


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
        return cls(os.getenv("SUPABASE_URL", ""), os.getenv("SUPABASE_SERVICE_ROLE_KEY", ""))

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
        release = (
            self._client.table("dataset_releases")
            .select("status,purpose")
            .eq("id", str(release_id))
            .limit(1)
            .execute()
        )
        if not release.data:
            raise DatasetRegistryError("dataset release does not exist")
        if release.data[0]["status"] != "draft":
            raise DatasetRegistryError("dataset items can only be added to draft releases")
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
