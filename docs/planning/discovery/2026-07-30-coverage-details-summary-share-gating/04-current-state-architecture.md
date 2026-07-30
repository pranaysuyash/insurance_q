# 04 — Current-State Architecture

**Bundle:** 2026-07-30-coverage-details-summary-share-gating
**Doc D (Part 0)** — system map for the share-gate test scope
**Author:** session-init agent
**Date:** 2026-07-30

---

## A. Scope of this architecture map

This document maps only the entities, contracts, and flows that the share-gate test exercise touches. It does not aim to describe the entire CoverWise codebase — only the slice relevant to "free user taps share → sees upgrade snackbar; paid user taps share → completes OS share sheet."

## B. Component map (the test exercises this trio + 1 helper)

| Component | Path | LoC | Role | Owned in this workstream? |
|---|---|---|---|---|
| `CoverageDetailsSummaryScreen` | `mobile/lib/screens/coverage_details_summary_screen.dart` | 935 | Renders extracted policy fields with share/export + comment/property/life/etc type-specific sections | Touch only if WS-2 realigns |
| `EntitlementNotifier` | `mobile/lib/providers/entitlement_provider.dart` | 183 | Riverpod notifier over `EntitlementService`; provides `checkAction(action) → String?` | Read-only — single canonical gate |
| `Entitlement` + `PlanLimits` + `planLimits` map | `mobile/lib/models/entitlement.dart` | 258 | Per-tier limit registry | Read-only — single canonical boundary |
| `CoverWiseSnackBar` | `mobile/lib/widgets/shared/coverwise_snackbar.dart` | (read on demand) | Reusable themed snackbar with optional `actionLabel` + `onAction` | Touch only if WS-2 realigns |
| `coverage_details_summary_screen_test.dart` | `mobile/test/coverage_details_summary_screen_test.dart` | 128 | Six test cases: 3 tier scenarios + 3 PlanLimits invariants | Touch only if WS-2 realigns |
| `hive_test_helper.dart` | `mobile/test/helpers/hive_test_helper.dart` | 89 | Shared Hive init/teardown; not invoked directly by this test | Read-only |
| `share_plus` package | (Flutter package) | n/a | `SharePlus.instance.share(ShareParams)` opens OS share sheet | Read-only |
| (Out of scope) `main.dart`, `policy_detail_screen.dart`, `dashboard_screen.dart`, etc. | (various) | various | Reach the screen; not in WS-1/WS-2 scope | Read-only |

## C. Strong foundations

- **`planLimits` registry** — immutable `Map<PlanTier, PlanLimits>`; declared `const`. The test's 3 invariants (tests 4–6) read it directly. This is the single canonical free/paid boundary in the mobile codebase.
- **`EntitlementNotifier.checkAction('export')`** — exhaustively switches on action name; returns `null` for allowed actions. This is the single canonical gate in the mobile codebase.
- **`buildCoverageShareText(PolicySummary)`** — extracted as a module-level pure function in the same screen file. Independently tested in `mobile/test/coverage_share_text_test.dart`. Easy to reason about, no widget tree needed.
- **`_buildTestApp` pattern** — overrides `entitlementProvider` via `ProviderScope` overrides; no Hive gymnastics for tier tests. Clean.
- **`HiveTestHelper.setUp/tearDown`** — proper `setUpAll/tearDownAll` discipline; shared across many tests.

## D. Fragile foundations

- **`CoverageDetailsSummaryScreen` at 935 lines** — god-object. The 2026-07-23 UX audit noted 1,439 lines (that figure was from then; current 935 reflects partial refactor). Pre-existing debt. **Out of scope for this workstream.**
- **`EntitlementNotifier.checkAction` mixes "expired" check with action-specific switch** — design wart, future-proofing only. The "expired" branch returns "Your {tier} plan has expired..." which can shadow the per-action reason. Test 1 does not exercise expiry, so this is latent. Out of scope.
- **Substring match in test 1** (`find.textContaining('Export is available on Plus')`) — passes against `'Export is available on Plus and Family plans.'` because of substring semantics. Works today; could silently pass if the canonical copy drifts to something like `'Export now available on Plus and Family plans.'`. Worth knowing, not worth "fixing" without a real test brittleness signal.

## E. Public contracts in scope

| Contract | Shape | Status |
|---|---|---|
| `EntitlementNotifier.checkAction(String) → String?` | Returns null if allowed; otherwise human-readable reason | Stable; do not modify |
| `planLimits[PlanTier].allowExport` | `bool`; false for free, true for plus & family | Stable; do not modify |
| `CoverageDetailsSummaryScreen({required PolicySummary summary})` | Constructor; only constructor | Stable; do not modify |
| `Icons.ios_share_rounded` in AppBar actions | UI presence | Stable |
| `CoverWiseSnackBar.warning(context, message, {actionLabel, onAction})` | API | Stable |
| `/plans` named route | `Navigator.pushNamed(context, '/plans')` | Tested; reachable |

## F. Internal contracts in scope

- `_shareSummary(BuildContext, WidgetRef)` — calls `checkAction('export')`, dispatches to `CoverWiseSnackBar.warning` or `SharePlus.instance.share(...)`. Static shape; one consumer.
- `buildCoverageShareText(PolicySummary)` — pure; documented in `buildCoverageShareText` test.

## G. State flows for the three test scenarios

```
Free user:
  test buildTestApp(entitlement=free) → pumpAndSettle
  → screen renders with share icon in AppBar
  → tap share icon → _shareSummary called
  → checkAction('export') → 'Export is available on Plus and Family plans.'
  → CoverWiseSnackBar.warning(context, msg, actionLabel='Upgrade', onAction=push /plans)
  → snackbar visible with text containing the gate-reason
  → Upgrade action visible (covered by find.text('Upgrade'))
  Test assertions:
    - find.byIcon(Icons.ios_share_rounded) findsOneWidget
    - find.textContaining('Export is available on Plus') findsOneWidget   (substring match)
    - find.text('Upgrade') findsOneWidget                                 (exact match — depends on snackbar action rendering)

Plus user:
  test buildTestApp(entitlement=plus) → pumpAndSettle
  → share icon present
  → tap share icon → _shareSummary called
  → checkAction('export') → null (allowed)
  → SharePlus.instance.share(ShareParams(...)) invoked
  Test assertions:
    - find.byIcon(Icons.ios_share_rounded) findsOneWidget
    - find.textContaining('Export is available on Plus') findsNothing      (negative)

Family user: same as Plus but entitlement = family.

PlanLimits invariants (tests 4–6):
  planLimits[PlanTier.free]!.allowExport == false
  planLimits[PlanTier.plus]!.allowExport == true
  planLimits[PlanTier.family]!.allowExport == true
```

## H. Failure flows

| Failure | What user sees | What's auditable |
|---|---|---|
| Free user denied export | Snackbar "Export is available on Plus and Family plans." with "Upgrade" action | `checkAction('export')` returns the reason; snackbar builder receives it; action button routes to `/plans` |
| Plus user share call throws | `CoverWiseSnackBar.error(context, l10n.coverageShareError)` | Caught by `_shareSummary`'s try/catch; UI graceful |
| Plus user share call succeeds | OS share sheet opens (not testable without mock) | Out of scope |

## I. Routes & deep links

The `CoverageDetailsSummaryScreen` is reachable via:

- `dashboard_screen.dart` — direct `MaterialPageRoute` with `PolicySummary` argument
- `policy_detail_screen.dart` — direct `MaterialPageRoute` with `PolicySummary` argument

It is **not registered** as a named route in `main.dart`. This is intentional: the screen takes a `PolicySummary` object, not a `documentId` string. Adding a deep-link route would require a contract change. **Out of scope for this workstream.**

## J. Persistence layer

None in scope. Hive boxes exist for local cache but the share gate itself does not read/write any of them. The test does not exercise Hive-backed entitlement state — it uses the Riverpod override pattern instead.

## K. External integrations

- `SharePlus` (from `share_plus` package) — opens OS share sheet. Not mocked in this test (the free-tier branch never reaches it).
- Supabase, RevenueCat, Sentry — not exercised by this test.

## L. Build, test, deployment

- Test command: `flutter test test/coverage_details_summary_screen_test.dart` (run from `mobile/`).
- Flutter toolchain in this session: `/Users/pranay/Projects/adhoc_resources/flutter/bin/flutter` (not on default PATH; requires `export PATH=...`).
- CI configuration: `.github/workflows/ci.yml` (modified; contains Flutter test invocation; not in scope).
- Backend, deployment: not in scope.

## M. Observability

- Analytics event `_shareSummary` does not emit in this codebase (no `AnalyticsService.track` call from `_shareSummary`). This is a Tier-2 coverage gap worth surfacing as a follow-up but out of scope here.
- Sentry: errors caught by the try/catch are surfaced via `CoverWiseSnackBar.error`; no Sentry.captureException call.

## N. Build system

`pubspec.yaml` declares the Flutter deps; `mobile/pubspec.lock` is committed. In-flight parallel-agent work includes 4 line insertions into `pubspec.yaml` and 6 changes in `pubspec.lock`. These are dep updates associated with the auth/workspace refactor. **Not in scope.** No changes planned to either.

## O. Known debt (relevant)

- **`CoverageDetailsSummaryScreen` god-object** — 935 lines. Pre-existing. Out of scope.
- **`checkAction` mixes expired + per-action** — pre-existing. Out of scope.
- **No analytics on share attempts** — pre-existing Tier-2 coverage gap. Out of scope for this workstream (could be a follow-up).
- **No deep-link route for the screen** — intentional. Out of scope.
- **No `_shareSummary` analytics event** — mentioned under M, out of scope.

## P. Adjacent tests in the test pyramid

| Test file | Purpose | Status |
|---|---|---|
| `coverage_details_summary_screen_test.dart` | This workstream's target | Compile-blocked by parallel refactor |
| `entitlement_test.dart` | EntitlementNotifier.checkAction matrix | Not run; compile-blocked |
| `coverage_share_text_test.dart` | buildCoverageShareText formatter | Not run; compile-blocked |
| `coverwise_snackbar_test.dart` | CoverWiseSnackBar widget | Not run; compile-blocked |
| `dashboard_screen_test.dart` | Dashboard navigation flow, references CoverageDetailsSummaryScreen indirectly | Not run; compile-blocked |

All blocked by `auth_service.dart:303`'s `createdAt` type mismatch. None of these tests directly test the screen+gate path without going through `main.dart` or `auth_service.dart` first. The compile-block is a transitive dependency that the parallel refactor will resolve.

## Anything else? (motto §0.1.1)

The screen + snackbar + PlanLimits trio is genuinely well-factored for an MVP-quality mobile codebase. The fragile parts are concentrated in the `CoverageDetailsSummaryScreen` size and the auth/workspace refactor in flight — both pre-existing and out of scope. The single canonical gate (`checkAction('export')`) and the single canonical PlanLimits table (`planLimits[PlanTier]`) are *good* first-principles design. Resisting the urge to fragment them is the largest single architectural defense this workstream performs, even while making no edits.
