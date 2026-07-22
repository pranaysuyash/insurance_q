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

The migration is incremental. This handler, substrate extraction, and account
deletion are registered today; the remaining job types still lack production
handlers and must be migrated deliberately.
"""
from __future__ import annotations

import logging
import os

from src.models.job_outbox import OutboxJob

log = logging.getLogger(__name__)


async def handle_document_processing(job: OutboxJob) -> None:
    """Run the document processing pipeline for the job's
    payload. The payload is a JSON object with:
      - document_id: the document UUID
      - object_reference: canonical source-object reference
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
    object_reference = payload.get("object_reference")
    if not object_reference:
        raise ValueError("document_processing job missing object_reference")

    # Lazy import: the document processing service is heavy and
    # only needed when a job is dispatched.
    from src.services.document_processing_service import (
        DocumentProcessingService,
    )
    from src.services.job_outbox_service import JobOutboxService
    from src.services.document_processing_job import run_document_processing_job
    from src.services.document_object_store import create_document_object_store
    from src.services.document_repository import create_document_repository

    repository = create_document_repository()
    document = repository.get(document_id, owner_id)
    if not document:
        raise ValueError("document_processing job document is missing or not owned by owner_id")
    file_content = create_document_object_store().get(object_reference)
    envelope = payload.get("processing_inputs_envelope")
    if envelope:
        from src.utils.secure_processing_payload import decrypt_processing_inputs

        processing_inputs = decrypt_processing_inputs(
            document_id=str(document_id), envelope=str(envelope)
        )
        pdf_password = processing_inputs.get("pdf_password")
        on_device_ocr_text = processing_inputs.get("on_device_ocr_text")
    else:
        if os.getenv("ENVIRONMENT", "development").lower() == "production" and (
            payload.get("pdf_password") or payload.get("on_device_ocr_text")
        ):
            raise ValueError("plaintext processing inputs are forbidden in production jobs")
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
        rag = RAGPipeline()
        store = create_document_object_store()
        service = DocumentProcessingService(
            rag_pipeline=rag,
            document_object_store=store,
            document_repository=repository,
            job_outbox_service=JobOutboxService.from_env(),
        )
        handle_document_processing._service = service

    result = await run_document_processing_job(
        service=service,
        repository=repository,
        document_id=document_id,
        filename=filename,
        processing_mode=processing_mode,
        owner_id=owner_id,
        file_content=file_content,
        pdf_password=pdf_password,
        on_device_ocr_text=on_device_ocr_text,
        terminal_failure_on_exception=job.attempts >= job.max_attempts,
    )
    log.info(
        "document_processing_job_completed job_id=%s document_id=%s status=%s",
        job.id, document_id, (result or {}).get("status"),
    )
