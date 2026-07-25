# CoverWise backend-to-frontend UI gap review — 2026-07-25

## Scope and baseline

This review compares the mounted FastAPI contracts in `src/app/main.py` and
`src/api/` with the Flutter services and user-facing surfaces in `mobile/lib/`.
It treats retired compatibility routers (`src/api/policy.py` and
`src/api/family.py`) as intentionally non-canonical, not as missing mobile
features.

The product boundary remains: CoverWise helps a person understand and organize
policies they already own. It does not submit claims, make insurer decisions,
sell policies, or present self-recorded statuses as insurer-sourced truth.

Evidence in this review is Tier 1 unless a higher tier is stated.

## Capability coverage

| Backend capability | Current Flutter surface | Status | UI/design decision |
|---|---|---|---|
| Health and readiness | `backend_health_provider.dart`, global/offline banners | Present | Keep customer copy simple; deployment diagnostics belong in operator tooling. |
| Document upload, list, detail, source, delete, reprocess, status, summaries and pages | Documents, processing, policy detail and preview flows | Present | Preserve the document-first hierarchy. Continue removing nested-card density. |
| Document field citations | Evidence service and policy/answer citation surfaces | Present | Verification state remains the signature trust element. |
| Document Q&A and usage stats | Q&A screen, usage/entitlement UI | Present | Never merge local unverified output with backend evidence-backed status. |
| Subscription sync, status and Q&A balance | Billing adapter, entitlement providers, paywall/Q&A packs | Present | Customer-facing availability still depends on live provider evidence. |
| Account export, deletion and deletion status | Account/profile flows | Present | High-risk; retain explicit partial/deferred status and retry language. |
| Consent record and current state | Local ledger plus background server sync | Present | The local cache gates features; the server remains authoritative. |
| Consent history (`GET /consent/history`) | **Added in this work:** Consent activity screen | Tier 2 | Show the append-only account record; do not show a partial local cache as complete. |
| Claims create/list | Claim wizard, claim log, startup sync | Partial | Existing sync does not preserve the client ID returned by local creation. |
| Claims get/update/delete | Backend supports owner-scoped CRUD | Missing from mobile mutations | Do not add superficial sync badges until identity mapping, retries and delete semantics are fixed. |
| Analytics ingest | Local-first event batching | Present | Appropriate for the customer app. |
| Analytics summary, health and error feed | No customer mobile surface | Intentionally absent | These are operator capabilities. Route to an authenticated operator surface, not More/Settings. |
| RAG stats, service debug and OCR cache debug | No customer mobile surface | Intentionally absent | Keep behind operator/debug boundaries. |
| Retired `/policy` and `/family` routers | Canonical `/documents` plus derived/local family workspace | Intentionally absent | Do not revive duplicate routes or a second source of truth. |

## Highest-priority unresolved frontend contract gap

### Claims sync identity and CRUD integrity

`ClaimsSyncService.pushClaim()` posts a locally generated claim but discards the
server response. The backend generates a different UUID. Subsequent full syncs
therefore cannot prove that the local record already exists remotely and may
post it again. Mobile status, reference-number and delete mutations also update
Hive without calling the backend `PATCH`/`DELETE` routes.

This is not a visual-only problem. A truthful UI requires a canonical mapping or
client-generated idempotency contract, queued mutation state, retry/error
visibility and tests for duplicate, offline, partial-success and delete cases.
Owner: product/backend/mobile. Closure criteria:

1. Record an ADR for client/server claim identity and offline mutation semantics.
2. Make create idempotent or persist the server ID returned by create.
3. Wire status/reference/notes and deletion through the canonical backend routes.
4. Add pending/synced/needs-attention states without implying insurer status.
5. Verify duplicate retry, partial failure, offline recovery and cross-device
   merge at Tier 3 or higher.

Risk of shipping current sync: duplicate private claim-log rows and cross-device
drift. This is a product-record integrity risk, not insurer claim processing.

## Implemented design decision: consent activity

The first coherent UI slice is the missing consent history surface because the
backend route explicitly exists for the user-facing “show me what I consented
to” workflow and the current Privacy & Security screen exposes only a local
analytics toggle.

The implementation:

- adds a typed `getConsentHistory()` call to the canonical consent service;
- adds a chronological, month-grouped Consent activity screen;
- shows policy version and localised event time without exposing IP address,
  user-agent or user ID;
- distinguishes loading, empty and authoritative-ledger-unavailable states;
- refuses to label a partial local cache as complete;
- links the surface from Privacy & Security;
- replaces the shared all-caps tracked section eyebrow with a normal product
  section heading;
- reduces canonical card/dialog/shared-surface radii to 16dp.

## Image-generation design reference

The generated concept is stored at
`docs/review/assets/consent_activity/consent_activity_reference_2026-07-25.png`.
It is internal design evidence, not a shipped app asset.

Prompt summary: high-fidelity portrait Material 3 “Consent activity” screen in
the CoverWise navy/blue/cloud palette; chronological privacy-choice ledger;
timeline rows and dividers; accessible contrast; no gradients, glass, nested
cards, oversized metrics, purple, sparkle motifs or radii above 16px.

The implementation deliberately rejected the generated mockup’s unsupported
encryption sentence. The product UI says the record is account-scoped and does
not turn an image-model proposal into a security claim.

## Verification log

- Tier 2: targeted Flutter analysis passed for the consent service, activity
  screen, privacy entry point, theme, shared components and tests.
- Tier 2: 14/14 targeted consent/privacy tests passed, including a narrow
  320px viewport, dark theme and 200% text-scale regression.
- Tier 2: 19/19 focused backend consent API, ledger and schema tests passed.
- Tier 4 (web rendering only): Browser rendered the existing app onboarding at
  a 390x844 phone viewport from Flutter's web server. Evidence:
  `docs/review/assets/consent_activity/flutter_web_onboarding_browser_2026-07-25.png`.
- The first native build attempt was blocked in `sentry_flutter 8.14.2` by the
  iOS 26/Xcode SDK (`imageByAddress` SPI access).
- A temporary `sentry_flutter 9.25.0` evaluation exposed a mixed
  SwiftPM/CocoaPods duplicate-symbol graph and, under the single-manager
  experiment, an incompatible Cocoa Sentry API. The package and build-setting
  changes were fully rolled back; no speculative native dependency change is
  retained.
- Browser verified the ServeSim preview controls at `http://127.0.0.1:3200`.
  ServeSim reported no inspectable Safari/WKWebView target, so
  `docs/review/assets/consent_activity/servesim_browser_preview_2026-07-25.png`
  is control-panel evidence, not native app evidence.
- Tier 4 native app evidence is blocked. The consent activity screen itself was
  not observed on an iOS simulator in this work.

## Multi-pass review

### Pass 1 — immediate correctness and completeness

Checked success, empty, loading and unavailable states; no sensitive server
metadata is rendered; unknown future consent types remain legible. Added and
passed the narrow-screen, dark-theme, 200% text-scale test.

### Pass 2 — architecture and long-term viability

Extended the canonical consent service and mounted backend route. No new API
route, parallel consent pipeline or local-history truth source was introduced.
The claims gap was kept separate because visual polish cannot repair its
identity/idempotency contract.

### Pass 3 — rule compliance and supervision readiness

Checked the customer-claim boundary, evidence wording, accessibility semantics,
48dp action sizing via the theme, loading/empty/error behavior, image-generation
claim safety, documentation continuity and explicit evidence tiers. No commit,
push, branch, deletion or history operation was performed.

## Anything else?

Yes:

- The privacy and consent surfaces still contain hard-coded English while the
  app has English/Hindi localization infrastructure. Owner: mobile. Closure:
  move the complete privacy surface as one coherent localization unit rather
  than localizing only the new route.
- Several one-off screens still use radii above the 16dp product ceiling. Owner:
  design system/mobile. Closure: migrate them to canonical shared primitives and
  verify narrow phone, dark mode and 200% text scale.
- Native visual QA remains blocked by the current Sentry/plugin dependency
  graph. Owner: mobile/platform. Closure: choose a capability-preserving Sentry
  and dependency-manager migration, then run iOS debug, release and physical
  device smoke checks before treating web evidence as native evidence.
- The generated `PRODUCT.md` context file is missing. Impeccable allows scoped
  work to proceed from code and `DESIGN.md`, but a future `$impeccable init`
  should capture the stable product context.
