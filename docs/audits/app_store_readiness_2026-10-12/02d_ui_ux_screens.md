# 02d UI/UX Launch-Readiness Audit: Flutter Screens and Shared Widgets

**Date:** 2026-10-12
**Scope:** `mobile/lib/screens/` (10 named screens), plus a quick pass over `mobile/lib/widgets/` and `mobile/lib/theme/`.
**Method:** Static inspection only (Evidence Tier 1). Grep sweeps plus targeted reads of each file. No runtime, device, screenshot, VoiceOver, or text-scale testing was performed. No existing files were edited and no Git commands were run.
**Localization source:** `mobile/lib/l10n/app_en.arb` and the generated `app_localizations_gen*.dart`.

## Summary of counts

| Screen | Lines | `l10n.` uses | Hardcoded user-visible literals (approx.) | Forbidden-copy hit |
|---|---|---|---|---|
| profile_screen.dart | 612 | 52 | 10+ | No |
| qa_packs_screen.dart | 450 | 3 | 15+ | No |
| qa_screen.dart | 2313 | 47 | 12+ | No (but missing disclaimer, see UX-D-01) |
| renewal_calendar_screen.dart | 1025 | 31 | 8+ | No |
| reset_password_screen.dart | 166 | 0 | 12+ | No |
| search_screen.dart | 647 | 0 | 20+ | No |
| settings_screen.dart | 684 | 47 | 15+ | No |
| splash_screen.dart | 248 | 0 | 3 | No |
| terms_of_service_screen.dart | 139 | 0 | 6 | No |
| upgrade_screen.dart | 738 | 0 | 30+ | No (but unverified savings claim, see UX-D-03) |

## Per-screen table

Legend: PASS = no issue found in static inspection. FAIL = issue found. VERIFY = needs runtime check.

| Screen | Placeholder / TODO / debug UI | Dead buttons | Loading / empty / error states | Hardcoded strings (not in ARB) | Accessibility (tooltips, semantics, tap targets, fixed sizes, overflow) | SafeArea | Ad-hoc colors vs CoverWiseColors | Forbidden copy (advice, score, premium estimate) | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| **profile_screen** | PASS for TODO. FAIL: raw exception text shown to user (555). debugPrint at 185, 187 (log only). | PASS. Delete flow wired (250-300). | Partial. Family section has loading (552) and error (553-556), but error is raw `$e`. | FAIL: "Export account data?" dialog 313-317, "Export" 326, "Family" 573, "No family members detected yet" 580, "Family members" 602, "people across your policies" 603, "Add family member" 590 (ARB key exists). | FAIL: `value == 'DELETE'` (70) is an English-only typed confirmation. Fixed sizes 12 (229). | Scaffold/AppBar covers top. VERIFY bottom. | FAIL: hex colors at 83, 211, 241, 381, 415, 434, 461, 485, 507, 516, 565, 601. | PASS. | FAIL (HIGH) |
| **qa_packs_screen** | PASS for TODO. | PASS. Buy buttons wired to billing (333-390). | FAIL: no loading or error UI for `qaPackStateProvider` (line 32). Balance card has no loading or error fallback. | FAIL: "Buy a pack" 48, "No subscription needed. Pay once, ask questions." 55, "Your packs" 75, "Pack purchased!..." 98 (ARB has parameterized key), "Start asking" 104, "How packs work" 114, all FAQ text 120-139, "Best value" 282, "Buy" 333, "questions available" 165, "from monthly plan" 177-194. "pack(s)" at 186 is not pluralized. | FAIL: fixed sizes 14-16 (throughout). | Uses SingleChildScrollView under Scaffold. PASS. | FAIL: Colors.green 94, Colors.orange 441. | VERIFY: factual claims at 127-128 ("valid for 90 days", "unused questions are lost") and 132-133 ("FIFO") must match server behavior. | FAIL (MED) |
| **qa_screen** (2313 lines) | PASS for TODO and coming-soon. VERIFY: demo sequence at 107-150 is gated by `AppConfig.bootstrapPolicyDemo`, which app_config.dart:414-415 rejects in release builds. Demo question list is hardcoded (130-137). | PASS for most. FAIL: clear-search IconButton at 1398-1404 has no tooltip. | PASS. Loading at 1220, 2259. Error and retry at 407-408, 567-568, 691-692. Empty state at 1366. | FAIL: "Q: " 1792, "A: " 1816, "Sources (n):" 2020, "You might also be interested in:" 1759, "You might also ask:" 2031 (ARB key exists), "Retry" 407, 567, 691, feedback and copy tooltips 2050, 2066, 2082, 2093, "Answer copied", "High/Medium/Low" 2297-2300. | FAIL: missing tooltip (1398). Fixed fontSize 16 at 1793-1794 and 1817, 14 and 13 at 2011-2015. Confidence and relevance % at 2139-2200 are shown as numbers. | Uses ConstrainedBox and SingleChildScrollView. PASS. | FAIL: Colors.green/orange/red at 939-940, 2187-2202. Hex at 1370. | Advice: no advice-style copy. **Citations: present** (1818-1993, verified or rejected states, "Verify in your policy"). **Disclaimer: absent.** Share text at 2092-2096 sends only Q and A with no source or disclaimer. | FAIL (BLOCKER on disclaimer, see UX-D-01) |
| **renewal_calendar_screen** | PASS for TODO. | PASS. | PASS. Empty state for no policies (`hasNoPolicies`). No error state for the summaries load (verify). | FAIL: "Switch to calendar" / "Switch to list" 117-118, "Previous month" 343, "Next month" 364, "Today" 357 (ARB key exists), legend "Active" / "Expiring soon" / "Expired" 397-399. | PASS. IconButtons have tooltips (106, 340, 361). Adaptive large-text logic at 807. VERIFY date-cell tap targets. | Uses SafeArea at 2 places. PASS. | FAIL: hex status colors at 45-47, 148, 397-399, 681; Colors.red/orange/green/blueGrey at 212-240, 685, 958-968. Fixed colors are not theme-aware (dark mode unverified). | PASS. | FAIL (MED) |
| **reset_password_screen** | PASS for TODO. | PASS. | PASS. Busy state (147-155). Error text (136-145). | FAIL: entire screen is English with zero l10n: "Reset password" 72, headers 77-80, error copy 35, 39, 58-59, field labels 123-124, 133, "Back to sign in" 104, "Update password" 155. | FAIL: no Semantics on spinner. Autofill hints absent (118-134). | Scaffold + AppBar. PASS. | FAIL: Color(0xFF0F9D50) at 89. | PASS. | FAIL (HIGH for localization) |
| **search_screen** | PASS for TODO. | PASS. | FAIL: no loading state for search. Empty states PASS (173-179 and onboarding branch at 155-171). | FAIL: entire screen is English with zero l10n: "Search policies" 89, hint 99, "Clear search" 103, "Nothing matched" 176, "Try another term..." 177, filter chips 220-252 ("All", "Active", "Expiring", "Expired", "All Types"), filter Semantics label 296 ("$label filter"), "EXPIRED" 358, "$days days left" 360, "Active" 361, "Benefit"/"Exclusion" 449-453, "Coverage: ..." 474, "...and N more match(es)" 529. | FAIL: grey.shade500 text at 530 and 617 has poor contrast on white (WCAG AA risk). Fixed 11-12 sizes at 517, 530, 617. Horizontal filter bar scrolls at 205-216 (PASS). Live region at 128 (PASS). | Scaffold + AppBar. PASS. | FAIL: Colors.grey/green/orange/red/blue at 222-264, 358-361, 450-470, 614; hex 169, 178. | VERIFY: "Premium" label at 420-422 is extracted from the document, not estimated. PASS. | FAIL (HIGH for localization) |
| **settings_screen** | FAIL (MED): "Service endpoint" row shows the raw backend base URL to end users (537-543). Internal infrastructure detail. | PASS. Info rows use onTap:null by design. | PASS. Confirm dialog (179-215). Error snackbar at 328-330. | FAIL: theme labels "System default" / "Light" / "Dark" 63-67, 79-81; "Appearance" 76; "Language / भाषा" 133; "Unknown" 406. | PASS. No IconButton. | Scaffold + AppBar. PASS. | FAIL: hex 361-362, 384, 402, 429, 442, 474, 482, 496, 517, 530, 539, 553, 585, 669, 678; Colors.red.shade700 194; Colors.blue 103, 158. | PASS. Performance cost card (415-421) displays "Each question costs 1 Q&A unit" copy, see UX-D-22. | FAIL (MED) |
| **splash_screen** | PASS for TODO. | N/A. | PASS. Health banner is an error state (182-248). | FAIL: "CoverWise" 138 (brand, acceptable), tagline "Your cover, made clear." 148, banner copy "Service unavailable. Some features may be limited. Reconnecting..." 233-234. | PASS. Logo is decorative (133). Fixed sizes 34 and 15 at 140, 150 (acceptable for brand). | Banner uses SafeArea (209). Main content centered. PASS. | FAIL: hex banner colors 200-208. Light banner background #FFF4DD is hardcoded. Dark mode is handled via brightness. | PASS. | FAIL (LOW-MED) |
| **terms_of_service_screen** | PASS for TODO. | PASS. | PASS. Loading (58), error with retry (61-70). | FAIL: "Terms of Service" 39, tooltip "Copy terms text" 43, snackbar "Terms of service copied to clipboard" 49, error "The terms of service could not be loaded." 63, "Effective ..." 108. Legal body is English-only from the asset markdown. | PASS. Copy button has a tooltip (43), but it is English. | SingleChildScrollView under Scaffold. PASS. | PASS. Uses CoverWiseColors (92). | PASS. | FAIL (MED, localization of legal text) |
| **upgrade_screen** | PASS for TODO. | PASS. Disabled buttons at 450 and 458 are intentional ("Current plan" / "Free forever"). FAIL: when `billingReady` is false, the Upgrade button is silently disabled (466-468) with no explanation or loading state. | FAIL: no loading state for billing (`billingInitProvider`, 34-35). Error is silent. | FAIL: zero l10n. "Choose your plan" 40, "Manage" 45, "Plan limit reached" 57, "Plan upgraded!..." 100, "Start using" 106, "Compare plans" 117, "Questions" 128, all FAQ text 135-147, "Annual" 286, "Save up to 44%" 298 (generated key `upgradeSaveUpTo` exists), "Best value" 395, feature chips 431-441, "Current plan" 451, "Free forever" 459, "Upgrade to ..." 475, "Billing is not available yet..." 160, "Compare policies" 572, "Feature" 606. | FAIL: fixed sizes 13, 18, 20 at 386-415. Price Text at 412-419 sits in a Row and is not constrained (overflow risk at large text, VERIFY). | SingleChildScrollView under Scaffold. PASS. | FAIL: hex 192, 349, 417; Colors.green 96; mint and blue tokens are used correctly elsewhere. | **Advice check:** no recommendation copy. "Best value" 395 and 282 are marketing badges, not advice. **Payment check:** PASS. Subscriptions go through RevenueCat, which wraps StoreKit and Play Billing (billing_adapter.dart:241-262). Manage uses App Store and Play subscription URLs (347-366). No web checkout is present in these screens. | FAIL (HIGH for localization, MED for savings claim) |

## Findings table

Severity key: BLOCKER = must fix before submission. HIGH = fix before launch. MED = fix in launch window or with a documented waiver. LOW = polish.

| ID | Sev | File:line | Issue | Fix |
|---|---|---|---|---|
| UX-D-01 | BLOCKER | qa_screen.dart:2002-2044 (answer card). No disclaimer string exists in `mobile/lib/**/*.dart` or `app_en.arb`. | AI answers show citations (1818-1993), but there is no "not advice" disclaimer. The brief's forbidden-advice rule requires one for an insurance AI answer. | Add a localized, persistent disclaimer under every AI answer, for example "This answer is based on your uploaded document. It is not insurance, legal, or financial advice. Verify important details with your insurer." Add the ARB key, and an S2 widget test that asserts the disclaimer renders for a non-empty answer. |
| UX-D-02 | HIGH | qa_screen.dart:2092-2096 | The share action sends only "Q: ... A: ..." with no citations, source, or disclaimer. Answers leave the app with no provenance. | Append the source-document name and the disclaimer text to the shared payload, using the same ARB keys as UX-D-01. |
| UX-D-03 | MED | upgrade_screen.dart:298 | "Save up to 44%" is hardcoded and is a savings claim. The generated key `upgradeSaveUpTo` already exists (app_localizations_gen_en.dart:1039). No pricing evidence was found in this audit. | Use the l10n key. Compute the discount from the live `priceMonthly` and `priceYearly` values, or remove the claim. Record the basis for the claim in the decision log. |
| UX-D-04 | HIGH | reset_password_screen.dart (all), search_screen.dart (all), upgrade_screen.dart (all), terms_of_service_screen.dart:39-63, splash_screen.dart:148, 233-234 | Four screens are fully or mostly hardcoded English. Settings offers 5 locales (settings_screen.dart:136-139), so users in hi, gu, mr, and ta will see mixed-language screens. | Move all literals to ARB keys. Reuse existing keys where they exist (for example "Buy a pack", "Choose your plan"). Add a lint or grep gate that fails on new `Text('[A-Z]` in `screens/`. |
| UX-D-05 | HIGH | profile_screen.dart:555 | Error state shows the raw exception: `Text('Error loading family: $e')`. Internal exception text reaches users and is not localized. | Replace it with `AppErrorView` and a localized message, log `$e` through the existing error path, and add a retry. |
| UX-D-06 | MED | settings_screen.dart:537-543 | The "Service endpoint" row displays the raw backend base URL to end users. This is a debug-style infrastructure detail. | Move it behind a debug or support screen, or hide it in release builds. |
| UX-D-07 | MED | settings_screen.dart:179-215 and profile_screen.dart:193-300 | Settings only offers "Clear data" (device wipe, 552-554). In-app account deletion lives only in the Profile tab (main_navigation.dart:90). This meets the in-app deletion requirement, but a user looking for it in Settings will not find it. | Add a Settings row "Delete account" that routes to the Profile deletion flow, and rename "Clear data" to "Erase this device". |
| UX-D-08 | MED | profile_screen.dart:70 | The typed confirmation `value == 'DELETE'` is an English literal. Non-English users must type the English word, and the hint may not match. | Compare against a localized confirmation word, or require a checkbox or long-press instead of a typed word. |
| UX-D-09 | MED | profile_screen.dart:313-317, 326 | "Export account data?" and its privacy copy ("may include short-lived links to your private source files") are hardcoded English. This is consent-relevant copy. | Move to ARB keys and have legal review the translations. |
| UX-D-10 | MED | upgrade_screen.dart:466-468, 34-35 | When billing is not ready, plan buttons are silently disabled. There is no loading indicator and no explanation. This reads as a dead button. | Show a localized loading state while `billingInitProvider` loads, and a retry message on error. |
| UX-D-11 | MED | qa_packs_screen.dart:32, 165-194 | The balance card and pack list have no loading or error UI. Balance strings are hardcoded English and the "pack(s)" text is not pluralized. | Add loading and error states. Localize with plural ARB keys. |
| UX-D-12 | MED | qa_screen.dart:2139-2200, 2297-2300 | Relevance percent and "High/Medium/Low" confidence badges are shown as numbers next to legal-style answers. They read as an answer score. | Keep them only if the product owner approves. Label them clearly ("Source match" not "%"), localize, and document the basis in the decision log. |
| UX-D-13 | MED | qa_packs_screen.dart:113-139, 282 | FAQ factual claims ("valid for 90 days", "unused questions are lost after expiry", "FIFO") are hardcoded. They must match server behavior. "Best value" is a marketing badge. | Verify each claim against the backend ledger. Move to ARB. Record evidence in the decision log. |
| UX-D-14 | MED | qa_screen.dart:407, 567, 691 and lines 2050-2093 | "Retry" and feedback, copy, and share tooltips are hardcoded English. | Move to ARB. |
| UX-D-15 | MED | qa_screen.dart:1398-1404 | The clear-search IconButton has no tooltip. | Add `tooltip: l10n.<clearSearch>`. |
| UX-D-16 | MED | search_screen.dart:220-296 and whole file | No localization. Filter chip semantics "$label filter" is English. | Localize the full screen. |
| UX-D-17 | MED | search_screen.dart:530, 617 | Secondary text uses `Colors.grey.shade500` on white at 11pt. This likely fails WCAG AA contrast. | Use `theme.colorScheme.onSurfaceVariant` with a verified contrast ratio. |
| UX-D-18 | MED | renewal_calendar_screen.dart:45-47, 148, 212-240, 397-399, 681-685 | Status colors are hardcoded hex or Material colors, not theme-aware. Legend labels and tooltips are English. | Route status colors through CoverWiseColors or a theme extension with dark variants. Localize labels. Verify dark-mode contrast. |
| UX-D-19 | MED | upgrade_screen.dart:412-419 (and 380-421 row) | The price Text is not wrapped in Expanded or flexible layout. At large text scale the plan header row can overflow. | Wrap the title column in Expanded and let the price shrink with FittedBox or wrap. Verify at 200% text scale. |
| UX-D-20 | MED | services/lead_generation_service.dart:118-193 and widgets/shared/contextual_cta_card.dart | CTA copy is hardcoded English (for example "Review your policy wording", "Ask about this policy"). The copy itself is conditional and does not give advice. | Move to ARB keys. Keep the conditional wording. |
| UX-D-21 | MED | widgets/shared/operation_usage_card.dart:95-99 | "Each question you ask costs 1 Q&A unit from your monthly or pack budget." is hardcoded English, with fixed fontSize 11. | Move to ARB. Use a scale-safe text style. |
| UX-D-22 | MED | settings_screen.dart:63-67, 76-81, 133-139 | Appearance and language dialogs have hardcoded English labels ("System default", "Light", "Dark", "Appearance"). | Move to ARB. |
| UX-D-23 | MED | terms_of_service_screen.dart and assets/legal | The terms document is English-only, while the app offers 4 Indian languages. | Confirm with legal whether a localized terms version is required for launch markets. If yes, add localized assets and a locale-aware loader. |
| UX-D-24 | LOW | terms_of_service_screen.dart:43-63 | Copy tooltip, snackbar, and error text are hardcoded English. | Move to ARB. |
| UX-D-25 | LOW | qa_screen.dart:1792, 1816, 2020 | "Q: ", "A: ", and "Sources (n):" are hardcoded. | Move to ARB with a count parameter. |
| UX-D-26 | LOW | splash_screen.dart:200-208, 233-234 | Banner colors are hardcoded hex. The "Service unavailable" banner is English. | Use theme tokens. Move copy to ARB. |
| UX-D-27 | LOW | reset_password_screen.dart:118-134 | Password fields have no `autofillHints`. | Add `AutofillHints.newPassword` to improve password-manager use. |
| UX-D-28 | LOW | profile_screen.dart:185, 187; qa_screen.dart:369, 373, 656, 660, 755, 811 | `debugPrint` calls remain in production code paths. They are log-only, but they add noise. | Route through the existing logger, gated for release. |
| UX-D-29 | LOW | qa_screen.dart:107-150; config/app_config.dart:69-70, 414-415 | The demo sequence is gated and rejected in release builds. Verify the release build config before submission. | Add a release-build test that asserts `bootstrapPolicyDemo` is false. |
| UX-D-30 | LOW | upgrade_screen.dart:450, 458 | Disabled "Current plan" and "Free forever" buttons look dead. This is intentional. | Render as plain text labels instead of disabled buttons. |
| UX-D-31 | LOW | search_screen.dart:102-106 and whole file | Search has no loading state. | Add a spinner or skeleton while summaries load. |
| UX-D-32 | LOW | Shared: profile, qa, renewal, search, settings, upgrade | Fixed `fontSize` values (11 to 20) are used throughout. Flutter scales these by text scaler, but they may overflow at 200%. The app sets no global text-scale clamp (app.dart has none). | Verify at 200% text scale on a device. Prefer theme text styles. |
| UX-D-33 | LOW | Shared: 26 widget files | 26 widget files use `Colors.*` or `Color(0x...)` directly, bypassing CoverWiseColors. | Migrate to tokens over time. Start with the shared widgets. |

## Pass items (verified in static inspection)

- No TODO, FIXME, "coming soon", or placeholder UI found in the 10 named screens (grep sweep).
- Dark mode: `CoverWiseTheme.dark()` is wired in app.dart:230. Settings has a System, Light, and Dark picker (settings_screen.dart:71-107). Splash and offline banners branch on brightness.
- Text scaling: no global clamp in app.dart. Renewal (807), onboarding, and policy comparison branch on the text scaler. Scaling is not blocked.
- Account deletion: in-app flow exists (profile_screen.dart:193-300) with a typed confirmation, an in-flight guard (inFlight check at 196-204), and a deletion-status poller. It is reachable from the Profile tab (main_navigation.dart:90; app_router.dart:139).
- Payments: digital goods (plans and Q&A packs) go through RevenueCat (billing_adapter.dart:241-291) and manage-subscription links go to App Store or Play (347-366). No Stripe, Razorpay, or web checkout is referenced in these screens.
- QA citations: rendered with verified and rejected states and a "Verify in your policy" affordance (qa_screen.dart:1818-1993).
- Splash health banner uses SafeArea (splash_screen.dart:209).
- Terms of Service has loading and error-with-retry states (terms_of_service_screen.dart:57-70).
- Forbidden-copy grep (guarantee, recommend, should buy, best policy, premium estimate, will be covered, score, advice) found no hits in the 10 screens. Relevance and confidence badges are covered in UX-D-12.
- Icon-only buttons in renewal (106, 340, 361), search (102-106), and terms (43) have tooltips. The gap is localization, not presence.

## Not verified (static-only limits)

- No runtime, device, simulator, screenshot, VoiceOver, TalkBack, or dark-mode visual check was performed. Evidence tier is 1 (static inspection), so none of these findings is a device proof.
- Overflow claims (UX-D-19, UX-D-32) are static risks. They must be confirmed at 200% text scale.
- Contrast claims (UX-D-17, UX-D-18) need a measured contrast ratio.
- Whether the disclaimer requirement (UX-D-01) is mandated by the legal or App Store review gate is an owner decision. This audit treats it as a BLOCKER based on the brief's forbidden-advice rule.
- The 90-day pack expiry, FIFO, and "Save up to 44%" claims (UX-D-03, UX-D-13) need backend and pricing evidence that this audit did not inspect.

## Uncommitted work and preservation

- Only this file was created: `docs/audits/app_store_readiness_2026-10-12/02d_ui_ux_screens.md`.
- No existing files were edited. No Git mutation was performed. Existing uncommitted changes in the working tree were not touched.

## Recommended next steps

1. Resolve UX-D-01 and UX-D-02 (disclaimer and share provenance) before any submission. Owner decision on wording with legal review.
2. Run a localization sweep for the four English-only screens (UX-D-04) and a grep gate in CI.
3. Fix the raw-error leak (UX-D-05) and the endpoint row (UX-D-06).
4. Verify the payments and savings-claim evidence (UX-D-03, UX-D-13) against the RevenueCat offerings and backend ledger.
5. Run a device pass at 200% text scale and in dark mode for the screens listed in UX-D-17, UX-D-18, UX-D-19, and UX-D-32.
