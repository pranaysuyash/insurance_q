"""Job outbox service (durable work queue access layer).

Per ADR-2026-07-19-01 (docs/decisions/), the outbox is the canonical
queue for every async path in CoverWise. This module is the typed
access layer; per motto v3 §0.1 (no parallel paths), every enqueue
and claim goes through this service. The dispatcher
(src/services/job_dispatcher.py) is the only caller that maps a
claimed job to a handler function.

Append-only by intent: completed and dead-lettered jobs are not
deleted. They remain in the table for audit. Operators prune via
a separate scheduled task (not yet built; the pruning policy is
its own ADR when needed).

Idempotency contract: the queue guarantees at-least-once delivery.
A handler that crashes between "claim" and "complete" leaves the
job leased; another worker reclaims it after the lease expires.
Handlers MUST be idempotent. The 5 existing async paths are
already idempotent (see ADR-2026-07-19-01).
"""
from __future__ import annotations

import logging
import os
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID, uuid4

from src.models.job_outbox import (
    ClaimResult,
    DeadLetterRecord,
    EnqueueRequest,
    JobStatus,
    JobType,
    OutboxHealthSnapshot,
    OutboxJob,
)
from src.utils.runtime_config import supabase_server_key

log = logging.getLogger(__name__)


class JobOutboxError(Exception):
    """Base for all outbox service errors."""


class JobOutboxUnavailable(JobOutboxError):
    """The outbox is not configured on this deployment. Same
    fail-loud contract as EvidenceSubstrateService: missing env
    means the caller must surface the failure, not silently
    drop the job."""


class JobNotClaimable(JobOutboxError):
    """The job cannot be claimed (status changed, lease held by
    another worker, or max_attempts reached). The caller should
    move on to the next claim attempt."""


class JobOutboxService:
    """Typed access layer for the job_outbox table.

    All enqueue, claim, complete, fail, and read methods go
    through here. The constructor accepts an optional pre-built
    client for testability; production uses from_env().
    """

    def __init__(
        self,
        supabase_url: str,
        service_role_key: str,
        client: Optional[object] = None,
    ):
        if client is not None:
            self._client = client
            return
        if not supabase_url or not service_role_key:
            raise JobOutboxUnavailable(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for the job outbox"
            )
        try:
            from src.utils.supabase_client import create_client
        except ImportError as error:  # pragma: no cover - deployment dependency
            raise JobOutboxUnavailable(
                "supabase package is required for the job outbox"
            ) from error
        self._client = create_client(supabase_url, service_role_key)

    @staticmethod
    def from_env() -> "JobOutboxService":
        url = os.getenv("SUPABASE_URL", "").strip()
        key = supabase_server_key()
        if not url or not key:
            raise JobOutboxUnavailable(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set"
            )
        return JobOutboxService(url, key)

    # --- enqueue ---

    async def enqueue(self, request: EnqueueRequest) -> UUID:
        """Add a job to the outbox. Returns the new job id.

        The job starts in status='pending' with next_attempt_at=now()
        (or the request's not_before). A worker will claim it on
        the next poll cycle.
        """
        if request.max_attempts < 1:
            raise JobOutboxError("max_attempts must be >= 1")
        row = {
            "job_type": request.job_type.value,
            "payload": request.payload,
            "max_attempts": request.max_attempts,
            "next_attempt_at": (
                request.not_before.isoformat()
                if request.not_before
                else datetime.now(timezone.utc).isoformat()
            ),
            "partition_key": request.partition_key,
        }
        response = (
            self._client.table("job_outbox").insert(row).execute()
        )
        if not response.data:
            raise JobOutboxError("job_outbox insert returned no row")
        return UUID(response.data[0]["id"])

    async def find_by_payload_field(
        self,
        job_type: JobType,
        field: str,
        value: str,
        *,
        active_only: bool = False,
    ) -> Optional[UUID]:
        """Find an existing job by a bounded JSON payload identity.

        This supports idempotent retry of destructive workflows such as
        account deletion without exposing raw table access to callers. When
        [active_only] is true, completed and dead-lettered history is ignored
        so a failed durable request can be enqueued again.
        """
        if not field or not field.replace("_", "").isalnum():
            raise JobOutboxError("payload identity field must be alphanumeric")
        query = (
            self._client.table("job_outbox")
            .select("id")
            .eq("job_type", job_type.value)
            .contains("payload", {field: value})
        )
        if active_only:
            query = query.in_(
                "status",
                [JobStatus.PENDING.value, JobStatus.RUNNING.value],
            )
        response = query.limit(1).execute()
        if not response.data:
            return None
        return UUID(response.data[0]["id"])

    # --- claim ---

    async def claim(
        self, lease_seconds: int = 60
    ) -> Optional[ClaimResult]:
        """Atomically claim one pending job. Returns None if no
        job is available.

        The database function performs SELECT ... FOR UPDATE SKIP LOCKED
        and the state transition in one transaction. Two workers cannot
        claim the same row.
        """
        response = self._client.rpc(
            "claim_job_outbox", {"p_lease_seconds": lease_seconds}
        ).execute()
        if not response.data:
            return None
        claimed = response.data[0]
        try:
            job = OutboxJob.model_validate(claimed)
        except Exception as error:
            log.error("claimed row failed to validate: %s", error)
            return None
        return ClaimResult(job=job, lease_seconds=lease_seconds)

    async def extend_lease(
        self, job_id: UUID, lease_token: UUID, lease_seconds: int = 60
    ) -> bool:
        """Extend the lease on a currently-running job. Returns
        True if the extension succeeded, False if the job is no
        longer in 'running' status (e.g. another worker reclaimed
        it after a stuck lease)."""
        lease_expires_at = (
            datetime.now(timezone.utc).timestamp() + lease_seconds
        )
        from datetime import datetime as _dt
        lease_iso = _dt.fromtimestamp(
            lease_expires_at, tz=timezone.utc
        ).isoformat()
        response = (
            self._client.table("job_outbox")
            .update({"lease_expires_at": lease_iso})
            .eq("id", str(job_id))
            .eq("status", "running")
            .eq("lease_token", str(lease_token))
            .execute()
        )
        return bool(response.data)

    # --- complete / fail / dead-letter ---

    async def complete(self, job_id: UUID, lease_token: UUID) -> None:
        """Mark a job as successfully completed. The row is
        retained in the table for audit."""
        response = (
            self._client.table("job_outbox")
            .update({"status": "completed", "lease_expires_at": None})
            .eq("id", str(job_id))
            .eq("status", "running")
            .eq("lease_token", str(lease_token))
            .execute()
        )
        if not response.data:
            raise JobOutboxError(
                f"job_outbox complete failed: row {job_id} not found"
            )

    async def fail(
        self,
        job_id: UUID,
        lease_token: UUID,
        error: str,
        backoff_seconds: int,
    ) -> JobStatus:
        """Mark a job as failed and either re-queue it (if
        attempts < max_attempts) or send it to dead_letter.

        Returns the new status. The caller may use this to log
        'this job is now dead_letter' and surface it to the
        operator dashboard.

        backoff_seconds is how long until the next retry. The
        caller computes this (typically exponential: 1s, 4s,
        16s, 64s, 256s for attempts 1-5).
        """
        # Look up the row to know current attempts and max_attempts.
        lookup = (
            self._client.table("job_outbox")
            .select("attempts, max_attempts")
            .eq("id", str(job_id))
            .eq("status", "running")
            .eq("lease_token", str(lease_token))
            .limit(1)
            .execute()
        )
        if not lookup.data:
            raise JobOutboxError(
                f"job_outbox fail: row {job_id} not found"
            )
        row = lookup.data[0]
        attempts = row["attempts"]
        max_attempts = row["max_attempts"]
        if attempts >= max_attempts:
            new_status = JobStatus.DEAD_LETTER
        else:
            new_status = JobStatus.PENDING
        from datetime import timedelta
        next_attempt_at = (
            datetime.now(timezone.utc) + timedelta(seconds=backoff_seconds)
        ).isoformat()
        response = (
            self._client.table("job_outbox")
            .update(
                {
                    "status": new_status.value,
                    "last_error": error[:1000],  # truncate to fit
                    "next_attempt_at": next_attempt_at,
                    "lease_expires_at": None,
                    "lease_token": str(uuid4()),
                }
            )
            .eq("id", str(job_id))
            .eq("status", "running")
            .eq("lease_token", str(lease_token))
            .execute()
        )
        if not response.data:
            raise JobOutboxError(
                f"job_outbox fail update failed for row {job_id}"
            )
        return new_status

    async def reclaim_stuck_leases(self, max_age_seconds: int = 300) -> int:
        """Reclaim jobs whose lease has been stuck for more than
        max_age_seconds. The caller invokes this periodically
        (e.g. once per minute from the worker). Returns the
        number of jobs reclaimed.

        A reclaimed job is reset to status='pending' with
        attempts incremented. If attempts >= max_attempts, the
        job goes to dead_letter.
        """
        response = self._client.rpc(
            "reclaim_job_outbox", {"p_max_age_seconds": max_age_seconds}
        ).execute()
        return int(response.data or 0)

    # --- reads (operator dashboard) ---

    async def get_health(self) -> list[OutboxHealthSnapshot]:
        """Read v_outbox_health. Returns one row per job_type with
        counts and the oldest pending age."""
        response = (
            self._client.table("v_outbox_health").select("*").execute()
        )
        if not response.data:
            return []
        return [
            OutboxHealthSnapshot.model_validate(row) for row in response.data
        ]

    async def get_dead_letter(self, limit: int = 100) -> list[DeadLetterRecord]:
        """Read v_outbox_dead_letter, newest first. The operator
        uses this to triage and re-queue failed jobs."""
        response = (
            self._client.table("v_outbox_dead_letter")
            .select("*")
            .limit(limit)
            .execute()
        )
        if not response.data:
            return []
        return [
            DeadLetterRecord.model_validate(row) for row in response.data
        ]

    async def retry_dead_letter(self, job_id: UUID) -> None:
        """Operator action: take a dead_letter job, reset it to
        pending with attempts=0, and let a worker re-process it.
        The payload is unchanged. The new run is a fresh attempt
        sequence; the prior failures are in the audit trail
        (the row is not deleted)."""
        response = (
            self._client.table("job_outbox")
            .update(
                {
                    "status": "pending",
                    "attempts": 0,
                    "last_error": None,
                    "next_attempt_at": datetime.now(
                        timezone.utc
                    ).isoformat(),
                    "lease_expires_at": None,
                    "lease_token": str(uuid4()),
                }
            )
            .eq("id", str(job_id))
            .eq("status", "dead_letter")
            .execute()
        )
        if not response.data:
            raise JobOutboxError(
                f"retry_dead_letter: row {job_id} not in dead_letter status"
            )
