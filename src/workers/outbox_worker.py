"""Outbox dispatcher worker entry point.

Run this as a Cloud Run service (or a long-running process) to
process jobs from the job_outbox. The worker:

1. Reclaims stuck leases once per minute.
2. Polls the outbox at 1s intervals.
3. Dispatches claimed jobs to registered handlers.
4. Completes or fails the job based on the handler's result.

The current v1 of this file has the registry empty: handlers
are registered by the existing async-path modules. Each module
that wants to expose a handler calls `dispatcher.register()` at
import time. The migration from the existing in-process poll
loops to outbox-based dispatch is a follow-up per
ADR-2026-07-19-01; this file is the worker's skeleton.
"""
from __future__ import annotations

import asyncio
import logging
import os
import signal

from src.services.job_dispatcher import JobDispatcher
from src.services.job_outbox_service import JobOutboxService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger(__name__)


def _register_handlers(dispatcher: JobDispatcher) -> None:
    """Import and register all known job handlers. Each module
    that exposes a handler must call dispatcher.register() at
    import time.

    Per the 2026-07-19 current-state review: the previous
    version of this file had the registry empty. The outbox
    was a contract without execution. This v2 registers the
    two handlers that are needed for the end-to-end evidence
    path: document processing (which enqueues substrate
    extraction in turn) and substrate extraction (the
    pipeline that produces cited fields). The other 5 job
    types keep their existing in-process paths until their
    migration is designed and implemented (per
    ADR-2026-07-19-02).
    """
    # v1 of the migration: register the two handlers that are
    # needed for the end-to-end evidence path. The other 5
    # job types (qa_response, webhook_reconciliation, etc.)
    # keep their existing in-process paths.
    from src.models.job_outbox import JobType
    from src.workers.document_processing_handler import (
        handle_document_processing,
    )
    from src.workers.substrate_extraction_handler import (
        handle_substrate_extraction,
    )

    dispatcher.register(JobType.DOCUMENT_PROCESSING, handle_document_processing)
    dispatcher.register(JobType.SUBSTRATE_EXTRACTION, handle_substrate_extraction)
    log.info(
        "registered handlers: %s",
        [jt.value for jt in dispatcher.registered_types],
    )
    #   from src.services.webhook_handler import handle_webhook_reconciliation
    #   dispatcher.register(JobType.WEBHOOK_RECONCILIATION, handle_webhook_reconciliation)
    #   from src.services.subscription_handler import handle_subscription_writeback
    #   dispatcher.register(JobType.SUBSCRIPTION_WRITEBACK, handle_subscription_writeback)
    #   from src.services.qa_handler import handle_qa_response
    #   dispatcher.register(JobType.QA_RESPONSE, handle_qa_response)


async def _main() -> None:
    outbox = JobOutboxService.from_env()
    dispatcher = JobDispatcher(outbox)
    _register_handlers(dispatcher)
    log.info("outbox dispatcher worker starting (handlers=%d)",
             len(dispatcher.registered_types))

    # Graceful shutdown on SIGTERM / SIGINT. Cloud Run sends
    # SIGTERM; this loop exits cleanly between dispatch cycles.
    stop = asyncio.Event()

    def _on_signal(*_args) -> None:
        log.info("received shutdown signal")
        stop.set()

    loop = asyncio.get_event_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, _on_signal)

    poll_interval = float(os.getenv("OUTBOX_POLL_INTERVAL_SECONDS", "1.0"))
    await dispatcher.run(
        poll_interval_seconds=poll_interval,
        stop_condition=stop.is_set,
    )
    log.info("outbox dispatcher worker exiting cleanly")


if __name__ == "__main__":
    asyncio.run(_main())
