"""Server-side Q&A reservation adapter."""

from __future__ import annotations

import os
from typing import Any
from uuid import UUID

from src.utils.runtime_config import supabase_server_key


class QaUsageService:
    def __init__(self, client: Any):
        self._client = client

    @classmethod
    def from_env(cls) -> "QaUsageService":
        url = os.getenv("SUPABASE_URL", "").strip()
        key = supabase_server_key()
        if not url or not key:
            raise RuntimeError("Q&A usage ledger requires Supabase server credentials")
        from src.utils.supabase_client import create_client

        return cls(create_client(url, key))

    def reserve(self, *, owner_id: str, request_id: UUID) -> dict[str, Any]:
        response = self._client.rpc(
            "reserve_qa_question",
            {"p_owner_id": owner_id, "p_request_id": str(request_id)},
        ).execute()
        result = response.data
        if isinstance(result, list):
            result = result[0] if result else None
        if not isinstance(result, dict) or "allowed" not in result:
            raise RuntimeError("Q&A usage ledger returned no decision")
        return result

    def finalize(self, *, owner_id: str, request_id: UUID) -> dict[str, Any]:
        return self._transition(
            "finalize_qa_question", owner_id=owner_id, request_id=request_id
        )

    def release(self, *, owner_id: str, request_id: UUID) -> dict[str, Any]:
        return self._transition(
            "release_qa_question", owner_id=owner_id, request_id=request_id
        )

    def _transition(
        self, function_name: str, *, owner_id: str, request_id: UUID
    ) -> dict[str, Any]:
        response = self._client.rpc(
            function_name,
            {"p_owner_id": owner_id, "p_request_id": str(request_id)},
        ).execute()
        result = response.data
        if isinstance(result, list):
            result = result[0] if result else None
        if not isinstance(result, dict) or "status" not in result:
            raise RuntimeError(f"Q&A usage ledger {function_name} returned no status")
        return result


def production_qa_usage_enabled() -> bool:
    return (
        os.getenv("ENVIRONMENT", "development").lower() == "production"
        and os.getenv("RAG_VECTOR_BACKEND", "").lower() == "supabase"
    )
