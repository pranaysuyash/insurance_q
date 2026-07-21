# Launch execution status — 2026-07-21

This is an execution record. Launch claims below are based on commands, current code, and local runtime behavior, not on planning documents.

## Current decision

CoverWise is not launch-ready yet. The local API path, local Supabase schema, Supabase-backed API startup, launch-critical mobile surface, and Android compile path are verified. Production configuration, real external credentials, production Supabase linkage, and distribution remain open.

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

## Evidence captured from code/runtime

| Check | Result | Evidence tier |
|---|---|---|
| `flutter analyze` | No issues found | Tier 1 |
| Analytics consent gate tests | 5 passed | Tier 2 |
| Dashboard tests | 16 passed | Tier 2 |
| Complete Flutter test suite | 573 passed | Tier 2 |
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
| Android release build | `build/app/outputs/bundle/release/app-release.aab` built successfully (77.8 MB) with placeholder defines; staging compile proof only | Tier 2 |
| Local Supabase stack | Docker Desktop running; local Postgres 17.6 and Supabase services healthy | Tier 4 |
| Local Supabase migration reset | All 13 normalized migrations applied successfully from a fresh local database | Tier 3 |
| Local Supabase schema lint | No schema errors found | Tier 2 |
| Local Supabase RLS/grants | Core tables have RLS; operator views deny anon/authenticated and allow service-role; document tables allow service-role repository operations | Tier 3 |
| Supabase-backed API on port 8001 | App startup, `/healthz`, and `/readyz` passed with local Supabase runtime values | Tier 3 |
| Supabase runtime config validator | Passed with local stack values supplied only to the process environment | Tier 2 |
| Remote Supabase Auth endpoint | `/auth/v1/settings` returned 200 with the publishable key | Tier 3 |
| Remote secret-key Python client | Read-only `documents` query succeeded with the provided server secret | Tier 3 |
| Remote-configured API on port 8002 | App startup, `/healthz`, and `/readyz` passed with remote Supabase values | Tier 3 |
| Remote-configured iOS simulator | Supabase initialization completed; anonymous-provider-disabled startup is handled by local-principal fallback | Tier 4 |
| Local identity-link tests | Guest-to-account link retry is idempotent; rebinding to another account is rejected | Tier 2 |
| Remote identity/analytics schema probe | Remote `identity_aliases` and `analytics_events` are available and queryable with the server key | Tier 3 |
| Remote migration application | Supabase Management API previously accepted the 25 normalized migrations; the new billing-ledger migration is not applied because the temporary management credential now returns HTTP 403 | Tier 3 mixed |
| Current full backend pytest suite | 336 passed, 4 skipped; the prior failures were repaired in the OpenAI verification harness, citation test contract, doctr image input shape, deletion repository injection path, subscription webhook coverage, billing-ledger coverage, analytics identity/retention coverage, runtime configuration coverage, and current parallel-work regressions | Tier 2 |
| Current Flutter analyzer | No issues found with `flutter analyze --no-fatal-infos` | Tier 1 |
| Current remote-configured API on port 8002 | Latest code running in development/staging mode; `/readyz` returned 200 and a real anonymous profile round-trip preserved the same owner UID | Tier 3 |
| RevenueCat webhook tests | Authorization, duplicate delivery idempotency, initial purchase, and expiration precedence pass | Tier 2 |
| Native runtime probe | Homebrew native libraries and WeasyPrint import pass; doctr predictor initializes successfully from the project venv | Tier 2 |
| Billing-ledger migration validation | New PostgreSQL ledger migration parsed and its purchase, duplicate, stale-event, and expiration behavior passed in an isolated local PostgreSQL database; hosted application remains pending | Tier 3 local |
| Latest staging API on port 8002 | Started with current billing fail-closed code; `/readyz` 200, anonymous creation 200, subscription status/webhook return 503 until hosted billing tables exist | Tier 3 |

## Remaining blockers and closure paths

1. Production environment is incomplete. The remote URL, publishable key, and modern secret key are now present in ignored local env storage, but the remote project has anonymous sign-ins disabled and still needs the approved production anonymous-auth strategy/signing key, public site URL, allowed origins, backend settings, and RevenueCat webhook authorization; rerun `tools/validate_production_config.py`.
2. The local OpenAI key currently receives 401 invalid-key responses. Replace it with a valid production credential or explicitly configure the intended production fallback, then rerun real extraction and question-answer flows.
3. Production Supabase schema linkage is now applied through the Management API. Authenticated cross-owner isolation and guest-claim tests still need to be run against a real staging account pair.
4. The Android bundle now compiles, but it used placeholder release defines. Rebuild with real production values and verify install/startup plus authenticated flows before distribution.
5. The full backend suite is now green at 336 passed and 4 skipped. The skipped async verification scripts still need an async pytest plugin or an explicit separate execution command before those scripts can count as broad integration proof.
6. External distribution/deployment was not performed. No deployment destination or production credentials were available, and no commit or push was authorized.
7. The identity-link and analytics tables are now remotely queryable. The new Supabase entitlement/webhook ledger is implemented and locally verified, but the hosted migration was blocked by HTTP 403 from the temporary management credential; the API therefore fails closed for subscription operations until that migration is applied.

## Artifact and workspace state

All work remains uncommitted. Existing parallel changes were preserved. `insurance_app.db` changed during local backend startup and remains for review; it was not reverted or deleted.

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
