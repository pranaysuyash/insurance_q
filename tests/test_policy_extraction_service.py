"""Regression tests for PolicyExtractionService initialization (H-05).

Previously the production branch raised NameError because the only
``create_client`` import sat on an unreachable line after a ``raise``. The
service then failed to initialize in production and policy extraction was
silently disabled. These tests lock the corrected behavior.
"""
import os

import pytest
from unittest.mock import MagicMock

from src.services import policy_extraction_service as pes
from src.services.policy_extraction_service import PolicyExtractionService


@pytest.fixture
def fake_llm():
    return MagicMock()


def test_prod_init_constructs_supabase_client(monkeypatch, fake_llm):
    """Production path must build the Supabase client without raising (H-05)."""
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")

    sentinel = object()
    monkeypatch.setattr(pes, "create_client", lambda url, key: sentinel)
    monkeypatch.setattr(pes, "supabase_server_key", lambda: "test-service-role-key")

    svc = PolicyExtractionService(llm_client=fake_llm)
    assert svc._supabase is sentinel


def test_prod_init_without_credentials_raises(monkeypatch, fake_llm):
    """Fail-fast when required prod storage config is missing."""
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("SUPABASE_URL", "")
    monkeypatch.setattr(pes, "supabase_server_key", lambda: None)

    with pytest.raises(RuntimeError):
        PolicyExtractionService(llm_client=fake_llm)


def test_dev_init_uses_local_store(monkeypatch, fake_llm):
    """Development path must NOT build a Supabase client and must not touch disk."""
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setattr("os.makedirs", lambda *a, **k: None)  # avoid on-disk side effects

    svc = PolicyExtractionService(llm_client=fake_llm)
    assert svc._supabase is None
