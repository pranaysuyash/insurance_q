# Go-Live Readiness Audit & Fixes — 2026-07-11

## Addendum to technical_decisions.md

This document records the go-live readiness audit performed on the CoverWise
mobile app (`mobile/`) and the decisions made to resolve blockers found.
Evidence tiers follow motto_v3 §0.5.

---

## 1. Android build was completely broken (BLOCKER — fixed)

**Evidence:** Tier 1 (static) + Tier 2 (targeted build). `flutter build apk`
failed before any changes.

**Root cause:** The Kotlin Gradle plugin was pinned to `1.8.22`
(`settings.gradle.kts`) while `share_plus-12.0.2` ships classes compiled with
Kotlin `2.2.0` metadata. The Kotlin 1.8 compiler cannot read 2.2.0 metadata, so
`:share_plus:compileDebugKotlin` failed with
`Class 'kotlin.Unit' was compiled with an incompatible version of Kotlin`.

**Resolution:**
- Bumped Kotlin Gradle plugin `1.8.22` → `2.2.0`.
- Bumped Android Gradle Plugin `8.7.0` → `8.9.1` (required by
  `androidx.core:core:1.18.0`).
- Bumped Gradle wrapper `8.10.2` → `8.11.1` (AGP 8.9 minimum).
- Bumped `compileSdk` `35` → `36` (required by `androidx.core:core:1.18.0`).

**Why this path:** These are not optional upgrades — the resolved dependency
graph requires them. Pinning older versions would require downgrading
`share_plus` and other plugins, which is a dead-end (motto §0, §7). Aligning
the toolchain with the dependency graph is the long-term-correct path.

**Verification:** `flutter build apk --debug` succeeds; app launches and runs
(Tier 4 — runtime observed in emulator, PID confirmed, no crashes).

---

## 2. Firebase was half-wired with zero usage (BLOCKER — resolved)

**Evidence:** Tier 1 (static) + Tier 4 (runtime). Logcat from baseline run
(PID 4813):
```
W FirebaseApp: Default FirebaseApp failed to initialize because no default
  options were found. This usually means that com.google.gms:google-services
  was not applied to your gradle project.
I FirebaseInitProvider: FirebaseApp initialization unsuccessful
```

**Findings:**
- `firebase_core`, `firebase_auth`, `firebase_messaging` declared in pubspec.
- AndroidManifest registered `FlutterFirebaseMessagingService` and
  `FlutterFirebaseMessagingInitProvider`.
- **Zero** Dart-side usage: no `Firebase.initializeApp()`, no `FirebaseAuth`,
  no `FirebaseMessaging`, no `DefaultFirebaseOptions`, no `google-services.json`,
  no `GoogleService-Info.plist`, no Gradle google-services plugin applied.
- Result: the `FirebaseInitProvider` ran on every launch, failed, and left
  push/auth completely non-functional — silent dead weight.

**Decision: Strip Firebase entirely.**

**Rationale (first-principles):**
- Motto §11: "do not introduce framework-level abstractions prematurely
  without proven need." No code uses Firebase.
- Motto §7 (Supersession): one source of truth. Half-in is the worst state —
  a manifest referencing a service the build cannot satisfy.
- Motto §0: the long-term-correct product is an offline-first, local-persisted
  insurance assistant (Hive + local storage + graceful degradation). Push
  notifications and server-side auth are a *future* layer, not the current
  product. A future "real Firebase" addition is a clean additive change.
- Keeping dead half-wired infra would be a dead-end workaround, not the
  long-term path (motto §0.7).

**What was removed:**
- `firebase_core`, `firebase_auth`, `firebase_messaging` from pubspec.yaml.
- `<service>` and `<provider>` Firebase blocks from main + debug manifests.
- Orphaned `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK` permissions (only
  served firebase_messaging; no Dart usage).
- Unused `xmlns:tools` namespace from main manifest.

**Verification:** Tier 4 — logcat for the post-fix PID (5261) contains zero
`FirebaseApp`/`FirebaseInitProvider` lines. App runs without crashes.

**Re-adding Firebase later (closure path):** Add a Firebase project, drop in
`google-services.json`/`GoogleService-Info.plist`, apply the
`com.google.gms.google-services` Gradle plugin, add the deps back, and call
`Firebase.initializeApp()` in `main.dart`. This is purely additive.

---

## 3. Default Flutter branding → custom icon + splash (fixed)

**Evidence:** Tier 1. Launcher icons were the canonical `flutter create`
defaults (e.g. `mipmap-xxxhdpi/ic_launcher.png` = 1443 bytes). Splash was a
plain white screen with the bitmap item commented out.

**Resolution:**
- Created a branded CoverWise shield+checkmark icon (`#1565c0` blue).
  Note: flat colors used because ImageMagick's SVG rasterizer does not render
  `<linearGradient>` (verified: gradients render as solid black).
- Added `flutter_launcher_icons` + `flutter_native_splash` as dev deps with
  config blocks in pubspec.yaml.
- Generated adaptive icons (Android 8+), all density buckets, iOS icons (alpha
  removed for App Store compliance), and native splash (incl. Android 12+).

**Verification:** Tier 1 — generated `mipmap-xxxhdpi/ic_launcher.png` is now
9449 bytes with background pixel = `srgb(21,101,192)` (`#1565c0`). Splash
drawables updated by the generator.

---

## 4. Dead error widget + no connectivity awareness (fixed)

**Evidence:** Tier 1. `widgets/shared/error_widget.dart` defined `ErrorWidget`
and `ErrorBanner` with **zero importers** (dead code). The class name
`ErrorWidget` shadows Flutter's built-in `material.ErrorWidget` (the red error
screen renderer) — a latent footgun.

**Resolution:**
- Renamed to `AppErrorView` / `AppErrorBanner` to avoid shadowing.
- Added `connectivity_plus` + a `connectivityProvider` / `isOnlineProvider`.
  Note: `connectivity_plus` ≥ 6.0 returns `List<ConnectivityResult>` (not
  single) — handled correctly.
- Added a reusable `OfflineBanner` widget.
- Wired `OfflineBanner` into the QA screen (the most backend-dependent screen).

---

## 5. Six "coming soon" stubs → real screens / manual family members (fixed)

**Evidence:** Tier 1. Six `SnackBar(content: Text('... coming soon!'))` stubs
in `more_screen.dart` (×4), `dashboard_screen.dart` (×1), `family_screen.dart`
(×1).

**Resolution:**
- Built real screens: `SettingsScreen`, `HelpSupportScreen`,
  `PrivacySecurityScreen`, `AboutScreen` — wired via routes in main.dart.
- **Manual family member management** (initially stripped, then restored after
  user feedback): a dependent who has their own separate policy and isn't named
  in any uploaded document won't be auto-detected — they need manual entry.
  Implemented a full add/delete flow with Hive persistence:
  - `PolicyHolder` extended with a `source` field (`'document'` vs `'manual'`),
    backward-compatible with existing `fromJson` (defaults to `'document'`).
  - `AppStateRepository` stores manual members as a JSON list in Hive.
  - `family_providers.dart` refactored: `autoFamilyMembersProvider` (from docs)
    + `manualFamilyMembersProvider` (from storage) → `mergedFamilyMembersProvider`.
  - `AddFamilyMemberDialog` (name, relationship dropdown, optional DOB picker).
  - Family screen + dashboard show source badges ("Manual" vs "From document"),
    and manual members can be deleted (auto-detected cannot — remove the doc).
  - Verified Tier 4: added a member, force-stopped the app, relaunched — member
    persisted.

---

## 6. Release signing config (wired, needs user action)

**Evidence:** Tier 1. The release build type hardcoded
`signingConfig = signingConfigs.getByName("debug")` — fine for testing, not
Play Store.

**Resolution:**
- Made the release build type conditionally use the release signing config when
  `key.properties` exists, falling back to debug otherwise (local builds work).
- Documented keystore generation in
  `docs/technical/deployment/release_signing.md`.
- Added `*.jks` and `key.properties` to `.gitignore`.

**⚠️ Security finding requiring user decision:** `android/key.properties` (repo
root, not `mobile/android/`) is **tracked in git** and contains signing
passwords (`storePassword=android`, `keyPassword=android`, alias `upload`,
keystore `app/upload-keystore.jks`). The password `android` is weak and is the
well-known debug default. This is a committed secret. Removing it from git
history requires explicit user approval (destructive git operation, motto §3).
**Recommendation:** generate a new strong keystore, rotate, and use
`git filter-repo` / BFG to purge the old file from history.

---

## Summary of files changed

**Build config:**
- `mobile/android/settings.gradle.kts` — Kotlin 2.2.0, AGP 8.9.1
- `mobile/android/gradle/wrapper/gradle-wrapper.properties` — Gradle 8.11.1
- `mobile/android/app/build.gradle.kts` — compileSdk 36, conditional release signing

**Manifests:**
- `mobile/android/app/src/main/AndroidManifest.xml` — removed Firebase blocks + orphaned permissions
- `mobile/android/app/src/debug/AndroidManifest.xml` — removed Firebase blocks

**Dart:**
- `mobile/pubspec.yaml` — removed firebase_*, added connectivity_plus, launcher_icons, native_splash
- `mobile/lib/main.dart` — new routes
- `mobile/lib/providers/connectivity_provider.dart` — NEW
- `mobile/lib/widgets/shared/offline_banner.dart` — NEW
- `mobile/lib/widgets/shared/error_widget.dart` — renamed ErrorWidget → AppErrorView
- `mobile/lib/screens/qa_screen.dart` — OfflineBanner
- `mobile/lib/screens/more_screen.dart` — real screen navigation
- `mobile/lib/screens/settings_screen.dart` — NEW
- `mobile/lib/screens/help_support_screen.dart` — NEW
- `mobile/lib/screens/privacy_security_screen.dart` — NEW
- `mobile/lib/screens/about_screen.dart` — NEW
- `mobile/lib/screens/family_screen.dart` — manual add/delete + source badges
- `mobile/lib/screens/dashboard_screen.dart` — add button + merged provider
- `mobile/lib/screens/add_family_member_dialog.dart` — NEW
- `mobile/lib/models/document_model.dart` — `PolicyHolder.source` field
- `mobile/lib/providers/family_providers.dart` — merged auto + manual providers
- `mobile/lib/services/app_state_store.dart` — manual family members key
- `mobile/lib/services/app_state_repository.dart` — manual member CRUD
- `mobile/lib/config/app_config.dart` — (unchanged; dead `getStableUrl()` noted, low priority)

**Assets:**
- `mobile/assets/branding/` — NEW icon + splash SVGs and PNGs
- Generated launcher icons + splash drawables (Android + iOS + web)

**Docs:**
- `docs/technical/deployment/release_signing.md` — NEW
- `docs/review/go_live_readiness_2026-07-11.md` — THIS FILE
- `.gitignore` — added `*.jks`, `key.properties`

## Remaining (lower priority, not blockers)
- `app_config.dart:92-96` `getStableUrl()` is dead code returning a placeholder.
- Backend health endpoint hardcodes a stale timestamp (`main.py:225`).
- Backend `allow_origins=["*"]` in production (motto §0.8 data/config — should
  be restricted to the app's origin for production).
