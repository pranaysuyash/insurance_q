"""Tests for the policy redaction pipeline in tests/evals/live_fixture.py.

Covers ``extract_policy_pages`` (schedule-page drop) and ``_mask_pii`` (PII
masking). All PII used here is SYNTHETIC (John Doe / example.com / fake phone /
fake policy number) -- never real PII. The synthetic PDF is built in a /tmp path
with PyMuPDF.

Confidence: VERIFIED by running these tests against the real functions. See the
report for a documented limitation of ``_mask_pii`` with free-text names.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import fitz
import pytest

from tests.evals.live_fixture import extract_policy_pages, _mask_pii

SCHEDULE_STUB = "[REDACTED POLICY SCHEDULE / PII PAGE]"


def _make_synthetic_pdf(path: Path, page_texts: list[str]) -> Path:
    doc = fitz.open()
    for txt in page_texts:
        pg = doc.new_page()
        pg.insert_text((50, 60), txt)
    doc.save(str(path))
    doc.close()
    return path


def test_extract_policy_pages_drops_schedule_page_and_masks_email(tmp_path):
    pdf = _make_synthetic_pdf(
        tmp_path / "synthetic_policy.pdf",
        [
            # Page 1 -> schedule (must be dropped / stubbed).
            "SCHEDULE Policyholder John Doe john.doe@example.com +1 555 0100 Policy No. AB-12345",
            # Page 2 -> wording (must be kept, email masked).
            "Coverage includes hospitalisation. For claims contact john.doe@example.com.",
        ],
    )

    pages = extract_policy_pages(pdf)
    assert len(pages) == 2, pages

    # (1) schedule page (page 1) is dropped and replaced by a PII-free stub.
    assert pages[0][0] == 1
    assert pages[0][1] == SCHEDULE_STUB
    assert "John Doe" not in pages[0][1]
    assert "john.doe@example.com" not in pages[0][1]

    # (2) page 2 is kept, and the email is masked.
    assert "John Doe" in pages[1][1] or "hospitalisation" in pages[1][1]
    assert "[EMAIL]" in pages[1][1], "email must be masked in the wording page"
    assert "john.doe@example.com" not in pages[1][1], "raw email must not leak"


def test_mask_pii_masks_email():
    out = _mask_pii("Please email john.doe@example.com to confirm")
    assert "john.doe@example.com" not in out
    assert "[EMAIL]" in out


def test_mask_pii_masks_pin_format_phone_and_cci_policy_number():
    # An UNMASKED phone must be masked. (Already-asterisked tokens like
    # "12******34" are left as-is by design -- defense-in-depth targets raw PII.)
    pin = _mask_pii("mobile +1 555 0100 secondary")
    assert "[PHONE]" in pin and "+1 555 0100" not in pin

    policy = _mask_pii("ref 9999i/AB/12 issued today")
    assert "[POLICY_NO]" in policy and "9999i/AB/12" not in policy


def test_mask_pii_does_not_redact_free_text_name():
    # Documented limitation (see report): _mask_pii only masks a fixed token
    # list + the regex shapes above. A free-text name is NOT masked.
    out = _mask_pii("John Doe signed the form")
    assert out == "John Doe signed the form"
