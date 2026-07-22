from types import SimpleNamespace
from uuid import UUID, uuid4

import pytest

from src.services.qa_usage_service import QaUsageService, production_qa_usage_enabled


class _Client:
    def __init__(self, response):
        self.response = response
        self.calls = []

    def rpc(self, name, params):
        self.calls.append((name, params))
        return SimpleNamespace(execute=lambda: SimpleNamespace(data=self.response))


def test_q_and_a_reservation_passes_owner_and_idempotency_key():
    request_id = uuid4()
    client = _Client({"allowed": True, "source": "pack", "duplicate": False})

    result = QaUsageService(client).reserve(
        owner_id="owner-1", request_id=request_id
    )

    assert result["allowed"] is True
    assert client.calls == [
        (
            "reserve_qa_question",
            {"p_owner_id": "owner-1", "p_request_id": str(request_id)},
        )
    ]


def test_q_and_a_reservation_rejects_malformed_ledger_response():
    with pytest.raises(RuntimeError, match="no decision"):
        QaUsageService(_Client({})).reserve(owner_id="owner-1", request_id=uuid4())


def test_q_and_a_lifecycle_transitions_use_owner_and_request_id():
    request_id = uuid4()
    client = _Client({"status": "consumed"})
    service = QaUsageService(client)

    assert service.finalize(owner_id="owner-1", request_id=request_id)["status"] == "consumed"
    assert service.release(owner_id="owner-1", request_id=request_id)["status"] == "consumed"
    assert client.calls == [
        (
            "finalize_qa_question",
            {"p_owner_id": "owner-1", "p_request_id": str(request_id)},
        ),
        (
            "release_qa_question",
            {"p_owner_id": "owner-1", "p_request_id": str(request_id)},
        ),
    ]


def test_q_and_a_ledger_is_enabled_only_for_production_supabase_rag(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("RAG_VECTOR_BACKEND", "supabase")
    assert production_qa_usage_enabled() is True

    monkeypatch.setenv("RAG_VECTOR_BACKEND", "qdrant")
    assert production_qa_usage_enabled() is False
