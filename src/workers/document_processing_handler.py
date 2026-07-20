"""Outbox handler for `document_processing` jobs.

Per ADR-2026-07-19-01, the durable work queue is the canonical
async path for every async work in CoverWise. This handler is
the v1 implementation for the `document_processing` job type:
when a document upload enqueues a `document_processing` job, the
outbox worker dispatches it to this handler, which runs the
document processing pipeline (OCR + classification + RAG
ingestion + evidence extraction).

Per the 2026-07-19 current-state review, the existing in-process
upload path runs `process_document_background` as a FastAPI
background task. This handler is the migration target: the
upload path enqueues a job; the worker dispatches the job to
this handler. The handler's contract is identical to the
in-process call: same arguments, same result, same error
semantics.

The migration is incremental. v1 of the worker registers only
this handler + the substrate_extraction handler. The other 5
job types (`qa_response`, `webhook_reconciliation`, etc.) keep
their existing in-process paths until their migration is
designed and implemented (per ADR-2026-07-19-02).
"""
from __future__ import annotations

import logging
from typing import Any

from src.models.job_outbox import OutboxJob

log = logging.getLogger(__name__)


async def handle_document_processing(job: OutboxJob) -> None:
    """Run the document processing pipeline for the job's
    payload. The payload is a JSON object with:
      - document_id: the document UUID
      - file_content_b64: the base64-encoded file bytes
      - filename: the original filename
      - processing_mode: 'full' / 'ocr_only' / 'rag_only'
      - owner_id: the user's stable principal ID
      - pdf_password: optional
      - on_device_ocr_text: optional
    """
    payload = job.payload
    document_id = payload.get("document_id")
    if not document_id:
        raise ValueError("document_processing job missing document_id")
    filename = payload.get("filename", "unknown")
    processing_mode = payload.get("processing_mode", "full")
    owner_id = payload.get("owner_id")
    if not owner_id:
        raise ValueError("document_processing job missing owner_id")
    file_content_b64 = payload.get("file_content_b64")
    if not file_content_b64:
        raise ValueError("document_processing job missing file_content_b64")

    # Lazy import: the document processing service is heavy and
    # only needed when a job is dispatched.
    import base64
    from src.services.document_processing_service import (
        DocumentProcessingService,
    )

    file_content = base64.b64decode(file_content_b64)
    pdf_password = payload.get("pdf_password")
    on_device_ocr_text = payload.get("on_device_ocr_text")

    log.info(
        "document_processing_job_started job_id=%s document_id=%s owner=%s",
        job.id, document_id, owner_id[:12],
    )

    # The processing service is a module-level singleton in
    # the existing app. The worker initializes one if not
    # already initialized.
    service = getattr(handle_document_processing, "_service", None)
    if service is None:
        # The full DocumentProcessingService requires a RAG
        # pipeline. The worker has the same dependency graph
        # as the main app; in production, both share the same
        # Cloud Run service, so the singleton is the same
        # instance.
        from src.rag.pipeline import RAGPipeline
        from src.services.document_object_store import create_document_object_store
        rag = RAGPipeline()
        store = create_document_object_store()
        service = DocumentProcessingService(rag_pipeline=rag, document_object_store=store)
        handle_document_processing._service = service

    result: dict[str, Any] = await service.process_document_full(
        file_content=file_content,
        filename=filename,
        document_id=document_id,
        processing_mode=processing_mode,
        owner_id=owner_id,
        pdf_password=pdf_password,
        on_device_ocr_text=on_device_ocr_text,
    )
    log.info(
        "document_processing_job_completed job_id=%s document_id=%s status=%s",
        job.id, document_id, result.get("status"),
    )
