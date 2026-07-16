# CoverWise visual system review — 2026-07-16

## Correction addendum — 2026-07-16

The earlier review incorrectly treated successful generator/build commands as
proof that the raster branding was visually correct. A later pixel audit found
the PNG inputs were grayscale+alpha and effectively black. The SVG masters were
correct. The rasters and platform catalogs have since been regenerated as
RGB/RGBA, visually inspected, and protected by
`mobile/test/asset_integrity_test.dart`. The canonical inventory and exact
regeneration procedure are recorded in
`docs/review/coverwise_asset_catalog_and_remediation_2026-07-16.md`. Historical
evidence statements below describe what was believed at that stage and must not
be read as current proof without this addendum.

## Decision

Unify the native launch screen, Flutter splash, onboarding, launcher icon, and
Material theme around one CoverWise identity: deep ink surfaces, electric blue
for action, mint for confirmation, and a shield/check mark with consistent
geometry. Generated illustration is reserved for expressive onboarding moments;
the identity mark remains deterministic vector artwork so platform assets stay
crisp and reproducible.

## Visual thesis

Calm protection with a living signal: the product should feel clear, capable,
and reassuring rather than like an insurer sales funnel.

## Interaction thesis

- The native splash and Flutter splash share the same background and mark so
  startup feels continuous rather than like two separate screens.
- The in-app mark enters with restrained scale/fade motion and a short signal
  line replaces an indefinite spinner.
- Onboarding pages use a short eased page transition, progressive track, and
  one dominant illustration per concept. Motion uses opacity/transform only.

## Assets

- `mobile/assets/branding/coverwise_icon.svg`: canonical full launcher artwork.
- `mobile/assets/branding/coverwise_foreground.svg`: Android adaptive foreground.
- `mobile/assets/branding/coverwise_splash.svg`: canonical native splash mark.
- `mobile/assets/onboarding/understand-policy.png`: generated document clarity art.
- `mobile/assets/onboarding/ask-policy.png`: generated grounded-answer art.
- `mobile/assets/onboarding/stay-ready.png`: generated preparedness art.

Raster platform catalogs are generated from these sources with
`flutter_launcher_icons` and `flutter_native_splash`.

## Runtime and accessibility contract

- iOS and Android are both supported; phone layout is the verified target.
- Primary buttons are at least 52 logical pixels tall; header actions retain a
  48-pixel hit area.
- Illustration assets have semantic labels derived from their page title.
- No meaning depends on animation. Color is paired with text and iconography.
- Onboarding keeps a visible Skip action and avoids gesture-only navigation.

## Review passes

### Pass 1 — immediate correctness and completeness

Found and fixed a launch-blocking widget-tree error: the Flutter splash rendered
Material widgets before `MaterialApp`. The splash now lives inside the canonical
app shell. Re-generated iOS, Android, and web native splash/launcher assets and
verified all three onboarding pages fit an iPhone 17 Pro without overflow.

### Pass 2 — architecture and long-term viability

Added one theme source (`CoverWiseTheme`), one code-native mark
(`CoverWiseMark`), and canonical SVG sources rather than per-screen copies. The
generated artwork is presentation-only and does not become a second identity
source. No API route, data pipeline, or product contract changed.

### Pass 3 — rule compliance and supervision readiness

Rechecked touch targets, semantic labels, deterministic asset generation,
runtime navigation, and preservation of parallel work. The existing modified
model/tests/docs were not discarded. Android runtime verification remains
blocked on this machine because `adb` and the Android SDK are unavailable;
asset generation completed, but an Android build/emulator pass still requires
an SDK-enabled environment.

## Evidence

- Tier 2: `flutter analyze` reached zero findings after the scoped lint cleanup.
- Tier 2: iOS Xcode build succeeded through the Runner workspace.
- Tier 4: iPhone 17 Pro runtime observed through XcodeBuildMCP and serve-sim;
  splash completion, three-page onboarding navigation, generated-art cropping,
  CTA labels, accessibility targets, and dashboard arrival were inspected.
- Tier 4 artifacts: `artifacts/ui/onboarding-ask.png`,
  `artifacts/ui/onboarding-stay-ready-settled.png`, and
  `artifacts/ui/dashboard-polished-theme.png`.

## Open hardening

- Owner: mobile engineering. Run `flutter build apk --debug`, then the ADB UI
  dump/screenshot workflow on a compact Android emulator once `ANDROID_HOME`
  and `adb` are available. Closure: clean build plus splash/onboarding screenshots.
- Owner: mobile engineering. The full Flutter suite currently has an existing
  long-running global-error-boundary test/analytics lifecycle interaction.
  Closure: make the test service clock/flush deterministic, then run the entire
  suite to a final pass summary.

## Cross-app expansion pass

The visual system is now moving beyond launch surfaces. A canonical page
header, section label, semantic icon badge, action row, and grouped surface live
in `mobile/lib/widgets/shared/coverwise_components.dart`. The More hub now uses
task-based groups and distinct icon/color semantics instead of a flat utility
list. Shared empty/error states and the primary navigation also use the same
language; the Q&A destination is labeled `Ask` for plain-language clarity.

The first settings migration replaces unrelated bare list rows with grouped
account, experience, app-detail, and device-data surfaces. Theme-level status
bar contrast, input, chip, dialog, and divider styling now provide consistent
defaults for screens still awaiting direct migration.

### Expansion verification

- Tier 2: `flutter analyze` passed with zero findings after the shared-component
  and settings changes.
- Tier 2: widget, global error-boundary, and follow-up chip tests passed (16
  tests in the selected run).
- Tier 3: the iOS Runner workspace rebuilt, installed, and launched successfully
  on the iPhone 17 Pro simulator.
- Tier 4: the reorganised More hub was navigated with runtime semantics; grouped
  labels and action rows were exposed without duplicate announcements.
- Tier 4: the updated system overlay was visually observed with dark iOS status
  content on the light onboarding background.

This is an active migration, not a completion claim. Dashboard, documents,
policy detail, search, Q&A, processing, family, claims, comparison, health, and
secondary support surfaces still require screen-level review and conversion.

## Full-app asset and component migration

The screen-level migration now covers every Dart screen under
`mobile/lib/screens/`, plus the reusable overlays and state widgets used by
those screens. The earlier active-migration note above is retained as timeline
history; this section records the later integrated state.

### Core and policy workflow

- Dashboard, document library/list, source preview and document selector
- Processing timeline and policy detail
- Search and Ask CoverWise (suggested, custom and history states)
- Family overview and add-member dialog

### Planning, readiness and learning

- Emergency card, insurance cards and renewal calendar
- Coverage gaps, side-by-side comparison and what-if calculator
- Coverage health score
- Insurance glossary and quiz
- Claims information guide and personal claims log

### Trust, account and support

- More hub, Settings and Profile
- Notifications, Privacy & Security, Help & Support and About
- Lead consent, phone-linking, terminology, usage allowance and comparison
  overlays
- Offline, loading, empty, recoverable-error and global-error states

Generated illustration is intentionally limited to onboarding concepts where
art adds comprehension. Routine actions use code-native semantic icons and the
canonical `PolicyTypeIcon` classifier, avoiding decorative raster assets and
preventing per-screen icon drift. Platform launcher/splash assets continue to
derive from the canonical branding sources.

## Final review passes

### Pass 1 — immediate correctness and completeness

Reviewed every screen file and the reusable widgets reachable from them.
Replaced flat generic menus, low-contrast gradients, one-off empty states,
gesture-only filters and undersized controls with shared CoverWise hierarchy,
semantic badges, grouped surfaces and accessible Material controls. Runtime
inspection caught and fixed duplicate search-filter announcements.

### Pass 2 — architecture and long-term viability

All migrations reuse `CoverWiseTheme`, `CoverWiseMark`,
`CoverWisePageHeader`, `CoverWiseSectionLabel`, `CoverWiseIconBadge`,
`CoverWiseActionRow`, `CoverWiseSurface`, `PolicyTypeIcon`, `EmptyStateWidget`
and `AppErrorView`. No duplicate visual system, API route, model pipeline or
editable branding source was introduced. Data, calculations, navigation and
storage contracts were preserved.

### Pass 3 — rule compliance and supervision readiness

Rechecked information-broker positioning, claims/reminder limitations, source
verification language, dark mode, reduced motion, larger-text responsive
layouts, semantic live regions, tooltips and retry paths. Runtime dark-mode
inspection found and fixed light-only onboarding ink tokens. Parallel and
unrelated work in the dirty tree remains untouched.

## Integrated evidence

- Tier 2: full `flutter analyze` completed with zero findings.
- Tier 2: full `flutter test` completed with 166 passing tests.
- Tier 3: the complete Runner workspace rebuilt, installed and launched after
  the final shared-component and dark-mode fixes.
- Tier 4: iPhone 17 Pro runtime inspection covered onboarding, dashboard,
  documents, Ask, family, More and search semantics in light/dark appearance.
- Tier 4: serve-sim remained live at `http://127.0.0.1:3200/`; Chrome verified
  the streaming iPhone 17 Pro, CoverWise process and accessibility controls.

## Remaining platform verification boundary

Android launcher and splash resources were generated for all density and night
variants, but this machine still has no Android SDK/`adb`. Android runtime proof
therefore remains unverified. Closure command when an SDK is available:
`cd mobile && flutter build apk --debug`, followed by the compact-emulator
screenshot and UI-dump matrix from the Android verification skill. Shipping an
Android build without that pass risks density-, system-bar- or OEM-specific
layout differences that iOS runtime evidence cannot reveal.
