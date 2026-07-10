from pydantic import BaseModel, Field
from typing import List


class EvalSample(BaseModel):
    query: str
    expected_fields: dict[str, str | None] = Field(
        default_factory=dict,
        description="Key-value pairs of expected field extractions"
    )
    expected_answer_contains: List[str] = Field(
        default_factory=list,
        description="Substrings expected in the generated answer"
    )


INSURANCE_EVAL_SET: List[EvalSample] = [
    EvalSample(
        query="What is the policy number?",
        expected_fields={"policy_number": "POL-12345"},
        expected_answer_contains=["POL-12345"],
    ),
    EvalSample(
        query="Who is the insurance provider?",
        expected_fields={"insurer": "Niva Bupa"},
        expected_answer_contains=["Niva Bupa"],
    ),
    EvalSample(
        query="What is the coverage amount?",
        expected_fields={"coverage_amount": "500000"},
        expected_answer_contains=["500000", "5,00,000"],
    ),
    EvalSample(
        query="What is the effective date?",
        expected_fields={"effective_date": "2025-01-01"},
        expected_answer_contains=["2025-01-01", "January 1, 2025"],
    ),
    EvalSample(
        query="What is the deductible?",
        expected_fields={"deductible": "5000"},
        expected_answer_contains=["5000"],
    ),
    EvalSample(
        query="Who is the insured?",
        expected_fields={"insured_name": "John Doe"},
        expected_answer_contains=["John Doe"],
    ),
]
