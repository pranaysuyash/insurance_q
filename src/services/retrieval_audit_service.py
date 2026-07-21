"""Write privacy-safe retrieval and answer lineage to Supabase."""

from __future__ import annotations

import hashlib
from typing import Any


def stable_hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def write_audit(client: Any, trace: dict[str, Any]) -> None:
    """Persist one trace and its bounded candidate/evidence records.

    The caller supplies only hashes and identifiers; this function never
    accepts or writes raw query, answer, quote, or source text.
    """
    run = client.table("retrieval_runs").insert({
        "owner_id": trace["owner_id"],
        "query_hash": trace["query_hash"],
        "query_length": trace["query_length"],
        "query_variant_count": trace.get("query_variant_count", 1),
        "retrieval_strategy": trace.get("retrieval_strategy") or "unknown",
        "top_k": min(max(int(trace.get("top_k", 1)), 1), 50),
        "embedding_model": trace.get("embedding_model"),
        "embedding_version": trace.get("embedding_version"),
        "reranker_model": trace.get("reranker_model"),
        "latency_ms": trace.get("latency_ms"),
        "cache_hit": bool(trace.get("cache_hit", False)),
        "failure_class": trace.get("failure_class"),
    }).execute()
    if not run.data:
        raise RuntimeError("retrieval run audit insert returned no row")
    run_id = run.data[0]["id"]

    candidates = trace.get("candidates") or []
    if candidates:
        client.table("retrieval_candidates").insert([
            {
                "run_id": run_id,
                "rank": int(row["rank"]),
                "chunk_id": row.get("chunk_id"),
                "document_id": row.get("document_id"),
                "source_path": row.get("source_path", "unknown"),
                "score": row.get("score"),
                "included": bool(row.get("included", True)),
            }
            for row in candidates[:50]
        ]).execute()

    answer = trace.get("answer")
    if answer is None:
        return
    answer_response = client.table("rag_answers").insert({
        "run_id": run_id,
        "owner_id": trace["owner_id"],
        "answer_hash": stable_hash(str(answer["text"])),
        "answer_length": len(str(answer["text"])),
        "llm_used": bool(answer.get("llm_used", False)),
        "llm_model": answer.get("llm_model"),
        "confidence": answer.get("confidence"),
        "missing_information_count": int(answer.get("missing_information_count", 0)),
    }).execute()
    if not answer_response.data:
        raise RuntimeError("answer audit insert returned no row")
    answer_id = answer_response.data[0]["id"]
    evidence = answer.get("evidence") or []
    if evidence:
        client.table("answer_evidence").insert([
            {
                "answer_id": answer_id,
                "citation_index": int(row["citation_index"]),
                "chunk_id": row.get("chunk_id"),
                "document_id": row.get("document_id"),
                "page_number": row.get("page_number"),
                "citation_status": row.get("citation_status", "rejected"),
                "quote_hash": stable_hash(str(row.get("quote", ""))),
            }
            for row in evidence[:50]
        ]).execute()
