"""Regression test for the evidence API owner-check contract.

The User model exposes `uid`, not `id`. Using `current_user.id`
in src/api/evidence.py would raise AttributeError at runtime.
This test pins the contract: the route handler MUST use
`current_user.uid`, not `current_user.id`.

The test uses TestClient against a minimal FastAPI app that
includes only the evidence router. The DocumentRepository is
mocked; the test only cares that the route handler calls the
repo with the right user identifier.
"""

import os
import sys
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.models.user import User  # noqa: E402


# Stub the auth dependency BEFORE importing the route module.
from src.api import user as user_api  # noqa: E402


class _StubUser(User):
    """A User with no extra fields; the real User accepts
    arbitrary kwargs. The auth dependency returns a real User."""

    def __init__(self, uid: str = "user-1"):
        super().__init__(
            uid=uid,
            email="test@example.com",
            phone="+15555555555",
            display_name="Test User",
        )


@pytest.fixture
def stub_current_user(monkeypatch):
    """Stub src.api.user.get_current_user to return a User
    with uid='user-1' (the test owner)."""
    user = _StubUser(uid="user-1")
    monkeypatch.setattr(user_api, "get_current_user", lambda: user)
    return user


@pytest.fixture
def stub_substrate(monkeypatch):
    """Stub the substrate construction so the route handler
    does not need a real Supabase project."""
    from src.api import evidence as evidence_module

    service = MagicMock()
    service.get_field_citations = AsyncMock(return_value=[])
    monkeypatch.setattr(
        evidence_module, "_get_substrate", lambda: service
    )
    return service


@pytest.fixture
def stub_repo(monkeypatch):
    """Stub the DocumentRepository. The test controls what
    `repo.get(document_id, owner_id)` returns."""
    from src.services import document_repository as dr_module

    repo = MagicMock()
    monkeypatch.setattr(
        dr_module, "create_document_repository", lambda: repo
    )
    return repo


def test_evidence_route_uses_current_user_uid_not_id(
    stub_current_user, stub_substrate, stub_repo
):
    """The evidence route's owner check must use current_user.uid.
    If the route is ever changed to current_user.id, the
    DocumentRepository would receive a wrong owner_id and the
    document lookup would fail. This test asserts the
    DocumentRepository is called with the right owner_id."""
    import uuid
    from src.api import evidence as evidence_api

    doc_id = str(uuid.uuid4())
    # Set up the stub: the document exists for owner 'user-1'.
    stub_repo.get.return_value = MagicMock(id=doc_id)

    # Build a minimal app with only the evidence router.
    app = FastAPI()
    app.include_router(evidence_api.router)

    with TestClient(app) as client:
        response = client.get(
            f"/evidence/{doc_id}/field-citations",
            headers={"Authorization": "Bearer stub-token"},
        )

    # The route handler must have called repo.get with
    # (doc_id, 'user-1'). If the route used current_user.id
    # (which does not exist on the User model), the call
    # would have raised AttributeError, which the try/except
    # would translate to a 503 — and this assertion would
    # still see the right call. The right thing to assert is
    # the call signature.
    assert stub_repo.get.called
    call_args = stub_repo.get.call_args
    # The call is repo.get(document_id, owner_id) — positional.
    assert call_args[0][0] == doc_id
    assert call_args[0][1] == "user-1", (
        f"evidence route must use current_user.uid; got {call_args[0][1]!r}. "
        "The User model has no `id` attribute; using current_user.id "
        "would raise AttributeError at runtime."
    )
    # The route returned 200 (or at least did not 503).
    assert response.status_code == 200, (
        f"expected 200; got {response.status_code} {response.text}"
    )


def test_evidence_route_returns_404_when_document_not_found(
    stub_current_user, stub_substrate, stub_repo
):
    """The route returns 404 when the document does not exist for
    the current user. The owner check is the gate."""
    import uuid
    from src.api import evidence as evidence_api

    doc_id = str(uuid.uuid4())
    stub_repo.get.return_value = None  # document not found

    app = FastAPI()
    app.include_router(evidence_api.router)

    with TestClient(app) as client:
        response = client.get(
            f"/evidence/{doc_id}/field-citations",
            headers={"Authorization": "Bearer stub-token"},
        )
    assert response.status_code == 404
