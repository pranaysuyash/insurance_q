# DashboardScreen — Comprehensive Audit

**Date:** 2026-07-18  
**Screen:** `mobile/lib/screens/dashboard_screen.dart` (~1170 lines)  
**Evidence Tier:** Tier 1 (static inspection of source, tests, models, providers, widgets)  
**Author:** Buffy (AI Agent)  
**Purpose:** First-principles audit of the app's main hub screen — UI quality, UX flows, copy accuracy, technical architecture, test coverage, and alignment with motto_v3.

---

## 0. Executive Summary

**Overall Rating: 7.5/10**

DashboardScreen is the most feature-rich screen in the app. It handles empty state, populated state, and error state correctly. The design system integration is strong (CoverWiseSurface, CoverWisePageHeader, CoverWiseStatusChip, HealthScoreCard). However, there are issues with information density, section ordering, copy consistency, missing interactions, and test gaps.

| Dimension | Score | Key Issue |
|---|---|---|
| **UI Design** | 8/10 | Good design system usage, but too many sections create scroll fatigue |
| **UX Flow** | 7/10 | Empty state is excellent; populated state has navigation gaps |
| **Copy & Messaging** | 6/10 | Inconsistent tone, some placeholder-quality text, missing microcopy |
| **Technical Architecture** | 7/10 | Solid Riverpod usage, but 1170-line file needs decomposition |
| **Accessibility** | 7/10 | Good Semantic labels, but some interactive elements lack hints |
| **Test Coverage** | 6/10 | Happy paths covered; missing interaction, edge case, and widget tests |
| **motto_v3 Alignment** | 7/10 | Strong on §0.14 (workflow), weak on §0.11 (claims) and §0.3 (docs) |

---

## 1. Screen Inventory — What Exists

### 1A. States

| State | Trigger | What Renders | Quality |
|---|---|---|---|
| **Loading** | `documentsAsync.when(loading:)` | Centered `CircularProgressIndicator` with Semantic label | ✅ Good |
| **Error** | `documentsAsync.when(error:)` | `AppErrorView` with "We could not load your policy overview" + retry | ✅ Good |
| **Empty** | `documents.isEmpty` | `_FirstUploadCta` — full-screen CTA with scene image, copy, and button | ✅ Excellent |
| **Populated** | `documents.isNotEmpty` | 9 sections in a `CustomScrollView` | ⚠️ Dense |

### 1B. Sections (Populated State, Top → Bottom)

| # | Section | Widget | Purpose | Lines of Code |
|---|---|---|---|---|
| 1 | Page Header | `CoverWisePageHeader` | "Your cover, at a glance" + subtitle | Reusable |
| 2 | Welcome Card | `_WelcomeCard` | Doc count, active policies, expiring count | ~40 |
| 3 | Health Score | `HealthScoreCard` | At-a-glance coverage score (0–100) with animated gauge | Reusable widget |
| 4 | Policy Summary Cards | `_PolicySummaryCards` → `_PolicyCard` | List of policies with type icon, status badge, metrics | ~120 |
| 5 | Search Shortcut | `_SearchShortcutButton` | Full-width CTA to cross-document search | ~30 |
| 6 | Documents by Type | `_DocumentSummary` → `_CoverageTypeExplorer` | Grid of policy types with count + description | ~120 |
| 7 | Quick Actions | `_QuickActions` → `_ActionButton` | 4 buttons: Upload, Ask, Compare, Terms | ~80 |
| 8 | Emergency Shortcut | `_EmergencyShortcutButton` | Full-width red CTA (only if documents exist) | ~30 |
| 9 | Family Members | `_FamilySection` | Auto-detected + manually added family members | ~80 |
| 10 | Recent Activities | `_RecentActivities` | Recent uploads, deletions, questions | ~60 |
| 11 | Health Tips | `_PreventiveTipsSection` | Contextual tips from PreventiveHealthService | ~60 |
| 12 | Insurance Terminology | `_InsuranceTerminologySection` | Quick terminology glossary | ~40 |

**Total: 12 sections in the populated state.** This is too many for a single scroll.

---

## 2. UI Audit

### 2A. Design System Compliance

| Component | Used? | Correct? | Notes |
|---|---|---|---|
| `CoverWiseSurface` | ✅ Empty state CTA | ✅ Yes | Good — branded card with border |
| `CoverWisePageHeader` | ✅ Section 1 | ✅ Yes | Correct title/subtitle hierarchy |
| `CoverWiseStatusChip` | ✅ Policy cards | ✅ Yes | ACTIVE/EXPIRED/X LEFT badges |
| `CoverWiseIconBadge` | ✅ Health score, Quick actions | ✅ Yes | Consistent icon treatment |
| `CoverWiseScene` | ✅ Empty state | ✅ Yes | Decorative illustration with fallback |
| `CoverWiseActionRow` | ❌ Not used | — | Available but not used in dashboard |
| `CoverWiseInfoPanel` | ❌ Not used | — | Could replace `_WelcomeCard` |
| `CoverWiseSelectableRow` | ❌ Not used | — | Could be used in `_CoverageTypeExplorer` |
| `CoverWiseSectionLabel` | ❌ Not used | — | Sections use raw `Text` instead |

**Issue:** Sections use raw `Text` widgets with inline styles (`fontSize: 18, fontWeight: FontWeight.bold`) instead of `CoverWiseSectionLabel` which provides the canonical section label treatment (uppercase, primary color, letter-spacing).

### 2B. Layout & Spacing

| Aspect | Assessment | Issue |
|---|---|---|
| Horizontal padding | ✅ Consistent 16px | Matches design system |
| Vertical spacing | ⚠️ Inconsistent | Some sections use `SizedBox(height: 20)`, some 16, some 12 |
| Card elevation | ⚠️ Mixed | `_PolicyCard` uses `elevation: 2`, `_ActivityItem` uses `elevation: 1`, `HealthScoreCard` uses default Card |
| Border radius | ⚠️ Mixed | `_PolicyCard` uses 12, `CoverWiseSurface` uses 22, `_ActionButton` uses 16 |
| Scroll behavior | ✅ Good | `CustomScrollView` + `RefreshIndicator` with pull-to-refresh |

**Issue:** The vertical spacing between sections is inconsistent. `_PolicySummaryCards` ends with `SizedBox(height: 20)`, but `_SearchShortcutButton` adds another `SizedBox(height: 20)` after itself. Some sections have 16px, others 20px. Standardize to 20px between major sections.

### 2C. Typography

| Element | Style | Assessment |
|---|---|---|
| Section headers | `fontSize: 18, fontWeight: FontWeight.bold` | ⚠️ Should use `CoverWiseSectionLabel` or `textTheme.titleMedium` |
| Policy type name | `fontSize: 16, fontWeight: FontWeight.bold` | ✅ OK |
| Policy insurer | `fontSize: 13, color: Colors.grey.shade600` | ⚠️ Should use `theme.colorScheme.onSurfaceVariant` |
| Metric labels | `fontSize: 11, color: Colors.grey.shade500` | ⚠️ Should use `theme.textTheme.labelSmall` |
| Metric values | `fontSize: 14, fontWeight: FontWeight.bold` | ✅ OK |
| Activity subtitle | Default `ListTile.subtitle` | ✅ OK |

**Issue:** Multiple places use hardcoded `Colors.grey.shade600` and `Colors.grey.shade500` instead of theme-derived colors. This breaks in dark mode.

### 2D. Color Usage

| Element | Color | Assessment |
|---|---|---|
| Quick Action buttons | `Colors.blue`, `Colors.purple`, `Colors.orange`, `Colors.teal` | ⚠️ Hardcoded, not from theme |
| Activity icons | `Colors.blue`, `Colors.red`, `Colors.purple` | ⚠️ Hardcoded |
| Status badges | `Colors.red`, `Colors.orange`, `Colors.green` | ⚠️ Hardcoded |
| Family avatar | `Colors.blue.withValues(alpha: 0.1)` | ⚠️ Hardcoded |

**Issue:** All colors are hardcoded rather than derived from `Theme.of(context).colorScheme`. This means:
1. Dark mode may look wrong (hardcoded colors don't adapt)
2. Brand color changes require editing every widget
3. Inconsistent with the design system's color tokens

### 2E. Accessibility

| Element | Semantic Label | Assessment |
|---|---|---|
| Loading state | ✅ "Loading policy overview" | Good |
| Empty state CTA | ✅ `Semantics(label: 'Your original policy is always available...')` | Good but verbose |
| Quick Action buttons | ✅ `Semantics(button: true, label: label)` | Good |
| Search shortcut | ✅ `Semantics(button: true, label: 'Search across all policies')` | Good |
| Emergency shortcut | ✅ `Semantics(button: true, label: 'Open emergency card')` | Good |
| Policy cards | ❌ No `Semantics(button: true)` | **Missing** — tap target not announced |
| Health score | ✅ `Semantics(label: '$score out of 100')` | Good |
| Coverage type grid | ✅ `Semantics(button: true, selected: isSelected)` | Good |
| Activity items | ❌ No `Semantics` wrapper | **Missing** — ListTile provides some, but no button semantics |
| Section headers | ❌ No `Semantics(header: true)` | **Missing** |

**Issue:** `_PolicyCard` wraps an `InkWell` but doesn't have `Semantics(button: true, label: ...)`. Screen readers won't announce it as a tappable element.

---

## 3. UX Flow Audit

### 3A. Empty State (First-Time User)

```
DashboardScreen (empty)
  → CoverWiseScene (firstPolicy illustration)
  → "Turn your first policy into clear answers"
  → Copy about what CoverWise does
  → Privacy note (verified_user_outlined icon)
  → "Choose policy file" button
  → DocumentsScreen(startWithFilePicker: true)
  → System file picker
```

**Rating: 9/10** — Excellent. Clear hierarchy, single CTA, no competing actions. The scene illustration adds personality. The privacy note builds trust at the right moment.

**Minor issues:**
- The privacy note text is small and easy to miss — consider making it a `CoverWiseInfoPanel`
- No "Skip" or "I'll do this later" option — user is forced to either upload or use back button

### 3B. Populated State — Navigation Map

| Tap Target | Destination | Rating | Issue |
|---|---|---|---|
| Policy card | `/policy-detail` (via `Navigator.pushNamed`) | ✅ | — |
| "Choose policy file" (empty) | DocumentsScreen | ✅ | — |
| "Upload Document" | DocumentsScreen(startWithFilePicker: true) | ✅ | — |
| "Ask a Question" | QaScreen | ✅ | — |
| "Compare Policies" | PolicyComparisonSheet (modal) | ✅ | — |
| "Insurance Terms" | TerminologyDialog (modal) | ✅ | — |
| "Search Across All Policies" | `/search` (via `Navigator.pushNamed`) | ✅ | — |
| "Emergency Card" | EmergencyScreen | ✅ | — |
| "Add" family member | AddFamilyMemberDialog | ✅ | — |
| "View All" terminology | TerminologyDialog | ✅ | — |
| Refresh button | Invalidates providers | ✅ | — |
| Health Score card | Toggles expand/collapse | ✅ | — |
| Coverage type grid item | Selects type (no navigation) | ⚠️ | **Issue:** Tapping a type with 0 policies does nothing — should offer to upload that type |
| "Dismiss All" health tips | Marks all tips as shown | ✅ | — |
| Individual tip dismiss | Marks single tip as shown | ✅ | — |

**Missing navigation targets:**
- No tap target on `_WelcomeCard` — should navigate to policy list or documents
- No tap target on `_DocumentSummary` section — tapping a type should filter/navigate
- No tap target on `_RecentActivities` items — should navigate to the relevant document or question
- No tap target on `_FamilySection` members — should show member's policies

### 3C. Interaction Gaps

| Interaction | Expected | Actual | Severity |
|---|---|---|---|
| Tap on `_WelcomeCard` | Navigate to documents or policy list | Nothing happens | 🟡 Medium |
| Tap on activity item | Navigate to document detail | Nothing happens | 🟡 Medium |
| Tap on family member | Show member's policies | Nothing happens | 🟡 Medium |
| Tap on coverage type with 0 policies | Offer to upload that type | Nothing happens (just selects) | 🟡 Medium |
| Pull to refresh | Refresh data | ✅ Works | — |
| Long press on policy card | Show context menu (delete, share) | Nothing happens | 🟢 Low |

### 3D. Information Architecture

**Current ordering (top → bottom):**
1. Header ("Your cover, at a glance")
2. Welcome card (stats)
3. Health score (score gauge)
4. Policy cards (list)
5. Search shortcut
6. Documents by type (grid)
7. Quick actions (buttons)
8. Emergency shortcut
9. Family members
10. Recent activities
11. Health tips
12. Insurance terminology

**Issues with ordering:**
- **Search shortcut (§5) is buried** between policy cards and type grid. It should be higher — either in the header area or as a floating action.
- **Quick actions (§7) are too low.** These are the most common actions (Upload, Ask, Compare). They should be near the top, possibly after the welcome card.
- **Emergency shortcut (§8) is below Quick Actions.** Emergency should be more prominent — either at the top or as a persistent element.
- **Recent activities (§10) is near the bottom.** This is high-value context that users check frequently. Should be higher.
- **Terminology (§12) is educational, not actionable.** Should be at the bottom or moved to a separate screen.

**Recommended reordering:**
1. Header
2. Quick Actions (most-used actions first)
3. Emergency shortcut (safety-critical, always visible)
4. Health score
5. Policy cards
6. Search shortcut
7. Welcome card (stats summary)
8. Recent activities
9. Family members
10. Documents by type
11. Health tips
12. Terminology (bottom — lowest priority)

---

## 4. Copy & Messaging Audit

### 4A. Header & Titles

| Location | Current Copy | Assessment | Suggestion |
|---|---|---|---|
| AppBar | "Home" | ✅ Clear, simple | — |
| Page header title | "Your cover, at a glance" | ✅ Good — conversational, benefit-oriented | — |
| Page header subtitle | "See what is protected, what needs attention, and what to do next." | ✅ Good — action-oriented | — |
| Welcome card | "Your policy hub" | ⚠️ Generic | "Your Insurance Dashboard" or remove — redundant with header |
| "Your Policies" | Section title | ✅ Clear | — |
| "Documents by Type" | Section title | ⚠️ Technical | "Your Coverage Types" — user thinks in coverage, not documents |
| "Quick Actions" | Section title | ✅ Standard | — |
| "Family Members & Insured" | Section title | ⚠️ Verbose | "Your People" or "Insured Members" |
| "Recent Activities" | Section title | ✅ Standard | — |
| "Health Tips" | Section title | ✅ Clear | — |
| "Insurance Terminology" | Section title | ✅ Clear | — |

### 4B. Empty State Copy

| Element | Current Copy | Assessment |
|---|---|---|
| Title | "Turn your first policy into clear answers" | ✅ Excellent — benefit-focused, action-oriented |
| Body | "Choose a PDF or policy image. CoverWise organizes the file and shows the cover, exclusions and dates for you to review." | ✅ Good — sets expectations |
| Privacy note | "Your original policy is always available. We process it securely to generate summaries." | ✅ Good — addresses trust |
| Button | "Choose policy file" | ✅ Clear CTA |

### 4C. Status & Metric Copy

| Element | Current Copy | Assessment | Issue |
|---|---|---|---|
| Status badge | "ACTIVE", "EXPIRED", "X LEFT" | ✅ Clear | "X LEFT" could be "X days left" for clarity |
| Coverage metric | "Coverage" label + "₹5.0 L" value | ✅ Clear | — |
| Premium metric | "Premium" label + "₹12.0K" value | ⚠️ Missing frequency | Should show "₹12K/yr" or "₹1K/mo" |
| Expiry metric | "Expires" label + "1/1/2027" value | ⚠️ Date format | Use "1 Jan 2027" for readability |
| Policy number | "Policy: POL-12345" | ✅ Clear | — |
| Welcome card stats | "2 documents • 2 active policies" | ✅ Clear | — |
| Expiring warning | "1 policies expiring soon" | ❌ Grammar | Should be "1 policy expiring soon" (singular) |

**Bug:** Line 217 has `'$expiringCount ${expiringCount == 1 ? "policy" : "policies"} expiring soon'` — this is correct for the expiring count, but line 213 has `'$docCount document${docCount == 1 ? "" : "s"} • $activePolicies active ${activePolicies == 1 ? "policy" : "policies"}'` — also correct. However, the `_WelcomeCard` receives these as parameters, so the grammar logic is in the parent. Verify at runtime.

### 4D. Error & Edge Case Copy

| Scenario | Current Copy | Assessment |
|---|---|---|
| Network error | "We could not load your policy overview." | ✅ Clear, non-technical |
| Empty documents | "Turn your first policy into clear answers" | ✅ Encouraging |
| No family info | "No family information detected in your policies" | ✅ Clear |
| No recent activities | "No recent activities" | ✅ Clear |
| No health tips | Section hidden (`SizedBox.shrink()`) | ✅ Correct — don't show empty section |
| No coverage type selected | "Explore the kinds of cover you can keep here..." | ⚠️ Wordy | Simplify to "Select a coverage type to see details" |

### 4E. Tone Consistency

| Aspect | Assessment |
|---|---|
| Voice | Mostly consistent — second person ("Your cover", "Your Policies") |
| Formality | Mixed — "at a glance" is casual, "Documents by Type" is formal |
| Verb tense | Mixed — "Turn your first policy" (imperative), "See what is protected" (infinitive) |
| Technical vs. plain language | Mostly plain — "documents" should be "policies" where possible |

**Recommendation:** Standardize to second-person imperative voice: "See your cover", "Ask your policy", "Track renewals".

---

## 5. Technical Architecture Audit

### 5A. File Size & Decomposition

**Current:** 1170 lines in a single file with 15+ widget classes.

**Issue:** This file violates the single-responsibility principle. It contains:
- The main `DashboardScreen` widget
- `_FirstUploadCta` (empty state)
- `_WelcomeCard` (stats)
- `_PolicySummaryCards` + `_PolicyCard` + `_StatusBadge` + `_MetricChip` (policy list)
- `_SearchShortcutButton` (search CTA)
- `_DocumentSummary` + `_CoverageTypeExplorer` (type grid)
- `_QuickActions` + `_ActionButton` (action buttons)
- `_EmergencyShortcutButton` (emergency CTA)
- `_FamilySection` (family members)
- `_RecentActivities` + `_ActivityItem` (activity feed)
- `_PreventiveTipsSection` (health tips)
- `_InsuranceTerminologySection` (terminology)

**Recommendation:** Extract into separate files:
- `widgets/dashboard/first_upload_cta.dart`
- `widgets/dashboard/welcome_card.dart`
- `widgets/dashboard/policy_summary_cards.dart`
- `widgets/dashboard/coverage_type_explorer.dart`
- `widgets/dashboard/quick_actions.dart`
- `widgets/dashboard/family_section.dart`
- `widgets/dashboard/recent_activities.dart`
- `widgets/dashboard/preventive_tips.dart`
- `widgets/dashboard/terminology_section.dart`

### 5B. State Management

| Provider | Type | Purpose | Assessment |
|---|---|---|---|
| `documentsProvider` | `AsyncValue<List<InsuranceDocument>>` | Document list from backend/Hive | ✅ Good — async handled correctly |
| `policySummariesProvider` | `PolicySummariesNotifier` | Extracted policy summaries | ✅ Good |
| `recentQuestionsProvider` | `Provider<List<String>>` | Recent Q&A questions from AppStateRepository | ✅ Good |
| `healthScoreProvider` | `Provider<InsuranceHealthScore>` | Computed health score | ✅ Good — derived from summaries + gaps |
| `mergedFamilyMembersProvider` | `AsyncValue<Map<String, PolicyHolder>>` | Family members from policies + manual | ✅ Good |
| `documentTypeCountsProvider` | `Provider.family<int, String>` | Count by type | ⚠️ Defined but not used in DashboardScreen |

**Issue:** `documentTypeCountsProvider` is defined at the top of the file but never used. The `_CoverageTypeExplorer` computes counts inline. Either use the provider or remove it.

### 5C. Navigation Pattern

| Method | Used | Assessment |
|---|---|---|
| `Navigator.push(context, MaterialPageRoute(...))` | ✅ DocumentsScreen, QaScreen, EmergencyScreen | ⚠️ Should use named routes for consistency |
| `Navigator.pushNamed(context, '/policy-detail', arguments: ...)` | ✅ PolicyDetailScreen | ✅ Good |
| `Navigator.pushNamed(context, '/search')` | ✅ SearchScreen | ✅ Good |
| `showModalBottomSheet(...)` | ✅ PolicyComparisonSheet | ✅ Good |
| `showDialog(...)` | ✅ TerminologyDialog, AddFamilyMemberDialog | ✅ Good |

**Issue:** Mixed navigation patterns — some use `push` with `MaterialPageRoute`, others use `pushNamed`. Should standardize on named routes for deep linking and analytics.

### 5D. Performance Considerations

| Aspect | Assessment | Issue |
|---|---|---|
| Provider invalidation | ✅ `ref.invalidate(documentsProvider)` on refresh | Good |
| AnimatedContainer | ✅ Used in `_CoverageTypeExplorer` | Good — smooth type selection |
| AnimatedSwitcher | ✅ Used in type description panel | Good |
| Image loading | ✅ `CoverWiseScene` uses `cacheWidth` for memory optimization | Good |
| List rendering | ⚠️ `SliverChildListDelegate` with all sections | Could use `SliverChildBuilderDelegate` for lazy rendering |
| Health score animation | ✅ `AnimationController` with `SingleTickerProviderStateMixin` | Good — respects `reduceMotion` |

**Issue:** The `SliverChildListDelegate` creates all 12 sections at once. For a screen with this many sections, `SliverChildBuilderDelegate` would defer creation of off-screen sections until they're needed.

### 5E. Error Handling

| Scenario | Handling | Assessment |
|---|---|---|
| `documentsProvider` error | `AppErrorView` with retry | ✅ Good |
| `mergedFamilyMembersProvider` error | Static error card | ⚠️ No retry option |
| `preventiveHealthService` tips empty | `SizedBox.shrink()` | ✅ Good — hides section |
| `_CoverageTypeExplorer` with 0 docs | Shows "Explore the kinds of cover..." | ✅ Acceptable |
| Policy summary with null fields | `formattedCoverageAmount` returns "Unknown" | ✅ Graceful fallback |

---

## 6. Test Coverage Audit

### 6A. Existing Tests

**File: `dashboard_screen_test.dart`** (16 tests)

| Group | Tests | Coverage |
|---|---|---|
| Populated state | 11 tests | Renders without crash, page header, welcome card, policy cards, policy numbers, active badge, expiring badge, coverage amount, premium amount, quick actions, emergency shortcut, search shortcut, documents by type |
| Empty state | 2 tests | Shows first upload CTA, hides populated sections |
| Error state | 1 test | Shows error view when documents fail to load |

**File: `dashboard_empty_state_test.dart`** (1 test)

| Test | Coverage |
|---|---|
| Empty home leads with one complete first-policy action | Verifies CTA text, button, and that populated sections are hidden |

### 6B. Missing Tests

| Category | Missing Test | Priority |
|---|---|---|
| **Interaction** | Tap policy card → navigates to PolicyDetailScreen | 🔴 High |
| **Interaction** | Tap "Upload Document" → navigates to DocumentsScreen | 🔴 High |
| **Interaction** | Tap "Ask a Question" → navigates to QaScreen | 🔴 High |
| **Interaction** | Tap "Compare Policies" → shows PolicyComparisonSheet | 🟡 Medium |
| **Interaction** | Tap "Search Across All Policies" → navigates to SearchScreen | 🟡 Medium |
| **Interaction** | Tap "Emergency Card" → navigates to EmergencyScreen | 🟡 Medium |
| **Interaction** | Tap coverage type → selects type, shows description | 🟡 Medium |
| **Interaction** | Pull-to-refresh → invalidates providers | 🟡 Medium |
| **Interaction** | Health score tap → toggles expand/collapse | 🟡 Medium |
| **Interaction** | "Add" family member → shows dialog | 🟡 Medium |
| **Interaction** | Dismiss health tip → removes tip from list | 🟡 Medium |
| **Edge case** | Single document (singular "policy") | 🟢 Low |
| **Edge case** | Many documents (scrolling performance) | 🟢 Low |
| **Edge case** | Policy with all null fields | 🟢 Low |
| **Edge case** | Policy with expiry date in the past (expired) | 🟢 Low |
| **Edge case** | Policy expiring within 30 days | ✅ Covered |
| **Widget** | `_WelcomeCard` renders correct stats | 🟡 Medium |
| **Widget** | `_CoverageTypeExplorer` type selection | 🟡 Medium |
| **Widget** | `_RecentActivities` with mixed activity types | 🟡 Medium |

### 6C. Test Quality Issues

| Issue | Severity | Fix |
|---|---|---|
| Tests don't verify navigation targets | 🟡 Medium | Use `MockNavigatorObserver` to verify push calls |
| Tests don't test interaction callbacks | 🟡 Medium | Use `tester.tap()` + verify side effects |
| Empty state test sets explicit viewport size | 🟢 Low | OK for layout testing, but fragile |
| No dark mode tests | 🟡 Medium | Add `ThemeData(brightness: Brightness.dark)` variant |
| No accessibility test | 🟡 Medium | Use `flutter_test` semantics tester |

---

## 7. motto_v3 Alignment

### 7A. Clause-by-Clause Assessment

| Clause | Alignment | Evidence |
|---|---|---|
| **§0.1 Boldness & Long-Term Build** | ⚠️ Partial | HealthScoreCard and _CoverageTypeExplorer are bold features. But the 1170-line file and missing navigation interactions suggest incremental rather than holistic design. |
| **§0.3 Documentation** | ❌ Gap | No dartdoc on `DashboardScreen` class or any private widgets. No inline comments explaining section ordering rationale. |
| **§0.6 Risk-Based Verification** | ✅ Good | Empty state, error state, and loading state all handled. Test coverage for happy paths. |
| **§0.8 Data Layer Rule** | ✅ Good | `quickTerminology` is a data asset in `insurance_terminology.dart`. `PreventiveHealthService` generates tips from data. |
| **§0.10 Observability** | ⚠️ Gap | No analytics events tracked on dashboard interactions (policy tap, action tap, search tap). §12 of UX audit defined events but they're not implemented here. |
| **§0.11 Customer-Facing Claims** | ⚠️ Gap | "Your cover, at a glance" implies comprehensive visibility. But if extraction fails or fields are null, the user sees "Unknown" everywhere. The claim should be conditional. |
| **§0.14 Operator Workflow** | ✅ Good | Clear workflow: empty → upload → populated → act. Quick actions are prominent. Emergency shortcut is one tap. |
| **§11 Engineering Standards** | ⚠️ Gap | File needs decomposition. Hardcoded colors need theme migration. Navigation pattern needs standardization. |
| **§12 Product & Domain Alignment** | ✅ Good | Health score, coverage types, family members, and preventive tips all reinforce the "insurance info broker" product identity. |

### 7B. Specific motto_v3 Violations

1. **§0.3 — No documentation on private widgets.** Each widget class should have a 1-2 line dartdoc explaining its purpose.

2. **§0.10 — No analytics events.** The dashboard is the most-visited screen but has zero analytics instrumentation. Key events to track:
   - `dashboard_section_viewed` (which sections are visible)
   - `dashboard_action_tapped` (which quick action)
   - `dashboard_policy_tapped` (which policy card)
   - `dashboard_empty_cta_tapped` (first upload)

3. **§0.11 — "Your cover, at a glance" is a claim.** If extraction fails, the user sees nothing useful. The header should adapt: "Your cover, at a glance" when data is good, "Some fields need review" when extraction is partial.

4. **§11 — Hardcoded colors violate design system.** `Colors.grey.shade600`, `Colors.blue`, `Colors.red`, etc. should all come from the theme.

---

## 8. Priority Fix Stack

| Priority | Issue | Effort | Impact | motto_v3 |
|---|---|---|---|---|
| **P0** | Add missing navigation interactions (policy card tap, activity item tap, family member tap) | Small | 🔴 Core UX gap | §0.14 |
| **P0** | Fix hardcoded colors → theme-derived colors for dark mode support | Small | 🔴 Dark mode broken | §11 |
| **P1** | Reorder sections (Quick Actions + Emergency near top, Terminology at bottom) | Small | 🟡 Information architecture | §0.14 |
| **P1** | Replace raw section headers with `CoverWiseSectionLabel` | Small | 🟡 Design system consistency | §11 |
| **P1** | Add analytics events for dashboard interactions | Small | 🟡 Observability gap | §0.10 |
| **P1** | Add dartdoc comments to all widget classes | Small | 🟡 Documentation gap | §0.3 |
| **P2** | Extract widgets into separate files (reduce from 1170 to ~200 lines) | Medium | 🟡 Maintainability | §11 |
| **P2** | Add missing interaction tests (tap → navigation verification) | Medium | 🟡 Test coverage | §0.6 |
| **P2** | Fix grammar: "1 policies" → "1 policy" in edge cases | Small | 🟡 Copy quality | §0.11 |
| **P2** | Standardize navigation pattern (all named routes) | Medium | 🟡 Architecture consistency | §11 |
| **P3** | Add dark mode test variant | Small | 🟢 Future-proofing | §0.6 |
| **P3** | Add accessibility semantics to policy cards | Small | 🟢 a11y | §0.14 |
| **P3** | Use `SliverChildBuilderDelegate` for lazy section rendering | Small | 🟢 Performance | §11 |

---

## 9. Decision Record

### Decision: Section Ordering

**Context:** The dashboard has 12 sections. Users scroll past low-priority content (terminology, tips) to reach high-priority actions (upload, ask, search).

**Options:**
1. Keep current ordering (information flow: stats → data → actions → education)
2. Actions-first ordering (actions → data → stats → education)
3. Contextual ordering (changes based on user behavior)

**Chosen:** Option 2 — Actions-first.

**Rationale:** The dashboard is an action hub, not a report. Users come to do something (upload, ask, compare), not to read stats. Put the most common actions at the top.

**Tradeoffs:**
- Pro: Reduces time-to-action for returning users
- Pro: Emergency shortcut becomes more prominent
- Con: First-time users see actions before understanding what the app does (but empty state handles this)
- Con: Stats summary moves down (but health score card is a better summary anyway)

### Decision: Analytics Events

**Context:** §0.10 requires observability. The dashboard has zero analytics instrumentation.

**Options:**
1. Add events inline in each widget
2. Create a `DashboardAnalytics` wrapper that tracks section visibility and interactions
3. Use a Riverpod provider that auto-tracks on state changes

**Chosen:** Option 2 — wrapper approach.

**Rationale:** Centralizes analytics logic, easier to add/remove events, doesn't pollute widget code.

---

*Last updated: 2026-07-18 — Initial comprehensive audit.*
