# CoverWise Latest-Push Whole-System Audit

**Repository:** `pranaysuyash/insurance_q`  
**Branch:** `main`  
**Reviewed commit:** `3d55b8d0ee0d905ee06e76902e74875b7a06787e`  
**Previous commit:** `bed96ebe9096cfe6b0c321c43777f79e289ecbcf`  
**Review date:** 2026-07-31  
**Review posture:** read-only, long-term first principles, `motto_v4` aligned

---

## 1. Executive verdict

### Release decision: NO-GO

Do not promote this commit to a customer-facing production release yet.

The latest push is directionally useful. It adds typed outcomes, principal epochs, per-record parsing intent, awaited consent writes, modular navigation, bounded document downloads, and stronger defensive comments. The backend already contains several genuinely strong foundations: a durable outbox, database leases, dead-letter handling, owner-scoped document hashing, upload rollback, non-root containers, RLS, and visible answer-verification states.

The release failure is not a lack of effort or architecture. It is a lack of **cross-layer contract closure**.

Mobile, backend, Supabase, worker, UI, and deployment frequently implement individually reasonable assumptions that disagree with one another. The clearest example is claims sync: the mobile POST body sends an `id`, while the backend request model forbids that field. The new code can pass its local tests and still fail on the first real request.

### Architecture foundation

**Foundation quality:** 6/10  
**Release readiness:** 4/10  
**Security/privacy readiness:** 3/10  
**Evidence quality:** 3/10

These are reviewer judgments, not measured benchmark scores.

### Immediate P0 blockers

1. Claims sync contract is broken and can delete or duplicate data.
2. Policy source files are stored unencrypted on the device.
3. Guest, anonymous, and registered principals are not deterministically modeled.
4. Consent is not reconciled from server authority or enforced at the backend operation boundary.
5. Public account-deletion requests are process-local while the API claims durability and email verification.
6. The What-If calculator fabricates premium estimates outside the signed product boundary.
7. CI signs one artifact while the deployment script can deploy a different local source tree.
8. Q&A “fully backed” semantics overstate what the verifier actually proves.
9. Onboarding can complete after local consent persistence fails.
10. Analytics is not fenced against revocation, principal transitions, or concurrent flushes.

---

## 2. Scope and evidence limits

### Reviewed

- Latest commit and its changed files
- Product doctrine and current-state architecture
- Flutter composition, navigation, onboarding, settings, upload, Q&A, claims, local persistence, consent, analytics, and identity
- FastAPI claims, document, consent, user, capabilities, auth, RAG, and worker paths
- Supabase claims migration and owner boundaries
- Durable job outbox and dispatcher
- Android manifest, attribution receiver, iOS plist
- GitHub Actions, Dockerfile, and Cloud Run deployment script
- Tests added by the latest push and representative existing tests

### Not independently executed

- Flutter tests, Python tests, APK build, iOS build, or GitHub Actions
- Android/iOS runtime interaction
- Dark mode, 200% text scale, screen-reader, keyboard, narrow-device, offline, and process-death testing
- Production Supabase, object storage, OpenAI, RevenueCat, or Cloud Run behavior
- Dependency-vulnerability freshness against current external databases

The GitHub connector did not surface commit status checks or pull-request-triggered workflow evidence for the reviewed commit. The repository does contain a substantial CI workflow, but the commit-message claims were not independently reproduced in this review. A local clone could not be established in this runtime, so UI findings are static code and design findings, not screenshot-based device QA.

---

## 3. What the latest push did well

### 3.1 Typed outcomes replace some ambiguous booleans

The new claims sync, capability parsing, consent parsing, and reconciliation code moves toward explicit results instead of relying only on exceptions and `true`/`false`. That is the correct direction because callers need to distinguish retryable failure, permanent rejection, stale work, malformed authority, and successful convergence.

### 3.2 Principal epochs are the right primitive

`mobile/lib/sync/reconciliation_coordinator.dart` introduces an epoch check before and after asynchronous work. This is the correct concurrency primitive for preventing stale principal transitions from committing after a newer transition.

The implementation is incomplete because not every async subsystem is bound to the same epoch, but the model is sound.

### 3.3 The backend document ingestion path is materially stronger

`src/api/document.py` has several production-grade behaviors:

- owner-scoped content-hash deduplication
- validation before expensive processing
- source persistence before metadata publication
- rollback when durable work cannot be enqueued
- encrypted transient processing inputs
- policy-slot reservation
- production refusal to pretend in-process work is durable

This is one of the strongest areas of the repository.

### 3.4 Durable queue foundations are good

`src/services/job_outbox_service.py`, `src/services/job_dispatcher.py`, and `src/workers/outbox_worker.py` implement:

- atomic database claims
- lease tokens
- lease extension
- retries and dead-letter states
- explicit handler registration
- operator-facing health reads
- startup failure when the outbox is unavailable in production

This is good long-term architecture. The remaining work is operational truth and handler-level fencing.

### 3.5 Security defaults are improving

Positive examples include:

- non-root container execution
- hashed Python lock installation
- owner-scoped RLS
- restricted production CORS and trusted hosts
- Android backup disabled
- contextual retrieval disabled by default
- private Q&A cache scoping
- explicit answer verification badges
- consent default-deny behavior

### 3.6 UI architecture is beginning to separate

Extracting `app_router.dart` and `main_navigation.dart` from `app.dart` is a real improvement. The app shell is easier to reason about, and the missing-arguments route is better than uncontrolled casts.

---

## 4. Area-wise audit

# A. Doctrine, governance, and product boundary

### Status: P0 governance ambiguity

### Files

- `motto_v4.md`
- `.agent/AGENT_KICKOFF_PROMPT.txt`
- `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`
- `docs/planning/discovery/2026-07-30-project-wide-recon/MANIFEST.md`
- `docs/planning/discovery/2026-07-30-project-wide-recon/04-current-state-architecture.md`
- `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md`
- `mobile/lib/screens/what_if_calculator_screen.dart`
- `mobile/lib/utils/what_if_calculator.dart`
- `mobile/lib/navigation/app_router.dart`

### Good

The proposed product constitution is unusually clear:

- explain the user’s own policy
- expose evidence and uncertainty
- abstain when evidence is insufficient
- do not sell, quote, advise, transact, or make insurer decisions
- maintain one principal graph
- make server consent authoritative
- avoid parallel execution paths

### Poor

`PRODUCT_FIRST_PRINCIPLES.md` is still marked **proposed, awaiting operator sign-off**, while implementation and reviews treat it as canonical. This creates an unresolvable hierarchy problem for agents.

The What-If calculator violates the proposed product boundary. It estimates premiums using arbitrary multipliers:

- deductible above base: `0.85`
- deductible below base: `1.15`
- maternity: `1.08`
- daycare: `1.03`
- pre/post hospitalization: `1.05`

These are not evidence-backed policy facts. They are fabricated financial estimates. A disclaimer does not turn an arbitrary formula into a trustworthy product capability.

### Required improvement

1. Formally sign or reject the current product constitution.
2. Remove the What-If route and implementation from the launch surface.
3. Create an explicit exception process for future product-boundary changes.
4. Make CI fail when prohibited launch routes are reintroduced.

### Acceptance evidence

- Signed doctrine ADR with operator decision and date
- No `/what-if` route in release build
- No arbitrary premium-estimation formula in shipped code
- Product-boundary test enumerating allowed route capabilities
- Updated architecture and decision logs

---

# B. Claims data model and synchronization

### Status: P0 broken contract and data-loss risk

### Files

- `mobile/lib/services/claims_sync_service.dart`
- `mobile/lib/models/claim_record.dart`
- `mobile/lib/services/app_state_repository.dart`
- `src/models/claim.py`
- `src/api/claims.py`
- `supabase/migrations/20260724000000_claims_table.sql`
- new claims-sync tests

### Good

- Owner is derived from the authenticated backend principal.
- Backend reads and writes are owner-scoped.
- RLS exists.
- Sync results expose counts and failures instead of only returning `void`.
- Status values are constrained server-side.

### Critical defects

#### B1. Mobile POST cannot satisfy backend schema

Mobile sends `id`. `CreateClaimRequest` forbids extra fields and does not accept `id`. The request will return HTTP 422.

#### B2. Local and remote identity are not coherently modeled

The backend generates a new UUID. The mobile later compares server IDs to local IDs instead of using a stable `remoteId` relation. This can repeatedly recreate claims or fail to reconcile them.

#### B3. Modified claims are never pushed

The sync algorithm only creates records missing on the server. A local claim with an existing remote ID and `ClaimSyncState.modified` is not PATCHed.

#### B4. Malformed success responses are reported as success

A 200/201 response with an invalid body can still become a successful `ClaimSyncAction`. The local record remains unresolved, while the caller is told it succeeded.

#### B5. Pull treats one page as the full server authority

The backend defaults to 50 records. The mobile pull can treat absence from that page as deletion. A user with more than 50 claims risks losing local records during reconciliation.

#### B6. User-entered filed date is lost

The backend always sets `filed_date` to server `now()`. The mobile model allows a filed date, but the API contract discards it.

#### B7. No honest delete or tombstone model

A local deletion cannot be distinguished from absence, remote deletion, pagination, or a filtered view.

#### B8. Speculative schema is leaking into launch code

The schema includes `initiated_by='agent'` and `agent_id`, although the signed product direction excludes agent/adviser operation.

#### B9. Referential boundaries are weak

`document_id` and `photo_paths` are accepted without proving they belong to the same principal.

### Required improvement

Build one versioned claims wire contract with:

- `local_id`
- optional `remote_id`
- server `version` or `updated_at`
- explicit create/update/delete operations
- cursor pagination
- tombstones
- conflict policy
- owner-validated document and artifact references
- idempotency key
- strict response unions

Prefer generated Dart and Pydantic types from a single schema rather than manually mirrored classes.

### Acceptance evidence

- Mobile-to-FastAPI integration test proving POST, PATCH, GET pagination, and DELETE
- More-than-200-claims reconciliation test
- Offline create, edit, delete, process death, reconnect test
- Conflict tests for simultaneous device and server updates
- Contract test that rejects undocumented fields
- No local deletion based on a partial page
- No duplicated claim after retry or timeout
- Server response is the source of remote identity and version

---

# C. Local-state strictness, quarantine, and concurrency

### Status: P0/P1 silent fabrication and lost-update risk

### Files

- `mobile/lib/services/app_state_repository.dart`
- `mobile/lib/models/claim_record.dart`
- `mobile/test/app_state_repository_quarantine_test.dart`
- `mobile/lib/services/app_state_store.dart`

### Good

The latest push recognizes that one malformed record should not destroy an entire collection. Per-record parsing is the correct direction.

### Problems

#### C1. Quarantine is not actually strict

`ClaimRecord.fromJson` converts absent or invalid values into:

- empty IDs
- `Unknown`
- current date/time
- `filed`
- default sync state

Malformed records are therefore silently transformed into invented data instead of being quarantined.

The new tests explicitly preserve this lenient behavior.

#### C2. Corrupt collection and legitimate empty collection are indistinguishable

Top-level decode failure returns an empty list. Reconciliation can interpret corruption as “the user has no claims.”

#### C3. Dropped records are not recoverable

There is no durable quarantine box, reason code, source key, original payload, repair action, or operator metric.

#### C4. Locking does not protect a full mutation transaction

Several sync flows read outside the lock and replace under the lock. A user write between read and replace can still be lost.

#### C5. One global lock is too broad

File deletion or slow work inside the lock blocks unrelated state. A global non-reentrant `Completer` lock can also deadlock if a locked operation calls another locked operation.

### Required improvement

Introduce:

- strict wire DTO parsers
- durable quarantine records
- typed read results: `valid`, `partial`, `corrupt`
- repository-level atomic mutation APIs
- record/version compare-and-swap
- separate lock domains or a serialized repository actor
- corruption telemetry without PII

### Acceptance evidence

- Every required field malformed independently
- Mixed valid and invalid records
- Durable original payload retained in quarantine
- User-visible recovery/reset flow
- Concurrent sync plus user edit tests
- Process-death tests during write
- No invented IDs, dates, statuses, or insurers

---

# D. Identity, principal isolation, and workspace transition

### Status: P0 nondeterministic ownership

### Files

- `mobile/lib/bootstrap/app_bootstrap.dart`
- `mobile/lib/services/auth_service.dart`
- `mobile/lib/sync/reconciliation_coordinator.dart`
- `mobile/lib/services/hive_workspace_service.dart`
- `mobile/lib/services/principal_key_service.dart`
- `src/api/user.py`
- auth and reconciliation tests

### Good

- Epoch checks are the correct stale-work primitive.
- Backend anonymous-to-account transfer has a durable identity-link record and idempotent completed state.
- Principal-scoped Hive boxes and DEKs are directionally correct.
- Backend owner identity is taken from verified tokens.

### Critical defects

#### D1. Guest identity is nondeterministic

Startup opens an install-scoped workspace. A deferred Supabase anonymous sign-in later arrives as a generic signed-in event, and the coordinator can treat that anonymous user as an account principal. Timing determines which workspace becomes active.

#### D2. Registered status is inferred from email/phone

The client should use an authoritative identity type, not “has email or phone.”

#### D3. Anonymous claim intent is consumed too early

The local claim flag can be cleared before server transfer completes. A transient network failure can permanently strand ownership transfer.

#### D4. Local and server ownership can split

Local workspace copying can complete before server document transfer, leaving two sources of truth on failure.

#### D5. Sign-out does not perform verified local isolation

Clearing an in-memory DEK while encrypted boxes remain open does not make already-open data unreadable. Old principal DEKs and files can persist indefinitely.

#### D6. Provider identity can bleed

RevenueCat logout is best-effort. A failed logout during principal change can expose entitlement state from the previous user.

#### D7. Request retry can replay non-replayable bodies

The generic auth retry path needs to prove that multipart and streaming request bodies are replayable.

### Required improvement

Define one explicit identity state machine:

- `install_guest`
- `backend_anonymous`
- `registered_account`

All long-lived operations must carry:

- principal ID
- identity type
- principal epoch
- cancellation/fencing token

Anonymous claim must be a durable client outbox operation that remains pending until the server identity-link record is completed.

### Acceptance evidence

- Cold start under every auth timing order
- Anonymous token refresh without workspace switch
- Guest to registered account with network loss at each stage
- Account A to account B with in-flight upload, analytics, consent, and Q&A
- Process death during identity link
- RevenueCat identity failure blocks entitlement publication
- Old principal files and boxes unavailable after transition
- Server and local ownership converge after retry

---

# E. Consent and legal authorization

### Status: P0 server-authority gap

### Files

- `mobile/lib/services/consent_ledger.dart`
- `mobile/lib/services/server_consent_service.dart`
- `mobile/lib/services/consent_sync_service.dart`
- `mobile/lib/screens/onboarding_screen.dart`
- `mobile/lib/screens/documents_screen.dart`
- `mobile/lib/widgets/lead_capture_dialog.dart`
- `src/api/consent.py`
- `src/api/document.py`

### Good

- Consent defaults to denied.
- Purpose-specific records exist.
- Local writes are awaited before the upload dialog returns success.
- Server ledger is append-only.
- The API extracts principal identity rather than accepting a body user ID.
- The UI exposes current consent states.

### Critical defects

#### E1. “Sync” only pushes

The client never pulls current server consent despite server authority being the stated architecture.

#### E2. Consent work is not principal-epoch scoped

A singleton in-flight sync can complete after the principal changes.

#### E3. No idempotency at the append-only boundary

A crash after server append but before local signature caching can create duplicate events on retry.

#### E4. Client wall clock determines current local state

An older event with a future clock can outrank a later revocation.

#### E5. Backend operation trusts client assertion

`POST /documents/upload` accepts client `processing_consent=true` plus a version string. It does not query the server consent ledger before storing and processing the source.

#### E6. Audit provenance can be forged

The public consent request model can override IP address and user agent. Test injection belongs in a service seam, not the HTTP body.

#### E7. Onboarding can complete without durable local consent

Local consent errors are caught, then `onboarding_complete=true` is stored.

#### E8. Terms and Privacy are conflated

One checkbox says the user agrees to both, but the persisted purpose does not model them as separate legal artifacts.

#### E9. Contact capture and processing consent share one dialog

“Skip” skips contact capture but grants processing. The semantics are not obvious.

#### E10. Anonymous consent can be copied into an account workspace

Preserving the old Hive workspace during account linking copies consent state without an explicit server-authoritative reassociation.

### Required improvement

Build a principal-scoped reconciliation state machine:

1. Pull server current state.
2. Compare local pending events.
3. Append idempotently.
4. Pull again.
5. Publish a typed convergence result.
6. Enforce current consent server-side at each protected operation.

Use server sequence/order, not device time, for authority.

Separate:

- Terms acceptance
- Privacy Policy acknowledgement
- Document-processing authorization
- Analytics
- Contact storage
- Marketing
- Evaluation/model improvement

### Acceptance evidence

- Server revocation on another device blocks next upload
- Revocation during upload prevents processing from starting
- Crash after append does not duplicate an event
- Principal switch during sync cannot write into the new principal
- Terms and Privacy versions are separately auditable
- HTTP clients cannot supply audit IP/user-agent
- Onboarding cannot finish if mandatory legal persistence fails
- Malformed partial server consent produces an explicit error state

---

# F. Analytics and privacy telemetry

### Status: P0/P1 revocation and duplication risk

### Files

- `mobile/lib/services/analytics_service.dart`
- analytics provider/notifier files
- event registry documentation
- onboarding copy

### Good

- Opt-in defaults to false.
- Revocation clears queued and persisted events.
- Consent is rechecked near upload.
- Policy content is intended to stay outside event properties.

### Problems

#### F1. In-flight uploads are not fenced

Revocation or principal change does not cancel or invalidate an already-running request.

#### F2. Concurrent flushes can duplicate data

Timer and threshold flushes can transmit the same buffer and then remove the wrong range.

#### F3. No event-level idempotency

The backend cannot safely deduplicate retries.

#### F4. Release schema enforcement is weak

Unknown events and properties can still escape in release builds if checks are only debug-oriented.

#### F5. Pseudonymous is described as anonymous

Install IDs, session IDs, and principal-derived values are identifiers. The UI copy should say pseudonymous usage telemetry, not anonymous analytics.

#### F6. Persistence and flush can race

Async buffer persistence can overwrite a newer buffer state.

### Required improvement

Use one serialized analytics actor with:

- principal and consent generation
- event UUID
- immutable event envelope
- one in-flight batch
- cancellation/fencing
- backend idempotency
- release-enforced schema and property allowlist
- PII redaction before logging/Sentry

### Acceptance evidence

- Revoke during upload
- Account switch during upload
- Timer and threshold fire simultaneously
- HTTP success followed by app crash
- Backend timeout after ingest
- Unknown event/property rejected in release
- No event from principal A sent under principal B
- Correct pseudonymous user-facing copy

---

# G. Local document security and lifecycle

### Status: P0 sensitive plaintext

### Files

- `mobile/lib/services/local_storage_service.dart`
- `mobile/lib/models/document_model.dart`
- `mobile/lib/services/document_service.dart`
- `mobile/lib/screens/settings_screen.dart`
- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/ios/Runner/Info.plist`

### Good

- Android backup is disabled.
- Hive metadata has a principal-scoped encryption direction.
- Server download sizes are bounded.
- Temporary CoverWise cache deletion is scoped in one service.

### Critical defects

#### G1. Policy files are plaintext

Original PDFs/images are copied into the general application documents directory. Original filenames are embedded in local file paths. Encrypting Hive metadata does not encrypt the source policy.

#### G2. Files are not principal-scoped

The file path structure does not provide a dedicated encrypted content root per principal.

#### G3. iOS file-protection posture is not explicit

The reviewed plist does not establish a release-grade policy-file protection contract. Custom URL scheme and development local-network/Bonjour declarations also remain in the release plist.

#### G4. Clear Data deletes the entire app documents directory

`settings_screen.dart` recursively deletes and recreates the whole application documents directory, not a CoverWise-owned subtree. This can destroy files owned by other plugins or future features.

#### G5. Clear Data does not prove secure-key erasure

The flow clears Hive, preferences, files, notifications, ledger, and token, but does not visibly delete every principal DEK from secure storage or verify that no protected files remain.

#### G6. Document state can be fabricated

Pending documents can receive `processingCompletedAt=DateTime.now()`.

#### G7. Duplicate detection is filename-based

Filename/base-filename heuristics can reject legitimate policy revisions while calling them identical.

### Required improvement

Build a dedicated principal content store:

- opaque content ID filenames
- per-principal encryption key
- authenticated encryption
- content digest
- atomic metadata/file journal
- platform file-protection and backup exclusion
- migration from existing plaintext paths
- verified erasure
- narrow owned directories

### Acceptance evidence

- Extracted sandbox contains no readable policy source or sensitive filename
- Migration survives process death
- Principal A cannot open principal B files
- Key deletion makes residual ciphertext unrecoverable
- Clear Data deletes only owned paths
- Device backup/restore behavior documented and tested
- File and metadata deletion are atomic or recoverable
- Duplicate identity uses content hash, not filename

---

# H. Document upload and reconciliation

### Status: P0/P1 client orchestration and contract debt

### Files

- `mobile/lib/services/document_service.dart`
- `mobile/lib/screens/documents_screen.dart`
- `mobile/lib/models/document_model.dart`
- `src/api/document.py`
- policy-slot and outbox services

### Good

- Backend content-hash dedupe is owner-scoped.
- Backend rollback is strong.
- Durable queueing is mandatory in production.
- Transient processing secrets are encrypted.
- Client checks file type, size, consent, entitlement, and connectivity.
- UI surfaces per-file batch state.

### Problems

#### H1. Client idempotency is a parallel fiction

The client key is filename plus size. The backend uses content hash. The client header is not the canonical deduplication identity and creates false confidence.

#### H2. Offline-first is contradicted by the UI

The screen rejects offline uploads before the service’s pending-upload path can operate.

#### H3. Server receipt is not durably committed locally first

If the server accepts a file and local persistence fails, the user has a server document without a reliable local receipt.

#### H4. Consent-blocked retry is mislabeled as permanent failure

A re-grant should unblock a pending upload.

#### H5. Batch web uploads can exhaust memory

Every file is held as bytes with no aggregate batch cap.

#### H6. Password retry recursively calls upload without awaiting it

This complicates state and cancellation.

#### H7. Multi-file backend responses are ambiguous on partial failure

Earlier files can be durable before a later file raises an HTTP error. The client may not receive complete per-file outcomes.

#### H8. Download integrity is incomplete

Length is checked, but the source host and content digest are not validated against an authoritative receipt.

#### H9. `DocumentsScreen` is a god-screen

It owns picker, validation, duplicate handling, consent, contact capture, OCR, entitlement, networking, batch state, navigation, and analytics.

### Required improvement

Create an `UploadCoordinator` and typed state machine:

- selected
- validating
- consent_blocked
- queued_offline
- uploading
- accepted
- processing
- completed
- retryable_failure
- permanent_rejection

Persist an upload intent and content digest before network transmission. Return per-file typed outcomes from the server.

### Acceptance evidence

- Offline select, queue, restart, reconnect
- Server accepted then local commit fails
- App killed during upload
- Partial multi-file failure
- Regrant consent resumes blocked item
- Aggregate memory limit
- Content digest and host verified
- One canonical dedupe identity
- UI contains no business/network orchestration logic

---

# I. Capabilities and configuration contract

### Status: P1 versioning and initialization race

### Files

- `mobile/lib/models/capabilities_response.dart`
- `mobile/lib/services/capabilities_service.dart`
- `mobile/lib/providers/capabilities_provider.dart`
- `src/api/capabilities.py`
- `mobile/lib/bootstrap/app_bootstrap.dart`
- `mobile/lib/services/document_service.dart`

### Good

- Client defaults are conservative.
- Trust gates fail closed.
- The server exposes operational limits centrally.

### Problems

1. Backend does not supply all trust gates the mobile expects.
2. There is no schema version or generated shared type.
3. Server environment integers can fail at import time without bounded validation.
4. Client field fallback can mix old and new schema values.
5. Client raises a server max-upload limit to at least 1 MiB, potentially exceeding a deliberately lower server limit.
6. Bootstrap fetches capabilities without awaiting it.
7. A singleton Dio client can capture defaults before capabilities arrive and never update.
8. “Server-enforced timeout” is inaccurate naming for a client hint.

### Required improvement

- Versioned response model
- One schema source
- Bounded server config parsing
- Awaited composition or reactive immutable config
- Explicit stale-cache state
- No mixed-version fallback

### Acceptance evidence

- Old/new schema compatibility matrix
- Invalid server environment values fail startup with a clear error
- First network client always receives resolved capabilities
- Lower server limit remains lower
- Trust gates have a tested enable path

---

# J. Q&A, evidence, and truth surface

### Status: P0/P1 semantic overclaim

### Files

- `mobile/lib/screens/qa_screen.dart`
- `mobile/lib/models/qa_models.dart`
- `mobile/lib/widgets/answer_verification_badge.dart`
- `src/services/answer_verifier.py`
- `src/rag/pipeline.py`
- Q&A localization files

### Good

- Verification state is visible.
- Sources, citations, missing information, and follow-up questions are modeled.
- Contextual retrieval is disabled by default.
- Private query caching is scoped.
- Prompt-injection controls exist.
- Confidence can remain hidden until calibrated.

### Critical defects

#### J1. Two request implementations

Streaming and non-streaming paths duplicate entitlement, connectivity, retry, loading, and answer state. They will drift.

#### J2. Transport failure becomes an answer object

A network fallback is constructed as `QaAnswer`, conflating request failure with a policy answer.

#### J3. Client filters evidence by names and substrings

Sources containing names such as “John Smith” or sample-like filenames are removed in the UI. A real customer source can disappear while the answer remains.

#### J4. Relevance is fabricated

String sources receive score `1.0`.

#### J5. Verifier does not prove entailment

The answer verifier checks that a material sentence contains a citation marker pointing at a citation labelled verified. It does not prove the cited text supports the factual claim.

#### J6. Short answers can be “fully backed” trivially

When the heuristic finds zero material sentences, the result is fully backed.

#### J7. UI copy overstates proof

“Every claim in this answer is verified” is stronger than the implementation.

#### J8. Unsupported claims may remain visible

A partially backed classification is not the same as removing or clearly isolating unsupported claims.

### Required improvement

- One Q&A request controller
- Disjoint UI states: idle/loading/answer/abstention/transport_error/quota_error
- Strict response schema
- Server-owned evidence sanitation
- Claim-level decomposition
- Claim-to-evidence entailment or calibrated conservative wording
- Source provenance IDs and source hashes
- No invented relevance values
- Server-authoritative quota consumption and returned balance

### Acceptance evidence

- Every rendered factual claim mapped to an evidence span
- Contradictory citation cannot produce fully backed
- Citation-present but non-entailing evidence cannot produce fully backed
- Short unsupported answer cannot become fully backed
- Transport failure never enters answer history
- Streaming/non-streaming share one state machine
- Real customer names are never filtered by substring
- Wording matches measured verifier semantics

---

# K. UI, navigation, accessibility, and localization

### Status: P1 static structure improving, runtime proof absent

### Files

- `DESIGN.md`
- `mobile/lib/app.dart`
- `mobile/lib/navigation/app_router.dart`
- `mobile/lib/navigation/main_navigation.dart`
- `mobile/lib/screens/onboarding_screen.dart`
- `mobile/lib/screens/documents_screen.dart`
- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/screens/qa_screen.dart`
- localization files
- Android and iOS deep-link declarations

### Good

- Router and navigation are separated.
- Reduced-motion support exists in onboarding.
- Some progress states use live-region semantics.
- Empty states and action rows are generally explicit.
- Lazy tab construction reduces unnecessary work.

### Problems

1. Route names and arguments remain stringly typed.
2. Deep links can reach routes before onboarding, workspace, and auth readiness are proven.
3. Custom URL schemes are hijackable; verified app/universal links are not established.
4. The Android install-referrer receiver is exported and accepts spoofable external broadcasts.
5. Onboarding footer density risks failure at 200% text scale.
6. Many strings remain hardcoded English despite five locale files.
7. Purple accents and speculative “smart suggestions” conflict with the canonical design/product direction.
8. Direct `MaterialPageRoute` calls bypass central navigation policy.
9. Renewal scheduling is not clearly reactive to policy changes.
10. Runtime accessibility evidence is absent.
11. Large screens own too many business concerns.

### Required improvement

- Typed route API and route guards
- Verified HTTPS app links/universal links
- Restrict or replace exported attribution receiver
- Release l10n enforcement
- Accessibility and visual-regression matrix
- Screen decomposition into state/view layers
- Remove prohibited or speculative navigation entries

### Acceptance evidence

- Android and iOS deep-link security tests
- Cold deep link before bootstrap cannot bypass gates
- 200% text, dark mode, screen reader, keyboard, narrow phones
- All launch strings localized or explicitly excepted
- No overflow/golden regressions
- No business logic inside visual components
- No What-If or unapproved smart-guidance route

---

# L. Onboarding and first-value flow

### Status: P0 legal transaction problem

### Files

- `mobile/lib/screens/onboarding_screen.dart`
- `mobile/lib/widgets/lead_capture_dialog.dart`
- `mobile/lib/services/consent_ledger.dart`
- `mobile/lib/services/analytics_service.dart`

### Good

- Analytics is an unticked optional control.
- Mandatory legal acceptance is visually separate.
- First policy upload is the intended value transition.
- Reduced-motion behavior is considered.

### Problems

1. Onboarding completion is stored even if mandatory local consent write failed.
2. Privacy Policy and Terms are represented by one checkbox but not separate persisted artifacts.
3. “Anonymous usage stats” overstates telemetry privacy.
4. “Surface the cover, exclusions and benefits that matter” can imply advisory ranking.
5. The last page is dense and not fully scroll-bound with the page content.
6. Server consent sync is best-effort, but no explicit pending legal-sync state is surfaced.

### Required improvement

Treat onboarding completion as a transaction:

- required legal records persist successfully
- local state commits
- server sync state is explicit
- only then mark onboarding complete

Offline onboarding can remain possible, but it needs a durable pending-sync record and operation-level server enforcement.

### Acceptance evidence

- Disk-full/local write failure blocks completion
- Process death between consent and completion resumes safely
- Offline completion records durable pending sync
- Upload blocked until server authority is current where required
- Terms and Privacy versions separately visible
- 200% text and small-screen test

---

# M. Account deletion, export, and data lifecycle

### Status: P0 false durability claim

### Files

- `src/api/user.py`
- `src/services/account_lifecycle_service.py`
- job-outbox account-deletion handler
- mobile profile/settings/auth/local-storage services

### Good

The authenticated production deletion path uses:

- durable deletion request
- outbox enqueue
- idempotent active-job lookup
- per-stage status
- no immediate false “permanently deleted” response

This is strong progress.

### Critical defect

The public `/user/delete-account-request` path:

- stores requests in a process-local list
- loses them on restart
- sends no verification email
- still says the request was registered and a verification email will be sent

This is a direct truth and compliance failure.

The mobile local-delete path also does not prove secure-store key erasure, and account deletion does not automatically perform verified local erasure.

### Required improvement

Route public deletion into the same durable lifecycle system:

- durable request row
- verified email challenge
- abuse protection
- status endpoint
- outbox job
- retry
- audit trail
- truthful response copy

Create a separate verified local erasure flow.

### Acceptance evidence

- Restart after request does not lose it
- Duplicate requests converge
- Verification email is actually sent or copy does not claim it
- Unverified requester cannot erase an account
- Status survives deployment
- All server stages verified
- All local keys/files verified deleted
- Export/download access expires and is audited

---

# N. Backend API and security boundary

### Status: P1 strong baseline with operational leaks

### Files

- `src/app/main.py`
- `src/api/user.py`
- `src/api/document.py`
- `src/api/claims.py`
- `src/api/consent.py`
- runtime-config and auth utilities

### Good

- Trusted hosts
- restricted production CORS
- bearer authentication
- owner-scoped access
- fail-loud production composition
- liveness and readiness separation
- structured logging initialization
- Sentry initialization before service startup

### Problems

1. `/metrics` is exposed by a publicly invokable Cloud Run service.
2. CORS allows all methods and headers.
3. Readiness mostly proves object initialization, not dependency viability.
4. Health can depend on an external paid embedding call.
5. Analytics cleanup runs as an in-process loop on every API instance.
6. Global module-level service variables weaken composition and parallel tests.
7. Static API version and old product naming can drift.
8. Security headers were not established in the reviewed app composition.
9. Audit/request error strings require systematic PII redaction.
10. Client-provided consent audit metadata is accepted.

### Required improvement

- Protect metrics through internal ingress or authenticated observability
- Dependency-aware but bounded readiness
- Scheduler-owned maintenance
- Application-scoped dependency injection
- security headers
- structured typed errors
- request correlation IDs
- PII-safe logging policy

### Acceptance evidence

- Public unauthenticated metrics request denied
- Readiness fails when canonical DB/outbox unavailable
- Liveness remains cheap
- One cleanup job regardless of API replicas
- No PII in logs/Sentry fixtures
- Security-header tests

---

# O. Durable pipeline and worker

### Status: P1 good architecture, incomplete operational truth

### Files

- `src/services/job_outbox_service.py`
- `src/services/job_dispatcher.py`
- `src/workers/outbox_worker.py`
- document/substrate/account-deletion handlers
- outbox migrations

### Good

- Durable at-least-once queue
- lease fencing at database updates
- retry and dead-letter
- handler registry
- lease heartbeat
- stuck-lease recovery
- operator health views

### Problems

1. Worker `/readyz` always returns ready without checking the queue or dependencies.
2. Cancelling an async task after lease loss does not guarantee a blocking OCR/native/provider operation stops mutating downstream state.
3. Invalid claimed rows are effectively abandoned until lease reclaim.
4. `str(error)` can leak sensitive values into queue history and logs.
5. Fail is a select then update sequence rather than one atomic database operation.
6. Retry backoff has no jitter.
7. Worker throughput is single-job sequential.
8. Old comments describe outdated migration state and motto versions.

### Required improvement

- Real worker readiness
- handler mutation fencing and idempotency ledger
- atomic fail/dead-letter RPC
- typed sanitized failure codes
- jitter
- malformed-job quarantine
- measured concurrency model
- production soak and fault injection

### Acceptance evidence

- Lease loss during OCR/storage/vector write
- Worker killed at every handler stage
- Duplicate delivery produces one logical result
- Dependency outage changes readiness
- Invalid job becomes operator-visible quarantine/dead letter
- No PII in failure records
- Throughput and latency SLO measured

---

# P. Infrastructure, CI, deployment, and supply chain

### Status: P0 provenance split

### Files

- `.github/workflows/ci.yml`
- `Dockerfile`
- `tools/deploy_cloud_run.sh`
- dependency lock files
- repository deployment documentation

### Good

CI includes:

- backend tests
- Python compile and critical Ruff checks
- dependency audit
- OCR lock verification
- Flutter analyze and tests
- release APK build and size check
- non-root image
- Cosign signing

### Critical defects

#### P1. The verified artifact is not the deployed artifact

CI builds and signs a DockerHub image. The canonical Cloud Run script deploys from a local source directory using `gcloud run deploy --source`.

The signed digest and the serving revision can therefore be different code.

#### P2. No committed `.gcloudignore` was found

A source deployment can include unintended local files or depend on generated ignore behavior.

#### P3. Secrets use mutable `latest`

Deployments are not bound to immutable secret versions.

#### P4. Service identity is not explicit

The deployment script does not set a dedicated least-privilege service account.

#### P5. Public ingress exposes internal surfaces

The service is `--ingress=all --allow-unauthenticated`; application auth is required for business routes, but metrics and operational endpoints need separate protection.

#### P6. Supply-chain verification is too broad

Cosign verification accepts a broad GitHub identity regex rather than exact repository, workflow, and ref identity.

#### P7. Security and contract coverage is incomplete

Missing or weak gates include:

- mobile-backend schema tests
- transitive dependency audit
- SBOM
- source/container/IaC scanning
- secret scanning
- iOS build
- Android instrumentation
- accessibility/golden tests
- coverage thresholds
- deploy smoke/canary/rollback
- immutable image promotion

### Required improvement

Build once and promote by digest:

1. CI builds image.
2. CI tests exact image.
3. CI generates SBOM and provenance.
4. CI signs exact digest.
5. Deployment references exact digest.
6. Environment approval promotes it.
7. Smoke tests run.
8. Automated rollback is possible.

Use GCP workload identity federation, immutable secret versions, and a dedicated service account.

### Acceptance evidence

- Cloud Run revision digest equals CI-tested digest
- Provenance attestation references commit SHA
- No local-source production deployment
- Exact Cosign certificate identity
- No public metrics
- Contract tests catch current claims mismatch
- iOS and Android release builds
- rollback rehearsal
- deployment acceptance report

---

# Q. Tests and evidence quality

### Status: P0/P1 passing tests do not prove the workflows

### Files

- `mobile/test/reconciliation_coordinator_test.dart`
- `mobile/test/app_state_repository_quarantine_test.dart`
- other latest-push tests
- `.github/workflows/ci.yml`
- launch evidence docs

### Good

- New concurrency and stale-transition cases were added.
- Per-record parsing is tested.
- Test names document intended contracts.
- CI has both backend and mobile suites.

### Problems

1. Several tests define success as “does not crash.”
2. Source-level tests read Dart source text and assert string ordering rather than behavior.
3. Quarantine tests intentionally bless lenient malformed records.
4. No real mobile-to-backend claims contract test.
5. No full principal transition integration test.
6. No process-death/state-recovery test.
7. No pagination stress test.
8. No consent revocation during operation.
9. No analytics concurrency/revocation test.
10. No runtime UI/accessibility evidence.
11. A test count in a commit message is not a release acceptance report.
12. Previously dismissed/skipped tests need explicit resolution.

### Required improvement

Adopt an evidence pyramid:

- strict unit tests
- generated-schema contract tests
- state-machine/property tests
- local Supabase/service integration
- process-death tests
- device end-to-end tests
- production-like acceptance and chaos tests

Ban source-string assertions except for narrow code-generation/tooling contracts.

### Acceptance evidence

- Every P0 task has a behavioral test
- Whole-system acceptance report records command, commit, environment, result, and artifacts
- No unresolved skipped launch-critical tests
- Contract drift fails CI
- Test failure demonstrates that the test catches the defect it claims to prevent

---

# R. Android and iOS platform posture

### Status: P1 release hardening incomplete

### Files

- `mobile/android/app/src/main/AndroidManifest.xml`
- `mobile/android/app/src/main/kotlin/com/coverwise/app/InstallReferrerReceiver.kt`
- `mobile/ios/Runner/Info.plist`
- platform entitlements/privacy manifests

### Good

- Android backup disabled
- minimal Android permissions
- usage descriptions exist
- raw referrer is not intentionally logged

### Problems

1. Exported install-referrer receiver can accept spoofed external broadcasts.
2. UTM values have no explicit length/schema bounds.
3. Custom URL scheme can be claimed by another app.
4. iOS plist includes development local-network and Bonjour declarations.
5. No reviewed associated-domain/universal-link setup.
6. No explicit reviewed iOS file-protection contract for policy sources.
7. No iOS Privacy Manifest was found in the reviewed search.
8. CI does not build iOS.

### Required improvement

- verified HTTPS links
- restrict/remove exported receiver
- bound and sanitize attribution data
- release-specific plist
- Privacy Manifest and permission audit
- explicit file protection
- iOS CI and device acceptance

---

## 5. Prioritized agent backlog

### Execution rule

Do not let agents independently patch isolated files. Each task owns a complete contract and must inspect all listed files plus adjacent callers, tests, migrations, docs, and runtime composition.

### Phase 0: Canonical decisions

1. **CW-P0-001 — Sign doctrine and cut prohibited surface**
2. **CW-P0-002 — Define shared wire-contract strategy**

### Phase 1: Release blockers

3. **CW-P0-003 — Rebuild claims sync contract**
4. **CW-P0-004 — Implement deterministic principal state machine**
5. **CW-P0-005 — Encrypt and principal-scope local policy sources**
6. **CW-P0-006 — Make consent server-authoritative**
7. **CW-P0-007 — Replace public deletion fiction with durable workflow**
8. **CW-P0-008 — Fence analytics by consent and principal generation**
9. **CW-P0-009 — Correct Q&A evidence semantics**
10. **CW-P0-010 — Make onboarding a durable legal transaction**
11. **CW-P0-011 — Deploy the exact signed artifact**

### Phase 2: Contract and orchestration hardening

12. **CW-P1-012 — Atomic local repository and durable quarantine**
13. **CW-P1-013 — Extract upload coordinator and durable receipt**
14. **CW-P1-014 — Version capabilities and fix composition race**
15. **CW-P1-015 — Worker readiness and handler fencing**
16. **CW-P1-016 — Typed guarded navigation and verified links**
17. **CW-P1-017 — Release localization and accessibility matrix**
18. **CW-P1-018 — CI contract, platform, and security gates**
19. **CW-P1-019 — Claims schema ownership and speculative-field cleanup**
20. **CW-P1-020 — Backend observability and maintenance topology**

### Phase 3: Maintainability and measured operation

21. **CW-P2-021 — Decompose god-screens and duplicated request paths**
22. **CW-P2-022 — Establish SLO, cost, cold-start, and chaos evidence**
23. **CW-P2-023 — Reconcile stale docs, comments, and motto references**

The companion JSON file contains full copy-paste task definitions.

---

## 6. Required launch gates

A release candidate is not acceptable until all gates pass.

### Product

- Signed product constitution
- What-If removed
- No unapproved advice, quote, ranking, or smart-guidance claim

### Identity and data

- Deterministic principal state machine
- Anonymous-to-account transfer survives restart and network loss
- Principal A data cannot appear under principal B
- Local policy bytes encrypted and erasable

### Consent and privacy

- Server-current consent enforced at protected operations
- Revocation races tested
- Public audit metadata cannot be forged
- Analytics is pseudonymous, fenced, and idempotent

### Core workflows

- Upload works online and queued offline
- Processing is durable
- Q&A claims are honestly classified
- Claims create/edit/delete/paginate/reconcile correctly
- Account deletion and export are truthful and durable

### Infrastructure

- Exact tested digest deployed
- Immutable secrets and least-privilege service identity
- Metrics protected
- Worker readiness truthful
- Rollback rehearsed

### Evidence

- Backend and mobile contract tests
- Android and iOS release builds
- device-level accessibility matrix
- process-death and fault-injection tests
- acceptance report pinned to release commit and artifact digest

---

## 7. Recommended sequencing

1. Sign doctrine and remove prohibited features.
2. Freeze and generate cross-layer contracts.
3. Fix identity, consent, claims, and local encrypted storage.
4. Refactor upload and Q&A state machines around those contracts.
5. Harden worker and backend operation boundaries.
6. Build integration and process-death tests.
7. Change deployment to exact signed digest.
8. Run Android/iOS runtime QA and accessibility acceptance.
9. Produce a release evidence report.
10. Only then consider production promotion.

Parallel agents should work only on tasks whose contracts are already frozen. The repository’s current failure pattern is caused by parallel local improvements landing before shared contracts converge.

---

## 8. Final assessment

The latest push should not be reverted wholesale. It contains useful building blocks and several improvements worth keeping.

The correct move is also not another broad “fix all audit findings” pass.

The correct move is to freeze the system around four canonical state machines:

1. **Principal ownership**
2. **Consent authorization**
3. **Document lifecycle**
4. **Evidence-backed answer lifecycle**

Claims, analytics, account deletion, capabilities, UI, and deployment should attach to those contracts rather than inventing local interpretations.

Until that happens, more tests and more defensive branches will increase code volume faster than they increase truth.
