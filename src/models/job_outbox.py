"""Typed Pydantic models for the job outbox (durable work queue).

Per ADR-2026-07-19-01 (docs/decisions/), the outbox is the canonical
queue for every async path in CoverWise. These models are the
typed shape of the queue's contents. The service module
(src/services/job_outbox_service.py) and the dispatcher
(src/services/job_dispatcher.py) use these types throughout.
"""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field, field_validator, model_validator


class JobType(str, Enum):
    """The 7 job types the outbox supports. Adding a new type
    requires:
      1. Adding the new value here.
      2. Adding the new value to the SQL CHECK in
         supabase/migrations/2026_07_19_job_outbox.sql.
      3. Adding the new value to the dispatcher's handler map.
    """

    DOCUMENT_PROCESSING = "document_processing"
    SUBSTRATE_EXTRACTION = "substrate_extraction"
    QA_RESPONSE = "qa_response"
    WEBHOOK_RECONCILIATION = "webhook_reconciliation"
    SUBSCRIPTION_WRITEBACK = "subscription_writeback"
    CLAIM_VERIFICATION = "claim_verification"
    RENEWAL_DIFF = "renewal_diff"


class JobStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    DEAD_LETTER = "dead_letter"


class OutboxJob(BaseModel):
    """The shape of a row in public.job_outbox."""

    id: str
    job_type: JobType
    payload: dict
    status: JobStatus
    attempts: int = Field(ge=0)
    max_attempts: int = Field(ge=1)
    next_attempt_at: datetime
    lease_expires_at: Optional[datetime] = None
    last_error: Optional[str] = None
    partition_key: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    @field_validator("attempts")
    @classmethod
    def _attempts_non_negative(cls, v: int) -> int:
        if v < 0:
            raise ValueError(f"attempts must be >= 0 (got {v})")
        return v

    @model_validator(mode="after")
    def _attempts_le_max(self) -> "OutboxJob":
        if self.attempts > self.max_attempts:
            raise ValueError(
                f"attempts ({self.attempts}) must not exceed max_attempts ({self.max_attempts})"
            )
        return self


class EnqueueRequest(BaseModel):
    """Caller-supplied shape for `JobOutboxService.enqueue`."""

    job_type: JobType
    payload: dict
    max_attempts: int = 5
    # Optional: delay the job's first eligible claim time. Useful
    # for retry backoff or scheduled work.
    not_before: Optional[datetime] = None
    partition_key: Optional[int] = None


class ClaimResult(BaseModel):
    """The shape returned by `JobOutboxService.claim`. Either a job
    was claimed, or no job was available (returns None)."""

    job: OutboxJob
    lease_seconds: int = 60  # how long the worker holds the lease


class OutboxHealthSnapshot(BaseModel):
    """A snapshot of v_outbox_health, per job type. Used by the
    operator dashboard."""

    job_type: JobType
    pending_count: int
    running_count: int
    completed_count: int
    failed_count: int
    dead_letter_count: int
    oldest_pending_age_seconds: Optional[int] = None
    most_recent_dead_letter_error: Optional[str] = None


class DeadLetterRecord(BaseModel):
    """One row from v_outbox_dead_letter. Used by the operator
    dashboard's triage view."""

    id: str
    job_type: JobType
    payload: dict
    attempts: int
    last_error: Optional[str] = None
    created_at: datetime
    updated_at: datetime
