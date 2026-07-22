import asyncio
from uuid import uuid4

from src.app import main
from src.models.user import User


class _Usage:
    def __init__(self, result):
        self.result = result
        self.calls = []

    def reserve(self, *, owner_id, request_id):
        self.calls.append((owner_id, request_id))
        return self.result

    def finalize(self, *, owner_id, request_id):
        self.calls.append(("finalize", owner_id, request_id))
        return {"status": "consumed"}

    def release(self, *, owner_id, request_id):
        self.calls.append(("release", owner_id, request_id))
        return {"status": "released"}


class _Processing:
    def __init__(self):
        self.calls = 0

    async def query_documents(self, **_kwargs):
        self.calls += 1
        return {"answer": "grounded", "sources": []}


def _user():
    return User(uid="owner-qa", email=None, phone=None, display_name=None)


def test_query_gate_blocks_without_calling_rag():
    old_usage = main.qa_usage_service
    old_processing = main.document_processing_service
    usage = _Usage({"allowed": False, "reason": "qa_budget_exhausted"})
    processing = _Processing()
    main.qa_usage_service = usage
    main.document_processing_service = processing
    try:
        response = asyncio.run(
            main.query_documents(
                main.QueryRequest(query="What is covered?", request_id=uuid4()),
                current_user=_user(),
            )
        )
    finally:
        main.qa_usage_service = old_usage
        main.document_processing_service = old_processing

    assert response.error == "qa_budget_exhausted"
    assert response.answer == ""
    assert processing.calls == 0
    assert usage.calls[0][0] == "owner-qa"


def test_query_gate_allows_and_passes_through_when_reserved():
    old_usage = main.qa_usage_service
    old_processing = main.document_processing_service
    usage = _Usage({"allowed": True, "source": "subscription"})
    processing = _Processing()
    main.qa_usage_service = usage
    main.document_processing_service = processing
    try:
        response = asyncio.run(
            main.query_documents(
                main.QueryRequest(query="What is covered?", request_id=uuid4()),
                current_user=_user(),
            )
        )
    finally:
        main.qa_usage_service = old_usage
        main.document_processing_service = old_processing

    assert response.answer == "grounded"
    assert processing.calls == 1
    assert usage.calls[1][0] == "finalize"


def test_query_gate_releases_usage_when_processing_is_unavailable():
    old_usage = main.qa_usage_service
    old_processing = main.document_processing_service
    usage = _Usage({"allowed": True, "source": "subscription"})
    main.qa_usage_service = usage
    main.document_processing_service = None
    try:
        response = asyncio.run(
            main.query_documents(
                main.QueryRequest(query="What is covered?", request_id=uuid4()),
                current_user=_user(),
            )
        )
    finally:
        main.qa_usage_service = old_usage
        main.document_processing_service = old_processing

    assert response.error == "Document processing service not initialized"
    assert usage.calls[1][0] == "release"
