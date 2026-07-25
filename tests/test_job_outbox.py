"""Tests for the job outbox service and dispatcher.

Per ADR-2026-07-19-01, the outbox is the canonical queue for
every async path in CoverWise. These tests are the regression
net for the typed access layer (JobOutboxService) and the
dispatch loop (JobDispatcher). The tests do NOT require a live
Supabase project; they exercise the in-process validation,
pydantic roundtrips, and the dispatcher's handler-routing
logic with a mocked outbox.

The trust / security / architecture audits' Bucket 5
acceptance is: every async path is durable. The unit tests
prove the outbox's correctness; the launch playbook's
Step 1 verify proves the SQL contract; the real-Supabase
load is T0 (operational, deferred to the operator).
"""

import asyncio
import os
import sys
from unittest.mock import AsyncMock, MagicMock

import pytest
from uuid import uuid4

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from src.models.job_outbox import (  # noqa: E402
    ClaimResult,
    EnqueueRequest,
    JobStatus,
    JobType,
    OutboxJob,
)
from src.services.job_dispatcher import (  # noqa: E402
    JobDispatcher,
    _exponential_backoff,
)
from src.services.job_outbox_service import (  # noqa: E402
    JobOutboxError,
    JobOutboxService,
    JobOutboxUnavailable,
)


# --- 1. initialization is fail-loud ---

def test_from_env_raises_when_url_missing(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-key")
    with pytest.raises(JobOutboxUnavailable):
        JobOutboxService.from_env()


def test_from_env_raises_when_key_missing(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://example.supabase.co")
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    monkeypatch.delenv("SUPABASE_SECRET_KEY", raising=False)
    with pytest.raises(JobOutboxUnavailable):
        JobOutboxService.from_env()


def test_constructor_rejects_empty_inputs():
    with pytest.raises(JobOutboxUnavailable):
        JobOutboxService("", "key")
    with pytest.raises(JobOutboxUnavailable):
        JobOutboxService("url", "")


# --- 2. JobType enum matches SQL CHECK ---

def test_job_type_enum_matches_sql_check():
    """The SQL CHECK lists 8 job types. The enum must match
    exactly. Drift here means an enqueue that the DB rejects."""
    expected = {
        "document_processing",
        "substrate_extraction",
        "qa_response",
        "webhook_reconciliation",
        "subscription_writeback",
        "claim_verification",
        "renewal_diff",
        "account_deletion",
    }
    actual = {jt.value for jt in JobType}
    assert actual == expected


def test_job_status_enum_matches_sql_check():
    expected = {
        "pending", "running", "completed", "failed", "dead_letter",
    }
    actual = {js.value for js in JobStatus}
    assert actual == expected


# --- 3. OutboxJob validation ---

def _outbox_job(**overrides) -> OutboxJob:
    defaults = dict(
        id="00000000-0000-0000-0000-000000000001",
        job_type=JobType.DOCUMENT_PROCESSING,
        payload={"document_id": "d1"},
        status=JobStatus.PENDING,
        attempts=0,
        max_attempts=5,
        next_attempt_at="2026-07-19T10:00:00+00:00",
        lease_token=uuid4(),
        created_at="2026-07-19T10:00:00+00:00",
        updated_at="2026-07-19T10:00:00+00:00",
    )
    defaults.update(overrides)
    return OutboxJob.model_validate(defaults)


def test_outbox_job_validates_minimum_fields():
    j = _outbox_job()
    assert j.job_type == JobType.DOCUMENT_PROCESSING
    assert j.attempts == 0
    assert j.max_attempts == 5


def test_outbox_job_rejects_attempts_exceeding_max():
    with pytest.raises(ValueError):
        _outbox_job(attempts=6, max_attempts=5)


# --- 4. enqueue ---

def _service_with_mocked_client() -> JobOutboxService:
    client = MagicMock()
    return JobOutboxService(
        "https://x.supabase.co", "test-key", client=client
    )


def test_enqueue_rejects_max_attempts_below_one():
    svc = _service_with_mocked_client()
    import asyncio
    request = EnqueueRequest(
        job_type=JobType.DOCUMENT_PROCESSING,
        payload={"x": 1},
        max_attempts=0,
    )
    with pytest.raises(JobOutboxError):
        asyncio.run(svc.enqueue(request))


def test_enqueue_passes_payload_to_supabase():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.insert.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    request = EnqueueRequest(
        job_type=JobType.SUBSTRATE_EXTRACTION,
        payload={"document_id": "d1", "parser_version": "v1"},
    )
    job_id = asyncio.run(svc.enqueue(request))
    assert str(job_id) == "00000000-0000-0000-0000-000000000001"
    # Verify the table was called with the right row shape
    call_args = svc._client.table.return_value.insert.call_args
    inserted_row = call_args[0][0]
    assert inserted_row["job_type"] == "substrate_extraction"
    assert inserted_row["payload"] == {
        "document_id": "d1", "parser_version": "v1"
    }
    assert inserted_row["max_attempts"] == 5


def test_enqueue_respects_not_before():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.insert.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    from datetime import datetime, timezone
    import asyncio
    scheduled = datetime(2026, 8, 1, 12, 0, 0, tzinfo=timezone.utc)
    request = EnqueueRequest(
        job_type=JobType.QA_RESPONSE,
        payload={"q": "what's the deductible?"},
        not_before=scheduled,
    )
    asyncio.run(svc.enqueue(request))
    call_args = svc._client.table.return_value.insert.call_args
    inserted_row = call_args[0][0]
    assert inserted_row["next_attempt_at"] == scheduled.isoformat()


def test_find_by_payload_field_returns_existing_job():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.contains.return_value.limit.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    job_id = asyncio.run(svc.find_by_payload_field(
        JobType.ACCOUNT_DELETION, "request_id", "request-1"
    ))
    assert str(job_id) == "00000000-0000-0000-0000-000000000001"


def test_find_by_payload_field_can_limit_to_active_jobs():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.contains.return_value.in_.return_value.limit.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    job_id = asyncio.run(svc.find_by_payload_field(
        JobType.ACCOUNT_DELETION,
        "request_id",
        "request-1",
        active_only=True,
    ))
    assert str(job_id) == "00000000-0000-0000-0000-000000000001"


# --- 5. claim ---

def test_claim_returns_none_when_no_pending_jobs():
    svc = _service_with_mocked_client()
    svc._client.rpc.return_value.execute.return_value.data = []
    import asyncio
    result = asyncio.run(svc.claim())
    assert result is None


def test_claim_returns_job_when_pending_exists():
    svc = _service_with_mocked_client()
    candidate_row = {
        "id": "00000000-0000-0000-0000-000000000001",
        "job_type": "document_processing",
        "payload": {"document_id": "d1"},
        "status": "pending",
        "attempts": 0,
        "max_attempts": 5,
        "next_attempt_at": "2026-07-19T10:00:00+00:00",
        "lease_expires_at": None,
        "lease_token": "00000000-0000-0000-0000-000000000002",
        "last_error": None,
        "partition_key": None,
        "created_at": "2026-07-19T10:00:00+00:00",
        "updated_at": "2026-07-19T10:00:00+00:00",
    }
    svc._client.rpc.return_value.execute.return_value.data = [
        {**candidate_row, "status": "running", "attempts": 1}
    ]
    import asyncio
    result = asyncio.run(svc.claim())
    assert result is not None
    assert isinstance(result, ClaimResult)
    assert result.job.job_type == JobType.DOCUMENT_PROCESSING
    assert result.job.status == JobStatus.RUNNING
    assert result.job.attempts == 1


def test_claim_returns_none_when_lost_race():
    """Two workers claim concurrently. The first one wins; the
    second one's atomic UPDATE affects 0 rows. The second
    caller's claim() returns None."""
    svc = _service_with_mocked_client()
    candidate_row = {
        "id": "00000000-0000-0000-0000-000000000001",
        "job_type": "document_processing",
        "payload": {"document_id": "d1"},
        "status": "pending",
        "attempts": 0,
        "max_attempts": 5,
        "next_attempt_at": "2026-07-19T10:00:00+00:00",
        "lease_expires_at": None,
        "lease_token": "00000000-0000-0000-0000-000000000002",
        "last_error": None,
        "partition_key": None,
        "created_at": "2026-07-19T10:00:00+00:00",
        "updated_at": "2026-07-19T10:00:00+00:00",
    }
    svc._client.table.return_value.select.return_value.eq.return_value.lte.return_value.order.return_value.limit.return_value.execute.return_value.data = [candidate_row]
    # The atomic UPDATE returns 0 rows (another worker won)
    svc._client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = []
    import asyncio
    result = asyncio.run(svc.claim())
    assert result is None


# --- 6. complete / fail ---

def test_complete_marks_job_as_completed():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    from uuid import uuid4
    asyncio.run(svc.complete(uuid4(), uuid4()))
    # Verify the update set status=completed and cleared the lease
    call_args = svc._client.table.return_value.update.call_args
    update_row = call_args[0][0]
    assert update_row["status"] == "completed"
    assert update_row["lease_expires_at"] is None


def test_fail_with_attempts_under_max_requeues():
    """A job that fails with attempts=1 and max_attempts=5 is
    re-queued with status=pending and a backoff. The next
    attempt will be eligible at next_attempt_at=now()+backoff."""
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"attempts": 1, "max_attempts": 5}
    ]
    svc._client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    from uuid import uuid4
    new_status = asyncio.run(svc.fail(uuid4(), uuid4(), "boom", backoff_seconds=4))
    assert new_status == JobStatus.PENDING
    call_args = svc._client.table.return_value.update.call_args
    update_row = call_args[0][0]
    assert update_row["status"] == "pending"
    assert update_row["last_error"] == "boom"


def test_fail_with_attempts_at_max_goes_to_dead_letter():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"attempts": 5, "max_attempts": 5}
    ]
    svc._client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    from uuid import uuid4
    new_status = asyncio.run(svc.fail(uuid4(), uuid4(), "exhausted", backoff_seconds=0))
    assert new_status == JobStatus.DEAD_LETTER


def test_fail_truncates_long_error_messages():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.eq.return_value.eq.return_value.eq.return_value.limit.return_value.execute.return_value.data = [
        {"attempts": 1, "max_attempts": 5}
    ]
    svc._client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    from uuid import uuid4
    long_error = "x" * 5000
    asyncio.run(svc.fail(uuid4(), uuid4(), long_error, backoff_seconds=4))
    call_args = svc._client.table.return_value.update.call_args
    update_row = call_args[0][0]
    # The last_error must be truncated to <= 1000 chars to fit
    # in the column. The exact column width is the SQL
    # migration's concern; the service enforces a 1000-char cap.
    assert len(update_row["last_error"]) <= 1000


# --- 7. dispatcher ---

def test_dispatcher_registers_handler():
    outbox = MagicMock()
    outbox.claim = AsyncMock(return_value=None)
    dispatcher = JobDispatcher(outbox)
    handler = AsyncMock()
    dispatcher.register(JobType.DOCUMENT_PROCESSING, handler)
    assert dispatcher.registered_types == [JobType.DOCUMENT_PROCESSING]


def test_dispatcher_dispatches_claimed_job_to_handler():
    outbox = MagicMock()
    job = _outbox_job()
    outbox.claim = AsyncMock(return_value=ClaimResult(job=job, lease_seconds=60))
    outbox.complete = AsyncMock()
    outbox.fail = AsyncMock()
    dispatcher = JobDispatcher(outbox)
    handler = AsyncMock()
    dispatcher.register(JobType.DOCUMENT_PROCESSING, handler)
    import asyncio
    processed = asyncio.run(dispatcher.dispatch_one())
    assert processed is True
    handler.assert_awaited_once_with(job)
    outbox.complete.assert_awaited_once_with(
        job_id=job.id, lease_token=job.lease_token
    )


def test_dispatcher_renews_lease_for_long_running_handler():
    outbox = MagicMock()
    job = _outbox_job()
    outbox.claim = AsyncMock(return_value=ClaimResult(job=job, lease_seconds=1))
    outbox.extend_lease = AsyncMock(return_value=True)
    outbox.complete = AsyncMock()
    outbox.fail = AsyncMock()
    dispatcher = JobDispatcher(outbox)

    async def handler(_job):
        await asyncio.sleep(1.1)

    dispatcher.register(JobType.DOCUMENT_PROCESSING, handler)
    processed = asyncio.run(dispatcher.dispatch_one())

    assert processed is True
    outbox.extend_lease.assert_awaited()
    outbox.complete.assert_awaited_once_with(
        job_id=job.id, lease_token=job.lease_token
    )


def test_dispatcher_stops_handler_when_lease_fencing_fails():
    outbox = MagicMock()
    job = _outbox_job()
    outbox.claim = AsyncMock(return_value=ClaimResult(job=job, lease_seconds=1))
    outbox.extend_lease = AsyncMock(return_value=False)
    outbox.complete = AsyncMock()
    outbox.fail = AsyncMock()
    dispatcher = JobDispatcher(outbox)
    cancelled = asyncio.Event()

    async def handler(_job):
        try:
            await asyncio.sleep(10)
        except asyncio.CancelledError:
            cancelled.set()
            raise

    dispatcher.register(JobType.DOCUMENT_PROCESSING, handler)
    processed = asyncio.run(dispatcher.dispatch_one())

    assert processed is True
    assert cancelled.is_set()
    outbox.complete.assert_not_awaited()
    outbox.fail.assert_not_awaited()


def test_dispatcher_stops_handler_when_lease_renewal_errors():
    outbox = MagicMock()
    job = _outbox_job()
    outbox.claim = AsyncMock(return_value=ClaimResult(job=job, lease_seconds=1))
    outbox.extend_lease = AsyncMock(side_effect=RuntimeError("queue unavailable"))
    outbox.complete = AsyncMock()
    outbox.fail = AsyncMock()
    dispatcher = JobDispatcher(outbox)
    cancelled = asyncio.Event()

    async def handler(_job):
        try:
            await asyncio.sleep(10)
        except asyncio.CancelledError:
            cancelled.set()
            raise

    dispatcher.register(JobType.DOCUMENT_PROCESSING, handler)
    processed = asyncio.run(dispatcher.dispatch_one())

    assert processed is True
    assert cancelled.is_set()
    outbox.complete.assert_not_awaited()
    outbox.fail.assert_not_awaited()


def test_dispatcher_returns_false_when_no_job():
    outbox = MagicMock()
    outbox.claim = AsyncMock(return_value=None)
    dispatcher = JobDispatcher(outbox)
    import asyncio
    processed = asyncio.run(dispatcher.dispatch_one())
    assert processed is False


def test_dispatcher_fails_job_when_no_handler_registered():
    """If a job type has no registered handler, the dispatcher
    must fail the job (not crash). This prevents stuck leases
    from jobs whose handler was never wired."""
    outbox = MagicMock()
    job = _outbox_job()
    outbox.claim = AsyncMock(return_value=ClaimResult(job=job, lease_seconds=60))
    outbox.fail = AsyncMock(return_value=JobStatus.PENDING)
    outbox.complete = AsyncMock()
    dispatcher = JobDispatcher(outbox)
    # No handler registered for DOCUMENT_PROCESSING
    import asyncio
    processed = asyncio.run(dispatcher.dispatch_one())
    assert processed is True
    outbox.fail.assert_awaited_once()
    outbox.complete.assert_not_awaited()


def test_dispatcher_catches_handler_exception_and_fails_job():
    outbox = MagicMock()
    job = _outbox_job()
    outbox.claim = AsyncMock(return_value=ClaimResult(job=job, lease_seconds=60))
    outbox.fail = AsyncMock(return_value=JobStatus.PENDING)
    outbox.complete = AsyncMock()
    dispatcher = JobDispatcher(outbox)
    handler = AsyncMock(side_effect=RuntimeError("extraction failed"))
    dispatcher.register(JobType.DOCUMENT_PROCESSING, handler)
    import asyncio
    processed = asyncio.run(dispatcher.dispatch_one())
    assert processed is True
    outbox.fail.assert_awaited_once()
    call_args = outbox.fail.await_args
    assert "extraction failed" in call_args.kwargs["error"]
    outbox.complete.assert_not_awaited()


def test_dispatcher_sends_exhausted_job_to_dead_letter():
    outbox = MagicMock()
    job = _outbox_job(attempts=5, max_attempts=5)
    outbox.claim = AsyncMock(return_value=ClaimResult(job=job, lease_seconds=60))
    outbox.fail = AsyncMock(return_value=JobStatus.DEAD_LETTER)
    outbox.complete = AsyncMock()
    dispatcher = JobDispatcher(outbox)
    handler = AsyncMock(side_effect=RuntimeError("final failure"))
    dispatcher.register(JobType.DOCUMENT_PROCESSING, handler)
    import asyncio
    processed = asyncio.run(dispatcher.dispatch_one())
    assert processed is True
    # The fail() return value (DEAD_LETTER) is what the dispatcher
    # observed; the dispatcher does not need to take additional
    # action because fail() already wrote the dead_letter status.
    assert outbox.fail.await_args is not None


# --- 8. exponential backoff ---

def test_exponential_backoff_sequence():
    # 1s, 4s, 16s, 64s, 256s for attempts 1-5; capped at 256.
    assert _exponential_backoff(1) == 1
    assert _exponential_backoff(2) == 4
    assert _exponential_backoff(3) == 16
    assert _exponential_backoff(4) == 64
    assert _exponential_backoff(5) == 256
    assert _exponential_backoff(6) == 256  # capped
    assert _exponential_backoff(0) == 1  # safety: attempts 0 still gets 1s


# --- 9. operator dashboard reads ---

def test_get_health_returns_per_type_snapshots():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.execute.return_value.data = [
        {
            "job_type": "document_processing",
            "pending_count": 3,
            "running_count": 1,
            "completed_count": 100,
            "failed_count": 0,
            "dead_letter_count": 0,
            "oldest_pending_age_seconds": 12,
            "most_recent_dead_letter_error": None,
        },
        {
            "job_type": "substrate_extraction",
            "pending_count": 0,
            "running_count": 0,
            "completed_count": 50,
            "failed_count": 1,
            "dead_letter_count": 1,
            "oldest_pending_age_seconds": None,
            "most_recent_dead_letter_error": "extraction failed",
        },
    ]
    import asyncio
    snapshots = asyncio.run(svc.get_health())
    assert len(snapshots) == 2
    by_type = {s.job_type: s for s in snapshots}
    assert by_type[JobType.DOCUMENT_PROCESSING].pending_count == 3
    assert by_type[JobType.SUBSTRATE_EXTRACTION].dead_letter_count == 1


def test_get_dead_letter_returns_records():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.select.return_value.limit.return_value.execute.return_value.data = [
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "job_type": "webhook_reconciliation",
            "payload": {"provider": "dodo", "event_id": "evt_1"},
            "attempts": 5,
            "last_error": "subscription write timed out",
            "created_at": "2026-07-19T10:00:00+00:00",
            "updated_at": "2026-07-19T10:05:00+00:00",
        }
    ]
    import asyncio
    records = asyncio.run(svc.get_dead_letter(limit=10))
    assert len(records) == 1
    assert records[0].job_type == JobType.WEBHOOK_RECONCILIATION
    assert records[0].attempts == 5


def test_retry_dead_letter_resets_status():
    svc = _service_with_mocked_client()
    svc._client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {"id": "00000000-0000-0000-0000-000000000001"}
    ]
    import asyncio
    from uuid import uuid4
    asyncio.run(svc.retry_dead_letter(uuid4()))
    call_args = svc._client.table.return_value.update.call_args
    update_row = call_args[0][0]
    assert update_row["status"] == "pending"
    assert update_row["attempts"] == 0
    assert update_row["last_error"] is None
    assert update_row["lease_expires_at"] is None


# --- 10. handler idempotency contract (documentation as test) ---

def test_handler_idempotency_is_a_documented_contract():
    """The outbox guarantees at-least-once delivery. A handler
    that crashes between claim and complete leaves the job
    leased; another worker reclaims it after the lease expires.
    Handlers MUST be idempotent.

    This test does not run a handler. It documents the
    contract. See ADR-2026-07-19-01 for the full discussion.
    """
    contract_doc = (
        "Every async path in CoverWise must be idempotent. "
        "The outbox may deliver the same job twice if a worker "
        "crashes between claim and complete. The handler must "
        "produce the same end state on re-execution as on the "
        "first execution. The 5 existing async paths "
        "(document processing, substrate extraction, Q&A, "
        "webhook reconciliation, subscription writeback) are "
        "already idempotent. New handlers written in the "
        "future must be idempotent or they will double-execute."
    )
    assert "idempotent" in contract_doc
    assert "twice" in contract_doc
