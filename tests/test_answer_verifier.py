"""Tests for the answer verifier (ADR-2026-07-19-09 face 3).

Per ADR-2026-07-19-09 (evidence-backed release-grade definition):

  **Face 3: Answer face — "every material claim has a verified citation"**

  1. Every material claim in the answer is followed by a citation marker.
  2. Every citation marker resolves to a citation that passes the citation face.
  3. The answer's verification_status is one of: fully_backed, partially_backed,
     or abstained.
  4. The answer never returns verification_status = unverified.
"""

from __future__ import annotations

from src.models.rag import RAGCitation
from src.services.answer_verifier import (
    verify_answer,
    _extract_citation_indices,
    _material_sentences,
    _count_cited_sentences,
)


# --- Citation index extraction ---

class TestExtractCitationIndices:
    def test_single_index(self):
        assert _extract_citation_indices("The sum insured is ₹5L [1].") == [1]

    def test_multiple_indices(self):
        assert _extract_citation_indices("Coverage includes A [1] and B [2].") == [1, 2]

    def test_comma_separated(self):
        assert _extract_citation_indices("Multiple sources support this [1, 2, 3].") == [1, 2, 3]

    def test_range(self):
        assert _extract_citation_indices("This claim is supported [1-3].") == [1, 2, 3]

    def test_no_citations(self):
        assert _extract_citation_indices("This sentence has no citation.") == []

    def test_mixed_format(self):
        assert _extract_citation_indices("Claims [1, 2, 4-6] are covered.") == [1, 2, 4, 5, 6]

    def test_ignores_zero_index(self):
        assert _extract_citation_indices("Invalid citation [0].") == []


# --- Material sentence splitting ---

class TestMaterialSentences:
    def test_simple_claim(self):
        sentences = _material_sentences(
            "Your policy covers hospitalization expenses [1]."
        )
        assert len(sentences) == 1

    def test_filters_short_sentences(self):
        """Sentences under 10 characters are filtered out."""
        sentences = _material_sentences("Hi. [1]. Your policy covers hospitalization [2].")
        assert len(sentences) == 1
        assert "hospitalization" in sentences[0]

    def test_filters_hedges(self):
        """Sentences starting with hedge words are filtered out."""
        text = (
            "Let me check your policy details. "
            "Your sum insured is ₹5,00,000 [1]. "
            "I'll look up the waiting period."
        )
        sentences = _material_sentences(text)
        assert len(sentences) == 1
        assert "sum insured" in sentences[0]

    def test_all_hedges_returns_empty(self):
        """When every sentence is a hedge, no material claims are extracted."""
        text = "Let me check. I'll look that up. Here is a summary."
        sentences = _material_sentences(text)
        assert len(sentences) == 0

    def test_multiple_material_claims(self):
        text = (
            "Your room rent limit is ₹5,000 per day [1]. "
            "Pre-hospitalization expenses are covered for up to 30 days [2]. "
            "The policy has a waiting period of 2 years [3]."
        )
        sentences = _material_sentences(text)
        assert len(sentences) == 3


# --- Count cited sentences ---

class TestCountCitedSentences:
    def test_all_sentences_cited(self):
        answer = (
            "Your room rent limit is ₹5,000 per day [1]. "
            "Pre-hospitalization expenses are covered for 30 days [2]."
        )
        citations = [
            RAGCitation(source_index=1, quote="room rent limit", citation_status="verified"),
            RAGCitation(source_index=2, quote="pre-hospitalization", citation_status="verified"),
        ]
        count = _count_cited_sentences(answer, citations)
        assert count == 2

    def test_some_sentences_cited(self):
        answer = (
            "Your room rent limit is ₹5,000 per day [1]. "
            "The policy is with ICICI Lombard."  # No citation marker
        )
        citations = [
            RAGCitation(source_index=1, quote="room rent limit", citation_status="verified"),
        ]
        count = _count_cited_sentences(answer, citations)
        assert count == 1  # Only the first sentence is cited

    def test_citation_marker_points_to_rejected_citation(self):
        """A citation marker pointing to a rejected citation does not count."""
        answer = (
            "Your sum insured is ₹10,00,000 [1]. "
            "The waiting period is 2 years [2]."
        )
        citations = [
            RAGCitation(source_index=1, quote="sum insured", citation_status="verified"),
            RAGCitation(source_index=2, quote="waiting period", citation_status="rejected"),
        ]
        count = _count_cited_sentences(answer, citations)
        assert count == 1  # Only [1] is verified

    def test_approximate_citations_do_not_count_as_verified(self):
        """Approximate citations remain warnings, not verified evidence."""
        answer = "Your room rent limit is ₹5,000 per day [1]."
        citations = [
            RAGCitation(source_index=1, quote="room rent limit", citation_status="approximate"),
        ]
        count = _count_cited_sentences(answer, citations)
        assert count == 0

    def test_no_citations_returns_zero(self):
        answer = "Your policy provides coverage for hospitalization."
        count = _count_cited_sentences(answer, citations=[])
        assert count == 0


# --- Full verify_answer ---

class TestVerifyAnswer:
    def test_fully_backed(self):
        """Every material claim has a verified citation."""
        answer = (
            "Your room rent limit is ₹5,000 per day [1]. "
            "Pre-hospitalization expenses are covered for 30 days [2]."
        )
        citations = [
            RAGCitation(source_index=1, quote="room rent limit", citation_status="verified"),
            RAGCitation(source_index=2, quote="pre-hospitalization", citation_status="verified"),
        ]
        status, total, cited = verify_answer(answer, citations)
        assert status == "fully_backed"
        assert total == 2
        assert cited == 2

    def test_partially_backed(self):
        """Some claims are cited, some are not."""
        answer = (
            "Your room rent limit is ₹5,000 per day [1]. "
            "The policy is with ICICI Lombard."  # No citation
        )
        citations = [
            RAGCitation(source_index=1, quote="room rent limit", citation_status="verified"),
        ]
        status, total, cited = verify_answer(answer, citations)
        assert status == "partially_backed"
        assert total == 2  # The uncited factual sentence is still material.
        assert cited == 1

    def test_abstained_no_verified_citations(self):
        """No verified citations for any claim."""
        answer = "Your room rent limit is ₹5,000 per day [1]."
        citations = [
            RAGCitation(source_index=1, quote="room rent limit", citation_status="rejected"),
        ]
        status, total, cited = verify_answer(answer, citations)
        assert status == "abstained"
        assert total == 1
        assert cited == 0

    def test_abstained_no_citations_at_all(self):
        """No citations provided at all."""
        answer = "Your policy covers hospitalization."
        status, total, cited = verify_answer(answer, citations=[])
        assert status == "abstained"
        assert total == 1
        assert cited == 0

    def test_never_returns_unverified(self):
        """Check 4: the answer verifier never returns 'unverified'."""
        test_cases = [
            # fully backed
            ("The limit is ₹5,000 [1].", [RAGCitation(source_index=1, quote="5,000", citation_status="verified")], "fully_backed"),
            # partially backed
            ("The limit is ₹5,000 [1]. No citation here.", [RAGCitation(source_index=1, quote="5,000", citation_status="verified")], "partially_backed"),
            # abstained
            ("The limit is ₹5,000 [1].", [RAGCitation(source_index=1, quote="5,000", citation_status="rejected")], "abstained"),
            # empty answer
            ("Let me check.", [], "fully_backed"),
        ]
        for answer_text, citations, expected_status in test_cases:
            status, total, cited = verify_answer(answer_text, citations)
            assert status == expected_status, (
                f"Expected {expected_status}, got {status} "
                f"for answer={answer_text!r} citations={citations}"
            )

    def test_approximate_only_answer_abstains(self):
        """Approximate-only evidence cannot satisfy the answer face."""
        answer = "Your room rent limit is ₹5,000 per day [1]."
        citations = [
            RAGCitation(source_index=1, quote="room rent limit", citation_status="approximate"),
        ]
        status, total, cited = verify_answer(answer, citations)
        assert status == "abstained"
        assert total == 1
        assert cited == 0

    def test_empty_answer_returns_fully_backed_trivially(self):
        """No material claims means trivially fully_backed."""
        status, total, cited = verify_answer("Let me check your policy.", citations=[])
        assert status == "fully_backed"
        assert total == 0
        assert cited == 0
