# CoverWise Supabase Data Architecture, Migration Integrity, RLS, Concurrency, and Lifecycle Audit

**Date:** 2026-07-20  
**Repository:** `pranaysuyash/insurance_q`  
**Branch:** `main`  
**Commit audited:** `ace259055c86ba8f8e9d6e4790831be8f788741d`  
**Evidence tier:** Tier 1 static inspection  
**Runtime status:** no combined GitHub status and no workflow run attached to the audited commit  
**Scope:** Supabase/Postgres schema, migrations, RLS, ownership, evidence, pgvector, consent, outbox, analytics, subscriptions, storage references, retention, deletion, and data-plane integration.

## Executive verdict

Supabase remains the correct long-term production platform for CoverWise. The repository now has several strong database foundations: a private source bucket, owner-scoped document deduplication, a fixed pgvector dimension, an evidence substrate, an append-only consent ledger, a Postgres outbox design, partial queue indexes, a shared atomic rate-limit RPC, and service-role-only sensitive tables.

The system is nevertheless **not ready to become the canonical production data plane**.

The main weakness is no longer a lack of tables. It is missing cross-table and cross-lifecycle integrity:

- evidence rows can be linked across different documents;
- the citation view can return multiple parser versions for one field;
- page artifacts cannot be versioned despite the append-only claim;
- active processing does not create page artifacts before evidence extraction;
- evidence persistence is not transactional;
- ownership claim moves only documents, not duplicated chunk ownership and other principal aggregates;
- outbox jobs lack idempotency and lease fencing;
- intended job payloads include file bytes and PDF passwords;
- Supabase vector persistence does not implement the new source/retrieval split;
- the consent API uses a nonexistent user property;
- immutable consent history retains raw identity and network data without an erasure contract;
- RevenueCat state is stored in Cloud Run SQLite while the Supabase subscriptions table models different providers;
- the shared Supabase rate limiter exists but active code still uses Redis, process memory, and SQLite;
- migrations are manually applied from two directories and one contains invalid PostgreSQL policy syntax.

The launch playbook states that all eight SQL migrations are still pending. No production-like database evidence exists.

**Decision: NO-GO for applying the current chain to a production customer-data project without repair and rehearsal.**


## What is genuinely strong

1. **Supabase is the right platform.** Postgres, pgvector, Auth, private Storage, and a service-mediated API are a coherent solo-product architecture.

2. **Owner-scoped source deduplication is correct.** The `(owner_id, source_hash)` unique index avoids global cross-user deduplication side channels.

3. **The vector dimension is explicit.** `vector(1536)` correctly expresses one embedding contract per index.

4. **Evidence is a first-class data model.** Raw, normalized, and display values are separate, and citations have page/evidence records.

5. **Consent history is database-enforced append-only.** The trigger is stronger than an application convention.

6. **The shared rate-limit RPC is atomic.** `INSERT ... ON CONFLICT DO UPDATE` is the correct multi-instance direction.

7. **Outbox hot-path indexes are appropriate.** Pending, stuck-lease, and dead-letter partial indexes match queue operations.

8. **Sensitive operational tables are service-role-only.** This is appropriate for the server-mediated product boundary.

These foundations should be completed rather than replaced.


## P0 findings

### P0-01: There is no reproducible migration system

The operator is instructed to manually paste eight SQL files from two directories into the Supabase SQL editor. There is no automated migration ledger, checksum, empty-database test, upgrade test, schema-diff gate, or controlled transaction protocol.

`create table if not exists` proves only that an object with the same name exists. It does not prove its columns, constraints, triggers, indexes, or grants match the repository.

**Required move:** consolidate into one ordered `supabase/migrations/` chain, apply through the Supabase CLI or a controlled `psql` runner, and test empty-build plus upgrade paths.

### P0-02: The RevOps migration contains invalid SQL

`2026_07_18_revops_tables.sql` contains:

```sql
create policy if not exists "Users read own profile"
```

PostgreSQL does not support `IF NOT EXISTS` for `CREATE POLICY`. The migration will fail at that statement.

Use an explicit `DO` block that checks `pg_policies` before creating the policy.

### P0-03: Active processing does not create the page artifacts required by evidence extraction

The evidence pipeline first loads `page_artifacts` and rejects a field if the cited page has no artifact. The active processing path supplies `page_texts` but does not first render/upload pages and insert page-artifact/source-span rows.

The result is an evidence pipeline that can run extractors but cite zero fields.

**Required order:**

```text
source -> render page -> upload page image -> page_artifact
       -> source_spans -> field extraction -> field_evidence
```

### P0-04: Cross-document evidence links are not constrained

`field_evidence` references an extracted field, page artifact, and optional source span independently. Postgres does not prove they belong to the same document or processing run.

A valid foreign-key graph can therefore connect a field from document A to a page from document B and a span from page C.

Add `document_version_id`/`processing_run_id` to all evidence rows and use composite foreign keys or validation triggers.

### P0-05: `v_field_citations` does not return one current field

The view selects the strongest evidence for every extracted-field row. It does not first choose the latest accepted field per `(document_id, field_name)`.

Parser reruns can return multiple policy numbers, premiums, or room-rent caps while the view claims one row per field.

Create a `latest accepted field` CTE using `distinct on` or `row_number`, then choose its strongest evidence.

### P0-06: Evidence is described as append-only but the database does not enforce it

The migration grants `DELETE` to service role and has no immutable-data trigger. Unlike the consent ledger, evidence history can be altered or deleted by a bug or script.

Either enforce immutable run history or stop describing it as database-enforced append-only.

### P0-07: Page uniqueness prevents versioned reruns

`unique(document_id, page_number)` allows only one page artifact per document page. That contradicts the stated design where parser reruns append new immutable versions.

Add `document_version_id`, `processing_run_id`, and parser version to the page identity.

### P0-08: Evidence writes are non-transactional

A field is inserted, then its evidence is inserted, then its cost is inserted through separate Supabase calls. Failure can leave uncited fields, missing costs, or half-written runs.

Create a transactional RPC that writes one extraction result, and promote an extraction run only after all required writes succeed.

### P0-09: The server consent API is broken

`src/api/consent.py` calls `current_user.id`; the `User` model exposes `uid`. Record, current-state, and history routes therefore fail at the API boundary.

Use `current_user.uid` and test with the real principal model.

### P0-10: Immutable consent history conflicts with erasure

The consent trigger blocks all update and delete operations, while the row retains raw `user_id`, IP address, and user agent without expiry.

Account deletion does not enumerate or pseudonymize these records.

Retain consent proof through a pseudonymous reference, destroy the identity mapping during erasure, and expire raw network metadata.

### P0-11: Anonymous claim transfers only documents

The SQL function updates the `documents` owner and JSON payload. It does not transfer `document_chunks.owner_id`, consent lineage, subscriptions, lifecycle records, analytics identity, jobs, or local correction lineage, and it does not revoke the anonymous principal.

Create one transactional principal-claim function that resolves source-hash conflicts, moves every aggregate, records lineage, and revokes old access.

### P0-12: Outbox leases do not fence stale workers

Jobs store only `lease_expires_at`. Completion and failure update by job ID, with no `locked_by`, lease token, or claim generation.

A worker whose lease expired can still complete after another worker reclaimed the job.

Add `lease_token`, `locked_by`, and generation. Heartbeat, complete, and fail must condition on the active token.

### P0-13: Outbox claim is not a real database queue claim

The service selects a candidate and then conditionally updates it. There is no claim RPC and no `FOR UPDATE SKIP LOCKED`.

Losing workers repeatedly select the same row and return empty rather than claiming another job. Real concurrency has not been tested.

Create an atomic claim RPC using `SKIP LOCKED`.

### P0-14: The intended job payload is unsafe

The document handler expects base64 source bytes, the PDF password, OCR text, owner, and filename in generic outbox JSON.

If adopted, source files and passwords will be duplicated into Postgres, WAL, backups, dead-letter views, and operator tooling.

Queue references only: document version, object reference, processing run, and requested capabilities. Never store a PDF password in a durable generic job row.

### P0-15: Jobs have no business idempotency key

Repeated enqueues or retries can create duplicate processing, embeddings, fields, and costs. Append-only duplicates are not idempotency.

Add a unique key such as:

```text
document_processing:{document_version_id}:{pipeline_version}
```

### P0-16: The document handler does not finish the document aggregate

The outbox handler invokes `process_document_full` and logs the result, but it does not claim/update the canonical document row, persist exact state, clear the document lease, or atomically enqueue the next stage.

If the upload path is switched now, a job can finish while the document remains `received`.

### P0-17: The Supabase chunk adapter breaks the source/retrieval contract

The RAG pipeline now distinguishes `source_text` and `retrieval_text`. The Supabase adapter still accesses `block["text"]` and writes one `content` column.

New-style chunks can fail with a missing key, and contextual retrieval separation is lost.

Add `source_text`, `retrieval_text`, `page_artifact_id`, source-span references, and `index_version_id` to `document_chunks`.

### P0-18: Page-artifact assignment in RAG is a no-op

The pipeline creates an updated local `block` variable but never writes it back to `text_blocks`. Page-artifact IDs therefore do not reach persisted chunks.

Build a new transformed list or update by index.

### P0-19: Selected-document filtering happens after vector limit

The RPC ranks and limits by owner, then Python removes results outside `document_ids`. Relevant selected-document chunks can be excluded before filtering.

Move the allowed-document filter into SQL before ranking and limit.

### P0-20: Billing has contradictory data planes

The Supabase `subscriptions` table accepts only Dodo and Razorpay. The actual app uses RevenueCat. The active subscription API trusts client-submitted plan state and stores it in `insurance_app.db`, not Supabase.

This allows plan spoofing, loses server state on Cloud Run restart, and leaves the supposed canonical subscription table unused.

Use RevenueCat webhook/API verification to project Supabase subscription and entitlement state. The mobile state must be a cache, not authority.


## P1 findings

1. `documents.status` has no check constraint tied to the state machine.
2. Indexed document columns are duplicated inside `payload`, allowing drift.
3. `documents.updated_at` is application-managed with no standard trigger.
4. Account claim can fail if the destination already owns the same source hash.
5. `document_chunks.owner_id` duplicates document ownership without enforcement.
6. Production exact lookup and full-text search are still missing.
7. Runtime embedding fallback can change dimensions and references Qdrant in Supabase mode.
8. Field names, parser versions, prompt versions, and validation versions lack registries.
9. Parser version is a timestamp rather than reproducible code identity.
10. LLM extraction cost rows are currently zero.
11. Synchronous `supabase-py` calls run inside async methods.
12. Consent types require schema migration despite comments saying otherwise.
13. Consent latest-state ordering lacks an `id` tie-breaker.
14. Consent IP/user agent can be overridden by client body values.
15. Consent read errors are converted to empty state rather than `unavailable`.
16. Raw IP/session data remains in document metadata and anti-abuse stores.
17. The shared Supabase rate-limit RPC is unused.
18. Redis rate limiting is count-then-add rather than atomic.
19. Redis sorted-set members based on timestamps can collide.
20. Active anti-abuse fails open and process-memory fallback is per instance.
21. Analytics idempotency uses `(received_at,event_name,user_uid)`, not event ID.
22. All same-name events in a batch share `received_at` and can collide.
23. Client event timestamps are not validated.
24. Analytics views use raw user UID and can double-count anonymous/account transitions.
25. Analytics remains SQLite-first despite Cloud Run ephemerality.
26. Supabase subscriptions lack standard created/updated timestamps.
27. `deal_decisions.related_subscription_id` has no foreign key.
28. Provider vocabularies do not include the actual RevenueCat system.
29. `profiles` grants authenticated insert/update but defines only a SELECT policy.
30. Base documents/chunks enable RLS but define no owner policies.
31. Storage retention, abandoned-upload cleanup, and page-image cleanup are unspecified.
32. Page image URIs are unverified strings rather than promoted object manifests.
33. Dead-letter views expose generic payload JSON that may contain sensitive data.
34. Outbox includes a `failed` status that runtime normally never uses.
35. Stuck-lease reclamation is a select-and-update loop rather than one DB operation.
36. Worker logs say it is idle after registering two handlers.
37. User field corrections remain device-local parallel truth and do not feed evidence/Q&A.
38. Most database “integration” tests use mocked clients rather than real Postgres/Supabase.


## Target data architecture

### Principal layer

```text
principals
  id
  type: anonymous | account
  status
  claimed_into_principal_id
  revoked_at
```

Use `principal_id` consistently rather than rewriting unrelated owner strings.

### Document aggregate

```text
documents
document_versions
processing_runs
```

A replacement creates a version. A processing attempt creates a run. Only a promoted run becomes current.

### Evidence aggregate

```text
page_artifacts
source_spans
extraction_runs
extracted_fields
field_evidence
```

Every row carries a document-version and processing-run identity. Composite constraints prove all citation records belong to the same aggregate.

### Retrieval aggregate

```text
index_versions
document_chunks(
  source_text,
  retrieval_text,
  page_artifact_id,
  source_span_ids,
  index_version_id,
  embedding
)
```

SQL filters principal, document version, and index version before ranking.

### Outbox

```text
job_outbox(
  principal_id,
  aggregate_type,
  aggregate_id,
  idempotency_key,
  payload_reference,
  locked_by,
  lease_token,
  lease_expires_at,
  status,
  result_summary
)
```

Payloads contain references, never source bytes or passwords.

### Consent

```text
privacy_disclosures
consent_events
principal_identity_mapping
```

Consent proof is retained pseudonymously. Erasure destroys the identity mapping and expires raw network metadata.

### Billing

```text
billing_events
subscriptions
entitlement_ledger
consumable_balances
```

RevenueCat webhooks/API are verified server-side. Supabase is canonical; Flutter is a cache.


## Ordered remediation

### Phase A: Repair and automate migrations

- consolidate into one migration directory;
- fix policy syntax;
- add migration checksums/history;
- test empty database and upgrades;
- enforce schema diff and grants/RLS assertions.

### Phase B: Evidence schema v2

- add document versions, processing runs, and extraction runs;
- enforce same-document links;
- fix current-field view;
- create page artifacts in the active path;
- transact and promote extraction runs;
- persist source/retrieval chunks separately.

### Phase C: Outbox v2

- add idempotency and aggregate references;
- add atomic `SKIP LOCKED` claim RPC;
- add lease token, worker identity, and heartbeat;
- fence completion/failure;
- remove sensitive payloads;
- make handlers update canonical document state.

### Phase D: Principal claim and erasure

- create principal lineage;
- transfer every aggregate;
- resolve duplicate uploads;
- revoke anonymous access;
- implement document and account erasure jobs;
- pseudonymize retained consent proof.

### Phase E: Billing and analytics convergence

- remove production SQLite truth;
- verify RevenueCat events server-side;
- project Supabase subscriptions and entitlements;
- add analytics `event_id`;
- enforce event schema;
- wire the shared hashed rate limiter.


## Required verification

### Migration

- empty database to latest;
- previous schema to latest;
- migration replay;
- schema diff equals zero;
- function/trigger/index/grant snapshot.

### RLS

Test as anon, account A, account B, and service role.

### Evidence

- cross-document field/page link rejected;
- cross-page span link rejected;
- one current field per field name;
- failed run never promoted;
- rerun preserves history;
- delete cascades correctly.

### Outbox

Using multiple real DB connections:

- no double claim;
- losing worker claims another job;
- stale worker cannot complete;
- heartbeat prevents reclaim;
- idempotency prevents duplicate logical jobs;
- payload contains no source/password.

### Ownership and deletion

- anonymous claim with and without duplicate source;
- chunks and all aggregates move;
- old principal loses access;
- repeated claim is idempotent;
- source, pages, chunks, evidence, billing, analytics, local corrections, and auth follow the erasure policy.

### Billing

- forged mobile request cannot unlock paid plan;
- webhook replay is idempotent;
- cancellation, renewal, refund, reinstall, and restore reconcile.

### Query

- exact identifiers;
- FTS;
- selected-document filtering in SQL;
- owner isolation;
- current index version;
- `EXPLAIN ANALYZE` budgets.


## Decisions

### Keep

- Supabase;
- private Storage;
- fixed embedding dimensions per index;
- evidence substrate concept;
- raw/normalized/display values;
- consent event history;
- Postgres outbox direction;
- service-role-only sensitive tables;
- owner-scoped source deduplication;
- atomic shared rate limits.

### Change

- manual SQL to automated migrations;
- owner rewrites to principal lineage;
- page identity to version/run identity;
- app-only evidence checks to DB constraints;
- multi-call field writes to transaction/RPC;
- timestamp-only leases to fenced lease tokens;
- queue payloads to references;
- SQLite billing to verified Supabase billing;
- one chunk content field to source/retrieval fields;
- raw immutable consent identity to pseudonymous proof.

### Retire

- production SQLite analytics correctness;
- production SQLite subscription truth;
- Redis/process-memory rate-limit correctness;
- client-asserted paid entitlement authority;
- source bytes/passwords in generic jobs;
- claims of DB-enforced append-only evidence without enforcement.


## Release gate

The Supabase data plane is production-ready only when:

- all migrations apply automatically and upgrade correctly;
- invalid SQL is removed;
- schema diff is clean;
- RLS tests pass;
- evidence links cannot cross documents;
- page and extraction runs are versioned;
- citation view returns one current accepted field;
- evidence writes are transactional;
- active upload produces page artifacts and citations;
- outbox has lease fencing, heartbeat, and idempotency;
- queue payloads are references only;
- ownership claim transfers every aggregate and revokes old access;
- erasure verifies every store;
- consent retention is pseudonymous and explicit;
- RevenueCat, Supabase subscriptions, and mobile entitlement agree;
- analytics uses event IDs;
- shared hashed rate limiting is active;
- real concurrent Postgres tests pass;
- no migration is pending;
- the current commit has CI evidence.

## Bottom line

The best new CoverWise architecture is already visible in the database direction:

```text
principal
  -> document version
  -> processing run
  -> page/span evidence
  -> extracted field
  -> retrieval index
  -> customer projection
  -> deletion/audit
```

The next database phase must be **integration integrity, not schema expansion**.
