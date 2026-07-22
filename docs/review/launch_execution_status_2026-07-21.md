# Launch execution status — 2026-07-21

This is an execution record. Launch claims below are based on commands, current code, and local runtime behavior, not on planning documents.

## Current decision

CoverWise is not launch-ready yet. The local API path, Supabase-backed API
startup, launch-critical mobile surface, and Android compile path have verified
evidence. The local Supabase reset is not reproducible on the current machine,
and the remote schema probe currently finds `model_run_results` missing.
Production configuration, real external credentials, remote schema closure, and
distribution remain open.

## Code changes made in this pass

- Hardened nullable legal-document copy actions.
- Isolated Flutter Hive test directories to prevent cross-test locking.
- Corrected consent ledger revoke timestamps and latest-record selection.
- Corrected analytics consent cache evaluation after revoke/regrant.
- Made OCR optional at API import time when native OCR dependencies are unavailable.
- Verified the local OCR stack against the project venv and Homebrew runtime libraries; installed the missing `pdf2image==1.17.0` dependency and recorded it in `requirements-local.txt`.
- Fixed app startup ordering so analytics opens only after encrypted Hive boxes exist, and made `PrincipalKeyService` shared across callers.
- Added OpenAI SDK compatibility fallback for `max_completion_tokens`.
- Made production-config validation runnable from the repository root.
- Made the populated dashboard’s finite content eagerly testable and isolated its family extraction provider in dashboard tests.
- Updated dashboard test expectations to match the strings rendered by the current widgets.
- Isolated legal asset-bundle caches and made the upgrade purchase test use a genuinely pending billing future.
- Moved `flutter_native_splash` into runtime dependencies so Android's generated plugin registrant is present on the release classpath.
- Added a forward migration securing the pre-existing analytics views with invoker security and service-role-only grants: `supabase/migrations/20260721061309_secure_analytics_views.sql`.
- Normalized the legacy Supabase migration filenames to unique 14-digit versions, mirrored the base CoverWise schema into the CLI migration path, and fixed the FTS RPC result types.
- Added service-role table/sequence grants required by the server-side document and vector repositories.
- Pinned the tested Supabase Python client set and `httpx==0.27.2` so the GoTrue/PostgREST `proxy` client contract matches the installed HTTPX API.
- Connected the provided remote Supabase project through ignored env storage and upgraded the Python client to `supabase==2.31.0`, which accepts the modern `sb_secret_` server key format.
- Hardened Flutter startup to fall back to a local principal when the configured Supabase project disables anonymous sign-ins; account auth remains available.
- Added a durable, idempotent guest-to-account identity-link contract in `supabase/migrations/20260721074000_identity_aliases.sql` and wired the claim endpoint to record pending/completed/failed transfer state.
- Added guest-claim analytics outcomes, paywall-view instrumentation, RevenueCat account identification, and server subscription-state sync through the existing `/subscription/sync` route.
- Repaired the full-suite failures in the OpenAI verification harness, citation verifier test contract, doctr image input normalization, and account-deletion repository injection path.
- Added authenticated, idempotent RevenueCat webhook ingestion with verified-state precedence over client reconciliation; cancellation preserves access through expiry and expiration/revocation removes the verified entitlement.
- Fixed evidence substrate construction to use the required environment-backed Supabase client and added macOS Homebrew native-library path configuration for GLib/Pango/Cairo/GDK-Pixbuf/Harfbuzz/Fontconfig/Freetype before optional OCR/PDF imports.
- Stopped retrying deterministic OpenAI credential failures in the embedding path; configured local fallback remains observable while the invalid credential is replaced.
- Reconciled the Python dependency contract with `uv`: Supabase 2.31 now has a compatible Pydantic lower bound, the project venv is installed from `requirements-local.txt`, and `tools/run_backend_tests.sh` prevents accidental system-Python test runs.
- Added a macOS `DYLD_FALLBACK_LIBRARY_PATH` runtime path for Homebrew GLib/Pango/Cairo/GDK-Pixbuf dependencies without overriding the venv's PyTorch libraries.
- Added `pytest.ini` so standalone verification scripts are not mis-collected as unit tests; the one remaining skip is the intentionally credential/deployment-gated Azure integration test.

## Evidence captured from code/runtime

| Check | Result | Evidence tier |
|---|---|---|
| `flutter analyze` | No issues found | Tier 1 |
| Analytics consent gate tests | 5 passed | Tier 2 |
| Dashboard tests | 16 passed | Tier 2 |
| Complete Flutter test suite (current run) | 636 passed from `mobile/` with `--concurrency=1`; `flutter analyze --no-fatal-infos` also passes | Tier 2 current |
| Launch-critical mobile bundle | 132 passed | Tier 2 |
| Backend targeted tests | 33 passed | Tier 2 |
| Supabase/backend targeted tests after dependency and schema fixes | 17 passed | Tier 2 |
| Full backend pytest suite (historical baseline) | 277 passed, 14 failed, 4 skipped; retained as the pre-fix baseline | Tier 2 historical |
| Local backend `/healthz`, `/readyz`, `/health` | All 200 while server was running | Tier 4 |
| Local deployed-launch verification | Liveness, readiness, anonymous identities, profile isolation, and owner-scoped lists passed | Tier 3 |
| LLM token compatibility probe | Passed | Tier 2 |
| OCR imports with project venv + Homebrew dylib path | `PDFProcessor`, `ImageProcessor`, and `OCRPipeline` imported successfully | Tier 2 |
| Live iOS simulator + serve-sim | App running on iPhone 17 Pro; serve-sim HTTP 200 | Tier 4 |
| Production config validator against current `.env` | Deployment-time production values are still required, including the RevenueCat webhook authorization secret; local `.env` is not treated as production configuration | Tier 1 |
| Android release build (historical staging proof) | `build/app/outputs/bundle/release/app-release.aab` was built successfully (77.8 MB) with placeholder defines; ignored build outputs were later removed under disk pressure, so the artifact must be regenerated | Tier 2 historical |
| Local Supabase stack (historical run) | Docker Desktop running; local Postgres 17.6 and Supabase services healthy | Tier 4 historical; not reproducible on current disk state |
| Local Supabase migration reset (historical run) | All 13 normalized migrations applied successfully from a fresh local database | Tier 3 historical |
| Local Supabase schema lint (historical run) | No schema errors found | Tier 2 historical |
| Local Supabase RLS/grants (historical run) | Core tables have RLS; operator views deny anon/authenticated and allow service-role; document tables allow service-role repository operations | Tier 3 historical |
| Supabase-backed API on port 8001 | App startup, `/healthz`, and `/readyz` passed with local Supabase runtime values | Tier 3 |
| Supabase runtime config validator | Passed with local stack values supplied only to the process environment | Tier 2 |
| Remote Supabase Auth endpoint | `/auth/v1/settings` returned 200 with the publishable key | Tier 3 |
| Remote secret-key Python client | Read-only `documents` query succeeded with the provided server secret | Tier 3 |
| Remote-configured API on port 8002 | App startup, `/healthz`, and `/readyz` passed with remote Supabase values | Tier 3 |
| Remote-configured iOS simulator | Supabase initialization completed; anonymous-provider-disabled startup is handled by local-principal fallback | Tier 4 |
| Local identity-link tests | Guest-to-account link retry is idempotent; rebinding to another account is rejected | Tier 2 |
| Remote identity/analytics schema probe | Remote `identity_aliases` and `analytics_events` are available and queryable with the server key | Tier 3 |
| Remote migration application (historical claim; current recheck supersedes) | Earlier Management API evidence accepted migrations through `20260721090703`; current service-role probe finds `model_run_results` absent | Tier 3 historical / current gap |
| Current full backend pytest suite | 378 passed, 1 intentionally skipped through the canonical `uv` + `.venv` runner; this includes the full-health launch gate and safe Supabase schema diagnostic coverage | Tier 2 |
| Current Flutter analyzer | No issues found with `flutter analyze --no-fatal-infos` from `mobile/` | Tier 1 |
| Current remote-configured API on port 8002 | Latest code running in development/staging mode; `/readyz` returned 200 and a real anonymous profile round-trip preserved the same owner UID | Tier 3 |
| RevenueCat webhook tests | Authorization, duplicate delivery idempotency, initial purchase, and expiration precedence pass | Tier 2 |
| Native runtime probe | Homebrew native libraries and WeasyPrint import pass; doctr predictor initializes successfully from the project venv | Tier 2 |
| Billing-ledger migration validation | New PostgreSQL ledger migration parsed and its purchase, duplicate, stale-event, and expiration behavior passed locally and through the hosted Supabase RPC | Tier 3 |
| Remote billing-ledger validation | Hosted Supabase RPC passed purchase, duplicate, stale-event, entitlement-state, and synthetic-row cleanup checks; publishable-key reads were denied by RLS | Tier 3 |
| RevenueCat outbox path | Staging API returned accepted/queued, a real remote `job_outbox` row was created, the worker handler applied the hosted billing RPC, and synthetic queue/ledger rows were removed | Tier 3 |
| Latest staging API on port 8002 | Started with current billing fail-closed code; `/readyz` 200, anonymous creation 200, remote subscription status/sync/webhook paths returned 200, and synthetic billing rows were removed | Tier 3 |

## Current-state addendum (2026-07-21)

The current process state is `serve-sim` on port 3200 and the staging API on
port 8002, both returning 200/readiness responses. Docker Desktop was stopped
after its Docker VM consumed the local disk and made the CLI unresponsive; no
containers, project files, or session data were deleted. A full local
Supabase reset therefore remains unverified in the current machine state.

The current staging `/health` probe is intentionally returning HTTP 503 with
`embedding_probe=failed`: the effective process uses the Supabase vector
backend and the configured OpenAI embedding credential is invalid. This is a
real degraded-RAG signal, not a missing dependency; `/readyz` remains HTTP 200
because the API and document-processing services are initialized. The embedding
contract must be repaired before treating staging Q&A as healthy.

### Current local-service recheck (2026-07-21)

The machine currently has Homebrew PostgreSQL 17.4 and Redis running, and
`pg_isready -h 127.0.0.1 -p 5432` accepts connections. This is not equivalent
to the repository's local Supabase stack: the standalone database exposes
`pgcrypto` and `pg_trgm` but not `vector`, and the Docker daemon is currently
unreachable. The root volume is at 100% usage with approximately 566 MB free,
so starting Docker again is not a safe verification action until disk pressure
is handled. It is useful for generic SQL diagnostics but cannot prove the
Supabase migration, RLS, or pgvector contract. No migration was applied to the
standalone database.

The repository `.env.example` was corrected to use the canonical
`text-embedding-3-small` model and to enumerate the production launch fields;
no secret values were added. The project `.venv` remains dependency-complete
(`uv pip check` passed).

The Cloud Run deployment contract was tightened: the API deploy now requires
and binds the RevenueCat webhook authorization secret, and its preflight
validates the non-secret runtime file plus explicitly declared Secret Manager
bindings. The validator supports both dotenv and the YAML mapping format
accepted by `gcloud --env-vars-file`.

### Current remote-schema recheck (2026-07-21)

The non-mutating service-role probe confirms that the required remote tables are
present except `public.model_run_results`, which returns PostgREST `PGRST205`
(`public.model_run_results` is absent from the schema cache). The local Supabase
CLI is not linked to the project, and the supplied `SUPABASE_EXPERIMENTAL_API_KEY`
was rejected by `supabase projects list` as an invalid CLI access token. No
remote migration was attempted. Closure requires a valid Supabase CLI access
token and then:

```bash
export SUPABASE_ACCESS_TOKEN=<valid-token>
supabase link --project-ref eyumuxwabmsymytjbxoj
supabase db push --linked --dry-run
supabase db push --linked --yes
uv run --python .venv/bin/python python tools/verify_supabase_schema.py
```

The supplied database password was also tested through the CLI's direct
password path against one candidate Mumbai pooler endpoint. The endpoint
returned `ENOTFOUND tenant/user ... not found`, which proves that candidate
region/connection identity is not the project's pooler route; it did not apply
or partially apply a migration. The project region or a valid linked CLI
credential is still required before another direct connection attempt is safe.

## Remaining blockers and closure paths

1. Production environment is incomplete. The remote URL, publishable key, and modern secret key are now present in ignored local env storage, but the remote project has anonymous sign-ins disabled and still needs the approved production anonymous-auth strategy/signing key, public site URL, allowed origins, backend settings, and RevenueCat webhook authorization; rerun `tools/validate_production_config.py`.
2. The local OpenAI key currently receives 401 invalid-key responses. Replace it with a valid production credential or explicitly configure the intended production fallback, then rerun real extraction and question-answer flows.
3. Production Supabase schema linkage is not yet current: the non-mutating remote probe finds `model_run_results` missing, and the supplied CLI credential was rejected. After a valid CLI/database credential is available, apply the migration and run authenticated cross-owner isolation and guest-claim tests against a real staging account pair.
4. The Android bundle now compiles, but it used placeholder release defines. Rebuild with real production values and verify install/startup plus authenticated flows before distribution.
   The canonical release script now fails closed if `mobile/android/key.properties` is absent or the historical tracked `android/key.properties` remains; credential rotation and history cleanup are still required.
5. The full backend suite is now green at 378 passed and 1 intentionally skipped through the canonical `uv`/`.venv` runner. The remaining skip is `tests/test_azure_api.py`, which requires a real deployed integration base URL and credentials; it is not a dependency or collection failure.
6. External distribution/deployment was not performed. No deployment destination or production credentials were available, and no commit or push was authorized.
7. The identity-link, analytics, policy-domain, artifact-lifecycle, and billing-ledger tables are now remotely queryable with service-role access and denied to publishable-key reads. Real RevenueCat sandbox delivery and production webhook-secret configuration remain required before relying on live subscription revenue data.
8. The outbox worker now has a Cloud Run-compatible health listener and a dedicated deployment script (`tools/deploy_outbox_worker.sh`), but no external worker deployment was performed in this session. Deployment and a real queued-job round trip remain required before claiming production durable-work execution.
9. CI now contains a pinned Flutter analyze/test/release-build job and the Docker publication uses an immutable commit-SHA tag; hosted workflow execution remains unverified from this local session.
10. The legacy CI formatter/import gate was failing on broad historical style debt, including many unrelated files. It now runs pinned Ruff critical-safety checks (`E9`, `F821`) plus Python compilation; full formatting/import cleanup remains explicit follow-up debt rather than a silently failing release gate.

## Artifact and workspace state

All work remains uncommitted. Existing parallel changes were preserved. `insurance_app.db` changed during local backend startup and remains for review; it was not reverted or deleted. The ignored, regenerable `mobile/build/` directory was moved to Trash after the disk-pressure check; no source files, database files, Docker data, or user caches were removed.

## Anything else?

No additional launch blocker was inferred from documents alone. The blockers above are the ones reproduced from current code, commands, runtime output, or missing executable deployment prerequisites.

## Anonymous identity strategy analysis (code-derived; decision pending)

This is an analysis, not a decision that the product must be account-first or anonymous-first. It is based on the current executable paths in `mobile/lib/main.dart`, `mobile/lib/services/auth_service.dart`, `mobile/lib/services/analytics_service.dart`, `mobile/lib/services/billing_adapter.dart`, `src/api/user.py`, `src/api/analytics.py`, and `src/api/subscription.py`.

### What the current code actually does

- The product already has a custom guest identity: `POST /user/anonymous` issues a 30-day server-signed bearer token whose owner is an `anon:<uuid>` subject. Documents and policy-bearing API requests use that owner.
- Supabase is currently used for account sessions. The app also attempts `auth.signInAnonymously()` only to derive the local encryption principal; the remote project currently has anonymous sign-ins disabled, and startup falls back to a device-local principal.
- These are separate identities. `claim-anonymous` moves documents from the custom `anon:<uuid>` owner to the Supabase account `sub`; there is no Supabase-anonymous-to-account claim path.
- Analytics remain server-attributed to the bearer principal in `src/api/analytics.py`, but the guest-to-account link is now recorded durably when the remote migration is present. The client sends `install_id`, `session_id`, and claim outcome events without raw identity IDs in event properties.
- `identity_created`, `account_created`, claim lifecycle events, paywall views, and purchase lifecycle events are now instrumented and registered in the mobile schema. Server-confirmed subscription lifecycle webhooks are implemented and covered by idempotency tests; a real sandbox delivery is still unverified.
- RevenueCat now receives the Supabase account UID via `PurchasesConfiguration.appUserID` or `Purchases.logIn(accountId)` and the mobile client calls `/subscription/sync`. Verified webhook events take precedence over client sync; the remaining production gaps are webhook-secret configuration and moving the webhook audit ledger to the canonical remote store.

### User and business implications

Guest mode can improve the user journey by letting a person upload a policy, receive an extraction or answer, and reach the product's value moment before asking for email/password. It also gives the product a stable server owner for the guest workspace, instead of treating every request as an unauthenticated visitor.

That can improve revenue by increasing the number of users who reach activation and a relevant paywall. It also allows measurement of the full funnel: install -> upload -> successful extraction -> question -> answer -> paywall -> purchase. Account-first can improve recovery, cross-device continuation, email lifecycle, and subscription ownership, but it adds friction before value and can lower top-of-funnel activation.

The revenue upside is not only conversion rate. A durable identity lets the team distinguish a first-time trial from a returning subscriber, prevent duplicate entitlement attribution when a user changes devices, measure paywall reach per activated workspace, and connect purchase/renewal/expiration to the originating activation cohort. The cost is that account creation can reduce the number of users who ever reach the paywall, while an unclaimed guest workspace creates support, refund, and deletion ambiguity. These are measurable tradeoffs, not reasons to assume one onboarding policy.

The current code has the primitives to run that comparison, but not enough verified production data to declare a winner. The missing measurement layer is an explicit experiment assignment plus a stable pre-account-to-account link used consistently by analytics and RevenueCat events; the link and lifecycle events now exist, but the experiment and server-authoritative production ledger remain incomplete.

The analytics benefit is not simply “more data.” It is the ability to measure anonymous activation and then attribute later account creation and purchase to the same journey. With the current separate UIDs, that attribution is incomplete and can double-count people or lose the pre-account funnel.

### First-principles recommendation

The durable product choice should be **value-first guest mode with an account conversion boundary**, not a blanket account-first rule and not an unconditional Supabase-anonymous toggle.

The boundary should occur before a user needs durable cross-device recovery, cloud backup, family sharing, or a paid entitlement that must survive identity changes. This keeps the first value moment low-friction while making the reason to create an account concrete and user-benefiting.

The durable technical choice should be **one canonical identity pipeline**. Before enabling Supabase anonymous sign-ins in the remote project, either make Supabase Auth the canonical guest identity and retire the custom bearer identity, or explicitly keep the custom identity and remove Supabase anonymous auth from the product path. Maintaining both as owners is the current architectural risk.

### Required work before choosing or enabling the provider path

1. Define the canonical owner ID and identity-alias/claim model for guest -> account conversion, including idempotency, retries, partial transfer, deletion, and recovery.
2. Align documents, analytics, consent, lifecycle/RevOps, and subscriptions to that canonical identity model. The current implementation covers document claim, claim lifecycle events, paywall/purchase lifecycle events, RevenueCat account identification, and verified webhook precedence; remote account-pair E2E proof remains open.
3. Make RevenueCat identity transitions explicit and test restore/purchase/upgrade on the guest-to-account path. The webhook route and idempotency tests exist; production configuration and a real sandbox delivery are still required before relying on revenue analytics.
4. Complete the missing funnel and purchase event emissions, register the emitted event names, and add install-to-account attribution without sending PII. Event names are now registered and emitted for current lifecycle points; production analytics volume and attribution quality remain unverified.
5. Run an experiment comparing guest-first and account-first onboarding using activation, paywall reach, paid conversion, 7/30-day retention, claim/restore success, support burden, and anonymous-orphan/deletion rates.
6. Only then enable the selected Supabase provider setting and run cross-owner, account-claim, purchase-restore, deletion, and analytics-attribution integration tests against a staging project.

Current confidence: Tier 1 static code evidence for the product/economic analysis; Tier 3 for the observed Supabase configuration and API identity behavior. No account-first product decision has been made.

## Supabase security audit addendum (2026-07-21)

The live backend does not use the `public.profiles` table for `/user/profile`
or for account identity decisions. `src/api/user.py` constructs that response
from the verified bearer claims, and active server data paths use the
service-role client. The profile table is therefore server/operator-owned in
the current product path.

Static migration review found one latent contract issue for a future
direct-client flow: `public.profiles` grants authenticated `insert` and
`update`, but defines only a `select` policy. PostgreSQL RLS would make
authenticated writes non-functional until matching owner-scoped `with check`
and `using` policies exist. No access was widened in this pass. The closure is
to keep profile mutations service-role-only, or add explicit owner-scoped
policies in the same change when direct authenticated profile editing is
actually enabled.

The security-definer functions reviewed use an explicit `search_path`, and
operator/data views are security-invoker and service-role-only. Storage object
policies include owner checks on select, insert, update, and delete. This is
static migration evidence; live remote policy verification remains blocked
until the project is linked with a valid Supabase CLI access token.

## Launch-gate hardening addendum (2026-07-21)

`tools/verify_deployed_launch.py` now checks `/health` in addition to liveness
and readiness. A service is not launch-ready when the embedding or document
processing health contract is degraded. Against the current staging API, the
verifier passes liveness, readiness, anonymous identity creation, profile
round-trips, and owner-scoped lists, but correctly fails `service health` with
HTTP 503 because the OpenAI embedding credential is invalid. This converts the
current degraded-RAG finding into an executable release gate rather than a
documentation-only warning.

The verifier accepts the canonical API success payload `{"status": "ok"}`;
`{"status": "degraded"}` with HTTP 503 remains a failure. A fresh current-code
instance on port 8003 was started with the already-running local healthy
process's credential (without printing or persisting it) and passed the full
verifier: liveness, readiness, health, unauthenticated rejection, two distinct
anonymous owners, profile round-trips, and owner-scoped document lists. Port
8002 still uses the rejected value in `.env` and remains degraded. This proves
the code path and local credential availability, not production credential
rotation or deployment configuration.

### Anything else?

Yes: the previous verifier could have produced an all-green launch result while
the API's full health endpoint was degraded. That gap is now covered by code,
tests, and the operator tool documentation.

## Flutter resource-gate addendum (2026-07-21)

The current full Flutter rerun did not produce a completion claim. The first
attempt stalled under overlapping test processes; the clean attempt then
failed while compiling `service_test.dart` with macOS `ENOSPC` (the root
volume had approximately 566 MB free). The isolated `follow_up_chips_test.dart`
passed all 12 tests and `flutter analyze --no-fatal-infos` passed. The ignored,
regenerable `mobile/build/` directory was moved to Trash after confirming it
was 4.1 GB of build output; source files and user data were not deleted. A
fresh full Flutter suite is still required after disk capacity is restored.

## Mobile verification addendum (2026-07-21)

After the document-list fixture was aligned with the canonical policy taxonomy
(`Health Insurance`, `Auto Insurance`, and so on), the current focused mobile
set passed 120 tests and `flutter analyze --no-fatal-infos` reported no issues.
The full current Flutter suite remains intentionally unclaimed because the
machine has only about 2 GB free and prior full-suite compilation failed with
`ENOSPC`; the last completed broad suite remains historical evidence.

The resource gate is now closed for the current checkout: after disk capacity
recovered, the full `mobile/` suite completed with **636 passed**, and the
analyzer remained clean. The earlier ENOSPC observations remain historical
context; they no longer describe the current verification state.

## Final local verification addendum (2026-07-21)

The current checkout now has the following local evidence:

- backend: `391 passed, 1 skipped`
- mobile: `636 passed` with `--concurrency=1`
- Flutter analyzer: no issues
- strict document-capability evaluator: native PDF, table/cell, image-artifact,
  AcroForm field, and synthetic doctr OCR cases passed
- launch verifier: passed against both the serve-sim target API on port 8000
  and a fresh current-code instance on port 8003
- serve-sim: HTTP 200 on port 3200

The remaining launch gaps are external-state gates, not untested local code:
the `.env` OpenAI key is rejected while a different already-running local
process credential succeeds; remote Supabase lacks `model_run_results` and the
available CLI token is invalid; production deployment and authenticated
RevenueCat/remote migration E2E remain unverified. Docker Compose is installed,
but the Docker daemon currently returns an EOF during `docker version`, so no
local Supabase stack claim is made.

### External-state recheck (2026-07-21)

Docker Desktop's backend log identifies the daemon failure as `no space left on
device` while writing Docker's host analytics store; the Docker data directory
is approximately 9.7 GB. No Docker prune, reset, or deletion was performed.
The three project-held Supabase keys were tested only as CLI access-token
candidates and none was accepted by the CLI's `sbp_...` access-token contract.
The remote schema therefore remains unchanged and requires a valid Supabase
personal access token or the correct direct database connection details.

## Current verification correction addendum (2026-07-21)

The previous local verification counts above are historical snapshots. The
current checkout rerun completed with **396 passed, 1 skipped** through
`.venv/bin/python -m pytest -q`; the intentional skip remains the credential-
and deployment-gated Azure integration test. Ruff critical checks, `uv pip
check --python .venv/bin/python`, and `git diff --check` also pass.

The strict document-capability evaluator was rerun with local doctr OCR. All
five executable cases passed with zero unrun cases: native digital PDF,
synthetic native table/figure, synthetic scanned OCR, mixed native/scanned
PDF, and synthetic native AcroForm. Sentence nodes are now present in the CIR
for exact source-linked
structural segments, and CIR metadata records observed Unicode script families
as a routing signal; neither is being represented as language-understanding
or multilingual OCR accuracy.

The live launch verifier was rerun against the current API on port 8003 with
the serve-sim origin on port 3200. Liveness, readiness, integrated health,
unauthenticated rejection, two distinct anonymous owners, profile round trips,
owner-scoped lists, and CORS all passed. The verifier now also accepts an empty
successful CORS-preflight body, with a regression test covering that behavior.

The mixed-PDF path was also hardened: native pages and image-only pages are
classified independently, shared doctr OCR is attempted for image-only pages,
and unresolved pages produce an explicit partial document state. Focused
regression coverage for mixed capability classification and partial-state
derivation passes.

## Local Supabase closure addendum (2026-07-21)

Docker is now available and the local Supabase containers are healthy. A dry
run showed 13 migrations pending after `20260721079000`; those migrations were
applied to the local database with `supabase db push --local --yes`. The local
schema verifier now reports all required tables present, including
`billing_subscription_states` and `model_run_results`, and `supabase db lint
--local` reports no schema errors. The local migration list is fully aligned
through `20260721140000`.

The local Supabase-backed API on port 8001 passes the full launch verifier,
including liveness, readiness, integrated health, anonymous owner isolation,
and CORS. This closes the local-stack gate only; the remote project still
reports `model_run_results` missing and has not been mutated.

The latest full backend rerun completed with **407 passed, 1 skipped**. The
strict capability evaluator now executes five cases with local doctr and all
five pass, including the mixed native/scanned PDF case. The OCR worker retries
the untouched source image when preprocessing produces an empty or trivially
small result; this fallback is logged and remains bounded to one retry.

## Addendum — local guest-to-account acceptance proof (2026-07-21)

The local Supabase/Auth/API path now has a reusable acceptance verifier at
`tools/verify_local_identity_claim.py`. It is local-only, creates a synthetic
`example.com` account, creates an anonymous identity through the running API,
claims that identity with the real Supabase account bearer, verifies the
account profile, and deletes the temporary Auth user in a `finally` cleanup.
It never uploads a document or prints credentials.

The live run against local Supabase and the current API on port 8005 passed:
local account signup (HTTP 200), anonymous identity (HTTP 200), guest-to-account
claim (HTTP 200), and account profile (HTTP 200). This is Tier 3 local
integration evidence for the identity boundary, not production deployment
proof. The identity-link service also accepts `SUPABASE_SECRET_KEY` directly,
so direct service use no longer depends on main-entrypoint normalization.

The same test group passed 44 tests, including fallback and direct-secret-key
coverage. The active current-code API used for this proof is port 8005; the
serve-sim browser remains on port 3200. Remote Supabase schema, production
secrets, RevenueCat webhook authentication, and deployed worker recovery remain
open external-state gates.

## Addendum — Supabase server-key contract convergence (2026-07-21)

The current-code audit found that the main entrypoint normalized
`SUPABASE_SECRET_KEY`, but several direct service constructors still read only
`SUPABASE_SERVICE_ROLE_KEY`. The canonical service paths now use
`src.utils.runtime_config.supabase_server_key()`, covering repository,
object-store, evidence, processing-event, auth, vector, lineage, dataset,
consent, policy, account, anti-abuse, and document-processing boundaries.
This prevents a configured modern Supabase environment from silently disabling
one of those paths when invoked outside the main entrypoint.

Verification: the full backend suite completed with **417 passed, 1 skipped**;
critical Ruff, dependency, compilation, and diff checks passed. The live local
identity verifier passed signup, anonymous identity, claim, and profile checks;
local Supabase schema lint remained clean. This is local/runtime evidence only.

Remote recheck remains explicit: the project responds to Auth, but
`model_run_results` is still missing/unqueryable (`PGRST205`). No remote
migration was attempted because no valid project access token or direct remote
database credential was found in the repository environment, local Supabase
configuration surfaces, or shell history. The developer `.env` is a secret-
bearing source file and is not a valid production runtime env file; deployment
must bind secrets through Secret Manager as the deployment script requires.

## Addendum — typed source-span capability contract (2026-07-21)

The evidence substrate migration `20260721160000_source_span_capability_types`
now allows source-bearing CIR nodes to retain their actual type: text block,
sentence, heading, line, word, table, table cell, formula, form field, caption,
or annotation. `layout_block` is no longer mislabeled as a paragraph. Image-only
figures remain page-artifact evidence and are not converted into synthetic
source text.

The migration applied successfully to local Supabase, and the focused contract
suite passed 41 tests. This closes the schema/adapter drift locally; specialist
OCR table recovery, formula recognition, handwriting, and production remote
migration remain separate benchmark/deployment gates.

## Addendum — runtime document-capability visibility (2026-07-21)

The current API health contract now includes a safe `document_capabilities`
snapshot. The new CLI `tools/inspect_document_capabilities.py` provides the
same report without starting the API. It identifies active PyMuPDF/native and
doctr paths, disabled optional Docling/MinerU/Surya/Paddle profiles, and
explicit candidate/unavailable states for formulas, handwriting, multilingual
accuracy, and VLM annotation. No credentials or source text are included.

Verification: CLI execution and six runtime-health tests passed. The registry
reports availability, not corpus-level accuracy; the existing strict document
benchmark remains the quality gate.

Fresh runtime proof: a current-code API instance on port 8006 returned HTTP
200 for `/health`, `/healthz`, and `/readyz`, and `/health` included
`document-capabilities.v1` with the expected native/OCR/table/form/figure,
formula-candidate, handwriting-unavailable, and multilingual-routing-only
states. The browser-facing serve-sim remains on port 3200. The developer
OpenAI credential is still rejected by the provider; the current development
instance falls back to local Ollama, so this does not establish production
provider readiness.

Final regression after the capability registry integration: **422 backend
tests passed, 1 intentionally skipped** (the deployed Azure credential-gated
integration test). Ruff, dependency, compilation, and diff checks also pass.

The registry’s VLM state is explicit: local Ollama/OpenAI profiles are
configured-but-unverified, while Mistral and Gemini document-understanding
profiles remain candidates. A successful text fallback is not image-understanding
proof; the image-fixture benchmark and provider/privacy review remain required.

## Addendum — final local regression and mobile surface (2026-07-21)

The current local regression is green: **432 backend tests passed, 1
intentionally skipped**, and the Flutter suite completed with **639 tests
passed**. `flutter analyze --no-fatal-infos`, Ruff, dependency checks,
compilation, and `git diff --check` also passed. The local serve-sim remains
available at port 3200; the current-code API remains available at port 8006
with `/health`, `/healthz`, and `/readyz` healthy.

This closes the local code, test, and development-runtime gates. It does not
close the remote production gate: the Supabase CLI still has no project access
token, and the remote schema probe still reports `model_run_results` as
missing/unqueryable. No remote migration or deployment mutation was attempted.

Fresh current-code API proof on port 8007 also exposes the live VLM registry:
OpenAI Vision and local Ollama are `configured_unverified`, while Mistral OCR
annotations and Gemini document understanding are `candidate`. The health
contract correctly requires an image-fixture benchmark and provider/privacy
review before any of these routes can be treated as production capability.

## Addendum — local migration closure and remote credential classification (2026-07-21)

The local Supabase database was rechecked against the current migration set and
had two pending migrations. Both were applied locally:
`20260721170000_policy_slot_reservations.sql` and
`20260721180000_qa_usage_ledger.sql`. The local database now contains
`model_run_results`, `policy_slot_reservations`, `qa_pack_grants`, and
`qa_usage_events`; the Q&A reservation function is present. Local schema lint
reports no errors and a dry-run reports no pending migrations.

The existing experimental `sbp_v0_...` value was tested as the Supabase CLI
access token. Supabase rejected it as an invalid Management API token format.
It is therefore not sufficient to apply the remote migration. The remote probe
continues to report only `model_run_results` as missing/unqueryable; no remote
state was changed.

Final backend regression after local migration application: **432 passed, 1
intentionally skipped**; `uv pip check`, compilation, and `git diff --check`
also passed.

The strict document-capability evaluator was also rerun with local doctr in the
project virtual environment. All five manifest cases passed with zero unrun
cases, including scanned and mixed-page OCR. This remains synthetic Tier 2
evidence and does not substitute for the consented corpus and specialist
provider gates.

## Addendum — production OCR dependency parity (2026-07-21)

Deployment inspection found that the Docker image used the slim dependency
profile even though local verification used the OCR-enabled project profile.
The canonical `Dockerfile` now installs `requirements-production-ocr.txt`,
which pins the same PyTorch/doctr runtime used by the strict evaluator, and the
Cloud Run deployment default is 4Gi. This removes the local-versus-production
dependency mismatch for scanned PDFs. A production-like container build and
runtime smoke remain required before claiming deployed OCR readiness.

Container evidence is currently partial, not green: the first Linux build
completed dependency installation but the doctr import smoke exposed a missing
`libpangoft2-1.0-0` runtime library. That package is now declared in the
Dockerfile. A rebuild could not be completed because Docker Desktop stopped
responding (`Docker Desktop is unable to start`). The exact closure check is to
restart Docker Desktop, rebuild `coverwise-api-ocr:local`, then run the doctr
import/predictor smoke and a generated scanned-page request inside the image.

The legacy AWS multi-architecture and Azure full-backend generators were also
aligned to the same OCR profile, Linux libraries, and 4Gi-class memory budget;
they no longer silently rebuild a slim scanned-document-incompatible image.

## Addendum — deployment contract regression and full-suite rerun (2026-07-21)

The new production-container contract tests passed, covering the OCR profile,
Linux runtime libraries, generated deployment images, and model-bearing memory
defaults. The full backend suite then passed **442 tests, 1 intentionally
skipped** when run with `TMPDIR=/tmp`; the earlier 10,000-row analytics failure
was reproduced as a temporary-volume exhaustion error and passed under the
explicit temporary directory. This is an environment-health qualification, not
a code failure.

The browser-facing serve-sim was restored on port 3200 (HTTP 200). Current-code
API health is HTTP 200 on ports 8006 and 8007; port 8007 includes the live VLM
registry, while 8006 is an older process snapshot. These are local runtime
surfaces for parallel testing, not deployed production proof.

## Addendum — corrected container build and ARM64 predictor boundary (2026-07-21)

Docker recovered and the corrected `coverwise-api-ocr:local` image built
successfully. The image installs the production OCR profile and all required
Linux libraries; a container import smoke reached `fitz`, `torch`, and `doctr`
successfully. This is Tier 2 container-build/import evidence.

The next container smoke then failed at doctr predictor construction with exit
code 139 (native segmentation fault), reproduced with one and two OpenMP/MKL
threads and also with `pretrained=False`. The Docker daemon became unavailable
after this native crash, so no generated scanned-page or container HTTP smoke
can be claimed. The project virtual environment remains the verified OCR lane:
the doctr predictor initializes there and the strict five-case synthetic
document evaluator passes. This is now an explicit ARM64/container-runtime
deployment blocker, not a missing-package blocker.

Closure requires a stable Docker daemon plus an ARM64-safe OCR runtime choice:
either a pinned compatible doctr/PyTorch build verified by the same predictor
and scanned-page smoke, or an explicitly selected isolated OCR worker/provider
with its own deployment contract and benchmark. Until then, deployment is
OCR-import-ready but not OCR-execution-ready.

## Addendum — explicit x86_64 OCR runtime and container closure (2026-07-21)

The architecture diagnosis was completed against the actual image: basic Torch
operations worked in Linux ARM64, while torchvision ResNet forward execution
segfaulted. The canonical Dockerfile now declares `linux/amd64` explicitly and
installs CPU-only Torch/torchvision from the PyTorch CPU index on x86_64. The
generated AWS, Azure, and Cloud Run deployment paths therefore share an
architecture-explicit OCR contract instead of relying on the developer
machine's architecture.

The rebuilt x86_64 image passed all three runtime layers: doctr predictor
initialization, a generated scanned-page OCR smoke extracting `COVERWISE`,
`POLICY`, and `CW-2026-0042`, and an HTTP `/healthz` smoke returning 200. The
first HTTP run also exposed and corrected a real production import gap:
`redis==5.0.1` is now in `requirements.txt` rather than only the local profile.
The full `/health` endpoint returned 503 in the credentialed smoke because the
current local OpenAI key is invalid (401) and no local embedding fallback is
bundled in the production image; this is a credential/provider readiness
failure, not an OCR crash.

## Addendum — remote migration-history parity risk (2026-07-21)

The remote schema is now present and the required-table verifier is green, but
the remote migration ledger is not a complete mirror of the repository's
migration set. A live read-only query returned one history row: the generated
Management API entry for the newly applied `model_run_results` migration,
while the remote database already contains the other application tables. This
is not a current schema-availability failure, but it is a release, rollback,
and drift-audit risk because a future blind `supabase db push` could treat
existing remote objects as unapplied local migrations.

The safe closure path is an explicit migration-history reconciliation: compare
remote object definitions and policies against each repository migration,
identify the authoritative baseline, then record the baseline/repair through a
reviewed DBA change before normal CLI migration flow resumes. Until that audit
is completed, remote schema correctness is Tier 3 verified, while migration
ledger parity and rollback safety remain open launch gates.

## Addendum — production entitlement and Q&A schema closure (2026-07-21)

The first read-only parity audit found that the production feature flags select
Supabase-backed policy-slot reservations and server-authoritative Q&A usage,
but the remote project lacked their tables and RPC functions. The exact
repository migrations `20260721170000_policy_slot_reservations.sql`,
`20260721180000_qa_usage_ledger.sql`, and
`20260721190000_qa_usage_reservation_lifecycle.sql` were applied transactionally
through the same Management API migration path. The follow-up audit now reports
all 46 repository-declared tables present and all six required RPC functions
present; it exits 0. No application rows were inserted by these migrations.

The reusable read-only check is
`tools/audit_supabase_migration_parity.py`. It intentionally reports the
remaining ledger warning separately: all current objects are present, but only
four generated remote history rows describe a 44-file repository migration
directory. Normal remote migration flow must still wait for a reviewed baseline
reconciliation.

The local ARM64 Docker image is not a supported OCR execution target. The
supported production target is the explicit x86_64 image; local ARM developers
should use the project venv or the x86_64 Docker target for container parity.

## Addendum — remote Supabase authority and schema closure (2026-07-21)

The earlier remote-schema blocker is closed. The app `.env` experimental
`sbp_` credential was rejected by the CLI because it is not accepted by the
CLI's legacy token parser, but a direct read-only Management API probe
authenticated successfully and listed the exact `coverwise` project ref
`eyumuxwabmsymytjbxoj`. A read-only database query confirmed that
`public.model_run_results` alone was absent.

Using the official transactional Management API migrations endpoint, the exact
contents of repository migration
`supabase/migrations/20260721100000_model_run_results.sql` were applied to that
project. Verification then confirmed the generated migration-history entry,
PostgREST queryability, RLS enabled, and no table ACL for `public`, `anon`, or
`authenticated` with server-side `service_role` privileges. The canonical
`tools/verify_supabase_schema.py` now returns all required tables present and
exit code 0. No application data was inserted or deleted.

This is Tier 3 remote schema evidence. Anonymous sign-ins remain disabled by
the project configuration and continue to be handled by the app's
local-principal fallback; that is a product/auth decision, not a schema
failure.

## Addendum — current full launch-gate rerun (2026-07-21)

The current checkout was re-run after the remote entitlement/Q&A closure:

- Backend: **481 passed, 1 skipped** with the project `.venv` and `TMPDIR=/tmp`.
- Mobile: **649 tests passed** and `flutter analyze` reported no issues.
- Remote schema verifier: exit 0.
- Remote parity audit: all 46 local tables and six required production RPCs
  present; migration-history parity warning remains explicit.
- serve-sim: HTTP 200 on port 3200; current API: HTTP 200 on port 8007.

This supersedes the older 407/636/remote-missing counts in earlier historical
sections. It does not convert provider credentials, Android signing, external
deployment, or real RevenueCat delivery into verified evidence.

## Addendum — expanded remote integrity parity (2026-07-21)

The parity auditor now checks public tables, functions, indexes, and triggers,
not only the initial required-table list. The latest live result is clean for
all repository-declared objects: 46 tables, all local public functions, all
declared public indexes, and all declared public triggers are present. The
latest RevenueCat unknown-consumable fence and account-deletion write fence
migrations were applied before this result. The only remaining parity warning
is the incomplete remote migration ledger, which still needs a reviewed
baseline reconciliation.

The expanded audit then found and closed the final detected object mismatch:
`job_outbox.lease_token` was missing remotely. The canonical lease-fencing
migration was applied and the expanded audit now exits 0 with no missing local
tables, columns, functions, indexes, or triggers. The remote ledger warning is
now purely historical/procedural; current schema and integrity-object parity is
green.

### Anything else?

Yes. The object audit does not prove semantic parity for every constraint,
policy body, extension, Storage rule, or function implementation; those remain
part of the reviewed migration-baseline reconciliation. It also does not prove
real provider behavior, external deployment, or store-signing readiness.

The audit now additionally checks declared policies and extensions. The current
live result has no missing tables, columns, functions, indexes, triggers,
policies, or extensions. Semantic comparison of definitions remains the next
baseline-reconciliation step; names and presence alone are not proof of body,
type, default, or policy-expression equality.

Function-body comparison is now implemented in the parity auditor. It
normalizes SQL comments and whitespace, then compares each latest repository
function body with `pg_get_functiondef` from the live project. The current
report has zero mismatched function bodies, zero missing policies/extensions,
and zero missing object contracts. Column types/defaults, constraints, policy
expressions, and Storage semantics still require the reviewed baseline export.

## Addendum — named-constraint and policy-boundary verification (2026-07-21)

The read-only parity audit now also compares every explicitly named
`ALTER TABLE ... ADD CONSTRAINT` contract in the repository with
`pg_constraint` in the live project. The current report has zero missing named
constraints. This is a stronger Tier 1/2 integrity check, but it intentionally
does not pretend that regex extraction is a complete SQL parser for inline
`CREATE TABLE` constraints.

A direct live `pg_policies` query was also reviewed. The observed policies are:
the profile policy scopes reads to the JWT subject, and the four Storage
policies require the authenticated role plus ownership of the referenced
document in the `coverwise-documents` bucket. No public or anonymous Storage
policy was observed. This is Tier 3 security-boundary evidence; a full
authenticated/unauthenticated request matrix remains required before a
production auth approval.

The parity auditor remains green for tables, added columns, functions and
normalized function bodies, indexes, triggers, named constraints, policies,
and extensions. The only live parity warning is still migration-ledger
reconciliation: 9 remote history rows versus 44 repository migration files.

## Addendum — canonical test surfaces rerun (2026-07-21)

The repository-wide Flutter analyzer is clean. The canonical mobile package
suite (`mobile/`) passes **649 tests**. The preserved `temp_migration/new_mobile`
package now has its missing starter app restored and its smoke test passes; it
was a real package with a test importing a non-existent `lib/main.dart`, not a
reason to weaken the repository analyzer.

The backend suite passes **473 tests with 1 skipped** using `.venv/bin/python`.
The local simulator remains HTTP 200 on port 3200, and the current API remains
HTTP 200 on `/health` and `/healthz` on port 8007. These are local Tier 3/4
signals; they do not close external Cloud Run deployment, production provider
credentials, Android release signing, or real RevenueCat sandbox delivery.

## Addendum — local Supabase database and Auth boundary closure (2026-07-21)

The local Docker/Supabase stack was rechecked instead of relying on the older
unavailable-state note. The Postgres container restarted successfully and is
healthy on `127.0.0.1:54322`; the local Auth, REST, Storage, Realtime, metadata,
and Kong containers were also brought up and their health probes passed. The
local migration ledger now contains all **44** repository migrations, including
the three latest additive migrations that were previously pending.

A transactional SQL smoke check passed for Q&A reservation, finalization, and
unknown RevenueCat consumable fencing, with the transaction rolled back. A
separate local API acceptance check passed for synthetic account signup,
anonymous identity creation, guest-to-account claim, account profile read, and
synthetic-user cleanup. This is Tier 3/4 local evidence for the Auth/API
contract, not production provider or deployment evidence.

The current `.env` OpenAI credential returns HTTP 401 when the primary model is
called directly. The local API remains operational through its configured
fallback path, but a production launch still requires a valid provider
credential and an authenticated end-to-end model call before approval.

The canonical deployed-launch verifier was also run against the local API on
port 8008 with the local CORS origin and explicitly authorized synthetic
identity creation. Liveness, readiness, integrated health, unauthenticated
document rejection, two distinct anonymous identities, profile ownership,
owner-scoped document listing, and CORS all passed. This is Tier 3/4 local
boundary evidence; it is not a substitute for the same probe against a
deployed HTTPS environment.

The current production-config validator gives these exact failures from the
loaded environment: `PROCESSING_PAYLOAD_ENCRYPTION_KEY`,
`ANONYMOUS_AUTH_SIGNING_KEY`, `PUBLIC_SITE_URL`,
`REVENUECAT_WEBHOOK_AUTHORIZATION`, and `ALLOWED_ORIGINS` are missing; and
`DOCUMENT_REPOSITORY_BACKEND`, `DOCUMENT_OBJECT_STORE_BACKEND`,
`RAG_VECTOR_BACKEND`, and `BILLING_LEDGER_BACKEND` are not set to `supabase`.
No values were invented or copied into production configuration. Closure is to
provide reviewed deployment secrets and URLs, set the four backend selectors,
then rerun the validator and the deployed-launch verifier.

## Addendum — local schema diff and Supabase advisor hardening (2026-07-21)

The first local `supabase db diff --local` run found a real function-body drift:
the applied local `reserve_policy_upload_slot` lacked the
`upload_in_progress` guard present in the current repository and remote
function. An additive corrective migration,
`20260721220000_fix_policy_slot_pending_race.sql`, repaired the local and
remote definitions without rewriting the already-applied migration. The local
schema diff now reports **No schema changes found**.

The local Supabase advisor then identified mutable function search paths and a
per-row profile JWT policy evaluation. Two additive hardening migrations pin
the relevant server functions to `search_path=public`, use the init-plan-safe
`auth.uid()` profile predicate, and cover the revoked legacy retrieval
overload. The local advisor now reports only the two extension-placement
warnings for `vector` and `pg_trgm` at that point in the audit. The subsequent
extension-placement addendum below records the compatibility experiment and
the completed move into the private `extensions` schema.

The same hardening migrations were applied to the remote project and verified
through live `pg_proc`/`pg_policies` metadata. Current live parity remains
green for repository-declared objects, normalized function bodies, and
function search-path configuration. The
remote migration ledger now has 13 rows versus 48 repository migration files;
the history warning remains procedural and is not being hidden as schema
parity.

## Addendum — extension placement closure (2026-07-21)

The previously documented `vector` and `pg_trgm` advisor warnings were tested
transactionally before changing persistent state. Moving both extensions to
the existing `extensions` schema preserved vector distance operators,
trigram similarity, and the FTS RPC. The additive migration
`20260721250000_move_extensions_to_private_schema.sql` was then applied locally
and remotely. Local advisors now report **No issues found**, the local schema
diff remains clean, and live metadata confirms both extensions are in
`extensions` with retrieval functions using `search_path=extensions, public`.

The parity auditor now compares the latest per-function search-path setting,
including extension-qualified vector signatures. Remote object/function
parity remains green; the only remaining Supabase warning is the procedural
migration-ledger mismatch.

## Addendum — deployment authority check (2026-07-21)

The available deployment credentials were checked without mutating any cloud
resource. Railway and Fly CLI are installed but unauthenticated; `gcloud` is
not installed. Azure CLI has a cached account but management calls require
interactive reauthentication. AWS credentials are valid for identity and ECR
read access, but App Runner listing is denied by the current IAM policy. No
deployment was attempted against the older AWS path because the canonical
solo-launch decision is Railway + Supabase, not the superseded App Runner
deployment. Closure requires an authenticated Railway workspace (or an
explicitly approved alternate platform) plus the reviewed production runtime
secrets.

## Addendum — current verifier and remote schema correction (2026-07-21)

The default deployed-launch verifier is now non-mutating with respect to
identity creation. Its two-owner profile/list probe requires explicit
`--allow-identity-creation` authorization. The read-only remote schema probe
now returns exit code 0 with `model_run_results` present; older missing-table
and default-identity-creation statements above are historical. The current
remote object audit is green, while migration-ledger baseline reconciliation,
deployed worker execution, and real staging recovery remain open.

## Addendum — native DOCX capability closure (2026-07-21)

The canonical document service no longer sends `.docx` files through the
generic text fallback. `python-docx` now preserves paragraphs, headings,
tables/cells, and embedded-image relationships in the existing CIR/evidence
path. The versioned document evaluator now has eight executed cases, including
native DOCX, HTML, and EML structure, and all eight pass locally with the
project `.venv`.
PPTX, XLSX, HTML, email, scanned tables, semantic scanned forms, formulas,
handwriting, multilingual accuracy, and VLM image interpretation remain
explicit capability gates.

## Addendum — current remote contract parity correction (2026-07-21)

The live parity audit initially found three remote gaps: the latest
`process_revenuecat_webhook` body, the `get_qa_pack_balance` RPC, and the
latest `claim_anonymous_documents` body. The exact repository migrations were
applied through the reviewed transactional Management API path. A fresh audit
now reports zero missing or mismatched tables, columns, functions, function
bodies, indexes, triggers, policies, constraints, search paths, or extension
schemas. The remote migration-history baseline remains a separate warning
(16 generated rows versus 51 repository migrations).

## Addendum — semantic constraint and replay closure (2026-07-21)

The parity audit was strengthened to compare CHECK definitions, not only
constraint names. It found and closed stale `source_spans_span_type_check`
vocabulary through the exact `20260721160000_source_span_capability_types.sql`
migration. PostgreSQL-equivalent `IN`/`ANY(ARRAY[...])` rendering is
canonicalized; actual allowed-value differences remain failures. The current
remote audit is green, local shadow replay returns `No schema changes found`,
and the ledger warning is now 18 generated rows versus 52 repository files.

## Addendum — native HTML/EML capability closure (2026-07-21)

The canonical document service now preserves HTML headings, paragraphs,
tables/cells, and non-fetched image references, plus EML subject/body
structure and attachment hashes. The document evaluator now has eight
executable cases; HTML and EML are Tier 2 targeted evidence. PPTX/XLSX,
scanned tables/forms, formulas, handwriting, multilingual accuracy, and VLM
image interpretation remain explicit quality gates.
