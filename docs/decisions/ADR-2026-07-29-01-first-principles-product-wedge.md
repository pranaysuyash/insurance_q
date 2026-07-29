# ADR-2026-07-29-01: First-Principles Product Wedge and Decision Framework

**Status:** Accepted
**Date:** 2026-07-29
**Updated:** 2026-07-29 (initial)

## Context

The product had no written first-principles definition of what it is, what problem it solves, and what it refuses to do. Feature decisions were made case-by-case without a unifying framework. A 6-month Play Store post-mortem exercise surfaced conflicting recommendations (e.g., demo policy, camera-first flow) that could not be resolved against a shared north star.

Without an anchored wedge, three failure modes recur:

1. **Scope creep:** features from adjacent products (lead capture, literacy quizzes, what-if calculators) accumulate because there is no test for "is this us?"
2. **Contradictory recommendations:** audits and analyses produce recommendations that conflict because there is no shared decision framework to evaluate them against.
3. **Wasted engineering:** features are built, then cut, then re-proposed by the next agent because the rejection reason was never recorded.

## Decision

**Adopt the following first-principles product wedge as the canonical decision framework for all product, feature, engineering, and marketing decisions.**

### The Wedge

> **CoverWise is a personal insurance knowledge base.**
> Not a document reader. Not a generic AI chat. Not a policy comparison tool.
> A single source of truth for "what does my insurance actually cover."

### The Fundamental User Need

> *"I have insurance policies. I need to understand what they cover, when they expire, and what to do when something happens."*

The user's outcome is **comprehension** — understanding their insurance situation. Upload is onboarding (a means, not the end). Chat is an interface (one way to reach the outcome, not the outcome itself).

### The Decision Gate

Every product decision — feature, screen, prompt, UI copy, monetization model, marketing message — must pass this question:

> **"Does this directly help the user understand their insurance situation better?"**

If the answer is "no" or "indirectly," the item is outside the wedge and must be cut or deferred, not merely de-prioritized.

## Options Considered

| Option | Description | Verdict |
|--------|-------------|---------|
| **A: Broad insurance platform** | CoverWise as a unified platform: policy management, comparison, agent connect, claims filing, education, estimation | Rejected. Each adjacent capability (comparison, estimation, agent connect) is a different product with different trust obligations, regulatory requirements, and business models. Combining them under one roof creates conflicts (e.g., showing a "best price" recommendation while also connecting users to agents who pay for leads). |
| **B: Document reader + AI chat** | CoverWise as "upload any document and ask questions about it" — generic, not insurance-specialized | Rejected. A generic document reader has no defensible moat. The insurance specialization (type-specific fields, citation verification, regulator escalation paths, family coverage) is the differentiation. Generic AI chat is a commodity. |
| **C: Personal insurance knowledge base (CHOSEN)** | Narrow wedge focused on a single outcome: the user understands their own insurance situation | **Chosen.** The wedge is narrow enough to be defensible (insurance-specific extraction, citation verification, regulator context) and broad enough to support a product (coverage summaries, Q&A, alerts, family context, renewal reminders). |

## Chosen Path

**Option C.** The wedge is:

- **Personal** — one user, their policies, their family. Not multi-tenant, not enterprise.
- **Knowledge base** — the system knows what the policies say. It does not recommend, compare, estimate, or broker.
- **Insurance-specific** — type-aware extraction (health, motor, life, home, travel, marine), regulator context (IRDAI escalation), claim-support materials (what to do, who to call).

### Core Principles That Follow

1. **Proactive beats reactive.** The app should surface coverage, deadlines, and gaps before the user asks. Q&A is the fallback for edge cases, not the primary interface.

2. **Comprehension delay is the real friction.** The problem with upload friction is not "the app is empty" — it's that every tap between "I want to understand my policy" and "I understand it" blocks the core outcome. The solution is shortening the comprehension path, not adding fake data.

3. **Coverage summary is closer to the wedge than Q&A.** The summary screen shows all extracted fields across all policy types. Q&A answers questions the summary doesn't cover. The first-principles ordering: coverage overview first, Q&A second.

4. **Meet the user where their document already lives.** Policies arrive via email, insurer portals, and WhatsApp — not printed paper. The import path should match the delivery channel: share sheet, email forwarding, auto-import. Camera capture is for the minority case.

5. **Comprehension is free; convenience and depth are paid.** The free tier stores unlimited policies and shows the coverage summary. The paid tier adds export, AI deep-dive Q&A (beyond basic queries), family sharing, and priority processing. Gating comprehension itself would violate the wedge.

### What's Outside the Wedge

The following features fail the decision framework and are explicitly **outside the product boundary**:

| Feature | Why It Fails |
|---------|-------------|
| Demo/bootstrap policy | Does not help the user understand *their* situation. Teaches wrong behavior. |
| Camera-first upload | Does not match how policies arrive (email/portal PDFs > printed paper). |
| What-if premium calculator | Speculative estimation, not grounded in actual coverage. Implies underwriting authority. |
| Policy comparison across insurers | Implies recommendation. Outside the personal-knowledge-base boundary. |
| Lead capture / "connect with an agent" | Implies brokering. Outside the wedge. |
| Newsletter signup | Outside the wedge. |
| Insurance literacy quiz | Education is not comprehension of *your* situation. Belongs on marketing site. |

### What's Inside the Wedge (Strengthen)

| Feature | Why It Belongs |
|---------|----------------|
| Upload → coverage summary | Shortest path to comprehension. The coverage summary (not Q&A) should be the post-upload destination. |
| Multi-policy aggregation | "What do I have?" is the first question every user asks. One view of all coverages, expirations, gaps. |
| Proactive gap alerts | "Your motor policy doesn't cover flood damage." Prevents surprises at claim time. |
| Family coverage per policy | "Does my family's health insurance cover X?" — wedge question. |
| Citation verification badges | The moat: "every answer cites its source." Differentiates from hallucination-prone AI. |
| Renewal reminders | Drives return visits. |
| Claim support (what to do, who to call) | Renewal/contact utility component of the wedge. |

## Tradeoffs

- **Narrow wedge means rejecting useful-adjacent features.** A what-if calculator would be useful to some users. A demo policy would give instant value. The wedge requires saying no to useful features that belong to a different product.
- **Discipline cost.** Every feature proposal must be evaluated against the wedge. This takes effort and requires the team to internalize the framework rather than following a checklist.
- **Risk of over-correction.** The wedge could be applied too rigidly, rejecting features that are genuinely inside the wedge but not obviously so. Mitigation: if a feature is on the boundary, discuss it explicitly against the decision question rather than rejecting reflexively.

## Assumptions

1. The target user has one or more insurance policies (health, motor, life, home, travel, or marine) and wants to understand what they cover.
2. The user is an individual policyholder, not a broker, agent, or enterprise.
3. Policies arrive primarily as digital PDFs (email, portal download, WhatsApp).
4. The user's primary language is English or an Indian language (Hindi, Gujarati, Marathi, etc.).
5. The user is comfortable with a mobile app as the primary interface.

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| User has mostly printed policies | Medium | Share sheet + email inbound cover digital delivery. For printed policies, suggest the user ask their insurer for a digital copy. Do not optimize for the shrinking minority. |
| User wants comparison/recommendation, not comprehension | Medium | Marketing and onboarding must set expectations: "We help you understand your policy, not choose one." Users who want comparison are not CoverWise's audience. |
| Wedge is too narrow to sustain a business | Low | The wedge supports a freemium model (comprehension free, depth paid). If proven too narrow, widen deliberately via a new ADR — not by feature accretion. |

## Validation Plan

1. **Every new feature proposal** is evaluated against the decision question before implementation begins.
2. **Quarterly wedge audit:** review all features shipped in the quarter against the wedge. Flag any that are outside the boundary for cut/keep/finish.
3. **Launch-claim registry (§0.11.1):** every marketing claim references the wedge (e.g., "helps you understand" maps to this ADR; "compares insurers" does not).
4. **ADR-adjacency rule:** any feature that is on the boundary of the wedge requires its own ADR before implementation.

## Rollback / Migration Path

If the wedge is revised (widened or narrowed), this ADR is updated via the Update log (append-only, per §0.12.1). The revision records what changed, why, and what triggered the change. All prior wedge state decisions remain visible.

## Owner / Next Reviewer

Pranay (operator) — initial sign-off on this ADR. Subsequent wedge revisions require operator sign-off.

## Links

- [First-Principles Wedge document (detailed analysis)](../architecture/FIRST_PRINCIPLES_WEDGE.md) — the working document that this ADR formalizes
- [Free vs Paid Tier Boundary (detailed analysis)](../architecture/FREE_VS_PAID_BOUNDARY.md) — applies the wedge to every monetizable feature with per-feature classification, tier definitions, and principle resolutions
- [ADR-2026-07-19-08 Cut/keep/finish half-built features](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) — the first cut/keep/finish anchored to the long-term product shape
- [ADR-2026-07-28 Reject demo mode](./ADR-2026-07-28-reject-demo-mode.md) — a specific wedge decision (demo rejected) that this framework generalizes
- [motto_v4.md §0.12 Decision Record Requirement](../../motto_v4.md) — the ADR schema this record follows
- [motto_v4.md §0.3.1 Everything Is a Documentation Candidate](../../motto_v4.md) — the mandate that led to this ADR

## What Would Cause This Decision to Be Revisited

1. The product acquires a regulatory or business-model function (e.g., becomes a licensed insurance advisor) that widens the wedge.
2. Real user data shows that comprehension alone does not drive retention or revenue, forcing a pivot.
3. A competitor commoditizes the comprehension layer, requiring widening for differentiation.
4. The operator explicitly widens the wedge via a new ADR.

Until one of these triggers fires, the wedge is the canonical constraint for all product decisions.

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | Initial ADR created. Formalizes the first-principles wedge analysis from 2026-07-28 session. | motto_v4 §0.3.1 mandate: the wedge analysis existed only in chat and in `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` (a working doc, not a formal ADR). Promoted to ADR status so every future decision has an anchoring reference. |
| 2026-07-29 | Added detailed free vs paid tier boundary. Applied the wedge to 18 monetizable features, classified each as Comprehension (free), Convenience (paid), or Depth (paid). Identified 1 misalignment (export gating), resolved 3 principle objections (export, Q&A limits, pricing). | Founder directive: "Apply the first-principles framework to the free vs paid tier boundary." Detailed analysis in `docs/architecture/FREE_VS_PAID_BOUNDARY.md`. |
| 2026-07-29 | **Sign-off correction + partial supersession by [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md).** (1) **Sign-off:** This ADR's header declared "Status: Accepted" but the repository contains no operator sign-off evidence (grep for sign-off/operator/accepted returned nothing; the file is untracked with no git history). The self-declared Accepted status is therefore not authoritative; this ADR is treated as **Proposed** until the operator signs off on ADR-2026-07-29-02. The original header text is preserved above unchanged. (2) **Partial supersession:** ADR-2026-07-29-02 establishes a layered doctrine stack in which the Product Constitution (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) sits above this ADR's wedge. The following clauses of this ADR are superseded where conflicting: the single decision question ("Does this directly help…") is replaced by the five-gate stack (Gates A–E); "policy comparison is outside" is narrowed (neutral owned-policy comparison IN, shopping comparison OUT); "single source of truth for actual insurance situation" is corrected to "source-verifiable workspace"; "not multi-tenant" is corrected to "consumer/household product, backend multi-user with principal isolation"; camera and demo rejections are reclassified as strategy decisions (not permanent principles); exact prices/limits and the "PPP-adjusted"/"RevenueCat median" claims are demoted to Proposed in the commercial layer. (3) **What remains valid:** the comprehension outcome, the coverage-summary-first hypothesis, the citation-moat, household organisation, factual reminders, and the onboarding-friction reframing all remain valid strategy and are preserved in the revised `FIRST_PRINCIPLES_WEDGE.md`. (4) **Status change:** self-declared Accepted → **Proposed** (pending operator sign-off on ADR-2026-07-29-02). | Operator direction: layered doctrine stack; discovery that no sign-off evidence exists for this ADR. See ADR-2026-07-29-02 §4.12 and §7. |

## Anything Else?

**Yes.** This ADR replaces no existing ADR. It sits *above* all feature-level ADRs as the framework they derive from:

- ADR-2026-07-19-08 (cut/keep/finish) implicitly used a wedge — now the wedge is explicit.
- ADR-2026-07-28 (reject demo mode) was a wedge decision — now the framework that produced it is documented.
- ADR-2026-07-19-13 (reject what-if premium) was a wedge decision — same.

Future ADRs should reference this one in their "Context" section when the decision framework is relevant. No need to re-derive the wedge in every ADR.
