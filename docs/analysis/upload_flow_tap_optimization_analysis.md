# Upload Flow Optimization: Comprehension Delay Analysis

> **Status:** Draft (analysis, partially implemented)
> **Date:** 2026-07-29
> **Source session:** Founder request: "Start with a simpler refinement of the current flow — reduce the upload-to-answer path from 8 taps to 3 without changing the architecture"
> **Evidence tier:** Codebase audit (Tier 1) — verified against source code
> **Related:** [Onboarding Redesign](onboarding_first_principles_redesign.md), [Dashboard Redesign](dashboard_first_principles_redesign.md), [Product Wedge](../architecture/FIRST_PRINCIPLES_WEDGE.md)

---

## 1. What Prompted This Analysis

After rejecting the demo policy and camera-first suggestions from the product audit (see `six_month_product_post_mortem.md` §5), the founder asked for a *simpler* refinement: shrink the upload-to-answer path from 8 taps to 3, without changing the architecture or adding fake data.

## 2. The Current Flow (8 Taps to First Answer)

```
1. Tap app icon                   [Tap 1]
2. Splash screen (2s)             [Wait]
3. Swipe through 3 onboarding     [3 swipes]
4. Tap consent checkbox           [Tap 2]
5. Tap "Get Started / Upload"    [Tap 3]
6. Select PDF from file picker    [Tap 4]
7. Wait for processing (30s-2min) [Wait]
8. Navigate to Q&A tab            [Tap 5]
9. Type question                  [Tap 6-7 (type + send)]
10. See answer                     [Tap 8]
```

**Total: 8+ taps, 2+ minutes before any value**

## 3. The 3-Tap Target

The request: reach the same outcome (user sees an answer about their policy) in **3 taps**.

## 4. Analysis: What Can Be Removed Without Architecture Change

### Taps That Require Architecture Change (NOT in scope)

- **File picker interaction (Tap 4/6):** The user must select their file. Can't be removed without a different import mechanism (share sheet, email forwarding). These are architecture changes.

### Taps That Can Be Removed

| Tap # | Current Step | Can remove? | How |
|-------|-------------|-------------|-----|
| 1 | App icon | No | Must tap to open app |
| 2 | Splash screen 2s | **Partially** | Reduce to 1s; or skip if user has policies |
| 3-5 | 3 onboarding slides | **Yes** | Replace with 1 outcome screen (see redesign doc) |
| 6 | Consent checkbox | **No** | Legal requirement. But can be on same screen as upload |
| 7 | Tap "Upload" button | **No** | Must invoke file picker |
| 8 | File picker interaction | **No** | User must select the PDF |
| 9 | Wait for processing | **No** | Must process the document |
| 10 | Navigate to Q&A | **Yes** | Send to coverage summary instead (destination change) |
| 11 | Type question | **Yes** | If the coverage summary already shows key info, user may not need to type a question |
| 12 | See answer | **Not needed** | If destination is coverage summary, the "answer" is already visible |

### Implemented Change: Destination After Upload

**Change made:** After upload completes, the user is navigated to Q&A tab (`qa_screen.dart`) instead of `dashboard_screen.dart`. This was the first tap-optimization change.

**Wedge alignment assessment:** The coverage summary (not Q&A) is the correct destination per the wedge (coverage summary is closer to comprehension than Q&A is). However, the Q&A-after-upload change is still an improvement over the previous state (dashboard-after-upload which required another tap to reach Q&A). The full fix (coverage summary as destination) requires a separate change.

### Proposed Remaining Changes

| Change | Taps Saved | Effort | Done? |
|--------|-----------|--------|-------|
| 1. Replace 3-slide onboarding with 1 outcome screen | 2 taps saved | 2-3 hours | ❌ Not implemented |
| 2. Navigate to coverage summary (not Q&A) after upload | 0 taps (better experience) | 1 hour | ❌ Not implemented (went to Q&A instead) |
| 3. Reduce splash delay from 2s to 1s | N/A (time saved) | 5 min | ❌ Not implemented |
| 4. Show key extracted fields inline on upload completion | 0 taps (reduces need to type a question) | 3-4 hours | ❌ Not implemented |
| 5. Skip onboarding for returning users who already consented | 3 taps saved | 1 hour | ❌ Not implemented |

## 5. The 3-Tap Target Is Achievable

If changes 1, 2, 3, and 5 are implemented:

```
1. Tap app icon                    [Tap 1]
2. (Splash 1s, skip onboarding     [saved 2 taps + 1s]
   if returning user)
3. Tap "Upload" on outcome screen  [Tap 2]
   (consent already on this screen)
4. File picker                     [Tap 3]
5. Processing (unavoidable wait)
6. → Coverage summary (auto-navigate, shows key info)
```

**Result: 3 taps to value. 1 minute total (including processing wait).**

## 6. What Was Actually Implemented

In a focused session, the following was implemented to reduce taps:

**Change 1: Q&A after upload**
- `document_service.dart`: After upload processing completes, the polling loop now navigates to `qa_screen.dart` with `autoFocus: true` instead of dashboard.
- `qa_screen.dart`: Added support for `autoFocus` parameter — when true, the keyboard and text field focus automatically so the user can immediately type their first question without tapping the text field first.

**Estimated taps saved:** 2 (skip dashboard → Q&A navigation, skip text field tap)

**Change 2: Onboarding refinement (not implemented — deferred to redesign doc)**

## 7. The Ideal First-Principles Flow

Per the wedge analysis (see `onboarding_first_principles_redesign.md` and `dashboard_first_principles_redesign.md`), the ideal flow is:

```
1. Tap app icon                    [1 tap]
2. (Skip onboarding if returning)  [0]
3. See dashboard with coverage     [0 — info is already there]
   info loaded from existing data
4. Tap the policy card             [1 tap]
5. → Coverage summary screen       [0 — auto-navigate]
```

This is the "proactive" mode from the wedge. The user doesn't need to upload or ask — the information is already there from a previous session. Taps 3-5 are exploration, not comprehension.

## 8. Relation to Other Documents

This analysis represents iteration between the "do nothing" and "redesign everything" extremes. The founder asked for a middle path — optimize the existing architecture, don't rebuild. The remaining changes are tracked in `onboarding_first_principles_redesign.md` and `dashboard_first_principles_redesign.md` for when architecture changes are acceptable.

## 9. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — tap-by-tap analysis of upload flow with implemented Q&A-after-upload change | Founder directive: reduce 8 taps to 3 without architecture change. Documented per §0.3.1. |
