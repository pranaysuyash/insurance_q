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

    def order(self, *_args, **_kwargs):
        return self

    def execute(self):
        return SimpleNamespace(data=self.rows)


def test_auth_failure_marks_deletion_request_failed(monkeypatch):
    request_table = _Table([{
        "account_uid": "account-1",
        "status": "pending",
        "stage_state": {},
    }])
    documents_table = _Table(
        [{"id": "doc-1", "payload": {"file_path": "local://doc-1"}}]
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
    store = SimpleNamespace(delete=lambda _path: None)
    monkeypatch.setattr(lifecycle, "create_document_object_store", lambda: store)
    monkeypatch.setattr(
        "src.services.artifact_registry.delete_owner_artifacts",
        lambda _owner_id: {"attempted": 0, "deleted": 0},
    )

    with pytest.raises(RuntimeError, match="auth unavailable"):
        lifecycle.process_deletion("request-1", "account-1")

    assert request_table.updates[0]["status"] == "running"
    failed = request_table.updates[-1]
    assert failed["status"] == "failed"
    assert failed["last_error_class"] == "RuntimeError"
    assert failed["stage_state"]["documents"] == 1
    assert failed["stage_state"]["auth"] is False


def test_deletion_status_returns_safe_latest_projection(monkeypatch):
    request_table = _Table([{
        "id": "request-2",
        "account_uid": "account-1",
        "status": "running",
        "requested_at": "2026-07-21T10:00:00+00:00",
        "started_at": "2026-07-21T10:01:00+00:00",
        "completed_at": None,
        "updated_at": "2026-07-21T10:02:00+00:00",
        "stage_state": {"auth": False},
        "last_error_class": "RuntimeError",
    }])
    client = MagicMock()
    client.table.return_value = request_table
    monkeypatch.setattr(lifecycle, "_supabase", lambda: client)

    result = lifecycle.get_deletion_status("account-1")

    assert result == {
        "status": "running",
        "request_id": "request-2",
        "requested_at": "2026-07-21T10:00:00+00:00",
        "started_at": "2026-07-21T10:01:00+00:00",
        "completed_at": None,
        "updated_at": "2026-07-21T10:02:00+00:00",
    }
    assert "stage_state" not in result
    assert "last_error_class" not in result


def test_retry_uses_persisted_auth_checkpoint(monkeypatch):
    request_table = _Table([
        {
            "account_uid": "account-1",
            "status": "failed",
            "stage_state": {"auth": True, "documents": 1},
        },
    ])
    documents_table = _Table([])
    client = MagicMock()
    client.table.side_effect = lambda name: {
        "account_deletion_requests": request_table,
        "documents": documents_table,
        "document_chunks": _Table(),
        "dataset_items": _Table(),
    }[name]
    monkeypatch.setattr(lifecycle, "_supabase", lambda: client)
    monkeypatch.setattr(
        "src.services.artifact_registry.delete_owner_artifacts",
        lambda _owner_id: {"attempted": 0, "deleted": 0},
    )

    lifecycle.process_deletion("request-1", "account-1")

    client.auth.admin.delete_user.assert_not_called()
    assert request_table.updates[-1]["status"] == "completed"
    assert request_table.updates[-1]["stage_state"]["auth"] is True


def test_deletion_rejects_request_owner_mismatch(monkeypatch):
    request_table = _Table([{
        "account_uid": "account-owner",
        "status": "pending",
        "stage_state": {},
    }])
    client = MagicMock()
    client.table.return_value = request_table
    monkeypatch.setattr(lifecycle, "_supabase", lambda: client)

    with pytest.raises(PermissionError, match="owner mismatch"):
        lifecycle.process_deletion("request-1", "different-account")
