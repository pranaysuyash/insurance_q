"""Outbox dispatcher worker entry point.

Run this as a Cloud Run service (or a long-running process) to
process jobs from the job_outbox. The worker:

1. Reclaims stuck leases once per minute.
2. Polls the outbox at 1s intervals.
3. Dispatches claimed jobs to registered handlers.
4. Completes or fails the job based on the handler's result.

Handlers are registered in one dispatcher registry. The production document,
substrate-extraction, RevenueCat reconciliation, and account-deletion paths use
this worker; remaining job types are explicit migration work rather than
silently assumed support.
"""
from __future__ import annotations

import asyncio
import logging
import os
import signal

from src.utils.runtime_config import normalize_supabase_environment
from src.utils.log_config import configure_structlog
from src.utils.sentry_config import init_sentry, shutdown_sentry
from src.services.job_dispatcher import JobDispatcher
from src.services.job_outbox_service import JobOutboxService

normalize_supabase_environment()

# Configure structured JSON logging via the shared config. After this call,
# all logging.getLogger(__name__) calls in this process produce JSON output.
configure_structlog(service_name="worker")

log = logging.getLogger(__name__)


async def _health_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    """Answer Cloud Run liveness/readiness probes without touching the queue."""
    try:
        request = await asyncio.wait_for(reader.read(4096), timeout=2.0)
        request_line = request.splitlines()[0].decode("ascii", errors="ignore") if request else ""
        parts = request_line.split(" ")
        path = parts[1] if len(parts) >= 2 else "/"
        status = "200 OK" if path in {"/", "/healthz", "/readyz"} else "404 Not Found"
        body = b'{"status":"ready","worker":"outbox"}' if status == "200 OK" else b'{"detail":"not found"}'
        response = (
            f"HTTP/1.1 {status}\r\n"
            "Content-Type: application/json\r\n"
            f"Content-Length: {len(body)}\r\n"
            "Connection: close\r\n\r\n"
        ).encode("ascii") + body
        writer.write(response)
        await writer.drain()
    except (asyncio.TimeoutError, ConnectionError):
        log.debug("worker health client disconnected before response")
    finally:
        writer.close()
        await writer.wait_closed()


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
    # Register every durable production path that has a handler. Unregistered
    # job types fail visibly in the dispatcher instead of disappearing.
    from src.models.job_outbox import JobType
    from src.workers.document_processing_handler import (
        handle_document_processing,
    )
    from src.workers.substrate_extraction_handler import (
        handle_substrate_extraction,
    )
    from src.workers.revenuecat_webhook_handler import (
        handle_revenuecat_webhook,
    )
    from src.workers.subscription_writeback_handler import (
        handle_subscription_writeback,
    )

    dispatcher.register(JobType.DOCUMENT_PROCESSING, handle_document_processing)
    dispatcher.register(JobType.SUBSTRATE_EXTRACTION, handle_substrate_extraction)
    dispatcher.register(JobType.WEBHOOK_RECONCILIATION, handle_revenuecat_webhook)
    dispatcher.register(JobType.SUBSCRIPTION_WRITEBACK, handle_subscription_writeback)
    from src.services.account_lifecycle_service import process_deletion

    async def handle_account_deletion(job):
        # The account lifecycle service uses the synchronous Supabase client.
        # Keep its network I/O off the event loop so the worker can continue
        # serving health probes and lease/retry control while deletion runs.
        await asyncio.to_thread(
            process_deletion,
            job.payload["request_id"],
            job.payload["account_uid"],
        )

    dispatcher.register(JobType.ACCOUNT_DELETION, handle_account_deletion)
    log.info(
        "registered handlers: %s",
        [jt.value for jt in dispatcher.registered_types],
    )
    #   from src.services.qa_handler import handle_qa_response
    #   dispatcher.register(JobType.QA_RESPONSE, handle_qa_response)


async def _main() -> None:
    init_sentry(service_name="worker")
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
    port = int(os.getenv("PORT", "8080"))
    health_server = await asyncio.start_server(_health_client, "0.0.0.0", port)
    log.info("outbox worker health listener started on port %d", port)
    try:
        await dispatcher.run(
            poll_interval_seconds=poll_interval,
            stop_condition=stop.is_set,
        )
    finally:
        health_server.close()
        await health_server.wait_closed()
        shutdown_sentry()
    log.info("outbox dispatcher worker exiting cleanly")


if __name__ == "__main__":
    asyncio.run(_main())
