"""Canonical durable document-processing job runner.

Both the local compatibility path and the outbox worker use this module so
claiming, terminal state persistence, and classification cannot drift.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Optional

log = logging.getLogger(__name__)


async def run_document_processing_job(
    *,
    service: Any,
    repository: Any,
    document_id: str,
    filename: str,
    processing_mode: str,
    owner_id: str,
    file_content: bytes,
    pdf_password: Optional[str] = None,
    on_device_ocr_text: Optional[str] = None,
) -> Optional[dict[str, Any]]:
    """Claim, process, and persist one owner-scoped document job.

    ``None`` means another worker already owns a live lease. The returned
    result is the processing service's canonical result; repository state is
    updated before the function returns.
    """
    if not repository.claim_processing(document_id, owner_id, lease_seconds=900):
        log.info("document_processing_claim_skipped document_id=%s", document_id)
        return None

    try:
        result = await service.process_document_full(
            file_content=file_content,
            filename=filename,
            document_id=document_id,
            processing_mode=processing_mode,
            owner_id=owner_id,
            pdf_password=pdf_password,
            on_device_ocr_text=on_device_ocr_text,
        )
        document = repository.get(document_id, owner_id)
        if document:
            status = str(result.get("status") or "failed")
            document.status = status
            document.processing_lease_expires_at = None
            if status in {"completed", "completed_no_summary", "completed_summary_partial", "completed_text_partial", "ready_for_qa", "partial", "indexing_failed"}:
                document.processing_completed_at = datetime.utcnow()
            if status == "failed":
                document.error_message = "Document processing did not complete. Please retry the upload."
            await _apply_classification(document, result, service, document_id)
            repository.update(document)
        return result
    except Exception:
        log.exception("document_processing_job_failed document_id=%s", document_id)
        document = repository.get(document_id, owner_id)
        if document:
            document.status = "failed"
            document.error_message = "Document processing did not complete. Please retry the upload."
            document.processing_lease_expires_at = None
            repository.update(document)
        raise


async def _apply_classification(
    document: Any, result: dict[str, Any], service: Any, document_id: str
) -> None:
    """Persist best-effort classification without hiding processing state."""
    if result.get("status") == "failed":
        return
    try:
        ocr = result.get("stages", {}).get("ocr", {})
        text_content = ocr.get("full_text", "") if isinstance(ocr, dict) else ""
        if not text_content:
            return
        from src.utils.document_classifier import get_document_classifier
        classifier = get_document_classifier(service.rag_pipeline)
        classification = await classifier.classify_document(document_id, text_content)
        document.document_type = classification.get("document_type", "Insurance Policy")
        document.insurer = classification.get("insurer", "Unknown")
        metadata = dict(document.metadata or {})
        metadata["classification"] = classification
        metadata.update(
            {
                "policy_number": classification.get("policy_number"),
                "effective_date": classification.get("effective_date"),
                "expiration_date": classification.get("expiration_date"),
                "classification_confidence": classification.get("confidence", 0.0),
            }
        )
        document.metadata = metadata
        from src.services.policy_domain_service import sync_document
        rag_ingestion = result.get("stages", {}).get("rag_ingestion", {})
        try:
            sync_document(
                document_id=document_id,
                owner_id=document.user_uid,
                source_hash=document.source_hash,
                metadata=metadata,
                sections=rag_ingestion.get("sections", []) if isinstance(rag_ingestion, dict) else [],
            )
            result.setdefault("stages", {})["policy_domain_projection"] = {
                "status": "completed",
            }
        except Exception as error:
            # Classification success must not hide a failed normalized
            # projection. Keep processing state honest and retain only the
            # bounded error class, never service credentials or raw text.
            result.setdefault("stages", {})["policy_domain_projection"] = {
                "status": "failed",
                "error_type": type(error).__name__,
            }
            metadata["policy_domain_projection_status"] = "failed"
            metadata["policy_domain_projection_error_type"] = type(error).__name__
            document.metadata = metadata
            log.exception(
                "policy_domain_projection_failed document_id=%s error_type=%s",
                document_id,
                type(error).__name__,
            )
    except Exception as error:
        log.warning(
            "document_classification_failed document_id=%s error_type=%s",
            document_id,
            type(error).__name__,
        )
        text = text_content.lower()
        if "health" in text or "medical" in text:
            document.document_type = "Health Insurance"
        elif "auto" in text or "vehicle" in text:
            document.document_type = "Auto Insurance"
        elif "life" in text:
            document.document_type = "Life Insurance"
        else:
            document.document_type = "Insurance Policy"
