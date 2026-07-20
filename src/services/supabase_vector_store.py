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
                for key in ("page", "section", "source", "filename", "bbox", "embedding_model", "parent_chunk_id")
                if block.get(key) is not None
            }
            content_text = block.get("retrieval_text", block.get("text", ""))
            metadata["text_content"] = content_text
            rows.append(
                {
                    "document_id": document_id,
                    "owner_id": owner_id or "",
                    "chunk_index": index,
                    "content": content_text,
                    "metadata": metadata,
                    "section_type": block.get("section_type", "general"),
                    "chunk_type": block.get("chunk_type", "paragraph"),
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

    async def search_fts(
        self,
        query_text: str,
        limit: int,
        filters: Optional[Dict[str, Any]],
    ) -> List[Any]:
        if not filters or not filters.get("owner_id"):
            raise ValueError("Supabase FTS search requires an owner_id filter")
        params = {
            "query_text": query_text,
            "match_owner_id": filters["owner_id"],
            "match_count": min(max(limit, 1), 50),
        }
        response = self._client.rpc("match_document_chunks_fts", params).execute()
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

    async def get_adjacent_chunks(self, chunk_ids: List[str], link_type: str = 'adjacent') -> List[Any]:
        if not chunk_ids:
            return []
            
        # Get target_chunk_ids from chunk_links
        links_res = (
            self._client.table("chunk_links")
            .select("source_chunk_id, target_chunk_id")
            .eq("link_type", link_type)
            .in_("source_chunk_id", chunk_ids)
            .execute()
        )
        
        target_ids = []
        for row in (links_res.data or []):
            tid = row.get("target_chunk_id")
            if tid and tid not in chunk_ids:
                target_ids.append(tid)
                
        target_ids = list(set(target_ids))
        if not target_ids:
            return []
            
        # Fetch the actual chunks
        chunks_res = (
            self._client.table("document_chunks")
            .select("id, content, metadata, section_type, document_id")
            .in_("id", target_ids)
            .execute()
        )
        
        adjacent_chunks = []
        for row in (chunks_res.data or []):
            metadata = dict(row.get("metadata") or {})
            metadata["document_id"] = row.get("document_id")
            metadata["text_content"] = row.get("content", "")
            metadata["section_type"] = row.get("section_type", "general")
            metadata["is_adjacent_context"] = True
            
            adjacent_chunks.append(
                SimpleNamespace(
                    id=str(row.get("id")),
                    payload=metadata,
                    score=0.0
                )
            )
            
        return adjacent_chunks
