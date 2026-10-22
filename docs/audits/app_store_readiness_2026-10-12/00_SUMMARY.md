# CoverWise — App Store / Play Launch Readiness Audit (2026-10-12 → 14)

**Verdict: NOT READY for submission.** 9 orchestrator-verified blockers below; ~40 HIGH findings across lane reports.

## How this audit was run

| Lane | Report | Model | Method |
|------|--------|-------|--------|
| 01 Store compliance & build config | `01_store_compliance.md` | Claude Haiku | static |
| 02a–d UI/UX/a11y/copy (42 screens + widgets) | `02a`–`02d_ui_ux_screens.md` | Claude Haiku ×4 (swarm) | static |
| 03 End-to-end user flows | `03_user_flows.md` | Codex gpt-6-luna xhigh | static, client↔backend route tracing |
| 04 Bugs / analysis / tests | `04_bugs_tests.md` | Codex gpt-6-luna xhigh | static (tests blocked in sandbox — see §4) |
| 05 Backend / security / privacy / data inventory | `05_backend_security_privacy.md` | Codex gpt-6-luna xhigh | static |

First Haiku attempt (5 lanes) died on a session rate limit; all lanes were re-run. Raw Codex logs: `_codex_logs/`.

**Evidence tier:** Tier 1 (static inspection) for all findings. Items in §1 were re-read in source by the orchestrator (still Tier 1, independently confirmed). No device, simulator, StoreKit sandbox, or hosted-service proof. Lane findings not listed in §1 are agent claims — verify before acting.

## 1. Verified launch blockers (fix before submission)

| # | ID | Area | Issue | Evidence |
|---|----|------|-------|----------|
| 1 | SEC-02 | Security | Live-looking Supabase DB password committed in a git-tracked doc | `docs/context/PROJECT_CONFIG.md:83` (tracked; last touched `45d30aa`). **Rotate now**, then scrub file + history (history rewrite needs owner approval). |
| 2 | SEC-01 | Security | Public `POST /delete-account-request` queues deletion of any account by email alone — no email proof, no rate limit | `src/api/user.py:470-520` |
| 3 | FLOW-12 | Billing | Q&A pack purchases: webhook maps pack SKUs to `free` and returns `unsupported_product`; no credit grant path → users pay, get nothing | `src/api/subscription.py:295-302, 378-385` |
| 4 | STORE-01 | Apple 4.8 | Google sign-in offered on iOS with no Sign in with Apple | `mobile/lib/screens/account_screen.dart:112,231` |
| 5 | STORE-02 / UX-C-01 | Apple 3.1.1/3.1.2 | Paywall: no Restore Purchases (fn exists, zero callers), no auto-renew disclosure, no privacy/terms links | `billing_adapter.dart:328`; `upgrade_screen.dart` |
| 6 | STORE-03 | Apple privacy | No app-level `PrivacyInfo.xcprivacy` in `ios/Runner` (only in Pods) | `mobile/ios/Runner/` |
| 7 | UX-D-01 | Legal / Apple 1.4-ish | AI answers have no "not insurance advice" disclaimer anywhere | `qa_screen.dart`, `app_en.arb` |
| 8 | UX-B-01 | Safety | Emergency hotline lookup uses bidirectional substring alias match → "HDFC Life", "ICICI Prudential", "Star Union Dai-ichi" get a *general* insurer's hotline; short queries match anything | `mobile/lib/data/insurer_directory.dart:121-134` |
| 9 | UX-A-01 | Core wedge | Coverage-gaps route (dashboard/Insights/More) built without citations → always "no information" | `app_router.dart:83` vs working path `policy_detail_screen.dart:1597` |

**Owner-verification blocker:** UX-B-02 — every insurer hotline/claims email in `insurer_directory.dart` is unsourced yet labelled "Verified". Must be checked against official insurer sites.

## 2. Verified HIGH issues (orchestrator-confirmed)

- `/plans` route unregistered → "Page not found" from export-gate Upgrade (`coverage_details_summary_screen.dart:503`).
- Restore-document always shows success even on failure (`documents_list.dart:765-777`).
- ToS consent recorded with the privacy-policy version (`onboarding_screen.dart:143-146`).
- `PRIVACY_POLICY_URL`, `TERMS_OF_SERVICE_URL`, `SUPPORT_EMAIL` default to empty with no release gate (`app_config.dart:105-111`).
- Unbacked "Save up to 44%" claim (`upgrade_screen.dart:298`).

## 3. Unverified HIGH themes from lanes (triage next)

- **Store:** Android release falls back to debug keystore unless `COVERWISE_RELEASE_BUILD=true` (STORE-04); no web account-deletion URL for Play (STORE-06); privacy policy omits RevenueCat/Google OAuth/Sentry (STORE-07); no iOS release script/DEVELOPMENT_TEAM.
- **Backend:** deletion misses linked tables (SEC-03); export incomplete (SEC-04); legacy Q&A route bypasses server entitlement (SEC-05); worker never runs prod-config validation (SEC-06).
- **Flows:** Supabase init skipped while principal resolution still uses it (FLOW-01); no doc-processing consent withdrawal (FLOW-09); iOS notification permission uses Android-only API (FLOW-08); family sync field/delete mismatches and pull never wired (FLOW-05/06); QA treats 401 as normal response (FLOW-04).
- **Bugs:** policy fields / OCR text in release + backend logs (BUG-01); claim photos deleted on sheet dismiss (BUG-02); family save delete-then-add data loss (BUG-04 / UX-B).
- **UX:** raw exception text shown on ~4 screens; dead/no-op buttons (dashboard coverage summary, claims prep guide, claim refresh); negative "days remaining"; internal IDs + "Security Phase 3" tooltip visible; PDF password reused across uploads; ~150+ hardcoded strings while 5 locales are offered; consent/legal copy English-only; account deletion not linked from Settings; raw backend URL shown in Settings; Google-search handoff of insurer name.

## 4. Test / analysis status

- `flutter analyze` / `flutter test`: Codex sandbox could not write Flutter SDK cache — not run in lane. Orchestrator re-run 2026-10-14 (`_codex_logs/flutter_run_2026-10-14.log`): **`flutter analyze` — No issues found (exit 0); `flutter test` — 1390 passed, 0 failed (exit 0).** Note: green tests did not catch any §1 blocker — coverage gap, not readiness proof.
- Backend `pytest`: **cannot run** — `./venv` documented in AGENTS.md does not exist. Creating it requires package install (owner approval).

## 5. Owner decisions required

1. Rotate the DB password (now) and approve git-history scrub.
2. Sign in with Apple vs. removing Google sign-in on iOS.
3. Disclaimer wording (AI answers, emergency, coverage) — legal review.
4. Verify every insurer hotline/email with source + date.
5. Approve creating backend venv to run pytest.
6. Encryption-export answer (`ITSAppUsesNonExemptEncryption`), hosted legal URLs, support email, web deletion page.

## 6. Recommended fix order

1. SEC-02 rotate → SEC-01 → FLOW-12 (money/security first).
2. Apple rejections: STORE-01, STORE-02/UX-C-01, STORE-03, release URL gate.
3. Safety/wedge: UX-B-01/02, UX-D-01, UX-A-01.
4. HIGH data-integrity bugs (BUG-01/02/04, restore toast, consent version).
5. Then device pass (simulator + ARTEMIS per AGENTS.md §4) to convert Tier 1 → Tier 4.
