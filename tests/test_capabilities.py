"""Tests for the GET /capabilities endpoint (A1-P1b)."""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.api.capabilities import router


def _make_client() -> TestClient:
    app = FastAPI()
    app.include_router(router)
    return TestClient(app)


class TestGetCapabilities:
    def test_returns_all_six_fields(self):
        client = _make_client()
        response = client.get("/capabilities")
        assert response.status_code == 200
        data = response.json()
        assert "max_upload_file_size_bytes" in data
        assert "default_session_limit" in data
        assert "default_ip_limit" in data
        assert "session_duration_seconds" in data
        assert "connect_timeout_seconds" in data
        assert "receive_timeout_seconds" in data

    def test_max_upload_file_size_bytes_is_positive(self):
        client = _make_client()
        response = client.get("/capabilities")
        assert response.json()["max_upload_file_size_bytes"] > 0

    def test_default_session_limit_is_positive(self):
        client = _make_client()
        response = client.get("/capabilities")
        assert response.json()["default_session_limit"] > 0

    def test_default_ip_limit_is_positive(self):
        client = _make_client()
        response = client.get("/capabilities")
        assert response.json()["default_ip_limit"] > 0

    def test_session_duration_seconds_is_positive(self):
        client = _make_client()
        response = client.get("/capabilities")
        assert response.json()["session_duration_seconds"] > 0

    def test_connect_timeout_seconds_is_positive(self):
        client = _make_client()
        response = client.get("/capabilities")
        assert response.json()["connect_timeout_seconds"] > 0

    def test_receive_timeout_seconds_is_positive(self):
        client = _make_client()
        response = client.get("/capabilities")
        assert response.json()["receive_timeout_seconds"] > 0

    def test_all_fields_are_integers(self):
        client = _make_client()
        response = client.get("/capabilities")
        data = response.json()
        for key, value in data.items():
            assert isinstance(value, int), f"{key} should be int, got {type(value)}"

    def test_no_auth_required(self):
        """The endpoint must be accessible without any auth token."""
        client = _make_client()
        response = client.get("/capabilities")
        assert response.status_code == 200
