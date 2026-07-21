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

- iOS: colored launcher and native splash regenerated and observed on an
  iPhone 17 Pro simulator after a clean install.
- Android: colored legacy/adaptive icons, native splash and monochrome themed
  icon generated. The standard adaptive launcher icon and app launch were
  observed on an API 35 emulator; the themed-icon treatment and Android 12
  cold-start splash still require a clean system-level observation.
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

## Addendum — full-surface asset and interaction pass, 2026-07-21

This pass re-audited all mobile screens, shared visual components, launch
catalogs, desktop identity resources and the real iPhone 17 Pro runtime. The
governing rule is now explicit: if an empty state exists to start a task, its
primary action is part of the state and must remain visible/reachable at the
default viewport and with larger text. Decorative art supports that action; it
never pushes it below navigation or replaces it.

### Asset and platform corrections

- The canonical launcher source and web maskable icon are full-bleed. iOS no
  longer acquires white corners during alpha removal.
- Android adaptive assets use separate background, foreground and monochrome
  contracts. The monochrome file is an alpha-mask glyph with separate shield
  outline and check, rather than a black/white illustration whose opaque
  regions collapse when Android applies the system theme color.
- macOS uses a padded desktop-specific icon; Windows now carries a 256 px ICO.
- Linux uses the CoverWise binary/application identity and includes a desktop
  entry and icon. macOS test bundle identifiers no longer use the template
  `com.example.mobile` value.
- Web install metadata uses the canonical `#145BC7` theme and exposes Apple
  standalone capability metadata.
- `asset_integrity_test.dart` now checks full-bleed corners, monochrome alpha
  topology, platform color variation, desktop identity and Windows icon size.

### Screen and component corrections

- Claims guide, Emergency, Insurance Cards, Compare, Renewals, What-if and
  Search prerequisite states now expose the same `Choose policy file` action
  and open the canonical `DocumentsScreen(startWithFilePicker: true)` flow.
- Search policy-type art now uses the canonical type color; expiry remains a
  separate status signal. Search metrics wrap instead of overflowing.
- Claim guidance sheets scroll within a 90% safe-height surface. Insurance
  cards use the canonical text-plus-icon status chip.
- Family editing widths, action controls and metadata adapt to narrow/large-text
  layouts. What-if values and renewal status layouts now wrap or reflow.
- Legal-content errors use the canonical recoverable error component and do not
  expose raw exceptions.
- Onboarding `Skip intro` leads to the consent page rather than bypassing legal
  acceptance. At text scales above 1.5 it becomes an accessible icon control
  with the same tooltip, eliminating compact-screen overflow.
- The stale local paywall is now a compatibility entry into the canonical
  RevenueCat-backed upgrade screen, with limit context but no duplicate prices,
  scarcity offer or feature claims.
- Bottom navigation preserves visited-tab state while mounting tabs lazily, so
  in-progress UI survives tab changes without starting hidden network work.
- Custom-scheme deep links normalize host-based routes, cold-start links are
  handled, and missing policy arguments render a recovery path instead of a
  cast failure.

### Motion and micro-interaction decision

Research was checked against current primary platform guidance:

- [Apple HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
  says motion should be purposeful, brief, optional, cancellable and not added
  to frequent interactions when standard controls already provide feedback.
- [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility/)
  recommends reducing automatic/repetitive motion and replacing spatial or
  depth transitions with fades when Reduce Motion is enabled.
- [Apple Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/)
  explicitly calls out scaling, spinning, parallax and ongoing motion, while
  allowing meaning-preserving fades, highlights and color shifts.
- [Android mobile accessibility guidance](https://developer.android.com/design/ui/mobile/guides/foundations/accessibility)
  treats accessibility as a design foundation rather than a post-build check.

CoverWise therefore keeps its existing short state/onboarding transitions and
standard Material control feedback, routes custom durations through
`CoverWiseMotion`, resolves them to zero under system Reduce Motion, and avoids
looping decorative animation, parallax, bounce-heavy springs and animation-only
status. The full-page CTA is a stable task surface; it does not auto-advance or
move while the user is reading it.

### Runtime and verification evidence

- `flutter analyze`: clean.
- Full Flutter suite: passed after the integration corrections.
- iOS simulator debug build: passed; `Runner.app` built for
  `com.coverwise.app`.
- Web release build with `--no-tree-shake-icons`: passed.
- iPhone 17 Pro clean install reached the complete onboarding surface; the
  launcher/native splash and full onboarding art were visually inspected.
- Android API 35 built, installed and launched the app. The branded adaptive
  launcher icon was visually inspected in the launcher. The first app launch
  reached onboarding behind an emulator `System UI isn't responding` dialog;
  because that dialog belongs to the emulator system process, this is app
  launch evidence but not a clean Android onboarding or splash acceptance.
- A second simulator launch retained the same local encryption principal. The
  root cause of the earlier native-splash stall was a timestamp-based local
  principal that rotated the Hive encryption key on every launch; local-only
  mode now uses the persisted install id. Startup also performs one legacy-key
  check instead of per-box secure-store migration checks on fresh installs.
- Evidence is stored under
  `docs/review/evidence/asset-revamp-2026-07-21/`.

Android's standard adaptive launcher icon has Tier 4 evidence on API 35, and
the app build/install/launch path has Tier 3/4 evidence. The themed-icon tint,
Android 12 cold-start splash mask and system Reduce Motion response remain Tier
1/2: their source/configuration and integrity tests are verified, but they were
not cleanly observed in the emulator. Linux and Windows packaging are also
statically verified rather than built on their native hosts.

### Three-pass review

1. **Immediate correctness and completeness:** rechecked all screen entry
   states and repaired the missing actions, clipped/overflow-prone layouts,
   duplicate paywall and unsafe legal/onboarding behavior. Focused and full
   tests exposed and closed stale-copy and shared-header integration failures.
2. **Architecture and long-term viability:** kept one policy picker path, one
   paywall, one policy-type map, one status/metadata/error vocabulary and one
   motion-token system. No parallel asset or routing source was introduced.
3. **Rule compliance and supervision readiness:** regenerated platform assets,
   visually inspected representative outputs and iOS runtime, recorded evidence
   tiers and preserved unrelated working-tree changes without staging,
   committing or deleting them.

### Anything else?

Yes. A clean Android emulator/device pass with themed icons enabled is still
required before claiming the themed icon, Android 12 splash mask and system
Reduce Motion behavior at Tier 4. A release-configured iOS cold-start trace should also be
captured before making a startup-time performance claim; the current proof is a
debug simulator runtime and establishes correctness, not production latency.

## Addendum — Android 16 release baseline and native-system closure, 2026-07-21

The earlier API 35 Android evidence was insufficient for the current Play
baseline. CoverWise now compiles **and targets Android 16/API 36** while
retaining Android 6/API 23 as its minimum supported version. The decision,
options, rollback and update history are recorded in
[`ADR-2026-07-21-02`](../decisions/ADR-2026-07-21-02-android-16-target-and-system-identity.md).

Android 16 verification used a newly provisioned Google APIs ARM Pixel emulator
and a fresh debug APK install:

- cold launch showed the system-owned dark CoverWise splash before Flutter
  rendered onboarding;
- the app reached the first onboarding page with no app ANR or fatal exception;
- Android reports `targetSdk=36` for `com.coverwise.app`;
- system themed icons were enabled in Wallpaper & style;
- the packaged APK contains the API 33+ `mipmap-anydpi-v33` adaptive-icon
  variant with a direct alpha-only monochrome drawable reference, in addition to
  the existing Android 8+ adaptive variant; its standard and round manifest
  declarations resolve to the same canonical resource;
- `asset_integrity_test.dart`, `flutter analyze`, and the Android 16 debug APK
  build pass.

Evidence is retained in
`docs/review/evidence/android16-platform-qa-2026-07-21/`. The API 36 screenshot
captures are Tier 4 for system splash, app launch and the enabled system theme;
the CoverWise monochrome layer itself is Tier 1/2 packaged-resource/test proof
because the emulator launcher does not allow ADB-driven pinning of the app to
its home workspace for a direct tinted-glyph capture. This limitation is stated
explicitly rather than counted as a completed visual observation.

### Three-pass review — Android 16 closure

1. **Immediate correctness:** aligned target and compile SDKs, preserved
   `minSdk=23`, added the Android 13+ monochrome resource variant and made the
   target/splash/icon contract testable.
2. **Architecture:** kept one launcher resource name with version-qualified
   Android variants; no second icon pipeline, duplicate activity, or custom
   splash path was introduced.
3. **Supervision readiness:** captured clean Android 16 screenshots and UI
   hierarchy, inspected the built APK with `aapt2`, recorded the unresolved
   evidence boundary, and preserved unrelated workspace changes.

### Anything else?

Android 17/API 37 remains a preview compatibility lane. It was not installed in
this workspace because provisioning Android 16 left only 1.8 GiB of free local
storage; downloading another system image would risk unrelated work. The Android
16/API 36 release contract is complete and gated. Android 17 needs a separate
device/emulator run once build storage is available.

### Addendum — Android 17 retry, 2026-07-21

Android 17/API 37.1's 16 KB Google APIs ARM system image was installed with an
updated command-line SDK toolchain, and its clean Pixel emulator booted with
`SDK=37` and `Release=17`. The CoverWise runtime pass remains blocked at the
artifact handoff: an isolated-cache debug build reaches `mergeDebugNativeLibs`
but fails with `No space left on device`, while the preserved API 36 test AVD
also cannot boot at the remaining capacity. No project or pre-existing SDK
asset was deleted to force this run. The next closure is a fresh APK build on a
volume with adequate headroom, followed by install, cold launch, splash, and
themed-icon checks on the already-provisioned API 37 device.

### Addendum — Android 17 runtime closure, 2026-07-21

After storage recovered, the current APK built, installed, and cold-launched on
the clean API 37.1 device. `dumpsys package` reports `targetSdk=36`; the cold
launch returned `Status: ok`, `LaunchState: COLD`, and `TotalTime: 3850` in the
debug emulator. The captured native splash handoff and rendered first onboarding
screen are retained as `android17-api37-native-splash.png` and
`android17-api37-cold-launch.png` in the Android platform evidence directory.
This closes Android 17 startup compatibility at Tier 4; it is correctness
evidence, not a production startup-latency claim.

### Addendum — Android 17 launcher icon closure, 2026-07-21

The previous Android launcher caveat is now closed. On the same Android
17/API 37.1 Pixel emulator, I selected and applied **Wallpaper & style → Icons
→ Minimal**, then inspected the real home screen. CoverWise appears in the
launcher as the system-rendered single-colour shield/check glyph. The visual
evidence is
`docs/review/evidence/android16-platform-qa-2026-07-21/android17-api37-minimal-launcher-coverwise.png`.

Evidence tier: **Tier 4** (manual/runtime visual observation). This complements
the API 33+ resource and package checks; it is direct launcher rendering proof,
not an inference from XML. Android 17 names its current icon treatment
"Minimal", so the older on-device wording "Themed icons" is not expected on
this system image.
