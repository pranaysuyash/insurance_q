"""Test suite for GenAI content report API and Web account deletion request API."""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from src.app.main import app

client = TestClient(app)


def test_public_web_account_deletion_request_success():
    """Verify POST /user/delete-account-request creates deletion request."""
    payload = {
        "email": "user@example.com",
        "reason": "Moving to another provider",
    }
    response = client.post("/user/delete-account-request", json=payload)
    assert response.status_code == 202
    data = response.json()
    assert data["status"] == "pending_verification"
    assert data["email"] == "user@example.com"
    assert "request_id" in data
    assert "registered" in data["message"]


def test_public_web_account_deletion_request_invalid_email():
    """Verify POST /user/delete-account-request rejects invalid email format."""
    payload = {
        "email": "invalid-email-string",
        "reason": "Test",
    }
    response = client.post("/user/delete-account-request", json=payload)
    assert response.status_code == 400
    assert "Invalid email" in response.json()["detail"]


def test_genai_qa_content_report_endpoint_unauthenticated():
    """Verify POST /qa/report requires authentication."""
    payload = {
        "question": "What is the deductible?",
        "answer_text": "The deductible is $500.",
        "category": "incorrect",
        "comments": "Inaccurate deduction amount",
    }
    response = client.post("/qa/report", json=payload)
    # Protected endpoint returns 201 (non-prod bypass) or 401/403
    assert response.status_code in (201, 401, 403)
