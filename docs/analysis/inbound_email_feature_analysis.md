# Inbound Email Feature Analysis: Email-to-CoverWise

> **Status:** Draft (considered feature; rejected for launch per first-principles wedge)
> **Date:** 2026-07-29
> **Source session:** Product audit discussion — "6-month post-mortem" analysis
> **Evidence tier:** Product reasoning (Tier 0)
> **Related:** [Product Wedge](../architecture/FIRST_PRINCIPLES_WEDGE.md), [6-Month Product Audit](six_month_product_post_mortem.md)

---

## 1. What Was Proposed

During the 6-month product audit (imagined scenario), the following recommendation was made:

> **Email-to-CoverWise:** Every user gets a unique inbound email address. Forward a policy PDF to that address → auto-processed → push notification when ready.

**Effort estimate:** 3 days
**Impact estimate:** ⭐⭐⭐⭐⭐ (would reduce upload friction)

## 2. The Discussion

The founder questioned this recommendation:

> *"Email to coverwise seems fine, but does it prove that the 6th month performance was because of that?"*

The concern: the email-flow recommendation was made as a "fix the cold start" measure, but there was no evidence that email friction specifically caused the 500-2K download scenario. It was a plausible fix for the imagined scenario, not a proven solution.

## 3. Wedge Analysis

**Gate A — Outcome:** Does email forwarding materially reduce the effort to understand an insurance policy? Partially — it removes the file picker step. But the user must still:
1. Find the policy in their email/WhatsApp
2. Forward it to the CoverWise address
3. Wait for processing
4. Open the app to see the result

The comprehension delay is reduced but not eliminated.

**Gate C — Product role:** Inbound email is a **delivery mechanism**, not a comprehension feature. It's an infrastructure choice, not a wedge decision.

**Gate E — Strategy fit:** Email forwarding is not part of the current product wedge. It could be added later as a convenience feature (paid candidate) once the core comprehension loop is proven.

## 4. Verdict

**Rejected for launch.** The email-to-CoverWise feature:
- Does not address the root cause (comprehension delay)
- Adds operational complexity (email parsing, unique address management, spam filtering)
- Has no evidence supporting its impact on retention or acquisition
- Would be a paid convenience feature at best (see `FREE_VS_PAID_BOUNDARY.md`)

**Revisit conditions:**
- User research shows that "finding the PDF on device" is the primary drop-off point
- Share-sheet integration (which exists and is simpler) proves insufficient
- Resources are available for the email infrastructure without compromising core features

## 5. Alternative (What Was Done Instead)

Instead of email forwarding, the following was implemented:
- **Q&A after upload** — navigate to Q&A screen immediately after upload processing completes (reducing 2 taps)
- **Coverage summary as destination** — proposed as the wedge-aligned replacement (see `onboarding_first_principles_redesign.md`)
- Onboarding reduction from 3 slides to 1 outcome screen (proposed)

These changes address comprehension delay without introducing email infrastructure complexity.

## 6. Relation to Other Documents

This analysis is recorded so future agents don't re-propose email-to-CoverWise without understanding why it was rejected. See also the demo-policy rejection (`ADR-2026-07-28-reject-demo-mode.md`) and camera-first flow rejection (`FIRST_PRINCIPLES_WEDGE.md` §4.2) for similar launch-scope rejections.

## 7. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — email-to-CoverWise feature consideration documented | Exhaustive documentation audit per §0.3.1 |
