from __future__ import annotations

from typing import List, Literal, Optional

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


# --- Policy Wording Specialist: structured coverage interpretation ---
# Legal-safety note: this is an INTERPRETATION of the wording as written, not a
# binding coverage / eligibility / claim / legal decision. The insurer decides.
# Field names deliberately avoid "decision"; the model must surface ambiguity
# rather than assert a single binding reading. See docs/review/... audit.


class CoverageLimitationRef(BaseModel):
    label: str = Field(..., description="Short label, e.g. 'Exclusion 3', 'Endorsement 4', 'Limit on baggage'.")
    quote: str = Field(
        "",
        description="Short supporting quote copied from source_text (the immutable OCR'd text).",
    )
    source_index: Optional[int] = Field(
        None,
        description="1-based index of the retrieved source this limitation was read from.",
    )


class WordingAssessment(BaseModel):
    # Deliberately 'reading', never 'decision'.
    reading: Literal["likely_covered", "likely_not_covered", "conditional", "ambiguous"] = Field(
        "ambiguous",
        description=(
            "Interpretation of the wording as written. NOT a binding coverage decision. "
            "'conditional' = covered only if a condition/limit is met; 'ambiguous' = the "
            "wording permits more than one reasonable reading."
        ),
    )
    summary: str = Field(
        "",
        description="One or two sentence plain-language reading of the wording for the question asked.",
    )
    applicable_exclusions: List[CoverageLimitationRef] = Field(
        default_factory=list, description="Exclusions that carve out the asked-about cover."
    )
    applicable_exceptions: List[CoverageLimitationRef] = Field(
        default_factory=list, description="Carve-backs to those exclusions that may restore cover."
    )
    applicable_conditions: List[CoverageLimitationRef] = Field(
        default_factory=list, description="Conditions, notification duties, or claims conditions that must be met."
    )
    applicable_limits: List[CoverageLimitationRef] = Field(
        default_factory=list, description="Limits or deductibles that cap the cover."
    )
    amending_endorsements: List[CoverageLimitationRef] = Field(
        default_factory=list, description="Endorsements, riders, or schedules that amend or override the base wording."
    )
    alternative_interpretation: Optional[str] = Field(
        None,
        description="The most reasonable unintended reading of the wording (adversarial test). Null if none identified.",
    )
    disclaimer: str = Field(
        (
            "This is an interpretation of the policy wording as written, not a binding coverage, "
            "eligibility, or claim decision. Confirm with your insurer before relying on it."
        ),
        description="Mandatory non-legal-ish disclaimer; the insurer makes binding decisions.",
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
    wording_assessment: Optional[WordingAssessment] = Field(
        None,
        description=(
            "Optional structured interpretation produced when the question is about "
            "whether something is covered. Interprets the wording; never a binding decision. "
            "Populated only when the Policy Wording Specialist persona is active."
        ),
    )
    persona_version: Optional[str] = Field(
        None,
        description="Version of the Policy Wording Specialist persona prompt that produced this answer (traceability).",
    )
