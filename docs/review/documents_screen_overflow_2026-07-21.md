# Documents screen overflow review — 2026-07-21

## Finding

The empty Documents state was rendered as a fixed-height centered composition
inside the `Expanded` list area. On short mobile viewports, the page header,
upload allowance, upload CTA, and saved-policy heading left less vertical room
than the illustration and explanatory copy needed. Flutter therefore reported a
bottom `RenderFlex` overflow and painted the yellow/black diagnostic stripe.

## Decision

`EmptyStateWidget` now keeps its centered layout when it fits and uses a
vertical `SingleChildScrollView` when the available viewport is shorter than
the composition. This keeps the existing Documents page structure and fixed
navigation intact while also covering larger text scales and other screens that
reuse the shared empty-state widget.

## Design conformance

The Documents surface now uses the canonical `CoverWiseSectionLabel` hierarchy
for the saved-policy section, rounded refresh icons for navigation/actions, and
the rounded upload-file icon for the primary empty-state action. The existing
`first-policy.png` remains the canonical generated scene: a new image-generation
candidate was reviewed, but it was not adopted because the existing scene has
stronger policy-review meaning through its document, folder, lens, and shield
composition and already satisfies the asset contract.

## Verification

- The Documents screen test suite passes.
- Focused upload regressions now cover the selected-file panel (including the
  narrow-layout overflow path) and the `Loading saved policies` transition.
- The final full Flutter suite passes cleanly: `flutter test` — 573 tests
  passed.
- A focused short-viewport regression test asserts no Flutter exception and
  confirms the empty-state copy remains present.
- The current checkout rebuilt successfully and launched on the iPhone 17 Pro
  iOS Simulator. Final runtime UI automation navigated to Documents and
  captured the compact screen at 368x800: the illustration, `No saved policies
  yet`, explanatory copy, rounded refresh controls, and bottom navigation are
  visible with no yellow/black overflow diagnostic stripe. The runtime snapshot
  also exposed the expected Documents tab and empty-state labels.

## Scope correction

The current checkout also changes the upload affordance beyond the overflow
fix: an empty library shows `Add policy file`, a populated library shows the
compact `Add new policy` CTA, and the expanded upload panel is shown only after
a file has been selected. This is a coherent UX direction, but it is an upload
journey change rather than a layout-only change.

The focused tests cover the empty state, saved-policy rendering, the populated
`Add new policy` CTA, the selected-file panel, and the provider-loading
transition. No route, storage, or server contract change was observed.

## Verification addendum — 2026-07-21

- `flutter test test/documents_screen_test.dart test/coverwise_components_test.dart` — passed (16 tests).
- `flutter analyze lib/screens/documents_screen.dart lib/widgets/shared/coverwise_components.dart lib/widgets/shared/empty_state_widget.dart test/documents_screen_test.dart` — passed.
- `flutter analyze lib/screens/policy_detail_screen.dart lib/widgets/shared/coverwise_snackbar.dart lib/screens/documents_screen.dart test/confidence_badge_test.dart` — passed.
- `flutter test` — passed (573 tests).
- XcodeBuildMCP runtime snapshot after tapping Documents — passed; expected
  Documents labels and controls were exposed on the iPhone 17 Pro simulator.
- XcodeBuildMCP screenshot — passed; final compact Documents layout visually
  inspected with no overflow diagnostic stripe.
- Android tooling is available (`adb`, Android SDK, API 35 emulator); `flutter build apk --debug`, APK install, and Flutter activity launch passed. Android Documents-screen visual proof remains open because the emulator UI dump became unavailable during navigation.
