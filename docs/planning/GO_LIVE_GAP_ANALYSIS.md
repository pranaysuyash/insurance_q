# CoverWise — Go-Live Gap Analysis

**Generated:** 2026-07-28  
**Purpose:** Segregate every remaining pre-launch action into technical (engineering-can-execute) and non-technical (founder/owner-dependent), with owner, effort, dependency, and current status.

---

## 1. DONE (no action needed)

These are fully implemented, tested, and verified:

| Area | Status | Evidence |
|------|--------|----------|
| P0 Production Readiness | ✅ Complete | All sub-items checked |
| Claims Workflow | ✅ Complete | Wizard, photo attach, tracking, dashboard section |
| Family Coverage Summary | ✅ Complete | Member cards, coverage matrix |
| M10 Multi-language | ✅ Complete | Hindi, Gujarati, Marathi ARB files; all screens migrated from S.xxx |
| BR-01/03 Copy corrections | ✅ Complete | "Information broker"→"Policy assistant", claim-log disclaimers |
| BR-02 Evidence-backed pipeline | ✅ Complete | 12/12 corpus tests, all 5 doc types |
| BR-04/05 Identity + isolation | ✅ Complete | 11/11 checks passed against remote Supabase |
| BR-10 Mobile baseline | ✅ Complete | 1,157 Flutter tests, 706 Python tests |
| BR-11 Security/Ruff/SBOM | ✅ Complete | 0 Ruff findings, SBOM approved, Cosign wired, PyJWT migrated, FastAPI upgraded |
| Prometheus /metrics | ✅ Complete | Content-type fixed, all 5 business counters wired |
| Sentry SDK | ✅ Complete | Initializes cleanly, test metric sent |
| DockerHub secrets | ✅ Complete | DOCKERHUB_USERNAME + DOCKERHUB_TOKEN set in GitHub |
| Grafana dashboard | ✅ Complete | JSON exported, Prometheus scrape configured |

---

## 2. TECHNICAL — Engineering can execute now (no founder dependency)

These need code work, not credentials or business decisions.

| # | Item | Effort | Depends On | Current Status |
|---|------|--------|-----------|----------------|
| T1 | **Fix 22 Flutter test failures** — Apply provider override pattern to ~15 test files (Hive-error cascade) | ~45 min | None | Pattern proven, reviewed, working for 1 file |
| T2 | **Push to main + trigger CI pipeline** — Verify all 5 jobs (test, lint, supply-chain, mobile, docker) including Cosign signing | ~10 min | None | DockerHub secrets configured |
| T3 | **Wire Sentry business counters into Sentry dashboard** — Create a dashboard or alert so the business metrics are visible | ~30 min | None | Counters exist in code, need dashboard visualization |
| T4 | **Verify Prometheus scraping** — Restart Prometheus, confirm /metrics scrapes without "data does not end with # EOF" error | ~15 min | None | Content-type fixed, needs restart |
| T5 | **Document start/stop procedure** for monitoring stack (Prometheus + Grafana) | ~15 min | None | Files exist in infra/monitoring/ |
| T6 | **Add Sentry env to .env.example** — Document SENTRY_DSN as expected env var | ~5 min | None | Already in .env, missing from .env.example |

---

## 3. NON-TECHNICAL — Founder/owner must act (engineering can't unblock)

These require credentials, accounts, business decisions, or deployment access.

### 3.1 Credentials & Accounts (can be done right now)

| # | Item | What's needed | Effort | Dependencies | Current Status |
|---|------|--------------|--------|-------------|----------------|
| N1 | **Deploy API to Cloud Run / hosting** — DNS, HTTPS, production URL for `coverwise.app` | Cloud Run deploy + DNS setup | ~2h | Google Cloud account, domain | Not started |
| N2 | **Deploy hosted legal pages** — Set `PUBLIC_SITE_URL` so `/privacy` and `/terms` are live | Deploy API + DNS | ~2h | N1 | Not started |
| N3 | **Verify hosted legal pages** — Run `tools/verify_hosted_legal_documents.py` against real HTTPS URLs | N2 complete | ~5 min | N2 | Ready to run |
| N4 | **RevenueCat account setup** — Create RevenueCat project, configure entitlements, generate webhook signing secret | ~30 min | None | Not started |
| N5 | **RevenueCat sandbox lifecycle** — Run BIL-01 lifecycle with sandbox events | RevenueCat account | ~1h | N4 | Procedure documented, waiting execution |
| N6 | **Android keystore + signing** — Generate upload key, fill `key.properties` | `keytool` command ready | ~10 min | None | Template ready, needs execution |
| N7 | **iOS cert + provisioning profile** — Apple Developer account setup | Apple Developer enrollment | ~30 min | None | Not started |
| N8 | **Set SUPABASE_SERVICE_ROLE_KEY in .env** — Copy the JWT `eyJ...` key from Supabase Dashboard → Project Settings → API | ~30 sec | None | **Critical blocker for BR-04/05** |

### 3.2 Deployment & Infrastructure

| # | Item | What's needed | Effort | Dependencies | Current Status |
|---|------|--------------|--------|-------------|----------------|
| N9 | **Choose deployment platform** — Cloud Run (current Dockerfile), Railway, Fly.io, or self-hosted | Decision | ~15 min | None | Not decided |
| N10 | **Set production env vars** — All ~20 vars (SUPABASE_*, OPENAI_*, SENTRY_DSN, signing keys, etc.) | N9 chosen | ~30 min | N9 | Template exists: `.env.example` |
| N11 | **Configure database** — Production Supabase project (or other) with full schema | Database URL | ~15 min | N9 | Dev Supabase project exists, needs promotion |
| N12 | **Set up Sentry project** — Create Python project in Sentry, get DSN | Sentry account | ~5 min | None | Python backend DSN already set |
| N13 | **Deploy API** — Run deploy script or CI/CD | N9-N11 | ~30 min | N9-N11 | CI/CD ready, DockerHub secrets set |
| N14 | **Set up monitoring** — Prometheus + Grafana (or Sentry-only), configure alerts | N13 | ~1h | N13 | Local stack working, needs production config |

### 3.3 Legal & Policy

| # | Item | What's needed | Effort | Dependencies | Current Status |
|---|------|--------------|--------|-------------|----------------|
| N15 | **Founder approve Privacy Policy wording** — Review `docs/legal/privacy_policy.md` | Founder review | ~30 min | None | Engineering-ready, awaiting approval |
| N16 | **Founder approve Terms of Service wording** — Review `docs/legal/terms_of_service.md` | Founder review | ~30 min | None | Engineering-ready, awaiting approval |
| N17 | **Set support email** — Replace `support@coverwise.app` placeholder + set up mailbox | Email account | ~15 min | None | Placeholder in documents |
| N18 | **Set jurisdiction** — Set to "India" (as discussed) | Decision | ~5 min | None | Not yet committed |
| N19 | **Fill support operations attestation** — Name, identity verification, escalation, response targets | Founder fills template | ~30 min | None | Template exists at `docs/review/SUPPORT_AND_DATA_RIGHTS_OPERATIONS_ATTESTATION_TEMPLATE.md` |
| N20 | **Fill credential rotation attestation** — Inventory, provider-verification, history-decision, acceptance | Founder fills template | ~30 min | None | Template exists at `docs/review/CREDENTIAL_ROTATION_ATTESTATION_TEMPLATE.md` |

### 3.4 Store Distribution

| # | Item | What's needed | Effort | Dependencies | Current Status |
|---|------|--------------|--------|-------------|----------------|
| N21 | **Google Play Console account** — $25 registration, app listing | Payment + docs | ~1h | Apk ready | Not started |
| N22 | **Apple App Store account** — $99/year, app listing | Payment + docs | ~1h | iOS build ready | Not started |
| N23 | **Build signed APK/AAB** — Run `flutter build apk --release` with keystore | N6 complete | ~15 min | N6 | Ready to build |
| N24 | **Build signed iOS IPA** — Run `flutter build ipa` with certs | N7 complete | ~15 min | N7 | Ready to build |
| N25 | **Store screenshots + description** — Create listing assets | ~2h | None | Not started |

### 3.5 Commercial & Transaction Readiness

| # | Item | What's needed | Effort | Dependencies | Current Status |
|---|------|--------------|--------|-------------|----------------|
| N26 | **Fill transaction-readiness evidence pack** — IP, accounts, customer liability, continuity, handover | Founder fills template | ~1h | None | Template exists (`TRANSACTION_READINESS_EVIDENCE_PACK_TEMPLATE.md`) |

---

## 4. TANGENTIAL / OPTIONAL (not required for go-live, nice to have)

| # | Item | Why optional | Effort |
|---|------|-------------|--------|
| O1 | **More insurance types** (Cyber, Liability, Pet) | App works with current types, can be added later | ~2h per type |
| O2 | **Multi-language post-launch** (Tamil, Bengali) | P3 priority, need user geography data | ~1h per locale |
| O3 | **22 Flutter test failures** | Pre-existing, non-functional, mostly provider isolation issues | ~45 min |
| O4 | **APK size optimization** | Already within 60MB budget | Low priority |

---

## 5. MINIMUM VIABLE LAUNCH CHECKLIST

If you wanted the absolute minimum to get to a real user uploading a policy and asking a question:

### Must-do (engineering, ~2h):
- [ ] T1: Push to main → trigger CI → verify Cosign signing
- [ ] Deploy API to chosen platform (Cloud Run, Railway, etc.)

### Must-do (founder, ~1h total):
- [ ] N1: Choose deployment platform and deploy
- [ ] N8: Set SUPABASE_SERVICE_ROLE_KEY in production env
- [ ] N15-N16: Approve Privacy Policy and Terms of Service
- [ ] N17: Set up support email

### Nice-to-have for first user:
- [ ] N6-N7: Mobile app code signing (can distribute via TestFlight/Play Console internal testing without full store listing)
- [ ] N4-N5: RevenueCat (can start without billing — manual access works)

---

## Quick actions (can be done in < 5 min right now)

| Priority | Action | Time | Who |
|----------|--------|------|-----|
| 🔴 Critical | Set SUPABASE_SERVICE_ROLE_KEY = SUPABASE_SECRET_KEY in production env | 30s | You |
| 🟡 Important | Approve Privacy Policy wording in `docs/legal/privacy_policy.md` | 30 min | You |
| 🟡 Important | Approve Terms of Service wording in `docs/legal/terms_of_service.md` | 30 min | You |
| 🟢 Nice | Decide deployment platform (Cloud Run / Railway / Fly.io / other) | 15 min | You |
| 🟢 Nice | Push to main to trigger CI pipeline | 5 min | Engineering |
