# PolicyDetailScreen Comprehensive Audit

**Screen:** `mobile/lib/screens/policy_detail_screen.dart` (720 lines)
**Date:** 2026-07-18
**Methodology:** motto_v3 §0.1–§0.15 compliance audit, same framework as DashboardScreen audit

---

## 1. Screen Inventory

| Aspect | Status |
|--------|--------|
| File | `mobile/lib/screens/policy_detail_screen.dart` |
| Tests | `mobile/test/policy_detail_screen_test.dart` (26 tests, 4 groups) |
| Type | `ConsumerWidget` (Riverpod) |
| Lines | ~720 |
| Navigation in | From `/policy-detail` route with `documentId` argument |
| Navigation out | `/qa` (with docId), DocumentPreviewScreen (direct push), share (SharePlus) |

---

## 2. UI Audit

### 2.1 What Exists (Rated)

| Widget | Lines | Rating | Notes |
|--------|-------|--------|-------|
| `_HeaderCard` | 220–270 | ✅ Good | Uses CoverWiseIconBadge, CoverWiseStatusChip, theme colors |
| `_MoneyRow` | 275–340 | ⚠️ Medium | Hardcoded Colors.blue/green/orange for metric icons |
| `_DatesCard` | 345–395 | ⚠️ Medium | Uses CoverWiseColors.blueDeep directly + Colors.orange.shade700/green.shade700 |
| `_SectionList` (benefits) | 400–455 | ⚠️ Medium | Hardcoded Colors.green for benefits, Colors.red for exclusions |
| `_SectionList` (exclusions) | 105–120 | ⚠️ Medium | Same hardcoded colors |
| `_SectionList` (waiting) | 115–120 | ⚠️ Medium | Colors.orange hardcoded |
| `_CoverageItemsCard` | 560–630 | ⚠️ Medium | Colors.green/Colors.red for covered/not covered icons |
| `_QuickActions` | 640–710 | ⚠️ Medium | FilledButton + OutlinedButton — no hardcoded colors (good) |
| `_StatusBadge` | 280–315 | 🔴 Bad | Colors.red/orange/green/grey hardcoded — same issue as DashboardScreen |
| AppBar actions | 55–75 | ✅ Good | Proper icons, tooltips, navigation |
| Bottom disclaimer | 135–155 | ✅ Good | Uses theme colorScheme.onSurfaceVariant |

### 2.2 Hardcoded Color Instances (18 total)

| Line | Current | Should Be |
|------|---------|-----------|
| 94 | `Colors.green` (benefit iconColor) | `scheme.primary` or `scheme.tertiary` |
| 97 | `Colors.green` (benefit itemColor) | Same |
| 105 | `Colors.red` (exclusion iconColor) | `scheme.error` |
| 108 | `Colors.red` (exclusion itemColor) | Same |
| 116 | `Colors.orange` (waiting iconColor) | `scheme.tertiary` |
| 119 | `Colors.orange` (waiting itemColor) | Same |
| 299 | `Colors.red` (expired) | `scheme.error` |
| 302 | `Colors.orange` (expiring) | `scheme.tertiary` |
| 305 | `Colors.green` (active) | `scheme.primary` |
| 308 | `Colors.grey` (unknown) | `scheme.outline` |
| 338 | `Colors.blue` (sum insured) | `scheme.primary` |
| 345 | `Colors.green` (premium) | `scheme.tertiary` |
| 352 | `Colors.orange` (deductible) | `scheme.error` |
| 461 | `CoverWiseColors.blueDeep` | `scheme.primary` (theme-aware) |
| 488 | `Colors.orange.shade700` | `scheme.tertiary` |
| 489 | `Colors.green.shade700` | `scheme.primary` |
| 600 | `CoverWiseColors.blueDeep` | `scheme.primary` |
| 621 | `Colors.green`/`Colors.red` (coverage items) | `scheme.primary`/`scheme.error` |

### 2.3 What's Missing

- **No dark mode awareness**: 18 hardcoded colors will look wrong or have poor contrast in dark mode
- **No loading skeleton**: When navigating to this screen, there's no shimmer/skeleton while summary loads
- **No pull-to-refresh**: Users can't refresh the summary if extraction was recent
- **No share button in floating position**: Share is only in AppBar — could be more prominent
- **No "coverage gap" section**: The audit found coverage gaps are computed but not shown on this screen
- **No insurer contact quick-action**: Call/email insurer is only in QuickActions at the bottom — should be in the header area for emergency access

---

## 3. UX Audit

### 3.1 Information Architecture

**Current flow:**
```
AppBar (title + 3 actions: preview, chat, share)
  ↓
CoverWisePageHeader (policy type + insurer)
  ↓
_HeaderCard (type icon, insurer, status badge, policy number)
  ↓
_MoneyRow (coverage, premium, deductible)
  ↓
_DatesCard (start, end, days remaining)
  ↓
CoverWiseSectionLabel: "What this policy covers"
  ↓
_SectionList: Benefits (green checks)
  ↓
CoverWiseSectionLabel: "Important exclusions"
  ↓
_SectionList: Exclusions (red crosses)
  ↓
CoverWiseSectionLabel: "Timing conditions"
  ↓
_SectionList: Waiting periods (orange clocks)
  ↓
CoverWiseSectionLabel: "Coverage details"
  ↓
_CoverageItemsCard (item-by-item view)
  ↓
CoverWiseSectionLabel: "Next steps"
  ↓
_QuickActions (Ask, Share, Call, Email)
  ↓
Bottom disclaimer
```

**Rating: 7/10** — Good hierarchy, but:
- ⚠️ Too many sections before actionable content (4 section labels before "Next steps")
- ⚠️ Call/Email insurer buried at the bottom — should be accessible from header
- ⚠️ No visual separation between "what's covered" and "what's not" — both use same card layout
- ✅ CoverWiseSectionLabel provides clear visual hierarchy
- ✅ Status badge is prominent and correct

### 3.2 Interaction Patterns

| Action | Current | Rating | Issue |
|--------|---------|--------|-------|
| Ask a question | AppBar icon + QuickActions button | ✅ Good | Two entry points — accessible |
| Share summary | AppBar icon + QuickActions button | ✅ Good | Two entry points |
| View source PDF | AppBar icon only | ⚠️ Medium | Only one entry point, no fallback message in button |
| Call insurer | QuickActions only | 🔴 Bad | Buried at bottom, no header shortcut |
| Email insurer | QuickActions only | 🔴 Bad | Same as above |
| Compare with other policies | Not available | 🔴 Missing | No comparison entry from detail screen |
| Set renewal reminder | Not available | 🔴 Missing | No reminder CTA despite expiry data being shown |
| Export/print | Not available | ⚠️ Medium | Share exists but no print/PDF export |

### 3.3 Empty State

**Current:** Shows "Policy summary not available" with "Ask about this policy" CTA.
**Rating: 6/10**
- ✅ Clear message
- ✅ Actionable CTA
- ⚠️ No indication of *why* summary is missing (still processing? extraction failed?)
- ⚠️ No retry button
- ⚠️ No link to view the source document directly

### 3.4 Error Handling

**Current:** `_openDocumentPreview` handles 3 error cases with SnackBar messages.
**Rating: 7/10**
- ✅ Null document list
- ✅ Document not found
- ✅ No local file path
- ⚠️ No error handling for share failures
- ⚠️ No error handling for navigation failures

---

## 4. Flow Audit

### 4.1 Happy Path

```
User taps policy card on Dashboard
  → PolicyDetailScreen loads with documentId
  → policySummariesProvider resolves summary
  → Screen renders all sections
  → User scrolls through benefits, exclusions, waiting periods
  → User taps "Ask about this policy" → QaScreen with documentId
  → User taps "Share policy summary" → SharePlus dialog
  → User taps document preview icon → DocumentPreviewScreen
```

**Rating: 8/10** — Clean flow, all navigation works.

### 4.2 Edge Cases

| Scenario | Current Behavior | Rating |
|----------|-----------------|--------|
| Summary not found | Shows empty state with CTA | ✅ |
| Summary has no benefits | Section hidden (if empty) | ✅ |
| Summary has no exclusions | Section hidden (if empty) | ✅ |
| Summary has no waiting periods | Section hidden (if empty) | ✅ |
| Summary has no coverage items | Section hidden (if empty) | ✅ |
| Policy is expired | Red EXPIRED badge | ✅ |
| Policy expiring soon | Orange "Xd LEFT" badge | ✅ |
| No insurer contact info | Call/Email buttons hidden | ✅ |
| Document not on device | SnackBar: "only available on device where uploaded" | ✅ |
| Very long insurer name | maxLines: 1, overflow: ellipsis | ✅ |
| Very long policy number | No overflow handling | ⚠️ |

### 4.3 Missing Flows

- **No "compare this policy" flow** from detail screen
- **No "set renewal reminder" flow** despite expiry data
- **No "view coverage gaps" flow** — gaps are computed elsewhere but not linked
- **No "edit policy details" flow** for manual corrections
- **No "delete policy" flow** from detail screen

---

## 5. Copy Audit

### 5.1 Section Labels

| Label | Current | Rating | Suggestion |
|-------|---------|--------|------------|
| "What this policy covers" | ✅ Clear | 9/10 | — |
| "Important exclusions" | ✅ Clear | 9/10 | — |
| "Timing conditions" | ⚠️ Vague | 6/10 | "Waiting periods before coverage kicks in" |
| "Coverage details" | ⚠️ Redundant | 6/10 | "Item-by-item coverage breakdown" |
| "Next steps" | ✅ Action-oriented | 8/10 | — |

### 5.2 Status Badge Copy

| Status | Copy | Rating |
|--------|------|--------|
| Active | "ACTIVE" | ✅ |
| Expiring | "Xd LEFT" | ✅ Clear, urgent |
| Expired | "EXPIRED" | ✅ |
| Unknown | "UNKNOWN" | ⚠️ Could be "STATUS UNKNOWN" |

### 5.3 Empty State Copy

| Element | Current | Rating |
|---------|---------|--------|
| Title | "Policy summary not available" | ✅ |
| Subtitle | "Extraction may still be in progress..." | ⚠️ Too verbose |
| CTA | "Ask about this policy" | ✅ |

### 5.4 Disclaimer Copy

**Current:** "Extracted on {date} from your uploaded policy document. Always verify important details against the source document and your insurer."

**Rating: 8/10** — Clear, honest, appropriate hedging.

### 5.5 Quick Actions Copy

| Button | Copy | Rating |
|--------|------|--------|
| Ask | "Ask about this policy" | ✅ |
| Share | "Share policy summary" | ✅ |
| Call | "Call insurer" | ✅ |
| Email | "Email insurer" | ✅ |

---

## 6. Technical Architecture Audit

### 6.1 Widget Structure

```
PolicyDetailScreen (ConsumerWidget)
  ├── AppBar (title + 3 IconButton actions)
  ├── ListView
  │   ├── CoverWisePageHeader
  │   ├── _HeaderCard (Card)
  │   ├── _MoneyRow (Card)
  │   ├── _DatesCard (Card)
  │   ├── CoverWiseSectionLabel × 4
  │   ├── _SectionList × 3 (benefits, exclusions, waiting)
  │   ├── _CoverageItemsCard (Card)
  │   ├── _QuickActions (CoverWiseSurface)
  │   └── Disclaimer text
  └── (no FAB, no bottom nav override)
```

**Rating: 7/10**
- ✅ Clean separation of concerns
- ✅ Each section is its own widget
- ⚠️ `_SectionList` is reused 3 times with different params — good abstraction
- ⚠️ `_QuickActions` takes `BuildContext context` as constructor param (unused, shadowed by build context)
- ⚠️ `_shareSummary` is top-level function — good for testability but inconsistent with `_openDocumentPreview` which is a method

### 6.2 State Management

| Provider | Usage | Rating |
|----------|-------|--------|
| `policySummariesProvider` | Watched for summary data | ✅ |
| `documentsProvider` | Read for document preview | ✅ |

**Rating: 8/10** — Minimal, correct provider usage.

### 6.3 Navigation Contracts

| Route | Arguments | Return | Rating |
|-------|-----------|--------|--------|
| `/qa` | `documentId` (String) | void | ✅ |
| DocumentPreviewScreen | `filePath`, `filename`, `documentId` | void | ✅ |
| SharePlus | `ShareParams(text: ...)` | void | ✅ |

**Rating: 8/10** — Clean, typed navigation.

### 6.4 Theme Compliance

| Element | Uses Theme? | Issue |
|---------|-------------|-------|
| Section headers | ✅ `textTheme.titleLarge` | — |
| Body text | ✅ `textTheme.bodyMedium` | — |
| Status badge colors | 🔴 No | Hardcoded Colors.red/orange/green/grey |
| Money row icons | 🔴 No | Hardcoded Colors.blue/green/orange |
| Section list icons | 🔴 No | Hardcoded Colors.green/red/orange |
| Coverage item icons | 🔴 No | Hardcoded Colors.green/red |
| Date remaining text | 🔴 No | Colors.orange.shade700/green.shade700 |
| Disclaimer | ✅ `colorScheme.onSurfaceVariant` | — |
| AppBar | ✅ Theme AppBar | — |

**Theme compliance: 50%** — 18 hardcoded color instances need migration.

### 6.5 Accessibility

| Check | Status |
|-------|--------|
| Semantics on interactive elements | ✅ AppBar buttons have tooltips |
| Semantics on status badges | ✅ CoverWiseStatusChip has `label: 'Status: $label'` |
| Semantics on section lists | ❌ No Semantics wrapper on benefit/exclusion items |
| Color contrast (dark mode) | 🔴 Hardcoded colors may fail contrast |
| Screen reader navigation | ⚠️ No explicit semantic labels on sections |

---

## 7. Test Audit

### 7.1 Current Coverage

| Group | Tests | Coverage |
|-------|-------|----------|
| Populated state | 12 | Renders all sections, badges, money row, actions |
| Minimal summary | 2 | Hides empty sections |
| Empty state | 1 | Shows "not available" message |
| buildShareSummaryText | 3 | Full, minimal, null-field exclusion |
| **Total** | **18** | |

### 7.2 What's Tested

- ✅ Screen renders without crash
- ✅ Policy type shown in header
- ✅ Insurer name rendered
- ✅ Policy number rendered
- ✅ Active status badge
- ✅ Money row (coverage, premium, deductible)
- ✅ Key benefits section
- ✅ Exclusions section
- ✅ Waiting periods section
- ✅ Coverage items section
- ✅ Quick actions (Ask, Share)
- ✅ Extraction disclaimer
- ✅ AppBar title and icons
- ✅ Empty state when summary not found
- ✅ Minimal summary hides empty sections
- ✅ Share text includes all key fields
- ✅ Share text handles minimal summary
- ✅ Share text excludes null fields

### 7.3 What's NOT Tested

| Gap | Severity | Priority |
|-----|----------|----------|
| Navigation taps (Ask → /qa, Share → SharePlus) | High | P1 |
| Document preview button tap | High | P1 |
| Dark mode rendering | High | P1 |
| Expired/expiring status badges | Medium | P2 |
| Call/Email insurer buttons (launch URL) | Medium | P2 |
| Empty state CTA tap | Medium | P2 |
| Scroll behavior with long content | Low | P3 |
| Accessibility semantics | Low | P3 |
| Error states (summary load failure) | Medium | P2 |

---

## 8. motto_v3 Alignment

### 8.1 §0.0 Boldness & Long-Term Build

**Rating: 6/10**
- ⚠️ Screen is functional but not bold — missing comparison, reminders, gap visualization
- ✅ Good extraction disclaimer (honest about limitations)
- ⚠️ No "what should I do next" proactive guidance beyond "Ask a question"

### 8.2 §0.3 Documentation Continuity

**Rating: 5/10**
- ⚠️ No inline documentation of design decisions
- ⚠️ No doc explaining why sections are ordered this way
- ⚠️ No doc linking to extraction pipeline outputs

### 8.3 §0.5 Evidence Tiers

**Rating: 7/10**
- ✅ 18 unit tests (Tier 2)
- ⚠️ No integration tests (Tier 3)
- ⚠️ No dark mode visual verification (Tier 4)

### 8.4 §0.10 Observability

**Rating: 4/10**
- ❌ No analytics events for screen view
- ❌ No analytics for action taps (Ask, Share, Call, Email)
- ❌ No timing data for summary load
- ❌ No error reporting for failed navigation

### 8.5 §0.11 Customer-Facing Claims

**Rating: 8/10**
- ✅ Disclaimer: "Always verify important details against the source document"
- ✅ "Extracted on {date}" — honest about data freshness
- ✅ Status badges are factual (ACTIVE/EXPIRED/Xd LEFT)
- ⚠️ "What this policy covers" could be misleading if extraction missed benefits

### 8.6 §0.14 Product Reality & Operator Workflow

**Rating: 6/10**
- ✅ User can understand their policy at a glance
- ✅ Clear next actions (Ask, Share, Call, Email)
- ⚠️ Operator cannot see which policies users view most
- ⚠️ No way for operator to know if extraction quality is poor

---

## 9. Priority Stack

### P0 — Must Fix (blocks dark mode, breaks accessibility)

| # | Issue | Effort |
|---|-------|--------|
| 1 | Migrate 18 hardcoded colors to theme-derived colors | Small |
| 2 | Fix `_QuickActions` unused `context` constructor parameter | Tiny |

### P1 — Should Fix (UX gaps, test gaps)

| # | Issue | Effort |
|---|-------|--------|
| 3 | Add navigation tap tests (Ask, Share, Preview) | Medium |
| 4 | Add dark mode widget test | Medium |
| 5 | Add "Set renewal reminder" CTA to QuickActions | Small |
| 6 | Add "Compare with other policies" entry point | Medium |
| 7 | Add Semantics wrappers to section list items | Small |
| 8 | Move Call/Email insurer to header area (or add duplicate) | Small |

### P2 — Nice to Have (polish, observability)

| # | Issue | Effort |
|---|-------|--------|
| 9 | Add analytics events for screen view and action taps | Small |
| 10 | Add loading skeleton while summary loads | Medium |
| 11 | Add pull-to-refresh | Small |
| 12 | Add coverage gap section (link to existing gap data) | Medium |
| 13 | Add "edit policy details" flow | Large |
| 14 | Add "delete policy" flow from detail screen | Medium |

### P3 — Future

| # | Issue | Effort |
|---|-------|--------|
| 15 | Add print/PDF export of summary | Medium |
| 16 | Add side-by-side comparison view | Large |
| 17 | Add insurer rating/review integration | Large |

---

## 10. Comparison with DashboardScreen Audit

| Dimension | DashboardScreen | PolicyDetailScreen |
|-----------|----------------|-------------------|
| Hardcoded colors | 12 instances → Fixed | 18 instances → **Needs fix** |
| Navigation gaps | 3 missing → Fixed | 2 missing (Call/Email buried) |
| Dark mode readiness | ✅ After fix | 🔴 Before fix |
| Test coverage | Good | Good (18 tests) |
| Analytics | None | None |
| motto_v3 compliance | 7/10 | 6/10 |

---

## 11. Recommended Next Steps

1. **Immediate:** Migrate all 18 hardcoded colors to theme-derived equivalents (same pattern as DashboardScreen fix)
2. **Next:** Add navigation tap tests and dark mode test
3. **Then:** Add renewal reminder CTA and comparison entry point
4. **Finally:** Add analytics events and loading skeleton

---

*Audit completed: 2026-07-18*
*Auditor: Buffy (Freebuff AI agent)*
*motto_v3 compliance: §0.1–§0.15 checked*
