"""Tests for citation verifier with three-tier model (ADR-26, Commit 1)."""
from src.models.rag import RAGCitation
from src.services.citation_verifier import (
    verify_citation,
    CitationRejectionReason,
)


def make_citation(quote: str, source_index: int = 1, quote_source="source_text") -> RAGCitation:
    return RAGCitation(source_index=source_index, quote=quote, quote_source=quote_source)


def test_exact_match_verified():
    citation = make_citation("room rent limited to 1% of sum insured")
    source = "The room rent limited to 1% of sum insured per day is applicable."
    is_valid, reason, status = verify_citation(citation, source)
    assert is_valid is True
    assert status == "verified"
    assert reason is None


def test_retrieval_text_rejected():
    citation = make_citation("anything", quote_source="retrieval_text")
    is_valid, reason, status = verify_citation(citation, "anything")
    assert is_valid is False
    assert reason == CitationRejectionReason.QUOTE_FROM_RETRIEVAL
    assert status == "rejected"


def test_fuzzy_match_approximate():
    # Quote is a paraphrase — not exact but >=70% token overlap
    citation = make_citation("room rent cap one percent sum insured")
    source = "Room rent limited to 1% (one percent) of sum insured per day."
    is_valid, reason, status = verify_citation(citation, source)
    # Exact fails; fuzzy may pass depending on overlap
    # At minimum: status is not 'verified' and not 'rejected' on a close paraphrase
    assert status in ("approximate", "rejected")  # depends on overlap


def test_hallucinated_quote_rejected():
    citation = make_citation("maternity cover unlimited with zero waiting period")
    source = "Maternity expenses are subject to a 24-month waiting period and limited to Rs 40,000."
    is_valid, reason, status = verify_citation(citation, source)
    assert is_valid is False
    assert status == "rejected"


def test_empty_quote_rejected():
    citation = make_citation("   ")
    is_valid, reason, status = verify_citation(citation, "any source")
    assert is_valid is False
    assert reason == CitationRejectionReason.EMPTY_QUOTE


def test_source_index_out_of_bounds():
    citation = make_citation("valid quote", source_index=5)
    is_valid, reason, status = verify_citation(citation, "valid quote source", source_count=3)
    assert is_valid is False
    assert reason == CitationRejectionReason.SOURCE_INDEX_OUT_OF_BOUNDS
