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

## Addendum — motto_v3 architecture review (2026-07-12)

**Pass 1 — immediate correctness.** The production-storage factory contract now
names Supabase credentials before optional SDK imports, so a missing deployment
secret produces a deterministic safe startup failure. Targeted repository,
object-store, auth, and ownership tests pass locally (Tier 2).

**Pass 2 — canonical architecture.** Cloud Run + Supabase Postgres, Storage,
and pgvector is the single launch path. The historical AWS/App Runner template
is retained only as an explicitly superseded reference. It cannot become a
parallel production source of truth without a recorded platform-decision
change.

**Pass 3 — supervision and failure recovery.** The serving process still
executes document work, but it now claims a durable 15-minute lease from the
repository. Startup recovers only `received` or expired-lease documents from
the canonical object store; concurrent instances cannot claim the same active
lease. The versioned Supabase migration records this state machine. This is
Tier 2 local evidence. Before launch, prove the same behavior in Cloud Run with
restart, duplicate, timeout, and partial-failure evidence; move to Cloud Run
Jobs/Tasks if measured document work exceeds the bounded request/lease model.

## Addendum — privacy-safe observability (2026-07-12)

Canonical upload, processing, and query logs now record bounded operational
metadata (document ID, owner prefix, size, mode, stage, and safe error type),
not raw filenames, questions, exception strings, or policy text. User-visible
processing/query failures use safe generic messages. A regression test injects
a provider exception containing a private policy question and proves that the
question is absent from both the response error and captured application logs.
This is Tier 2 code evidence; Cloud Run log-sink retention/access controls still
need configuration and inspection before launch.

## Addendum — idempotent source handling (2026-07-12)

Documents now carry an owner-scoped SHA-256 source hash, backed by a production
unique index. Before any object-store write or background work, an identical
owner upload resolves to its existing document and reports an idempotent replay.
This prevents duplicate source objects, duplicate vector chunks, repeated model
cost, and conflicting policy state from ordinary retry behavior. A focused
endpoint-level test verifies that two same-byte uploads leave exactly one owner
document. Tier 3 cloud proof remains required because the production unique
constraint and recovery path must be exercised after the Supabase migrations
are applied.

## Addendum — honest offline upload behavior (2026-07-12)

The Flutter client now saves a pending local copy only for genuine transport
unavailability (connection or receive timeout without an HTTP response). A
server rejection, validation error, authentication error, or 5xx failure is
shown as a secure-save failure instead of being mislabeled as offline success.
This protects users from believing a sensitive policy was safely queued when
the server did not accept it. Flutter analysis is clean and the full mobile
test suite passes (Tier 2); manual airplane-mode and server-500 UI proof remain
part of the release test matrix.

## Addendum — production browser and database privilege boundaries (2026-07-13)

Production CORS now requires an explicit `ALLOWED_ORIGINS` allowlist and rejects
both a missing value and `*`; it no longer falls back to the retired App Runner
host. The Supabase processing-claim RPC uses `SECURITY DEFINER` for an atomic
lease, so both schema migrations revoke execution from public/anonymous/authenticated
roles and grant it only to `service_role`. Focused configuration tests pass.
Provisioning must verify the applied grants and final custom-domain origins in
the real Supabase/Cloud Run projects before release.

## Addendum — executable production preflight (2026-07-13)

`tools/validate_production_config.py` now checks the canonical Cloud Run +
Supabase contract without printing secrets, and the same validator runs at API
lifespan startup. It requires the selected persistence/vector adapters, OpenAI
key, Supabase server credentials, strong anonymous signing key, final HTTPS
public origin/CORS allowlist, and non-debug production logging. The current
unprovisioned environment was deliberately verified to fail closed. This turns
deployment readiness into an executable gate; it does not provision cloud
resources or replace Tier 3 deployed-flow testing.

## Addendum — mobile release configuration and privacy truth (2026-07-13)

The stale App Runner URL is no longer embedded in the mobile binary. A release
build now requires HTTPS `API_BASE_URL`, `PRIVACY_POLICY_URL`,
`TERMS_OF_SERVICE_URL`, and a non-disposable `SUPPORT_EMAIL` through Dart
defines; a missing release contract stops startup instead of silently using a
retired endpoint. The in-app privacy surface now describes the selected private
Supabase Storage/Postgres/pgvector path and supported synced-policy deletion,
not AWS/Qdrant or a known deletion limitation. Flutter analysis and tests pass.
Actual hosted legal pages and the real Cloud Run URL still need operator/legal
approval before a store build can be produced.

## Addendum — truthful document workflow UI (2026-07-13)

The document screen now treats a local duplicate as the same saved policy,
matching server-side source-hash idempotency instead of offering an impossible
“keep both” path. Secure-save failures stay visible rather than being rendered
as upload success. A received/processing policy explicitly says it is being
read, defers summary retrieval, and disables Q&A until it is ready. Onboarding
also no longer claims that cloud-backed analysis works offline. Flutter analysis
and tests pass; visual Tier 4 verification still requires the deployed API.

## Addendum — bounded, processable document ingestion (2026-07-13)

The canonical `/documents/upload` API and retained non-production ingestion
surfaces now share one content-validation boundary. They accept only PDF, PNG,
JPG, TIFF, and WebP when the file signature and parser agree with the filename;
they reject disguised content before hashing, anti-abuse accounting, storage,
or OCR. The boundary caps source bytes at 50 MB, PDFs at 100 pages, and images
at 40 megapixels. It also corrects a `.tif` branch gap in extraction. `.doc`
and `.docx` are no longer advertised as supported: the prior binary fallback
was not a safe or truthful parsing contract.

Focused tests cover valid images, signature mismatch, unsupported Office files,
over-budget PDFs, encrypted-PDF handling, and API rejection before hashing.
They pass locally (Tier 2). Tier 3 deployment proof still needs a Cloud Run
request-size policy check and redacted tests for malformed/multi-page documents
against the actual reverse proxy and Supabase-backed workflow.

### Review passes — 2026-07-13

- **Pass 1 — immediate correctness:** the API validates source bytes before
  hashing, anti-abuse accounting, object storage, metadata creation, or model
  processing. The accepted file list now matches a real extractor path.
- **Pass 2 — architecture:** all active ingestion surfaces share
  `src/utils/upload_validation.py`; no parallel extension lists remain. The
  image check avoids mutating process-global Pillow configuration, which keeps
  concurrent requests isolated.
- **Pass 3 — supervision:** 40 focused backend tests and Python compilation
  pass; scoped `git diff --check` passes. This is Tier 2, not deployed proof.
  Password-protected PDFs are rejected for launch because request-scoped
  passwords cannot survive an instance restart without a reviewed credential
  design.

## Addendum — explicit policy-processing consent (2026-07-13)

Before an upload can reach hashing, storage, or processing, the API now
requires `processing_consent=true` and a versioned Privacy Policy identifier.
The Flutter upload dialog presents an explicit required checkbox and a link to
the configured hosted Privacy Policy; the release build rejects an unspecified
policy version. The consent receipt is retained with the document metadata.
Optional contact information is now device-only in the mobile upload flow and
is not silently sent with policy content. Targeted backend tests plus Flutter
analysis and all 16 mobile tests pass locally (Tier 2). The final hosted policy
text/version and legal approval still require operator ownership before release.

## Addendum — canonical Cloud Run deployment command (2026-07-13)

`tools/deploy_cloud_run.sh` is the sole launch deployment entry point. It builds
the repository Dockerfile with Cloud Run source deployment, uses a non-secret
runtime environment file, references OpenAI/Supabase/auth values from Secret
Manager, sets bounded memory/concurrency/instance limits, and allows public
invocation only because native mobile clients cannot use Cloud Run IAM; policy
routes still require the application bearer token. Historical Azure and AWS
scripts remain archival only. This is Tier 1
deployment automation evidence; it has not run because the production GCP and
Supabase credentials/domain are not available in this workspace.

## Addendum — mobile bearer credential storage (2026-07-13)

Anonymous API bearer tokens and expiry metadata now use platform secure storage
(Android Keystore/iOS Keychain) rather than the general Hive app-state store.
One-time migration preserves an existing anonymous owner identity and removes
the legacy Hive values; a local-data reset clears both locations. Flutter
analysis and all 16 mobile tests pass (Tier 2). Tier 4 device verification is
still required for secure-storage migration on supported Android and iOS
versions before store release.

## Addendum — document-response data minimization (2026-07-13)

Customer-facing document list/detail responses no longer include internal object
paths, owner IDs, source hashes, or metadata. Those values remain server-side
for ownership, idempotency, processing, and deletion only. Focused owner and
response-shape tests cover the boundary (Tier 2); deployed API contract checks
remain part of the Cloud Run acceptance run.

## Addendum — production startup integrity (2026-07-13)

Production startup now fails closed if anti-abuse, RAG, or document-processing
initialization fails. Development can still run reduced functionality for local
diagnosis, but a Cloud Run production revision cannot become ready and accept
policy uploads with a missing core processing path. Deployed startup/revision
failure evidence remains required (Tier 3).

## Addendum — no demo-policy release fallback (2026-07-13)

Demo policy injection and local demo Q&A remain available only for explicitly
enabled development demonstrations. A release build now rejects
`BOOTSTRAP_POLICY_DEMO=true`, and the release script pins it to false. This
prevents sample identities, fabricated answers, or demo sources from reaching
a customer build when a real backend is unavailable.

## Addendum — local runtime smoke evidence (2026-07-13)

The actual FastAPI process was started locally with the development runtime
contract. It bound after approximately 47 seconds of initialization; `/healthz`
and `/readyz` then returned 200 with RAG/document processing available. A
freshly issued anonymous bearer token accessed `/user/profile` and its own empty
`/documents` list; the unauthenticated document request returned 401. This is
Tier 4 local runtime evidence. It does not substitute for a Cloud Run cold-start
budget, production secret, Supabase, CORS, upload, deletion, and two-owner
acceptance run.

## Addendum — demo-upgrade data cleanup (2026-07-13)

Android runtime inspection found a retained bundled demo policy on an emulator
with prior app state. The local document store now removes only the known demo
record whenever demo mode is disabled, preventing a beta/demo upgrade from
presenting sample coverage as a customer's policy. The focused storage test
passes locally; a fresh release-APK install/upgrade check remains part of Tier 4
release validation.

## Addendum — reusable launch verifier exercised locally (2026-07-13)

`tools/verify_deployed_launch.py` was run against the actual local FastAPI
process. It passed liveness, readiness, unauthenticated document rejection,
two independently issued anonymous identities, both profiles, both owner-scoped
document lists, and distinct-owner verification. This is Tier 4 local runtime
evidence. The same command with the final HTTPS API URL and public origin is a
required Cloud Run acceptance artifact before release.

## Addendum — anti-abuse persistence blocker (2026-07-13)

The current anti-abuse implementation is not valid for the canonical Cloud Run
launch: it initializes a local SQLite database and uses optional Redis or
process-memory counters. Neither is durable or shared across Cloud Run
instances, and local smoke execution mutates the tracked legacy
`insurance_app.db` artifact. Do not enable customer uploads in production until
the rate-limit/usage ledger is moved to an atomic Supabase/Postgres contract (or
an explicitly selected managed rate-limit service), with proxy-safe client-IP
handling, multi-instance tests, retention policy, and operator visibility.

## Decision required

Provision the Supabase project/schema and Cloud Run service, then verify the
server-signed anonymous issuer and production retention/deletion behavior.
Firebase remains optional and is not part of the launch core; neither path can
use process-local storage in production.
