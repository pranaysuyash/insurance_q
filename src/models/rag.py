from __future__ import annotations

from typing import List

from pydantic import BaseModel, Field


class RAGCitation(BaseModel):
    source_index: int = Field(..., ge=1, description="1-based index of the retrieved source used in the answer.")
    quote: str = Field(..., description="Short supporting quote copied from the retrieved source.")


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
