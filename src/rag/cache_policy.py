"""Privacy policy for application-managed RAG response caching."""

from typing import Any, Mapping, Optional


def private_cache_scope(filters: Optional[Mapping[str, Any]]) -> bool:
    """Return whether a RAG response has an owner/document cache boundary."""
    filters = filters or {}
    return bool(filters.get("owner_id") or filters.get("document_id"))
