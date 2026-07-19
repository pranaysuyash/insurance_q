"""Test that the document processing pipeline invokes the
evidence pipeline on a successful upload.

Per the 2026-07-19 review, the evidence system was a
contract without execution: the schema, extractor, API, and
UI existed, but ordinary uploads did not populate the
substrate. This test pins the integration: the
EvidencePipeline.run_for_document() method MUST be called
when the document processing succeeds, and the result must
be recorded in `result["stages"]["evidence_extraction"]`.

The test mocks the substrate and pipeline so the test
does not need a real Supabase project.
"""

import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


def _stub_ocr_result():
    return {
        "full_text": "Policy number ABC1234567\nSum insured 5,00,000\nHDFC ERGO",
        "page_texts": {
            1: "Policy number ABC1234567\nSum insured 5,00,000",
            2: "HDFC ERGO\nPremium 12,500",
        },
        "status": "completed",
        "method": "direct_text",
    }


@pytest.fixture
def mock_substrate(monkeypatch):
    """Stub the EvidenceSubstrateService. from_env returns a
    service whose methods are AsyncMock. Uses monkeypatch so
    the classmethod is restored after the test, preventing
    leaks into other tests."""
    from src.services import evidence_substrate_service as ess_module

    service = MagicMock()
    service.get_or_create_salt = AsyncMock(return_value=b"\x00" * 32)
    service.get_field_citations = AsyncMock(return_value=[])
    service.append_extracted_field = AsyncMock(return_value=None)
    service.link_field_evidence = AsyncMock(return_value=None)
    service.record_extraction_cost = AsyncMock(return_value=None)
    monkeypatch.setattr(
        ess_module.EvidenceSubstrateService,
        "from_env",
        classmethod(lambda cls: service),
    )
    return service


@pytest.mark.asyncio
async def test_evidence_pipeline_invoked_on_successful_upload(
    mock_substrate, monkeypatch
):
    """The document processing pipeline must invoke
    EvidencePipeline.run_for_document() when:
      1. processing_mode is 'full' (the default).
      2. The OCR produced page_texts.
      3. The substrate is configured (env vars set).
      4. The document is for a real owner.
    """
    # Force the helper to return True (substrate is configured).
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-key")

    from src.services.document_processing_service import (
        DocumentProcessingService,
    )
    from src.services.evidence_pipeline import EvidencePipeline, PipelineResult

    service = DocumentProcessingService(
        rag_pipeline=MagicMock(),
    )

    # Stub the OCR + storage so we control the inputs.
    service._save_file = AsyncMock(return_value="/tmp/fake.pdf")
    service._extract_text = AsyncMock(return_value=_stub_ocr_result())
    service._ingest_into_rag = AsyncMock(return_value={"status": "completed"})
    service._extract_entity_blocks = AsyncMock(return_value=[])

    # Mock the EvidencePipeline class so we can assert
    # run_for_document was called with the right inputs.
    with patch(
        "src.services.evidence_pipeline.EvidencePipeline"
    ) as MockPipeline:
        # The class itself returns an instance; the instance's
        # run_for_document is awaited. Set up both.
        instance = MagicMock()
        instance.run_for_document = AsyncMock(
            return_value=PipelineResult(
                document_id=MagicMock(),
                fields_extracted=7,
                fields_cited=7,
                fields_rejected=0,
                total_cost_usd=0.0,
                parser_version="evidence-pipeline-v1-test",
                duration_seconds=0.5,
            )
        )
        MockPipeline.return_value = instance
        result = await service.process_document_full(
            file_content=b"fake",
            filename="test.pdf",
            document_id="11111111-1111-1111-1111-111111111111",
            processing_mode="full",
            owner_id="user-1",
        )

    # The evidence extraction stage must be present and completed.
    assert "evidence_extraction" in result["stages"]
    stage = result["stages"]["evidence_extraction"]
    assert stage["status"] == "completed"
    assert stage["fields_extracted"] == 7
    assert stage["fields_cited"] == 7
    assert stage["fields_rejected"] == 0
    assert stage["parser_version"] == "evidence-pipeline-v1-test"

    # The pipeline was constructed and run_for_document was called.
    instance.run_for_document.assert_awaited_once()
    call_kwargs = instance.run_for_document.await_args.kwargs
    assert call_kwargs["document_id"].hex == "11111111111111111111111111111111"
    # The page_texts are passed through; the evidence pipeline
    # uses them for its 6 deterministic + 1 LLM extractor.
    assert call_kwargs["page_texts"] == _stub_ocr_result()["page_texts"]


@pytest.mark.asyncio
async def test_evidence_pipeline_skipped_when_substrate_not_configured(
    monkeypatch
):
    """When SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing,
    the evidence pipeline is skipped (not failed). The document
    is still processed; the policy detail screen shows the
    'Not yet verified' scaffold because the substrate is empty.
    """
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)

    from src.services.document_processing_service import (
        DocumentProcessingService,
    )
    from src.services.evidence_pipeline import EvidencePipeline

    service = DocumentProcessingService(rag_pipeline=MagicMock())
    service._save_file = AsyncMock(return_value="/tmp/fake.pdf")
    service._extract_text = AsyncMock(return_value=_stub_ocr_result())
    service._ingest_into_rag = AsyncMock(return_value={"status": "completed"})
    service._extract_entity_blocks = AsyncMock(return_value=[])

    with patch(
        "src.services.evidence_pipeline.EvidencePipeline"
    ) as MockPipeline:
        # No return_value set; the pipeline is not constructed.
        result = await service.process_document_full(
            file_content=b"fake",
            filename="test.pdf",
            document_id="22222222-2222-2222-2222-222222222222",
            processing_mode="full",
            owner_id="user-1",
        )

    # The evidence stage is recorded as skipped, not failed.
    assert "evidence_extraction" in result["stages"]
    stage = result["stages"]["evidence_extraction"]
    assert stage["status"] == "skipped"
    assert "Substrate not configured" in stage["reason"]
    # The pipeline class was never instantiated (the helper
    # returned False, so the if-branch was skipped).
    MockPipeline.assert_not_called()


@pytest.mark.asyncio
async def test_evidence_pipeline_failure_does_not_fail_document(
    mock_substrate, monkeypatch
):
    """If the evidence pipeline fails, the document is still
    processed (the user gets a real result). The failure is
    recorded in the result; the policy detail screen shows the
    'Not yet verified' scaffold (the substrate is empty for
    this document)."""
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-key")

    from src.services.document_processing_service import (
        DocumentProcessingService,
    )

    service = DocumentProcessingService(rag_pipeline=MagicMock())
    service._save_file = AsyncMock(return_value="/tmp/fake.pdf")
    service._extract_text = AsyncMock(return_value=_stub_ocr_result())
    service._ingest_into_rag = AsyncMock(return_value={"status": "completed"})
    service._extract_entity_blocks = AsyncMock(return_value=[])

    with patch(
        "src.services.evidence_pipeline.EvidencePipeline"
    ) as MockPipeline:
        instance = MagicMock()
        instance.run_for_document = AsyncMock(
            side_effect=RuntimeError("substrate write failed")
        )
        MockPipeline.return_value = instance
        result = await service.process_document_full(
            file_content=b"fake",
            filename="test.pdf",
            document_id="33333333-3333-3333-3333-333333333333",
            processing_mode="full",
            owner_id="user-1",
        )

    # The evidence stage is recorded as failed (not propagated).
    assert "evidence_extraction" in result["stages"]
    stage = result["stages"]["evidence_extraction"]
    assert stage["status"] == "failed"
    assert "Evidence extraction failed" in stage["error"]
    # The document processing itself succeeds.
    assert result["status"] in ("completed", "completed_no_summary", "completed_summary_partial", "completed_text_partial")
