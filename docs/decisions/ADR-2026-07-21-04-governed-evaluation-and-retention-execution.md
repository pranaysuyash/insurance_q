# ADR-2026-07-21-04: Governed evaluation and scheduled retention execution

## Status

Accepted for implementation; staging execution remains required.

## Decision

Approved dataset releases execute through `DatasetExecutionService`, which
materializes one immutable manifest, starts one governed `model_runs` record,
records one hash/metric-only result per dataset item, and finishes the run with
aggregate metrics. Retention executes through `tools/run_data_retention.py` and
the existing service boundaries: analytics purge, artifact expiry fencing, and
deletion of already-fenced object references.

## Context

The repository already governed consent, release approval, model lineage, and
artifact lifecycle, but those contracts stopped at registration. A registry
without an execution boundary cannot prove what ran, and a retention primitive
without a schedulable entry point cannot be operated consistently.

## Options considered

1. Keep registry and retention as manual service calls — rejected because the
   operational path would remain implicit and difficult to audit.
2. Add a separate training/evaluation platform now — rejected because provider,
   model, cost, and credential choices are not yet approved.
3. Add repository-owned execution boundaries with injected model evaluators and
   deployment scheduling — chosen; it preserves provider flexibility while
   making state transitions and evidence durable.

## Tradeoffs and safeguards

- Raw prompts, answers, and source material are not copied into run results;
  only hashes, scores, bounded metrics, and error classes are persisted.
- Evaluation can execute now with an injected provider adapter; actual provider
  execution remains a staging/credential gate.
- Retention deletion is two-phase: database eligibility fencing precedes object
  deletion, and failed deletes remain visible for retry.
- The maintenance command must be scheduled externally; API startup never runs
  destructive retention work.

## Revisit triggers and closure criteria

- Change the result schema if a reviewed model provider requires additional
  non-content telemetry.
- Run a real approved representative evaluation release and publish its
  artifact/report before claiming training readiness.
- Schedule the retention command in staging, inject expired/orphaned fixtures,
  verify the audit trail and post-delete Storage state, then rehearse restore.

## Affected paths

- `src/services/dataset_execution_service.py`
- `src/services/artifact_lifecycle_service.py`
- `tools/run_data_retention.py`
- `supabase/migrations/20260721100000_model_run_results.sql`
