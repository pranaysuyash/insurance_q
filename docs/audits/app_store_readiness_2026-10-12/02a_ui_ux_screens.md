# 02a. UI/UX Launch-Readiness Audit: Flutter Screens

**Date:** 2026-10-12
**Scope:** 11 screens in `mobile/lib/screens/` (listed below).
**Method:** Static inspection (Tier 1) of the full source of each screen, plus cross-checks against `mobile/lib/l10n/app_en.arb`, `mobile/lib/theme/coverwise_theme.dart`, `mobile/lib/navigation/app_router.dart`, `mobile/lib/app.dart`, `mobile/lib/widgets/not_yet_extracted_section.dart`, and `mobile/lib/models/policy_summary.dart`. Grep sweeps covered placeholders, forbidden copy, icon-button tooltips, literal colors, and literal font sizes.
**Evidence tier:** Tier 1 (static). No widget tests, device runs, or simulator runs were performed (test sensitivity S0 for every claim). Contrast ratios are hand-computed estimates and must be confirmed with a contrast tool.
**Files changed:** None. This report is the only file written.
**Severity scale:** BLOCKER = user-visible wrong result or dead path on a core flow; HIGH = dead control, misleading or incorrect copy, or accessibility failure likely to be flagged in review; MED = quality, localization, or accessibility gap; LOW = polish or code hygiene.

---

## 1. Screens audited

| # | File | Lines | Role |
|---|------|------:|------|
| 1 | `about_screen.dart` | 148 | App identity, disclaimer, legal links |
| 2 | `account_screen.dart` | 262 | Sign in, sign up, Google, password reset |
| 3 | `add_family_member_dialog.dart` | 156 | Manual family member dialog |
| 4 | `agent_requests_screen.dart` | 343 | Advisor request log |
| 5 | `claim_assistance_screen.dart` | 380 | Claim entry point from policy detail |
| 6 | `claim_tracking_screen.dart` | 525 | Private claim log |
| 7 | `claims_assistant_screen.dart` | 405 | Claim preparation guide |
| 8 | `consent_activity_screen.dart` | 409 | Consent ledger history |
| 9 | `coverage_details_summary_screen.dart` | 935 | Full extracted-field summary and share |
| 10 | `coverage_gap_screen.dart` | 295 | Coverage review (room rent, insurer, not-yet-extracted list) |
| 11 | `dashboard_screen.dart` | 767 | Home dashboard |

Base path for all screen files: `/Users/pranay/Projects/medpiper/insurance_app/mobile/lib/screens/`

---

## 2. Per-screen table

Legend: "none" means no issue found in that category. Counts of literal colors and font sizes are grep line counts.

| Screen | Placeholder / debug | Dead controls | Loading / empty / error | Hardcoded strings (vs arb) | Accessibility | SafeArea | Ad-hoc colors (`Color(0x..)` lines) | Copy risk | Finding IDs |
|---|---|---|---|---|---|---|---|---|---|
| about_screen | none | `_openUrl` fails silently (L16-18) | Static, n/a | All hardcoded; no arb keys exist for About | Icons decorative; no issue | Scaffold, OK | 0 | Disclaimer (L80) is appropriate | UX-A-20, UX-A-28 |
| account_screen | Developer text shown to user (L33, L114) | none | Busy spinner, snackbar errors; OK | All hardcoded (L158-257) although 20+ `account*` keys exist in arb (L322-349) | Password has no visibility toggle or autofill hints (L181-185) | Scaffold, OK | 0 | Legal-style disclaimer (L166) is appropriate; Google icon is Material, not the Google mark (L237) | UX-A-03, UX-A-04, UX-A-15, UX-A-36, UX-A-37 |
| add_family_member_dialog | none | none | Validator only; no async error path | All hardcoded (L81-151); arb has `familyAddButton` unused | Suffix date icon has no label (L136) | Dialog, OK | 0 | OK | UX-A-28, UX-A-35 |
| agent_requests_screen | none | Mark-contacted and clear-all have no error handling (L36-45, L69-71) | Loading, empty, populated: OK | Hardcoded (L88, L120-137, L153) | Faint text alpha 0.7 (L321) | Scaffold, OK | 3 (L199, L204, L234) | Phone number shown in list (L220) | UX-A-21, UX-A-22, UX-A-23, UX-A-28, UX-A-38 |
| claim_assistance_screen | none | "Refresh" is a no-op (L117-122); "View insurer claim process" is a no-op when insurer is unknown (L127, L284-289, L318-331) | Empty branch present (L88-125); no loading or error needed | Hardcoded (L56, L102-111, L133-137, L251) | Acceptable | Scaffold, OK | 0 (uses `colorScheme`) | Disclaimer (L61-66) OK; "5 steps" heading wrong (L251); roadmap copy (L133-137); missing grievance section (L379) | UX-A-05, UX-A-06, UX-A-12, UX-A-13, UX-A-14, UX-A-28 |
| claim_tracking_screen | none | Reference-number controller never disposed (L62) | Spinner (L131-132), empty state (L134-143); no error state | Hardcoded (L67, L101-102, L125, L128, L136-150, L203, L456-457) | Fullscreen close IconButton has no tooltip (L214-217); reference chip target too small (L340-381); timeline toggle has no expanded state (L439-475); photos lack labels (L392-412) | Scaffold, OK | 5 (L247-253) | "Does not submit claims" disclaimer (L138) is appropriate | UX-A-23, UX-A-25, UX-A-26, UX-A-28, UX-A-29, UX-A-30, UX-A-31 |
| claims_assistant_screen | none | Guide tap is a silent no-op when guide is null (L179-183); call and email are unguarded (L332-339) | Loading, error, empty all present (L64-88) | Hardcoded (L63, L75-76, L94-95, L107, L136, L165, L263, L307, L321) | Fixed font sizes (L295, L373) | SafeArea in sheet (L236), OK | 4 (L32-39, L85) | Guidance disclaimer (L102-103) appropriate | UX-A-09, UX-A-19, UX-A-23, UX-A-24, UX-A-28 |
| consent_activity_screen | none | none | Skeleton, unavailable with retry, empty: all present; invalid result shown as "unavailable" (L43-45) | Hardcoded (L54, L80-90, L121, L312-362) | Skeleton has no label (L374-409); Semantics on rows OK (L164) | Scaffold, OK | 2 (L230-231) | Copy OK | UX-A-23, UX-A-27, UX-A-28, UX-A-32 |
| coverage_details_summary_screen | none | "Upgrade" routes to unregistered `/plans` (L503); share future not awaited inside try (L510-518) | No empty state when all fields are blank (shows dashes) | Hardcoded almost entirely (L25, L40, L42, L44-88, L139-266, L511-520 partly l10n); share text English-only (L534-802) | 15 literal `fontSize` values (L97-99, L172-201, L479, L482, L833-930) | SingleChildScrollView, OK | 8 (L267, L301, L331, L335, L378, L413, L421, L456) | "Everything Extracted" internal jargon (L40); negative "Days Remaining" (L161) | UX-A-02, UX-A-10, UX-A-16, UX-A-17, UX-A-18, UX-A-23, UX-A-24, UX-A-28, UX-A-39 |
| coverage_gap_screen | none | none | Empty message present (L100-118); no loading or error needed | Hardcoded (L56, L63-78, L86, L94, L112-113, L208-209); arb has `coverageGapTitle` and `coverageGapEmpty` unused | Badge font size 10 (L285) | Scaffold, OK | 1 (L177) | "Cross-checked" overclaims verification (L174); tier jargon (L74-78) | UX-A-07, UX-A-23, UX-A-24, UX-A-28, UX-A-40 |
| dashboard_screen | none | "Coverage details" routes to `/coverage-gaps` without citations, so it always shows empty data (L193, see UX-A-01); "Coverage summary" silent no-op (L488-499) | Loading (L58-63), error (L64-70), empty (L72-93) all present; RefreshIndicator returns before refresh completes (L53-56) | Hardcoded (L40, L44, L65, L107-108, L139-174, L226, L298, L356, L474, L486-530, L627-649, L737-759); arb has `dashboardQuickActions`, `dashboardAddPolicy` unused | Refresh IconButton has tooltip (L44), OK | Scaffold, OK | 14 (L143, L154, L166, L176, L192, L204, L215, L228, L487, L507, L521, L530, L637-641) | "Renew" and "Review" wording is appropriate; no advice found | UX-A-01, UX-A-08, UX-A-11, UX-A-23, UX-A-28, UX-A-33, UX-A-34 |

---

## 3. Checks that passed

- **Debug and placeholder UI:** No TODO, FIXME, "coming soon", placeholder, `debugPrint`, or lorem text in any of the 11 files.
- **Forbidden copy (premium estimates, scores, recommendations, guarantees):** Not found. Grep hits were "best match" (dropdown label in `claims_assistant_screen.dart:136`), which is a selection label and not advice. Premium and sum-insured values displayed in `coverage_details_summary_screen.dart` are extracted fields. Confirm that `PolicySummary.formattedPremium` (`models/policy_summary.dart:140`) formats the stored value and does not compute an estimate.
- **Disclaimers:** Present and appropriate on About (L80), Claim assistance (L61-66), Claims assistant (L102-103), Claim tracking (L138), Coverage gap (L74-78, L100-118), and Coverage details footer (L97-98).
- **Icon-button tooltips:** Present on all icon buttons except the fullscreen photo close button (`claim_tracking_screen.dart:214`).
- **SafeArea:** No missing SafeArea problem found. Scaffold handles top and bottom on all screens. The claim guide bottom sheet uses SafeArea explicitly (`claims_assistant_screen.dart:236`).
- **Named routes used:** `/qa`, `/renewals`, `/compare`, `/search`, `/documents`, `/claim-tracker`, `/coverage-gaps` are registered in `navigation/app_router.dart` and `app.dart`. Only `/plans` is missing (see UX-A-02).
- **Theme usage:** Claim assistance, Coverage gap (except one badge color), and Consent activity (except two colors) use theme tokens for most surfaces. Ad-hoc colors are concentrated in Dashboard, Coverage details, Claim tracking, Claims assistant, and Agent requests.

---

## 4. Findings

| ID | Severity | File:line | Issue | Fix |
|----|----------|-----------|-------|-----|
| UX-A-01 | BLOCKER | `screens/dashboard_screen.dart:186-196`, `screens/dashboard_screen.dart:193-194`, `navigation/app_router.dart:62-83` (L83), `screens/coverage_gap_screen.dart:27`, `screens/coverage_gap_screen.dart:51-52`, `screens/insights_screen.dart:57-62` | The `/coverage-gaps` named route builds `CoverageGapScreen(documentId: documentId)` without citations, so the screen's default `citations = const []` applies. Room rent and insurer lookups always return null, and the user sees "We don't have this information for your policy yet" even when extracted data exists. The dashboard "Coverage details" tile and the Insights entry both reach this screen. Only `policy_detail_screen.dart:1597` passes citations. | Resolve citations for `documentId` inside the route builder (same source as `policy_detail_screen.dart:1597`), or pass them via route arguments. Add a widget test that asserts room rent appears when the substrate has the field (S2 test first). |
| UX-A-02 | HIGH | `screens/coverage_details_summary_screen.dart:503` | "Upgrade" action in the export gate calls `Navigator.pushNamed(context, '/plans')`. No `/plans` route is registered in `navigation/app_router.dart` or `app.dart`. Tapping it hits `appOnUnknownRoute` (`app_router.dart:177-189`) and shows "Page not found". This is a dead end in the monetization path. | Register `/plans` to `screens/paywall_screen.dart` in `buildAppRoutes()`, or push the paywall directly. Add a route test. |
| UX-A-03 | HIGH | `screens/account_screen.dart:33`, `screens/account_screen.dart:114`, `screens/account_screen.dart:52-62` | When `AppConfig.hasSupabaseAuthConfig` is false, the screen still renders the full email and password form. Submitting shows the developer message "Account auth is not configured for this build." Google sign-in is hidden, but the form remains. A user on a misconfigured build sees a non-functional form and a dev-facing message. | Hide the form and show a localized "Sign-in is unavailable" state when auth is not configured. Use the existing arb key `accountAuthNotConfigured` (`app_en.arb:334`). |
| UX-A-04 | HIGH | `screens/account_screen.dart:158-257` | Every visible string is hardcoded, although the arb already defines matching keys: `accountTitle`, `accountHeaderTitle`, `accountHeaderSubtitle`, `accountNameLabel`, `accountEmailLabel`, `accountPasswordLabel`, `accountResendBanner`, `accountForgotPassword`, `accountResendVerification`, `accountSwitchToSignIn`, `accountGoogleSignIn`, and the error keys (`app_en.arb:322-349`). Errors at lines 33-98 and 114-149 are also literal. | Replace literals with `AppLocalizationsGen` lookups, as `coverage_details_summary_screen.dart:19` already does. Add ICU select for sign-in vs create-account titles. |
| UX-A-05 | HIGH | `screens/claim_assistance_screen.dart:117-122`, `screens/claim_assistance_screen.dart:127`, `screens/claim_assistance_screen.dart:284-289`, `screens/claim_assistance_screen.dart:318-331` | When the insurer name is unknown, the "Refresh" button calls `_openInsurerClaims(context, insurerName: null)`, which does nothing. The "View insurer claim process" button calls the same no-op. Both controls look live and give no feedback. | Remove "Refresh", or make it re-read citations. Disable "View insurer claim process" when there is no insurer and show a short explanation with the insurer contact instruction already present at L110-111. |
| UX-A-06 | HIGH | `screens/claim_assistance_screen.dart:318-321`, `screens/claim_assistance_screen.dart:287-288` | The button labelled "View insurer claim process" opens a Google search for "`<insurer>` claim process". The label implies the insurer's own page. The insurer name is sent to a third-party search engine without disclosure. | Rename to "Search online for `<insurer>` claim process" with a visible note that results are not from the insurer. Or link to an insurer URL that is cited from the policy document. |
| UX-A-07 | HIGH | `screens/coverage_gap_screen.dart:63-78`, `screens/coverage_gap_screen.dart:174`, `screens/coverage_gap_screen.dart:207-209` | Copy describes items as "Cross-checked" and "Lower confidence" and explains "Tier 0/1/2" to end users. "Cross-checked" implies independent verification that the app may not have performed. Product rules require reliability claims to be conditional and evidence-backed, and tier numbers are internal jargon. The copy also references a "Pending extraction" state that this screen never renders. | Replace with plain statements, for example "Found in policy text" and "Needs checking against your policy". Remove tier numbers. Either render the pending state or remove the reference. Route wording to the legal copy review (`docs/legal_risk_copy_audit_2026-07-24.md`). |
| UX-A-08 | HIGH | `screens/dashboard_screen.dart:487-499` | The "Coverage summary" quick tool does nothing when `policySummaries` is empty. Documents can exist before summaries are ready, so the tile can appear live with no response. | Disable the tile with a "Summary not ready yet" label, or show a snackbar. |
| UX-A-09 | HIGH | `screens/claims_assistant_screen.dart:179-183` | "View preparation guide" returns silently when `claimGuideProvider` yields null. The user taps a primary action and nothing happens. | Show an error or empty state with a retry, using `CoverWiseSnackBar` or an inline message. |
| UX-A-10 | HIGH | `screens/coverage_details_summary_screen.dart:161`, `models/policy_summary.dart:116-119` | For an expired policy, `daysUntilExpiry` is negative (for example, -12). The "Days Remaining" row shows "-12 days". The dashboard uses `.abs()` for the same value (`dashboard_screen.dart:152`), so the two screens disagree. | Show "Expired N days ago" when `isExpired`, otherwise show remaining days. Keep the dashboard and summary consistent. |
| UX-A-11 | HIGH | `screens/dashboard_screen.dart:154-166`, `screens/dashboard_screen.dart:176`, `screens/dashboard_screen.dart:292-298` | Primary CTA uses `Colors.white` text on `action.color`. Amber `#EF8C1A` gives about 2.5:1 contrast with white (estimated), which fails WCAG AA. Teal `#079A86` gives about 3.5:1, which passes only the large-text threshold. Red `#E53935` gives about 4.2:1 (estimated). The button label is 14sp bold, so the large-text exemption is marginal. | Use a darker amber and red for text-bearing CTAs, or use dark text on amber. Verify with a contrast tool before release. |
| UX-A-12 | MED | `screens/claim_assistance_screen.dart:251`, `screens/claim_assistance_screen.dart:297-302` | Heading says "Filing a claim in 5 steps" but the list has 6 items. | Change the heading to "Filing a claim" or correct the count. Generate the count from the list length. |
| UX-A-13 | MED | `screens/claim_assistance_screen.dart:40-46`, `screens/claim_assistance_screen.dart:133-137`, `widgets/not_yet_extracted_section.dart` (defaults) | The screen shows internal field names ("Per-policy claim document checklist", "Per-policy claim form draft") and promises "They will be added in a future update." Roadmap commitments and internal terms do not belong in launch UI. | Replace with user-facing language, such as "Not in your policy summary yet. Contact your insurer for this." Remove the roadmap promise. |
| UX-A-14 | MED | `screens/claim_assistance_screen.dart:379` | File ends with a dangling doc comment: "IRDAI escalation. Deserves its own section, not buried as". The grievance-escalation section is missing. For an Indian insurance product, a regulator-escalation path is a launch expectation. | Route to product owner. Either build the section with cited, non-advisory copy or remove the comment. Record the decision in `DECISION_LOG.md`. |
| UX-A-15 | MED | `screens/account_screen.dart:237` | "Continue with Google" uses `Icons.g_mobiledata_rounded`, which is not the official Google mark. Google's sign-in branding rules require the official logo. | Use the official Google "G" asset from the approved branding source. Confirm against Google's current guidelines. |
| UX-A-16 | MED | `screens/coverage_details_summary_screen.dart:508-518` | `SharePlus.instance.share(...)` is not awaited inside `try`, so async share failures are never caught. The `catch` at L514 only handles synchronous errors. | `await` the share call inside the `try` block, or return its future. Add an error-path test. |
| UX-A-17 | MED | `screens/coverage_details_summary_screen.dart:534-802` | Shared text is English-only, uses emoji (for example L538, L545, L548), and is not localized beyond subject line L512. Shared content goes to external apps. | Move labels into arb, or generate the share text from localized field labels. Replace emoji with plain text. |
| UX-A-18 | MED | `screens/coverage_details_summary_screen.dart:25`, `screens/coverage_details_summary_screen.dart:40`, `screens/coverage_details_summary_screen.dart:44-88` | Title "Everything Extracted" is internal pipeline language. Title case differs from the other screens. | Rename to a plain title such as "Your policy details". Match sentence case with the rest of the app. |
| UX-A-19 | MED | `screens/claims_assistant_screen.dart:332-339` | `_callNumber` and `_sendEmail` call `launchUrl` without checking the result or catching exceptions. On devices without a dialer or mail app, the tap fails silently. | Use `canLaunchUrl` and show a snackbar with the number or address to copy when it returns false. Wrap in try/catch. |
| UX-A-20 | MED | `screens/about_screen.dart:14-19` | `_openUrl` returns silently when `canLaunchUrl` is false. The privacy and terms rows show an external-link icon but do nothing. | Show a snackbar with the URL or fall back to the in-app screen, as the `else` branch already does (L109-115). |
| UX-A-21 | MED | `screens/agent_requests_screen.dart:36-45`, `screens/agent_requests_screen.dart:69-71` | `markContacted` and `clear` have no try/catch. A storage failure surfaces as an unhandled async error, and the success snackbar still appears if the call did not throw. | Wrap each in try/catch, reload state in `finally`, and show an error snackbar on failure. |
| UX-A-22 | MED | `screens/agent_requests_screen.dart:261-277` | Row contains an icon, a SizedBox, and a `Text` that is not wrapped in `Expanded`. A long insurer name with document type can overflow at large text scale. | Wrap the `Text` in `Expanded` and set `maxLines: 2, overflow: TextOverflow.ellipsis`. |
| UX-A-23 | MED | `screens/dashboard_screen.dart:143, 154, 166, 176, 192, 204, 215, 228, 487, 507, 521, 530, 637-641`; `screens/coverage_details_summary_screen.dart:267, 301, 331, 335, 378, 413, 421, 456`; `screens/claim_tracking_screen.dart:247-253`; `screens/claims_assistant_screen.dart:32-39, 85`; `screens/agent_requests_screen.dart:199, 204, 234`; `screens/consent_activity_screen.dart:230-231`; `screens/coverage_gap_screen.dart:177` | Ad-hoc `Color(0x..)` literals are used outside `CoverWiseColors`. `CoverWiseColors` (`theme/coverwise_theme.dart:4-12`) has no success, warning, danger, or teal tokens, so screens each invent their own. This breaks dark-mode consistency because these colors do not adapt. | Add semantic tokens to `CoverWiseColors` (success, warning, danger, accent teal, purple) with light and dark variants. Replace literals. |
| UX-A-24 | MED | `screens/coverage_details_summary_screen.dart:172, 177, 182, 187, 199-201, 479, 482, 833, 835, 877, 906, 930`; `screens/coverage_gap_screen.dart:285`; `screens/claims_assistant_screen.dart:295, 373`; `screens/account_screen.dart:208` | Literal `fontSize` values (10 to 14) bypass `textTheme`. The 10sp evidence-tier badge and the 11sp field labels are below comfortable reading size. | Replace with `Theme.of(context).textTheme` styles. Set a 12sp minimum for labels. Verify at 200% text scale. |
| UX-A-25 | MED | `screens/claim_tracking_screen.dart:214-217` | Fullscreen photo close `IconButton` has no tooltip. Screen readers announce an unlabeled button. | Add `tooltip: 'Close'` (localized). |
| UX-A-26 | MED | `screens/claim_tracking_screen.dart:340-381` | Reference-number tap target is an `InkWell` around a 15px icon and 3px vertical padding, about 24dp tall. This is below the 44-48dp minimum. | Wrap in a `SizedBox` or `ConstrainedBox` with minimum 44dp height, or use `TextButton.icon`. |
| UX-A-27 | MED | `screens/consent_activity_screen.dart:43-45`, `screens/consent_activity_screen.dart:320` | `ConsentSnapshotInvalid` renders the same "could not reach the account ledger" message as `ConsentSnapshotUnavailable`. Invalid data is not a connectivity failure, so the message is misleading. | Give invalid responses their own copy, for example "We could not read your consent history. Try again." |
| UX-A-28 | MED | Systemic: see per-screen column "Hardcoded strings" | Across all screens except Coverage details (which uses one l10n key for the share action), user-visible strings are literal. Arb keys already exist for some screens and are unused: account (L322-349), coverage gap (`coverageGapTitle` L460, `coverageGapEmpty` L461), dashboard (`dashboardQuickActions` L452, `dashboardAddPolicy` L454), family (`familyAddButton` L127, `familyAddMember` L119), and privacy (`privacyTitle` L432). About, Claim assistance, Claim tracking, Claims assistant, Consent activity, and Agent requests have no arb keys. | Create keys for all remaining user-visible strings in `app_en.arb`. Use `AppLocalizationsGen` throughout. Note: "Coverage Review" (arb) and "Coverage review" (screen) already differ. |
| UX-A-29 | LOW | `screens/claim_tracking_screen.dart:439-475` | Timeline toggle `InkWell` does not expose expanded or collapsed state to assistive technology. | Wrap in `Semantics(button: true, expanded: isTimelineExpanded)`. |
| UX-A-30 | LOW | `screens/claim_tracking_screen.dart:62` | `TextEditingController` in `_editReferenceNumber` is never disposed. | Create the controller in a stateful dialog widget with `dispose`, or dispose after `showDialog` returns. |
| UX-A-31 | LOW | `screens/claim_tracking_screen.dart:392-412`, `screens/claim_tracking_screen.dart:189-193` | Photo thumbnails and fullscreen images have no semantic label. Thumbnail `GestureDetector` has no button semantics. | Add `Semantics(label: 'Claim photo N', button: true)` and `semanticLabel` on `Image.file`. |
| UX-A-32 | LOW | `screens/consent_activity_screen.dart:374-409` | Loading skeleton has no semantic label, so screen readers announce nothing while loading. | Wrap in `Semantics(label: <localized "Loading consent history">, liveRegion: true)`. |
| UX-A-33 | LOW | `screens/dashboard_screen.dart:53-56` | RefreshIndicator `onRefresh` invalidates providers but does not await them, so the spinner dismisses immediately. | Await the provider futures (`ref.read(...future)`) before returning from `onRefresh`. |
| UX-A-34 | LOW | `screens/dashboard_screen.dart:219-221` | Blank comment block where "Action 4" was removed. Code debris that suggests an unfinished change. | Delete the blank lines and renumber the comment. |
| UX-A-35 | LOW | `screens/add_family_member_dialog.dart:43-58`, `screens/add_family_member_dialog.dart:130-139`, `screens/add_family_member_dialog.dart:52` | Date of birth cannot be cleared once set. `setState` runs after an `await` without a `mounted` check. | Add a clear suffix button for the date field. Guard `setState` with `if (!mounted) return;`. |
| UX-A-36 | LOW | `screens/account_screen.dart:181-185` | Password field has no visibility toggle and no `autofillHints`. | Add `suffixIcon` visibility toggle with a localized tooltip. Set `autofillHints: [AutofillHints.password]`. |
| UX-A-37 | LOW | `screens/account_screen.dart:52`, `screens/account_screen.dart:119` | `prepareAnonymousWorkspaceClaim()` runs before credentials are verified. This is outside UI scope. | Refer to the security and privacy audit to confirm claim timing and failure behavior. |
| UX-A-38 | LOW | `screens/agent_requests_screen.dart:220` | Phone number is displayed unmasked in the request list. | Mask all but the last four digits in the list. Show full number only on the card detail if one exists. |
| UX-A-39 | LOW | `screens/coverage_details_summary_screen.dart:137-164` | No empty state when the summary has no extracted fields. Sections render as rows of dashes. | Show a single "Not enough details were extracted from this policy yet" state with the source-check note. |
| UX-A-40 | LOW | `screens/coverage_gap_screen.dart:74-78` | Copy describes a "Pending extraction" badge that this screen never renders. | Covered by UX-A-07 fix. Remove the reference or render the state. |

---

## 5. Priority order for remediation

1. **UX-A-01** (BLOCKER): fix the `/coverage-gaps` citation source before any dashboard tile ships.
2. **UX-A-02, UX-A-03, UX-A-05, UX-A-06, UX-A-08, UX-A-09, UX-A-10**: dead paths and incorrect values that a reviewer will hit in the first session.
3. **UX-A-07, UX-A-11, UX-A-14**: copy overclaims, contrast, and the missing escalation section. These need owner or legal review, not only code changes.
4. **UX-A-04, UX-A-28**: localization. Account screen is first because arb keys already exist.
5. **UX-A-16, UX-A-19, UX-A-21, UX-A-27**: error handling on async paths.
6. **UX-A-23, UX-A-24, UX-A-25, UX-A-26**: visual tokens and accessibility.
7. LOW items as capacity allows.

---

## 6. Inferred, unknown, and unverified

- **Contrast ratios** in UX-A-11 are estimates from sRGB math and must be confirmed with a contrast tool on the real theme.
- **Route behavior** for `/plans` (UX-A-02) relies on `appOnUnknownRoute` as shown in `navigation/app_router.dart:177-189`. Runtime behavior was not observed.
- **`ConsentSnapshotInvalid`** handling (UX-A-27) assumes the sealed-class variants are mutually exclusive as used in the switch. Not verified at runtime.
- **Claim log and dashboard data** (UX-A-01, UX-A-10) were not exercised with real data. The behavior follows from the source.
- **Insights screen** reaches `/coverage-gaps` too (`screens/insights_screen.dart:57-62`). It is outside this audit's scope but inherits UX-A-01.
- **Not run:** widget tests, golden tests, Flutter analyze, device runs, TalkBack or VoiceOver checks, text-scale checks. Every finding is Tier 1 and S0 until verified.

---

## 7. Remaining risks and hardening path

| Risk | Hardening path |
|------|----------------|
| Silent dead taps on several primary controls (UX-A-05, UX-A-08, UX-A-09) are invisible in unit tests | Add widget tests that tap each control in the empty and unknown states and assert visible feedback (S2: fail first, then pass). |
| Copy overclaims on coverage reliability (UX-A-07) | Route to legal copy audit; add a copy-lint check for "Cross-checked", "verified", and tier numbers in `lib/screens/`. |
| Localization drift (UX-A-04, UX-A-28) | Add a CI check that fails on new `Text('` literals in `lib/screens/` outside an allowlist. |
| Contrast and font-size regressions (UX-A-11, UX-A-24) | Add a golden or accessibility-guideline test for the dashboard CTA at 200% text scale. |

---

## 8. Docs, artifacts, and uncommitted work

- **Files changed:** none. Read-only inspection, plus this report.
- **Artifacts written:** `docs/audits/app_store_readiness_2026-10-12/02a_ui_ux_screens.md` (this file).
- **Uncommitted work:** Not touched. The repository already had many modified files at session start; none were staged, committed, or reverted.
- **Follow-up decisions needed from owner:**
  - Whether the IRDAI or grievance escalation section (UX-A-14) ships at launch.
  - Whether the Google-search claim-process link (UX-A-06) is kept, relabeled, or removed.
  - Whether to proceed with the account-screen auth-unavailable state (UX-A-03).
  - Legal review of the coverage reliability wording (UX-A-07).

## 9. Review passes

1. **Correctness:** Every file:line in this report was read directly. Route and l10n cross-checks used grep against `navigation/app_router.dart`, `app.dart`, and `app_en.arb`.
2. **Architecture and ownership:** Findings name canonical sources (`CoverWiseColors`, `AppLocalizationsGen`, `app_router.dart`) rather than proposing parallel ones.
3. **Doctrine and evidence:** All claims are Tier 1 and S0. No runtime, device, or production claim is made.
