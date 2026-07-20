# ADR-2026-07-19-01: Durable work queue = Supabase outbox, not Cloud Tasks

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** Use a single Supabase table (`public.job_outbox`) as the durable work queue for every async path in CoverWise. Do not adopt Google Cloud Tasks.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator) + future work in the bucket 5 ADR queue.
- **Status:** Accepted; implementation tracked in commits 7a42df8 (Phase C pipeline that produces substrate rows) and the new outbox commits that follow this ADR.

---

## Context

CoverWise runs async work in 5 places:

1. **Document processing** — `derive_document_state()` orchestrates OCR, parsing, and RAG ingestion. Today the state lives in `documents.processing_attempts` and `documents.processing_lease_expires_at`. A Cloud Run instance death mid-processing is recoverable via the lease pattern.
2. **Evidence substrate extraction** — `EvidencePipeline` runs 6 deterministic + 1 LLM extractor on the parsed pages. Today the cost rows go to `evidence_extraction_costs`; the orchestration is in-process.
3. **Q&A response generation** — the RAG pipeline produces a response, which can include an LLM call. Today the call is in-request; a Cloud Run timeout loses the work.
4. **Webhook reconciliation** — Dodo Payments / Razorpay webhooks update subscription state. Today the idempotency table `processed_webhook_events` is the durability; a duplicate delivery is dropped, a missed delivery requires manual replay.
5. **Subscription write-back** — when a subscription state change fails to write to the source-of-truth table, the row goes to `failed_subscription_writes`. Today this is reviewed manually.

The architecture audit flagged this as ADR-03 ("durable work queue"). The trust audit's NO-GO on document state depends on document-processing durability. The security audit's NO-GO on account deletion depends on webhook reconciliation durability. The RevOps R1 substrate's cost-tracking depends on the pipeline not losing jobs.

The decision shapes the durability of every async path. Get it right once; every path inherits it. Get it wrong; every path silently loses jobs.

---

## Options considered

### Option A: Google Cloud Tasks

- **How it works:** HTTP POST to a target Cloud Run service with an OIDC token. The handler enqueues a task; Cloud Tasks delivers it to the target URL.
- **Delivery model:** push-only.
- **Retry:** exponential backoff with a max-attempts cap. Dead-letter queue is a separate target HTTP endpoint.
- **Ordering:** per-queue FIFO with task IDs. Same task ID is deduped.
- **Failure mode:** 5xx → retry; 4xx → drop or DLQ depending on config.
- **Cost:** ~$0.40 / million task operations.
- **Lock-in:** full. Migration means rewriting the enqueue code.
- **Auth:** OIDC tokens to the target service. The target must be a Cloud Run service (or App Engine, or a URL with IAM auth).
- **Operational surface:** a new GCP service to manage (IAM, billing, monitoring); a new auth boundary; a new failure mode (Cloud Tasks can be unavailable; the API has to handle that).

### Option B: Supabase outbox pattern

- **How it works:** a `job_outbox` table with `(id, job_type, payload, status, attempts, next_attempt_at, lease_expires_at, last_error, created_at)`. A worker process polls the table.
- **Delivery model:** pull-native. Any number of workers can poll.
- **Retry:** a worker sets `next_attempt_at = now() + backoff(attempts)` on failure. After `max_attempts`, the row goes to `status='dead_letter'`.
- **Ordering:** by `created_at` (or a sequence column) within a partition.
- **Failure mode:** a stuck lease is reclaimed by another worker after `lease_expires_at`.
- **Cost:** zero. The queue is a table. Worker runs in Cloud Run at ~$0 idle.
- **Lock-in:** none. The queue is a table; any client can read it.
- **Auth:** the worker uses the service role key, which is the same key already used for the substrate and document tables.
- **Operational surface:** a single new table; a single new worker process; the existing `document_processing_service` lease pattern is reused.

### Option C: third-party (e.g. Celery + Redis, Sidekiq, BullMQ)

- **Why not:** introduces a new runtime dependency (Redis already exists in some paths but is not the canonical store). Adds a separate process to manage, a separate auth boundary, and a separate failure mode. None of the existing 5 async paths require the message-broker semantics Celery provides. The Supabase outbox is sufficient.

---

## Chosen path

**Option B: Supabase outbox.**

The decision is not "which queue is better in isolation" — it is "which queue fits the system we already have."

The system already has 80% of an outbox:

- `documents.processing_attempts` and `documents.processing_lease_expires_at` (recover from worker death).
- `processed_webhook_events` (idempotency for webhooks, shipped in commit `fa02854`).
- `failed_subscription_writes` (retry queue for subscription reconciliation, shipped in `fa02854`).
- The substrate's append-only contract (re-processing produces new rows, not overwrites).

The missing 20% is a generic outbox table for jobs that don't fit any of the above (Q&A jobs, RAG ingestion, substrate extraction jobs, claim verification jobs, future async paths). The 20% is a single table + a worker + a dispatcher.

---

## Why this path

### 1st-principle argument

**Durable work must live where the durable state already lives.** A task that survives a Cloud Run death is a row in a database, not a message in a managed queue. The queue is a delivery mechanism; the database is the durability mechanism. We need durability, not delivery.

### Architectural argument

Cloud Tasks adds:

- a new GCP service to manage (IAM, billing, monitoring).
- a new auth boundary (OIDC tokens, separate from Supabase auth).
- a new failure mode (Cloud Tasks can be unavailable; the API has to handle that).
- vendor lock-in for the work-queue layer.

Supabase outbox adds:

- a single new table (~30 lines SQL).
- a worker that polls the table (can be the existing Cloud Run service or a separate one).
- a retry / backoff helper (already in the codebase as `claim_anonymous_documents`-style lease patterns in `infra/supabase/001_coverwise_schema.sql`).
- zero new GCP services, zero new auth boundaries, zero new failure modes.

### Cost argument

Cloud Tasks is ~$0.40 / million operations. Supabase outbox is free. For CoverWise's traffic (solo founder, ~10K queries/month, ~10K async jobs/month), Cloud Tasks would be ~$0.008/month — negligible. The principle is: **don't pay for what you can build in 30 lines of SQL.**

### Practical argument

Supabase outbox is **1 new table + 1 worker + 1 dispatcher.** Cloud Tasks is **1 new GCP service + IAM setup + OIDC config + a new failure mode to monitor + a rewrite of every existing poll loop.** The outbox is the path that ships in this session; Cloud Tasks is the path that takes a week of setup.

### Anti-parallel-paths argument (motto v3 §0.1)

The RevOps R1 commit (`fa02854`) shipped `processed_webhook_events` and `failed_subscription_writes` as **table-based** durability for those two paths. Introducing Cloud Tasks would mean **two queue systems** (the table-based ones and Cloud Tasks), each with its own failure mode, its own auth, its own monitoring. That is the parallel-paths anti-pattern. The outbox is **one** queue system, and the two existing tables become aliases for specific job types in that one system.

---

## Tradeoffs

- **Polling latency.** The outbox poll interval is the floor on job latency. Today the document-processing worker polls continuously in the same Cloud Run process, so latency is sub-second. A dedicated outbox worker that polls every N seconds adds that floor. Mitigation: the worker is a long-running Cloud Run job (`--no-cpu-throttling --min-instances=1`) with a poll interval of 1 second. Latency target: <2s end-to-end.
- **Throughput ceiling.** One worker pulling one row at a time is the floor. The ceiling is `1 / (poll_interval * job_duration)`. For 1s polls and 5s jobs, that's 0.2 jobs/second = 17,280/day. CoverWise's actual load is ~300 jobs/day. If the worker is the bottleneck, we can run multiple workers, each claiming a distinct partition of the outbox. The table is partitioned-friendly (a `partition_key` column could be added later).
- **Operator visibility.** Cloud Tasks has a built-in dashboard. The outbox has the Supabase Table Editor plus a custom operator view. The view (`v_outbox_health`) is part of the implementation. The cost of the missing dashboard is real but small: 1 SQL view.
- **No at-least-once delivery semantics for new workers.** A worker that crashes between "claim" and "complete" leaves the row leased; another worker reclaims it after the lease expires. The handler MUST be idempotent. The 5 existing async paths are already idempotent (the substrate is append-only; `processed_webhook_events` dedupes by event_id; the document lease is a known-good pattern). New workers written in the future must be idempotent or they will double-execute.
- **Dead-letter handling.** A job that fails `max_attempts` times goes to `status='dead_letter'`. The operator dashboard needs a view and a manual-retry action. This is follow-up work, not a blocker.

---

## Assumptions

- **Supabase Postgres can sustain the polling load.** The outbox poll is `SELECT ... FOR UPDATE SKIP LOCKED LIMIT 1` once per second per worker. At CoverWise's scale (~300 jobs/day, ~5 concurrent workers max) this is well within free-tier limits. Verified by the existing `001_coverwise_schema.sql` lease pattern, which polls at a similar rate.
- **A single long-running Cloud Run job is the right worker process.** Today the `document_processing_service` runs in-process; the new worker is a separate process but runs the same handler code. Splitting workers by job_type is a future refactor.
- **The 5 existing async paths can be migrated to the outbox in this session.** The migration is the enqueue + claim path; the handlers themselves stay put. This is a 1-session refactor, not a multi-day rewrite.
- **Idempotency is a property of the handler, not the queue.** The queue guarantees at-least-once delivery; the handler is responsible for being idempotent. The 5 existing paths satisfy this; new paths must be written with idempotency in mind.

---

## Risks

- **Worker single-point-of-failure.** A single worker dying means no jobs are processed. Mitigation: `min-instances=1` on the Cloud Run job; health check that fails when the worker stops polling; an alert on the operator dashboard when the outbox's `pending` row count grows. v1 of the implementation uses a single worker; multi-worker is a v2 follow-up.
- **Polling query performance.** The `SELECT ... FOR UPDATE SKIP LOCKED` query touches the partial index `job_outbox_pending_idx`. At CoverWise's scale this is fine; at higher scale a partitioned table would be needed. Risk is low for the current product.
- **Schema drift between the outbox and the canonical tables.** The substrate migration (`2026_07_18_evidence_substrate.sql`) and the outbox migration are independent. If a new substrate field is added, the outbox's `job_type` enum does not need to change (the payload is opaque to the queue). If a new job_type is added, the dispatcher table needs a new entry. This is a low-friction maintenance cost.
- **Adoption pressure.** New code in the future might be tempted to use Cloud Tasks or Celery for "convenience." Mitigation: the outbox is the canonical pattern, documented in `docs/decisions/`, and the gate's motto v3 §0.1 sweep catches parallel paths.

---

## Validation plan

- **Unit tests:** the outbox service has 23+ tests for enqueue, claim, complete, fail, dead-letter, and concurrent-claim behavior. (Implemented in this ADR's follow-up work.)
- **Integration test:** a test worker that enqueues 100 jobs of each of the 5 types, processes them, and verifies that the canonical tables are in the expected post-state. (T1 — verifiable against the live Supabase project once the migration is applied.)
- **Real-load test:** once deployed, the operator dashboard shows: pending count, average wait time, dead-letter count, jobs-per-hour by type. (Implemented as `v_outbox_health` view.)
- **Regression test:** the 5 existing async paths must continue to work. The migration is additive (the existing `processed_webhook_events` and `failed_subscription_writes` tables stay; they become job_type='webhook' and job_type='subscription_writeback' aliases in the dispatcher).
- **Operational test:** the launch playbook includes a verify step for the outbox: after applying migration #7, `select count(*) from job_outbox` returns 0 rows on a fresh deploy; after a document upload, the row appears with `status='completed'` within 30 seconds.

---

## Rollback or migration path

If the outbox turns out to be the wrong choice (e.g. we hit a polling-throughput ceiling at 10x current load):

1. **Keep the table; switch the delivery mechanism.** The outbox table is the source of truth for jobs. The worker can be replaced with a Cloud Tasks adapter that reads from the outbox, enqueues to Cloud Tasks, and deletes from the outbox on completion. The schema does not change; only the worker changes.
2. **Or, switch to push-based delivery.** A Cloud Run service can be invoked by a Postgres trigger (via `pg_net` or a Supabase Edge Function on `INSERT`) that enqueues a Cloud Task. The outbox table is unchanged; the trigger replaces the poll loop.
3. **Or, partition the table.** If polling is the bottleneck, partition by `job_type` and run one worker per partition. The application code does not change.

The outbox is the durable substrate; the worker is the delivery layer. They are decoupled by design.

---

## What would cause this decision to be revisited

- **Cloud Run's per-instance memory or CPU becomes a bottleneck for a single long-running worker.** Mitigation: multi-worker with a `partition_key` (e.g. `hash(document_id) % 4`). Revisit if real load exceeds 100 jobs/second sustained.
- **The 5 existing async paths grow to 20+ paths and the dispatcher table becomes hard to navigate.** Mitigation: a `job_handlers` registry in code, auto-discovered. Revisit if the dispatcher's `if/elif` chain exceeds 20 branches.
- **Postgres polling overhead at 1M+ jobs/day becomes a real cost.** Mitigation: switch the worker to LISTEN/NOTIFY for low-latency wakeup, or move to Cloud Tasks with the outbox as the canonical store. Revisit when sustained load exceeds the partial-index scan time.
- **A new team or contractor joins and proposes a different queue.** Mitigation: this ADR + the motto v3 §0.1 sweep catches the parallel-paths anti-pattern. Revisit only if the new requirement is something the outbox genuinely cannot model (e.g. cross-region fanout).
- **The operator wants a managed dashboard.** Mitigation: write a Supabase Edge Function that exposes outbox stats via a custom dashboard. Revisit if the operator's actual pain justifies the build cost.

---

## Links

- **Affected files (after this ADR's implementation):**
  - `supabase/migrations/2026_07_19_job_outbox.sql` (new)
  - `src/services/job_outbox_service.py` (new)
  - `src/services/job_dispatcher.py` (new)
  - `src/api/evidence.py` (existing, will be migrated to enqueue substrate jobs)
  - `src/api/document.py` (existing, will be migrated to enqueue document-processing jobs)
  - `src/api/webhooks.py` (existing, will be migrated to enqueue webhook-reconciliation jobs)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (updated to include migration #7)
- **Related ADRs / docs:**
  - `docs/planning/coverwise_audit_task_classification_2026-07-18.md` (Bucket 5 entry for ADR-03)
  - `docs/audits/coverwise_architecture_audit_2026-07-18.docx` (the source audit)
- **Related code:**
  - `infra/supabase/001_coverwise_schema.sql` (existing lease pattern; outbox reuses it)
  - `supabase/migrations/2026_07_18_revops_tables.sql` (existing `processed_webhook_events` and `failed_subscription_writes`; these become aliases in the outbox dispatcher)
- **Motto v3 alignment:** §0.1 (no parallel paths), §0.5 (evidence tiers — T1 SQL, T2 service-layer tests, T0 real-Supabase load), §0.10 (observability is delivery — `v_outbox_health` view), §0.12 (this document).
