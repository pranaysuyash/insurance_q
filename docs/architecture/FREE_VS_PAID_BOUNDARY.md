# Free vs Paid Tier Boundary — Commercial & Packaging Layer

> **Status:** Proposed (experiment record) — all exact limits and prices require operator approval with unit economics and sourced benchmarks before they govern.
> **Layer:** Commercial & packaging — sits beneath the [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) and the [First-Principles Wedge](./FIRST_PRINCIPLES_WEDGE.md). **This document does not redefine the product boundary.** The five gates (A–E) in the constitution decide what is in the product; this document only decides how an in-product feature is packaged and priced.
> **Last updated:** 2026-07-29 (revised by ADR-2026-07-29-02)
> **Governing ADR:** [ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
> **Evidence tier:** Decision-grade commercial reasoning; exact prices are hypotheses (Tier 0), not market facts, unless each carries a durable source citation (see §7).

> ⚠️ **Scope rule:** If a feature fails Gate C (product role) in the constitution, it is **not in the product at any tier** — not free, not paid. This document only classifies features that are already inside the product boundary. Where the earlier draft of this file treated "comparison" as a paid tier feature while the Wedge said comparison was outside the product, that contradiction is resolved in [ADR-2026-07-29-02 §4.1](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md): neutral owned-policy comparison is IN (basic free / advanced paid candidate); shopping comparison is OUT at every tier.

---

## 1. The Framework

The wedge says:

> **CoverWise is a personal insurance knowledge base.**
> The user's outcome is **comprehension** — understanding their insurance situation.
> **Comprehension is free. Convenience and depth are paid.**

This document applies that statement to every monetizable feature in the product. The goal is a sharp boundary: no user ever pays for understanding what their policy covers, and no feature that is merely convenient or deep is free.

### The Three Categories

| Category | Definition | Examples | Pricing |
|----------|------------|----------|---------|
| **🧠 Comprehension** | Directly answers "what does my insurance cover?" The feature's job is understanding — not speed, not export, not comparison. | See §2 | **Free** — gating this would violate the wedge |
| **⚡ Convenience** | Makes comprehension faster, easier, or accessible across devices. Does not add new understanding. | Priority processing, cloud sync, export | **Paid** — the user pays for time saved |
| **🔬 Depth** | Adds analysis beyond single-policy comprehension. Comparison, family cross-policy matrix, deep Q&A. | Policy comparison, family view, annual review | **Paid** — the user pays for more insight |

### The Single Gate Question

Apply this question to every feature that could be monetized:

> **"If I gate this behind payment, does a user who needs to understand their insurance situation lose access to something essential?"**

- If **yes** → it must be free. Comprehension cannot be a paywall.
- If **no** → it can be paid. The user can still achieve their core outcome without it.

---

## 2. Feature-by-Feature Classification

### 2.1 Policy Upload

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Can a user understand their insurance without uploading it? No. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** — with a policy count limit as the monetization lever |
| **Current state** | Free: 1 policy. Aligned. |
| **Rationale** | Upload IS onboarding — the means to comprehension. One policy is enough to demonstrate value. Most users have 1-2 policies (founder input), so 1 free creates a natural upgrade path for the minority who need more. |

### 2.2 Coverage Summary

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Can a user understand their insurance without the summary? No — this IS the comprehension output. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** — gating this would make the app useless |
| **Current state** | Free: full summary. Aligned. |
| **Rationale** | The summary is the closest feature to the wedge. It shows what the user's policy covers at a glance. Gating it would violate the product's reason to exist. |

### 2.3 Policy Detail Screen

| Aspect | Analysis |
|--------|----------|
| **Gate question** | If this were paid, could the user understand their insurance? They could use the summary, but the detail is where nuanced comprehension lives (exclusions, limits, conditions). |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** — detail is still comprehension |
| **Current state** | Free: full detail. Aligned. |
| **Rationale** | Detail screen shows extracted fields (sum insured, deductible, exclusions, etc.). These ARE the policy comprehension. Charging for access to your own policy data would break trust. |

### 2.4 Basic Q&A

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user need to ask questions to understand their policy? Yes — especially for complex clauses, exclusions they don't recognize, or specific coverage they're wondering about. Comprehension is not complete without the ability to ask. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** — with a monthly question limit |
| **Current state** | Free: 20 questions/month. Reasonable. |
| **Rationale** | Most comprehension questions are answered in the first 5-10 queries per policy. 20/month covers the core need. Heavy users who exhaust the limit naturally have deeper needs and are candidates for paid tiers or Q&A packs. |
| **The boundary** | Basic Q&A (direct policy questions) is free. Advanced analysis ("simulate a claim scenario across all policies") is depth → paid. |

### 2.5 Q&A Packs (Alternative to Subscription)

| Aspect | Analysis |
|--------|----------|
| **Gate question** | If packs are the ONLY way to get more questions, do free users lose comprehension? |
| **Category** | ⚡ **Convenience** (for the free user who needs more) |
| **Verdict** | **Paid** — but as a microtransaction alternative to subscription |
| **Current state** | Starter ₹49/5Q, Value ₹119/15Q, Pro ₹199/30Q. Aligned — packs exist. |
| **Rationale** | Packs are an alternative payment path for users who don't want a subscription. The free user gets 20 questions/month for free comprehension. If they need more, they can pay per pack rather than committing to a subscription. This respects the wedge (comprehension starts free) while monetizing heavy use. |

### 2.6 Citation Verification Badges

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Is evidence-backed comprehension a premium feature? No — it's the core trust mechanism. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** — the moat is for everyone |
| **Current state** | Free: full citation badges. Aligned. |
| **Rationale** | The citation verification (fully_backed / partially_backed / abstained) is CoverWise's differentiator. "Every answer cites its source" is the marketing message. Gating this would undermine the core value prop. |

### 2.7 Emergency Card

| Aspect | Analysis |
|--------|----------|
| **Gate question** | At the moment of a claim, does the user need to understand what their policy covers? Critically yes. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** |
| **Current state** | Free. Aligned. |
| **Rationale** | The emergency card shows the user exactly what to do, who to call, and what their policy covers when they need it most. Monetizing this would be predatory — the user is in distress and needs information, not a paywall. |

### 2.8 Claim Support

| Aspect | Analysis |
|--------|----------|
| **Gate question** | "What do I need to file a claim" is a comprehension question — understanding the process. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** |
| **Current state** | Free. Aligned. |
| **Rationale** | Claim documentation requirements are part of what the policy covers. The user needs to understand what to do. Not a premium feature. |

### 2.9 Renewal Reminders

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user need to know when their coverage expires to understand their insurance situation? Yes. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** |
| **Current state** | Free. Aligned. |
| **Rationale** | Renewal reminders are a direct comprehension need: "when does my coverage end?" Gating this would cause lapses in coverage, harming the user. |

### 2.10 Proactive Coverage Gap Alerts

| Aspect | Analysis |
|--------|----------|
| **Gate question** | "Your policy does not cover flood damage" — is this comprehension or depth? It directly tells the user something about their situation. |
| **Category** | 🧠 **Comprehension** |
| **Verdict** | **Free** — but gap analysis across policies could be depth |
| **Current state** | Not yet built. |
| **Rationale** | A simple alert per policy ("your health policy doesn't cover dental") is comprehension — it directly tells the user what they lack. A cross-policy gap analysis ("across all 3 policies, you have no flood coverage anywhere") is depth analysis. The boundary: per-policy gap notifications are free; cross-policy gap reports are paid. |
| **Implementation guidance** | Single-policy gap = free event/notification. Cross-policy gap = paid feature (gate as `allowAdvancedSearch` or new `allowGapAnalysis`). |

### 2.11 Family Coverage Per Policy

| Aspect | Analysis |
|--------|----------|
| **Gate question** | "Does my family's health insurance cover my dependent's hospital visit?" This is a comprehension question about a specific policy's family coverage. |
| **Category** | 🧠 **Comprehension** (per-policy) |
| **Verdict** | **Free** — per-policy family coverage is part of understanding the policy. |
| **Current state** | Family view is gated behind Plus/Family tiers. This might be over-gated. |
| **⚠️ Boundary check** | Looking at the policy and seeing "dependent coverage includes spouse and children up to ₹5L" is comprehension. The feature `FamilyView` in the current codebase is a CROSS-POLICY family matrix — that IS depth (paid). But per-policy family coverage shown within the policy detail screen should be free. |
| **Recommendation** | Per-policy family coverage info in the detail screen = free. Cross-policy family matrix view = paid (`allowFamilyView`). This is consistent with the current code — the `allowFamilyView` gating is for the cross-policy matrix. |

### 2.12 Policy Comparison

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user NEED to compare two policies to understand each one individually? No. The summary of each policy provides individual comprehension. Comparison is a depth analysis that adds value beyond comprehension. |
| **Category** | 🔬 **Depth** |
| **Verdict** | **Paid** |
| **Current state** | Gated behind Plus/Family (`allowComparison`). Aligned. |
| **Rationale** | Side-by-side comparison across policies is analysis, not comprehension. It's a premium feature that helps the user make tradeoff decisions — a depth exercise, not a basic understanding need. |

### 2.13 Family Cross-Policy Matrix

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user need a cross-policy matrix to understand each family member's coverage? The per-policy coverage details already answer "what does this policy cover for my family." The matrix is a convenience aggregation. |
| **Category** | 🔬 **Depth** |
| **Verdict** | **Paid** |
| **Current state** | Gated behind Plus/Family (`allowFamilyView`). Aligned. |
| **Rationale** | The matrix shows all policies with per-member coverage in one view. This is depth analysis beyond single-policy comprehension. |

### 2.14 Export / Share Coverage Report

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user NEED to export to understand their insurance? No. Understanding happens in the app. Export is a convenience for sharing with family, CA, or insurer. |
| **Category** | ⚡ **Convenience** |
| **Verdict** | **Paid** |
| **Current state** | Currently not gated. The share button on `CoverageDetailsSummaryScreen` is functional for all users. |
| **⚠️ Gap** | Per the wedge, export is convenience, not comprehension. It should be a paid feature. |
| **Recommendation** | Add an entitlement gate before export. Free users can view the summary in-app but cannot export/share. This is a small code change but aligns with the wedge. |

### 2.15 Cloud Sync

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user NEED multi-device sync to understand their insurance? No — they can understand on a single device. |
| **Category** | ⚡ **Convenience** |
| **Verdict** | **Paid** |
| **Current state** | Gated behind Plus/Family (`allowCloudSync`). Aligned. |
| **Rationale** | The wedge is about comprehension, not device portability. Cloud sync is a pure convenience/backup feature. |

### 2.16 Priority Q&A (Faster Backend)

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user NEED fast answers to understand their insurance? No — they need accurate answers. Speed is convenience, not comprehension. |
| **Category** | ⚡ **Convenience** |
| **Verdict** | **Paid** |
| **Current state** | Not explicitly gated (rate limits exist per user, but no speed tier). |
| **Recommendation** | Implement as part of rate-limit structure: free users get a shared queue (may be slower during peak), paid users get priority. The current 20 questions/month limit already serves this purpose indirectly. |

### 2.17 Advanced Search

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Can the user understand their policy using basic search (cover, exclusions, hospital list)? Yes. Advanced search (regex, cross-document, semantic search) is depth. |
| **Category** | 🔬 **Depth** |
| **Verdict** | **Paid** |
| **Current state** | Gated behind Plus/Family (`allowAdvancedSearch`). Aligned. |

### 2.18 Annual Review / Deep Analysis

| Aspect | Analysis |
|--------|----------|
| **Gate question** | Does the user need an annual review to understand their current coverage? No — the summary and detail screens provide that. The annual review is a depth exercise: "how has your coverage changed this year, and what should you consider for renewal?" |
| **Category** | 🔬 **Depth** |
| **Verdict** | **Paid** |
| **Current state** | Gated behind Family tier (`allowAnnualReview`). Aligned. |
| **Rationale** | Annual review is a premium analysis report that synthesizes changes, suggests renewal checks, and identifies evolving gaps. This is depth beyond daily comprehension. |

---

## 3. Current State vs Constitution Alignment

> **[CORRECTED 2026-07-29]** Per ADR-2026-07-29-02 §4.1 and §4.6: (a) "Policy comparison" is split — basic neutral owned-policy comparison is comprehension (free), advanced comparison is depth (paid candidate); shopping comparison is out at every tier. (b) "Emergency card" must be free per the constitutional floor (essential safety information); the earlier table's "emergency access ✅ dedicated support" under the paid Family tier conflated the free emergency *facts* with a paid *support* channel — those are separated below. (c) "Per-policy gap alerts" renamed to "coverage facts and verification prompts" and must use evidence-state wording.

| Feature | Constitution category | Current gate | Alignment |
|---------|----------------------|--------------|-----------|
| Policy upload (≥1 free) | 🧠 Free baseline | Free: 1 policy | ✅ Aligned (exact free capacity is Proposed) |
| Coverage summary | 🧠 Free baseline | Free | ✅ Aligned |
| Policy detail screen | 🧠 Free baseline | Free | ✅ Aligned |
| Basic grounded Q&A | 🧠 Free baseline (limited) | Free: 20/mo | ✅ Aligned (exact free quota is Proposed) |
| Citation badges | 🧠 Free baseline | Free | ✅ Aligned |
| Essential emergency facts | 🧠 Free baseline | Free | ✅ Aligned (constitutional floor; never gated) |
| Claim process info + contacts (policy-stated) | 🧠 Free baseline | Free | ✅ Aligned |
| Renewal reminders (factual) | 🧠 Free baseline | Free | ✅ Aligned |
| Per-policy coverage facts & verification prompts | 🧠 Free baseline | Not built yet | 🟡 Not yet (must be free when built; evidence-state wording) |
| Per-policy family coverage | 🧠 Free baseline | Currently free (detail screen) | ✅ Aligned |
| **Basic neutral owned-policy comparison** | 🧠 Free baseline (basic) / 🔬 Depth (advanced) | Gated: Plus/Family | ⚠️ **Split needed** — basic comparison should be free; advanced can be paid. See G4. |
| Export/share | ⚡ Paid candidate | **Currently free (gap)** | ❌ **Misaligned** (G1) |
| Cloud sync | ⚡ Paid candidate | Gated: Plus/Family | ✅ Aligned |
| Priority processing | ⚡ Paid candidate | Not explicitly gated | 🟡 Partially aligned (G2) |
| Q&A Packs (microtransaction) | ⚡ Paid candidate | Paid packs exist | ✅ Aligned (exact prices Proposed) |
| Advanced owned-policy comparison | 🔬 Depth | Gated: Plus/Family | ✅ Aligned (basic portion must be free — see G4) |
| Family cross-policy matrix | 🔬 Depth | Gated: Plus/Family | ✅ Aligned |
| Advanced search | 🔬 Depth | Gated: Plus/Family | ✅ Aligned |
| Annual workspace review | 🔬 Depth | Gated: Family | ✅ Aligned |
| Cross-policy coverage-facts report | 🔬 Depth | Not built yet | 🟡 Not yet |
| Shopping comparison (best/buy/switch) | ❌ OUT at every tier | n/a | n/a — not in product |

### Gaps Requiring Action

> **[CORRECTED 2026-07-29]** No code action is authorized by this document. These are tracked commercial decisions, gated on operator sign-off of [ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md) and a separate implementation inventory. Estimates are commit-units for planning only.

| # | Gap | Severity | Recommendation (post-sign-off) |
|---|-----|----------|----------------|
| G1 | **Export/share is free but is a convenience (paid candidate)** — `CoverageDetailsSummaryScreen` share button functional for all users. | P2 | Decide commercially: gate export behind a paid tier, OR keep free. Constitution does not require either. Requires operator decision + unit-economics check. |
| G2 | **Priority processing not explicitly gated** — rate limits exist but no differentiated queue. | P3 | Implement queue tiers when scaling; until then rate limits differentiate. |
| G3 | **Per-policy coverage-facts detection not implemented** — evidence-state prompts from extracted fields. | P2 | When built, must be free (constitutional floor) and use evidence-state wording only. |
| G4 | **Comparison must be split: basic free, advanced paid** — current gate treats all comparison as paid, but basic neutral owned-policy comparison is comprehension. | P2 | Define the basic/advanced split: basic (side-by-side cited facts, missing-data warnings) = free; advanced (cross-policy synthesis, matrices) = paid candidate. |
| G5 | **Emergency access classification** — essential emergency *facts* must be free (constitutional floor); any paid *support channel* must be a separate, clearly-labelled paid candidate, not a gating of the facts. | P2 | Separate "emergency facts" (free, never gated) from "dedicated support" (paid candidate) in tier definitions. |

---

## 4. Tier Definition (Proposed — all exact limits and prices require operator approval)

> **[CORRECTED 2026-07-29]** All exact limits and prices below are **Proposed hypotheses**, not settled doctrine, per ADR-2026-07-29-02 §4.6 and §4.7. They require operator approval with unit economics and sourced benchmarks. The constitutional free baseline (§2 of this doc, derived from the constitution) is the only hard floor.

### Free Tier: Comprehension baseline (constitutional floor)

> **Purpose:** The user receives enough source-verifiable comprehension to understand the product's value without paying.

| Limit | Value (Proposed) | Status |
|-------|------------------|--------|
| Policies | ≥1 (exact capacity Proposed) | Constitutional floor = at least 1 |
| Q&A/month | Limited (exact quota Proposed) | Constitutional floor = limited grounded Q&A |
| Essential emergency facts | Free, never gated | Constitutional floor |
| Source-page inspection | Free | Constitutional floor |
| Honest unknown/abstention states | Free | Constitutional floor |

Features included (constitutional floor): full coverage summary + detail screen · citation badges · essential emergency facts (policy-stated) · claim process info + contacts · factual renewal reminders · per-policy family coverage info · per-policy coverage facts & verification prompts (when built) · **basic neutral owned-policy comparison** (when built — see G4).

### Plus Tier: Convenience + Depth (Proposed)

> **Purpose:** The user has more policies, wants convenience (export, priority), and deeper organisation.

| Limit | Value (Proposed — pending operator approval) |
|-------|----------------------------------------------|
| Policies | 10 (Proposed) |
| Q&A/month | 200 (Proposed) |
| Export/share | ✅ (Proposed — see G1) |
| Cloud sync | ✅ |
| Priority processing | ✅ (see G2) |
| Advanced owned-policy comparison | ✅ (basic is free — see G4) |
| Family cross-policy matrix | ✅ |
| Advanced search | ✅ |

Pricing: **Proposed** — ₹149/month or ₹999/year (India). These numbers are hypotheses requiring a sourced benchmark (see §7) and unit-economics validation before they govern. Do not treat as settled.

### Family Tier: Full Depth (Proposed)

> **Purpose:** Household coverage management for families with multiple policies and members.

| Limit | Value (Proposed — pending operator approval) |
|-------|----------------------------------------------|
| Policies | 50 (Proposed) |
| Q&A/month | 500 (Proposed) |
| All Plus features | ✅ |
| Annual workspace review | ✅ |
| Dedicated support channel | ✅ (paid candidate — NOT a gating of emergency facts; see G5) |

> **[CORRECTED 2026-07-29]** The earlier "Emergency access ✅ (dedicated support)" row is removed from the paid Family tier. Essential emergency *facts* are a constitutional free baseline. A paid *dedicated support channel* is a separate paid candidate and must not be conflated with emergency access.

Pricing: **Proposed** — ₹249/month or ₹1,799/year (India). Hypotheses requiring sourcing + unit economics (see §7).

### Alternative: Q&A Packs (Proposed)

> **Purpose:** Free users who need more questions without committing to a subscription.

| Pack | Price (Proposed) | Questions (Proposed) |
|------|------------------|----------------------|
| Starter | ₹49 (Proposed) | 5 |
| Value | ₹119 (Proposed) | 15 |
| Pro | ₹199 (Proposed) | 30 |

All prices Proposed pending sourcing + operator approval.

---

## 5. Principle Resolution: Does Export Violate the Wedge?

**Objection:** "Exporting a coverage summary is how users share comprehension with their family. Gating it means a family member can't understand."

**Resolution:**
- **What's free:** The user can open the in-app summary and show it to someone, read it aloud, screenshot it. Comprehension is accessible.
- **What's paid:** A formatted PDF/HTML export with share button. The user is paying for convenience (auto-formatting, file creation, cross-platform sharing), not for the information itself.
- **Analogy:** Dropbox lets you view files for free (comprehension), but exporting a zip archive or sharing with external users requires a paid plan (convenience).
- **Test:** If a user can achieve comprehension by looking at the screen, the feature is convenience, not comprehension. The summary is on the screen for free. Export is a file creation + sharing convenience.

---

## 6. Principle Resolution: Would Q&A Limits Block Comprehension?

**Objection:** "A user with a complex policy might need 30 questions to fully understand it. The free tier 20/month limit blocks comprehension."

**Resolution:**
- **Most comprehension happens in the first 5-10 questions.** The summary + detail screen answer 80% of common questions (coverages, exclusions, sum insured, deductible, expiry). Q&A fills in the remaining 20%.
- **20 questions/month covers this with margin.** If the user truly needs more, ads (watch 2 ads for +6 questions) or the lowest-cost pack (₹49 for 5 questions, which is ~₹10/question) provide an accessible bridge.
- **The ads/pack alternatives exist specifically to prevent this objection** — the user is not blocked, only the free automatic quota. The barrier is very low (₹49 ≈ cost of a chai at a cafe).
- **Comprehension is not blocked — the automatic supply is.** This distinction matters. The user can still achieve full comprehension, they just may need to take a low-friction action if they're an outlier.

---

## 7. Pricing Evidence — audit required (CORRECTED 2026-07-29)

> **[CORRECTED 2026-07-29]** Per ADR-2026-07-29-02 §4.7, the earlier "PPP-adjusted" framing and the "RevenueCat 2026 India median monthly price ₹300–315" claim are **unsourced** and must not be retained as fact until each carries a durable citation. The table below is the evidence-audit skeleton that **must** be completed before any price governs.

For each price, record before it can be treated as anything more than a hypothesis:

| Field | Required content |
|-------|------------------|
| Source URL / durable citation | (to be filled — e.g., RevenueCat report URL, App Annie, store scrape) |
| Source date | (to be filled) |
| Geography | India / US / etc. |
| Store | Google Play / App Store / both |
| App category | Finance / Productivity / etc. |
| Original currency | INR / USD |
| Exchange or PPP methodology | (if "PPP-adjusted", name the actual method and index) |
| Market fact or internal hypothesis? | (state which) |

**Open pricing-evidence questions (must resolve before prices govern):**

1. The "RevenueCat 2026 India median monthly price ₹300–315" claim needs a URL, date, and confirmation it covers this app category on the relevant store(s). Until then it is an internal hypothesis.
2. The "PPP-adjusted" label needs an actual PPP method (which index? which year? which basket?). FX conversion is not PPP.
3. The US-equivalent prices (~$7.99 etc.) need a source for the US comparison set.
4. All exact tier prices (₹149/₹999/₹249/₹1,799) and pack prices (₹49/₹119/₹199) are experiments until supported by unit economics (CAC, LTV, churn) and user evidence.

Do not call any price "settled" or "PPP-adjusted" in copy, launch claims, or store listings until this audit is complete and the operator has approved.

---

## 8. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — applied first-principles wedge to 18 monetizable features, classified each as Comprehension/Convenience/Depth, identified 1 misalignment (export gating), resolved 3 principle objections. | Founder request: "Apply the first-principles framework to the free vs paid tier boundary" |
| 2026-07-29 | **Major revision per ADR-2026-07-29-02.** Document reclassified as the commercial/packaging layer beneath the constitution and wedge. Changes: (1) all exact prices and limits demoted to **Proposed** hypotheses requiring operator approval + sourcing; (2) "PPP-adjusted" and "RevenueCat 2026 India median ₹300–315" claims flagged unsourced, replaced with evidence-audit skeleton (§7); (3) policy comparison split — basic neutral owned-policy comparison = free baseline, advanced = paid candidate, shopping = out at every tier (G4); (4) emergency access separated — essential facts = free constitutional floor, dedicated support = separate paid candidate (G5); (5) added scope rule that this document does not redefine the product boundary (Gate C in the constitution decides that); (6) status changed from self-declared "Draft" to Proposed. | Operator direction: layered doctrine stack; ADR-2026-07-29-02 reconciliation. |

---

## 9. Anything else?

Yes. This document now carries five tracked commercial decisions (G1–G5) that are **open**, not resolved. They form the commercial decision backlog. None of them authorize code changes; each requires operator approval after ADR-2026-07-29-02 sign-off and a separate implementation inventory. A future agent must not read the tier table here as settled pricing — every number is a Proposed hypothesis until §7's evidence audit is complete and the operator has approved.

*This document is the commercial layer of the doctrine stack. For the product boundary, see the [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (Gates A–E). For the strategy and current wedge, see [FIRST_PRINCIPLES_WEDGE.md](./FIRST_PRINCIPLES_WEDGE.md). For the reconciliation that governs this layer, see [ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md).*
