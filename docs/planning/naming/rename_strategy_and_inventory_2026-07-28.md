# Product Naming Strategy & Comprehensive Rename Inventory

**Date:** 2026-07-28
**Status:** DECISION PENDING — awaiting founder's new name. This doc is the strategy + inventory; execution is blocked on the name choice.
**Decision owner:** Pranay
**Doctrine:** `motto_v4.md` — §0 (bold long-term), §0.0.1 (whole-answer), §0.1.1 (anything else?), §0.2 (confidence honesty)
**Evidence tier:** Tier 1 (full-repo static audit) + Tier 0 (naming strategy reasoning — no external verification of trademark availability)

---

## Why this exists

The founder stated: *"CoverWise is a set of different products, same and different markets, same industry, so I am working on the naming and we will have to refactor so many things — start making that list."*

This document:
1. Frames the naming decision first-principles (company vs product vs app layering).
2. Inventories **every** occurrence of the current brand so the refactor is complete, not partial.
3. Defines the dependency order so nothing breaks during the rename.
4. Does NOT pick a name — that is the founder's decision. It prepares the ground so that once the name is chosen, execution is mechanical.

---

## 1. The three-layer naming problem

The audit surfaced a real architectural issue: the project currently has **three uncoordinated naming layers**, and they don't compose.

| Layer | Current name | Where it lives | Example |
|---|---|---|---|
| **Company / entity** | PSRS Technologies Pvt Ltd | Legal, billing, entity registration | `coverwise_india_billing...decision.md` |
| **Product line / portfolio** | (none — "CoverWise" is doing double duty) | — | — |
| **App / service identifiers** | `coverwise` + `insurance_app` (mixed!) | Package IDs, Docker images, code | `com.coverwise.app`, `insurance_app` image |

The infra layer is named `insurance_app` / `insurance-app-repo`, the app layer is `coverwise`, and there is no explicit product-portfolio layer. This is the root cause of the rename being "so many things" — the layers were never separated, so the brand name leaked into every layer including ones it shouldn't have.

**First-principles principle:** A name at the *product-portfolio* layer should be reusable across multiple apps. A name at the *app* layer should be unique per app. The company name is legally fixed. If the founder's vision is "a set of products in the same industry," then we need a portfolio name that doesn't collide with any single app.

### Recommended layering (whatever the names turn out to be)

```
PSRS Technologies (entity — fixed, legal)
└── <Portfolio brand>  ← the umbrella that spans products/markets
    ├── <App 1>  (e.g. the insurance-document app)
    ├── <App 2>  (future product, same or adjacent industry)
    └── <App 3>
```

**Concrete implication:** Package IDs, Docker images, and code should carry the *app* name, not the portfolio name. The portfolio name appears in marketing, legal entity "a product of," and the store publisher field. This separation is what lets you launch a second product without renaming the first.

**Decision needed from founder:**
- The portfolio name (the umbrella).
- The first app's name (the current insurance app).
- Whether `com.coverwise.app` → `com.<portfolio>.<app>` or `com.<app>` (see §5).

---

## 2. Naming criteria (first-principles)

A good name for this product portfolio must satisfy, in priority order:

1. **Legally available** — trademark search in India (and target markets) + domain availability. This is the hard gate; nothing else matters if the name is taken.
2. **Domain available** — `.app`, `.in`, `.com` at minimum. `.app` is the modern default for apps and is HTTPS-enforced.
3. **Does not imply regulated activity** — consistent with the permanent non-regulated boundary (`docs/audits/coverwise_product_strategy...2026-07-18.md` §1). Avoid words like *advise, broker, agent, counsel, insure, claim-filing*.
4. **Survives across products and markets** — since the vision is multi-product, the portfolio name can't be so specific to insurance that it blocks a future product. (Insurance-specific words like *Cover*, *Policy* are risky for this reason — they may be the very thing the founder wants to escape.)
5. **Pronounceable and short in English, Hindi, and romanized regional languages** — the app ships with en/hi/ta/gu/mr localization.
6. **Not a near-collision with an existing app in the same store category** — store search confusion kills organic discovery.
7. **Package-ID-safe** — must form a valid reverse-DNS identifier (lowercase, no hyphens in the Java/Kotlin package segments, valid DNS).

This doc does **not** recommend a name. It establishes the criteria so the founder can evaluate candidates.

---

## 3. What this rename is NOT

- **Not a re-architecture.** No code behavior changes. Pure identifier + string surgery.
- **Not urgent enough to block launch.** The current `coverwise` identifiers work. The rename can happen before first public release (ideal, so users never see the old name) OR after (costs a marketing reset but no technical debt). The founder decides timing.
- **Not all-or-nothing.** The soft layer (docs, UI strings) can be renamed in a later pass. Only the hard layer (package ID, storage bucket, RC products, domain) must be coherent at a given release.

---

## 4. Comprehensive inventory (the "list" the founder asked for)

**Headline counts (full-repo audit):**
- **210** filename/path occurrences
- **702** files with content matches
- **~5,000+** individual string occurrences
- **5 hard identifier systems** (must change in coordinated lockstep)
- **1 hard external system already misaligned** (Docker/AWS use `insurance_app`, not `coverwise`)

### 4.1 HARD — Package / bundle identifiers (CRITICAL, coordinated)

These break the build or break existing installs if changed wrong.

**Android (`com.coverwise.app`):**
| File | Line | Identifier |
|---|---|---|
| `mobile/android/app/build.gradle.kts` | 37 | `namespace = "com.coverwise.app"` |
| `mobile/android/app/build.gradle.kts` | 58 | `applicationId = "com.coverwise.app"` |
| `mobile/android/app/src/main/AndroidManifest.xml` | 53 | `android:name="com.coverwise.app.InstallReferrerReceiver"` |
| `mobile/android/app/src/main/AndroidManifest.xml` | 35 | deep-link scheme `io.coverwise` |
| `mobile/android/app/src/main/kotlin/com/coverwise/app/MainActivity.kt` | 1 | `package com.coverwise.app` |
| `mobile/android/app/src/main/kotlin/com/coverwise/app/InstallReferrerReceiver.kt` | 1 | `package com.coverwise.app` |
| (Kotlin directory tree) | — | `com/coverwise/app/` must be moved |

**iOS (`com.coverwise.app` + scheme `io.coverwise`):**
| File | Line | Identifier |
|---|---|---|
| `mobile/ios/Runner.xcodeproj/project.pbxproj` | 490, 672 | `PRODUCT_BUNDLE_IDENTIFIER = com.coverwise.app` (×2 configs) |
| `mobile/ios/Runner.xcodeproj/project.pbxproj` | 507, 525, 541, 694 | `com.coverwise.app.RunnerTests` (×4 test configs) |
| `mobile/ios/Runner/Info.plist` | 10, 18 | `<string>CoverWise</string>` (CFBundleName / CFBundleDisplayName) |
| `mobile/ios/Runner/Info.plist` | 31, 34 | URL scheme `io.coverwise` |

**Coordination requirement (motto §0.6 — high-risk path):** Changing the application ID requires *simultaneous* updates to: Gradle namespace + applicationId, AndroidManifest, Kotlin package dir + declarations, pbxproj (all 6 configs), Apple Developer App ID, Google Play Console listing + existing signing key enrollment, RevenueCat app config, Supabase auth redirect URL allowlist, and the `io.coverwise` URL scheme on both platforms. A partial change bricks installs and deep links.

### 4.2 HARD — URL scheme & deep links

| Identifier | Where | Coordinated with |
|---|---|---|
| `io.coverwise` | AndroidManifest.xml L35, Info.plist L31/34 | OAuth callbacks, password-reset links, citation deep links |
| `coverwise/install_referrer` (MethodChannel) | InstallReferrerReceiver.kt | MethodChannel mock in tests |

**Auth impact:** the `io.coverwise://login-callback` scheme is already flagged as buggy in the 07-21 store-readiness audit (scheme-as-host vs path mismatch). A rename is the right time to fix that bug too, not just relabel it.

### 4.3 HARD — Supabase storage bucket + RLS policies

| Identifier | Where | Notes |
|---|---|---|
| `coverwise-documents` (bucket) | `supabase/migrations/20260717000000...:143`, `20260721072000_storage_owner_policies.sql` (×5), `.env` `SUPABASE_STORAGE_BUCKET` | Objects already stored under this bucket — renaming requires Supabase-side object migration |
| `coverwise_documents_select/insert/update/delete` (RLS policy names) | `20260721072000_storage_owner_policies.sql` (×13) | Postgres identifiers; must drop+recreate together |

**Cost of renaming the bucket:** every existing document in production storage must be copied to a new bucket, then code + env + RLS updated atomically, then old bucket drained. Non-trivial. **Recommendation: keep the bucket name internal (it's not user-visible) even if the brand changes.** Bucket names are infrastructure, not marketing.

### 4.4 HARD — RevenueCat product IDs (external, can't be renamed — only recreated)

These are owned in the RevenueCat dashboard. Once a user purchases a product ID, **it cannot be renamed** — only deprecated and replaced.

| Current ID | Type | Status |
|---|---|---|
| `coverwise_plus_monthly` | Subscription | In billing_adapter.dart:32 + 4 SQL migrations |
| `coverwise_plus_yearly` | Subscription | Same |
| `coverwise_qa_starter`, `coverwise_qa_value`, `coverwise_qa_pro` | Consumable (legacy) | Same |

**Recommendation:** Since these products are not yet live to any customer (pre-launch), the rename is free now. After launch, it would be permanent. **This is the strongest argument for renaming before any paying customer exists.**

### 4.5 HARD — Environment variable names (`COVERWISE_*`, ~34 distinct names)

Most frequent: `COVERWISE_RUNTIME_ENV_FILE`, `COVERWISE_API_URL`, `COVERWISE_API_BASE_URL`, `COVERWISE_TERMS_OF_SERVICE_URL`, `COVERWISE_PRIVACY_POLICY_URL`, `COVERWISE_DB_PATH`, `COVERWISE_INTEGRATION_BASE_URL`.

These are read by Python and Dart at runtime. Renaming requires coordinated updates to `.env`, `.env.example`, all readers, deploy manifests, and Cloud Run / Render env defs. **Risk:** a missed reader silently breaks with empty values.

**Note:** the mobile app actually reads `API_BASE_URL`, `SUPABASE_URL`, etc. (no `COVERWISE_` prefix) per `app_config.dart`. So the `COVERWISE_*` names are largely backend-side. Lower coordination cost than it appears.

### 4.6 HARD-adjacent — Dart package name (`name: coverwise` in pubspec.yaml)

This is the single most viral identifier in the codebase:
- `pubspec.yaml:1` → `name: coverwise`
- Every test import: `import 'package:coverwise/...';` — **~100 test files, hundreds of import lines**
- Generated localization references the package name

Renaming the Dart package triggers a mass find-replace across all test imports. Mechanically simple but voluminous. **Tooling:** `sed` or a IDE rename handles this in one pass.

### 4.7 SOFT — User-visible UI strings (localization)

| Source | Count | Languages |
|---|---|---|
| `mobile/lib/l10n/app_*.arb` | 46 strings | en, hi, ta, gu (11 each), mr (2) |
| Generated `app_localizations_gen*.dart` | 57 occurrences | auto-regenerated from .arb |

Representative keys: `appName`, `qaScreenTitle` ("Ask CoverWise"), `profileDefaultHeader` ("Your CoverWise profile"), `accountSwitchToSignIn` ("New to CoverWise?"). Safe find-replace; regenerate localization after.

### 4.8 SOFT — Source code identifiers & log strings

- `app_config.dart:90` → `static const String appName = 'CoverWise';` (the canonical constant)
- Backend: `SITE_NAME = "CoverWise"` (frontend/app.py:32), `ISSUER = "coverwise-api"` (anonymous_auth.py), `parser_version = "coverwise.document-intelligence.v1"` (document_intelligence.py)
- MethodChannel names: `coverwise/services`, `coverwise/providers`, `coverwise/models`
- structlog logger names: `coverwise.auth`
- Sentry release tag: `coverwise-{service}@{version}`

**Note on `parser_version` and similar version tags:** these may be referenced in stored data (model lineage). Renaming them mid-stream could break lineage lookups. Treat as semi-hard; verify against `model_lineage` table before renaming.

### 4.9 SOFT — Documentation (260 .md files)

| Directory | Files |
|---|---|
| `docs/review/` | 99 |
| `docs/recovered-off-repo-work/` | 47 |
| `docs/planning/` | 35 |
| `docs/technical/` | 33 |
| `docs/audits/` | 18 |
| `docs/legal/` | 3 |
| Top-level READMEs | ~12 |
| Other | ~13 |

All soft. Find-replace safe. **Decision:** historical audit docs (e.g. `coverwise_launch_readiness_review_2026-07-22.md`) can be left with the old name in their *filename* as an immutable historical record — only the body text needs updating if referenced. This respects motto §0.3 (documentation continuity — don't erase history).

### 4.10 SOFT — Legal / policy (HIGH VISIBILITY despite being soft text)

| File | Occurrences |
|---|---|
| `docs/legal/terms_of_service.md` | 9 |
| `mobile/assets/legal/terms_of_service.md` | 9 |
| `docs/legal/privacy_policy.md` | 6 |
| `mobile/assets/legal/privacy_policy.md` | 6 |
| `docs/legal/account_deletion.html` | 8 |
| `site/terms.html`, `site/privacy.html`, `site/index.html` | ~20 |

Soft to edit, but these are **published legal documents**. Changes need legal review and a version bump (`PRIVACY_POLICY_VERSION` is already wired in `app_config.dart`). The `mobile/assets/legal/` copies are bundled into the app binary.

### 4.11 MIXED — Assets / branding

| Asset | Referenced in | Notes |
|---|---|---|
| `mobile/assets/branding/coverwise_icon.png/.svg` | `pubspec.yaml` flutter_icons | Rename file + update pubspec |
| `coverwise_foreground.png/.svg` | pubspec.yaml | Same |
| `coverwise_monochrome.png/.svg` | pubspec.yaml | Same |
| `coverwise_macos.png/.svg` | pubspec.yaml | Same |
| `coverwise_splash.png/.svg` | pubspec.yaml | Same |
| iOS AppIcon / LaunchImage | generic names (no coverwise) | Just swap the image content |
| Dart class files | `coverwise_theme.dart`, `coverwise_motion.dart`, `coverwise_components.dart`, `coverwise_mark.dart`, `coverwise_scene.dart`, `coverwise_snackbar.dart` | Rename files + update imports |

**Recommendation:** the brand asset files (icons, splash) should be regenerated fresh for the new name anyway — a rename is a natural moment for a visual refresh. Don't preserve the old logo.

### 4.12 EXTERNAL MISALIGNMENT — Infra is already not "coverwise"

This is important: the infra layer never adopted the brand.

| System | Current name | Implication |
|---|---|---|
| DockerHub image | `$DOCKERHUB_USERNAME/insurance_app` | Used in `.github/workflows/ci.yml` |
| AWS ECR repo | `insurance-app-repo` | In deploy scripts |
| AWS App Runner service | `insurance-app` | In deploy scripts |
| GitHub repo | `medpiper/insurance_app` | The repo itself |

**Decision needed:** Should the infra align with the new app name, or stay generic? Recommendation: align, because `insurance_app` will be wrong the moment a second product ships. Use the portfolio or app name for infra.

---

## 5. Dependency order for the rename (the execution plan)

Sequenced so nothing breaks. Each step is a gated commit (motto §0.0.1).

### Stage 0 — Decide (BLOCKER, founder only)
1. Pick portfolio name, app name, domain.
2. Trademark + domain availability confirmed.
3. Decide package-ID scheme: `com.<app>` (simple) vs `com.<portfolio>.<app>` (multi-product-ready).

### Stage 1 — External systems first (founder + agent)
These must exist before code can reference them:
1. Register domain + DNS.
2. Apple App ID + Google Play app record (new application ID).
3. RevenueCat project + product IDs (new scheme).
4. Supabase: decide bucket (keep `coverwise-documents` internally, or migrate).
5. DockerHub / ECR new repo names (if aligning infra).

### Stage 2 — Hard internal linkages (one PR, atomic)
Must change together or the build breaks:
1. `pubspec.yaml` `name:` → triggers Dart package rename.
2. All `package:<old>/...` imports (sed across `mobile/test/`).
3. Gradle namespace + applicationId + Kotlin package dir + Manifest receiver name.
4. pbxproj (all 6 PRODUCT_BUNDLE_IDENTIFIER) + Info.plist CFBundleName/DisplayName + URL scheme.
5. `app_config.dart appName` + ARB `appName` (5 langs) + regenerate localization.
6. Brand asset filenames + pubspec references.
7. Dart class files (`coverwise_*.dart`) + their imports.
8. `COVERWISE_*` env var names (if renaming) + all readers.

### Stage 3 — Soft layer (multiple PRs, independent)
1. UI strings / localization body text.
2. Backend log strings, ISSUER/AUDIENCE, parser_version (verify lineage first).
3. Docs (260 files) — can be done in batches; historical audit filenames left as-is.
4. Legal docs — legal review + version bump.
5. Grafana / Prometheus labels.
6. Frontend HTML/SEO.

### Stage 4 — Verification
1. `flutter analyze` clean.
2. `flutter test` green.
3. Backend tests green.
4. Fresh release build installs without conflict with old app (different application ID).
5. Deep links resolve under new scheme.
6. RevenueCat purchase flow works with new product IDs in sandbox.

---

## 6. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| Renaming RC product IDs after first paying customer | **Permanent** | Rename before launch (now) — this is the strongest time-pressure argument |
| Partial package-ID change bricks installs | High | Atomic Stage-2 PR; test install on clean device |
| Bucket rename loses production documents | High | Keep bucket name internal; don't rename |
| Missed env var reader → silent empty value | Medium | Grep + CI smoke test that asserts required envs non-empty |
| Trademark collision discovered post-launch | High (legal) | Trademark search BEFORE committing to a name |
| `parser_version` rename breaks model lineage | Medium | Verify against `model_lineage` table; keep version tag stable if referenced |
| Old deep-link scheme breaks existing shared links | Low (pre-launch) | No users yet — free to change |

---

## 7. Anything else? (motto §0.1.1)

**Yes — three cross-cutting items the per-section analysis didn't cover:**

1. **The `medpiper` parent path.** The repo lives at `medpiper/insurance_app`. Is "medpiper" the portfolio brand, or a parent entity? If medpiper is meant to be the portfolio umbrella, the naming strategy changes — the app should be `medpiper/<app>`, not a fresh portfolio name. **Founder must clarify medpiper's role.**

2. **Store publisher name.** Google Play "Developer name" and Apple "Developer name" are visible to every user. Currently this would be an individual name or PSRS Technologies. The publisher name is part of the brand perception and should be decided alongside the product name.

3. **Localization of the brand name itself.** Should the app name be translated in hi/ta/gu/mr, or kept in English across all locales? Most Indian apps keep the brand in English. Confirm policy so the ARB files are consistent. (Current code keeps "CoverWise" untranslated in all ARBs — correct default.)

4. **The slogan / motto_v4 reference.** `motto_v4.md` itself is the engineering doctrine, not a product artifact — it should NOT be renamed even if the product is. Confirm it stays as the canonical engineering doctrine regardless of product name.

---

## 8. What I need from the founder to unblock execution

1. **Portfolio vs app naming scheme** (and medpiper's role).
2. **The chosen names** (after trademark/domain check).
3. **Domain** (which TLD).
4. **Timing:** rename-before-launch vs rename-after-launch.
5. **Infra alignment:** should Docker/AWS move from `insurance_app` to the new name?

Once 1–5 are answered, the execution is mechanical and I can run Stages 2–4 as gated commits.

---

## 9. medpiper elimination (founder directive 2026-07-28)

**Founder decision:** *"medpiper is out of it — it was a test app for medpiper that never went even for testing. Now it goes under my personal portfolio. Nothing should ever mention or be related to medpiper at all. Everything just pranaysuyash."*

**Scope audit (2026-07-28, Tier 1):**
- **135 files** mention "medpiper" (case-insensitive).
- **Zero occurrences in actual code** (`src/`, `mobile/lib/`) or env/config files (`.env`, `.env.example`).
- Occurrences are in: docs (`.md`), agent-context files (`docs/context/`, `.agent/`), and tooling scripts (`tools/*.py` that reference the medpiper project path for retrieval).
- The repo path itself is `medpiper/insurance_app` on disk — this is a directory name, not a code identifier. It can be moved on disk when convenient; no code references it as a literal.

**Classification: SOFT.** All medpiper references are non-load-bearing prose or path strings. No build breaks if they're changed. Safe to purge in a single docs/tooling pass, independent of the brand rename.

**Action:** Add a "medpiper purge" pass to the rename Stage 3 (soft layer). Replace "medpiper" with "pranaysuyash" (or the chosen portfolio name) in all 135 files. The repo directory can be renamed from `medpiper/insurance_app` to `<chosen-name>/<app>` on disk at the founder's convenience — it doesn't affect git history or code.

**Note:** This means the naming layers are now:
```
Pranay Suyash (individual — personal portfolio)
└── <Portfolio/app brand>  (founder deciding)
    └── <App>  (the insurance-document app)
```
PSRS Technologies Pvt Ltd remains the legal entity for billing/store purposes (per `coverwise_india_billing...decision.md`) but is not the public-facing brand.

---

## Update log

- 2026-07-28: created. Full-repo audit (Tier 1) + naming strategy. Awaiting founder name decision.
- 2026-07-28: appended §9 — medpiper elimination directive. 135 soft references, zero in code. Purge joins rename Stage 3.
