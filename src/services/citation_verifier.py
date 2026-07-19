"""Citation verifier (ADR-2026-07-19-09 face 2 + ADR-2026-07-19-11 Layer 3).

Verifies that a citation's quote is actually in the source text and that the
citation is to a valid document and page. Citations to `retrieval_text`
(LLM-augmented contextualized chunk) are rejected.

Per ADR-2026-07-19-11 (substrate as primary deliverable), citations may
quote only `source_text`. This is the engineering answer to the trust
audit's P0-12 (RAGCitation validates only `source_index >= 1` and
`quote is str`; there is no post-generation check that the quote is
contained in source text).
"""
from __future__ import annotations

import re
from typing import Optional

from src.models.rag import RAGCitation


class CitationVerificationError(Exception):
    """Base for citation verification errors."""


class CitationRejectionReason:
    QUOTE_NOT_IN_SOURCE = "quote_not_in_source"
    QUOTE_FROM_RETRIEVAL = "quote_from_retrieval"
    SOURCE_INDEX_OUT_OF_BOUNDS = "source_index_out_of_bounds"
    DOCUMENT_MISMATCH = "document_mismatch"
    PAGE_NOT_FOUND = "page_not_found"
    EMPTY_QUOTE = "empty_quote"


def _normalize_whitespace(text: str) -> str:
    """Collapse runs of whitespace into single spaces for substring matching.

    Per the trust audit's P0-12 fix, the quote may differ from the source
    text by whitespace and a few punctuation characters. We normalize
    whitespace before substring match.
    """
    return re.sub(r"\s+", " ", text).strip()


def verify_citation(
    citation: RAGCitation,
    source_text: str,
    retrieval_text: Optional[str] = None,
    source_count: Optional[int] = None,
    document_id: Optional[str] = None,
    page_count: Optional[int] = None,
) -> tuple[bool, Optional[str]]:
    """Verify a citation against the source text.

    Returns (is_valid, rejection_reason). When `is_valid` is True, the
    citation is grounded in source_text. When False, `rejection_reason`
    names the failure (one of CitationRejectionReason's constants).

    Per ADR-2026-07-19-11 Layer 3, the quote_source field is checked first.
    If `quote_source == "retrieval_text"`, the citation is rejected
    immediately (the quote must come from source_text, not retrieval_text).
    """
    # Check 1: quote_source must be source_text (per ADR-2026-07-19-11).
    if citation.quote_source != "source_text":
        return False, CitationRejectionReason.QUOTE_FROM_RETRIEVAL

    # Check 2: quote must be non-empty.
    if not citation.quote or not citation.quote.strip():
        return False, CitationRejectionReason.EMPTY_QUOTE

    # Check 3: source_index must be in bounds.
    if source_count is not None and (citation.source_index < 1 or citation.source_index > source_count):
        return False, CitationRejectionReason.SOURCE_INDEX_OUT_OF_BOUNDS

    # Check 4: document_id must match (per ADR-2026-07-19-11 Layer 3).
    if document_id is not None and citation.document_id is not None:
        if citation.document_id != document_id:
            return False, CitationRejectionReason.DOCUMENT_MISMATCH

    # Check 5: page_number must be valid (per ADR-2026-07-19-11 Layer 4).
    if page_count is not None and citation.page_number is not None:
        if citation.page_number < 1 or citation.page_number > page_count:
            return False, CitationRejectionReason.PAGE_NOT_FOUND

    # Check 6: quote must be a substring of source_text (after whitespace
    # normalization). Per the trust audit's P0-12 acceptance criteria,
    # "no customer-visible quote can originate from generated context";
    # this is the substring check.
    normalized_quote = _normalize_whitespace(citation.quote)
    normalized_source = _normalize_whitespace(source_text)
    if normalized_quote not in normalized_source:
        # Also check that the quote is NOT in retrieval_text (defense-in-depth).
        # If the quote is in retrieval_text but not source_text, it's a
        # contextualized chunk citation, which is rejected.
        if retrieval_text is not None:
            normalized_retrieval = _normalize_whitespace(retrieval_text)
            if normalized_quote in normalized_retrieval:
                return False, CitationRejectionReason.QUOTE_FROM_RETRIEVAL
        return False, CitationRejectionReason.QUOTE_NOT_IN_SOURCE

    return True, None
