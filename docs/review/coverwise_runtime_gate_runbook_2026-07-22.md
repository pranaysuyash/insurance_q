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

Acceptance condition:
- Recovery matrix shows retry counts, idempotency outcomes, and final post-conditions for each async path.

## 5) PORT-01 gate — portability rehearsal (P2)

Evidence artifact: `docs/review/evidence/portability_rehearsal_2026-07-22.json`

- Run self-hosted Supabase rehearsal where possible.
- Capture auth export/import, RLS parity replay checks, storage restore, and failback notes.

Acceptance condition:
- Rehearsal artifact includes a successful/failing status for each step and explicit operator owner sign-off.

## 6) Update register and close loop

After each gate, append pass/fail entries in:
`docs/review/coverwise_supabase_gap_register_2026-07-16.md` and
`docs/planning/coverwise_auth_and_provider_execution_plan_2026-07-22.md`.
