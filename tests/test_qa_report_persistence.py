import pytest
from fastapi.testclient import TestClient
from src.app.main import app
from src.models.user import User

@pytest.fixture
def override_user():
    def get_user():
        return User(uid="test-user-001", email="user@example.com", phone=None, display_name="Test User")
    from src.api.user import get_current_user
    app.dependency_overrides[get_current_user] = get_user
    yield
    app.dependency_overrides.clear()

def test_qa_report_submits_and_inserts_db(override_user, mocker):
    mock_client = mocker.MagicMock()
    mocker.patch("src.api.report_router._get_supabase_client", return_value=mock_client)
    
    client = TestClient(app)
    payload = {
        "question": "Does this cover dental?",
        "answer_text": "Yes, comprehensive dental is covered up to Rs 50,000.",
        "category": "incorrect",
        "comments": "My policy says dental is excluded."
    }
    response = client.post("/qa/report", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "registered"
    assert data["report_id"].startswith("rpt-")
    
    # Assert DB insert called
    mock_client.table().insert.assert_called_once()
    record = mock_client.table().insert.call_args[0][0]
    assert record["question"] == payload["question"]
    assert record["category"] == "incorrect"
    assert record["user_id"] == "test-user-001"

def test_qa_report_fallback_when_db_none(override_user, mocker):
    mocker.patch("src.api.report_router._get_supabase_client", return_value=None)
    client = TestClient(app)
    payload = {
        "question": "What is the waiting period?",
        "answer_text": "0 days",
        "category": "incorrect"
    }
    response = client.post("/qa/report", json=payload)
    assert response.status_code == 201
    assert response.json()["status"] == "registered"

def test_qa_reports_admin_endpoint(mocker):
    # Non-admin gets 403
    def get_user():
        return User(uid="normal-user", email="user@example.com", phone=None, display_name="Normal User")
    from src.api.user import get_current_user
    app.dependency_overrides[get_current_user] = get_user
    client = TestClient(app)
    res = client.get("/qa/reports")
    assert res.status_code == 403
    
    # Admin gets 200 and list
    admin_user = User(uid="admin-user", email="admin@example.com", phone=None, display_name="Admin")
    admin_user.__dict__["role"] = "admin"
    app.dependency_overrides[get_current_user] = lambda: admin_user
    
    mock_client = mocker.MagicMock()
    mock_exec = mocker.MagicMock()
    mock_exec.data = [{
        "report_id": "rpt-12345",
        "user_id": "u1",
        "question": "q",
        "answer_text": "a",
        "category": "harmful",
        "created_at": "2026-09-07T12:00:00Z"
    }]
    mock_client.table().select().order().limit().execute.return_value = mock_exec
    mocker.patch("src.api.report_router._get_supabase_client", return_value=mock_client)
    
    res = client.get("/qa/reports")
    assert res.status_code == 200
    assert len(res.json()) == 1
    assert res.json()[0]["report_id"] == "rpt-12345"
    app.dependency_overrides.clear()
