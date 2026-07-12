from pydantic import BaseModel, Field
from typing import List


class EvalSample(BaseModel):
    query: str
    required_source_contains: List[str] = Field(
        default_factory=list,
        description="Substrings that must appear in at least one retrieved source.",
    )
    expected_fields: dict[str, str | None] = Field(
        default_factory=dict,
        description="Key-value pairs of expected field extractions"
    )
    expected_answer_contains: List[str] = Field(
        default_factory=list,
        description="Substrings expected in the generated answer"
    )
    expected_citations: List[int] = Field(
        default_factory=list,
        description="1-based source indices that should be cited by the answer.",
    )


INSURANCE_EVAL_SET: List[EvalSample] = [
    EvalSample(
        query="What is the policy number?",
        required_source_contains=["POL-12345"],
        expected_fields={"policy_number": "POL-12345"},
        expected_answer_contains=["POL-12345"],
        expected_citations=[1],
    ),
    EvalSample(
        query="Who is the insurance provider?",
        required_source_contains=["Niva Bupa"],
        expected_fields={"insurer": "Niva Bupa"},
        expected_answer_contains=["Niva Bupa"],
        expected_citations=[1],
    ),
    EvalSample(
        query="What is the coverage amount?",
        required_source_contains=["500000"],
        expected_fields={"coverage_amount": "500000"},
        expected_answer_contains=["500000", "5,00,000"],
        expected_citations=[1],
    ),
    EvalSample(
        query="What is the effective date?",
        required_source_contains=["2025-01-01"],
        expected_fields={"effective_date": "2025-01-01"},
        expected_answer_contains=["2025-01-01", "January 1, 2025"],
        expected_citations=[1],
    ),
    EvalSample(
        query="What is the deductible?",
        required_source_contains=["5000"],
        expected_fields={"deductible": "5000"},
        expected_answer_contains=["5000"],
        expected_citations=[1],
    ),
    EvalSample(
        query="Who is the insured?",
        required_source_contains=["John Doe"],
        expected_fields={"insured_name": "John Doe"},
        expected_answer_contains=["John Doe"],
        expected_citations=[1],
    ),
]
