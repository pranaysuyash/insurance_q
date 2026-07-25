# insurance_app issue review - 2026-07-25

## Scope

Mobile leak-capture readiness for Android and iOS.

## What I verified

- Android app build now gets past the Kotlin/Sentry compile failures after updating the app Android Gradle DSL and the cached `sentry_flutter` plugin to use Kotlin 1.8 language level.
- iOS app build now gets past the earlier Sentry Swift compile failure after updating the cached `sentry_flutter` iOS/macOS plugin call to `imageByAddress(_:)`.
- The app shell and the obvious timer/subscription-heavy screens inspected so far dispose their timers/controllers/subscriptions correctly.

## Blocking issues

1. Android emulator does not stay attached long enough for a stable `adb` device during the launch/install phase.
2. iOS simulator on this machine is iOS 26.2 arm64-only, and the current ML Kit pods pulled in by `google_mlkit_commons` / `google_mlkit_text_recognition` do not ship arm64 simulator support.

## Evidence

- Android build completed once the Kotlin/Sentry compatibility issue was patched.
- iOS build now stops at:
  - `GoogleMLKit`
  - `MLImage`
  - `MLKitCommon`
  - `MLKitVision`
  - missing arm64 simulator support for iOS 26+.

## Likely next steps

- Android:
  - Stabilize emulator attachment or use a physical device.
  - Then run the Android heap capture script against the live package.
- iOS:
  - Replace the current ML Kit-based iOS path with an arm64-simulator-compatible OCR stack, or test on a physical device.

## Notes

- No confirmed runtime leak was captured in this session yet.
- The cleanup paths in the inspected screens look correct; the remaining blockers are platform/toolchain compatibility, not an obvious missing `dispose()`.
