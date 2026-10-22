"""Unit tests for the page-aware grounding check (the #36 fix).

These run with ZERO network / LLM access — the grounding decision is a pure
function of the example's `expected_page` and the retrieved sources' `page_number`
(with a soft token-containment fallback). This is what makes the live gate
CI-safe after the exact-substring over-firing was fixed.

The headline regression case is the v3 false-positive: "Maternity Cover &
New Born Baby Cover" was read CORRECTLY (pred == gold == `conditional`) yet the
old exact-substring check flagged it ungrounded. With page-aware grounding the
correct reading is never penalised.
"""

from __future__ import annotations

from tests.evals.run_evals import Example, is_grounded, _token_containment


def _ex(page: int | None = None, citation: str = "Maternity Cover & New Born Baby Cover") -> Example:
    return Example(
        id="policy-pdf",
        product="Health Shield 360 (redacted)",
        clause="Maternity Cover & New Born Baby Cover Not Applicable for 3 Lacs",
        question="Am I covered for maternity and newborn expenses?",
        gold_reading="conditional",
        gold_rationale="conditional on sum-insured tier",
        expected_citation=citation,
        expected_page=page,
    )


def _src(page: int, text: str = "Maternity Cover & New Born Baby Cover wording") -> dict:
    return {"page_number": page, "text": text}


# --- _token_containment -----------------------------------------------------

def test_token_containment_full_overlap():
    assert _token_containment("deductible not applicable", "deductible not applicable") == 1.0


def test_token_containment_paraphrase_partial():
    # Model rewords; only some tokens overlap. Should be < 1.0 but > 0.
    score = _token_containment("maternity waiting period 36 months",
                               "the maternity benefit has a waiting period")
    assert 0.0 < score < 1.0


def test_token_containment_empty_needle_is_zero():
    assert _token_containment("", "anything") == 0.0


# --- is_grounded: page-aware primary signal ---------------------------------

def test_page_aware_pass_when_expected_page_in_sources():
    ex = _ex(page=2)
    # Retrieved sources include page 2 (the maternity-newborn page) -> grounded,
    # even though the exact citation string is paraphrased away.
    assert is_grounded(ex, [_src(2), _src(3)], "the maternity benefit is conditional") is True


def test_page_aware_false_when_expected_page_absent_but_text_strong():
    ex = _ex(page=2)
    # Expected page NOT in retrieved sources, but the citation text IS present ->
    # soft fallback keeps a correctly-grounded answer from being penalised.
    assert is_grounded(ex, [_src(9), _src(10)], "Maternity Cover & New Born Baby Cover") is True


def test_page_aware_false_when_page_absent_and_no_text_overlap():
    ex = _ex(page=2)
    # Neither the expected page nor any meaningful text overlap -> not grounded.
    assert is_grounded(ex, [_src(9)], "unrelated liver transplant wording") is False


# --- the v3 false-positive regression ---------------------------------------

def test_v3_false_positive_no_longer_fires():
    """Exact reproduction of the v3 over-fire: correct reading, flagged before."""
    ex = _ex(page=2, citation="Maternity Cover & New Born Baby Cover")
    # Old check: "Maternity Cover & New Born Baby Cover".lower() in (sources+citations)
    # would fail on a paraphrased/truncated retrieval. New check: page 2 is present
    # in the retrieved sources, so grounded=True despite no verbatim phrase.
    sources = [_src(2, "the newborn cover is subject to a maternity limit and waiting period")]
    citations_text = "the newborn cover is subject to a maternity limit"
    assert is_grounded(ex, sources, citations_text) is True


# --- legacy rows without expected_page fall back to containment --------------

def test_legacy_row_without_expected_page_uses_containment():
    ex = _ex(page=None, citation="Deductible Not Applicable")
    # No expected_page -> soft containment path; present -> grounded.
    assert is_grounded(ex, [_src(12)], "Deductible Not Applicable") is True


def test_legacy_row_without_expected_page_low_overlap_ungrounded():
    ex = _ex(page=None, citation="Deductible Not Applicable")
    assert is_grounded(ex, [_src(12)], "unrelated cataract wording") is False
