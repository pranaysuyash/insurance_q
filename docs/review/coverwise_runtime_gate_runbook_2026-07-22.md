# CoverWise Runtime Gate Runbook (2026-07-22)

Use this runbook to close **open runtime gaps** after docs-coherence lock.

- Canonical references: 
  - `docs/decisions/ADR-2026-07-22-08-auth-and-provider-platform-strategy.md`
  - `docs/planning/coverwise_auth_provider_platform_gap_scan_2026-07-22.md`
  - `docs/review/coverwise_supabase_gap_register_2026-07-16.md`

## 0) Preconditions

- Environment variables for a staging Supabase project set (not production):
  - `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`, `SUPABASE_JWT_SECRET`
- Staging backend reachable (for app + worker APIs)
  - Frontend/API: `COVERWISE_API_URL`
  - Outbox worker process: running in non-local mode
- Test account identity available (email + password)

### Local two-principal rehearsal (BR-04/BR-05 preparation only)

With Docker, local Supabase, and the local API running, export only local test
keys and run `python3 tools/verify_local_tenant_isolation.py`. The tool creates
and removes two disposable users, uploads a generated PDF as principal A,
checks API and authenticated-Storage cross-owner denial, deletes it as A, and
checks post-delete absence. It refuses non-local targets before any request.
Record redacted output in the BR-05 evidence artifact. This is local runtime
preparation only, not deployed RLS, durable-worker deletion, or production
erasure evidence.

## 1) AUTH-01 gate — auth lifecycle (P0)

Evidence artifact: `docs/review/evidence/auth_lifecycle_2026-07-22.json`

Use this order and collect pass/fail logs:

1. Sign-up → confirm flow
   - Create a new user account.
   - Confirm email as required by Supabase project config.
2. Sign-in + refresh
   - Authenticate via app endpoint or SDK.
   - Force/observe refresh path (session expired/refresh token exercised).
3. Anonymous claim transfer
   - Start anonymous session path, create 1 seeded artifact, sign into real account, and call
     `/user/claim-anonymous` (or run app flow that triggers it).
   - Verify owned document UUID set changed from `anon:*` subject to stable account subject.
4. Sign-out behavior
   - Validate anonymous or signed-out mode state transitions and inability to call protected routes.
5. Recovery, deletion, export
   - Run password reset.
   - Run deletion/export workflow and validate downstream cleanup jobs are queued and replayed.

Acceptance condition:
- Evidence package contains at least one successful signed-in matrix row, one claim-transfer row, one refresh row, one recover/delete/export row, each with request/response + owner assertions.

## 2) RETR-01 + RETR-02 gates — retrieval and embedding safety (P0)

Evidence artifact: `docs/review/evidence/retrieval_parity_2026-07-22.json`

- Run representative corpus backfill using production-like corpora.
- Record:
  - dense+FTS ranking examples,
  - latency quantiles,
  - duplicate handling,
  - citation coverage and owner-filter correctness.
- Reproduce fallback when embedding dimension or model-family mismatch is encountered.
- Verify re-embed checkpoint + rollback plan and store migration script/hash.

Acceptance condition:
- A documented checkpoint exists before/after backfill, rollback path is reproducible, and no mixed-vector write slips through
  without hard-fail.

## 3) TRAIN-01 gate — provider execution lineage (P1)

Evidence artifact: `docs/review/evidence/training_execution_2026-07-22.json`

- Execute one provider-gated training run on configured credentials.
- Save:
  - training config, model/provider versions, commit SHA,
  - evaluation corpus IDs,
  - result hashes, run timestamps,
  - dataset release manifest linkage.

Acceptance condition:
- Artifact bundle is present and links dataset release IDs to model artifacts and evaluator outputs.

## 4) ASYNC-01 gate — recovery / deletion lifecycle (P1)

Evidence artifact: `docs/review/evidence/async_recovery_2026-07-22.json`

- Force fail-retry simulation for:
  - `qa_response`, `claim_verification`, `renewal_diff`
- Verify stale work items recover and no duplicate customer-facing effects.
- Verify account deletion and storage cleanup paths run to completion with post-conditions logged.
- Deploy the dedicated worker to the intended non-production environment and
  record its health/ready response, deployment revision, and start time.
- Run `tools/verify_deployed_launch.py` with both `--worker-url` and
  `--require-worker` for this gate; an API-only verifier pass is not ASYNC-01
  evidence.
- Enqueue one synthetic, non-customer job through the canonical producer. After
  the worker acquires its lease, deliberately restart or interrupt only that
  worker instance where the environment permits it; confirm the job is
  reclaimed/retried once, reaches its intended terminal state, and remains
  visible to the operator throughout. Do not use deletion or a real customer
  document as the synthetic job.

Acceptance condition:
- Recovery matrix shows retry counts, idempotency outcomes, worker health,
  restart/reclaim behavior, and final post-conditions for each async path.

## 5) PORT-01 gate — portability rehearsal (P2)

Evidence artifact: `docs/review/evidence/portability_rehearsal_2026-07-22.json`

- Run self-hosted Supabase rehearsal where possible.
- Capture auth export/import, RLS parity replay checks, storage restore, and failback notes.

Acceptance condition:
- Rehearsal artifact includes a successful/failing status for each step and explicit operator owner sign-off.

## 6) BIL-01 gate — RevenueCat and store lifecycle (P0)

Evidence artifact: `docs/review/evidence/revenuecat_store_lifecycle.json`

Use a non-production CoverWise deployment and a store test account. RevenueCat
itself does not create the sandbox/production distinction; record the store
transaction environment reported in the provider event. Do not put webhook
authorization values, store receipts, purchase tokens, or full customer
identifiers in the evidence artifact.

1. **Identity and initial purchase**
   - Start with a dedicated test identity and record its redacted app-user-ID
     hash/reference.
   - Purchase the configured subscription/product through the store test flow.
   - Verify the app's entitlement presentation, the server ledger state, and a
     real `INITIAL_PURCHASE` provider webhook accepted by the durable outbox.
2. **Restore and account continuity**
   - Restore the purchase after an app restart or on a second test device as
     appropriate for the selected store.
   - Confirm the entitlement is associated with the same account and no
     unrelated account gains access.
3. **Cancellation, refund, and expiry semantics**
   - Cancel through the supported store/provider test flow. Record the
     `CANCELLATION` event and whether access correctly continues through the
     reported expiration.
   - Exercise the provider/store-supported refund or expiration path. Record
     the resulting lifecycle event and confirm that the server ledger applies
     the provider timestamp ordering before changing entitlement state.
   - If a platform cannot simulate a step in its test environment, record the
     platform limitation and an approved production-observation plan rather
     than marking the step passed.
4. **Webhook replay, ordering, and durable writeback**
   - Use a real provider retry/replay or an approved non-production delivery
     mechanism that preserves the event ID. Confirm duplicate delivery does
     not grant, revoke, or consume twice.
   - Capture a delayed/out-of-order lifecycle pair where the provider tooling
     supports it, or record the exact unsupported limitation. Confirm the
     newer provider timestamp wins.
   - Verify the worker drains the accepted webhook job and the post-write
     entitlement read matches the expected server-ledger state.

Acceptance condition:
- The redacted evidence artifact links each observed provider/store event to
  the app-user reference, webhook/outbox job, ledger outcome, and final
  entitlement read. It includes initial purchase, restore, cancellation, and
  a refund/expiry outcome where the selected store permits it; it also records
  duplicate-delivery and ordering results or a platform-specific exception.

Provider reference: [RevenueCat webhook event types and fields](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields)
and [common webhook flows](https://www.revenuecat.com/docs/integrations/webhooks/event-flows).

## 7) OBS-01 gate — non-production crash and recovery observation (P1)

Evidence artifact: `docs/review/evidence/observability_recovery_2026-07-22.json`

Use a non-production crash-reporting project and synthetic test accounts/data.
Do not send customer policy text, credentials, raw document names, email
addresses, or support message bodies as event attributes.

1. Confirm the mobile build is configured for the named non-production
   observability project and records the expected environment/release tag.
2. Trigger one deliberate, uniquely labeled synthetic exception using an
   approved test-only path. Confirm the event arrives in the configured
   project with timestamp, release/environment, and sanitized error metadata.
3. Exercise the app's offline and backend-unavailable paths on a real test
   device or emulator. Confirm the user sees a recoverable boundary, retries
   do not duplicate work, and the event/health signal is visible to the
   operator without sensitive payloads.
4. Record the alert/triage owner, notification route, retention setting, and
   the operator action for a failed upload, Q&A request, and worker job.

Acceptance condition:
- Evidence links a redacted crash event and recovery observation to the
  non-production release, names the accountable triage owner, and demonstrates
  a user-visible recovery path. A local unit test, console log, or configured
  DSN alone does not pass this gate.

## 8) Update register and close loop

After each gate, append pass/fail entries in:
`docs/review/coverwise_supabase_gap_register_2026-07-16.md` and
`docs/planning/coverwise_auth_and_provider_execution_plan_2026-07-22.md`.
