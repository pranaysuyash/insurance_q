# Dashboard Redesign: First-Principles Analysis

> **Status:** Draft (analysis, not implemented)
> **Date:** 2026-07-29
> **Source session:** Founder request: "Apply the first-principles framework to the home/dashboard screen — what should the user see first?"
> **Evidence tier:** Decision-grade product reasoning (Tier 0)
> **Related:** [First-Principles Derivation](../architecture/FIRST_PRINCIPLES_DERIVATION_FROM_MOTTO.md), [Product Wedge](../architecture/FIRST_PRINCIPLES_WEDGE.md), [Onboarding Redesign](onboarding_first_principles_redesign.md)

---

## 1. What Prompted This Analysis

After the first-principles wedge was established, the founder asked: *"Apply the first-principles framework to the home/dashboard screen — what should the user see first?"*

The wedge says: *"Coverage summary is closer to the wedge than Q&A."* And: *"Proactive beats reactive."* The dashboard is the first screen the user sees — it must reflect this hierarchy.

## 2. Current Dashboard Analysis

### What Exists Now

The current `DashboardScreen` shows:
1. **Quick action cards** — Upload, Ask a question, Emergency
2. **Policy cards** — List of uploaded policies with status badges
3. **Renewal reminders** — Expiry dates and countdowns
4. **Family quick summary** — Number of members covered
5. **Coverage summary quick action** — A card that navigates to CoverageDetailsSummaryScreen

### What the Wedge Says

The wedge says comprehension (coverage info) should be primary, and actions (upload, ask) should be secondary. The current dashboard is action-first:

> "The dashboard already exists and shows expiry dates and policy status, which is correct direction — but it's still secondary to the Q&A tab in how the app is organized (FAB is 'Ask', the first tab is Home with minimal content, Q&A is a navigation away)."

### The Tension

The FAB is "Ask" — implying Q&A is the primary action. The "Home" tab shows quick actions (upload, emergency) and policy cards — but the most actionable comprehension content (coverage summary, gap alerts) is buried a tap deeper.

## 3. First-Principles Redesign

### The Guiding Principle

> **Info before action. Coverage before interface. The user sees what they have before what they can do.**

### Proposed Layout (Top to Bottom)

```
┌─────────────────────────────────┐
│  [Coverage At A Glance]         │
│                                 │
│  ┌─ Active Policies ──────────┐ │
│  │  • Health: ICICI Lombard   │ │
│  │    Exp: 2027-03-15 (234d)  │ │
│  │    Sum insured: ₹5,00,000  │ │
│  │    └── [View details]      │ │
│  │                             │ │
│  │  • Motor: HDFC Ergo        │ │
│  │    Exp: 2026-12-31 (155d)  │ │
│  │    IDV: ₹6,50,000          │ │
│  │    └── [View details]      │ │
│  └─────────────────────────────┘ │
│                                 │
│  ┌─ Quick Actions ────────────┐ │
│  │  [+ Add Policy]  [Emergency]│ │
│  └─────────────────────────────┘ │
│                                 │
│  ┌─ What's Important ─────────┐ │
│  │  ⚠ Motor expiring in 45d   │ │
│  │  ⚡ 2 coverage facts found  │ │
│  └─────────────────────────────┘ │
│                                 │
│  ┌─ Family ───────────────────┐ │
│  │  3 members covered across  │ │
│  │  2 policies                │ │
│  └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### Key Changes from Current

| Aspect | Current | Proposed | Wedge Alignment |
|--------|---------|----------|-----------------|
| **Primary content** | Quick actions (upload, ask) | **Policy coverage cards** with inline values | ✅ Info before action |
| **FAB** | "Ask" (Q&A) | **"View coverage"** or remove FAB (replace with inline nav) | ✅ Coverage before interface |
| **Policy card** | Name, status badge, expiry date | Name, status, **sum insured, IDV, premium** inline | ✅ Comprehension at glance |
| **What-if calculator** | Present in nav | **Cut** | ✅ Outside wedge |
| **Renewal info** | Calendar tab | Inline on dashboard as "What's Important" section | ✅ Proactive, contextual |
| **Coverage facts** | Not shown | Shown inline as expandable section | ✅ Proactive beats reactive |
| **Quick actions** | Primary (top of screen) | Secondary (below policy cards) | ✅ Info before action |

## 4. Implementation Impact

| Change | Effort | Notes |
|--------|--------|-------|
| Reorder dashboard sections (info first, actions second) | 1-2 hours | Layout reorder in DashboardScreen |
| Show extracted fields inline on policy cards | 3-4 hours | Needs summary data available at card level |
| Change FAB from "Ask" to "View coverage" or remove | 0.5 hours | Simple FAB swap |
| Cut what-if calculator from navigation | 0.5 hours | Remove nav entry |
| Add "What's Important" section with renewal + coverage facts | 2-3 hours | New section widget |
| Add coverage facts detection (evidence-state wording) | 4-6 hours | New feature — see `FIRST_PRINCIPLES_WEDGE.md` §3.5 |
| Make policy card tap → CoverageSummaryScreen (not DetailScreen) | 0.5 hours | Route change |
| Update tests | 2-3 hours | Test snapshots will need updating |

## 5. What This Does NOT Change

- Upload flow (same)
- Policy detail screen (same — tapped from card)
- Q&A screen (same — secondary tab)
- Family screen (same — section on dashboard is a summary)
- Emergency card (same — action button)

## 6. Open Questions

| Question | Decision needed from |
|----------|---------------------|
| Should inline coverage data on cards be real-time or cached? | Engineering — performance vs freshness |
| Is the "What's Important" section actionable (tap → renew) or informational only? | Founder (wedge says informational with evidence-state wording) |
| Should the FAB be removed entirely on phones with bottom nav? | UX decision — redundant nav patterns |

## 7. Risk: Information Overload

The redesign puts more information on the dashboard than currently exists. Risk: the user sees numbers they don't understand and feels overwhelmed.

**Mitigation:**
- Policy cards show 2-3 key values inline (sum insured, expiry, premium)
- Full extraction is a tap away (→ CoverageSummaryScreen)
- "What's Important" section shows only actionable items
- Skeleton loading while data processes

## 8. Relation to Other Documents

This analysis is a **future implementation candidate**. It is recorded so the reasoning doesn't need re-derivation. The dashboard should be revisited when:
- Coverage facts detection is implemented (see `FIRST_PRINCIPLES_WEDGE.md`)
- Post-upload navigation is changed to coverage summary (see `onboarding_first_principles_redesign.md`)
- User feedback indicates the current dashboard isn't delivering comprehension-first experience

## 9. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — first-principles dashboard redesign analysis from chat | Founder correction: §0.3.1 documentation mandate |
