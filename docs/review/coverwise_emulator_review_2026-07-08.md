# CoverWise Emulator Review - 2026-07-08

## What Changed

- Rebranded the Flutter app to `CoverWise`.
- Aligned the Android package/namespace with `com.coverwise.app`.
- Moved the Android entrypoint to `mobile/android/app/src/main/kotlin/com/coverwise/app/MainActivity.kt`.
- Fixed the Flutter package import path in `mobile/test/widget_test.dart`.
- Cleaned a couple of local analyzer issues introduced by the rename pass.

## Runtime Evidence

- Screenshot: `docs/review/evidence/coverwise-emulator-home.png`
- UI tree: `docs/review/evidence/coverwise-ui.xml`
- Runtime log tail: `docs/review/evidence/coverwise-logcat-tail.txt`
- Policy demo video: `docs/review/evidence/coverwise-policy-demo/coverwise_policy_demo.mp4`
- Video frame check: `docs/review/evidence/coverwise-policy-demo/coverwise_policy_demo_frame.png`
- Live QA evidence: `docs/review/evidence/coverwise-policy-demo/coverwise_qa_answer.png`
- Late-stage QA evidence: `docs/review/evidence/coverwise-policy-demo/coverwise_qa_late.png`
- Live emulator state: `docs/review/evidence/coverwise-policy-demo/coverwise_live.png`

Observed screen state:

- Dashboard home screen renders.
- Bottom navigation is visible.
- App package shown by the emulator UI is `com.coverwise.app`.
- Copy on screen no longer mentions the legacy product name.

## Launch / Performance Notes

- The emulator required an `arm64-v8a` Android 35 Google APIs image on this Apple Silicon host.
- Package-only `adb shell am start -W -p com.coverwise.app` did not resolve, but the explicit component launch did:
  - `com.coverwise.app/io.flutter.embedding.android.FlutterActivity`
- The app launched successfully through `flutter run` and stayed responsive enough to capture the home screen.
- `adb shell dumpsys gfxinfo com.coverwise.app` showed heavy first-frame jank during startup:
  - 3 total frames rendered
  - 3 janky frames
  - 50th percentile around 300 ms
  - 90th/95th percentile around 450 ms

## Validation

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- Emulator boot on `coverwise_api35_arm`
- Runtime launch on `sdk gphone64 arm64`

## Remaining Gaps

- The app still contains broader production-quality warnings outside the rename slice, especially `print` calls and some async-context lint warnings.
- Those warnings are pre-existing and outside the immediate branding/emulator fix, but they remain a worthwhile follow-up if we want a cleaner analyzer state.
- The current policy-demo artifact set is repo-local now, and the fuller Play Store launch bundle is assembled under `docs/review/play_store_launch_assets/`.
