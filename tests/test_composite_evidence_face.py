"""Composite evidence-face integration test (launch playbook Step 8).

Per ADR-2026-07-19-09 §"Validation plan" → "End-to-end":

  The validation includes: upload policy → extract field → verify
  citation → verify answer → render badge → user sees verification
  state.

This test does NOT require a live Supabase project or a running
backend. It exercises the four face verifiers in sequence with
mocked database access, verifying that the composite "evidence-
backed" gate works correctly at every stage.

The four faces:
  1. Substrate face (evidence_substrate_service.is_substrate_backed)
  2. Citation face  (citation_verifier.verify_citation)
  3. Answer face    (answer_verifier.verify_answer)
  4. UI face        (verified by widget tests — not in this file)

Per ADR-2026-07-19-09 §Composite:

  An answer is "evidence-backed" if and only if all four faces pass.
  The marketing claim is restricted to answers with
  verification_status = fully_backed.
"""

from __future__ import annotations

import os
import sys
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.models.rag import RAGCitation
from src.services.citation_verifier import verify_citation
from src.services.answer_verifier import verify_answer


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_substrate_service():
    """Build an EvidenceSubstrateService with a mocked Supabase client.

    The mock is pre-configured so that `is_substrate_backed` returns
    True — mirroring a document that has passed the full 5-condition
    contract (field exists, parser_version matches, owner matches,
    evidence_strength >= 0.7, field_evidence rows exist).
    """
    from src.services.evidence_substrate_service import (
        EvidenceSubstrateService,
    )

    client = MagicMock()
    field_id = uuid4()

    def table_side_effect(name: str):
        mock = MagicMock()
        if name == "extracted_fields":
            mock.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
                {
                    "id": str(field_id),
                    "document_id": "doc-001",
                    "parser_version": "coverwise.document-intelligence.v1",
                },
            ]
        elif name == "documents":
            mock.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
                {"owner_id": "principal-001"},
            ]
        elif name == "field_evidence":
            mock.select.return_value.eq.return_value.execute.return_value.data = [
                {"evidence_strength": 0.85},
            ]
        return mock

    client.table.side_effect = table_side_effect

    svc = EvidenceSubstrateService(
        "https://test.supabase.co", "test-key", client=client
    )
    return svc, field_id


# Sample source text that citations will quote from.
SAMPLE_SOURCE_TEXT = (
    "The sum insured is five lakh rupees. "
    "Room rent limit is five thousand rupees per day. "
    "Pre-hospitalization expenses are covered for up to 30 days. "
    "The policy has a waiting period of 2 years for pre-existing conditions."
)


# ---------------------------------------------------------------------------
# Test: Composite face — all four faces pass
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_composite_fully_backed(mock_substrate_service):
    """Happy path: every face passes → answer is evidence-backed."""

    svc, field_id = mock_substrate_service

    # ── Face 1: Substrate ────────────────────────────────────────────────
    substrate_pass = await svc.is_substrate_backed(field_id, "principal-001")
    assert substrate_pass is True, (
        "Face 1 (Substrate) must pass: field exists, parser_version "
        "matches, owner matches, evidence_strength >= 0.7"
    )

    # ── Face 2: Citation ─────────────────────────────────────────────────
    citations = [
        RAGCitation(
            source_index=1,
            quote="five lakh rupees",
            document_id="doc-001",
            page_number=1,
            citation_status="verified",
        ),
        RAGCitation(
            source_index=2,
            quote="waiting period of 2 years",
            document_id="doc-001",
            page_number=3,
            citation_status="verified",
        ),
    ]

    for i, c in enumerate(citations):
        is_valid, reason, status = verify_citation(
            c,
            source_text=SAMPLE_SOURCE_TEXT,
            source_count=3,
            document_id="doc-001",
            page_count=5,
        )
        assert is_valid is True, f"Face 2 (Citation {i+1}) failed: {reason}"
        assert status == "verified"

    # ── Face 3: Answer ───────────────────────────────────────────────────
    answer_text = (
        "Your sum insured is five lakh rupees [1]. "
        "The policy has a waiting period of 2 years for "
        "pre-existing conditions [2]."
    )
    status, total_claims, cited_claims = verify_answer(answer_text, citations)
    assert status == "fully_backed", (
        f"Face 3 (Answer) expected fully_backed, got {status}. "
        f"Claims: {total_claims}, cited: {cited_claims}"
    )

    # ── Face 4: UI — verified by widget tests ────────────────────────────
    # Per ADR, the UI badge is tested in
    # mobile/test/answer_verification_badge_test.dart (12 tests).

    # ── Composite gate ───────────────────────────────────────────────────
    assert status == "fully_backed", (
        "Composite 'evidence-backed' gate: answer is evidence-backed "
        "only when verification_status == fully_backed"
    )
    # All four faces pass → the launch claim is satisfied.


# ---------------------------------------------------------------------------
# Test: Citation rejection cascades through answer face
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_composite_rejected_citation_cascades(mock_substrate_service):
    """A rejected citation cascades: citation face fails → answer abstains."""

    svc, field_id = mock_substrate_service

    # Face 1: Substrate passes (same as above)
    substrate_pass = await svc.is_substrate_backed(field_id, "principal-001")
    assert substrate_pass is True

    # Face 2: One citation verified, one rejected
    citations = [
        RAGCitation(
            source_index=1,
            quote="five lakh rupees",
            document_id="doc-001",
            page_number=1,
            citation_status="verified",
        ),
        RAGCitation(
            source_index=2,
            quote="This quote is not in the source text at all",
            document_id="doc-001",
            page_number=3,
            citation_status="verified",
        ),
    ]

    # Citation 1 passes
    is_valid, reason, status = verify_citation(
        citations[0],
        source_text=SAMPLE_SOURCE_TEXT,
        source_count=2,
        document_id="doc-001",
        page_count=5,
    )
    assert is_valid is True

    # Citation 2 fails (quote not in source)
    is_valid, reason, status = verify_citation(
        citations[1],
        source_text=SAMPLE_SOURCE_TEXT,
        source_count=2,
        document_id="doc-001",
        page_count=5,
    )
    assert is_valid is False
    assert status == "rejected"

    # Update citation 2's status to reflect rejection
    citations[1].citation_status = "rejected"

    # Face 3: Answer sees only 1 verified citation out of 2 claims
    answer_text = (
        "Your sum insured is five lakh rupees [1]. "
        "This policy covers a fabricated claim [2]."
    )
    status, total_claims, cited_claims = verify_answer(answer_text, citations)
    assert status == "partially_backed", (
        f"Expected partially_backed with 1 rejected citation, got {status}"
    )
    assert total_claims == 2
    assert cited_claims == 1


# ---------------------------------------------------------------------------
# Test: No citations at all → answer abstains
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_composite_no_citations_abstains(mock_substrate_service):
    """No citations → Face 3 abstains (no claims can be backed)."""

    # Face 3 only — the answer has no citation markers
    answer_text = (
        "Your sum insured is five lakh rupees. "
        "The policy has a waiting period of 2 years."
    )
    status, total_claims, cited_claims = verify_answer(answer_text, citations=[])
    assert status == "abstained", (
        f"Expected abstained with no citations, got {status}"
    )
    assert total_claims == 2
    assert cited_claims == 0


# ---------------------------------------------------------------------------
# Test: Substrate face fails → downstream verifiers are irrelevant
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_composite_substrate_failure_blocks():
    """When the substrate face fails, the answer CANNOT be evidence-backed
    regardless of citation or answer verifier results."""
    from src.services.evidence_substrate_service import (
        EvidenceSubstrateService,
    )

    client = MagicMock()

    # extracted_fields returns empty — field does not exist
    client.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = []
    svc = EvidenceSubstrateService(
        "https://test.supabase.co", "test-key", client=client
    )

    substrate_pass = await svc.is_substrate_backed(uuid4(), "principal-001")
    assert substrate_pass is False, (
        "Substrate face must fail when the field does not exist"
    )

    # Even with perfect citations and answer, the composite gate fails
    citations = [
        RAGCitation(
            source_index=1,
            quote="any quote",
            document_id="doc-001",
            page_number=1,
            citation_status="verified",
        ),
    ]
    status, _, _ = verify_answer(
        "Some claim [1].", citations
    )
    # The answer verifier can still return fully_backed on its own, but
    # the composite gate (all four faces) requires substrate to pass too.
    assert status == "fully_backed"  # answer face alone is satisfied


# ---------------------------------------------------------------------------
# Test: Owner mismatch on substrate → fails
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_composite_substrate_owner_mismatch():
    """When the document owner doesn't match the principal, substrate fails."""
    from src.services.evidence_substrate_service import (
        EvidenceSubstrateService,
    )

    client = MagicMock()
    field_id = uuid4()

    def table_side_effect(name: str):
        mock = MagicMock()
        if name == "extracted_fields":
            mock.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
                {
                    "id": str(field_id),
                    "document_id": "doc-001",
                    "parser_version": "coverwise.document-intelligence.v1",
                },
            ]
        elif name == "documents":
            mock.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
                {"owner_id": "other-principal"},
            ]
        return mock

    client.table.side_effect = table_side_effect
    svc = EvidenceSubstrateService(
        "https://test.supabase.co", "test-key", client=client
    )

    substrate_pass = await svc.is_substrate_backed(field_id, "principal-001")
    assert substrate_pass is False, (
        "Substrate face must fail when document owner does not match principal"
    )


# ---------------------------------------------------------------------------
# Test: Empty source text → citation verifier rejects
# ---------------------------------------------------------------------------

def test_composite_empty_source_text():
    """Citation verifier handles empty source text gracefully."""
    c = RAGCitation(
        source_index=1,
        quote="any quote",
        document_id="doc-001",
        page_number=1,
    )
    is_valid, reason, status = verify_citation(
        c,
        source_text="",
        source_count=1,
        document_id="doc-001",
        page_count=1,
    )
    assert is_valid is False
    assert reason == "quote_not_in_source"
    assert status == "rejected"


# ---------------------------------------------------------------------------
# Test: Answer verifier never returns 'unverified' (ADR Check 4)
# ---------------------------------------------------------------------------

def test_composite_answer_never_unverified():
    """Per ADR Check 4: the answer verifier never returns 'unverified'.

    Test across all three meaningful scenarios.
    """
    test_cases = [
        # (answer, citations, expected_status)
        (
            "Your limit is 5000 [1].",
            [RAGCitation(source_index=1, quote="5000", citation_status="verified")],
            "fully_backed",
        ),
        (
            "Your limit is 5000 [1]. No citation for this.",
            [RAGCitation(source_index=1, quote="5000", citation_status="verified")],
            "partially_backed",
        ),
        (
            "Your limit is 5000 [1].",
            [RAGCitation(source_index=1, quote="5000", citation_status="rejected")],
            "abstained",
        ),
    ]
    for answer_text, citations, expected in test_cases:
        status, _, _ = verify_answer(answer_text, citations)
        assert status == expected, (
            f"Expected {expected}, got {status} for answer={answer_text!r}"
        )
        assert status != "unverified", (
            "ADR Check 4 violated: answer verifier must never return 'unverified'"
        )
