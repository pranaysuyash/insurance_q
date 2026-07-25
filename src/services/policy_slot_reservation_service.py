"""Production policy-slot reservation adapter.

The reservation RPC is the concurrency boundary for policy entitlement. The
API calls it only when the Supabase production document path is active; local
development keeps its existing compatibility behavior and must not pretend to
have remote reservation evidence.
"""

from __future__ import annotations

import os
from typing import Any

from src.utils.runtime_config import supabase_server_key


class PolicySlotReservationService:
    def __init__(self, client: Any):
        self._client = client

    @classmethod
    def from_env(cls) -> "PolicySlotReservationService":
        url = os.getenv("SUPABASE_URL", "").strip()
        key = supabase_server_key()
        if not url or not key:
            raise RuntimeError("Policy-slot reservation requires Supabase server credentials")
        from src.utils.supabase_client import create_client

        return cls(create_client(url, key))

    def reserve(self, *, owner_id: str, source_hash: str) -> dict[str, Any]:
        response = self._client.rpc(
            "reserve_policy_upload_slot",
            {"p_owner_id": owner_id, "p_source_hash": source_hash},
        ).execute()
        result = response.data
        if isinstance(result, list):
            result = result[0] if result else None
        if not isinstance(result, dict) or "allowed" not in result:
            raise RuntimeError("Policy-slot reservation returned no decision")
        return result

    def finalize(self, *, reservation_id: str, owner_id: str, document_id: str) -> None:
        response = self._client.rpc(
            "finalize_policy_upload_slot",
            {
                "p_reservation_id": reservation_id,
                "p_owner_id": owner_id,
                "p_document_id": document_id,
            },
        ).execute()
        if response.data is not True and response.data != [True]:
            raise RuntimeError("Policy-slot reservation was not finalized")

    def release(self, *, reservation_id: str, owner_id: str) -> None:
        response = self._client.rpc(
            "release_policy_upload_slot",
            {"p_reservation_id": reservation_id, "p_owner_id": owner_id},
        ).execute()
        if response.data is not True and response.data != [True]:
            raise RuntimeError("Policy-slot reservation was not released")


def production_policy_slot_reservations_enabled() -> bool:
    return (
        os.getenv("ENVIRONMENT", "development").lower() == "production"
        and os.getenv("DOCUMENT_REPOSITORY_BACKEND", "").lower() == "supabase"
    )
