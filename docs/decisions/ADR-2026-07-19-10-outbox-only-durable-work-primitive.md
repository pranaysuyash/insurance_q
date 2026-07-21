# ADR-2026-07-19-10: Outbox is the only durable-work primitive; BackgroundTasks is removed from the production path

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The outbox is the only durable-work primitive in the production path.** FastAPI `BackgroundTasks` is removed from the production path. The three async paths that still use `BackgroundTasks` (document processing, evidence extraction, billing webhook handler) are migrated to the outbox. The 2 paths that already use the outbox (document processing, evidence extraction, per bc16e9e) stay on the outbox. The release guard is a CI test that asserts no production code path calls `BackgroundTasks.add_task` for durable work. The launch happens after the migration is complete and the release guard is green.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** The outbox is the only durable-work primitive in the production path. The 3 remaining `BackgroundTasks` paths are migrated; the release guard enforces the contract; the lease heartbeat, reaper, bounded retries, dead-letter state, and operator CLI are added. The wider wedge from ADR-2026-07-19-08 revision 2 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault) generates more durable work, but the contract is unchanged — every new durable work path goes through the outbox, and the release guard catches any new `BackgroundTasks` usage. The outbox must scale with the new work volume; the scaling test (per the validation plan) is the gate. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md), [ADR-2026-07-19-02](./ADR-2026-07-19-02-outbox-migration-deferred.md), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md), `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` P0-01, P0-02.

---

## Update log

- **2026-07-19 (original)**: Initial proposal. Outbox-only; 3 paths migrated; release guard; heartbeat + reaper + retries + dead-letter + CLI. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** The operator reviewed and signed off. The wider wedge from ADR-2026-07-19-08 revision 2 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault) generates more durable work — every observation, every scenario answer, every per-member observation, every document ingest is durable work — but the contract is unchanged. Every new durable work path goes through the outbox. The release guard (a CI test that scans production code for `BackgroundTasks` usage) catches any new path that bypasses the outbox. The outbox must scale with the new work volume; the scaling test (per the validation plan) is the gate. The lease heartbeat, reaper, bounded retries, dead-letter state, and operator CLI are the operational features that make the outbox reliable at the new volume. No contract changes; the volume is higher.

---

## Context

The current state, from the code archaeology pass and the audits:

- **The outbox** (`supabase/migrations/2026_07_19_job_outbox.sql`, `src/workers/outbox_worker.py`) is a Supabase table + a Python dispatcher. It has lease, heartbeat, retry, and dead-letter semantics. It was introduced in ADR-2026-07-19-01. The migration was deferred in ADR-2026-07-19-02 ("we'll get to it"). After bc16e9e, 2 of 5 async paths use the outbox: document processing and evidence extraction.
- **FastAPI `BackgroundTasks`** is the FastAPI in-process task runner. It runs after the HTTP response is sent, in the same process. It is not durable: if the process dies, the task is lost. It is not retried: if the task fails, there is no second attempt. It is not observable: there is no record of the task's state. It is not scalable: the task runs in the same process as the request, so a slow task blocks the worker.
- **The 3 async paths that still use `BackgroundTasks`** are:
  1. **Document processing** — the path that calls `process_document_background` after the upload returns 202. This is the path the audits flag as P0-01.
  2. **Evidence extraction** — the path that calls the LLM honesty check after the deterministic extractors run. This is part of the document processing path; the outbox version in bc16e9e is the third stage.
  3. **Billing webhook handler** — the path that receives `POST /billing/webhook` from the store and reconciles the entitlement. This is a future path (the billing workstream in ADR-2026-07-19-08 #4); it is not yet built, but the audit's T-4-4 names it as required.
- **The audits converge on the same fix.** The operations audit's P0-01 is "Move durable processing off FastAPI `BackgroundTasks` to the outbox + bounded worker." The trust audit's T-1-18 is "Single async-work truth: outbox as the only durable-work primitive." The current-state review's Phase C names the same work.

The decision is binary: outbox-only or hybrid. The hybrid version keeps `BackgroundTasks` for non-durable work (e.g. sending a one-shot notification, refreshing a cache) but removes it for durable work (anything that must complete, anything that has side effects, anything that the user can come back to). This ADR chooses outbox-only because the audit's NO-GO is "any durable work not in the outbox can be lost, and lost work is a contract violation."

---

## Options considered

### Option A: Keep `BackgroundTasks` for some paths, outbox for others (hybrid). REJECTED.

- **How it works:** the outbox handles document processing, evidence extraction, and billing webhooks (all durable work). `BackgroundTasks` handles cache refreshes, telemetry, and one-shot notifications (all non-durable). The boundary is "if the task can be lost without a contract violation, it stays on `BackgroundTasks`."
- **Why rejected:** the boundary is hard to enforce. The audits' complaint is that the boundary is invisible — there is no test that says "this path is durable, that path is not." Future engineers will add new paths and guess wrong. The outbox-only answer makes the boundary visible: every async path goes through the outbox. The hybrid answer preserves the boundary but loses the visibility.
- **Mitigation that was considered and rejected:** add a CI test that asserts every async path is on the outbox. The test would be a one-line check (grep for `BackgroundTasks` in production code). The mitigation is good, but the hybrid answer still has the boundary problem: the test catches the violation, it doesn't prevent the violation.

### Option B: Outbox-only, with `BackgroundTasks` removed from the production path. CHOSEN.

- **How it works:** the outbox is the only durable-work primitive. The 3 paths that still use `BackgroundTasks` are migrated. The 2 paths that already use the outbox stay. The `BackgroundTasks` import is removed from the production code (kept in tests for testing patterns). A CI test asserts no production code path calls `BackgroundTasks.add_task` for durable work.
- **Why chosen:** the audit's T-1-18 is "Single async-work truth: outbox as the only durable-work primitive." The "single" word is the load-bearing one. One primitive means one set of guarantees: lease, heartbeat, retry, dead-letter, observability. Two primitives means two sets of guarantees, and the weaker one is the floor.
- **Cost:** 1-2 weeks of work: migrate the 3 paths, add the CI test, remove the import, update the docs. The outbox is already built; the migration is the work.
- **Quality:** every async path is on the outbox. The boundary is enforced. The release guard catches regressions.

### Option C: Outbox-only, with `BackgroundTasks` removed from the codebase (including tests). REJECTED.

- **How it works:** the outbox is the only primitive. The `BackgroundTasks` import is removed from tests too. The migration is the same as Option B, plus a test refactor.
- **Why rejected:** FastAPI's `BackgroundTasks` is useful for testing the request/response cycle without going through the outbox. Removing it from tests would slow down the test suite. The audit's concern is durable work in production; tests are not durable work.

---

## The migration

The 3 paths that still use `BackgroundTasks`:

### Path 1: Document processing (`src/api/document.py` upload handler)

- **Current state:** the upload handler returns 202 immediately. It calls `BackgroundTasks.add_task(process_document_background, ...)` with the document ID. The `process_document_background` function runs in the same process.
- **Migration:** the upload handler enqueues a `document.processing` event in the outbox. The `OutboxWorker` (already in `src/workers/outbox_worker.py`) dequeues the event and runs `process_document_background` in a worker process. The outbox handler is already wired in bc16e9e (`src/workers/document_processing_handler.py`).
- **Effort:** S. The outbox handler exists. The migration is a 1-line change in the upload handler (replace `BackgroundTasks.add_task` with `outbox.enqueue`).
- **Tests:** unit test that asserts the upload handler enqueues the event. Integration test that asserts the outbox worker runs the handler.
- **Source:** `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` P0-01.

### Path 2: Evidence extraction (`src/services/document_processing_service.py`)

- **Current state:** production document processing enqueues substrate extraction after page artifacts are persisted. The worker reloads page OCR from `page_artifacts`; raw OCR is not placed in the outbox payload. Local development retains the inline compatibility path. Worker crash/reclaim and staging post-condition evidence remain verification gates.
- **Migration:** the document processing service enqueues a `substrate.extraction` event in the outbox. The `OutboxWorker` dequeues the event and runs the evidence pipeline in a worker process. The inline call is removed.
- **Effort:** S. The outbox handler exists. The migration is a 1-line change in the document processing service.
- **Tests:** unit test that asserts the document processing service enqueues the event. Integration test that asserts the outbox worker runs the evidence pipeline.
- **Source:** `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` T-1-18.

### Path 3: Billing webhook handler (future, per ADR-08 #4)

- **Current state:** the billing webhook handler does not exist yet. The billing workstream in ADR-2026-07-19-08 #4 will build it.
- **Migration:** when the billing workstream lands, the webhook handler is built on the outbox from the start. There is no `BackgroundTasks` version to migrate. The release-guard test prevents the `BackgroundTasks` version from being introduced.
- **Effort:** 0. The migration is "don't introduce `BackgroundTasks` for this path."
- **Tests:** the release-guard test (below) covers this.
- **Source:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #4.

### Release guard

- **What it is:** a CI test that scans the production code for `BackgroundTasks` usage. The test fails if any production code path imports `BackgroundTasks` or calls `BackgroundTasks.add_task` for durable work.
- **Where it lives:** `tests/test_no_background_tasks_in_production.py` (new). The test greps the production code (excluding `tests/`, `tools/`, and `docs/`) for `BackgroundTasks` and `background_tasks.add_task`. The test fails if the pattern is found.
- **Effort:** S. 0.5 day.
- **Source:** the audit's T-1-18 implicit in "single async-work truth."

### Lease heartbeat + reaper (T-2-2)

- **What it is:** the outbox already has lease semantics. This ADR adds a heartbeat (the worker updates the lease every 30s) and a reaper (a periodic job that reclaims leases that have not been heartbeat'd in 15 min).
- **Where it lives:** `src/workers/outbox_worker.py` (extend). The heartbeat is a SQL update on the lease row. The reaper is a SQL function that runs every 60s.
- **Effort:** M. 1-2 days.
- **Source:** `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` P0-02.

### Bounded retries + dead-letter (T-2-2)

- **What it is:** the outbox already has retry semantics. This ADR adds a maximum retry count (e.g. 5) and a dead-letter state (the event moves to a `job_outbox_dead_letter` table after 5 failures). The operator can re-queue from the dead-letter table.
- **Where it lives:** `src/workers/outbox_worker.py` (extend). The dead-letter table is a new migration.
- **Effort:** S. 1 day.
- **Source:** `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` P0-02.

### Operator tooling (T-2-9)

- **What it is:** an operator CLI that can list, retry, cancel, and quarantine outbox events. The CLI is the operator's tool for the dead-letter state.
- **Where it lives:** `tools/outbox_admin.py` (new). A Python script with a CLI.
- **Effort:** M. 1-2 days.
- **Source:** `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` P0-17.

---

## Chosen path

**The outbox is the only durable-work primitive in the production path.** The 3 paths that still use `BackgroundTasks` are migrated. The release guard prevents regressions. The lease heartbeat, reaper, bounded retries, dead-letter state, and operator CLI are added.

The work to implement:

1. **Path 1 migration** (document processing) — 0.5 day. The outbox handler exists.
2. **Path 2 migration** (evidence extraction) — 0.5 day. The outbox handler exists.
3. **Path 3 commitment** (billing webhook) — 0 day. The release guard prevents the `BackgroundTasks` version.
4. **Release guard** — 0.5 day. The CI test.
5. **Lease heartbeat + reaper** — 1-2 days. The worker extension.
6. **Bounded retries + dead-letter** — 1 day. The worker extension + migration.
7. **Operator CLI** — 1-2 days. The Python script.

**Effort:** 1-2 weeks. The migration is small; the outbox features (heartbeat, reaper, retries, dead-letter, CLI) are the bulk.

**Sequence:**
1. Lease heartbeat + reaper (the foundation for the rest).
2. Bounded retries + dead-letter (the retry policy).
3. Path 1 migration (document processing).
4. Path 2 migration (evidence extraction).
5. Path 3 commitment (release guard prevents regressions).
6. Operator CLI (the tool for the dead-letter state).
7. Release guard (the CI test).

The release happens after the release guard is green and the launch playbook's Step 8 (real-device end-to-end) validates the migration.

---

## Why this path

### 1st-principle argument

Durable work has one property: it must complete. The outbox is the only primitive in the codebase that guarantees completion (via lease, heartbeat, retry, dead-letter). `BackgroundTasks` does not guarantee completion (in-process, no retry, no observability). Mixing the two primitives is mixing two contracts: the user's contract is "your document will be processed," and that contract is only as strong as the weakest primitive in the path.

The outbox-only answer is the audit's T-1-18 applied as a contract: one primitive, one contract, one guarantee. The hybrid answer preserves the boundary but loses the contract.

### Anti-lying-UI argument (motto v3 §0.7, trust audit NO-GO)

The "evidence-backed" claim (ADR-2026-07-19-09) depends on the outbox. The evidence extraction path is a durable-work path: the system says "your policy is being processed," and the processing must complete. If the processing is lost (because `BackgroundTasks` died), the user sees "processing" forever, and the "evidence-backed" claim is a lie. The outbox is the engineering answer to the lying UI: the system processes the document, the system records the processing, the user sees the result.

### Anti-parallel-systems argument (motto v3 §0.1)

The audit's T-1-13 is explicit: parallel paths (legacy + new, stub + real, BackgroundTasks + outbox) violate the "no parallel systems" rule and let unsafe paths regress. The outbox-only answer removes the parallel system. The release guard prevents the parallel system from being reintroduced.

### Anti-dual-contract argument (motto v3 §0.4 acceptance contract)

The acceptance contract for "ship a feature" includes "the work the system promises will complete." Two primitives means two contracts, and the user's contract is the weaker one. The outbox-only answer makes the contract uniform: every async path, one contract, one guarantee.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The outbox-only answer is a recommendation grounded in the audits. The operator may want the hybrid answer; the operator may want a different primitive; the operator may want to defer the migration further. The reason this is an ADR and not a code change is that the durable-work contract is load-bearing and the operator should sign off on it.

---

## Tradeoffs

- **The outbox-only answer requires a Supabase write for every async path.** The outbox enqueue is a SQL insert. The cost is small (single-row insert, indexed on lease + status) but it is non-zero. The mitigation is the audit's T-2-3 budget: the outbox write is in the per-document budget.
- **The migration breaks the upload handler's 202-immediate-return contract.** The current contract is "return 202, process in the background." The outbox version is the same contract, but the processing is in the outbox worker, not the request process. The HTTP behavior is identical. The internal behavior is different.
- **The lease heartbeat adds 1 SQL update per 30s per active worker.** The cost is small but it is per-worker, not per-event. The mitigation is the audit's T-2-11 instrumentation: the heartbeat is observable.
- **The dead-letter state requires operator intervention.** If a document fails 5 times, the event goes to the dead-letter table. The operator must re-queue or cancel. The mitigation is the operator CLI.
- **The release guard is a grep test.** It catches `BackgroundTasks` usage in production code. It does not catch other async patterns (e.g. asyncio.create_task, threading.Thread). The mitigation is the audit's T-1-18 implicit: the outbox is the only primitive; asyncio.create_task is for in-process non-durable work only.
- **The outbox-only answer is not free.** It is 1-2 weeks of work. The launch slips. The operator's call. The outbox is the cost of having a durable-work contract.

---

## Assumptions

- **The outbox is correct.** The outbox was built in ADR-2026-07-19-01; the migration was deferred in ADR-2026-07-19-02; the outbox handler was wired in bc16e9e. The outbox is not the unknown. The migration is the unknown.
- **The lease + heartbeat + retry + dead-letter semantics are the right set of guarantees.** The audit's P0-02 names these. The operator may want a different set (e.g. exponential backoff, priority queues, per-event-type policies). The ADR is the place to discuss.
- **The operator CLI is a Python script.** A web UI is a future workstream. The CLI is sufficient for the launch.
- **The release guard is a grep test.** A more sophisticated AST-based test is a future workstream. The grep test is sufficient for the launch.
- **The Supabase write cost is acceptable.** The outbox enqueue is a single-row insert. The audit's T-2-3 budget covers the cost.

---

## Risks

- **The operator disagrees with the outbox-only answer.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the binary choice explicit and easy to revisit.
- **The migration breaks a path the audit did not flag.** The audits are comprehensive but not exhaustive. The mitigation is the release guard: any new `BackgroundTasks` usage is caught.
- **The outbox write cost is higher than estimated.** The mitigation is the budget test: if the cost exceeds the per-document budget, the enqueue is rejected (the upload returns 503 with a clear "try again later" message).
- **The lease heartbeat adds too much load.** The mitigation is the configurable heartbeat interval: 30s is a default; the operator can increase it.
- **The dead-letter state is not picked up.** The operator may not check the dead-letter table. The mitigation is the operator CLI + a daily alert (T-2-10).
- **The release guard is too strict.** Some legitimate non-durable work uses `BackgroundTasks` (e.g. test setup, one-shot notifications). The mitigation is the guard's exclusion list: the guard skips `tests/`, `tools/`, and `docs/`. The guard can be extended with an explicit allow-list if needed.

---

## Validation plan

- **For the migration:** integration tests that assert the outbox worker runs the handler for each of the 3 paths. The tests use a real Supabase (or a hermetic test Supabase) and a real outbox worker.
- **For the release guard:** the CI test scans the production code for `BackgroundTasks` usage. The test fails if any production code path uses `BackgroundTasks`.
- **For the lease heartbeat:** a test that asserts the lease is updated every 30s while the worker is active.
- **For the reaper:** a test that asserts a lease that has not been heartbeat'd in 15 min is reclaimed.
- **For the bounded retries:** a test that asserts an event that fails 5 times moves to the dead-letter table.
- **For the dead-letter state:** a test that asserts the operator CLI can re-queue or cancel a dead-letter event.
- **For the operator CLI:** a test that asserts the CLI lists, retries, cancels, and quarantines events.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the migration is complete. The validation includes: upload policy → outbox event enqueued → worker processes → evidence extracted → user sees the result.

---

## Rollback or migration path

The outbox is already in production (2 of 5 paths). The migration is additive: the 3 remaining paths are moved to the outbox, not removed from a different primitive. The rollback for any migrated path is to revert the 1-line change in the handler (replace `outbox.enqueue` with `BackgroundTasks.add_task`). The release guard prevents the rollback from being permanent.

The lease heartbeat, reaper, bounded retries, and dead-letter state are additive features on the outbox. The rollback is to disable the feature (config flag) without removing the code.

The operator CLI is a new tool. The rollback is to not use the CLI; the dead-letter state is still managed via SQL.

---

## What would cause this decision to be revisited

- **The operator wants a different primitive.** The outbox is a recommendation. A future ADR can introduce a different primitive (e.g. Temporal, Inngest) and the outbox becomes one of several. The audit's T-1-18 is the current recommendation.
- **The outbox write cost is too high.** A future ADR can introduce batching or priority queues. The audit's T-2-3 budget is the constraint.
- **The dead-letter state is too operator-heavy.** A future ADR can introduce auto-retry with exponential backoff and a longer max retry count. The audit's P0-02 is the current recommendation.
- **The market changes.** A competitor uses a different async primitive. The operator may decide to switch. The audit's T-1-18 is the current recommendation.
- **The substrate grows to include new async paths.** The release guard catches new `BackgroundTasks` usage. The migration is the work.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `src/api/document.py` (Path 1 migration: replace `BackgroundTasks.add_task` with `outbox.enqueue`)
  - `src/services/document_processing_service.py` (Path 2 migration: replace inline evidence pipeline with `outbox.enqueue`)
  - `src/workers/outbox_worker.py` (extend: lease heartbeat, reaper, bounded retries, dead-letter)
  - `src/workers/document_processing_handler.py` (already exists, no change)
  - `src/workers/substrate_extraction_handler.py` (already exists, no change)
  - `supabase/migrations/` (new: `job_outbox_dead_letter` table)
  - `tools/outbox_admin.py` (new: operator CLI)
  - `tests/test_no_background_tasks_in_production.py` (new: release guard)
  - `tests/test_outbox_lease_heartbeat.py` (new: heartbeat test)
  - `tests/test_outbox_reaper.py` (new: reaper test)
  - `tests/test_outbox_dead_letter.py` (new: dead-letter test)
  - `tests/test_outbox_admin_cli.py` (new: CLI test)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the outbox-only contract to the doc)
  - `docs/decisions/README.md` (add this ADR to the index)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (update the outbox section)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md) (the outbox's introduction)
  - [ADR-2026-07-19-02](./ADR-2026-07-19-02-outbox-migration-deferred.md) (the deferred migration, now unblocked)
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) (the billing webhook handler that will land on the outbox)
  - [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md) (the evidence-backed contract that depends on the outbox)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_operations_reliability_observability_performance_cost_audit_2026-07-18.md` P0-01, P0-02, P0-17 (the audit findings)
  - `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` T-1-18 (the audit's recommendation)
- **Related code (current state):**
  - `src/workers/outbox_worker.py` (the outbox dispatcher)
  - `src/workers/document_processing_handler.py` (the document processing outbox handler, in bc16e9e)
- `src/workers/substrate_extraction_handler.py` (the evidence extraction outbox handler, in bc16e9e)
- `supabase/migrations/2026_07_19_job_outbox.sql` (the outbox table)
- **Motto v3 alignment:** §0.1 (no parallel systems; the outbox-only answer removes the parallel `BackgroundTasks`), §0.4 (acceptance contract; the outbox is the contract for durable work), §0.5 (evidence tiers; the outbox write is observable), §0.7 (AI output boundary; the outbox is the engineering answer to the lying UI for evidence-backed claims), §0.10 (observability is delivery; the heartbeat + reaper + dead-letter make the outbox observable), §0.12 (this document).

## Implementation-status addendum (2026-07-21)

Static review found that the accepted decision was ahead of the live wiring:
the upload route still used `BackgroundTasks`, and the first document handler
did not share terminal status/classification finalization with the fallback
path. The first coherent migration stage is now landed: production startup
requires the outbox, upload jobs carry a canonical source-object reference,
and both paths use `document_processing_job.run_document_processing_job` for
owner-scoped claiming and terminal persistence. Development may retain the
legacy task only when the durable queue is intentionally unavailable.

This does not close the whole ADR. Substrate extraction is still inline,
Q&A/subscription/claim job types still lack registered handlers, and deployed
worker/object-store/lease/retry evidence remains required before the accepted
production contract can be called fully verified.

## Implementation-status addendum (2026-07-21, billing webhook)

The RevenueCat webhook route and event-ID idempotency fence now exist in
`src/api/subscription.py`, with focused tests for authorization, duplicate
delivery, ordering, purchase, and expiration. The current implementation uses
the local SQLite subscription ledger and therefore does not yet satisfy the
production form of this ADR. Move billing entitlement state and webhook audit
records to the canonical Supabase durable ledger, then route webhook work
through the existing outbox before production billing scale-up.
