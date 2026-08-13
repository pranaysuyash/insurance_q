"""In-memory fake of the Supabase client surface used by ``SupabaseVectorStore``.

This lets the canonical **production** pgvector adapter
(``src/services/supabase_vector_store.py``) be exercised in CI without a real
Postgres + pgvector instance. It emulates the exact call shapes the adapter
makes:

  * ``client.table(name).upsert(rows, on_conflict=...).execute()``
  * ``client.table(name).select(...).eq(col, val).in_(col, vals).execute()``
  * ``client.table(name).delete().eq(...).eq(...).execute()``
  * ``client.rpc("match_document_chunks", params).execute()``        (dense / cosine)
  * ``client.rpc("match_document_chunks_fts", params).execute()``    (lexical)

Real pgvector semantics (exact cosine distance, FTS ranking) are approximated
closely enough to verify the adapter's wiring, RPC param construction, the
1536-dim / ``embedding_model`` contract guards, and owner/document scoping --
the parts that were previously never tested in CI (debt entry H-07 / E3).

A *true* end-to-end pgvector round-trip (the ``pgvector`` column type + the
``match_document_chunks`` SQL function) still requires a disposable
Postgres+pgvector instance (e.g. testcontainers) and is tracked separately.
"""

from __future__ import annotations

import json
import math
from types import SimpleNamespace
from typing import Any, Dict, List, Optional, Tuple


def _parse_embedding(value: Any) -> List[float]:
    if isinstance(value, (list, tuple)):
        return [float(x) for x in value]
    if isinstance(value, str):
        return [float(x) for x in json.loads(value)]
    raise ValueError("embedding must be a list or a literal string")


def _cosine(a: List[float], b: List[float]) -> float:
    if len(a) != len(b) or not a:
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0.0 or nb == 0.0:
        return 0.0
    return dot / (na * nb)


class _SelectBuilder:
    def __init__(self, client: "FakeSupabaseClient", table: str, cols: str = "*"):
        self._client = client
        self._table = table
        self._cols = cols
        self._filters: List[Tuple[str, str, Any]] = []

    def select(self, cols: str = "*"):  # noqa: D401 - chainable
        self._cols = cols
        return self

    def eq(self, col: str, val: Any):
        self._filters.append((col, "eq", val))
        return self

    def in_(self, col: str, vals: List[Any]):
        self._filters.append((col, "in", list(vals)))
        return self

    def execute(self) -> SimpleNamespace:
        rows = [
            r
            for r in self._client._tables.get(self._table, [])
            if all(self._match(r, op, col, val) for col, op, val in self._filters)
        ]
        return SimpleNamespace(data=rows)

    @staticmethod
    def _match(row: Dict[str, Any], op: str, col: str, val: Any) -> bool:
        if op == "eq":
            return row.get(col) == val
        if op == "in":
            return row.get(col) in val
        return True


class _UpsertBuilder:
    def __init__(self, client: "FakeSupabaseClient", table: str, rows: List[Dict[str, Any]], on_conflict: Optional[str]):
        self._client = client
        self._table = table
        self._rows = rows
        self._on_conflict = on_conflict

    def execute(self) -> SimpleNamespace:
        self._client._apply_upsert(self._table, self._rows, self._on_conflict)
        return SimpleNamespace(data=self._rows)


class _DeleteBuilder:
    def __init__(self, client: "FakeSupabaseClient", table: str):
        self._client = client
        self._table = table
        self._filters: List[Tuple[str, Any]] = []

    def eq(self, col: str, val: Any):
        self._filters.append((col, val))
        return self

    def execute(self) -> SimpleNamespace:
        deleted = self._client._apply_delete(self._table, self._filters)
        return SimpleNamespace(data=deleted)


class _RpcBuilder:
    def __init__(self, client: "FakeSupabaseClient", name: str, params: Dict[str, Any]):
        self._client = client
        self._name = name
        self._params = params

    def execute(self) -> SimpleNamespace:
        return self._client._run_rpc(self._name, self._params)


class _TableRouter:
    def __init__(self, client: "FakeSupabaseClient", name: str):
        self._client = client
        self._name = name

    def upsert(self, rows, on_conflict: Optional[str] = None):
        return _UpsertBuilder(self._client, self._name, list(rows), on_conflict)

    def select(self, cols: str = "*"):
        return _SelectBuilder(self._client, self._name, cols)

    def delete(self):
        return _DeleteBuilder(self._client, self._name)


class FakeSupabaseClient:
    """Minimal in-memory stand-in for a Supabase client."""

    def __init__(self) -> None:
        self._tables: Dict[str, List[Dict[str, Any]]] = {}
        self._counters: Dict[str, int] = {}
        self.rpc_calls: List[Tuple[str, Dict[str, Any]]] = []

    # -- public surface ----------------------------------------------------

    def table(self, name: str) -> _TableRouter:
        return _TableRouter(self, name)

    def rpc(self, name: str, params: Dict[str, Any]) -> _RpcBuilder:
        return _RpcBuilder(self, name, params)

    def _run_rpc(self, name: str, params: Dict[str, Any]) -> SimpleNamespace:
        self.rpc_calls.append((name, params))
        if name == "match_document_chunks":
            data = self._match_dense(params)
        elif name == "match_document_chunks_fts":
            data = self._match_fts(params)
        else:
            data = []
        return SimpleNamespace(data=data)

    # -- internal table ops -------------------------------------------------

    def _ensure_id(self, table: str, row: Dict[str, Any]) -> None:
        if not row.get("id"):
            self._counters[table] = self._counters.get(table, 0) + 1
            row["id"] = f"{table}-{self._counters[table]}"

    def _apply_upsert(self, table: str, rows: List[Dict[str, Any]], on_conflict: Optional[str]) -> None:
        store = self._tables.setdefault(table, [])
        if on_conflict:
            keys = [k.strip() for k in on_conflict.split(",")]
            for row in rows:
                self._ensure_id(table, row)
                key = tuple(row.get(k) for k in keys)
                idx = None
                for i, r in enumerate(store):
                    if tuple(r.get(k) for k in keys) == key:
                        idx = i
                        break
                if idx is not None:
                    store[idx] = row
                else:
                    store.append(row)
        else:
            for row in rows:
                self._ensure_id(table, row)
                store.append(row)

    def _apply_delete(self, table: str, filters: List[Tuple[str, Any]]) -> List[Dict[str, Any]]:
        store = self._tables.setdefault(table, [])
        removed = [
            r for r in store if all(r.get(col) == val for col, val in filters)
        ]
        self._tables[table] = [
            r for r in store if not all(r.get(col) == val for col, val in filters)
        ]
        return removed

    # -- RPC emulation ------------------------------------------------------

    def _match_dense(self, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        query = _parse_embedding(params["query_embedding"])
        owner = params.get("match_owner_id")
        model = params.get("match_embedding_model")
        version = params.get("match_embedding_version")
        threshold = float(params.get("match_threshold", 0.2))
        count = int(params.get("match_count", 10))
        doc_ids = params.get("match_document_ids") or None
        scored: List[Tuple[float, Dict[str, Any]]] = []
        for row in self._tables.get("document_chunks", []):
            if row.get("owner_id") != owner:
                continue
            if model and row.get("embedding_model") != model:
                continue
            if version and row.get("embedding_version") != version:
                continue
            if doc_ids and row.get("document_id") not in doc_ids:
                continue
            sim = _cosine(query, _parse_embedding(row.get("embedding")))
            if sim < threshold:
                continue
            scored.append((sim, row))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [
            {
                "id": row.get("id"),
                "document_id": row.get("document_id"),
                "content": row.get("content"),
                "metadata": row.get("metadata"),
                "similarity": sim,
            }
            for sim, row in scored[:count]
        ]

    def _match_fts(self, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        query = (params.get("query_text") or "").lower()
        owner = params.get("match_owner_id")
        count = int(params.get("match_count", 10))
        doc_ids = params.get("match_document_ids") or None
        scored: List[Tuple[int, Dict[str, Any]]] = []
        tokens = [t for t in query.replace(".", " ").split() if t]
        for row in self._tables.get("document_chunks", []):
            if row.get("owner_id") != owner:
                continue
            if doc_ids and row.get("document_id") not in doc_ids:
                continue
            content = (row.get("content") or "").lower()
            hits = sum(1 for t in tokens if t and t in content)
            if hits == 0:
                continue
            scored.append((hits, row))
        scored.sort(key=lambda x: x[0], reverse=True)
        return [
            {
                "id": row.get("id"),
                "document_id": row.get("document_id"),
                "content": row.get("content"),
                "metadata": row.get("metadata"),
                "similarity": hits,
            }
            for hits, row in scored[:count]
        ]
