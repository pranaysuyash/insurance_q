# ADR-2026-07-21-02: Android 16 target baseline and system-owned identity

- **Status:** Accepted
- **Date:** 2026-07-21
- **Owner / next reviewer:** Pranay
- **Decision:** CoverWise compiles and targets Android 16 (API 36), while
  retaining `minSdk = 23`. Android 17 (API 37) is treated as a preview
  compatibility lane until its platform and Play policy status are final.
- **Related artifacts:**
  [`mobile/android/app/build.gradle.kts`](../../mobile/android/app/build.gradle.kts),
  [`mobile/android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml`](../../mobile/android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml),
  [`mobile/test/asset_integrity_test.dart`](../../mobile/test/asset_integrity_test.dart),
  [`docs/review/evidence/android16-platform-qa-2026-07-21/`](../review/evidence/android16-platform-qa-2026-07-21/).

## Context

The app compiled with API 36 but targeted API 35. That is architectural drift:
the build could see Android 16 APIs without adopting Android 16 behavior,
privacy, and security contracts. Current Google Play policy requires API 36 for
new mobile-app submissions and updates. Android 12's system splash and Android
13's themed-icon APIs remain live contracts on current Android versions; they
are not legacy decoration.

The operator directed this work to be completed to the long-term, first-
principles standard rather than left as an audit caveat.

## Options considered

1. **Leave `targetSdk = 35`. Rejected.** This misses the current Play baseline
   and hides Android 16 behavior changes until distribution.
2. **Target Android 17/API 37 now. Rejected for release baseline.** It is a
   current preview compatibility lane and carries additional behavior changes.
   Adopt it after a dedicated compatibility review, not as an incidental icon
   patch.
3. **Target Android 16/API 36 now and retain Android 17 as a compatibility
   lane. Chosen.** It satisfies current distribution policy and scopes change
   management to the stable baseline.

## Chosen path

1. Set `targetSdk = 36` alongside the existing `compileSdk = 36`.
2. Preserve Android 6+ support through `minSdk = 23`.
3. Keep the v26 adaptive icon for Android 8+ and add a v33 icon resource that
   names the alpha-only monochrome drawable directly. Android 13+ launchers
   select that resource when Material You themed icons are enabled, while older
   Android versions retain their existing adaptive layers.
4. Declare `android:roundIcon` against the same canonical adaptive icon, so
   Android surfaces that request a round icon do not depend on fallback
   selection.
5. Gate the build contract, Android 12 splash attributes, icon declarations,
   and v33 monochrome resource in `asset_integrity_test.dart`.
5. Verify on a clean Android 16/API 36 Google APIs Pixel emulator, with a fresh
   install, system themed icons enabled, a cold app launch, and native resource
   inspection of the packaged APK.

## Validation and evidence

- `flutter test test/asset_integrity_test.dart` passes with the Android 16
  target/splash/themed-icon gates.
- `flutter analyze` passes.
- `flutter build apk --debug` passes and installs on Android 16/API 36.
- The system splash and the first onboarding surface were captured on the clean
  API 36 emulator. The app's target SDK is reported as 36 by `dumpsys package`.
- The launcher configuration's `Themed icons` control was enabled and Android
  16's home screen visibly rendered system icons in the selected Material You
  palette. The packaged v33 resource was inspected with `aapt2` and contains a
  direct `monochrome` drawable reference.

The emulator does not permit pinning the third-party CoverWise activity to its
home workspace through ADB, so this session cannot show the launcher's tinted
CoverWise glyph in a home-screen screenshot. That is a Tier 1 packaged-resource
proof plus Tier 4 system-mode proof, not a claim of a direct CoverWise themed
icon observation. A physical Pixel or launcher-controlled home placement is the
remaining Tier 4 closure for that one visual assertion.

## Rollback

Revert the `targetSdk` line and v33 resource only if Android 16 testing exposes
a release-blocking behavioral incompatibility. Do not remove the v26 adaptive
icon or the Android 12 splash contract: those are required across supported
versions.

## Update log

- **2026-07-21 — Accepted.** Triggered by the operator: “so do it properly,
  have i not been saying long term 1st principles motto_v4 aligned”. Replaced
  the prior audit-only stance with a stable Android 16 target, runtime test,
  and regression gates.
- **2026-07-21 — Completeness correction.** Explicitly set
  `android:roundIcon` to the canonical adaptive launcher resource and covered
  both icon declarations in the asset-integrity gate.

## Anything else?

Yes. Android 17/API 37 should receive a dedicated compatibility run once local
build storage is available. The current workspace has 1.8 GiB free after
provisioning the Android 16 emulator, which is insufficient for another system
image without risking unrelated work. This is a documented environmental limit,
not a reason to weaken the Android 16 release contract.
