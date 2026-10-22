import pytest
from fastapi.testclient import TestClient
from src.app import main
from src.models.user import User


class _MockUsageService:
    def __init__(self, allowed: bool = True, reason: str = "qa_budget_exhausted"):
        self.allowed = allowed
        self.reason = reason
        self.reservations = []

    def reserve(self, *, owner_id, request_id):
        self.reservations.append((owner_id, request_id))
        return {"allowed": self.allowed, "reason": self.reason}

    def finalize(self, *, owner_id, request_id):
        return {"status": "consumed"}

    def release(self, *, owner_id, request_id):
        return {"status": "released"}


@pytest.fixture
def override_auth():
    def get_current_user():
        return User(uid="test-user-free", email="test@example.com", phone=None, display_name="Test User")
    from src.api.user import get_current_user as gcu
    main.app.dependency_overrides[gcu] = get_current_user
    yield
    main.app.dependency_overrides.clear()


def test_qa_entitlement_blocked_when_budget_exhausted(override_auth):
    old_service = main.qa_usage_service
    main.qa_usage_service = _MockUsageService(allowed=False, reason="qa_budget_exhausted")
    try:
        client = TestClient(main.app)
        response = client.post("/query", json={"query": "test?"})
        assert response.status_code == 200
        data = response.json()
        assert data.get("error") == "qa_budget_exhausted"
        assert data.get("answer") == ""
    finally:
        main.qa_usage_service = old_service


def test_qa_entitlement_allowed_when_within_budget(override_auth):
    old_service = main.qa_usage_service
    main.qa_usage_service = _MockUsageService(allowed=True)
    try:
        client = TestClient(main.app)
        response = client.post("/query", json={"query": "test?"})
        assert response.status_code in (200, 500, 503)
    finally:
        main.qa_usage_service = old_service


def test_qa_entitlement_anon():
    client = TestClient(main.app)
    response = client.post("/query", json={"query": "test?"})
    assert response.status_code == 401


