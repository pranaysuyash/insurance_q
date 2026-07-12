"""Supabase pgvector adapter for the CoverWise retrieval boundary."""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any, Dict, List, Optional


class SupabaseVectorStore:
    """Persist and search chunks through the owner-scoped SQL RPC."""

    def __init__(self, url: str, service_role_key: str):
        try:
            from supabase import create_client
        except ImportError as error:  # pragma: no cover - deployment dependency
            raise RuntimeError("supabase is required for pgvector retrieval") from error
        if not url or not service_role_key:
            raise RuntimeError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
        self._client = create_client(url, service_role_key)

    @staticmethod
    def _vector_literal(values: List[float]) -> str:
        return "[" + ",".join(str(float(value)) for value in values) + "]"

    async def upsert(
        self,
        document_id: str,
        blocks: List[Dict[str, Any]],
        embeddings: List[List[float]],
        owner_id: Optional[str] = None,
    ) -> int:
        rows = []
        for index, (block, embedding) in enumerate(zip(blocks, embeddings)):
            metadata = {
                key: block.get(key)
                for key in ("page", "section", "source", "filename", "bbox", "embedding_model")
                if block.get(key) is not None
            }
            metadata["text_content"] = block["text"]
            rows.append(
                {
                    "document_id": document_id,
                    "owner_id": owner_id or "",
                    "chunk_index": index,
                    "content": block["text"],
                    "metadata": metadata,
                    "embedding": self._vector_literal(embedding),
                }
            )
        if rows:
            self._client.table("document_chunks").upsert(
                rows, on_conflict="document_id,chunk_index"
            ).execute()
        return len(rows)

    async def search(
        self,
        query_vector: List[float],
        limit: int,
        filters: Optional[Dict[str, Any]],
    ) -> List[Any]:
        if not filters or not filters.get("owner_id"):
            raise ValueError("Supabase vector search requires an owner_id filter")
        params = {
            "query_embedding": self._vector_literal(query_vector),
            "match_owner_id": filters["owner_id"],
            "match_count": min(max(limit, 1), 50),
            "match_threshold": 0.20,
        }
        response = self._client.rpc("match_document_chunks", params).execute()
        allowed_ids = set(filters.get("document_ids", []))
        hits = []
        for row in response.data or []:
            if allowed_ids and row.get("document_id") not in allowed_ids:
                continue
            metadata = dict(row.get("metadata") or {})
            metadata["document_id"] = row.get("document_id")
            metadata["text_content"] = row.get("content", "")
            hits.append(
                SimpleNamespace(
                    id=str(row.get("id")),
                    payload=metadata,
                    score=float(row.get("similarity", 0.0)),
                )
            )
        return hits

    async def delete(self, document_id: str, owner_id: str) -> int:
        response = (
            self._client.table("document_chunks")
            .delete()
            .eq("document_id", document_id)
            .eq("owner_id", owner_id)
            .execute()
        )
        return len(response.data or [])
