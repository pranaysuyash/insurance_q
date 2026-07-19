"""Pytest configuration for the tests directory.

The evidence pipeline integration tests set SUPABASE_URL and
SUPABASE_SERVICE_ROLE_KEY in the environment. Without a
cleanup, subsequent tests see a 'configured' substrate and
the from_env fail-loud tests in test_evidence_substrate_service.py
fail. This conftest.py ensures the env vars are cleared before
and after every test.
"""
import pytest


@pytest.fixture(autouse=True)
def _reset_supabase_env(monkeypatch):
    """Clear SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before
    and after every test in this directory. The pre-yield
    cleanup ensures a test starts with a clean env; the
    post-yield cleanup handles cases where the test crashes
    or where the test's own monkeypatch.setenv would otherwise
    leak.
    """
    import os
    # Clear BEFORE the test.
    if "SUPABASE_URL" in os.environ:
        monkeypatch.delenv("SUPABASE_URL", raising=False)
    if "SUPABASE_SERVICE_ROLE_KEY" in os.environ:
        monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    yield
    # Clear AFTER the test, regardless of test outcome.
    if "SUPABASE_URL" in os.environ:
        monkeypatch.delenv("SUPABASE_URL", raising=False)
    if "SUPABASE_SERVICE_ROLE_KEY" in os.environ:
        monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
