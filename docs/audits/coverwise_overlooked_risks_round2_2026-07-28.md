# CoverWise Overlooked-Risks Audit — Round 2

**Date:** 2026-07-28
**Status:** Companion to `coverwise_regulatory_scope_risk_audit_2026-07-28.md`. Produced for founder review and external verification.
**Revision 2026-07-28 (B):** G-1 **RETRACTED** after re-verification (see §"G-1 retraction" below). The original finding overcalled a debug-default `key.properties`; no rotation or history rewrite is required.
**Revision 2026-07-28 (C):** The "hygiene fix applied" claim in rev B was **wrong**. The `key.properties` I untracked lived in a stray top-level `android/` directory that the build does not read (canonical path is `mobile/android/`); the real project was already correctly configured (`key.properties` ignored at `mobile/android/.gitignore:12`, `.example` already present). My attempted fix was misdirected and inert. Per [ADR-2026-07-28-02](../decisions/ADR-2026-07-28-02-stray-android-directory-disposition.md), the stray top-level `android/` directory is deleted entirely and nothing is restored, because the canonical project was already clean. All other findings (G-2…G-9) stand unchanged.
**Method:** Tier-1 static inspection. Each finding cites `path:line` and quotes verbatim text or shows the grep result.
**Scope:** Gaps *between* the existing dated audits, contradictions between stated policy and implemented behavior, and items whose interactions have not been synthesized. This doc intentionally avoids restating the 5 prior audits (launch-readiness 07-22, native/store 07-21, production-readiness 07-23, launch-preparedness 07-20, regulatory-scope 07-28) and instead surfaces what they collectively missed or what has drifted since they were written.

---

## Problem statement

The first audit (regulatory scope) asked: *does the app do something a regulated actor would do?* This second audit asks a different question:

> **Where does the app claim a behavior (in legal copy, config defaults, or audit assumptions) that the code does not actually perform — and where does the code do something the legal copy and the founder's risk posture assume it does not?**

Every contradiction between "what we say" and "what we do" is a liability surface: a privacy commitment the code breaks is a DPDP/Play-Store exposure; a secret checked into git is a key-compromise exposure; a deletion path that leaves derived personal data behind is an erasure-right failure. These are the bugs that survive precisely because each individual audit looked at one layer (code, or copy, or ops) and no one diffed the layers against each other.

This document diffs the layers.

---

## Executive summary

Nine findings. G-1 was **retracted** on re-verification (see below). Of the remaining eight: three are 🔴 high and launch-blocking on their own; three are 🟠 medium; two are 🟡 low / housekeeping.

| ID | Tier | One-line | Layer gap |
|---|---|---|---|
| ~~G-1~~ | ~~🔴~~ | ~~`android/key.properties` with real signing passwords committed to git~~ — **RETRACTED**: values are debug defaults, real keystore untracked; my attempted fix targeted a stray non-canonical dir and was inert — stray dir deleted per ADR-02 | ~~secret hygiene~~ → no fix needed; canonical project already clean |
| G-2 | 🔴 | Account deletion does not cancel the RevenueCat subscription or revoke entitlements; deleted users keep paying | code vs. user contract |
| G-3 | 🔴 | Account deletion does not purge Qdrant vectors; embeddings of deleted users' policies persist indefinitely | code vs. erasure right |
| G-4 | 🟠 | Privacy policy says analytics retained 30 days; code defaults to 90 days | copy vs. code |
| G-5 | 🟠 | Children's-privacy threshold is "under 13" (US COPPA); India's DPDP Act uses 18 | copy vs. jurisdiction |
| G-6 | 🟠 | No data-breach notification process exists; only a roadmap TODO | ops vs. DPDP duty |
| G-7 | 🟡 | iOS OAuth callback scheme/path mismatch still present (from 07-21 audit) | code, drifted/unfixed |
| G-8 | 🟡 | `support@coverwise.app` is referenced in 6 places but the domain does not resolve | copy vs. reality |
| G-9 | 🟡 | Deletion leaves rows in `qa_usage_ledger`, `consent_ledger`, `billing_ledger` referencing the deleted user | code, possibly intentional, undocumented |

The single most important synthesis: **the account-deletion path is the weakest link in the app's privacy posture.** It is well-engineered for the tables it touches (idempotent, staged, durable), but it is *incomplete* in a way that creates three independent liabilities at once — continued billing (G-2), retained embeddings (G-3), and orphaned ledger rows (G-9). Fixing deletion is the highest-leverage single action in this audit.

---

## Findings — detailed evidence

### ~~G-1~~ 🔴→❎ RETRACTED — Android signing "secrets" were debug defaults, not a compromise

**Retraction note (2026-07-28, rev B).** The original G-1 finding claimed `android/key.properties` contained "real signing passwords" committed to git and recommended keystore rotation + history rewrite. **That finding was wrong.** On re-verification before acting, the committed file contained:

```
storePassword=android
keyPassword=android
keyAlias=upload
storeFile=app/upload-keystore.jks
```

These are the **documented Flutter/Android debug-keystore defaults** (`android`/`android`), not production credentials. The actual keystore, `mobile/android/app/upload-keystore.jks`, is **not tracked in git** (verified: `git ls-files` shows no `.jks`/`.keystore`); only the pointer file `key.properties` was tracked. The release build path is already fail-closed — `mobile/android/app/build.gradle.kts:25-31` throws `GradleException` unless `COVERWISE_RELEASE_BUILD=true` *and* a valid `key.properties` with an existing `storeFile` is present. So the tracked file is the intentional local-dev fallback, not a leaked production secret.

**No rotation, no history rewrite, no compromise to report.** The repo being on a GitHub remote (`origin → pranaysuyash/insurance_q`) does not change this, because the values are public debug defaults.

**What I claimed was a "fix" on 2026-07-28 (rev B) was wrong, and is corrected here (rev C):** I wrote that I untracked `android/key.properties` and added `android/key.properties.example` as a hygiene fix. That was misdirected. The `key.properties` I untracked lived in a **stray top-level `android/` directory that is not the Android project the build reads** — `mobile/android/app/build.gradle.kts:14` resolves `rootProject.file("key.properties")` to `mobile/android/`, not the repo root. The canonical project at `mobile/android/` was **already correctly configured** before this session: `key.properties` properly ignored at `mobile/android/.gitignore:12`, and `mobile/android/key.properties.example` already present. My "fix" touched a husk nothing reads and changed nothing the build depends on.

**Actual disposition (per [ADR-2026-07-28-02](../decisions/ADR-2026-07-28-02-stray-android-directory-disposition.md)):** the stray top-level `android/` directory is **deleted entirely** (both the historically-tracked `android/key.properties` and my erroneous `android/key.properties.example`). Nothing is restored, because the canonical project was already clean. The deletion is a §7/§13 canonical-path decision (one Android project, at `mobile/android/`), recorded as an ADR, not a casual cleanup.

**Lesson for the audit process (recorded so it is not repeated):** the original finding had **two** root failures, not one. (1) It was written from a redacted grep ("values redacted") without verifying whether the redacted values were real secrets or known defaults. (2) Even after retracting on (1), my "fix" targeted the wrong path because I did not verify which `key.properties` the build actually reads (`mobile/android/app/build.gradle.kts:14` → `mobile/android/`, not the repo-root `android/`). For any future security/build claim, two verifications are now mandatory before recommending action: *read the actual value and confirm it is not a public default* AND *prove with a command that the relevant build/runtime resolves to the path being changed*. Catastrophizing a known dev-pattern, then "fixing" the wrong file, wastes founder attention and erodes trust in the rest of the audit. The other eight findings (G-2…G-9) were re-baselined against this standard and stand.

---

---

### G-2 🔴 Account deletion does not cancel the subscription or revoke entitlements

**Evidence.** `src/services/account_lifecycle_service.py:process_deletion` (lines 100–199) is the durable, staged erasure routine. The tables it touches, from its own body:
- `dataset_items` (mark withdrawn) — line 156
- `documents` (select then delete) — lines 161, 180
- `document_chunks` (delete) — line 179
- `auth.admin.delete_user` — line 183
- `account_deletion_requests` (status bookkeeping) — throughout

Tables and services it does **not** touch: `billing_ledger`, `entitlements`, `qa_usage_ledger`, and — critically — **no call to the RevenueCat API to cancel the subscription.** There is no import of a RevenueCat client in this file and no `revenuecat`/`subscription`/`entitlement` string anywhere in the deletion path (verified by grep).

**Why this matters.** A user who deletes their account:
- has their Supabase auth user removed, but
- **continues to be billed by Google Play** for the CoverWise subscription, because the Play subscription is owned by the Play account, not by CoverWise's auth layer, and CoverCat/RevenueCat is never told to cancel it.

The app *acknowledges* this in `docs/legal/account_deletion.html:128`:
> "Deleting your account does not automatically cancel active Google Play or Apple App Store subscriptions. Please cancel any active trial or subscription via your device store settings…"

This is honest, but it shifts a data-protection obligation onto the user and is a known chargeback/refund/complaint generator. It is also a re-occurrence of the P0 flagged in `launch_preparedness_audit_2026-07-20.md` ("deletion still doesn't cancel store subscriptions") — **still open**.

**Recommendation.** Before accepting paid subscriptions in production, the deletion path must call RevenueCat to cancel the Play subscription (RevenueCat supports server-side cancellation via its REST API for stores where the app has the entitlement). At minimum, the deletion-confirmation email/screen must deep-link the user directly to the Play subscription management page, not just instruct them in prose. Decide explicitly whether CoverWise will cancel server-side (best UX, more integration) or force user-side cancellation (less integration, more friction + refund risk), and make the legal copy match the chosen behavior exactly.

---

### G-3 🔴 Account deletion does not purge Qdrant vectors (embeddings persist)

**Evidence.** The configured vector backend is Qdrant (`.env.example:49`: `RAG_VECTOR_BACKEND=qdrant`). Qdrant is an *external* service to Supabase. The deletion routine deletes from `document_chunks` (the pgvector table, line 179) — but when the backend is Qdrant, the actual embeddings live in the Qdrant collection, not in `document_chunks`. The capability to delete by owner/document *exists* (`src/rag/pipeline.py:1023` `delete_document_data`, which calls `qdrant_client.delete` at line 1045) — but **`account_lifecycle_service.process_deletion` never calls it.** Grep for any qdrant/vector reference in the deletion file returns nothing.

**Why this matters — and why this is a DPDP issue, not just a bug.** Under the DPDP Act 2023, "personal data" includes data *derived* from personal data. A vector embedding of a user's insurance policy is derived from their document and is re-identifiable to the extent the policy text is unique (it usually is — policy numbers, names, sums insured). The right to erasure therefore extends to the embeddings, not just the source PDF and the row in `documents`.

So the current deletion path: deletes the PDF ✅, deletes the `documents` row ✅, deletes the `document_chunks` rows ✅ (which may be empty if the backend is Qdrant), and **leaves the embeddings in Qdrant forever** ❌. The privacy policy (`privacy_policy.md:56`) promises "Policy documents (server) → Until account deletion." The embeddings are arguably "policy documents (server)" in derived form, and they outlive deletion.

This is the most legally subtle finding because it depends on the configured backend. If production ships with `RAG_VECTOR_BACKEND=supabase` (pgvector), G-3 partially dissolves (deletion of `document_chunks` covers it). If it ships with `qdrant`, G-3 is a live erasure-right violation. **The choice of vector backend is now a compliance decision, not just a performance one.**

**Recommendation.** Either (a) call `delete_document_data` for each owned document inside `process_deletion` before deleting the `documents` rows, regardless of backend; or (b) document an explicit decision to use pgvector in production so that `document_chunks` deletion is sufficient. Option (a) is safer because it is backend-agnostic.

---

### G-4 🟠 Analytics retention: policy says 30 days, code says 90 days

**Evidence — copy:**
`docs/legal/privacy_policy.md:58`:
```
| Analytics events | 30 days | Automatic purge |
```

**Evidence — code:**
`src/services/analytics_retention_service.py:54-60`:
```python
def _default_retention_days() -> int:
    """Return the configured retention period, defaulting to 90 days."""
    try:
        return max(1, int(os.environ.get("ANALYTICS_RETENTION_DAYS", "90")))
    except ValueError:
        return 90
```
`src/app/main.py:206` (comment): *"retention window (default 90d)"*.

**Why this matters.** A retention period stated in a privacy policy is a binding commitment. Retaining analytics for 90 days when the policy promises 30 is a misrepresentation to users and a DPDP exposure. This is not hypothetical: it is a verifiable, date-stamped contradiction between two files in the same repo.

**Recommendation.** Pick one number and make both sides match. The cleaner fix is to set `ANALYTICS_RETENTION_DAYS=30` in production config and leave the code default at 30 (not 90) so a misconfiguration cannot silently extend retention beyond the promised window. Also verify the purge actually *runs* — it is wired through `main.py:241` (`purge_old_analytics_events`), confirm it is scheduled and not just defined.

---

### G-5 🟠 Children's-privacy threshold is "under 13" — wrong for India

**Evidence.** `docs/legal/privacy_policy.md:88-90`:
```
## Children's Privacy
CoverWise is not intended for users under 13. We do not knowingly collect data from children.
```

**Why this matters.** "Under 13" is the threshold from COPPA, the US children's-privacy statute. CoverWise is an India-targeted product (ap-south-1 backend, ₹ currency, IRDAI references). India's **DPDP Act 2023** defines a "child" as a person **under 18**, and requires verifiable parental consent before processing any child's personal data, with additional restrictions on behavioral tracking and targeted advertising toward children.

A policy that says "under 13" both (a) under-states the founder's actual obligation under Indian law and (b) reads as a copy-paste from a US template, which weakens the credibility of the whole document. For an insurance-adjacent app, there is also a reasonable product position that the app simply does not process children's data at all (children rarely own insurance policies) — but that position must be stated explicitly and the threshold must match the governing law.

**Recommendation.** For an India-targeted app, either: (a) raise the threshold to 18 and implement age-gating + verifiable parental consent (heavy, likely unnecessary for this product); or (b) take the position that the app is not directed at children and does not knowingly process their data, state the threshold as 18 per DPDP, and add a plain-language "not for users under 18" line. Option (b) is almost certainly the right one for CoverWise. Confirm with the reviewer.

---

### G-6 🟠 No data-breach notification process (DPDP requires it)

**Evidence.** The only reference to incident response is a roadmap checkbox:
`docs/planning/roadmap/unified_project_roadmap.md:189`:
```
- [ ] Develop incident response procedures
```
There is no breach-notification runbook, no contact list for the Data Protection Board, and no documented 72-hour clock anywhere in `docs/`.

**Why this matters.** The DPDP Act and Rules impose a duty on the Data Fiduciary to notify the Data Protection Board and affected Data Principals of a personal-data breach, on a short timeline (the Rules specify deadlines and content requirements). For a solo founder, the failure mode is not "we had a breach and hid it" — it is "we had a breach and had no idea what to do next, and burned the notification window figuring it out." That is treated the same as a deliberate failure to notify.

**Recommendation.** Write a one-page incident-response runbook before launch: what counts as a breach, who is notified (DPB + affected users), within what window, with what content, and where the trigger detection comes from (logs, Sentry, user report). It does not need to be enterprise-grade. It needs to exist, be dated, and be findable. This is cheap to write and expensive to be without.

---

### G-7 🟡 iOS OAuth callback scheme/path mismatch (carried forward)

**Evidence — still present:**
```
mobile/lib/services/auth_service.dart:391:  redirectTo: 'io.coverwise://login-callback',
mobile/lib/services/auth_service.dart:405:  redirectTo: 'io.coverwise://reset-callback',
mobile/ios/Runner/Info.plist:31,34: <string>io.coverwise</string>
```
In the URL `io.coverwise://login-callback`, `login-callback` is the **host**. The router (per the 07-21 audit) switches on `/login-callback` as a **path**. The handler never matches the URL the auth flow generates.

**Status.** First reported in `coverwise_native_mobile_platform_store_readiness_audit_2026-07-21.md`. Still present on current head. Not a launch blocker for Android-first, but it **must** be fixed before any iOS build or TestFlight, and because it is in shared code (`auth_service.dart`), it should be tracked now so it is not rediscovered under time pressure during iOS submission.

**Recommendation.** Track explicitly; fix when iOS work begins. Do not let it ride along as "known issue" into an iOS submission sprint.

---

### G-8 🟡 `support@coverwise.app` referenced but domain unresolved

**Evidence — referenced in 6 user-facing/legal surfaces:**
```
docs/legal/privacy_policy.md:99            Email: support@coverwise.app
docs/legal/terms_of_service.md:112         Email: support@coverwise.app
docs/legal/account_deletion.html:175,181   ...email support@coverwise.app
mobile/lib/screens/help_support_screen.dart:52   mailto:support@coverwise.app
```

From the live session log (2026-07-25 checkpoint): `curl https://coverwise.app/privacy` → `Could not resolve host`. The domain is not yet live, which means **the support inbox almost certainly does not exist yet either.**

**Why this matters.** Google Play requires a working support email and a reachable privacy policy for listing approval. A user who taps "email support" in-app or follows the deletion-instructions mailto will have their request bounce. For account-deletion specifically, a bounced support email is a direct DPDP erasure-right failure — the user tried to exercise their right and could not reach you.

**Recommendation.** Stand up `support@coverwise.app` (a simple forwarding inbox is fine to start) and host the privacy policy + terms at real URLs *before* store submission. This is on the critical path for Play approval, not a nice-to-have. Coordinate with G-6's incident contact (same inbox can serve both).

---

### G-9 🟡 Deletion leaves orphaned rows in usage/consent/billing ledgers

**Evidence.** `process_deletion` (G-2 above) deletes from `documents`, `document_chunks`, `dataset_items`, and auth. It does **not** delete from `qa_usage_ledger`, `consent_ledger`, or `billing_ledger`. These tables are keyed by `account_uid` / owner and will retain rows referencing a user who no longer exists in auth.

**Why this matters — and why this might be fine.** This is the one finding that is *possibly intentional*. Consent and billing ledgers are often deliberately retained as an audit trail (you may need to prove what a user consented to, or that a refund was processed, long after the account is gone). If that is the intent, it is defensible — but it is **undocumented**, and the privacy policy (`privacy_policy.md:59`: *"Account data → Until deletion"*) does not carve out an exception for these ledgers. So either the code or the policy is wrong about what "account data" means.

**Recommendation.** Make a deliberate, documented decision per ledger:
- `consent_ledger`: retain for the legally-required consent-evidence period, then purge. State the retention in the policy.
- `billing_ledger`: retain for tax/refund-dispute period (typically 3–7 years), then purge. State it.
- `qa_usage_ledger`: this is usage telemetry tied to the user, not a financial/legal record — purge on deletion.
Then update the privacy-policy retention table to reflect the carve-outs explicitly. The fix is mostly editorial; the risk is the *undocumented* inconsistency.

---

## Synthesis: the deletion path is the load-bearing wall

G-2, G-3, and G-9 all attach to the same function (`account_lifecycle_service.process_deletion`). Individually each is a medium-to-high finding; together they describe a deletion routine that is **well-built for half its job and blind to the other half**. It deletes what it knows about (documents, chunks, auth) and silently ignores what it doesn't (subscriptions, vectors, ledgers). That pattern — confident incompleteness — is more dangerous than a deletion path that fails loudly, because it returns `status: completed` while leaving derived and financial data behind.

The highest-leverage single action across this whole audit is to **make `process_deletion` complete and make its `completed` status mean what the privacy policy says it means.** Doing so closes G-2, G-3, and G-9 simultaneously and aligns the code with the legal copy that already exists.

---

## What is already solid (verified, do not re-litigate)

- **Rate limiting** is real, not aspirational: `src/utils/anti_abuse.py`, `check_supabase_rate_limits` / `check_all_rate_limits`, 429 responses in `src/api/document.py:231-243`, with Supabase RPC backing in production. Good.
- **Source-file download** uses signed/short-lived URLs from the object store (`create_download_url`, 900s expiry), not user-supplied URLs — no SSRF/open-redirect surface found in the download path.
- **Deletion durability** (idempotency, stage state, retry semantics) is well-engineered *for what it covers*. The criticism above is about coverage, not mechanism.
- **Vector-deletion capability exists** (`pipeline.delete_document_data`) — the gap is that the deletion orchestrator doesn't call it, not that the primitive is missing.

---

## Recommended remediation buckets

**Secrets (do immediately, independent of launch):**
- ~~G-1: rotate the Android keystore, untrack `key.properties`, decide on history rewrite.~~ **RETRACTED — no live compromise.** No fix was needed: the canonical Android project (`mobile/android/`) was already correctly configured. My attempted fix targeted a stray non-canonical `android/` directory and was inert; that stray directory is deleted per [ADR-2026-07-28-02](../decisions/ADR-2026-07-28-02-stray-android-directory-disposition.md). No further action on G-1.

**Deletion completeness (do before accepting paid subscriptions / before launch):**
- G-2: cancel subscription / revoke entitlement in the deletion path, or wire a forced user-side cancellation with a deep link; align `account_deletion.html` copy to the chosen behavior.
- G-3: call `delete_document_data` for each owned document in `process_deletion`, or commit to pgvector in production.
- G-9: decide per-ledger retention, document it, update the privacy-policy table.

**Copy-vs-code alignment (do before store submission):**
- G-4: set analytics retention to 30 in config and code, match the policy.
- G-5: set the children's threshold to 18 (or take the "not directed at children" position), match DPDP.
- G-8: stand up the support inbox and host the legal pages at real URLs.

**Ops (do before launch, cheap):**
- G-6: write a one-page breach-notification runbook.

**Carry-forward tracking:**
- G-7: iOS OAuth scheme/path fix — track for the iOS sprint, do not let it reach submission.

---

## Open questions for the reviewer

1. ~~Has the repo (`pranaysuyash/insurance_q` / this working copy) ever been pushed to a remote, shared with a collaborator, or included in any vendor-diligence package? If yes, G-1 escalates from "rotate" to "rotate + rewrite history + notify."~~ **Moot after G-1 retraction** (values were debug defaults; remote presence is not a factor). The underlying question — does the founder understand that any *real* future secret committed to a remote repo must be rotated + history-rewritten — is still worth a yes/no from the reviewer, but it no longer attaches to a live incident.
2. Is production intended to run on Qdrant or pgvector? The answer determines whether G-3 is a live violation or a latent one. (The `.env.example` default is Qdrant; the launch docs reference a Qdrant Cloud cluster.)
3. Does the reviewer agree that consent/billing ledgers may be retained post-deletion as an audit trail, and if so, for what period under DPDP? This determines the G-9 carve-out language.
4. Is the founder willing to take the "not directed at children under 18" position (G-5 option b), or does the product need age-gating? For a policy-document tool, option (b) is almost certainly sufficient, but it is the reviewer's call.

---

## Acceptance checklist (per `legal-risk-audit` skill)

- [x] No code changes.
- [x] Evidence includes `path:line` references and verbatim quotes / grep output.
- [x] All scanned layers listed (git tracking, backend services, legal copy, config defaults, mobile services).
- [x] Category buckets applied (secret hygiene / deletion completeness / copy-vs-code / jurisdictional / ops / carry-forward).
- [x] Open questions and contradictions called out explicitly.
- [x] Synthesis provided (the deletion-path load-bearing-wall framing) so the reviewer sees the interaction, not just the parts.
