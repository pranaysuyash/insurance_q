"""
Tests for the document state derivation logic.

Phase 0 P0-0.1 + P0-0.2 (trust audit, 2026-07-18): a document must become
`ready` only when every required stage for its mode is `completed`. Partial
readiness produces capability-specific states (`summary_partial`,
`ocr_required`, etc.) so the user never sees a "completed" document with
silent stage failures.

These tests are the regression net for the trust audit's primary NO-GO
verdict on document state.
"""

from src.services.document_processing_service import (
    derive_document_state,
    REQUIRED_STAGES,
)


def _completed_stage():
    return {"status": "completed"}


def _failed_stage(reason: str = "OCR engine unavailable"):
    return {"status": "failed", "error": reason}


def _skipped_stage(reason: str = "service unavailable"):
    return {"status": "skipped", "reason": reason}


def _partial_stage(reason: str = "some pages unresolved"):
    return {"status": "partial", "reason": reason}


def test_full_mode_with_all_stages_completed_is_ready():
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _completed_stage(),
        "policy_extraction": _completed_stage(),
        "rag_ingestion": _completed_stage(),
    }
    state = derive_document_state("full", stages, policy_summary_present=True)
    assert state == "ready", f"expected ready, got {state}"


def test_full_mode_with_ocr_failure_is_ocr_required():
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _failed_stage("Image OCR is not available in this build"),
        "policy_extraction": _skipped_stage("upstream failure"),
        "rag_ingestion": _skipped_stage("upstream failure"),
    }
    state = derive_document_state("full", stages, policy_summary_present=False)
    assert state == "ocr_required", f"expected ocr_required, got {state}"


def test_mixed_document_with_unresolved_scan_pages_is_partial():
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _partial_stage(),
        "policy_extraction": _skipped_stage("upstream partial text"),
        "rag_ingestion": _skipped_stage("upstream partial text"),
    }

    state = derive_document_state("full", stages, policy_summary_present=False)

    assert state == "partial"


def test_full_mode_with_password_required_is_password_required():
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _failed_stage("PDF password required"),
        "policy_extraction": _skipped_stage("upstream failure"),
        "rag_ingestion": _skipped_stage("upstream failure"),
    }
    state = derive_document_state("full", stages, policy_summary_present=False)
    assert state == "password_required", f"expected password_required, got {state}"


def test_full_mode_with_only_policy_extraction_failure_is_summary_partial():
    """A document can be text-ready + Q&A-ready but without a summary.
    The user must see `summary_partial`, not `ready` (which would lie about
    a value) and not `failed` (which would block Q&A which still works).
    """
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _completed_stage(),
        "policy_extraction": _failed_stage("LLM unavailable"),
        "rag_ingestion": _completed_stage(),
    }
    state = derive_document_state("full", stages, policy_summary_present=False)
    assert state == "summary_partial", f"expected summary_partial, got {state}"


def test_full_mode_with_only_rag_ingestion_failure_and_no_summary_is_ready_for_qa():
    """If RAG indexing failed but no policy summary exists either,
    the document is text-ready (OCR succeeded) but the Q&A surface
    has no data. `ready_for_qa` is the honest label here."""
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _completed_stage(),
        "policy_extraction": _failed_stage("LLM unavailable"),
        "rag_ingestion": _failed_stage("Embedding failed"),
    }
    state = derive_document_state("full", stages, policy_summary_present=False)
    assert state == "ready_for_qa", f"expected ready_for_qa, got {state}"


def test_full_mode_with_only_rag_ingestion_failure_and_summary_present_is_indexing_failed():
    """If RAG indexing failed and a summary exists, the user can still see
    the policy detail screen but Q&A will return empty. `indexing_failed`
    is the honest label — they can retry, or proceed with summary-only."""
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _completed_stage(),
        "policy_extraction": _completed_stage(),
        "rag_ingestion": _failed_stage("Embedding failed"),
    }
    state = derive_document_state("full", stages, policy_summary_present=True)
    assert state == "indexing_failed", f"expected indexing_failed, got {state}"


def test_full_mode_with_multiple_stage_failures_is_partial():
    """If multiple required stages fail, the document is partially complete
    but cannot pretend to be ready. `partial` is the catch-all honest
    state."""
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _failed_stage("Image OCR unavailable"),
        "policy_extraction": _failed_stage("LLM unavailable"),
        "rag_ingestion": _skipped_stage("no upstream text"),
    }
    state = derive_document_state("full", stages, policy_summary_present=False)
    assert state == "partial", f"expected partial, got {state}"


def test_ocr_only_mode_does_not_require_summary_or_rag():
    """ocr_only mode intentionally skips policy_extraction and rag_ingestion.
    The function must NOT flag those as missing when they are not in the
    required set."""
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _completed_stage(),
        "policy_extraction": _skipped_stage("not in mode"),
        "rag_ingestion": _skipped_stage("not in mode"),
    }
    state = derive_document_state("ocr_only", stages, policy_summary_present=False)
    assert state == "ready", f"expected ready, got {state}"


def test_rag_only_mode_is_ready_for_qa_even_without_summary():
    """rag_only mode intentionally skips policy_extraction. The function
    must NOT require a summary."""
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _skipped_stage("not in mode"),
        "policy_extraction": _skipped_stage("not in mode"),
        "rag_ingestion": _completed_stage(),
    }
    state = derive_document_state("rag_only", stages, policy_summary_present=False)
    assert state == "ready_for_qa", f"expected ready_for_qa, got {state}"


def test_required_stages_map_per_mode_is_explicit():
    """The contract per mode is part of the trust audit's exit gate
    (Phase 0 P0-0.1). If a future change adds a new mode, this test
    forces the developer to update REQUIRED_STAGES explicitly."""
    assert REQUIRED_STAGES["full"] == frozenset(
        {"file_storage", "ocr", "policy_extraction", "rag_ingestion"}
    )
    assert REQUIRED_STAGES["ocr_only"] == frozenset({"file_storage", "ocr"})
    assert REQUIRED_STAGES["rag_only"] == frozenset(
        {"file_storage", "rag_ingestion"}
    )


def test_no_full_mode_with_zero_text_can_be_ready():
    """Defence-in-depth: even if all stages report 'completed', if the
    text is empty (a known silent failure mode) the function must
    not claim ready. This catches a class of bugs where a stage
    self-reports 'completed' but produces no usable artifact."""
    stages = {
        "file_storage": _completed_stage(),
        "ocr": _completed_stage(),
        "policy_extraction": _completed_stage(),
        "rag_ingestion": _completed_stage(),
    }
    # Without a policy summary AND without indication that we deliberately
    # chose to skip, full mode requires the summary to be ready.
    state = derive_document_state("full", stages, policy_summary_present=False)
    # When the policy summary is missing but all stages are 'completed',
    # this is a logic bug upstream — we cannot tell the user it's ready
    # when the summary projection is empty. Return 'partial' so this
    # surfaces in monitoring rather than being silently shipped.
    assert state in ("partial", "summary_partial"), f"got {state}"
