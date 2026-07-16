# CoverWise Motion and Micro-interaction System

Date: 2026-07-16
Status: implementation decision and verification contract
Owner: mobile engineering

## Product intent

CoverWise motion should make policy state easier to understand. It should not
make the product feel playful, sales-led, or busy. Motion is justified only
when it answers one of these questions:

1. What changed?
2. Where did this content come from or go?
3. Is the app working, waiting, finished, or unable to continue?
4. Did my action take effect?

Routine navigation and frequently repeated actions should remain immediate.
No insurance, claim, renewal, coverage, confidence, or processing meaning may
depend on animation alone.

## Primary-source research

- Apple Human Interface Guidelines, Motion:
  https://developer.apple.com/design/human-interface-guidelines/motion
  - Add motion purposefully and keep feedback brief and precise.
  - Avoid gratuitous motion on frequent interactions.
  - Make motion optional and do not block interaction until it finishes.
- Apple Reduced Motion evaluation criteria:
  https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria
  - Detect the system preference.
  - Replace spatial/depth motion with dissolve, highlight fade, or color shift
    when motion communicates state.
- Flutter `MediaQuery.disableAnimationsOf`:
  https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html
  - This is the canonical, dependency-efficient way to observe the platform's
    request to reduce or disable animations.
- Flutter `AnimationStyle`:
  https://api.flutter.dev/flutter/animation/AnimationStyle-class.html
  - Durations can be set to zero; `AnimationStyle.noAnimation` is the explicit
    framework representation for disabled animation.
- Flutter animation guidance:
  https://api.flutter.dev/flutter/animation/Animation-class.html
  - Prefer implicit animation widgets for simple state changes; use controllers
    only when coordinated or continuously driven animation is necessary.
- Flutter accessibility guidance:
  https://docs.flutter.dev/ui/accessibility
  - Preserve 48x48 targets, legibility at enlarged text and nonvisual feedback.
- WCAG 2.2, Understanding 2.3.3 Animation from Interactions:
  https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions
  - Interaction-triggered nonessential animation must be disableable. Respect
    the operating-system preference and avoid unnecessary spatial motion.
- Design Spells, icon micro-animations when clicked:
  https://www.designspells.com/spells/icon-micro-animations-when-hovered-or-clicked-in-discord
  - Adapted as a contained icon-state acknowledgement for copy and feedback
    actions; excluded rotation, particles and bounce because this is a calm,
    high-trust insurance workflow.
- Android graphics guidance:
  https://developer.android.com/design/ui/mobile/guides/layout-and-content/images-graphics
  - Prefer programmatic or vector motion for small UI feedback rather than
    uploading heavy motion assets.

## Motion tokens

The canonical code location is `mobile/lib/theme/coverwise_motion.dart`.

| Token | Default | Use |
| --- | ---: | --- |
| instant | 0 ms | Reduced motion, immediate state replacement |
| quick | 140 ms | Press/selection/color feedback |
| standard | 220 ms | Expand/collapse and local content replacement |
| emphasized | 360 ms | One-time success or major contained state change |
| onboarding | 420 ms | First-run page/launch continuity only |

Default entrance curve: `easeOutCubic`.
Default exit curve: `easeInCubic`.
No bounce, elastic, parallax, rotation, confetti, or autonomous oscillation.

## Canonical behaviors

### Selection feedback

- Scope: policy-type selector, filters, choices and status toggles.
- Behavior: contained color/border change plus at most 2–4% icon scale.
- Reduced motion: immediate color/border change; no scale.
- Meaning remains available through selected semantics, text and icon state.

### Disclosure feedback

- Scope: coverage health, expandable policy/document sections and FAQs.
- Behavior: 220 ms size/cross-fade contained inside the owning surface.
- Reduced motion: immediate content replacement.
- Chevron direction and expanded semantics remain authoritative.

### Status progression

- Scope: upload/processing stages and asynchronous results.
- Behavior: one contained emphasis when the stage changes; no indefinite pulse.
- Reduced motion: immediate icon/state replacement with live-region announcement.
- Polling and navigation must never depend on the animation controller.

### Success and saved-state acknowledgement

- Scope: resolved gap, saved preference, copied value, logged personal claim.
- Behavior: system Snackbar plus a brief icon/color transition when the affected
  control stays visible.
- Reduced motion: Snackbar and immediate icon/color state only.
- Haptics are not added globally; platform/system controls retain native feedback.
- Copying an answer replaces the copy glyph with a short-lived checkmark while
  preserving the Snackbar and an updated tooltip. Feedback glyphs cross-fade
  between outlined and selected states.

### Screen and tab changes

- Primary bottom navigation: preserve Material system behavior; no custom slide.
- Pushed routes and sheets: preserve Material/Cupertino platform transitions.
- Splash/onboarding hand-off: short fade only; reduced motion is immediate.

## Explicit non-goals

- No animation asset files, GIFs, Lottie/Rive dependency, or decorative loops.
- No animated financial amounts that can obscure the final value.
- No celebratory effects for claims, coverage gaps, policy expiry or health score.
- No full-screen custom route translation for routine navigation.
- No animation that prevents tapping, backing out, scrolling or reading.

## Implementation inventory

Existing motion to retain and normalize:

- splash mark fade/scale and app-shell hand-off
- onboarding illustration entrance and page progress
- dashboard policy-type selection and description replacement
- coverage-health score entrance and disclosure
- processing stage progression
- keyboard-safe phone-sheet inset change

New shared primitives:

- reduced-motion-aware duration and curve helpers
- reduced-motion-aware fade/scale state switcher
- reduced-motion-aware expansion style for Material disclosures

## Acceptance criteria

- Every custom duration uses the canonical motion tokens.
- Every custom spatial/scale animation checks
  `MediaQuery.disableAnimationsOf(context)`.
- No repeating controller runs when reduced motion is enabled.
- Important state changes include text/icon/semantics independent of motion.
- All controllers are disposed and do not drive domain state.
- `flutter analyze`, full `flutter test`, and `git diff --check` pass.
- serve-sim is checked with normal motion and Reduce Motion enabled.
- The final runtime pass covers onboarding, dashboard selection, coverage-health
  disclosure and processing/status behavior.

## Rollback and revisit triggers

The motion layer is presentation-only. Rollback consists of replacing motion
helpers with their child/state output; no data migration is required. Revisit
this decision only if usability testing shows that a workflow's state change is
still unclear, or if Flutter adds a more comprehensive theme-level reduced-
motion API that supersedes the helper.

## Implementation outcome

- Added `CoverWiseMotion` as the single duration/curve and Reduce Motion policy.
- Added a fade-only keyed state transition for compact content replacement.
- Normalized splash, app-shell, onboarding, dashboard, policy selection,
  coverage-health disclosure, keyboard inset, search results, gap results and
  Q&A transitions to the shared policy.
- Removed the processing screen's indefinite pulse controller. Processing now
  communicates current state with stable iconography, text and semantics; its
  stage container only animates when a stage actually changes.
- Added live-region announcements for Q&A answers, search/gap result counts and
  document upload, on-device reading, success and error states.
- Added contained Q&A action acknowledgement: helpful/unhelpful glyphs now
  cross-fade, and copy briefly becomes a checkmark without moving layout.
- Processing completion now resolves its brief acknowledgement delay through
  the canonical motion policy, so Reduce Motion never waits on presentation.
- Made onboarding's compact layout resilient to 2x text scaling and changed its
  page navigation to an immediate jump when Reduce Motion is enabled.
- Retained native route, sheet, button and switch behavior. No global haptics,
  animation packages or generated motion assets were introduced.

## Review passes

### Pass 1 — immediate correctness and completeness

Checked every custom animation/controller call site and the highest-value state
changes. Fixed the uncancelled splash timer, hidden health-score ticker,
decorative processing loop, nested dashboard scale, non-announced result states
and reduced-motion gaps. Outcome: presentation state no longer owns or delays
domain behavior.

### Pass 2 — architecture and long-term viability

Rechecked the implementation against the shared primitive and platform motion
settings. No parallel motion helper, custom route stack, duplicate workflow or
new dependency was introduced. Outcome: one token policy covers custom motion;
native platform motion remains canonical for navigation and controls.

### Pass 3 — compliance and supervision readiness

Ran formatting, analyzer, targeted widget/regression tests, the full Flutter
suite, iOS simulator build/run, serve-sim Reduce Motion toggling and a maximum
text-size visual inspection. Restored simulator settings after the check.
Outcome: the implementation is reviewable and reversible without data or API
migration.

## Verification evidence

- Tier 2: `flutter analyze` — clean.
- Tier 2: targeted motion and regression suite — 19 current targeted tests
  passed (the earlier broader motion pass covered 55 tests).
- Tier 2: full `flutter test` — 179 tests passed.
- Tier 3: Xcode simulator build/install/launch — succeeded on iPhone 17 Pro;
  one existing ML Kit binary platform warning was emitted by Xcode.
- Tier 4: serve-sim changed Reduce Motion on the live simulator; onboarding
  advanced successfully with the setting enabled.
- Tier 4: maximum simulator text size showed the final onboarding page without
  clipping or overflow; settings were restored to their original values.

Processing against a real uploaded policy was not rerun because that requires a
live backend/document fixture. Its controller removal and stage mapping are
covered at Tier 1/2; the exact closure check is to upload a supported policy,
observe each stage once with Reduce Motion off and on, and confirm the live-region
stage labels with VoiceOver.

## Follow-up micro-interaction verification (2026-07-16)

- Re-ran online research against current Apple HIG motion and accessibility
  guidance, Apple App Store Reduced Motion evaluation criteria, WCAG 2.2 SC
  2.3.3, Flutter `MediaQueryData.disableAnimations`, and the Design Spells icon
  interaction reference linked above.
- `flutter analyze`: clean.
- `flutter test`: all 179 tests passed.
- `flutter build ios --simulator --debug
  --dart-define=ENVIRONMENT=development`: succeeded.
- Installed and launched `com.coverwise.app` on iPhone 17 Pro simulator.
- `serve-sim ui reduce-motion on/off`: setting changed successfully and was
  restored to off after the check.
- Visual evidence:
  - `docs/review/evidence/motion-2026-07-16/launch-normal.png`
  - `docs/review/evidence/motion-2026-07-16/launch-reduced-motion.png`
    (native launch surface captured during reduced-motion startup)
  - `docs/review/evidence/motion-2026-07-16/post-restore.png`
    (settled onboarding after restoring the simulator setting)
- The iOS 26.2 simulator produced delayed black rectangular compositing
  artifacts in `simctl io screenshot` after Reduce Motion stayed enabled for
  several seconds. The first live-toggle frame was clean, later frames were
  corrupted, and restoring the setting returned a clean frame. This is recorded
  as a simulator/capture boundary rather than claimed as clean Tier 4 reduced-
  motion visual proof. Widget tests directly verify zero durations and the app
  remained responsive; a physical-device reduced-motion pass is the closure
  check before declaring App Store Reduced Motion support.
- The Q&A copy acknowledgement is covered by analyzer/full-suite/static widget
  inspection, but not a live answer-card tap in this pass because the simulator
  has no processed policy fixture. Closure requires opening a real or fixture
  answer, tapping Copy, and observing the checkmark and Snackbar once with
  Reduce Motion off and on.
