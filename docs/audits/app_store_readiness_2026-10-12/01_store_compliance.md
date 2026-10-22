# 01 Store Compliance and Build Configuration Audit (CoverWise mobile)

**Date:** 2026-10-12
**Lane:** Store compliance and build configuration (iOS App Store + Google Play)
**Scope:** `mobile/` Flutter app in `/Users/pranay/Projects/medpiper/insurance_app`
**Mode:** Read-only static inspection. No existing files edited, no git commands, no builds, no installs. The only file written is this report.
**Evidence tier:** Tier 1 (static inspection) for most findings. Tier 2 for one check: `tools/validate_legal_release_assets.py` was run read-only and exited 0.
**Test sensitivity:** Not applicable (no tests run for findings; the validator is a preflight script, not a regression test).

## 1. Summary

- **iOS is not submittable as the code stands.** Two apps-review blockers: Google sign-in is offered with no Sign in with Apple (Guideline 4.8), and the in-app purchase flow has no Restore Purchases control (Guideline 3.1.1). A missing `PrivacyInfo.xcprivacy` and the absence of any iOS release script add further risk.
- **Android is closer, but the signing and release path has a silent-failure hole.** A direct `flutter build appbundle --release` silently signs with the debug keystore unless `COVERWISE_RELEASE_BUILD=true` is set. The Android-only release script does set it, so the script path is safe.
- **Play needs a web account-deletion link** in addition to the in-app deletion that exists.
- **The privacy policy under-discloses vendors.** It does not name RevenueCat, Google OAuth, or Sentry. The packaged copy must stay byte-identical to the publishable source (the validator enforces this).
- **Build identity is consistent and mostly sound.** Bundle/application ID `com.coverwise.app`, version `0.1.2+11`, targetSdk 36, iOS deployment target 16.0, icon set complete, ATS default, and backup disabled all check out.
- **Totals:** 3 BLOCKER, 4 HIGH, 6 MED, 4 LOW findings, plus 6 PASS items (see Section 2).

## 2. Findings table

Severity: BLOCKER (submission will be rejected or the build is unsafe), HIGH (likely rejection or serious risk), MED (should fix before submission), LOW (hygiene).

| ID | Sev | Platform | File:line | Issue | Fix |
|---|---|---|---|---|---|
| STORE-01 | BLOCKER | iOS | `mobile/lib/screens/account_screen.dart:231-239`; `mobile/lib/services/auth_service.dart:619-631` | "Continue with Google" is shown on all platforms, gated only by `hasSupabaseAuthConfig`. No Sign in with Apple exists: `pubspec.yaml` has no Apple sign-in package, and `mobile/ios/Runner/` has no `*.entitlements` file. Guideline 4.8 requires an equivalent login when a third-party social login is offered. | Add Sign in with Apple (Supabase `signInWithIdToken` or OAuth Apple provider) with the `com.apple.developer.applesignin` entitlement and token revocation on account deletion. Alternatively, hide Google on iOS. Decide before submission. |
| STORE-02 | BLOCKER | iOS | `mobile/lib/services/billing_adapter.dart:328-330` (`restorePurchases`); no caller in `mobile/lib/` | The restore method exists but nothing in the UI calls it. Guideline 3.1.1 requires a visible Restore Purchases mechanism for apps that sell subscriptions or non-consumables. | Add a "Restore purchases" action to `mobile/lib/screens/upgrade_screen.dart` (and paywall) that calls `billing.restorePurchases()`. |
| STORE-03 | BLOCKER | iOS | `mobile/ios/Runner/` (no `PrivacyInfo.xcprivacy`; `find` across `mobile/ios` returned nothing) | No app-level privacy manifest. The app uses required-reason APIs through Hive, shared preferences, and path_provider (for example file timestamps and UserDefaults). Apple requires declared reasons, and missing manifests generate upload warnings and can block review. Plugin manifests cover plugin usage only. | Add `mobile/ios/Runner/PrivacyInfo.xcprivacy` declaring tracking = false, the collected data types actually used, and the required-reason API categories found by a scan. Verify with an Xcode archive (UNVERIFIED here). Severity is set to BLOCKER because Apple now enforces it on upload. |
| STORE-04 | HIGH | Android | `mobile/android/app/build.gradle.kts:18,26,75-79` | Release signing falls back to the debug keystore unless `key.properties` contains `keyAlias`. The production guard (line 26) only fires when env `COVERWISE_RELEASE_BUILD=true`. A plain `flutter build appbundle --release` therefore silently produces a debug-signed bundle, which Play rejects, or which ships with the wrong key. | Make the release task fail when `key.properties` is missing, rather than only when the env var is set. Keep the debug fallback only for `debug` builds. |
| STORE-05 | HIGH | iOS (and cross-platform config) | `mobile/ios/Runner.xcodeproj/project.pbxproj` (no `DEVELOPMENT_TEAM` anywhere; `CODE_SIGN_STYLE` appears only on the RunnerTests target at lines ~503/521/537; Release `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` at lines ~454/577/634); `tools/build_mobile_release.sh:92-104` is Android-only (`flutter build appbundle`) | **Confirmed: there is no iOS release script equivalent to the Android key.properties guard.** The only release wrapper is `tools/build_mobile_release.sh`, which builds an AAB. There is no `flutter build ipa`, no `ExportOptions.plist`, no fastlane, and no team set on the Runner target. Separately, a release build without the `--dart-define`s throws at launch (`app_config.dart:192-216` requires `API_BASE_URL`; `app_config.dart:381-473` validates privacy/ToS/support email/version; called from `lib/bootstrap/app_bootstrap.dart:86`). An iOS archive from Xcode or a bare `flutter build ipa` would therefore crash on launch. | Add `tools/build_ios_release.sh` mirroring the Android script: same required env vars, same placeholder checks, `flutter build ipa --release` with all `--dart-define`s, and an `ExportOptions.plist`. Set `DEVELOPMENT_TEAM` and automatic signing on the Runner target. |
| STORE-06 | HIGH | Google Play | Not in Play listing; Play policy (UNVERIFIED live text) | Apps that allow in-app account creation must also provide a web-accessible account-deletion resource. Only in-app deletion exists (`mobile/lib/screens/profile_screen.dart:193,260,515-520`, `settings_screen.dart:256-279`). The privacy policy describes deletion only as "Account deletion request" (`mobile/assets/legal/privacy_policy.md:56,73`). | Publish a web deletion request page (for example on coverwise.app) and link it from the Play Data Safety form and the privacy policy. |
| STORE-07 | HIGH | iOS + Play | `mobile/assets/legal/privacy_policy.md:34-49` (vendor table lists Supabase and OpenAI only); grep for RevenueCat, Sentry, Google, Apple returned 0 hits | The disclosed vendors are incomplete. The app also uses RevenueCat (purchases, `billing_adapter.dart`), Google OAuth (`auth_service.dart:627`), and Sentry (when `SENTRY_DSN` is set, `app_bootstrap.dart:60`). Guideline 5.1.1(i) and the Play Data Safety form need these disclosed. | Update the publishable source `docs/legal/privacy_policy.md` first, then copy it byte-identically to `mobile/assets/legal/privacy_policy.md`. The validator (`tools/validate_legal_release_assets.py:38-40`) fails on any mismatch, so both must change together. |
| STORE-08 | MED | Android | `mobile/pubspec.yaml` (`camera: ^0.12.0`); no `package:camera/` import found in `mobile/lib`; camerax plugin manifest declares `CAMERA`, `RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE` (`~/.pub-cache/.../camera_android_camerax-0.7.4+2/android/src/main/AndroidManifest.xml`) | The camera plugin is a dependency but is not imported by app code (image capture uses `image_picker`, `claims_workflow_sheet.dart:148,155`). Its manifest still merges `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` into the app. Play requires a justification for sensitive permissions such as microphone access, and `WRITE_EXTERNAL_STORAGE` is obsolete. | Remove the `camera` dependency if unused. Otherwise add `tools:node="remove"` for `RECORD_AUDIO` and `WRITE_EXTERNAL_STORAGE` in `mobile/android/app/src/main/AndroidManifest.xml`. Verify the merged manifest after a build (UNVERIFIED). |
| STORE-09 | MED | iOS | `mobile/lib/screens/upgrade_screen.dart:137,147`; `mobile/lib/l10n/app_en.arb:307-311` | Subscription disclosures are thin. The copy covers plan changes and cancellation, but the paywall does not visibly state auto-renewal, the billing period, or links to Terms and Privacy. Guideline 3.1.2(a) requires these on the purchase screen. | Add auto-renew, price per period, and Terms/Privacy links on the purchase surface. Rendering not verified (static only). |
| STORE-10 | MED | iOS | `mobile/lib/config/app_config.dart:385` (`validateReleaseConfiguration` returns early when `environment == development`); `app_config.dart:65-67` (default `ENVIRONMENT` is production only when `kReleaseMode`) | A release-mode binary built with `--dart-define=ENVIRONMENT=development` skips all release validation and permits `http://localhost:8000` (`app_config.dart:213-215`). No code-level guard rejects this combination. The release script hard-codes production (`tools/build_mobile_release.sh:93`), so the risk is for manual builds. | Make `validateReleaseConfiguration` throw when `kReleaseMode && environment == development`. |
| STORE-11 | MED | Both | `mobile/assets/legal/terms_of_service.md:17-23,117`; `privacy_policy.md:10,111` | Disclaimers ("not insurance, financial, or legal advice"; "not an insurer or broker") exist in the legal documents but not in the app UI. Grep of `mobile/lib` for "not insurance advice", "informational", and "not an insurer" found no in-app copy. Reviewers and regulators may expect the disclaimer where coverage answers appear. | Surface a short disclaimer on Q&A, claims, and paywall screens. Flag for legal review, since wording must match ADR-2026-07-19-13 and the product's refusal list. |
| STORE-12 | MED | iOS | `mobile/ios/Runner/Info.plist` (no `ITSAppUsesNonExemptEncryption` key; grep count 0) | Without this key, App Store Connect asks an export-compliance question on every upload. The app uses HTTPS only, which is typically exempt. | Add `<key>ITSAppUsesNonExemptEncryption</key><false/>` after confirming the encryption position with the owner. |
| STORE-13 | MED | Android | `mobile/android/app/build.gradle.kts:80-81` (`isMinifyEnabled = false`, `isShrinkResources = false`); `mobile/android/app/proguard-rules.pro:31-41` | R8 is off, so there is no shrinking or obfuscation in release. The ProGuard rules reference `dio`, `file_picker`, and `code_scanner` packages, which look stale. | Enable R8 and shrink resources, and prune stale keep rules. Re-verify the release build (UNVERIFIED). |
| STORE-14 | LOW | iOS | `mobile/ios/Runner/Info.plist:42-49` | `NSBonjourServices` (`_dartobservatory._tcp`) and `NSLocalNetworkUsageDescription` ("...for development and debugging purposes") are development-only, but they ship in the release plist. Reviewers may question a local-network permission prompt. | Move to a debug-only plist or build configuration. |
| STORE-15 | LOW | Repo hygiene | `mobile/android/app/upload-keystore.jks` (untracked, ignored by `mobile/android/.gitignore:14`); `mobile/android/key.properties.example:33` expects `coverwise-upload.jks` | The upload keystore sits inside the working tree. It is correctly git-ignored and untracked, but its filename does not match the example. | Confirm an off-machine backup exists. Align the file name with `key.properties` when the real file is created. Never commit it. |
| STORE-16 | LOW | Repo hygiene | `mobile/.dartdefine.env` (git-tracked; contains only `API_BASE_URL=https://api.coverwise.app`) | Tracked and contains no secret, which is fine. It is incomplete for release: the required privacy, ToS, support-email, and version defines are missing (see STORE-05). | Keep as a development template, and rename or annotate it so it is not used as a release define file. |
| STORE-17 | LOW | Android | `mobile/android/app/src/main/AndroidManifest.xml:52-58` | `InstallReferrerReceiver` is `exported="true"` with the Play `INSTALL_REFERRER` action. The class exists (`mobile/android/app/src/main/kotlin/com/coverwise/app/InstallReferrerReceiver.kt`). Behavior is expected; noted for the data-safety declaration. | Confirm the data-safety form mentions install-referrer analytics if it stores UTM values. |
| STORE-PASS-01 | PASS | Android | `mobile/android/app/build.gradle.kts:38,64`; `mobile/pubspec.yaml:19` | `compileSdk = 36` and `targetSdk = 36` meet the current Play target-API baseline (the live deadline is UNVERIFIED). `versionCode` 11 and `versionName` 0.1.2 derive from `0.1.2+11`. | None. |
| STORE-PASS-02 | PASS | Both | `mobile/android/app/build.gradle.kts:58` (`com.coverwise.app`); `mobile/ios/Runner.xcodeproj/project.pbxproj:672,694` (`com.coverwise.app`); `mobile/ios/Runner/Info.plist:13-18` | Application ID and bundle ID are consistent across platforms. Display name is "CoverWise" on both platforms. | None. |
| STORE-PASS-03 | PASS | iOS | `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` (iPhone 2x/3x, iPad 1x/2x, 83.5 and 1024 marketing); `sips` check on `Icon-App-1024x1024@1x.png`: 1024x1024, no alpha | Icon set is complete, and the App Store marketing icon has no alpha channel. | None. |
| STORE-PASS-04 | PASS | iOS | `mobile/ios/Runner/Info.plist:46-51` (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`) | Permission strings are specific and match actual use (`claims_workflow_sheet.dart:148,155` via `image_picker`). No ATS override (`NSAllowsArbitraryLoads` absent), so HTTPS is enforced. `iOS deployment target 16.0` is consistent with `mobile/ios/Podfile:2`. | None. |
| STORE-PASS-05 | PASS | Android | `mobile/android/app/src/main/AndroidManifest.xml:9` (`allowBackup="false"`); no `usesCleartextTraffic` attribute | Backup disabled and cleartext defaults to off. Only `INTERNET`, `POST_NOTIFICATIONS`, and the merged plugin permissions are declared (see STORE-08). | None. |
| STORE-PASS-06 | PASS | Both | `tools/validate_legal_release_assets.py` (run, exit 0: "legal release assets are complete and match the packaged documents."); `mobile/lib/screens/profile_screen.dart:193-275` | Legal placeholder check passes, packaged privacy/ToS files match their publishable sources, and in-app account deletion is reachable from the profile screen. The paid-feature payment method is StoreKit/Play Billing via RevenueCat (`billing_adapter.dart:261,293`); no external web checkout was found in `paywall_screen.dart`, `upgrade_screen.dart`, or `billing_adapter.dart`. | None (verify RevenueCat dashboard configuration; see UNVERIFIED). |

Apple 4.2 (minimum functionality): the app has substantial features (document ingestion, grounded Q&A, renewal calendar, claim vault). Low rejection risk on this axis. Not a finding.

## 3. Platform checklist (condensed)

| Check | iOS | Android |
|---|---|---|
| Bundle/application ID | PASS (STORE-PASS-02) | PASS |
| Version/build | `0.1.2` / `11` via `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)` (Info.plist:21-39) | PASS (`versionCode` 11) |
| Privacy manifest | BLOCKER (STORE-03) | n/a (Data Safety form UNVERIFIED) |
| Permission strings | PASS (STORE-PASS-04); no microphone string needed as no mic capture found | MED (STORE-08) |
| Icons | PASS (STORE-PASS-03) | Adaptive icon present (`mipmap-anydpi-v26/ic_launcher.xml`) |
| Launch screen | Storyboard present (`LaunchScreen.storyboard`); rendering UNVERIFIED | Launch theme in manifest (`@style/LaunchTheme`) |
| ATS / cleartext | PASS | PASS |
| Entitlements | BLOCKER gap (STORE-01: no SIWA entitlement) | n/a |
| Deployment / min SDK | iOS 16.0 (PASS) | `minSdk = flutter.minSdkVersion` (not pinned; UNVERIFIED value) |
| Signing | HIGH gap (STORE-05): no team, manual identity, no release script | HIGH (STORE-04): debug fallback |
| R8 / obfuscation | n/a | MED (STORE-13) |
| In-app account deletion | PASS (profile_screen.dart:193-275) | PASS; web link missing (STORE-06) |
| Privacy policy URL in app | Present (`privacy_security_screen.dart:92`, `about_screen.dart:106`), gated on `PRIVACY_POLICY_URL` define | Same |
| Sign in with Apple | Missing (STORE-01) | n/a |
| Restore purchases | Missing (STORE-02) | Not required by Play, but Play Billing restore is provided via RevenueCat (UNVERIFIED wiring) |

## 4. Build configuration notes

- **Android release script** (`tools/build_mobile_release.sh`): refuses tracked `key.properties` (lines 76-84), refuses missing `mobile/android/key.properties` (85-88), sets `COVERWISE_RELEASE_BUILD=true` (89), rejects placeholder/example values (44-50), and requires https URLs. It runs `flutter analyze` and `flutter test` before building (90-91). This is the good path. STORE-04 is about the bypass path.
- **iOS release path:** does not exist in the repo. See STORE-05.
- **Hardcoded dev URLs:** the only one in `mobile/lib` is `http://localhost:8000` in `app_config.dart:214`. It is reachable only when `environment == development` or `!kReleaseMode`, so release builds are protected at runtime (STORE-10 covers the override case). No other `localhost`, `127.0.0.1`, or `10.0.2.2` references were found under `mobile/lib`.
- **RevenueCat key:** the app reads `REVENUECAT_API_KEY` from define (`app_config.dart:122-123`). The script rejects `sk_`/`atk_` prefixes (`build_mobile_release.sh:55-58`), which is correct. A single key is used for both platforms; RevenueCat key-per-platform configuration is UNVERIFIED.
- **Legal validator:** `tools/validate_legal_release_assets.py` checks for unresolved markers (`[Jurisdiction]`, `[Company Name]`, `[Controller Name]`, `[Legal Entity]`), byte-equality between `docs/legal/*.md` and `mobile/assets/legal/*.md`, and a disallowed product-role phrase ("information broker") in ToS. It passes. It does not check for vendor completeness (STORE-07), so passing it is not evidence that the privacy policy is complete.
- **Hosted legal check:** `tools/verify_hosted_legal_documents.py` requires https URLs and checks the final redirect target. It was NOT executed (it performs network I/O).

## 5. Recommended order of work

1. STORE-01 and STORE-02 (iOS blockers): decide Sign in with Apple versus hiding Google on iOS, and add a Restore Purchases control.
2. STORE-03 and STORE-05: add `PrivacyInfo.xcprivacy`, set signing, and create `tools/build_ios_release.sh`.
3. STORE-04 and STORE-06: harden the Android signing fallback, and publish a web deletion link.
4. STORE-07: update the privacy policy source, then copy it to the packaged asset and re-run the validator.
5. STORE-08 to STORE-13: permissions, subscription copy, disclaimers, release guard, R8.
6. LOW items in any order.

## 6. Owner decisions required

- **Google on iOS (STORE-01):** add Sign in with Apple, or remove Google from iOS. This changes the auth surface and needs an owner decision.
- **Disclaimer placement and wording (STORE-11):** legal review required. Must stay consistent with ADR-2026-07-19-13 and the product's refusal list.
- **Encryption export answer (STORE-12):** the owner confirms the answer before setting the key.
- **Camera plugin removal (STORE-08):** confirm the camera capture path is not planned before removing the dependency.

## 7. UNVERIFIED list

1. **Xcode archive and signing:** no build or archive was run. Signing identity, provisioning, and the Xcode/iOS SDK version (required to be a current SDK by Apple) are UNVERIFIED. The Flutter SDK version could not be derived from the `.metadata` revision `ea121f8859e4b13e47a8f845e4586164519588bc` without a Flutter binary.
2. **Merged Android manifest:** the permission list in STORE-08 comes from plugin manifests in `~/.pub-cache` for the resolved versions, not from a merged build manifest. Verify with `build/app/intermediates/merged_manifest`.
3. **Live store policy text:** Apple Guidelines 3.1.1, 3.1.2, 4.8, 5.1.1(i), 5.1.1(v), and the Google Play account-deletion web-resource rule and current target-API deadline were NOT checked against live sources (no web lookup performed). Findings reflect the stated guideline numbers and should be re-confirmed against current text.
4. **Play Data Safety and App Store privacy nutrition labels:** not present in the repo; not verified.
5. **App Store Connect and Play Console metadata:** product IDs, RevenueCat dashboard offerings, and per-platform RevenueCat keys are not inspectable from the repo.
6. **Paywall rendering:** subscription disclosure (STORE-09) is based on static strings only. No rendering was performed.
7. **Restore wiring on Android:** whether RevenueCat restore is reachable on Play was not confirmed beyond the absence of a UI caller.
8. **Launch screen rendering:** `LaunchScreen.storyboard` and `LaunchBackground.imageset` were not visually inspected.
9. **Plugin privacy manifests:** only the existence of pods in `ios/Pods` was checked, not the contents of each plugin's privacy manifest.
10. **Required-reason API usage in app code:** no scan of `lib/` for `UserDefaults`, file timestamp, disk space, or boot-time APIs was performed. STORE-03 is based on the plugin stack.
11. **Hosted privacy and ToS pages:** the live URLs were not fetched. `verify_hosted_legal_documents.py` was not executed.
12. **Sentry in production:** whether `SENTRY_DSN` is set in release builds is UNVERIFIED. The STORE-07 disclosure applies only if it is.
13. **Google sign-in reachability on iOS in production:** depends on the production `SUPABASE_URL` / publishable key. Not verified.
14. **`minSdk`:** the effective value comes from the Flutter SDK default and was not verified.

## 8. Commands run (all read-only)

- `grep`, `find`, `ls`, `cat`, `sed`, `awk`, `sips -g` on the repo and `~/.pub-cache` (read only).
- `git ls-files` and `git check-ignore` (read only).
- `python3 -B tools/validate_legal_release_assets.py` (exit 0). `-B` avoids writing bytecode.
- One unintended side effect: an earlier `pkill -f "grep -rl"` attempt was broader than intended and may have terminated unrelated `grep` processes owned by the same user. It affected no files.

## 9. Files changed

- Created: `docs/audits/app_store_readiness_2026-10-12/01_store_compliance.md` (this file).
- Created directory: `docs/audits/app_store_readiness_2026-10-12/`.
- No existing files were edited. No git state changed. No builds or installs were run.

## 10. Uncommitted work

This report is new and uncommitted. Pre-existing working-tree changes in the repository (the `git status` snapshot at session start lists many modified files) were left untouched.
