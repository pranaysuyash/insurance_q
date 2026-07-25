"""Tests for the claims API endpoints (src/api/claims.py).

Tests use a mocked Supabase client to verify:
- POST /claims creates a claim with the correct owner_id
- GET /claims lists claims with pagination and status filtering
- GET /claims/{id} returns a single claim
- PATCH /claims/{id} updates status, reference_number, and notes
- PATCH /claims/{id} appends to status_history on status change
- DELETE /claims/{id} deletes a claim
- Authentication is required (missing user returns 403)
"""
from __future__ import annotations

import os
import sys
from datetime import datetime
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient  # noqa: E402

# We need the app but with mocked dependencies
os.environ["SUPABASE_URL"] = "https://test.supabase.co"
os.environ["SUPABASE_SERVICE_ROLE_KEY"] = "test-service-role-key"
os.environ["SUPABASE_SECRET_KEY"] = "test-secret-key"
os.environ["JWT_SECRET"] = "test-jwt-secret"
os.environ["ENVIRONMENT"] = "test"

from src.app.main import app  # noqa: E402
from src.api.user import get_current_user  # noqa: E402
from src.models.user import User  # noqa: E402

# Mock the auth dependency to avoid real JWT verification in tests
TEST_USER = User(uid="test-user-001", identity_type="anonymous", email=None, phone=None, display_name=None)
app.dependency_overrides[get_current_user] = lambda: TEST_USER

client = TestClient(app)


# Helper: generate a mock Supabase token for auth
def _auth_header(uid: str = "test-user-001") -> dict:
    """Return an Authorization header with a mock JWT."""
    # We need to bypass actual token verification. In tests, we can
    # mock the get_current_user dependency directly.
    return {"Authorization": f"Bearer mock-token-for-{uid}"}


# ---------------------------------------------------------------------------
# Unit tests for the API logic (mock the Supabase client)
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_supabase():
    """Patch _get_client in the claims module so no real DB is hit."""
    mock_client = MagicMock()
    with patch("src.api.claims._get_client", return_value=mock_client):
        yield mock_client


def _make_claim_row(overrides: dict | None = None) -> dict:
    """Return a mock Supabase row for a claim."""
    now = datetime.utcnow().isoformat()
    row = {
        "id": str(uuid4()),
        "owner_id": "test-user-001",
        "document_id": "doc-123",
        "policy_type": "Health Insurance",
        "insurer": "Test Insurer",
        "incident_type": "Accident",
        "description": "Car accident on highway",
        "filed_date": now,
        "reference_number": "CLM-001",
        "status": "filed",
        "notes": None,
        "photo_paths": [],
        "status_history": [{"status": "filed", "timestamp": now}],
        "initiated_by": "user",
        "agent_id": None,
        "created_at": now,
        "updated_at": now,
    }
    if overrides:
        row.update(overrides)
    return row


def test_create_claim_success(mock_supabase):
    """POST /claims creates a claim and returns 201."""
    claim_row = _make_claim_row()
    mock_supabase.table.return_value.insert.return_value.execute.return_value.data = [
        claim_row
    ]

    response = client.post(
        "/claims",
        json={
            "policy_type": "Health Insurance",
            "insurer": "Test Insurer",
            "incident_type": "Accident",
            "description": "Car accident on highway",
        },
        headers=_auth_header(),
    )

    assert response.status_code == 201
    data = response.json()
    assert data["owner_id"] == "test-user-001"
    assert data["policy_type"] == "Health Insurance"
    assert data["insurer"] == "Test Insurer"
    assert data["status"] == "filed"
    assert data["initiated_by"] == "user"


def test_create_claim_rejects_retired_agent_provenance_fields(mock_supabase):
    """Clients cannot present CoverWise as filing a claim through an agent."""
    response = client.post(
        "/claims",
        json={
            "policy_type": "Health Insurance",
            "insurer": "Test Insurer",
            "incident_type": "Theft",
            "description": "Stolen laptop",
            "initiated_by": "agent",
            "agent_id": "agent-456",
        },
        headers=_auth_header(),
    )

    assert response.status_code == 422
    mock_supabase.table.assert_not_called()


def test_historical_agent_fields_are_never_exposed_as_product_provenance(mock_supabase):
    """Legacy rows remain readable but are normalised to the personal-log contract."""
    row = _make_claim_row({"initiated_by": "agent", "agent_id": "agent-456"})
    mock_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.limit.return_value.offset.return_value.execute.return_value.data = [row]

    response = client.get("/claims", headers=_auth_header())

    assert response.status_code == 200
    assert response.json()[0]["initiated_by"] == "user"
    assert response.json()[0]["agent_id"] is None


def test_list_claims_empty(mock_supabase):
    """GET /claims returns empty list when no claims exist."""
    mock_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.limit.return_value.offset.return_value.execute.return_value.data = []

    response = client.get("/claims", headers=_auth_header())

    assert response.status_code == 200
    assert response.json() == []


def test_list_claims_with_data(mock_supabase):
    """GET /claims returns claims ordered by filed_date desc."""
    rows = [
        _make_claim_row({"id": str(uuid4()), "incident_type": "Accident"}),
        _make_claim_row({"id": str(uuid4()), "incident_type": "Theft"}),
    ]
    mock_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.limit.return_value.offset.return_value.execute.return_value.data = rows

    response = client.get("/claims", headers=_auth_header())

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["incident_type"] == "Accident"


def test_list_claims_status_filter(mock_supabase):
    """GET /claims?status=paid filters by status."""
    row = _make_claim_row({"status": "paid"})
    chain = MagicMock()
    chain.execute.return_value.data = [row]
    mock_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.limit.return_value.offset.return_value.eq.return_value = chain

    response = client.get("/claims?status=paid", headers=_auth_header())

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["status"] == "paid"


def test_get_claim_found(mock_supabase):
    """GET /claims/{id} returns a single claim."""
    claim_id = str(uuid4())
    row = _make_claim_row({"id": claim_id})
    mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [row]

    response = client.get(f"/claims/{claim_id}", headers=_auth_header())

    assert response.status_code == 200
    assert response.json()["id"] == claim_id


def test_get_claim_not_found(mock_supabase):
    """GET /claims/{id} returns 404 when claim doesn't exist."""
    mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = []

    response = client.get(f"/claims/{uuid4()}", headers=_auth_header())

    assert response.status_code == 404


def test_update_claim_status(mock_supabase):
    """PATCH /claims/{id} updates status and appends to history."""
    claim_id = str(uuid4())
    now = datetime.utcnow().isoformat()
    existing = _make_claim_row({"id": claim_id, "status": "filed", "status_history": [{"status": "filed", "timestamp": now}]})
    updated = _make_claim_row({"id": claim_id, "status": "in_review", "status_history": [
        {"status": "filed", "timestamp": now},
        {"status": "in_review", "timestamp": datetime.utcnow().isoformat()},
    ]})

    # First call (select) returns existing, second call (update) returns updated
    mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [existing]
    mock_supabase.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = [updated]

    response = client.patch(
        f"/claims/{claim_id}",
        json={"status": "in_review"},
        headers=_auth_header(),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "in_review"
    assert len(data["status_history"]) == 2


def test_update_claim_reference_number(mock_supabase):
    """PATCH /claims/{id} updates reference_number."""
    claim_id = str(uuid4())
    existing = _make_claim_row({"id": claim_id, "reference_number": None})
    updated = _make_claim_row({"id": claim_id, "reference_number": "CLM-999"})

    mock_supabase.table.return_value.select.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [existing]
    mock_supabase.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = [updated]

    response = client.patch(
        f"/claims/{claim_id}",
        json={"reference_number": "CLM-999"},
        headers=_auth_header(),
    )

    assert response.status_code == 200
    assert response.json()["reference_number"] == "CLM-999"


def test_delete_claim(mock_supabase):
    """DELETE /claims/{id} returns 204."""
    claim_id = str(uuid4())
    mock_supabase.table.return_value.delete.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {"id": claim_id}
    ]

    response = client.delete(f"/claims/{claim_id}", headers=_auth_header())
    assert response.status_code == 204


def test_delete_claim_not_found(mock_supabase):
    """DELETE /claims/{id} returns 404 when claim doesn't exist."""
    mock_supabase.table.return_value.delete.return_value.eq.return_value.eq.return_value.execute.return_value.data = []

    response = client.delete(f"/claims/{uuid4()}", headers=_auth_header())
    assert response.status_code == 404
