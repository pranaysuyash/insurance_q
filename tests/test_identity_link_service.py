from pathlib import Path

import pytest

from src.services import identity_link_service as links


@pytest.fixture
def isolated_identity_db(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(links, "DB_PATH", str(tmp_path / "identity.db"))
    monkeypatch.setenv("ENVIRONMENT", "test")
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    links.clear_cache()
    yield
    links.clear_cache()


def test_guest_account_link_is_idempotent(isolated_identity_db):
    pending = links.begin("anon:guest-1", "account-1")
    assert pending.status == "pending"

    completed = links.complete("anon:guest-1", "account-1", 3)
    assert completed.status == "completed"
    assert completed.transferred_documents == 3

    retry = links.begin("anon:guest-1", "account-1")
    assert retry == completed


def test_guest_cannot_be_rebound_to_another_account(isolated_identity_db):
    links.begin("anon:guest-2", "account-1")
    with pytest.raises(ValueError, match="already linked"):
        links.begin("anon:guest-2", "account-2")


def test_supabase_secret_key_is_accepted_by_direct_service_use(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://project.supabase.co")
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "server-secret")
    fake_client = object()

    monkeypatch.setattr(
        "supabase.create_client",
        lambda url, key, options=None: fake_client,
    )
    links.clear_cache()
    assert links._supabase_client() is fake_client
    links.clear_cache()
