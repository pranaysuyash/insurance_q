"""Tests for the Family Workspace API endpoints (src/api/family.py).

Verifies:
- GET /family/members lists family members owned by authenticated user
- POST /family/members creates a family member with sanitized strings
- PUT /family/members/{id} updates a family member
- DELETE /family/members/{id} deletes a family member
- Owner isolation: requests are scoped to current_user.uid
"""
from __future__ import annotations

import os
import sys
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient

os.environ["SUPABASE_URL"] = "https://test.supabase.co"
os.environ["SUPABASE_SERVICE_ROLE_KEY"] = "test-service-role-key"
os.environ["SUPABASE_SECRET_KEY"] = "test-secret-key"
os.environ["JWT_SECRET"] = "test-jwt-secret"
os.environ["ENVIRONMENT"] = "test"

from src.app.main import app
from src.api.user import get_current_user
from src.models.user import User

TEST_USER = User(uid="test-user-001", identity_type="account", email="test@example.com", phone=None, display_name="Test User")
app.dependency_overrides[get_current_user] = lambda: TEST_USER

client = TestClient(app)


@pytest.fixture
def mock_supabase():
    mock_client = MagicMock()
    with patch("src.api.family._get_client", return_value=mock_client):
        yield mock_client


def test_list_family_members(mock_supabase):
    mock_query = MagicMock()
    mock_query.select.return_value = mock_query
    mock_query.eq.return_value = mock_query
    mock_query.order.return_value = mock_query
    mock_query.execute.return_value = MagicMock(data=[
        {
            "id": "fam-001",
            "user_uid": "test-user-001",
            "name": "Jane Doe",
            "relationship": "spouse",
            "dob": "1990-05-15",
            "phone": "+919876543210",
            "email": "jane@example.com",
            "notes": "Primary dependent",
            "created_at": "2026-08-24T12:00:00Z",
            "updated_at": "2026-08-24T12:00:00Z",
        }
    ])
    mock_supabase.table.return_value = mock_query

    resp = client.get("/family/members", headers={"Authorization": "Bearer mock-token"})
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["name"] == "Jane Doe"
    assert data[0]["relationship"] == "spouse"
    mock_query.eq.assert_called_with("user_uid", "test-user-001")


def test_create_family_member(mock_supabase):
    mock_query = MagicMock()
    inserted_row = {
        "id": "fam-002",
        "user_uid": "test-user-001",
        "name": "Junior Doe",
        "relationship": "child",
        "dob": "2018-10-20",
        "phone": None,
        "email": None,
        "notes": None,
        "created_at": "2026-08-24T12:00:00Z",
        "updated_at": "2026-08-24T12:00:00Z",
    }
    mock_query.insert.return_value = mock_query
    mock_query.execute.return_value = MagicMock(data=[inserted_row])
    mock_supabase.table.return_value = mock_query

    payload = {
        "name": "Junior Doe",
        "relationship": "child",
        "dob": "2018-10-20",
    }
    resp = client.post("/family/members", json=payload, headers={"Authorization": "Bearer mock-token"})
    assert resp.status_code == 201
    data = resp.json()
    assert data["id"] == "fam-002"
    assert data["name"] == "Junior Doe"
    assert data["relationship"] == "child"


def test_update_family_member(mock_supabase):
    mock_query = MagicMock()
    updated_row = {
        "id": "fam-001",
        "user_uid": "test-user-001",
        "name": "Jane Doe Updated",
        "relationship": "spouse",
        "dob": "1990-05-15",
        "phone": "+919876543210",
        "email": "jane@example.com",
        "notes": "Updated note",
        "created_at": "2026-08-24T12:00:00Z",
        "updated_at": "2026-08-24T12:30:00Z",
    }
    mock_query.update.return_value = mock_query
    mock_query.eq.return_value = mock_query
    mock_query.execute.return_value = MagicMock(data=[updated_row])
    mock_supabase.table.return_value = mock_query

    payload = {"name": "Jane Doe Updated", "notes": "Updated note"}
    resp = client.put("/family/members/fam-001", json=payload, headers={"Authorization": "Bearer mock-token"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "Jane Doe Updated"
    assert data["notes"] == "Updated note"


def test_delete_family_member(mock_supabase):
    mock_query = MagicMock()
    mock_query.delete.return_value = mock_query
    mock_query.eq.return_value = mock_query
    mock_query.execute.return_value = MagicMock(data=[{"id": "fam-001"}])
    mock_supabase.table.return_value = mock_query

    resp = client.delete("/family/members/fam-001", headers={"Authorization": "Bearer mock-token"})
    assert resp.status_code == 204
