# Upgrade & Paywall Screen: Wedge Audit

> **Status:** Draft (analysis, not implemented)
> **Date:** 2026-07-29
> **Source session:** Founder request: "Audit the current upgrade_screen.dart and paywall_screen.dart against the new tier definitions — do Plus/Family feature descriptions match the wedge framework?"
> **Evidence tier:** Codebase audit (Tier 1) — verified against source files
> **Related:** [Product Wedge](../architecture/FIRST_PRINCIPLES_WEDGE.md), [Free vs Paid Boundary](../architecture/FREE_VS_PAID_BOUNDARY.md), [Onboarding Redesign](onboarding_first_principles_redesign.md)

---

## 1. What Prompted This Audit

After the G1 export gate was implemented (gating share behind `allowExport` entitlement), the founder asked: *"Audit the current upgrade_screen.dart and paywall_screen.dart against the new tier definitions — do Plus/Family feature descriptions match the wedge framework?"*

## 2. Audited Files

- `mobile/lib/screens/upgrade_screen.dart` — Renders tier cards and comparison table
- `mobile/lib/screens/paywall_screen.dart` — Thin wrapper that delegates to UpgradeScreen

## 3. Current State Summary

**UpgradeScreen** renders dynamically from `PlanLimits`:
- **Feature chips** (shown per tier card): policies, Q&A/mo, Compare, Family view, Cloud sync, Emergency, Annual review, Advanced search
- **Comparison table** (all tiers): same 8 features as rows × 3 tier columns
- **Tier taglines**: Free="Understand one policy" / Plus="Household policy companion" / Family="Ongoing household management"
- **FAQ section**: 3 questions (Can I switch plans? What about my Q&A packs? How do I cancel?)

**PaywallScreen** is a thin wrapper that delegates to UpgradeScreen with an entry message. Two limit types: `documents` and `queries`. No wedge-specific concerns.

## 4. Findings

### Finding #1: Missing `allowExport` from comparison table and chips (🔴 P0)

**What:** The G1 fix added `allowExport` to `PlanLimits` (free=false, plus=true, family=true), but neither the feature comparison table nor the tier card chips surface it. A user considering Plus/Family doesn't know that export is a gated benefit.

**Files affected:**
- `upgrade_screen.dart` — `_FeatureComparisonTable` features list (~line 380): no `allowExport` row
- `upgrade_screen.dart` — `_PlanCard` feature chips (~line 230): no export chip for Plus/Family cards

**Fix:** Add `'Export'` row to the comparison table and an `if (limits.allowExport)` chip to the tier cards.

**Wedge impact:** Export is a paid convenience feature (per `FREE_VS_PAID_BOUNDARY.md` §2.14). Users choosing a plan need to know it exists. Missing it from the upgrade screen means users who need export may choose Free, hit the gate, churn, and never come back.

### Finding #2: "Emergency" chip conflates free facts with paid support (🟡 P2)

**What:** The `_PlanCard` shows `_FeatureChip(label: 'Emergency')` only for Family tier. But per the wedge, essential emergency *facts* (policy-stated claim numbers, helplines) are **comprehension** — must be free for all users. A paid *dedicated support channel* is a separate paid candidate — must not be conflated with emergency facts.

**Current chip label:** "Emergency" — implies the feature requires Family tier. This is misleading. The user's emergency helpline data should be visible regardless of plan.

**Fix:** Split into two separate concepts in the UI:
1. **"Emergency facts"** — free baseline (never mentioned in upgrade screen because it's always available)
2. **"Priority support"** — paid candidate (what the chip should say for Family)

### Finding #3: "Family view" chip doesn't communicate the free/paid split (🟡 P2)

**What:** The wedge says per-policy family coverage (e.g., "dependent coverage includes spouse up to ₹5L") is **free** comprehension, visible in the policy detail screen for all users. The cross-policy family matrix is **depth** and paid.

The chip just says "Family view" — the user can't tell what they're getting. This could cause frustration when a free user sees family data in their policy detail but doesn't understand why the "Family view" feature is gated.

**Fix:** Add descriptive detail: "Family matrix: all policies per member" for the paid feature. Clarify that per-policy family info is already available for free.

### Finding #4: Feature chips use generic labels, not outcome-focused ones (🟡 P3)

**Current chips:** "Compare", "Family view", "Cloud sync", "Emergency", "Annual review", "Advanced search"

**Wedge says:** Labels should describe the outcome, not the interface.

**Proposed labels:**

| Current | Outcome-focused | Why |
|---------|----------------|-----|
| Compare | "Side-by-side policy comparison" | Users understand what "compare" means |
| Family view | "All policies per family member" | Describes the outcome (seeing family coverage across all policies) |
| Cloud sync | "Multi-device backup & sync" | Describes what it does for the user |
| Emergency | "Priority support" (paid) / "Emergency facts" (free) | Separates free comprehension from paid support |
| Annual review | "Coverage change report" | Describes the output |
| Advanced search | "Search across all policies" | Describes what it does |

### Finding #5: Comparison table doesn't distinguish basic vs advanced comparison (🟡 P3)

**What:** The comparison table shows a single "Compare" row. Per `FREE_VS_PAID_BOUNDARY.md` §2.12 and ADR-2026-07-29-02, basic neutral owned-policy comparison (side-by-side cited facts) is free comprehension. Advanced comparison (cross-policy synthesis, matrices) is depth (paid).

**Fix:** Either split into "Basic comparison" (free) and "Advanced comparison" (paid) rows, or keep free comparison off the upgrade screen entirely and only list advanced comparison as a paid feature.

### Finding #6: Tier taglines could be sharper about the comprehension promise (⚪ P4)

**Current taglines:**
- Free: "Understand one policy"
- Plus: "Household policy companion"
- Family: "Ongoing household management"

**Proposed (outcome-focused):**
- Free: "Understand your first policy"
- Plus: "Manage all your policies"
- Family: "Coverage for the whole family"

## 5. Summary of Action Items

| # | Severity | Finding | Fix |
|---|----------|---------|-----|
| 1 | 🔴 P0 | `allowExport` missing from comparison table and chips | Add export row + chip |
| 2 | 🟡 P2 | "Emergency" chip mislabels free facts as paid | Rename → "Priority support" |
| 3 | 🟡 P2 | "Family view" chip doesn't explain free/paid split | Add descriptive detail |
| 4 | 🟡 P3 | Feature labels are interface-focused, not outcome-focused | Rewrite chip labels |
| 5 | 🟡 P3 | Comparison table doesn't distinguish basic vs advanced | Split or clarify comparison |
| 6 | ⚪ P4 | Tier taglines could be sharper | Minor copy improvements |

## 6. Relation to Other Documents

This audit should be consulted when:
- The upgrade screen is revisited for redesign
- New paid features are added to the comparison table
- The free vs paid boundary is updated (see `FREE_VS_PAID_BOUNDARY.md`)

## 7. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial audit — 6 findings from wedge analysis of upgrade screen | Founder directive: audit upgrade/paywall against wedge framework. Documented per §0.3.1. |
