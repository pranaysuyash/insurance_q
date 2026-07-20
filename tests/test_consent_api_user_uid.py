"""Regression test for the consent API user identifier contract.

The User model exposes `uid`, not `id`. Using `current_user.id` in
src/api/consent.py raises AttributeError at runtime. This test pins
the contract: the route handler MUST use `current_user.uid`.

These tests call the route handlers directly to avoid the project's
current httpx/starlette TestClient version mismatch.
"""

import os
import sys
from unittest.mock import AsyncMock, MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.models.user import User  # noqa: E402


class _StubUser(User):
    def __init__(self, uid: str = "user-1"):
        super().__init__(
            uid=uid,
            email="test@example.com",
            phone="+15555555555",
            display_name="Test User",
        )


@pytest.fixture
def stub_service(monkeypatch):
    """Stub the consent service so the route handler does not need
    a real Supabase project."""
    from src.api import consent as consent_module

    service = MagicMock()
    service.record_consent = AsyncMock(return_value="record-id")
    service.get_current_consent_all = AsyncMock(return_value=[])
    service.get_history = AsyncMock(return_value=[])
    monkeypatch.setattr(consent_module, "_get_service", lambda: service)
    return service


@pytest.fixture
def stub_user():
    return _StubUser(uid="user-1")


@pytest.fixture
def stub_request():
    """Minimal ASGI-like request stub with the attributes the route uses."""
    request = MagicMock()
    request.client.host = "127.0.0.1"
    request.headers = {}
    return request


@pytest.mark.asyncio
async def test_record_consent_uses_current_user_uid(
    stub_service, stub_user, stub_request
):
    from src.api.consent import record_consent
    from src.models.consent import RecordConsentRequest

    request_body = RecordConsentRequest(
        consent_type="analytics",
        granted=True,
        policy_version="v1",
    )
    response = await record_consent(
        request_body=request_body,
        request=stub_request,
        current_user=stub_user,
    )
    assert response["id"] == "record-id"
    stub_service.record_consent.assert_awaited_once()
    call_kwargs = stub_service.record_consent.await_args.kwargs
    assert call_kwargs["user_id"] == "user-1"


@pytest.mark.asyncio
async def test_get_current_consent_uses_current_user_uid(
    stub_service, stub_user
):
    from src.api.consent import get_current_consent_all

    response = await get_current_consent_all(current_user=stub_user)
    assert response == []
    stub_service.get_current_consent_all.assert_awaited_once_with("user-1")


@pytest.mark.asyncio
async def test_get_consent_history_uses_current_user_uid(
    stub_service, stub_user
):
    from src.api.consent import get_consent_history

    response = await get_consent_history(current_user=stub_user, limit=100)
    assert response == []
    stub_service.get_history.assert_awaited_once_with("user-1", limit=100)
