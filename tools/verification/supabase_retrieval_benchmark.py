#!/usr/bin/env python3
"""Run a safe local Supabase retrieval contract benchmark.

This is deliberately local-only by default. It exercises owner/document
isolation, exact FTS retrieval, pgvector retrieval, and cleanup. A staging or
production URL requires SUPABASE_BENCHMARK_ALLOW_EXTERNAL=1.
"""

from __future__ import annotations

import json
import os
import socket
import time
import uuid
from pathlib import Path

from supabase import create_client


def _vector(index: int, size: int = 1536) -> str:
    values = [0.0] * size
    values[index] = 1.0
    return "[" + ",".join(str(value) for value in values) + "]"


def main() -> int:
    url = os.environ.get("SUPABASE_URL", "http://127.0.0.1:54321").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not key:
        raise SystemExit("SUPABASE_SERVICE_ROLE_KEY is required")
    host = socket.gethostbyname(url.split("//", 1)[-1].split("/", 1)[0].split(":", 1)[0])
    if host not in {"127.0.0.1", "::1"} and os.environ.get("SUPABASE_BENCHMARK_ALLOW_EXTERNAL") != "1":
        raise SystemExit("Refusing non-local Supabase URL without SUPABASE_BENCHMARK_ALLOW_EXTERNAL=1")

    client = create_client(url, key)
    owner = f"benchmark:{uuid.uuid4()}"
    other_owner = f"benchmark-other:{uuid.uuid4()}"
    document_id = str(uuid.uuid4())
    other_document_id = str(uuid.uuid4())
    source_rows = [
        (document_id, owner, 0, "Room rent is limited to one percent of the sum insured.", _vector(0)),
        (document_id, owner, 1, "The waiting period for maternity benefits is twenty-four months.", _vector(1)),
        (other_document_id, other_owner, 0, "Room rent is unlimited for the other owner.", _vector(0)),
    ]
    started = time.perf_counter()
    try:
        client.table("documents").insert([
            {"id": document_id, "owner_id": owner, "source_hash": str(uuid.uuid4()),
             "payload": {"user_uid": owner, "filename": "benchmark.pdf"},
             "object_reference": f"benchmark://{document_id}"},
            {"id": other_document_id, "owner_id": other_owner, "source_hash": str(uuid.uuid4()),
             "payload": {"user_uid": other_owner, "filename": "other.pdf"},
             "object_reference": f"benchmark://{other_document_id}"},
        ]).execute()
        client.table("document_chunks").insert([
            {"document_id": doc, "owner_id": row_owner, "chunk_index": chunk_index,
             "content": text, "source_text": text, "retrieval_text": text,
             "metadata": {"benchmark": True}, "embedding": vector,
             "embedding_model": "text-embedding-3-small", "embedding_dimensions": 1536,
             "embedding_version": "v1"}
            for doc, row_owner, chunk_index, text, vector in source_rows
        ]).execute()

        fts_started = time.perf_counter()
        fts = client.rpc("match_document_chunks_fts", {
            "query_text": "maternity twenty-four months",
            "match_owner_id": owner,
            "match_count": 10,
            "similarity_threshold": 0.0,
            "match_document_ids": [document_id],
        }).execute().data or []
        dense_started = time.perf_counter()
        dense = client.rpc("match_document_chunks", {
            "query_embedding": _vector(1),
            "match_owner_id": owner,
            "match_count": 10,
            "match_threshold": 0.2,
            "match_document_ids": [document_id],
            "match_embedding_model": "text-embedding-3-small",
            "match_embedding_version": "v1",
        }).execute().data or []
        result = {
            "benchmark": "supabase_retrieval_contract_v1",
            "owner_isolation": all(row.get("document_id") == document_id for row in fts + dense),
            "fts_hits": len(fts),
            "dense_hits": len(dense),
            "fts_top_document": fts[0].get("document_id") if fts else None,
            "dense_top_document": dense[0].get("document_id") if dense else None,
            "fts_latency_ms": round((dense_started - fts_started) * 1000, 3),
            "dense_latency_ms": round((time.perf_counter() - dense_started) * 1000, 3),
            "total_latency_ms": round((time.perf_counter() - started) * 1000, 3),
        }
        if not result["owner_isolation"] or not fts or not dense:
            raise RuntimeError(json.dumps(result))
        output = Path(os.environ.get("BENCHMARK_OUTPUT", "docs/review/evidence/supabase-retrieval-benchmark-local.json"))
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, indent=2))
        return 0
    finally:
        client.table("document_chunks").delete().eq("owner_id", owner).execute()
        client.table("document_chunks").delete().eq("owner_id", other_owner).execute()
        client.table("documents").delete().eq("owner_id", owner).execute()
        client.table("documents").delete().eq("owner_id", other_owner).execute()


if __name__ == "__main__":
    raise SystemExit(main())
