# CoverWise launch-readiness review — 2026-07-12

## Decision

CoverWise is **not cleared to launch** as of this review. The mobile client is
again buildable, but the deployed backend cannot safely serve real insurance
documents. The launch path is a privacy-preserving, unified mobile API with
durable document ownership and a freshly deployed, integration-tested release.

## Evidence

| Area | Evidence tier | Current finding | Launch disposition |
| --- | --- | --- | --- |
| Flutter client | Tier 2 | `flutter analyze` is clean and `flutter test` passes 14 tests after repairing merge regressions in app navigation and Q&A. | Green for continued mobile work; not release proof. |
| Current production API | Tier 4 | `https://aa2485vt7t.ap-south-1.awsapprunner.com/health` returned `200`, but its OpenAPI document has no security schemes and does not include `/documents/{document_id}/summary`. | Blocked: deployed image is stale relative to current mobile contracts. |
| Document privacy | Tier 1 + Tier 4 schema evidence | `src/api/document.py` exposes upload, status, query, individual summary, and all-summaries paths without a verified principal. `session_id` is caller supplied and status permits access without it for backwards compatibility. | Critical blocker. |
| Storage and deletion | Tier 1 | Documents are tracked in process-global `DOCUMENTS`; originals and summary fallback are local instance disk; RAG deletion remains TODO. | Critical blocker: no durable ownership or complete deletion semantics. |
| Backend tests | Tier 2 | Historical tests targeted retired Azure hosts. They were converted to opt-in integration tests; the active Python environment has 62 passing non-Azure tests and one frontend assertion was updated in this pass. Full re-run is pending at this writing. | Yellow until fresh full suite result and real environment run. |
| LLM service | Tier 1 + prior review evidence | `docs/review/go_live_blocking_issues_2026-07-11.md` records a production OpenAI quota failure. Current health payload is from 2025 and cannot prove chat completion works now. | Critical blocker until a funded key and a real policy upload/query prove it. |

## Required architecture before public launch

### 1. Preserve the no-login onboarding, but establish a real principal

The product specification intentionally avoids an account wall. That does not
mean unauthenticated data access. The current implementation uses a server-signed
anonymous bearer principal on first launch, stored in platform secure storage and
attached to every policy-bearing mobile request. Before public launch, either
harden this issuer with key rotation/revocation or replace it with Firebase
Anonymous Authentication (or an equivalent managed provider). Upgrade anonymous
users to a named account only when they choose to back up or share their policies.

The backend must reject absent/invalid identity for all policy-bearing routes.
There must be no caller-provided `session_id` authorization path, no
backward-compatible public status lookup, and no public all-summaries route.

### 2. Establish one durable ownership model

Use:

- object storage for encrypted original documents;
- Postgres/DynamoDB for document metadata, processing state, and ownership;
- Qdrant metadata filtered by immutable owner ID and document ID;
- a deletion job that removes object, metadata, summary, vectors, cached
  answer history, and derived family records, with an auditable completion
  record.

No process-global list or instance-local disk may be the production source of
truth. RAG filters must be enforced server side; client document IDs are a
filter, never an access control mechanism.

### 3. Deploy the canonical unified API

The deployed App Runner service must contain the current API contract before
shipping a mobile binary. CI should fetch its OpenAPI document after deploy and
assert that required endpoints, response schemas, CORS origins, health state,
and authentication requirements match the release manifest.

### 4. Prove the critical user flow against the real deployment

In a disposable launch test identity:

1. install a release-signed Android build;
2. create anonymous identity;
3. upload a real text PDF and a scanned PDF;
4. observe progress, a grounded answer with page citation, a structured policy
   summary, and an offline cached emergency card;
5. retry after a simulated timeout and verify idempotency;
6. delete the policy and verify no list, summary, vector, or source remains;
7. test another identity cannot read the first identity's document or summary;
8. capture logs/trace IDs without policy text, PII, or bearer tokens.

This is Tier 3 minimum (Tier 4 preferred) evidence for the launch gate.

## Work completed in this pass

- Restored `mobile/lib/main.dart` class structure so the app builds.
- Reworked `mobile/lib/services/notification_service.dart` for
  `flutter_local_notifications` 20: timezone-aware `zonedSchedule`, a 9:00 AM
  local reminder time, Android notification permission, and inexact alarms.
  Exact-alarm permissions were removed from the Android manifest.
- Restored the Q&A answer-card class structure and made answer feedback visible
  instead of persisting an unreachable value.
- Made QA-history tests initialize their Hive store, eliminating false-positive
  persistence errors.
- Replaced retired Azure-host assumptions in integration tests with explicit
  `COVERWISE_INTEGRATION_BASE_URL` opt-in execution.

## Addendum — ownership migration started (2026-07-12)

The canonical API now has a first anonymous-identity implementation:

- `POST /user/anonymous` issues a server-signed bearer credential; production
  requires `ANONYMOUS_AUTH_SIGNING_KEY`.
- the Flutter client stores that credential through platform secure storage and
  attaches it via the shared Dio client;
- upload, status, usage, document-query, and root-query paths derive owner
  scope from the verified bearer subject;
- background ingestion carries `owner_id` into RAG metadata;
- the duplicate public `/documents` demo route was removed.

Deletion now calls the canonical RAG deletion path with both `owner_id` and
`document_id`, invalidates query cache, deletes the extracted summary, then
removes the original document record. Summary reads and bulk-summary reads are
also owner-filtered.

Legacy synchronous ingestion, processing diagnostics, RAG stats, and debug
routes are now explicitly non-production only. Lead capture no longer accepts
a caller-supplied session identifier; it binds data to the verified bearer
owner.

Targeted two-identity code proof now verifies that one anonymous owner cannot
read another owner's document status and that root RAG retrieval overwrites a
malicious caller-supplied owner filter with the verified bearer subject. This
is Tier 2 evidence only; it must still be repeated against deployed durable
storage and Qdrant before launch.

This is Tier 2 code/test evidence, not launch clearance. Remaining required
closure: owner checks for summaries and every legacy route, vector/summary
deletion, removal or production gating of debug/synchronous endpoints, durable
metadata/object storage, and a two-identity live integration test.

## Three review passes

1. **Immediate correctness:** fixed the compiling mobile navigation and Q&A
   regressions; validation is clean.
2. **Architecture:** identified mismatched anonymous/public and Firebase-only
   routes, instance-local storage, stale deployment, and no complete deletion
   pipeline. The anonymous managed-identity + durable ownership model is the
   first coherent replacement.
3. **Launch supervision:** no customer data should enter production until the
   identity, storage, deployed-contract, and real-policy workflow gates above
   are evidenced.

## Addendum — route and consent-boundary closure (2026-07-12)

- OpenAPI now declares HTTP bearer security for the profile and policy-bearing
  route dependencies; targeted tests verify issue/verify, profile access,
  ownership isolation, owner-filter overwrite, and production diagnostic
  hiding (`9 passed`).
- The old web BFF upload, query, and sample-document routes are explicitly
  non-production. Production marketing now explains that policy documents are
  accepted only through the authenticated mobile flow, removing a second,
  unauthenticated ingestion/query pipeline.
- Mobile notification initialization has been removed from app startup. iOS
  permission is requested only from the explicit renewal-reminder action.

The iPhone 17 Pro simulator did rebuild/install with the new `CoverWise` app
identity. It continued displaying a previously queued notification permission
sheet after reinstall, while `simctl privacy reset notifications` returned
`Operation not permitted`. Source inspection and `flutter analyze` confirm the
startup path no longer invokes `NotificationService`; this is Tier 1 static
evidence, not a replacement for a clean-device Tier 4 consent check. Before
release, validate the first-launch sequence on a freshly reset simulator or
physical test device and capture the no-prompt screen before the reminder CTA.

## Addendum — durable document-storage foundation (2026-07-12)

`DOCUMENTS` has been replaced by the canonical document repository boundary:
SQLite is restart-safe for local development/tests, while production defaults
to Supabase Postgres and rejects SQLite. Original source bytes use a private
Supabase Storage bucket in production; local files remain development-only.
Upload compensates by deleting the source object when metadata creation fails;
deletion keeps metadata until derived vectors/summaries and the source object
have been removed.

The legacy `/policy` in-memory router is no longer mounted; `/documents` is the
single public policy-document ownership path. The Supabase schema at
[`infra/supabase/001_coverwise_schema.sql`](../../infra/supabase/001_coverwise_schema.sql)
defines the production tables, private bucket, owner-scoped vector RPC, and
environment contract. Production provisioning and live verification remain
open; this is Tier 2 code proof, not evidence that cloud resources are
provisioned.

## Addendum — anonymous-session continuity (2026-07-12)

Anonymous access tokens now carry a unique token ID and the API exposes an
owner-preserving `/user/refresh` endpoint. The mobile secure-storage client
refreshes within seven days of expiry through a standalone authenticated
request, preserving the same anonymous owner and therefore the same documents.
It retains the existing still-valid token when offline. This does not restore
documents after a device is lost or secure storage is cleared; that requires an
optional named-account/backup decision and must be described accurately in the
product privacy UX.

## Decision required

Provision the Supabase project/schema and Cloud Run service, then verify the
server-signed anonymous issuer and production retention/deletion behavior.
Firebase remains optional and is not part of the launch core; neither path can
use process-local storage in production.
