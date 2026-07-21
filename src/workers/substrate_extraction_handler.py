"""Outbox handler for `substrate_extraction` jobs.

Per ADR-2026-07-19-01, the durable work queue is the canonical
async path. This handler is the v1 implementation for the
`substrate_extraction` job type: when a document is processed
and the parser pipeline needs to extract cited fields, the
worker dispatches the job to this handler.

In the current (2026-07-19) wiring, the substrate extraction
is invoked from within `process_document_full` as Stage 3.5.
This handler exists for the case where the extraction is
enqueued separately — e.g. a re-extraction triggered by a
parser-version bump, or a user-initiated "re-run extraction"
action.

The handler's contract:
  - payload.document_id: the document UUID
  - payload.owner_id: the verified owner identity (for audit/logging)
  - page OCR is reloaded from the persisted page_artifacts rows; raw OCR is
    never placed in the queue payload.

The handler is idempotent: the substrate is append-only, so
re-running produces new rows (with new parser_version) rather
than overwriting. The UI shows the latest row per
(document, field).
"""
from __future__ import annotations

import logging

from src.models.job_outbox import OutboxJob

log = logging.getLogger(__name__)


async def handle_substrate_extraction(job: OutboxJob) -> None:
    """Run the evidence pipeline on persisted page OCR.
    Writes cited fields to the substrate via
    EvidenceSubstrateService.
    """
    payload = job.payload
    document_id = payload.get("document_id")
    if not document_id:
        raise ValueError("substrate_extraction job missing document_id")
    owner_id = payload.get("owner_id")
    if not owner_id:
        raise ValueError("substrate_extraction job missing owner_id")

    # Lazy imports: the substrate and pipeline are heavy and
    # only needed when a job is dispatched.
    from uuid import UUID
    from src.services.document_repository import create_document_repository
    from src.services.evidence_substrate_service import (
        EvidenceSubstrateService,
    )
    from src.services.evidence_pipeline import EvidencePipeline

    repository = create_document_repository()
    if repository.get(str(document_id), str(owner_id)) is None:
        raise ValueError("substrate_extraction job document is missing or not owned by owner_id")
    substrate = EvidenceSubstrateService.from_env()
    artifacts = await substrate.get_page_artifacts_for_document(UUID(document_id))
    page_texts = {
        artifact.page_number: artifact.ocr_text
        for artifact in artifacts
        if artifact.ocr_text
    }
    if not page_texts:
        raise ValueError("substrate_extraction has no persisted page OCR")
    log.info(
        "substrate_extraction_job_started job_id=%s document_id=%s pages=%d",
        job.id, document_id, len(page_texts),
    )
    pipeline = EvidencePipeline(substrate=substrate)
    result = await pipeline.run_for_document(
        document_id=UUID(document_id),
        page_texts={int(k): v for k, v in page_texts.items()},
    )
    log.info(
        "substrate_extraction_job_completed job_id=%s document_id=%s "
        "extracted=%d cited=%d rejected=%d",
        job.id, document_id, result.fields_extracted,
        result.fields_cited, result.fields_rejected,
    )
