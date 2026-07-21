"""Job dispatcher (per ADR-2026-07-19-01).

The dispatcher is the only path that maps a claimed job to a
handler function. The mapping is a single registry; new job
types require a new entry here AND in src/models/job_outbox.py
AND in the SQL CHECK in supabase/migrations/20260719010000_job_outbox.sql.

The dispatcher does NOT own the queue. The queue is
JobOutboxService. The dispatcher owns the handler functions and
the dispatch loop. Per motto v3 §0.1 (no parallel paths), every
async path goes through this dispatch table; nothing calls
handlers directly.
"""
from __future__ import annotations

import asyncio
import logging
from typing import Any, Awaitable, Callable

from src.models.job_outbox import JobStatus, JobType, OutboxJob
from src.services.job_outbox_service import JobOutboxService

log = logging.getLogger(__name__)


# A handler takes a job and runs it. It returns nothing on
# success. On failure, it raises an exception; the dispatcher
# catches and calls fail() on the outbox.
JobHandler = Callable[[OutboxJob], Awaitable[None]]


class JobDispatcher:
    """Maps job_type -> handler. Owns the dispatch loop."""

    def __init__(self, outbox: JobOutboxService):
        self._outbox = outbox
        self._handlers: dict[JobType, JobHandler] = {}

    def register(self, job_type: JobType, handler: JobHandler) -> None:
        """Register a handler for a job type. Idempotent: re-registration
        replaces the previous handler (used in tests to swap in a
        fake)."""
        self._handlers[job_type] = handler

    @property
    def registered_types(self) -> list[JobType]:
        return list(self._handlers.keys())

    async def dispatch_one(self) -> bool:
        """Claim one job, dispatch it, complete or fail it.
        Returns True if a job was processed, False if no job
        was available (the caller may sleep and retry)."""
        claim = await self._outbox.claim(lease_seconds=60)
        if claim is None:
            return False
        job = claim.job
        handler = self._handlers.get(job.job_type)
        if handler is None:
            log.error(
                "no handler registered for job_type=%s (job_id=%s); "
                "failing with 'no handler' to avoid stuck lease",
                job.job_type, job.id,
            )
            await self._outbox.fail(
                job_id=job.id,
                error=f"no handler registered for job_type={job.job_type}",
                backoff_seconds=60,
            )
            return True
        try:
            await handler(job)
        except Exception as error:
            log.warning(
                "handler for %s failed (job_id=%s, attempts=%d): %s",
                job.job_type, job.id, job.attempts, error,
            )
            backoff = _exponential_backoff(job.attempts)
            new_status = await self._outbox.fail(
                job_id=job.id,
                error=str(error),
                backoff_seconds=backoff,
            )
            if new_status == JobStatus.DEAD_LETTER:
                log.error(
                    "job_id=%s job_type=%s sent to dead_letter after %d attempts",
                    job.id, job.job_type, job.attempts,
                )
            return True
        await self._outbox.complete(job_id=job.id)
        return True

    async def run(
        self,
        poll_interval_seconds: float = 1.0,
        stop_condition: Callable[[], bool] | None = None,
    ) -> None:
        """Run the dispatch loop until stop_condition() returns True.
        The loop:
          1. Reclaims stuck leases once per minute.
          2. Polls the outbox.
          3. Dispatches claimed jobs.
          4. Sleeps poll_interval_seconds if no job was available.

        The stop_condition is called at the top of each loop
        iteration; it must be cheap. v1 of the worker uses
        `lambda: False` to run forever; production uses a
        signal handler.
        """
        last_reclaim_at = 0.0
        while True:
            if stop_condition is not None and stop_condition():
                log.info("dispatcher stop condition met; exiting run loop")
                return
            # Reclaim stuck leases once per minute.
            import time
            now = time.time()
            if now - last_reclaim_at > 60:
                try:
                    n = await self._outbox.reclaim_stuck_leases()
                    if n > 0:
                        log.info("reclaimed %d stuck leases", n)
                except Exception as error:
                    log.warning("reclaim_stuck_leases failed: %s", error)
                last_reclaim_at = now
            # Dispatch one job.
            try:
                processed = await self.dispatch_one()
            except Exception as error:
                log.error("dispatch_one raised: %s", error)
                processed = False
            if not processed:
                await asyncio.sleep(poll_interval_seconds)


def _exponential_backoff(attempts: int) -> int:
    """Exponential backoff: 1s, 4s, 16s, 64s, 256s for attempts 1-5.
    The first failure is fast (1s); subsequent failures grow.
    Capped at 256s to keep the operator dashboard responsive."""
    return min(4 ** max(attempts - 1, 0), 256)
