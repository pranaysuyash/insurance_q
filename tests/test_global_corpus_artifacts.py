"""Unit tests for the resilient global-corpus downloader (tools/scrape_policy_corpus.py).

These run with ZERO network: HTTP is mocked at the real seam used by
``download_one`` -> ``_fetch_with_fallback``. NOTE: the downloader is built on
``urllib.request`` (not ``requests``), so we monkeypatch
``tools.scrape_policy_corpus._fetch_with_fallback`` rather than ``requests.get``
(the task spec assumed requests, but the implementation does not use it). This is
a spec/implementation mismatch, not a code bug.

See motto_v5 (Evidence Tiers / Confidence Honesty): claims below are VERIFIED by
direct execution of these tests against the real source.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import pytest

import tools.scrape_policy_corpus as scrape
from tools.scrape_policy_corpus import Target, download_one


def _target(**overrides) -> Target:
    d = {
        "market": "us",
        "lob": "health",
        "insurer": "Acme",
        "product": "Plan A",
        "url": "https://primary.example.com/policy.pdf",
        "license_class": "regulator",
    }
    d.update(overrides)
    return Target.from_dict(d)


# ---------------------------------------------------------------------------
# (a) mirror fallback
# ---------------------------------------------------------------------------
def test_mirror_fallback_tries_mirror_and_gets_pdf(tmp_path, monkeypatch):
    primary = "https://primary.example.com/policy.pdf"
    mirror = "https://mirror.example.com/policy.pdf"
    t = _target(url=primary, mirror=mirror)

    seen = []

    def fake_fetch(src, timeout=30):
        seen.append(src)
        if src == primary:
            # A 200 HTML bot-block page: looks successful but is not a PDF.
            return (b"<!doctype html><html><body>Access denied by bot check</body></html>",
                    "text/html")
        # Mirror serves a real PDF (>= MIN_PDF_BYTES so it is NOT "too_small").
        return (b"%PDF-1.4\n" + b"A" * 3000, "application/pdf")

    monkeypatch.setattr(scrape, "_fetch_with_fallback", fake_fetch)
    rec = download_one(t, tmp_path)

    assert rec["status"] == "ok", rec
    out = t.out_path(tmp_path)
    assert out.exists(), "real PDF should be written"
    assert out.read_bytes()[:4] == b"%PDF"
    assert primary in seen and mirror in seen, "must try primary then fall through to mirror"
    # The primary's bot-block page must still be quarantined for inspection.
    blocked = out.with_suffix(".blocked.html")
    assert blocked.exists()


# ---------------------------------------------------------------------------
# (b) bot-block quarantine
# ---------------------------------------------------------------------------
def test_bot_block_quarantined_as_html_not_pdf(tmp_path, monkeypatch):
    t = _target()  # no mirror -> nothing to fall back to

    def fake_fetch(src, timeout=30):
        return (b"<!doctype html><html><body>Please verify you are human</body></html>",
                "text/html")

    monkeypatch.setattr(scrape, "_fetch_with_fallback", fake_fetch)
    rec = download_one(t, tmp_path)

    assert rec["status"] == "bot_blocked", rec
    out = t.out_path(tmp_path)
    assert not out.exists(), "a non-PDF 200 response must NOT be saved as .pdf"
    blocked = out.with_suffix(".blocked.html")
    assert blocked.exists(), "bot-block page should be quarantined as .blocked.html"
    assert b"Please verify you are human" in blocked.read_bytes()


# ---------------------------------------------------------------------------
# (c) idempotency
# ---------------------------------------------------------------------------
def test_idempotent_skip_existing_valid_pdf(tmp_path, monkeypatch):
    t = _target()
    out = t.out_path(tmp_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(b"%PDF-1.4\n" + b"B" * 3000)  # a valid PDF already present

    seen = []

    def fake_fetch(src, timeout=30):
        seen.append(src)
        return (b"x", "text/plain")

    monkeypatch.setattr(scrape, "_fetch_with_fallback", fake_fetch)
    rec = download_one(t, tmp_path)

    assert rec["status"] == "skip_existing", rec
    assert seen == [], "an existing valid PDF must not trigger any network fetch"


# ---------------------------------------------------------------------------
# (d) %PDF magic validation
# ---------------------------------------------------------------------------
def test_non_pdf_magic_rejected(tmp_path, monkeypatch):
    t = _target()  # no mirror

    def fake_fetch(src, timeout=30):
        # Large payload, but it does NOT start with %PDF and is not HTML.
        return (b"FAKEDATA" * 600, "application/octet-stream")

    monkeypatch.setattr(scrape, "_fetch_with_fallback", fake_fetch)
    rec = download_one(t, tmp_path)

    assert rec["status"] == "bot_blocked", rec
    out = t.out_path(tmp_path)
    assert not out.exists(), "a response lacking %PDF magic must not be saved as .pdf"
    blocked = out.with_suffix(".blocked.html")
    assert blocked.exists(), "the unrecognised body should be quarantined"
