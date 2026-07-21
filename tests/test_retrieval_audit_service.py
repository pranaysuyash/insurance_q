from src.services.retrieval_audit_service import stable_hash, write_audit


class _Execute:
    def __init__(self, data):
        self.data = data

    def execute(self):
        return self


class _Table:
    def __init__(self, data):
        self.data = data
        self.rows = []

    def insert(self, rows):
        self.rows.append(rows)
        return _Execute(self.data)


class _Client:
    def __init__(self):
        self.tables = {
            "retrieval_runs": _Table([{"id": "run-1"}]),
            "retrieval_candidates": _Table([]),
            "rag_answers": _Table([{"id": "answer-1"}]),
            "answer_evidence": _Table([]),
        }

    def table(self, name):
        return self.tables[name]


def test_audit_writes_hashes_and_identifiers_without_raw_query():
    client = _Client()
    write_audit(client, {
        "owner_id": "user-1",
        "query_hash": stable_hash("private question"),
        "query_length": 16,
        "retrieval_strategy": "supabase_hybrid_fts_pgvector",
        "top_k": 2,
        "candidates": [{"rank": 1, "chunk_id": 7, "document_id": "doc-1", "source_path": "hybrid", "score": 0.9}],
        "answer": {"text": "private answer", "llm_used": True, "confidence": 0.8,
                   "evidence": [{"citation_index": 1, "chunk_id": 7, "document_id": "doc-1",
                                 "page_number": 1, "citation_status": "verified", "quote": "private quote"}]},
    })
    assert client.tables["retrieval_runs"].rows[0]["query_hash"] == stable_hash("private question")
    assert "private question" not in str(client.tables["retrieval_runs"].rows)
    assert client.tables["rag_answers"].rows[0]["answer_hash"] == stable_hash("private answer")
    assert client.tables["answer_evidence"].rows[0][0]["quote_hash"] == stable_hash("private quote")
