"""Safety contracts for the synthetic local identity verifier."""

import sys

from tools import verify_local_identity_claim as verifier


def test_verifier_refuses_remote_supabase_before_any_request(monkeypatch, capsys):
    monkeypatch.setattr(
        sys,
        "argv",
        ["verify_local_identity_claim.py", "--supabase-url", "https://example.supabase.co"],
    )
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "local-publishable")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "local-secret")
    monkeypatch.setattr(verifier, "_json_request", lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError()))

    assert verifier.main() == 2
    assert "SUPABASE_URL must point to localhost" in capsys.readouterr().err


def test_verifier_refuses_remote_api_before_any_request(monkeypatch, capsys):
    monkeypatch.setattr(
        sys,
        "argv",
        ["verify_local_identity_claim.py", "--api-url", "https://api.example.com"],
    )
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "local-publishable")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "local-secret")
    monkeypatch.setattr(verifier, "_json_request", lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError()))

    assert verifier.main() == 2
    assert "API URL must point to localhost" in capsys.readouterr().err
