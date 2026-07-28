# 🚀 CoverWise — Go-Live Deployment Checklist

**Date:** 2026-07-27
**App Version:** 0.1.2+11
**Build Target:** Solo production deployment
**Owner:** Pranay
**Engineering:** AI assistant

---

## How to use this checklist

- **👤 YOU** = items that require founder action, account ownership, or personal decision
- **🤖 ME** = items engineering/AI can do independently
- **👤+🤖** = items where we both need to act (you provide credentials, I do the technical work)
- Items are grouped by phase. Complete each phase before moving to the next.

---

## Phase 0: Pre-Flight Checks (do first)

These must be green before any deployment work begins. They validate the current state.

| # | Item | Who | Status | Notes |
|---|------|:---:|:------:|-------|
| 0.1 | Run and pass full Python test suite (669 tests) | 🤖 | ⬜ | `tools/run_backend_tests.sh tests/` |
| 0.2 | Run and pass full Flutter test suite (~1100 tests) | 🤖 | ⬜ | Last run had 72 failures — needs investigation first |
| 0.3 | `flutter analyze --no-fatal-infos` passes clean | 🤖 | ⬜ | |
| 0.4 | Ruff static check passes on `src/` and `tests/` | 🤖 | ⬜ | Currently at 23 findings |
| 0.5 | Verify CI workflow YAML is valid | 🤖 | ⬜ | `python3 -c "import yaml; yaml.safe_load(...)"` |

---

## Phase 1: Foundation & Accounts

### 1.1 Infrastructure Accounts

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 1.1.1 | **Deploy the backend** — choose a platform and provision | 👤+🤖 | ⬜ | Options: Railway ($5/mo minimum), Cloud Run (pay-per-use), or AWS App Runner. **Recommending Railway Hobby Plan** as the simplest solo option — accepts Docker, has private networking, $5/mo floor. I'll provision and configure; you need to create the account and add billing. |
| 1.1.2 | **Register a domain** (e.g. coverwise.app) | 👤 | ⬜ | ~$10-15/yr. I need the domain to configure `PUBLIC_SITE_URL`, `ALLOWED_HOSTS`, and SSL. |
| 1.1.3 | **Set DNS** pointing domain to deployment platform | 👤 | ⬜ | You control the DNS. I'll tell you what CNAME/records to create. |
| 1.1.4 | **DockerHub account** (free) — for CI image push | 👤+🤖 | ⬜ | Create an account at hub.docker.com. Share username + access token. I'll set as GitHub secrets. |
| 1.1.5 | **GitHub Actions secrets** — add DOCKERHUB_USERNAME, DOCKERHUB_TOKEN | 👤+🤖 | ⬜ | Go to repo Settings → Secrets and variables → Actions. I'll tell you exactly what to add. |

### 1.2 Third-Party Services

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 1.2.1 | **OpenAI API key** | 🤖 | ✅ **Done** | `sk-proj-...` set in `.env` |
| 1.2.2 | **Supabase project** | 🤖 | ✅ **Done** | `eyumuxwabmsymytjbxoj.supabase.co` — all 3 keys set |
| 1.2.3 | **Sentry account** — create project, get DSN | 👤+🤖 | ⬜ | Sign up at sentry.io (free tier). Create a project. Share the DSN so I can set `SENTRY_DSN` in `.env` and CI. The Sentry SDK is already wired in `main.dart` and `app_config.dart`. |
| 1.2.4 | **RevenueCat account** — create project, configure webhooks | 👤 | ⬜ | Sign up at revenuecat.com (free tier until $2.5k MRR). This is needed for in-app purchases/subscriptions. Local billing contracts are done (30+ tests). |
| 1.2.5 | **Qdrant cloud** (optional — Supabase pgvector is the primary) | 👤+🤖 | ⬜ | Currently configured for local Qdrant. Production uses Supabase pgvector via `RAG_VECTOR_BACKEND=supabase`. Skip unless you want a dedicated vector DB. |

---

## Phase 2: Infrastructure & CI

### 2.1 Deployment

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 2.1.1 | **Provision deployment platform** (Railway/Cloud Run/etc.) | 👤+🤖 | ⬜ | You create the account + add billing. I'll configure the service, environment variables, health checks, and private networking. |
| 2.1.2 | **Configure production environment variables** on platform | 🤖 | ⬜ | Set all `.env` values on the deployed service. Must NOT set `OPENAI_API_KEY` in logs or UI. |
| 2.1.3 | **Set production ALLOWED_HOSTS** | 👤+🤖 | ⬜ | Currently `127.0.0.1,localhost`. You tell me the production domain, I update it. `TrustedHostMiddleware` is already wired. |
| 2.1.4 | **Set production ALLOWED_ORIGINS** | 👤+🤖 | ⬜ | CORS origin list for the web frontend. I configure once you share the URL. |
| 2.1.5 | **Set PUBLIC_SITE_URL** | 👤+🤖 | ⬜ | Must be the final HTTPS origin. I update once domain/deploy URL is known. |
| 2.1.6 | **Verify health endpoints** on deployed backend | 🤖 | ⬜ | `/healthz`, `/readyz`, `/health` — 23 production health tests already written. I'll run them against the live URL. |

### 2.2 CI/CD Pipeline

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 2.2.1 | **Add DOCKERHUB secrets** to GitHub | 👤+🤖 | ⬜ | You create them in repo Settings → Secrets. |
| 2.2.2 | **Verify GitHub Actions CI passes** on push | 🤖 | ⬜ | Already pushed to `main`. Need to check the Actions tab for results. |
| 2.2.3 | **Verify Cosign container signing** in CI | 🤖 | ⬜ | Wired in CI — signs Docker images on `main` push. |
| 2.2.4 | **Add CODECOV_TOKEN** or confirm fail_ci_if_error:false | 👤+🤖 | ⬜ | Currently `fail_ci_if_error: false` — works without token. Optionally create Codecov account for coverage dashboard. |

### 2.3 Monitoring & Observability

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 2.3.1 | **Set SENTRY_DSN** in production environment | 👤+🤖 | ⬜ | SDK wired in `main.dart` + `app_config.dart`. You share the DSN, I configure it. |
| 2.3.2 | **Verify Sentry crash delivery** | 👤+🤖 | ⬜ | Test with a deliberate throw in non-production. Tests already written (`test_production_e2e.py`). |
| 2.3.3 | **Add uptime monitoring** | 👤 | ⬜ | Free options: UptimeRobot, BetterUptime. Monitor `/healthz` endpoint. |

---

## Phase 3: Mobile App Distribution

### 3.1 Android

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 3.1.1 | **Generate Android release keystore** | 👤+🤖 | ⬜ | I'll give you the exact `keytool` command to run. You run it once and send me the keystore file and credentials. **Keep this safe forever** — losing it means you can't update the app. |
| 3.1.2 | **Create `key.properties`** | 👤+🤖 | ⬜ | I'll create the file with the values from step 3.1.1. `.gitignore` already excludes it. |
| 3.1.3 | **Add CI secrets** (KEYSTORE_BASE64 + KEY_PROPERTIES) | 👤+🤖 | ⬜ | I'll provide the exact secrets to create. Build.gradle.kts already has the signing config wired. |
| 3.1.4 | **Build signed AAB** | 🤖 | ⬜ | `flutter build appbundle --release` — needs keystore from 3.1.1 |
| 3.1.5 | **Create Google Play Developer account** | 👤 | ⬜ | **$25 one-time fee.** Visit play.google.com/console — need to register as a developer. |
| 3.1.6 | **Create Play Store listing** — app description, screenshots, category | 👤+🤖 | ⬜ | I can draft the store copy and screenshots. You create the listing in Play Console and upload the AAB. |
| 3.1.7 | **Configure Google Play App Signing** | 👤 | ⬜ | Opt in during Play Console setup. This lets Google manage the signing key if your upload key is ever compromised. |
| 3.1.8 | **Complete Data Safety section** and target API requirements | 👤+🤖 | ⬜ | App targets API 36 (Android 16). Need to accurately declare data collection/sharing practices. App handles health insurance documents — triggers health-app disclosures. |
| 3.1.9 | **Submit for internal testing track** | 👤 | ⬜ | Upload signed AAB to Internal Testing track. Google reviews within hours for the first time. |

### 3.2 iOS

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 3.2.1 | **Enroll in Apple Developer Program** | 👤 | ⬜ | **$99/year.** Required for any iOS distribution. |
| 3.2.2 | **Generate distribution certificate + provisioning profile** | 🤖 | ⬜ | After you enroll, I can help generate certificates through Xcode or Fastlane. |
| 3.2.3 | **Create App Store Connect listing** | 👤 | ⬜ | App ID: `com.coverwise.app` |
| 3.2.4 | **Build signed IPA** | 🤖 | ⬜ | `flutter build ipa` or `flutter build ios --release` + Xcode archive |
| 3.2.5 | **Submit to TestFlight** | 👤+🤖 | ⬜ | I can set up Fastlane for iOS deployment. You upload to TestFlight for beta testing. |

---

## Phase 4: Legal & Compliance

| # | Item | Who | Status | Details |
|---|------|:---:|:------:|---------|
| 4.1 | **Review and approve Privacy Policy wording** | 👤 | ⬜ | Current draft at `docs/legal/privacy_policy.md`. Must resolve the `[Jurisdiction]` placeholder. CoverWise is not an insurer/broker/TPA — the policy must reflect that. |
| 4.2 | **Review and approve Terms of Service wording** | 👤 | ⬜ | Current draft at `docs/legal/terms_of_service.md`. Must resolve `[Jurisdiction]` and any founder-approval wording. The "information broker" contradiction was fixed — verify the final text. |
| 4.3 | **Set jurisdiction** (India) | 👤 | ✅ **As requested** | You confirmed jurisdiction as India. I can update both documents. |
| 4.4 | **Set support email** (support@coverwise.app) | 👤+🤖 | ⬜ | You need to create the mailbox or tell me which email to use. |
| 4.5 | **Host legal pages** at `/privacy` and `/terms` | 🤖 | ⬜ | Backend routes already exist. Once deployed, they serve the approved docs with SHA-256 headers. Need domain + deployment (Phase 2) first. |
| 4.6 | **Verify hosted legal pages** against canonical source | 🤖 | ⬜ | `tools/verify_hosted_legal_documents.py` already written. I'll run it against the live URL. |
| 4.7 | **Add consent mechanism** for document processing | 🤖 | ✅ **Done** | ConsentLedger is implemented with 37 passing tests. |
| 4.8 | **Complete Data Rights operations** — deletion, export | 👤+🤖 | ⬜ | Template exists at `docs/review/SUPPORT_AND_DATA_RIGHTS_OPERATIONS_ATTESTATION_TEMPLATE.md`. You need to execute and document the process. |
| 4.9 | **Retention policy alignment** — analytics set to 30 days | 🤖 | ✅ **Done** | Retention fallback corrected to 30 days. |

---

## Phase 5: Configuration & Environment

### 5.1 Production Environment Variables

| # | Variable | Who | Status | Notes |
|---|----------|:---:|:------:|-------|
| 5.1.1 | `OPENAI_API_KEY` | ✅ Done | Set in `.env` | |
| 5.1.2 | `SUPABASE_URL` | ✅ Done | `https://eyumuxwabmsymytjbxoj.supabase.co` | |
| 5.1.3 | `SUPABASE_PUBLISHABLE_KEY` | ✅ Done | `sb_publishable_...` | |
| 5.1.4 | `SUPABASE_SECRET_KEY` | ✅ Done | `sb_secret_...` | |
| 5.1.5 | `ENVIRONMENT=production` | 👤+🤖 | ⬜ | Must be set as "production" to enable production-only checks |
| 5.1.6 | `ALLOWED_HOSTS` | 👤+🤖 | ⬜ | Currently `127.0.0.1,localhost`. Update to real domain. |
| 5.1.7 | `ALLOWED_ORIGINS` | 👤+🤖 | ⬜ | Currently `https://example.com`. Update to real origin. |
| 5.1.8 | `PUBLIC_SITE_URL` | 👤+🤖 | ⬜ | Currently `https://example.com`. Update to real URL. |
| 5.1.9 | `SENTRY_DSN` | 👤+🤖 | ⬜ | Need Sentry account (1.2.3) |
| 5.1.10 | `COVERWISE_PRIVACY_POLICY_URL` | 👤+🤖 | ⬜ | Full HTTPS URL once hosted |
| 5.1.11 | `COVERWISE_TERMS_OF_SERVICE_URL` | 👤+🤖 | ⬜ | Full HTTPS URL once hosted |
| 5.1.12 | `ANONYMOUS_AUTH_SIGNING_KEY` | 🤖 | ⬜ | Currently a shell command — generate a real 64-char hex key |
| 5.1.13 | `REVENUECAT_WEBHOOK_AUTHORIZATION` | 👤+🤖 | ⬜ | Set after RevenueCat account created |

### 5.2 GitHub Actions Secrets

| # | Secret | Who | Status | Notes |
|---|--------|:---:|:------:|-------|
| 5.2.1 | `DOCKERHUB_USERNAME` | 👤 | ⬜ | DockerHub account username |
| 5.2.2 | `DOCKERHUB_TOKEN` | 👤 | ⬜ | DockerHub access token (not password) |
| 5.2.3 | `KEYSTORE_BASE64` | 👤+🤖 | ⬜ | After keystore generated — base64-encoded .jks file |
| 5.2.4 | `KEY_PROPERTIES` | 👤+🤖 | ⬜ | After keystore generated — content of key.properties |

---

## Phase 6: Testing & Validation

| # | Item | Who | Status | Notes |
|---|------|:---:|:------:|---------|
| 6.1 | **Run full Python suite** (669 tests) | 🤖 | ⬜ | Currently passing. Re-run after any deployment changes. |
| 6.2 | **Fix Flutter test failures** (currently 72 failing) | 🤖 | ⬜ | Needs investigation. ~37 were pre-existing, ~35 are new. |
| 6.3 | **Run production E2E tests** against deployed backend | 🤖 | ⬜ | `tests/test_production_e2e.py` — needs `COVERWISE_INTEGRATION_BASE_URL` |
| 6.4 | **Run tenant isolation verifier** against deployed backend | 🤖 | ⬜ | `tools/verify_deployed_identity_claim.py` — needs production URL |
| 6.5 | **Run hosted legal pages verifier** | 🤖 | ⬜ | `tools/verify_hosted_legal_documents.py` — needs production URL |
| 6.6 | **Test Sentry crash delivery** | 🤖 | ⬜ | Deliberate throw, verify event arrives in Sentry dashboard |
| 6.7 | **Real-device smoke test** — upload, Q&A, family, claims | 👤 | ⬜ | Test on a real device (not simulator) |
| 6.8 | **Verify account deletion flow** | 🤖 | ⬜ | Test in-app account deletion + data erasure |

---

## Phase 7: Launch

| # | Item | Who | Status | Notes |
|---|------|:---:|:------:|---------|
| 7.1 | **Final legal document sign-off** | 👤 | ⬜ | You approve the exact text of Privacy Policy and Terms of Service |
| 7.2 | **Final domain configured** | 👤+🤖 | ⬜ | DNS propagated, HTTPS working |
| 7.3 | **Set production ENVIRONMENT flag** | 👤+🤖 | ⬜ | Enables production-only guards |
| 7.4 | **Deploy backend to production** | 🤖 | ⬜ | Docker push → platform deploys |
| 7.5 | **Verify health endpoints on production** | 🤖 | ⬜ | Run production health test suite |
| 7.6 | **Upload signed Android AAB** to Google Play Internal Testing | 👤 | ⬜ | AAB built in Phase 3 |
| 7.7 | **Upload signed iOS IPA** to TestFlight | 👤+🤖 | ⬜ | IPA built in Phase 3 |
| 7.8 | **Monitor first 24 hours** — Sentry errors, uptime, logs | 👤+🤖 | ⬜ | Set alerts. Watch for issues. |
| 7.9 | **Document launch in CHANGELOG** | 🤖 | ⬜ | Write release notes |
| 7.10 | **Celebrate!** 🎉 | 👤 | ⬜ | You earned it! |

---

## Summary: What's actionable RIGHT NOW

| Item | Who | Est. time | Priority |
|------|:---:|:---------:|:--------:|
| Fix Flutter test failures (72 → 0) | 🤖 | 1-2 hours | 🔴 HIGH |
| Generate Android keystore + CI signing | 👤+🤖 | 30 min (you) + 30 min (me) | 🔴 HIGH |
| Create DockerHub account + share token | 👤 | 10 min | 🔴 HIGH |
| Set GitHub secrets (DOCKERHUB, keystore) | 👤 | 10 min | 🔴 HIGH |
| Choose deployment platform + create account | 👤 | 30 min | 🔴 HIGH |
| Create Sentry account + share DSN | 👤 | 10 min | 🟡 MEDIUM |
| Review/approve legal docs (resolve [Jurisdiction]) | 👤 | 30 min | 🟡 MEDIUM |
| Enroll in Apple Developer Program ($99/yr) | 👤 | 30 min | 🟡 MEDIUM |
| Create Google Play Developer account ($25) | 👤 | 30 min | 🟡 MEDIUM |
| Register domain (coverwise.app) | 👤 | 15 min | 🟡 MEDIUM |
| Create RevenueCat account | 👤 | 30 min | 🟢 LOW |
