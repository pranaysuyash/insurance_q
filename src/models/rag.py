from __future__ import annotations

from typing import List, Literal

from pydantic import BaseModel, Field


QuoteSource = Literal["source_text", "retrieval_text"]


class RAGCitation(BaseModel):
    source_index: int = Field(..., ge=1, description="1-based index of the retrieved source used in the answer.")
    quote: str = Field(..., description="Short supporting quote copied from the retrieved source.")
    quote_source: QuoteSource = Field(
        "source_text",
        description=(
            "Where the quote was copied from. Per ADR-2026-07-19-11 (substrate as primary "
            "deliverable), citations may quote only `source_text` (immutable, OCR'd page text). "
            "Quotes from `retrieval_text` (LLM-augmented contextualized chunk) are rejected "
            "by the citation verifier (per ADR-2026-07-19-09 face 2)."
        ),
    )
    document_id: str | None = Field(
        None,
        description=(
            "The document the quote was copied from. Per ADR-2026-07-19-11 Layer 3, "
            "citations belong to the same document as the answer."
        ),
    )
    page_number: int | None = Field(
        None,
        ge=1,
        description=(
            "The page the quote was copied from. Per ADR-2026-07-19-11 Layer 4, the "
            "page is reachable from the citation card via the 'open page' action."
        ),
    )
    citation_status: Literal["verified", "approximate", "rejected"] = Field(
        "verified",
        description=(
            "Post-generation verification status. 'verified' = exact substring match in source_text. "
            "'approximate' = fuzzy token overlap >=70% but not exact (shown with 'approximate match' label). "
            "'rejected' = quote not found in source_text (citation stripped from response)."
        ),
    )


VerificationStatus = Literal["fully_backed", "partially_backed", "abstained", "unverified"]


class RAGAnswer(BaseModel):
    answer: str = Field(..., description="Direct answer grounded in the retrieved context.")
    citations: List[RAGCitation] = Field(
        default_factory=list,
        description="Source-backed citations for the answer, ordered by relevance.",
    )
    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Estimated confidence that the answer is supported by the retrieved context.",
    )
    missing_information: List[str] = Field(
        default_factory=list,
        description="Important details that were not present in the retrieved context.",
    )
    follow_up_questions: List[str] = Field(
        default_factory=list,
        description="Helpful follow-up questions when the answer is incomplete or ambiguous.",
    )
    verification_status: VerificationStatus = Field(
        "unverified",
        description=(
            "Per ADR-2026-07-19-09 face 3 (answer face): 'fully_backed' if every "
            "material claim has a verified citation; 'partially_backed' if some "
            "claims are cited and verified but some are marked unsupported; "
            "'abstained' if the system declines to answer because no claims can "
            "be backed; 'unverified' is the initial state before the answer "
            "verifier runs (reserved for the UI badge to render a warning)."
        ),
    )
