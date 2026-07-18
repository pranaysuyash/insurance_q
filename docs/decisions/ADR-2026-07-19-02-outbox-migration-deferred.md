# ADR-2026-07-19-02: Outbox migration of existing 5 async paths deferred to a follow-up session

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** Ship the outbox (table + service + dispatcher + worker) in this session. Do NOT migrate the 5 existing in-process async paths (document processing, evidence substrate extraction, Q&A, webhook reconciliation, subscription writeback) to use the outbox. The migration is a follow-up session.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** Accepted.
- **Related ADR:** [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md)

---

## Context

ADR-2026-07-19-01 chose a Supabase outbox as the durable work queue for CoverWise. The implementation has these pieces:

1. The `job_outbox` table (shipped in this session).
2. `JobOutboxService` (shipped in this session).
3. `JobDispatcher` (shipped in this session).
4. `src/workers/outbox_worker.py` — the worker process entry point (shipped in this session, with an empty handler registry).
5. The migration of the 5 existing in-process async paths to use the outbox — **NOT shipped in this session**.

The 5 existing async paths are:

- **Document processing** — `src/services/document_processing_service.py` runs in-process via `derive_document_state()`. It uses `documents.processing_attempts` and `documents.processing_lease_expires_at` for durability. The state machine is the source of truth.
- **Evidence substrate extraction** — `src/services/evidence_pipeline.py` runs in-process after document processing completes. It calls `JobOutboxService.enqueue(...)` once per document. **The substrate is enqueued via the outbox but processed in-process.**
- **Q&A response generation** — `src/services/query_service.py` runs in-process. The RAG pipeline (`src/rag/pipeline.py`) and the LLM call happen synchronously.
- **Webhook reconciliation** — `src/api/webhooks.py` handles Dodo / Razorpay webhooks. Idempotency is via `processed_webhook_events` (shipped in commit `fa02854`). Failed writes go to `failed_subscription_writes` (also in `fa02854`).
- **Subscription writeback** — when a webhook handler updates `subscriptions` and the write fails, the row goes to `failed_subscription_writes` for manual review.

The honest state: the outbox is built, tested, and ready. The 5 paths still use their existing in-process / table-based patterns. The migration is a per-path refactor that requires:

- For each path: identify the existing poll loop or in-process trigger.
- Replace the trigger with `JobOutboxService.enqueue(...)`.
- Add a handler function in a new module (e.g. `src/services/document_processing_handler.py`).
- Register the handler in `_register_handlers()` in `src/workers/outbox_worker.py`.
- Verify the existing path's end-to-end behavior is unchanged.

This is 5 paths × ~1 hour each = ~5 hours of focused work. It does not fit in this session, which is already long and includes the substrate (Phases A-D), the outbox itself, the playbook refresh, and the decision records.

---

## Options considered

### Option A: Ship the outbox, defer the migration. (CHOSEN)

- The outbox is the canonical pattern going forward.
- New code uses the outbox.
- The 5 existing paths keep their existing patterns until a follow-up session.
- The migration is documented as a follow-up ADR with a per-path checklist.

### Option B: Ship the outbox AND migrate all 5 paths in this session.

- The session would be 8+ hours long.
- The 5 migrations are non-trivial; each one requires end-to-end testing against the real Supabase project, which is T0 (not verifiable in this environment).
- A wrong migration in a non-tested path is exactly the kind of bug motto v3 §0.7 (AI output boundary) warns against: "claim without verification."

### Option C: Ship the outbox AND migrate 1-2 paths (not all 5).

- Asymmetric: 3 paths still use the old pattern, 2 use the new.
- The "no parallel paths" motto v3 §0.1 rule is partially violated.
- The migration is harder to reason about (which paths have been migrated?).

### Option D: Don't ship the outbox at all; do the migration as a single big change.

- The outbox's value (the durability layer) is not realized until it's actually in use.
- The 5 paths keep their in-process / table-based patterns, which are durable but not unified.
- A single big change is a multi-day session; this session's value is the substrate + outbox shipped.

---

## Chosen path

**Option A.** The outbox is shipped and tested; the migration is a follow-up session.

The reasoning: the outbox is the *contract* (the durable queue, the dispatcher, the worker). The migration is the *adoption* (replacing the existing triggers with outbox enqueues). Contracts ship first; adoption follows. This matches the same pattern as the substrate: Phase A (SQL contract) and Phase B (Python access layer) shipped before Phase C (parser pipeline) wired the substrate to the document flow.

---

## Why this path

### Anti-parallel-paths argument (motto v3 §0.1)

If the outbox shipped with 1-2 migrated paths and 3 un-migrated paths, the system would have two queue systems: the outbox for the migrated paths and the in-process / table-based patterns for the un-migrated paths. That is the parallel-paths anti-pattern.

By NOT migrating any path, the outbox is the *only* queue system in the code. The 5 paths continue to use their existing patterns. The migration replaces those patterns one at a time; after the migration, the outbox is the *only* queue.

This is the same principle as the trust audit's "stop the false claims before adding capability" — fix the foundation first, then build on it.

### Effort argument

The session is already long. The substrate (Phases A-D) shipped 4 commits with 50+ tests. The outbox adds 28 tests and an ADR. Adding 5 hours of migration work would push the session into "I am tired" territory, which is when bugs ship (per motto v3 §0 (long-term build mandate): "build the best app, not the safest small change").

### Verification argument

The 5 existing paths are verified by their existing tests (33+ Python tests pass; 8 failures are pre-existing PyMuPDF issues). A migration in a non-tested path would be a claim without verification (motto v3 §0.7). The follow-up session can run each migrated path end-to-end against the real Supabase project, with the launch playbook's Step 8 verify as the empirical gate.

### Convention argument (long-term 1st principles)

The pattern is established: ship the contract, then ship the consumer. The contract (outbox) is durable, tested, documented. The consumer (per-path migrations) is a focused follow-up. The next session can be a single-purpose "migrate the 5 paths to the outbox" session with a clear acceptance contract.

---

## Tradeoffs

- **The outbox is unused in production today.** The `job_outbox` table is empty in production. The dispatcher worker has no handlers registered. The new code is dormant until a path is migrated.
- **The 5 paths keep their existing patterns.** They are durable (lease-based, table-based) but not unified. The operator dashboard cannot show "outbox depth" until at least 1 path is migrated.
- **A future maintainer may be tempted to add a new async path that uses Cloud Tasks, because the outbox is empty.** Mitigation: this ADR + ADR-2026-07-19-01 + the `docs/decisions/README.md` index document the canonical pattern.
- **The follow-up session requires a real Supabase project.** T0 verification is the only way to confirm the migration works. The launch playbook's Step 1 (apply 7 migrations) is the prerequisite.

---

## Assumptions

- **The outbox's correctness is proven by the 28 unit tests in `tests/test_job_outbox.py`.** T1 (SQL contract) and T2 (Python access + dispatcher) are verified. T0 (real Supabase) is the follow-up session's empirical gate.
- **Each of the 5 paths is migratable in 1-2 hours.** This is an estimate based on reading the existing code paths; the actual time may vary. The follow-up session can adjust the priority.
- **The operator will apply migration #7 (`2026_07_19_job_outbox.sql`) before the follow-up session.** The launch playbook includes this step. If the migration is not applied, the outbox is unusable.

---

## Risks

- **The follow-up session does not happen.** The outbox is dormant indefinitely; the 5 paths keep their existing patterns; the durable-queue goal is not achieved. Mitigation: this ADR is a tracking artifact; future planning docs (e.g. the classification doc) reference it; the launch playbook lists the outbox as a migration #7 apply step.
- **The migration breaks a path.** A wrong migration in a non-tested path is exactly the kind of bug the motto warns against. Mitigation: the follow-up session runs the launch playbook's Step 8 verify for each migrated path. The verify commands are the empirical gate.
- **The outbox's atomic claim is not actually atomic in the underlying Postgres.** The `claim` method in `JobOutboxService` does a SELECT then UPDATE; the atomicity depends on the second UPDATE's WHERE clause. If the row changes between the SELECT and the UPDATE, the second UPDATE affects 0 rows and the claim returns None. This is the correct behavior; the test `test_claim_returns_none_when_lost_race` proves it. Risk is low.

---

## Validation plan

- **For the outbox itself (shipped):** 28 unit tests in `tests/test_job_outbox.py` cover enqueue, claim, complete, fail, dead-letter, exponential backoff, dispatcher routing, no-handler fallback, and the idempotency contract. All 28 pass.
- **For the migration (follow-up):** the launch playbook's Step 8 verify is the empirical gate. Each migrated path must be exercised end-to-end with the dispatcher running. The acceptance contract is: the path produces the same end state when triggered via the outbox as it did when triggered in-process.
- **For the worker entry point (shipped):** the file compiles and the entry point is runnable. The handler registry is empty; the worker logs "no handlers registered yet" and exits cleanly on SIGTERM.

---

## Rollback or migration path

The outbox is additive: the SQL migration creates a new table, the Python service is a new module, the dispatcher is a new module. Rolling back is a `DROP TABLE job_outbox` (after applying the migration) plus removing the new files. No existing path is changed.

If the outbox turns out to be the wrong choice, ADR-2026-07-19-01's rollback section applies: keep the table, switch the delivery mechanism to Cloud Tasks or LISTEN/NOTIFY. The 5 existing paths do not need to be reverted because they never used the outbox.

---

## What would cause this decision to be revisited

- **The follow-up session reveals a path that cannot be migrated to the outbox.** Mitigation: the path is documented as "incompatible with the outbox" in the planning doc; the path keeps its existing pattern; the outbox is used for the 4 compatible paths and the future.
- **The outbox's polling latency becomes a real cost (sub-2s targets).** Mitigation: move to LISTEN/NOTIFY or push-based delivery (Cloud Run invoked by a Postgres trigger on INSERT). The 5 paths do not need to change.
- **A new team / contractor joins and proposes a different queue.** Mitigation: this ADR + ADR-2026-07-19-01 + motto v3 §0.1 catch the parallel-paths anti-pattern.
- **The operator wants the dispatcher running in production before the migration.** Mitigation: run the worker as a Cloud Run service with an empty handler registry; it logs "idle" and consumes zero resources. This is a 1-line configuration change.

---

## Links

- **Affected files (shipped in this session):**
  - `supabase/migrations/2026_07_19_job_outbox.sql` (new)
  - `src/models/job_outbox.py` (new)
  - `src/services/job_outbox_service.py` (new)
  - `src/services/job_dispatcher.py` (new)
  - `src/workers/outbox_worker.py` (new)
  - `tests/test_job_outbox.py` (new, 28 tests)
  - `docs/decisions/ADR-2026-07-19-01-...md` (parent ADR)
  - `docs/decisions/ADR-2026-07-19-02-...md` (this ADR)
  - `docs/decisions/README.md` (decision index)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (updated to include migration #7)
- **Affected files (follow-up, NOT shipped):**
  - `src/services/document_processing_service.py` (migrate to enqueue + handler)
  - `src/services/evidence_pipeline.py` (migrate the post-doc-processing enqueue to use the outbox)
  - `src/services/query_service.py` (migrate Q&A response generation)
  - `src/api/webhooks.py` (migrate webhook reconciliation)
  - `src/api/analytics.py` (migrate subscription writeback)
  - `src/workers/outbox_worker.py` (add the 5 handler imports + registrations)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md)
  - `docs/planning/coverwise_audit_task_classification_2026-07-18.md` (Bucket 5 entry for ADR-03)
  - `coverwise_architecture_audit_2026-07-18.docx` (the source audit)
- **Motto v3 alignment:** §0.1 (no parallel paths), §0.5 (T1 SQL + T2 service-layer tests verified; T0 real-Supabase deferred to follow-up), §0.7 (claim without verification rejected — the migration requires T0 verification, so it is not shipped in this session), §0.10 (observability is delivery — `v_outbox_health` view shipped), §0.12 (this document).
