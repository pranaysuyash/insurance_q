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
mean unauthenticated data access. Use Firebase Anonymous Authentication (or a
single equivalent managed identity provider) on first launch, store the refresh
credential using platform secure storage, and attach the verified ID token to
every document, summary, query, and deletion request. Upgrade anonymous users
to a named account only when they choose to back up or share their policies.

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

## Decision required

Provision or identify the Firebase project/service-account and AWS storage +
database target to use for the canonical production ownership model. Once
available, the migration can proceed without changing the user-facing
no-login-first flow.
