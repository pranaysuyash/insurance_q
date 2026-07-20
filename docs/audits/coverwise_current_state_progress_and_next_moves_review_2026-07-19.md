# CoverWise Current-State Progress Review and Next-Move Plan

**Date:** 2026-07-19  
**Repository:** `pranaysuyash/insurance_q`  
**Branch:** `main`  
**Current commit:** `dc29d6a37fafd530ee63214366db96833c2b564d`  
**Previous full-audit baseline:** `e3440a5da174c0cbbe279878bdff21950d8cab63`  
**Delta:** 12 commits ahead, 0 behind  
**Evidence:** static inspection of the current code, migrations, tests, ADRs, product surfaces, and baseline-to-current diff  
**Runtime status:** no combined GitHub statuses or workflow runs were attached to the current commit  
**Doctrine:** long-term first principles and `motto_v3.md`

---

## Executive verdict

A large amount of valuable work has been done.

CoverWise is materially better than the July 18 baseline. The most important improvement is not a new screen or model. The repository now contains credible long-term contracts for:

- evidence-backed extraction;
- page and field provenance;
- deterministic-first parsing;
- capability-specific document states;
- durable asynchronous work;
- operator-only analytics access;
- fail-closed analytics consent;
- safer error telemetry;
- canonical architecture and decision records;
- a narrower and more honest coverage-limit and claim-assistance direction.

This is real progress.

The current state is best described as:

> **Strong foundations being built beside the legacy execution path, not yet replacing it.**

Several commits correctly state that they “ship the contract” and defer adoption. That is acceptable for a staged refactor only when the repository and product do not claim the new contract is already the operational truth.

At present, parts of the canonical documentation and UI overstate completion:

- normal uploads do not run the new evidence pipeline;
- the evidence API contains an identity-field bug;
- the mobile evidence client is unauthenticated;
- new document states are collapsed to legacy `completed` or `failed`;
- the outbox worker has no handlers;
- principal encryption is neither adopted nor safe to adopt in its current JWT-derived form;
- account and document deletion remain incomplete;
- CI is structurally stale and the current commit has no workflow evidence.

### Updated release decision

**Still NO-GO for public use with real customer policies.**

The reason has changed.

The old repository was a NO-GO because trust, lifecycle, and architecture foundations were weak or missing.

The current repository is a NO-GO because several strong foundations are disconnected while legacy paths still determine product behaviour.

This is a much better position. It does not need another broad redesign. It needs disciplined convergence.

---

## 1. Overall scorecard

| Area | July 18 | Current | Direction |
|---|---:|---:|---|
| Architectural direction | C | B+ | Strong improvement |
| Evidence/provenance design | D | A- | Major improvement |
| Evidence-pipeline adoption | F | D | Contract exists, path disconnected |
| Document-state honesty | F | C | Pure model good, propagation broken |
| Security posture | D | C+ | Several real closures; lifecycle gaps remain |
| Privacy-copy honesty | D | C | Improved in places; contradictions remain |
| Async reliability | D | B design / F adoption | Excellent contract, unused |
| Product-boundary discipline | D | C+ | Thin slices improved; unsafe legacy remains |
| Mobile trust UX | C | B- | Citation and honest-state patterns are good |
| Data consistency | D | C | More canonical models, still parallel truth |
| Observability | D | C+ | Better substrate, enforcement incomplete |
| CI/release evidence | D | F | Stale workflow; no current status |
| Documentation discipline | C | B- | Better canonical docs; claims and volume need control |
| Motto v3 alignment | C- | B- intent / C execution | Reasoning improved faster than adoption |

---

## 2. Improvements that are genuinely good

### 2.1 Evidence substrate is the right long-term architecture

**Files**

- `supabase/migrations/2026_07_18_evidence_substrate.sql`
- `src/models/evidence.py`
- `src/services/evidence_substrate_service.py`
- `src/services/evidence_pipeline.py`
- `src/api/evidence.py`
- `mobile/lib/models/field_citation.dart`
- `mobile/lib/services/evidence_service.dart`
- `mobile/lib/widgets/field_citations_card.dart`

The schema introduces the missing trust chain:

```text
document
  -> page artifact
  -> source span
  -> extracted field
  -> field evidence
  -> customer-visible citation
```

Strong aspects:

- raw, normalized, and display values are separated;
- parser kind and evidence strength are explicit;
- source coordinates have a place in the model;
- fields are intended to be append-only;
- the UI does not invent citation strings;
- deterministic and LLM fields are distinguishable;
- extraction cost has a dedicated model;
- service-role access stays behind an owner-scoped API.

This is the strongest improvement in the repository.

**Decision:** Keep it and make it the actual ingestion truth. Do not create another extraction or citation architecture.

### 2.2 Deterministic-first extraction is correct

Current deterministic fields include policy number, policyholder, sum insured, policy start date, premium, and insurer. Room-rent cap is the first LLM-assisted experiment.

This lowers cost, improves reproducibility, and makes failures auditable. The LLM extractor also attempts to verify that the cited clause appears in the source.

**Decision:** Expand through measured field-specific extractors rather than one broad summary prompt.

### 2.3 Capability-specific state derivation is a sound primitive

`derive_document_state()` can distinguish ready, summary partial, ready for Q&A, indexing failed, OCR required, password required, partial, and failed.

That models what the user can do instead of pretending processing is binary.

**Decision:** Keep it, but propagate it through repository, API, mobile, retries, and operator tooling.

### 2.4 Contextual retrieval is off by default

This directly addresses contamination of source evidence with generated context.

**Decision:** Keep disabled until `source_text` and `retrieval_text` are separate and a CoverWise benchmark proves benefit.

### 2.5 Operator-only analytics reads are a real security closure

Global analytics endpoints now require a bearer and an `X-Operator-Token`, use constant-time comparison, and fail closed when unconfigured.

**Decision:** Keep as a transitional control; later replace with operator RBAC.

### 2.6 Analytics consent now fails closed

No consent record, ledger corruption, or revocation now means analytics off. The client also uses authenticated transport for event upload.

This is a real product-behaviour correction.

### 2.7 Error telemetry is materially safer

The mobile client no longer sends exception strings or stack traces. It sends a small error classification only.

**Decision:** Keep. Replace Dart `hashCode` with stable explicit error codes because `hashCode` is not a durable cross-build identifier.

### 2.8 Bearer-token clipboard exposure is closed

The Profile screen no longer displays or copies the active bearer token.

**Decision:** Closed. Do not reintroduce it in a release build.

### 2.9 Coverage-gap framing is much more honest

The new thin slice shows a cited room-rent cap, cited insurer, and an explicit list of fields not yet extracted. It no longer recommends buying missing policy types.

**Decision:** Keep the substrate-backed approach, but rename the screen to **Coverage limits found** or **Coverage details to review** until real evidence-backed gap analysis exists.

### 2.10 Claim assistance is more bounded

The new screen separates cited insurer identity from generic educational steps and explicitly lists unimplemented policy-specific fields.

**Decision:** Keep the narrow entry point, but remove fixed timelines and Google search before treating it as a trusted claim workflow.

### 2.11 The Supabase outbox is a sound architecture choice

The outbox contract includes attempts, leases, retries, dead letter, health views, typed job kinds, and one dispatcher registry. It avoids premature Cloud Tasks complexity while keeping durable work with durable state.

**Decision:** Keep. Adopt first for document processing and substrate extraction.

### 2.12 ADR and canonical-document discipline improved

The repository now records accepted decisions, alternatives, deferred work, rollback, and evidence expectations.

**Decision:** Keep the discipline; reduce document volume and correct claims that exceed actual adoption.

---

## 3. Good contracts that are not operational

### 3.1 Evidence pipeline is not invoked by normal uploads

The active path remains:

```text
POST /documents/upload
  -> FastAPI BackgroundTasks
  -> DocumentProcessingService.process_document_full
  -> legacy text/OCR
  -> legacy summary
  -> legacy RAG
```

It never calls `EvidencePipeline.run_for_document()`.

Therefore normal uploads do not produce page artifacts, source spans, extracted fields, field evidence, or mobile citations.

### 3.2 Outbox worker is idle

`src/workers/outbox_worker.py` registers no handlers. Current async paths still bypass the outbox.

Adopt in this order:

1. document processing;
2. substrate extraction;
3. deletion;
4. webhook reconciliation;
5. subscription writeback.

### 3.3 Supabase analytics is not yet canonical

SQLite is still always written and still powers reads. Supabase write is feature-flagged and best effort. No parity evidence exists.

Use a real `event_id`, make Supabase canonical, and retain SQLite only for local development.

### 3.4 Citation UI is disconnected

Two direct defects block it:

- `src/api/evidence.py` uses `current_user.id`; the model exposes `uid`;
- `mobile/lib/services/evidence_service.dart` creates raw Dio without the auth interceptor.

### 3.5 New states are discarded downstream

`process_document_background()` treats only `completed` as success and maps all other new states to `failed`.

The new state model is therefore not the system truth.

---

## 4. Critical defects

### P0-01: Evidence API identity bug

`repo.get(document_id, current_user.id)` must use `current_user.uid`.

The broad exception handling currently turns this programming defect into a misleading 503.

### P0-02: Evidence mobile client is unauthenticated

Inject the canonical authenticated Dio rather than constructing a private raw client.

### P0-03: Evidence pipeline is outside ingestion

Compose the evidence service and pipeline at startup and make substrate extraction a required durable stage.

### P0-04: Derived document states are collapsed

Persist exact state and expose capability flags such as `source_ready`, `summary_ready`, `qa_ready`, and `complete_pages`.

### P0-05: Mixed PDFs remain silently partial

The main path joins embedded text and skips image-only pages while still treating the document as complete.

Process each page independently and mark unreadable pages.

### P0-06: Persistent local processing copy remains

`storage/documents/{document_id}_{filename}` is outside canonical lifecycle, is not guaranteed to be cleaned, and uses a user filename in a path.

Use canonical storage or a generated secure temporary file with `finally` cleanup.

### P0-07: Undefined `document_id` in parser error handling

`_extract_text()` logs a variable it does not receive. An original parser failure can be replaced by `NameError`.

### P0-08: Principal encryption ADR should be reopened

The key is derived from the full Supabase access JWT. Access JWTs rotate:

```text
token A -> key A
refresh
token B -> key B
```

Normal refresh or re-login can make existing boxes unreadable.

Additional defects:

- salt key is global, not per principal;
- migration flag is global, not per principal or box;
- generated-byte helper ignores requested length;
- migration is not crash-safe;
- service is not called from startup or auth transitions;
- boxes are still opened unencrypted;
- sign-out does not clear a composed key service;
- storage is not namespaced per principal.

**Better direction:** stable principal namespace plus a random device/principal DEK protected by Keychain/Keystore. Do not derive persistent storage encryption from rotating bearer text.

### P0-09: Account deletion HTTP contract mismatch

Backend returns 202. Mobile accepts only 200. The client can report failure after the server already deleted some data.

Use a typed deletion-request/status model.

### P0-10: Deletion promises retry that does not exist

The backend says partial stages will be retried by a durable job, but no deletion job is enqueued.

### P0-11: Mobile document delete and replace are still local-only

`deleteDocument()` removes only the local file and Hive row. Replace uploads a new document and locally removes the old one, leaving the remote original.

### P0-12: Anonymous claim still transfers an incomplete aggregate

Documents can move without all chunks, evidence, summaries, answers, and consent. The old anonymous principal is not revoked.

### P0-13: “Minimum viable evidence” checks completeness, not evidence

`PolicySummary.hasMinimumViableEvidence` checks fields are populated, not that citations exist. Rename it to completeness and create a separate evidence-state contract.

### P0-14: Policy detail mixes cited and uncited facts

The screen renders substrate citations beside legacy summary money, benefits, exclusions, waiting periods, and coverage items. The cited card can make the whole page feel verified.

Every material field needs a status: verified, needs confirmation, conflicting, not found, or not yet extracted.

### P0-15: CI is structurally stale

The workflow:

- installs Node 16;
- runs `npm install` and `npm run build` at root despite no root `package.json`;
- does not install Flutter;
- does not run Flutter analysis/tests;
- does not test migrations;
- does not run Postgres integration tests;
- publishes a mutable `latest` image.

No current status or workflow run is attached to `dc29d6a`.

### P0-16: Embedding fallback remains unsafe for Supabase

Fallback can change dimensions and call `qdrant_client.recreate_collection()` even when Supabase is active.

Use one model/dimension per index version and fail closed or write a separate shadow index.

### P0-17: Exact lookup remains broken in the Supabase path

Exact lookup still depends on local FTS behaviour that is not initialized for the canonical production backend.

Implement Postgres exact/entity lookup and FTS with filters inside SQL.

---

## 5. Product surfaces that should move

### Remove Insurance Health Score

The score assumes health, motor, and life are “three essential types,” treats missing uploaded policies as weak coverage, and labels households Excellent or At Risk.

That is an invented suitability score, not document understanding.

A safe replacement is **Workspace completeness**, measuring parse success, evidence coverage, renewal dates found, and unverified fields.

### Remove What-if premium calculator

The fixed premium multipliers are invented underwriting assumptions and conflict with the permanent non-regulated boundary.

### Retire the old claims assistant

The repository now has old `claims_assistant_screen.dart` and new `claim_assistance_screen.dart`. `/claims` still points to the old path.

Retain the new substrate-backed path and remove the parallel legacy feature.

### Delete/quarantine the old coverage-gap engine

The new screen is safer, but the old recommendation engine remains available in services/providers and can regress back into the product.

### Remove fixed generic claim deadlines

Use “notify the insurer promptly and confirm the deadline in the policy” unless a cited policy deadline exists.

### Correct phone-link and device-first copy

A locally stored phone number is still described as linked and cross-device ready. Policies are processed and stored remotely, so “personal details stay local” is also too absolute.

---

## 6. New substrate issues to fix

### Latest field version is not selected

`v_field_citations` picks strongest evidence for each field row, but not the latest row per `(document_id, field_name)`. Reruns can return duplicates.

### Page artifacts are called append-only but unique by page

`unique(document_id, page_number)` prevents versioned reprocessing. Add `document_version_id` and `processing_run_id`.

### Page images are referenced but not uploaded by normal processing

Make page rendering and image storage part of the evidence job.

### Source spans are not populated

Page citations are acceptable for a first release, but docs and UI must not imply exact clause highlighting yet.

### Parser version is a timestamp

Persist stable parser, schema, prompt, model, run, and release versions separately.

### Room-rent extractor calls the wrong LLM contract

It calls `llm.complete()`, while production `LLMClient` exposes `generate()` and `generate_structured()`. Tests use a fake `complete()` and miss the integration defect.

### LLM cost is recorded as zero

Wire actual model/token usage into extraction cost records.

---

## 7. Analytics and RevOps remaining issues

What improved:

- authenticated event upload;
- fail-closed consent;
- operator-only reads;
- Supabase target schema;
- safer error events;
- install/session concepts.

What remains:

- validation runs only in debug and does not block events;
- unknown event names are accepted;
- backend accepts arbitrary names and properties;
- batch/property sizes are unbounded;
- install/session values are emitted inside `props` instead of the top-level fields the server expects;
- uniqueness by `(received_at,event_name,user_uid)` is not a true event identity;
- SQLite is still treated as durable on Cloud Run.

Introduce a client-generated `event_id` and strict shared schema enforcement on both sides.

---

## 8. Embedding benchmark judgement

The harness is good engineering:

- domain-specific ground truth;
- recall@3;
- explicit switch threshold;
- provider adapters;
- repeatable outputs.

The committed result is not decision-grade:

- policy IDs are `fixture-policy-*`;
- only 12 queries ran;
- timings are milliseconds;
- the report displays configured limits of 50 policies and 20 queries, not 50 real policies and 1,000 labelled pairs.

Keeping `text-embedding-3-small` is still correct because it matches the current 1536-dimensional schema and no real benchmark justifies migration.

Do not describe the fixture run as a real provider comparison.

---

## 9. Documentation and repository hygiene

### Good

- canonical architecture document;
- ADR index;
- explicit product-boundary decisions;
- launch playbook;
- migration/rollback thinking.

### Correct next

Label every major component as one of:

- active;
- implemented but not adopted;
- accepted design only;
- deferred.

The canonical architecture currently overstates evidence ingestion, outbox adoption, principal encryption, and citation operation.

### Clean up

Move or remove:

- root binary DOCX;
- generated audit docs from root;
- committed `insurance_app.db`;
- committed Hive test databases;
- dry-run benchmark results presented as decisions;
- unnecessary vendored skill trees if not deliberately part of the repo.

Add `.dockerignore` and a generated-artifact policy.

---

## 10. Motto v3 alignment

| Principle | Current judgement |
|---|---|
| Long-term first principles | Stronger |
| One canonical path | Not yet; strong new paths coexist with legacy |
| Code is truth | Violated by some canonical-doc claims |
| Evidence tiers | Improved language; current CI evidence absent |
| Risk-based verification | Better intent; high-risk integration tests missing |
| AI output is a proposal | Strong improvement |
| Data architecture before UI | Strong improvement |
| Observability is delivery | Partial; substrates not canonical yet |
| Customer-facing claim checks | Mixed; honest states added, deletion/phone/score claims remain |
| Scope control | Mixed; thin slices good, unsafe legacy remains |
| Decision records | Strong |
| Completion means adopted | Violated by “contract shipped” patterns |
| Operator workflow | Partial; views exist, recovery actions do not |
| No parallel systems | Violated by old/new claims, gaps, extraction, and async paths |

---

## 11. Ordered next-move plan

### Phase A: Make one evidence-backed upload work end to end

1. Fix `current_user.uid`.
2. Inject authenticated Dio into `EvidenceService`.
3. Compose EvidenceSubstrateService and EvidencePipeline at startup.
4. Render each page and store page artifacts.
5. Persist page text and page-level spans.
6. Run deterministic extractors.
7. Run room-rent through `generate_structured`.
8. Persist cited fields.
9. Project summary from cited fields.
10. return exact capability state;
11. fetch citations on mobile;
12. open exact cited page;
13. add Postgres-backed integration test.

**Exit gate**

```text
upload policy
  -> page artifact exists
  -> cited sum insured exists
  -> owner API returns it
  -> mobile renders value + page
  -> other owner gets 404
```

### Phase B: Propagate truthful state

- typed state enum;
- capability flags;
- unreadable-page warnings;
- failed-stage retry;
- remove in-memory stage truth.

### Phase C: Adopt outbox

- document-processing handler;
- substrate-extraction handler;
- enqueue from upload;
- handler registration;
- worker deployment;
- lease heartbeat;
- idempotency key;
- dead-letter retry tooling.

### Phase D: Close identity and lifecycle

- remote document deletion;
- remote replacement/versioning;
- durable account-erasure job;
- full anonymous aggregate transfer;
- anonymous revocation;
- principal-scoped local namespaces;
- redesigned encryption key;
- corrected phone/privacy copy.

### Phase E: remove unsafe product surfaces

Hide/remove:

- Insurance Health Score;
- What-if premium calculator;
- old gap engine;
- old claims assistant;
- unsupported deadlines and purchase/renewal recommendations.

Retain:

- cited policy summary;
- grounded Q&A;
- renewal dates;
- insurer contacts;
- evidence-backed owned-policy comparison;
- narrow policy limits;
- neutral claim preparation.

### Phase F: rebuild CI

Backend:

- locked dependencies;
- unit tests;
- Postgres migration/integration tests;
- coverage gate.

Flutter:

- pinned Flutter;
- `flutter analyze`;
- `flutter test`;
- Android build.

Security:

- secret scan;
- dependency scans;
- container scan;
- SBOM.

Image:

- build only after gates;
- immutable SHA tags;
- no `latest`-only release identity.

---

## 12. First 20 concrete moves

1. Fix `current_user.id` to `uid`.
2. Use authenticated Dio for evidence.
3. Accept/parse account deletion HTTP 202.
4. Remove false deletion-success snackbar.
5. Fix undefined `document_id`.
6. remove persistent local processing copies;
7. persist exact derived state;
8. add page-level extraction result;
9. wire page artifacts into active processing;
10. wire deterministic evidence extraction;
11. change room-rent extractor to `generate_structured`;
12. fix citation-view latest-version semantics;
13. add document version and processing run IDs;
14. register processing and substrate outbox handlers;
15. add outbox idempotency and atomic claim RPC;
16. implement remote delete and replacement;
17. reopen JWT-derived encryption ADR;
18. remove Health Score and What-if from navigation;
19. replace CI workflow;
20. mark architecture components active/contract/deferred.

---

## 13. What not to do next

Do not add:

- another model provider;
- another extraction framework;
- another vector store;
- more citation UI before the current API works;
- more ADRs for already-decided work;
- more RevOps events before enforcement;
- a larger operator dashboard before real jobs exist;
- new family, health, claim, or monetization features;
- more generated audit documents at repository root.

The bottleneck is adoption and integration, not ideation.

---

## Final judgement

### What improved

A great deal:

- architectural reasoning;
- trust-model sophistication;
- evidence schema;
- deterministic extraction;
- privacy controls;
- operator authorization;
- safer telemetry;
- product-boundary awareness;
- decision discipline;
- unit/widget-test coverage.

### What is actually good long term

- Supabase as one durable state plane;
- evidence substrate;
- page and field provenance;
- deterministic-first extraction;
- one versioned embedding index;
- Postgres outbox;
- owner-scoped API;
- explicit unknown/partial states;
- narrow document-grounded product surfaces;
- ADRs tied to acceptance and rollback.

### What is overclaimed

- active evidence ingestion;
- active outbox reliability;
- active principal encryption;
- complete deletion;
- evidence-backed policy detail;
- decision-grade embedding benchmark;
- release readiness.

### What needs to move

Shift from:

```text
design contract
  -> ADR
  -> skeleton
  -> another contract
```

to:

```text
one integrated path
  -> production-like test
  -> operator recovery
  -> delete legacy path
  -> update canonical doc
```

CoverWise is no longer architecturally directionless.

Its primary risk is now **unfinished convergence**.
