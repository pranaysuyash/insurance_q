"""Tests for the evidence extraction pipeline (Trust Phase 1 Phase C).

The pipeline is the orchestrator that turns a document's pages
into cited fields in the substrate. These tests exercise the
deterministic extractors (pure functions on text) and the
orchestrator (mocked substrate, end-to-end flow). The LLM
extractor is tested via a fake LLM client that returns canned
JSON, not a real OpenAI call.

The trust audit's Phase 1 acceptance is:
  1. Each deterministic extractor returns the correct field
     for a sample Indian health policy.
  2. The three-layer value wrapper (raw, normalized, display)
     roundtrips correctly: sum_insured raw is the regex match,
     normalized is paise (integer), display is the Indian-grouped
     rupee string.
  3. The LLM extractor rejects fields whose cited clause does
     not appear in the source text. This is the substrate's
     defense against the most common LLM failure mode.
  4. The orchestrator records a zero-cost row for every
     attempted extraction (even when the field is absent), so
     the operator dashboard can see pipeline activity.
  5. The orchestrator rejects fields whose cited page has no
     page_artifact in the substrate.
"""

import os
import sys
from unittest.mock import AsyncMock, MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.models.evidence import ParserKind, SpanType, ValueType  # noqa: E402
from src.services.evidence_pipeline import (  # noqa: E402
    EvidencePipeline,
    InsurerNameExtractor,
    PolicyHolderExtractor,
    PolicyNumberExtractor,
    PolicyStartDateExtractor,
    PremiumAmountExtractor,
    RoomRentCapExtractor,
    SumInsuredExtractor,
    _format_inr,
    _parse_currency_to_paise,
)
from src.services.evidence_substrate_service import (  # noqa: E402
    EvidenceSubstrateService,
)


# --- 1. helpers ---

def test_parse_currency_to_paise_handles_indian_grouping():
    assert _parse_currency_to_paise("5,00,000") == 50_000_000  # 5L = 50M paise
    assert _parse_currency_to_paise("12,500") == 1_250_000
    assert _parse_currency_to_paise("1,000") == 100_000
    assert _parse_currency_to_paise("100") == 10_000
    assert _parse_currency_to_paise("garbage") == 0


def test_format_inr_renders_indian_grouping():
    assert _format_inr(50_000_000) == "₹5,00,000"
    assert _format_inr(1_250_000) == "₹12,500"
    assert _format_inr(100_000) == "₹1,000"
    assert _format_inr(500) == "₹5"


# --- 2. deterministic extractors ---

SAMPLE_PAGES = {
    1: (
        "HDFC ERGO Health Insurance\n"
        "Policy No: ABC1234567\n"
        "Policy Holder: Pranay Suyash\n"
        "Sum Insured: 5,00,000\n"
        "Premium: 12,500\n"
    ),
    2: (
        "Policy period: 2026-01-15 to 2027-01-14\n"
        "Room rent: 1% of sum insured, max ₹5,000/day\n"
    ),
}


def _run(coro):
    import asyncio
    return asyncio.run(coro)


def test_policy_number_extractor():
    e = PolicyNumberExtractor()
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.field_name == "policy_number"
    assert r.value.raw == "ABC1234567"
    assert r.value.normalized == "ABC1234567"
    assert r.confidence >= 0.8
    assert r.cite_string == "page 1"


def test_policy_holder_extractor():
    e = PolicyHolderExtractor()
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.field_name == "policy_holder_name"
    assert r.value.raw == "Pranay Suyash"
    assert r.value.display == "Pranay Suyash"  # title() preserves
    assert r.cite_string == "page 1"


def test_sum_insured_extractor():
    e = SumInsuredExtractor()
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.field_name == "sum_insured"
    assert r.value.raw == "5,00,000"
    assert r.value.normalized == 50_000_000  # paise
    assert r.value.display == "₹5,00,000"
    assert r.value_type == ValueType.CURRENCY
    assert r.cite_string == "page 1"


def test_policy_start_date_extractor_iso_format():
    e = PolicyStartDateExtractor()
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.field_name == "policy_start_date"
    assert r.value.raw == "2026-01-15"
    assert r.value.normalized == "2026-01-15"
    assert r.value_type == ValueType.DATE


def test_policy_start_date_extractor_dmy_format():
    e = PolicyStartDateExtractor()
    pages = {1: "Policy start date: 15/01/2026"}
    r = _run(e.extract(_uuid(), pages))
    assert r is not None
    # DMY assumed for Indian policies
    assert r.value.normalized == "2026-01-15"


def test_premium_amount_extractor():
    e = PremiumAmountExtractor()
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.field_name == "premium_amount"
    assert r.value.normalized == 1_250_000
    assert r.value.display == "₹12,500"


def test_insurer_name_extractor():
    e = InsurerNameExtractor()
    assert e.parser_kind == ParserKind.DETERMINISTIC_LOOKUP
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.field_name == "insurer_name"
    assert "hdfc" in r.value.raw
    assert r.value_type == ValueType.STRING


def test_extractor_returns_none_when_field_absent():
    e = PolicyNumberExtractor()
    pages = {1: "Some document with no policy number."}
    r = _run(e.extract(_uuid(), pages))
    assert r is None


# --- 3. LLM extractor (fake LLM) ---

class FakeLLM:
    def __init__(self, response_payload):
        self.response_payload = response_payload

    async def generate_structured(self, response_model, **kwargs):
        return response_model.model_validate(self.response_payload)


class BrokenLLM:
    async def generate_structured(self, **kwargs):
        raise RuntimeError("rate limited")


def _room_rent_payload(present, clause="", display=""):
    return {"present": present, "clause": clause, "display": display}


def test_room_rent_cap_extractor_rejects_invalid_typed_payload():
    fake = FakeLLM(_room_rent_payload(True, "x" * 2_001, "cap"))
    e = RoomRentCapExtractor(llm_client=fake)
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is None


def test_room_rent_cap_extractor_uses_typed_output_contract():
    fake = FakeLLM(_room_rent_payload(
        True,
        "Room rent: 1% of sum insured, max ₹5,000/day",
        "1% of sum insured, max ₹5,000/day",
    ))
    e = RoomRentCapExtractor(llm_client=fake)
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.cite_string == "page 2"


def test_room_rent_cap_extractor_rejects_unverified_clause():
    fake = FakeLLM(_room_rent_payload(
        True,
        "There is no room rent cap in this policy.",
        "No room rent cap",
    ))
    e = RoomRentCapExtractor(llm_client=fake)
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is None


def test_room_rent_cap_extractor_handles_structured_llm_error():
    e = RoomRentCapExtractor(llm_client=BrokenLLM())
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is None


def test_room_rent_cap_extractor_present():
    fake = FakeLLM(
        _room_rent_payload(
            True,
            "Room rent: 1% of sum insured, max ₹5,000/day",
            "1% of sum insured, max ₹5,000/day",
        )
    )
    e = RoomRentCapExtractor(llm_client=fake)
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is not None
    assert r.field_name == "room_rent_cap"
    assert r.value_type == ValueType.CLAUSE_TEXT
    assert r.value.display == "1% of sum insured, max ₹5,000/day"
    assert r.evidence_strength == 1.0  # clause is on page 2
    assert r.cite_string == "page 2"


def test_room_rent_cap_extractor_absent():
    fake = FakeLLM(_room_rent_payload(False))
    e = RoomRentCapExtractor(llm_client=fake)
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is None


def test_room_rent_cap_extractor_rejects_hallucinated_clause():
    """Unverified model text must not enter the evidence substrate."""
    fake = FakeLLM(_room_rent_payload(
        True,
        "There is no room rent cap in this policy.",
        "No room rent cap",
    ))
    e = RoomRentCapExtractor(llm_client=fake)
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is None  # no unverified value enters the substrate


def test_room_rent_cap_extractor_handles_llm_error():
    e = RoomRentCapExtractor(llm_client=BrokenLLM())
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is None  # graceful failure, no row


def test_room_rent_cap_extractor_handles_non_json():
    fake = FakeLLM("I'm sorry, I can't help with that.")
    e = RoomRentCapExtractor(llm_client=fake)
    r = _run(e.extract(_uuid(), SAMPLE_PAGES))
    assert r is None


# --- 4. orchestrator (mocked substrate) ---

def _uuid():
    from uuid import uuid4
    return uuid4()


def _mock_substrate_with_pages(document_id, page_numbers):
    """Returns a mocked EvidenceSubstrateService that knows about
    page_artifacts for the given page numbers."""
    substrate = EvidenceSubstrateService(
        "https://x.supabase.co", "test-key", client=MagicMock()
    )
    # Set up get_page_artifacts_for_document to return typed rows
    from src.models.evidence import PageArtifact
    from datetime import datetime, timezone
    pages = []
    for pn in page_numbers:
        pages.append(
            PageArtifact(
                id=str(_uuid()),
                document_id=str(document_id),
                page_number=pn,
                image_uri=f"coverwise-documents/{document_id}/pages/{pn}.png",
                ocr_text=None,
                layout_json=None,
                sha256="0" * 64,
                created_at=datetime.now(timezone.utc),
            )
        )
    substrate.get_page_artifacts_for_document = AsyncMock(return_value=pages)
    substrate.append_extracted_field = AsyncMock(
        side_effect=lambda **kw: _uuid()
    )
    substrate.link_field_evidence = AsyncMock(side_effect=lambda **kw: _uuid())
    substrate.record_extraction_cost = AsyncMock(side_effect=lambda r: _uuid())
    return substrate


def test_orchestrator_runs_all_extractors():
    document_id = _uuid()
    substrate = _mock_substrate_with_pages(document_id, [1, 2])

    fake = FakeLLM(
        _room_rent_payload(
            True,
            "Room rent: 1% of sum insured, max ₹5,000/day",
            "1% of sum insured, max ₹5,000/day",
        )
    )
    pipeline = EvidencePipeline(substrate=substrate, llm_client=fake)
    result = _run(pipeline.run_for_document(document_id, SAMPLE_PAGES))
    # 6 deterministic + 1 LLM = 7 attempted
    # 5 deterministic present in sample (policy_number, holder, sum, start_date, premium, insurer) = 6
    # + 1 LLM room_rent_cap present = 7
    # All 7 should be cited
    assert result.fields_extracted == 7
    assert result.fields_cited == 7
    assert result.fields_rejected == 0
    assert result.total_cost_usd == 0.0  # no real LLM call was made
    assert "evidence-pipeline-v1-" in result.parser_version


def test_orchestrator_records_zero_cost_for_absent_fields():
    """Even when a deterministic extractor returns None (field
    not present), the orchestrator records a zero-cost row so
    the operator dashboard can see the pipeline tried every
    field."""
    document_id = _uuid()
    substrate = _mock_substrate_with_pages(document_id, [1])
    pages = {1: "Document with no policy data at all."}
    pipeline = EvidencePipeline(substrate=substrate, llm_client=None)
    result = _run(pipeline.run_for_document(document_id, pages))
    assert result.fields_extracted == 0
    assert result.fields_cited == 0
    # 6 deterministic + 0 LLM = 6 attempted
    assert substrate.record_extraction_cost.call_count == 6


def test_orchestrator_rejects_cited_page_without_artifact():
    """If an extractor cites page 5 but the substrate only has
    page_artifact for pages 1-3, the field is rejected."""
    document_id = _uuid()
    substrate = _mock_substrate_with_pages(document_id, [1, 2])  # no page 3
    pages = {
        1: "Policy No: ABC1234567",
        3: "Sum Insured: 5,00,000",  # cited page doesn't exist
    }
    pipeline = EvidencePipeline(substrate=substrate, llm_client=None)
    result = _run(pipeline.run_for_document(document_id, pages))
    # policy_number cites page 1 (exists) -> cited
    # sum_insured cites page 3 (does not exist) -> rejected
    assert result.fields_cited == 1
    assert result.fields_rejected == 1


def test_orchestrator_handles_missing_llm_client():
    """If no LLM client is provided, only the 6 deterministic
    extractors run."""
    document_id = _uuid()
    substrate = _mock_substrate_with_pages(document_id, [1, 2])
    pipeline = EvidencePipeline(substrate=substrate, llm_client=None)
    result = _run(pipeline.run_for_document(document_id, SAMPLE_PAGES))
    # 6 deterministic, all present in SAMPLE_PAGES
    assert result.fields_extracted == 6
    assert result.fields_cited == 6


def test_orchestrator_parser_version_is_unique_per_run():
    """Two pipelines constructed in the same second have
    different parser_version (timestamp + microsecond fallback
    in v2). For v1 we just verify the format."""
    document_id = _uuid()
    substrate = _mock_substrate_with_pages(document_id, [1])
    p1 = EvidencePipeline(substrate=substrate, llm_client=None)
    p2 = EvidencePipeline(substrate=substrate, llm_client=None)
    # Both have the v1 prefix; if they happen to land in the
    # same second they could collide, but the format is
    # stable.
    assert p1._parser_version.startswith("evidence-pipeline-v1-")
    assert p2._parser_version.startswith("evidence-pipeline-v1-")
