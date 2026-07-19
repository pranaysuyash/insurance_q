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
  - payload.page_texts: {1: 'page 1 text', 2: 'page 2 text', ...}
  - payload.parser_version: optional; defaults to the current
    pipeline's parser_version

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
    """Run the evidence pipeline on the job's page_texts.
    Writes cited fields to the substrate via
    EvidenceSubstrateService.
    """
    payload = job.payload
    document_id = payload.get("document_id")
    if not document_id:
        raise ValueError("substrate_extraction job missing document_id")
    page_texts = payload.get("page_texts")
    if not page_texts or not isinstance(page_texts, dict):
        raise ValueError(
            "substrate_extraction job missing or invalid page_texts"
        )

    log.info(
        "substrate_extraction_job_started job_id=%s document_id=%s pages=%d",
        job.id, document_id, len(page_texts),
    )

    # Lazy imports: the substrate and pipeline are heavy and
    # only needed when a job is dispatched.
    from uuid import UUID
    from src.services.evidence_substrate_service import (
        EvidenceSubstrateService,
    )
    from src.services.evidence_pipeline import EvidencePipeline

    substrate = EvidenceSubstrateService.from_env()
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
