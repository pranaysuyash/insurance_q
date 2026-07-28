# Product Naming Strategy & Comprehensive Rename Inventory

**Date:** 2026-07-28
**Status:** RENAME DECIDED. Execution blocked only on the founder's choice of replacement name.
**Decision owner:** Pranay
**Doctrine:** `motto_v4.md` — §0 (bold long-term), §0.0.1 (whole-answer), §0.1.1 (anything else?), §0.2 (confidence honesty), §0.5 (evidence tiers)
**Evidence tier:** Tier 1 (full-repo static audit) + Tier 1 (third-party name-clearance report with 25 cited sources) + Tier 0 (naming strategy reasoning — no direct registry verification yet)
**Governing decision:** `CoverWise_Name_Clearance_and_Brand_Risk_Report_2026-07-28.docx` — verdict RED/90+, **RENAME BEFORE PUBLIC LAUNCH**.

---

## 0. The rename is settled — evidence summary

The independent Name Clearance & Brand Risk Report (28 July 2026, 25 cited sources) reaches an unambiguous verdict: **CoverWise must be renamed before any public store submission, domain launch, partnership, or trademark filing.** This is no longer a question of preference; it is a question of clearance, defensibility, and avoidance of a permanent confusion tax.

### The conflict set (decisive, not marginal)

| Collision | Severity | Source |
|---|---|---|
| **CoverSure** — Indian insurance app, 500K+ Play downloads, near-identical feature set, IRDAI corporate agent CA0894 | **CRITICAL** | S2–S5 |
| "Coverwise — Life Insurance" — live on India App Store, Finance category, exact word | HIGH | S1 |
| Coverwise Limited — UK/Europe/global, travel insurance, regulated intermediary | HIGH | S6–S7 |
| coverwise.co.in — India health/travel/life services | HIGH | S8 |
| CoverWise REI (Australia), CoverWise Financial Services (SA), CoverWise Insurance Solutions (US) | MEDIUM–MEDIUM-HIGH | S9–S12 |

**The decisive collision is CoverSure, not the small iOS app.** Same country (India), same category, near-homophone sound ("CoverWise" / "CoverSure"), near-identical features (policy portfolio, coverage gaps, claims support, family access, renewal reminders). Even a narrow legal clearance would leave a permanent confusion cost across search, store discovery, referrals, partnerships, and support.

### Decision score from the report: 10/100

The report scores CoverWise on five independent brand-asset gates:

| Gate | Weight | Score | Weighted |
|---|---|---|---|
| Ownability / clearance | 25% | 1/5 | 5/100 |
| Distinctiveness | 20% | 1/5 | 4/100 |
| Search & app-store discovery | 20% | 0/5 | 0/100 |
| Category confusion | 25% | 0/5 | 0/100 |
| Expansion headroom | 10% | 1/5 | 1/100 |

CoverWise fails every gate. The exact score matters less than the failure across all five independent dimensions.

### What does NOT cure the collision

Per the report, these are explicitly rejected:
- Changing capitalization (Coverwise, CoverWise, COVERWISE) — same word mark.
- Adding a weak suffix (CoverWise AI, CoverWise App, CoverWise India) — dominant word remains.
- Different logo/color palette retaining the word — confusion persists.
- Arguing "it's software, not insurance" — category context, features, and marketing language still overlap (§1 Trade Marks Act, India).

### Naming territories to AVOID (from the report's design brief)

The "Cover + adjective" family is crowded in the insurance category: CoverSure, CoverWise, Coverfox, Cover360. The replacement name should be a **coined or unexpected word with no insurance-industry meaning**, distinctive enough to create legal and search leverage.

### Release gate (the report's hard stop)

Per the report's §7, **do not publish until all six are true:**
1. Final candidate cleared
2. Counsel trademark search completed (Classes 9, 36, 42 — India; plus target foreign jurisdictions before expansion)
3. Word-mark filing strategy agreed
4. Domains + core handles secured
5. Mobile + auth identities migrated
6. Store metadata + legal pages contain ONLY the new brand

**This release gate is now the canonical launch gate for any public-facing release.** It supersedes any earlier "ship under CoverWise" assumption.

### Limitations acknowledged

The report is a preliminary commercial/legal-risk clearance, not a formal legal opinion. India's IP India registry is interactive and was not directly queryable through the research environment; UK/EU records surfaced via secondary databases (TrademarkElite) and must be rechecked at UKIPO/EUIPO. The strong rename recommendation stands regardless, because the business case does not depend on a single registry outcome.

---

## Why this exists

The founder stated: *"CoverWise is a set of different products, same and different markets, same industry, so I am working on the naming and we will have to refactor so many things — start making that list."*

Combined with the independent clearance report's verdict, this document:
1. Records the rename decision and its evidence base (§0 above).
2. Frames the naming decision first-principles (company vs product vs app layering).
3. Inventories **every** occurrence of the current brand so the refactor is complete, not partial.
4. Defines the dependency order so nothing breaks during the rename.
5. Does NOT pick a name — that is the founder's decision, bounded by the report's design brief and clearance funnel. It prepares the ground so that once the name is chosen, execution is mechanical.

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

## 2. Naming criteria (first-principles, informed by the clearance report)

A good name for this product portfolio must satisfy, in priority order:

1. **Legally clearable** — official trademark search in India (IP India, Classes 9 + 36 + 42) plus target foreign jurisdictions before any expansion. This is the hard gate; nothing else matters if the name is blocked. The report explicitly warns that India's registry must be queried directly (exact, phonetic, contains, proprietor, device-mark), not via secondary aggregators.
2. **Not a collision or near-collision** — must not be exact, phonetic, semantic, or visually confusable with any existing finance/insurance product, especially in India. CoverSure/CoverWise is the cautionary case.
3. **Coined or unexpected** (from the report's design brief) — a word with no insurance-industry meaning creates legal and search leverage. **Avoid the "Cover + adjective" family entirely** (CoverSure, CoverWise, Coverfox, Cover360 — all crowded [S2, S21, S22]). Avoid "Policy + generic noun," "Insure + adjective," "Claim + helper" unless genuinely distinctive.
4. **Does not imply regulated activity** — consistent with the permanent non-regulated boundary (`docs/audits/coverwise_product_strategy...2026-07-18.md` §1). Avoid *advise, broker, agent, counsel, insure, claim-filing*.
5. **Survives across products and markets** — the portfolio name can't be so specific to insurance that it blocks a future product. This is exactly why "Cover" is the wrong root.
6. **Survives spoken referral** — must remain unambiguous when spoken in Indian English, Hindi, and major regional accents. The report flags this explicitly; "CoverWise" vs "CoverSure" fails it.
7. **Domain + handles available** — `.app`, `.in`, `.com` plus core social handles. Treated as a **secondary** signal per the report: select on trademark clearance + market collision + store uniqueness + memorability *together*, not domain availability alone.
8. **Package-ID-safe** — must form a valid reverse-DNS identifier (lowercase, no hyphens in Java/Kotlin package segments, valid DNS).

### Candidate clearance funnel (from the report's §6)

1. Generate 30–50 candidates across at least three naming territories.
2. Reject exact, phonetic, semantic, and visual collisions via web + app-store searches.
3. Check domains and social handles (secondary signal).
4. Run **official** trademark searches (IP India, Classes 9/36/42) for exact + phonetic variants; add foreign jurisdictions before expansion.
5. Have Indian trademark counsel review the final 3–5 candidates + goods/services descriptions.
6. Secure word mark, domains, core handles, and production app identity before any public announcement.

This doc does **not** recommend a name. It establishes the criteria so the founder can evaluate candidates through the funnel above.

---

## 3. What this rename is NOT — and what it now IS

- **Not a re-architecture.** No code behavior changes. Pure identifier + string surgery.
- **No longer optional.** The clearance report upgrades this from "founder preference" to "release gate." The report's verdict is RED/90+; keeping CoverWise publicly is REJECT. The only acceptable use of "CoverWise" going forward is as a **temporary internal codename** (repo/project label) until the migration completes, then it disappears from all user-facing identity.
- **Time-pressured, not leisurely.** The rename cost is LOW *now* (no public launch, no paying customers, no filed trademarks). It becomes HIGH-to-permanent after first store submission. RC product IDs and the package ID cannot be renamed once a paying customer or published listing exists. This is the cheapest point in the product's life to rename.
- **Not all-or-nothing for internal continuity.** The soft layer (docs, UI strings) can be renamed in a later pass. But the hard layer (package ID, RC products, domain, store listing) MUST be coherent and cleared before any public release per the report's §7 release gate.

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
1. Run the candidate clearance funnel (§2) — generate 30–50 candidates, reject collisions.
2. Pick portfolio name + app name + domain.
3. **Official trademark search** (IP India, Classes 9 + 36 + 42) for the final 3–5 candidates — exact + phonetic variants. This is non-negotiable per the clearance report.
4. Indian trademark counsel reviews the chosen name + goods/services descriptions.
5. Decide package-ID scheme: `com.<app>` (simple) vs `com.<portfolio>.<app>` (multi-product-ready).
6. Agree word-mark filing strategy.

### Stage 1 — External systems first (founder + agent)
These must exist before code can reference them:
1. Register domain + DNS.
2. File/secure the word mark per counsel's strategy.
3. Secure core social handles.
4. Apple App ID + Google Play app record (new application ID).
5. RevenueCat project + product IDs (new scheme).
6. Supabase: decide bucket (keep `coverwise-documents` internally, or migrate).
7. DockerHub / ECR new repo names (if aligning infra).

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
4. Legal docs — legal review + version bump + re-host.
5. Grafana / Prometheus labels.
6. Frontend HTML/SEO.

### Stage 4 — Verification + release gate
1. `flutter analyze` clean.
2. `flutter test` green.
3. Backend tests green.
4. Fresh release build installs without conflict with old app (different application ID).
5. Deep links resolve under new scheme.
6. RevenueCat purchase flow works with new product IDs in sandbox.
7. **The clearance report's six-point release gate (§0) is satisfied before any public submission:**
   (a) final candidate cleared; (b) counsel search completed; (c) word-mark filing strategy agreed; (d) domains + core handles secured; (e) mobile + auth identities migrated; (f) store metadata + legal pages contain ONLY the new brand. **No public release until all six are true.**

---

## 6. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| **Shipping publicly as CoverWise at all** | **CRITICAL** | Per clearance report: RED/90+. Rename before any public store listing. Keeping is REJECT, not a viable option. |
| **CoverSure confusion** (near-homophone, same category, IRDAI-registered) | **CRITICAL** | Pick a coined name outside the "Cover-*" family; report §6 design brief. |
| **Trademark complaint from Coverwise Limited (UK) or other exact-name users** | High | Official registry search + counsel review before committing; report sources S6–S12. |
| Renaming RC product IDs after first paying customer | **Permanent** | Rename before launch (now) — this is the strongest time-pressure argument |
| Partial package-ID change bricks installs | High | Atomic Stage-2 PR; test install on clean device |
| Bucket rename loses production documents | High | Keep bucket name internal; don't rename |
| Missed env var reader → silent empty value | Medium | Grep + CI smoke test that asserts required envs non-empty |
| Trademark collision discovered post-launch | High (legal) | Official IP India search (Classes 9/36/42) BEFORE committing to the replacement name |
| `parser_version` rename breaks model lineage | Medium | Verify against `model_lineage` table; keep version tag stable if referenced |
| Old deep-link scheme breaks existing shared links | Low (pre-launch) | No users yet — free to change |
| **Suffix "fix" (CoverWise AI / App / India) mistaken for a cure** | High | Explicitly rejected by report §4 — does not cure the dominant-word collision |

---

## 7. Anything else? (motto §0.1.1)

**Yes — cross-cutting items the per-section analysis didn't cover:**

1. **The clearance report is preliminary, not a legal opinion.** Its strong rename recommendation stands on the business case (permanent confusion tax) and does not depend on a single registry outcome. But the formal clearance of the *replacement* name requires direct IP India registry search (exact, phonetic, contains, proprietor, device-mark) plus counsel review — secondary aggregators are not sufficient. Budget for counsel time on the final 3–5 candidates.

2. **The competitor (CoverSure) is IRDAI-registered (corporate agent CA0894, valid through 9 Jan 2027).** This matters strategically, not just legally: a regulated entity has more incentive and standing to police look-alike names. The rename removes that exposure entirely.

3. **Store publisher name.** Google Play "Developer name" and Apple "Developer name" are visible to every user. Currently this would be an individual name or PSRS Technologies. The publisher name is part of the brand perception and should be decided alongside the product name.

4. **Localization of the brand name itself.** Should the app name be translated in hi/ta/gu/mr, or kept in English across all locales? Most Indian apps keep the brand in English. Confirm policy so the ARB files are consistent. (Current code keeps "CoverWise" untranslated in all ARBs — correct default, carry forward to the new name.)

5. **The slogan / motto_v4 reference.** `motto_v4.md` itself is the engineering doctrine, not a product artifact — it should NOT be renamed even if the product is. It stays as the canonical engineering doctrine regardless of product name.

6. **The `medpiper` parent path is RESOLVED.** Per founder directive (§9), medpiper is eliminated entirely; the project goes under Pranay's personal portfolio. The on-disk repo path `medpiper/insurance_app` can be renamed when convenient — no code depends on it as a literal.

---

## 8. What I need from the founder to unblock execution

1. **The chosen names** (portfolio + app), after running the candidate clearance funnel (§2) — generate 30–50 candidates, reject collisions, shortlist 3–5.
2. **Official trademark search result** for the shortlisted names (IP India, Classes 9/36/42) — ideally via counsel.
3. **Domain** (which TLD, after name is chosen).
4. **Package-ID scheme:** `com.<app>` (simple) vs `com.<portfolio>.<app>` (multi-product-ready).
5. **Store publisher name** (individual vs entity).
6. **Infra alignment:** should Docker/AWS move from `insurance_app` to the new name? (Recommended yes, since `insurance_app` will be wrong the moment a second product ships.)

**Already decided (no longer open):**
- Timing: rename **before** public launch (per clearance report — not optional).
- medpiper: eliminated (§9).
- "CoverWise" may remain only as a temporary internal codename until migration completes.

Once 1–6 are answered, the execution is mechanical and I can run Stages 2–4 as gated commits.

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
- 2026-07-28: integrated `CoverWise_Name_Clearance_and_Brand_Risk_Report_2026-07-28.docx`. Status upgraded from "decision pending" to "rename decided (RED/90+)." Added §0 (evidence summary + release gate), rewrote §2 (criteria informed by the report's design brief + candidate funnel), rewrote §3 (rename is now mandatory, not optional), updated §5 (Stage 0/4 incorporate official registry search + six-point release gate), expanded §6 risk register (CoverSure IRDAI status, suffix-rejection), restructured §7/§8 (medpiper resolved, timing decided). The report's §7 release gate is now the canonical launch gate for any public release.
