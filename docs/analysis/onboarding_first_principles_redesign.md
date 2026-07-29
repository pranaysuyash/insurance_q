# Onboarding Redesign: First-Principles Analysis

> **Status:** Draft (analysis, not implemented)
> **Date:** 2026-07-29
> **Source session:** Founder request: "Apply the first-principles framework to the onboarding — what should it be if the goal is comprehension, not 'show features'?"
> **Evidence tier:** Decision-grade product reasoning (Tier 0) — not validated against user behavior
> **Related:** [First-Principles Derivation](../architecture/FIRST_PRINCIPLES_DERIVATION_FROM_MOTTO.md), [Product Wedge](../architecture/FIRST_PRINCIPLES_WEDGE.md)

---

## 1. What Prompted This Analysis

Founder asked: *"Apply the first-principles framework to the onboarding — what should it be if the goal is comprehension, not 'show features'?"*

The current onboarding flow (at time of analysis):
- SplashScreen (2s delay)
- OnboardingScreen with 3 feature-slide pages explaining what the app does
- Consent acceptance checkbox
- Navigation to empty dashboard
- User must tap Upload → find PDF → wait for processing → navigate to Q&A → ask question

**Total taps to first value:** ~8 taps, ~2+ minutes

## 2. First-Principles Derivation

### First Cause Application

The wedge says: *"The user's outcome is comprehension — understanding their insurance situation."*
The wedge also says: *"Every tap between 'I want to understand' and 'I understand' is a comprehension delay."*

**First cause #1:** The user has an insurance policy they need to understand.
**First cause #4:** The user trusts the app with sensitive data — consent is a requirement, not a friction.

These two first causes are in tension. Consent (first cause #4) requires explaining to the user what they're agreeing to. But feature-slide pages (first cause #1) are comprehension delay.

### Resolution: The first slide is consent, not features

The correct first-principles solution is not "remove all information" — it's:
1. **Replace 3 feature-slide pages with 1 consent + outcome screen**
2. **Replace feature explanations with a concrete illustration of the outcome**
3. **The outcome screen shows: "Upload your policy → see what it covers"** not "3 features you might care about"

### The Flow That Follows

| Current | First-Principles | Why |
|---------|------------------|-----|
| Splash (2s) | Splash (2s, or skip if processed) | Acceptable — brand moment |
| 3 feature slides | **1 outcome screen** | User needs to know what happens, not what features exist |
| Consent checkbox on slide 3 | Consent on the outcome screen | Must still get consent — legal requirement |
| → Empty dashboard | → **Upload screen** with file picker triggered | First tap is the upload — removes 3 taps of navigation |
| → Upload → Wait → Q&A | → Upload → Wait → **Coverage Summary** | Destination is the comprehension output, not the chat interface |

### Why 3 Feature Slides Are Wrong (Per the Wedge)

The current feature slides say:
1. "Understand your policy" — tells the user what the app does
2. "Ask questions" — tells the user another feature
3. "Never miss a renewal" — tells the user another feature

The first-principles problem: **these describe the interface, not the outcome.** The user doesn't care about features. They care about understanding their policy. The onboarding should show the outcome (a coverage summary with citation badges) and nothing else.

## 3. The Proposed Redesign

### Screen 1 (The Only Onboarding Screen)

```
┌─────────────────────────────────┐
│  [CoverWise logo]               │
│                                 │
│  Understand your insurance      │
│  in 30 seconds.                 │
│                                 │
│  ┌─────────────────────────┐    │
│  │  [Screenshot of         │    │
│  │   coverage summary      │    │
│  │   showing real data]    │    │
│  └─────────────────────────┘    │
│                                 │
│  ✓ Upload policy PDF            │
│  ✓ See what's covered instantly │
│  ✓ Every answer cites its source│
│                                 │
│  ☐ I've read and accept the     │
│    Privacy Policy and Terms     │
│                                 │
│  [    Upload Your Policy    ]   │
│                                 │
├─────────────────────────────────┤
```

**Changed from current:**
- 3 feature slides → 1 outcome-focused screen
- Feature descriptions → outcome promises with a concrete visual
- Consent is on the same screen (not deferred to a later interaction)
- The call-to-action is the upload itself — not "Get Started" leading to more onboarding

### Screen 2 (Post-Upload, During Processing)

Processing screen already exists. Keep it. Update the destination link to coverage summary instead of Q&A.

### What the User Sees After

**Current:** Q&A screen with "Ask about your policy" prompt
**Proposed:** Coverage summary showing extracted fields (sum insured, premium, deductible, expiry, exclusions)

The user sees comprehension output immediately. Q&A is available as a secondary tab.

## 4. Implementation Impact

| Change | Effort | Risk |
|--------|--------|------|
| Replace 3-slide OnboardingScreen with 1 outcome screen | 2-3 hours | Low — single screen replacement |
| Navigate to CoverageSummaryScreen after upload (not Q&A) | 1 hour | Low — route change in upload handler |
| Keep consent gathering (legal requirement) | No change | None — consent stays |
| Add screenshot preview of coverage summary to onboarding | 1 hour | Low — static asset |
| Update tests for onboarding | 2 hours | Medium — test snapshots will change |

## 5. What This Does NOT Change

- Consent gathering (legal requirement, stays)
- Upload flow (stays, just destination changes)
- Processing screen (stays)
- Q&A screen (stays, becomes secondary)
- Coverage summary (already exists, just becomes the destination)

## 6. Open Questions

| Question | Decision needed from |
|----------|---------------------|
| Should the single onboarding screen also have a "Skip and explore" link? | Founder |
| Should existing users (who already completed 3-slide onboarding) see the new screen on upgrade? | Founder |
| Is the coverage summary ready to be the post-upload destination for ALL policy types? | Engineering verification |

## 7. Relation to Other Documents

This is a **future implementation candidate**, not a current requirement. The analysis is recorded here so that:
- When onboarding is revisited, the first-principles reasoning doesn't need to be re-derived
- The decision to keep 3 slides or reduce to 1 can be made deliberately, not by default
- The alternative (keep current flow) is preserved as a debated alternative, not silence

## 8. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — first-principles onboarding redesign analysis from chat | Founder correction: analysis was given in chat but never documented per motto_v4 §0.3.1 |
