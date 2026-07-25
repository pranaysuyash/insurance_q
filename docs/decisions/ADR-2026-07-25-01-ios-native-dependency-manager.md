# ADR-2026-07-25-01: Use CocoaPods as the single iOS native dependency manager

- Status: Rejected after validation; no project build-setting change retained
- Date: 2026-07-25
- Owner: Mobile/platform
- Next reviewer: Pranay

## Context

Flutter 3.44 enables Swift Package Manager by default and falls back to
CocoaPods for plugins that do not support SwiftPM. CoverWise currently depends
on `flutter_gemma_mediapipe`, `google_mlkit_commons`,
`google_mlkit_text_recognition` and `pdfx`, which report no SwiftPM support.
The mixed graph links `FBLPromises` through both managers and fails with 93
duplicate symbols.

The prior `sentry_flutter 8.14.2` pin also failed against the current Xcode SDK.
A temporary upgrade to 9.25.0 moved the failure but did not resolve the full
native graph, as recorded below.

## Options considered

1. Keep the mixed SwiftPM/CocoaPods graph and tolerate duplicate linking.
   Rejected: the app does not build.
2. Disable SwiftPM globally for the developer machine.
   Rejected: it would silently affect unrelated projects and would not encode
   the build contract for other contributors.
3. Disable SwiftPM in this project's `pubspec.yaml`.
   Evaluated, then rejected: Flutter documents this project-level compatibility
   path, but the resulting Cocoa-only graph exposed another incompatible Sentry
   API surface.
4. Remove or replace every non-SwiftPM plugin immediately.
   Deferred: this changes OCR, PDF and on-device model product capabilities and
   needs a separate capability-preserving migration decision.

## Evaluated decision

The evaluated change set disabled SwiftPM in `mobile/pubspec.yaml` and enabled
modular headers in `mobile/ios/Podfile`. Validation rejected that combination.
Both changes and the temporary Sentry upgrade were rolled back, so the current
decision is to preserve the prior dependency graph until a
capability-preserving migration is designed and verified.

## Trade-offs and risks

- A single dependency manager remains the preferred architectural endpoint, but
  the evaluated toggle did not produce a buildable graph.
- Modular headers would be global to the iOS pod graph; any future use requires
  a full native regression gate.
- CocoaPods is in maintenance mode and its registry becomes read-only on
  2026-12-02. This is a compatibility bridge, not the long-term endpoint.
- Flutter reports that disabling SwiftPM will not be allowed in a future
  release.
- The current ML Kit pods also warn about future Apple Silicon iOS 26+
  simulator arm64 requirements.

## Validation plan

- Resolve dependencies and run targeted Dart analysis/tests.
- Build and run the debug app on the booted iPhone 16e simulator.
- Exercise the app through ServeSim and Browser.
- Before production use, run the release iOS build and device smoke tests.

## Rollback and migration path

When all four blocking plugins ship adequate SwiftPM and arm64 simulator
support, remove the `enable-swift-package-manager: false` override, regenerate
the iOS project integration, and run debug/release/device gates. Do not enable a
mixed graph again.

## Revisit triggers

- Any blocking plugin adds SwiftPM support.
- Flutter removes the disable setting.
- CocoaPods registry read-only date approaches.
- OCR/PDF/on-device model capability ownership changes.

## Update log

- 2026-07-25: Created and accepted for the current compatibility build after
  direct duplicate-symbol evidence from Xcode. Pranay remains the next reviewer
  for the capability-preserving SwiftPM migration.
- 2026-07-25: Added CocoaPods modular headers after the single-manager build
  exposed `AppCheckCore` imports of `GoogleUtilities` and `RecaptchaInterop`
  without module maps.
- 2026-07-25: Rejected and rolled back after the single-manager/modular-header
  build exposed an incompatible Sentry Cocoa API surface:
  `SentrySDK.configureScope` was unavailable to `sentry_flutter 9.25.0`.
  `mobile/pubspec.yaml` and `mobile/ios/Podfile` were restored to their prior
  project settings. The durable conclusion is that the observability/plugin
  graph needs a dedicated migration; a package-manager toggle alone is not a
  valid fix.

## Anything else?

Yes. The eventual migration must preserve OCR, PDF viewing and on-device model
contracts rather than deleting capabilities merely to satisfy the package
manager.
