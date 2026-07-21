"""Focused tests for durable account-erasure stage transitions."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from src.services import account_lifecycle_service as lifecycle


class _Table:
    def __init__(self, rows=None):
        self.rows = rows or []
        self.updates = []

    def select(self, _columns):
        return self

    def insert(self, _payload):
        return self

    def update(self, payload):
        self.updates.append(payload)
        return self

    def delete(self):
        return self

    def eq(self, *_args):
        return self

    def in_(self, *_args):
        return self

    def limit(self, *_args):
        return self

    def execute(self):
        return SimpleNamespace(data=self.rows)


def test_auth_failure_marks_deletion_request_failed(monkeypatch):
    request_table = _Table()
    documents_table = _Table(
        [{"id": "doc-1", "payload": {"file_path": "supabase://bucket/doc-1"}}]
    )
    chunks_table = _Table()
    deleted_documents_table = _Table([{"id": "doc-1"}])
    dataset_items_table = _Table()

    client = MagicMock()
    client.table.side_effect = lambda name: {
        "account_deletion_requests": request_table,
        "documents": documents_table,
        "document_chunks": chunks_table,
        "dataset_items": dataset_items_table,
    }[name]
    client.auth.admin.delete_user.side_effect = RuntimeError("auth unavailable")
    monkeypatch.setattr(lifecycle, "_supabase", lambda: client)

    # The same table object is used for the document select/delete calls in
    # this small fake; make its execute result switch after the select path.
    documents_table.execute = MagicMock(
        side_effect=[
            SimpleNamespace(data=documents_table.rows),
            SimpleNamespace(data=deleted_documents_table.rows),
        ]
    )
    store = MagicMock()
    monkeypatch.setattr(lifecycle, "create_document_object_store", lambda: store)
    monkeypatch.setattr(
        "src.services.artifact_registry.mark_owner_deleted",
        lambda _owner_id: {"marked": 0},
    )

    with pytest.raises(RuntimeError, match="auth unavailable"):
        lifecycle.process_deletion("request-1", "account-1")

    assert request_table.updates[0]["status"] == "running"
    failed = request_table.updates[-1]
    assert failed["status"] == "failed"
    assert failed["last_error_class"] == "RuntimeError"
    assert failed["stage_state"]["documents"] == 1
    assert failed["stage_state"]["auth"] is False
