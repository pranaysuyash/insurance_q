# CoverWise J02–J07 Deep Dive — 2026-07-21

Status: exploration and contract audit; no product code changed in this pass.

This dated artifact is evidence for the canonical journey map at
`docs/user_experience/coverwise_user_journey_map.md`. It is not a second
journey source of truth. The journey map owns the product journey; this file
records the implementation findings, risks, and closure paths discovered while
tracing onboarding through Q&A.

## Scope and method

The trace covered:

`J02 onboarding → J03 identity and account claim → J04 upload → J05 processing and recovery → J06 evidence review → J07 Q&A`.

Evidence sources were current Flutter and FastAPI code, migrations, tests,
architecture/ADR documents, and official Supabase security documentation. The
static findings below are Tier 1 unless a test or prior runtime audit is named.

## End-to-end contract findings

| Journey | What is structurally sound | Confirmed gap or risk | Tier | Closure path |
|---|---|---|---:|---|
| J02 onboarding | Three-step orientation; terms/analytics state is represented locally; onboarding completion is persisted | Consent is local-only in the onboarding path, local and server consent vocabularies differ, consent failures are swallowed, and Skip can complete without an explicit terms acceptance decision. Copy still includes product-boundary-sensitive renewal language | 1 | Define one server-auditable consent contract and purpose vocabulary; make completion semantics explicit; replace boundary-drifting copy; test accept, decline, skip, retry, offline, and replay |
| J03 identity | Anonymous and account sessions are both supported; account claim has owner transfer; account deletion has a visible result contract | Custom anonymous identity and Supabase identity are dual principals; claim visibly transfers server document ownership but local encrypted principal migration is not proven; deletion returns 202 while the route performs synchronous best-effort deletion and references a durable job that is not enqueued in the inspected route; explicit session revocation checking is not visible | 1 | Choose the canonical principal lifecycle; make claim migration cover every local/server representation; implement durable deletion job + receipt or change the contract; verify session revocation and two-user isolation |
| J04 upload | Size/content validation, owner-scoped source-hash dedupe, object rollback on metadata failure, rate limits, consent/version fields, and offline local save exist | Production upload still schedules `process_document_background` through FastAPI `BackgroundTasks`; the durable outbox is documented as canonical but is not the upload enqueue path. Legacy lead-capture fields/routes remain in the upload contract despite the permanent product boundary | 1 | Make one durable enqueue path authoritative; add retry/dead-letter/operator visibility; remove or deprecate lead capture from document upload after caller inventory |
| J05 processing | Capability-aware state derivation includes partial, OCR-required, password-required, retryable, terminal, and QA states; processing lease and source-object rollback are present | Process loss after API termination remains possible when work is held by in-process background execution; real recovery/lease-expiry proof is missing | 1 | Enqueue transactionally with document receipt, run worker crash/retry/duplicate/timeout tests, expose state transitions and operator actions |
| J06 evidence | Append-only evidence substrate; page artifacts/source spans/field citations; owner check before evidence read; main RAG path verifies citations against immutable `source_text` and preserves approximate status | Typed structured extraction is stronger in the main RAG path than in the policy-field extractor; cross-document and fresh-runtime evidence proof is missing; service-role substrate access depends on API owner checks | 1–2 | Use typed schema validation for every model-backed extraction; run real-document citation acceptance tests; prove owner isolation and page/span navigation in the running stack |
| J07 Q&A | `/query` overwrites client filters with authenticated owner scope; retrieval quality gate can return honest not-found; structured answer schema, citation verification, missing-information and follow-up fields, context-only fallback, and query tracing exist | `/query` and `/documents/query` are parallel product actions with different transport contracts; mobile can use a local policy-demo answer only when an explicit compile-time demo flag is enabled, but the fallback must remain visibly non-production; fresh runtime proof of retrieval, citations, and failure recovery is absent | 1–2 | Inventory callers, select one canonical owner-scoped query route, deprecate/migrate the other, then verify answer/citation/fallback behavior against a real policy and two owners |

## Important implementation evidence

### J02–J03: consent and principal lifecycle

- `mobile/lib/screens/onboarding_screen.dart` records through the local
  `ConsentLedger` and catches consent errors as best effort.
- `mobile/lib/services/server_consent_service.dart` exists, but the traced
  onboarding/upload paths do not call it.
- Mobile purposes include `document_processing`, `analytics`, `lead_capture`,
  and `terms_accepted`; the server migration accepts a different vocabulary
  (`privacy_policy`, `analytics`, `marketing_emails`, `camera_access`). This is
  a contract mismatch, not merely a naming difference, because it prevents a
  single auditable answer to “what did the person consent to?”
- `mobile/lib/services/auth_service.dart` claims anonymous data by calling the
  server owner-transfer endpoint. The inspected implementation does not prove
  migration of encrypted Hive records from the anonymous principal key to the
  account principal key.
- `src/api/user.py` reports account deletion as `202` and can return a partial
  result, but the inspected route deletes synchronously and does not enqueue the
  durable deletion job named in its response message. This is a user-facing
  contract/operability mismatch.

### J04–J05: upload and processing

- `src/api/document.py` performs validation, owner-scoped hash replay, object
  storage, metadata persistence, and cleanup if metadata creation fails.
- The same route calls `background_tasks.add_task(process_document_background,
  ...)`. The outbox migrations, `JobOutboxService`, dispatcher, and handlers
  describe a durable queue, but the traced upload route does not enqueue the
  document-processing job.
- `src/services/document_processing_service.py` has a single `_save_file`
  implementation with one write in the current file; the earlier suspicion of a
  duplicate write is not confirmed and is not recorded as a defect.
- Mobile has an honest local pending/offline document state, but the inspected
  search did not establish a complete automatic pending-upload synchronization
  path. This remains an open Tier 1 question, not a claim that sync is absent.

### J06–J07: evidence and Q&A

- `src/rag/pipeline.py:1094-1099` calls `_verify_citations` on generated or
  context-only citations before returning them.
- `src/rag/pipeline.py:1046-1069` uses typed `RAGAnswer` structured generation,
  low temperature, and a fallback model; `src/services/evidence_pipeline.py`
  still has a weaker model-backed extraction path that should converge on typed
  validation.
- `src/app/main.py` and `mobile/lib/services/query_service.dart` provide safe
  unavailable/not-found states. The mobile local demo answer is gated by
  `BOOTSTRAP_POLICY_DEMO`, whose release validation rejects enabling it in a
  release build; it must not be used as evidence of production Q&A.
- `src/app/main.py` exposes JSON `POST /query`; `src/api/document.py` exposes
  form `POST /documents/query`. The existing audit already records the shape
  divergence. Under the canonical-route rule, this is a retirement decision,
  not a reason to add a third adapter route.

## Supabase security alignment to verify

The repository’s newer evidence, outbox, and consent migrations use RLS,
service-role-only grants, and `security_invoker` views. That is directionally
aligned with Supabase guidance, but it does not replace runtime proof of the
API owner checks and storage configuration.

- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security): exposed tables should have RLS; service-role access bypasses RLS and must remain server-only.
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control): private object access depends on Storage RLS policies and the required operation grants.
- [Bucket fundamentals](https://supabase.com/docs/guides/storage/buckets/fundamentals): the CoverWise bucket is configured private in the inspected migration.
- [Auth sessions](https://supabase.com/docs/guides/auth/sessions): deleting a user does not by itself prove that already-issued access tokens are unusable; sensitive paths need explicit revocation/session validation where required.

## Priority closure order

1. Establish one canonical consent contract and one canonical query route.
2. Replace upload-time in-process processing with the durable outbox path and
   prove retry, duplicate, crash, timeout, and dead-letter behavior.
3. Define anonymous-to-account migration across local encrypted state and every
   server representation.
4. Make deletion semantics truthful: durable job, idempotent stages, receipt,
   operator visibility, and explicit session-revocation posture.
5. Run a real-document Tier 3 evidence/Q&A acceptance pass with two principals,
   weak retrieval, missing pages, OCR-required input, and unavailable model/storage
   conditions.

## Verification notes from this pass

Focused command:

```text
pytest -q tests/test_anonymous_auth.py tests/test_document_state_derivation.py tests/test_citation_verifier.py tests/test_citation_verifier_integration.py tests/test_evidence_pipeline.py tests/test_supabase_fts.py
```

The first collection attempt was blocked by the missing `jose` package while
loading `tests/test_anonymous_auth.py`. A reduced run completed with **45 passed,
8 failed, 3 errors**:

- the citation-verifier unit tests still unpack two return values while the
  current verifier returns `(is_valid, reason, status)`; this is a test/contract
  drift that blocks a clean J06 verification claim;
- the Supabase FTS fixtures cannot construct `SupabaseVectorStore` because the
  installed `supabase` module does not expose `create_client`; this blocks FTS
  retrieval verification in the current environment;
- document-state, evidence-pipeline, citation-integration, and other reduced
  checks passed, but those passes do not compensate for the two blocked areas.

These failures are inside the J06/J07 verification blast radius and need a
resolution before the evidence/Q&A path can claim a clean targeted suite. No
test or dependency files were changed during this exploration pass.

## Exploration questions carried forward

- Is the person’s consent decision allowed to be recorded locally first, or must
  onboarding/upload block until the server ledger has acknowledged it?
- Should anonymous local documents remain device-only until account claim, or is
  cross-device ownership a product promise? The answer determines the principal
  migration design.
- Is Q&A one product action with JSON as the canonical contract, or is the form
  route an intentionally separate legacy/integration surface? If legacy, what is
  its deprecation trigger?
- What exact user-visible state distinguishes “uploaded,” “processing,” “partially
  understood,” “evidence unavailable,” and “answer unavailable”?

## Three review passes

### Pass 1 — Immediate correctness

Confirmed the findings against current call sites rather than relying on ADR
intent. Removed the suspected `_save_file` duplicate-write finding because the
current implementation contains one write.

### Pass 2 — Architecture and long-term viability

Identified consent vocabulary drift, dual principal ownership, in-process versus
durable async execution, and duplicate query routes as source-of-truth risks.
Closure is staged around canonical contracts, not new compatibility layers.

### Pass 3 — Rule compliance and supervision readiness

Marked static findings Tier 1/2, separated prior runtime evidence from fresh
verification, named operator and recovery requirements, and preserved unresolved
questions rather than converting them into assumptions.

## Anything else?

Yes: J02–J07 are not six isolated screens. They are one trust chain. If consent,
principal ownership, durable processing, evidence provenance, and Q&A scope do
not share a single auditable contract, a polished answer can still be wrong,
unrecoverable, or impossible to explain after the fact.
