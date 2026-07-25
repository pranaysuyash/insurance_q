"""Safety contracts for the synthetic local tenant-isolation verifier."""

import sys

from tools import verify_local_tenant_isolation as verifier


def test_verifier_refuses_remote_before_any_request(monkeypatch, capsys):
    monkeypatch.setattr(
        sys,
        "argv",
        ["verify_local_tenant_isolation.py", "--api-url", "https://example.com"],
    )
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "local-publishable")
    monkeypatch.setenv("SUPABASE_SECRET_KEY", "local-secret")
    monkeypatch.setattr(
        verifier,
        "_request",
        lambda *args, **kwargs: (_ for _ in ()).throw(AssertionError()),
    )
    assert verifier.main() == 2
    assert "local-only guard" in capsys.readouterr().err


def test_multipart_pdf_contains_the_required_upload_parts():
    body, boundary = verifier._multipart_pdf()
    assert boundary.encode() in body
    assert b'name="files"; filename="synthetic-policy.pdf"' in body
    assert b"processing_consent" in body
    assert b"%PDF-1.7" in body
