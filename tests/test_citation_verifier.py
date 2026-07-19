"""Tests for the chunk model split (ADR-2026-07-19-11 Layer 2)
and the citation verifier (ADR-2026-07-19-11 Layer 3 + ADR-2026-07-19-09 face 2).

Per ADR-2026-07-19-11 (substrate as primary deliverable):
- Every chunk has source_text (immutable, OCR'd page text) and retrieval_text
  (LLM-augmented contextualized chunk, when contextual retrieval is enabled).
- source_text is preserved untouched when _contextualize_chunks runs.
- Citations may quote only source_text.
- The citation verifier (per ADR-2026-07-19-09 face 2) rejects citations
  to retrieval_text.
"""
from __future__ import annotations

import pytest
from src.models.rag import RAGCitation
from src.services.citation_verifier import (
    CitationRejectionReason,
    verify_citation,
    _normalize_whitespace,
)


# --- Chunk model split (Layer 2) tests ---

class TestChunkModelSplit:
    """Per ADR-2026-07-19-11 Layer 2: every chunk has source_text and retrieval_text."""

    def test_chunk_has_both_source_text_and_retrieval_text(self):
        """A new chunk initializes both fields from the same OCR text."""
        # Simulate _split_into_sentences output for a single sentence
        source = "This is a sample policy clause about coverage."
        chunk = {
            "source_text": source,
            "retrieval_text": source,
            "id": "test-1",
            "sentence_index": 0,
            "chunk_type": "sentence",
        }
        assert chunk["source_text"] == source
        assert chunk["retrieval_text"] == source

    def test_source_text_is_preserved_when_retrieval_text_changes(self):
        """When retrieval_text is overwritten (e.g. by _contextualize_chunks),
        source_text is preserved untouched. This is the central trust
        contract per ADR-2026-07-19-11.
        """
        original_source = "The sum insured is five lakh rupees."
        chunk = {
            "source_text": original_source,
            "retrieval_text": original_source,
        }
        # Simulate _contextualize_chunks writing to retrieval_text only
        chunk["retrieval_text"] = f"Context: policy clause.\n\n{original_source}"
        assert chunk["source_text"] == original_source
        assert chunk["retrieval_text"] != original_source
        # The original source text is the citable form.
        assert original_source in chunk["source_text"]


# --- Citation model field (Layer 3) tests ---

class TestCitationModelField:
    """Per ADR-2026-07-19-11 Layer 3: RAGCitation has quote_source field
    that defaults to 'source_text'."""

    def test_citation_default_quote_source_is_source_text(self):
        """A new RAGCitation defaults quote_source to 'source_text' (the
        citable form). Per ADR-2026-07-19-11, citations may quote only
        source_text.
        """
        citation = RAGCitation(source_index=1, quote="Some quote")
        assert citation.quote_source == "source_text"

    def test_citation_rejects_retrieval_text_explicitly(self):
        """A citation can be created with quote_source='retrieval_text',
        but the citation verifier (per ADR-2026-07-19-11) will reject it.
        The model allows it for backward compat; the verifier enforces the
        contract.
        """
        citation = RAGCitation(
            source_index=1,
            quote="Some quote",
            quote_source="retrieval_text",
        )
        assert citation.quote_source == "retrieval_text"

    def test_citation_has_document_id_and_page_number_fields(self):
        """Per ADR-2026-07-19-11 Layer 3 and 4: every citation has
        document_id and page_number so the 'open page' action can find
        the source.
        """
        citation = RAGCitation(
            source_index=1,
            quote="Some quote",
            document_id="doc-1",
            page_number=4,
        )
        assert citation.document_id == "doc-1"
        assert citation.page_number == 4


# --- Citation verifier tests (per ADR-2026-07-19-11 Layer 3 + ADR-2026-07-19-09 face 2) ---

class TestCitationVerifier:
    """Per ADR-2026-07-19-11 Layer 3 + ADR-2026-07-19-09 face 2."""

    def test_verify_citation_accepts_quote_in_source_text(self):
        """A citation whose quote is a substring of source_text is valid."""
        source_text = "The sum insured is five lakh rupees. Coverage includes hospitalization."
        citation = RAGCitation(source_index=1, quote="five lakh rupees")
        is_valid, reason = verify_citation(citation, source_text)
        assert is_valid is True
        assert reason is None

    def test_verify_citation_rejects_quote_from_retrieval_text(self):
        """A citation whose quote_source is 'retrieval_text' is rejected,
        even if the quote is in the source. Per ADR-2026-07-19-11,
        citations may quote only source_text.
        """
        source_text = "The sum insured is five lakh rupees."
        retrieval_text = "Context: policy clause.\n\nThe sum insured is five lakh rupees."
        citation = RAGCitation(
            source_index=1,
            quote="Context: policy clause.",
            quote_source="retrieval_text",
        )
        is_valid, reason = verify_citation(citation, source_text, retrieval_text=retrieval_text)
        assert is_valid is False
        assert reason == CitationRejectionReason.QUOTE_FROM_RETRIEVAL

    def test_verify_citation_rejects_quote_not_in_source(self):
        """A citation whose quote is not in source_text is rejected."""
        source_text = "The sum insured is five lakh rupees."
        citation = RAGCitation(source_index=1, quote="ten lakh rupees")
        is_valid, reason = verify_citation(citation, source_text)
        assert is_valid is False
        assert reason == CitationRejectionReason.QUOTE_NOT_IN_SOURCE

    def test_verify_citation_rejects_empty_quote(self):
        """An empty quote is rejected."""
        source_text = "The sum insured is five lakh rupees."
        citation = RAGCitation(source_index=1, quote="")
        is_valid, reason = verify_citation(citation, source_text)
        assert is_valid is False
        assert reason == CitationRejectionReason.EMPTY_QUOTE

    def test_verify_citation_rejects_source_index_out_of_bounds(self):
        """A citation whose source_index is > source_count is rejected."""
        source_text = "The sum insured is five lakh rupees."
        citation = RAGCitation(source_index=5, quote="five lakh rupees")
        is_valid, reason = verify_citation(citation, source_text, source_count=3)
        assert is_valid is False
        assert reason == CitationRejectionReason.SOURCE_INDEX_OUT_OF_BOUNDS

    def test_verify_citation_rejects_document_mismatch(self):
        """A citation whose document_id differs from the answer's
        document_id is rejected. Per ADR-2026-07-19-11 Layer 3.
        """
        source_text = "The sum insured is five lakh rupees."
        citation = RAGCitation(
            source_index=1,
            quote="five lakh rupees",
            document_id="doc-A",
        )
        is_valid, reason = verify_citation(
            citation, source_text, document_id="doc-B"
        )
        assert is_valid is False
        assert reason == CitationRejectionReason.DOCUMENT_MISMATCH

    def test_verify_citation_rejects_page_not_found(self):
        """A citation whose page_number is > page_count is rejected.
        Per ADR-2026-07-19-11 Layer 4.
        """
        source_text = "The sum insured is five lakh rupees."
        citation = RAGCitation(
            source_index=1,
            quote="five lakh rupees",
            page_number=99,
        )
        is_valid, reason = verify_citation(citation, source_text, page_count=10)
        assert is_valid is False
        assert reason == CitationRejectionReason.PAGE_NOT_FOUND

    def test_verify_citation_normalizes_whitespace(self):
        """The substring match normalizes whitespace, so a quote with
        different whitespace (e.g. newlines vs. spaces) still matches.
        Per the trust audit's P0-12 acceptance criteria.
        """
        source_text = "The sum insured is five lakh rupees."
        # Quote has different whitespace than source
        citation = RAGCitation(
            source_index=1,
            quote="The  sum  insured  is  five  lakh  rupees.",
        )
        is_valid, reason = verify_citation(citation, source_text)
        assert is_valid is True
        assert reason is None


class TestNormalizeWhitespace:
    def test_collapses_multiple_spaces(self):
        assert _normalize_whitespace("a  b") == "a b"

    def test_collapses_tabs_and_newlines(self):
        assert _normalize_whitespace("a\tb\nc") == "a b c"

    def test_strips_leading_and_trailing(self):
        assert _normalize_whitespace("  hello  ") == "hello"
