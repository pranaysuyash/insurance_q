# CoverWise asset catalog and remediation — 2026-07-16

## Scope and product rule

This inventory covers branded platform assets, onboarding art, semantic icons,
shared visual components and the empty/error/status treatments used by every
Flutter screen. Operational insurance screens use deterministic code-native
icons and components. Generated art is reserved for explanatory scenes where it
improves comprehension; it must never imply insurer approval, claim submission,
coverage certainty or processing evidence.

## Ship-blocking correction

The first visual review recorded the SVG masters and generated catalogs as
verified. A later pixel-level audit found that the three PNG generator inputs
had been exported as grayscale+alpha and were effectively black. Android
launcher/splash output inherited the defect. A successful build did not detect
it.

The sources were re-rendered with macOS ImageIO via `sips`, then all platform
catalogs were regenerated. `test/asset_integrity_test.dart` now decodes the
sources and representative generated outputs, checks visible-pixel ratios and
color variation, and validates web/Android install metadata.

## Canonical brand assets

| ID | Source of truth | Generated input | Consumers | Semantics |
|---|---|---|---|---|
| app icon | `coverwise_icon.svg` | `coverwise_icon.png`, 1024×1024 RGBA | iOS, Android legacy, web, macOS, Windows | Product identity |
| adaptive foreground | `coverwise_foreground.svg` | `coverwise_foreground.png`, 1024×1024 RGBA | Android adaptive icon | Product identity |
| themed mark | `coverwise_monochrome.svg` | `coverwise_monochrome.png`, 1024×1024 RGBA | Android 13+ themed icon | Product identity |
| native splash | `coverwise_splash.svg` | `coverwise_splash.png`, 480×480 RGBA | Android, iOS and web splash | Decorative beside product name |

Regeneration:

```bash
cd mobile
sips -s format png assets/branding/coverwise_icon.svg --out assets/branding/coverwise_icon.png
sips -s format png assets/branding/coverwise_foreground.svg --out assets/branding/coverwise_foreground.png
sips -s format png assets/branding/coverwise_monochrome.svg --out assets/branding/coverwise_monochrome.png
sips -s format png assets/branding/coverwise_splash.svg --out assets/branding/coverwise_splash.png
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter test test/asset_integrity_test.dart
```

Do not substitute ImageMagick for the SVG export without pixel inspection; the
broken rasters were produced at this exact source-to-raster seam.

## Expressive art catalog

| Scene | Asset | Consumer | Crop contract | Semantics |
|---|---|---|---|---|
| understand a policy | `onboarding/understand-policy.png` | onboarding page 1 | square, cover, centered | Decorative; visible copy carries meaning |
| ask grounded questions | `onboarding/ask-policy.png` | onboarding page 2 | square, cover, centered | Decorative; visible copy carries meaning |
| stay prepared | `onboarding/stay-ready.png` | onboarding page 3 | square, cover, centered | Decorative; visible copy carries meaning |
| first policy / library | `scenes/first-policy.png` | dashboard first-policy CTA, empty document library, search prerequisite | square, cover, centered; middle 70% focal safe zone | Decorative; adjacent title/body/action carry meaning |

Missing/corrupt onboarding art falls back to the code-native CoverWise mark.
The image is excluded from semantics because its title and body immediately
follow it. Dark-mode crop and decoded-memory checks remain runtime review gates.

The first-policy scene was generated with the requested OpenAI image-generation
skill on 2026-07-16, using all three onboarding scenes as visual references. Its
prompt requires a policy folder, source document, shield/check and optional
clarity lens; prohibits text, people, currency, insurer branding and approval
certificate imagery; and reserves generous mobile crop margins. The original
generation remains under the Codex generated-image session directory, while the
reviewed source-controlled copy is `mobile/assets/scenes/first-policy.png`.

## Canonical code-native visual vocabulary

- `CoverWiseIconBadge`: semantic row/header icon with accessible foreground
  adjustment in light and dark themes.
- `PolicyTypeIcon`: the only policy-category compound visual; it consumes the
  canonical icon/color mapping in `utils/policy_type.dart`.
- `CoverWiseStatusChip`: icon plus text status; never color alone.
- `CoverWiseMetadataRow`: stable label/value/date/identifier presentation.
- `CoverWiseInfoPanel`: information, warning and limitation copy.
- `CoverWiseSelectableRow`: document, policy and structured-choice selection.
- `EmptyStateWidget`: contextual icon scene, title, copy and semantic action
  icon; it is not used for provider failures.
- `AppErrorView`: unavailable/recoverable state with retry.

Neutral/navigation icons use rounded outlined variants. Filled/check icons are
reserved for confirmed local state; claims guidance uses checklist/route
imagery, never approval/completion imagery. Ask uses the chat-bubble vocabulary.

## Screen remediation matrix

### P0 — workflow and high-density surfaces

- Policy detail: surface/fact/status/contact consistency.
- Dashboard: shortcuts, policy summaries, tips and first-policy state.
- Documents/upload/list: selected file, OCR controls, expansion metadata and
  destructive actions.
- Ask: answer, sources, warnings, history and feedback.
- Processing: one canonical stage icon/status map and step row.
- Coverage gaps, renewals and personal claims: canonical status chips,
  date/metadata rows and limitation panels.
- Search: canonical document/policy result surfaces and filter vocabulary.

### P1 — structured secondary surfaces

- Family/member cards, emergency contact card, insurance card, comparison,
  glossary/quiz, what-if controls, notification settings, privacy flow and
  document preview.

### P2 — low-drift surfaces

- About, Help, More, Profile, Settings and Splash need only compact metadata,
  trailing-icon and disclosure cleanup.

Generated art candidates are deliberately limited to reusable first-policy,
family-protection, guided-search, planning and claims-preparation scenes. They
will be added only after each empty state is tested with the improved code-native
scene, so decorative raster weight is not mistaken for product polish.

## Platform status

- iOS: colored launcher and native splash regenerated; runtime verification
  required after the correction.
- Android: colored legacy/adaptive icons, native splash and monochrome themed
  icon generated; runtime remains unavailable without Android SDK/ADB.
- Web: branded icons/splash plus CoverWise title, description and install colors.
- macOS/Windows: branded launcher resources generated. Their binary/project
  names remain legacy internal identifiers; visible Windows title/product label
  is CoverWise.

## Acceptance gates

- Asset integrity test and full Flutter suite pass.
- Analyzer and `git diff --check` pass.
- Source and representative generated outputs are visually inspected.
- iOS launch/home icon and web manifest/icon are observed after regeneration.
- Android 12 splash, adaptive mask and Android 13 themed icon are observed when
  an SDK-enabled emulator is available.
- Every screen uses a canonical state, icon or component, or records an explicit
  exception with rationale.
- Large text, dark mode, Reduce Motion and missing-asset fallback remain usable.

## Implementation evidence — current pass

- The source SVGs were rendered to RGBA with `sips`; launcher catalogs were
  regenerated for Android, iOS, web, macOS and Windows. Android adaptive XML
  now includes a monochrome layer.
- Source PNGs plus representative iOS, Android, web and macOS outputs were
  visually inspected and passed the automated visible-pixel/color-variance
  checks.
- The corrected iOS icon was observed on the iPhone 17 Pro simulator home
  screen. The Runner workspace rebuilt, installed and launched successfully.
- The development web release built with `--no-tree-shake-icons`, served
  locally, exposed the CoverWise document title/install metadata and displayed
  the colored native splash followed by onboarding.
- Web startup exposed an unrelated but real contract mismatch with the current
  Supabase package (`Supabase.isInitialized`) and a supposedly non-blocking
  anonymous-token warm-up that was awaited. Account-client readiness is now
  owned by `AuthService`, and token warm-up no longer blocks first paint.
- `flutter analyze` is clean. The full suite passed 175 tests before the latest
  component-test addition; targeted asset, policy, coverage-gap, smoke and
  component checks pass after it.
- The first P0 migration uses canonical status chips, metadata rows, information
  panels and selectable rows in policy detail, dashboard, search, emergency,
  renewals, claims, processing, Q&A, coverage gaps and document selection/list
  surfaces. Empty states now use contextual tones and action-specific icons.
- A typed `CoverWiseScene` registry now owns explanatory asset paths, semantics,
  cache sizing, large-text collapse and missing-asset fallback. The first-policy
  scene was visually verified on the live iPhone dashboard and is reused by the
  document-library and search prerequisite states.

The normal web build still hits a missing Flutter SDK
`darwin-x64/const_finder.dart.snapshot` during icon tree shaking in this local
installation. The no-tree-shake build proves application compilation and asset
integration, but repairing the SDK artifact is required before treating the
standard release command as clean.

## Dashboard empty-state correction — 2026-07-16

Runtime review found that the first-policy scene and action had been placed
after three empty-data surfaces: the general page header, zero-document policy
hub and zero-score coverage-health card. On an iPhone 17 Pro this pushed the
actual CTA under the bottom navigation and exposed only the top half of the
card. The asset itself was correct; the composition and task hierarchy were
not.

The dashboard now branches on the authoritative document-list state:

- zero documents render one scroll-safe first-policy task surface directly
  below the app bar;
- the complete scene, title, explanation, source-of-truth note and primary
  action are visible together at the default iPhone 17 Pro viewport;
- populated dashboards retain the overview, health score and management
  sections;
- explanatory art collapses at accessibility text sizes and the entire surface
  remains scrollable so the action stays reachable.

Evidence:

- `docs/review/evidence/asset-revamp-2026-07-16/dashboard-empty-fixed.png`
- `docs/review/evidence/asset-revamp-2026-07-16/dashboard-empty-large-text.png`
- `mobile/test/dashboard_empty_state_test.dart` prevents the redundant empty
  header/hub/health stack from returning and asserts that the primary action is
  present within the standard viewport.
