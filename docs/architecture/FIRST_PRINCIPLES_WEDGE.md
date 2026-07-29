# First-Principles Product Wedge: CoverWise — Strategy & Current Wedge

> **Status:** Proposed — subordinate to the [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) per [ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
> **Layer:** Strategy and current wedge — sits beneath the constitution, above the commercial boundary.
> **Last updated:** 2026-07-29 (revised by ADR-2026-07-29-02; original 2026-07-28 text preserved below where not in conflict)
> **Source:** First-principles analysis from 2026-07-28 session, prompted by product audit covering 6-month Play Store post-mortem scenario. Corrected 2026-07-29 against the layered doctrine stack.
> **Evidence tier:** Decision-grade product reasoning informed by repository review; not yet validated by representative user research or production behaviour. (Tier 0 per [`docs/launch_claims/README.md`](../launch_claims/README.md).)

> ⚠️ **This document is subordinate to the [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md).** Where any clause here conflicts with the constitution or with [ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md), the higher layer governs. The clauses marked **[CORRECTED 2026-07-29]** below have been narrowed or replaced; their original text is preserved in the Update Log for history.

---

## 1. The Wedge

> **CoverWise is a private, source-verifiable personal insurance knowledge workspace.**
> Not a document reader. Not a generic AI chat. Not a shopping-comparison tool.
> A source-verifiable workspace for "what do my uploaded policies establish, what remains unknown, and where does each fact come from?"

### The Fundamental User Need

> *"I have insurance policies. I need to understand what they cover, when they expire, and what to do when something happens."*

The user's outcome is **comprehension**, not upload and not chat.
- Upload is **onboarding** — a means, not the end.
- Chat is an **interface** — one way to reach the outcome, not the outcome itself.
- The output that matters: the user understands the policies they have uploaded.

> **[CORRECTED 2026-07-29]** Earlier text called CoverWise "a single source of truth for what does my insurance actually cover." That overstated the product's knowledge: CoverWise knows only what the user has uploaded, processed, and verified. The source policies are authoritative; CoverWise is the source-verifiable workspace. See constitution §1 and ADR-2026-07-29-02 §4.2.

---

## 2. The Decision Framework — five gates (replaces the single question)

> **[CORRECTED 2026-07-29]** The earlier single question — "Does this directly help the user understand their insurance situation better?" — was useful but insufficient. It would reject necessary infrastructure (consent, deletion, observability) while potentially permitting advisory features that appear helpful. The [Product Constitution §3](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) now defines a five-gate stack (Gates A–E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Every feature must pass all applicable gates. The single question is retained below as Gate A's spirit only.

**Gate A — Outcome:** Does this materially reduce the effort, time, or uncertainty required to understand or organise user-owned insurance policies? (For infrastructure: is it necessary to deliver that outcome safely, privately, reliably, recoverably, or sustainably?)

**Gate B — Truth:** Can every material policy-specific statement be grounded in current owned-source evidence? Does it handle found · not found · unverified · incomplete · stale · conflicting · unsupported · abstained?

**Gate C — Product role:** Does the activity remain within explanation · evidence · organisation · retrieval · reminders · user-authored recordkeeping?

**Gate D — Lifecycle and operations:** Are principal, consent, access, retention, correction, export, replacement, deletion, failure, retry, idempotency, observability, operator recovery, and launch claims defined and enforceable?

**Gate E — Strategy and commercial fit:** Is the feature inside the current wedge? Is free/paid treatment separately decided without contradicting the constitution?

### Evidence Tier for This Framework

> **[CORRECTED 2026-07-29]** Decision-grade product reasoning informed by repository review; not yet validated by representative user research or production behaviour. Aligns with Tier 0 in [`docs/launch_claims/README.md`](../launch_claims/README.md). (Earlier text self-labelled this "Tier 4 (runtime/manual reasoning)" — that was incorrect; conceptual reasoning is not runtime evidence.)

---

## 3. What Follows From the Wedge

### 3.1 Proactive Beats Reactive

| Mode | Current App | First-Principles Version |
|------|-------------|-------------------------|
| **Reactive** (what exists) | Upload → wait → ask → get answer | |
| **Proactive** (what should exist) | Open app → see coverage, deadlines, gaps | Q&A becomes the fallback for edge cases, not the primary interface |

The dashboard already exists and shows expiry dates/policy status — this direction is correct. But it's still organized as if Q&A is primary (FAB is "Ask", first tab has minimal content, Q&A is a navigation away).

### 3.2 Upload Friction Is the Correct Problem — But Not for the Reason Previously Framed

The original product audit framed the friction as "the app is empty until upload" and recommended a demo policy. That framing was **wrong** — see §4 for why.

The correct framing: friction matters because **comprehension is blocked** until the user's real data is in the system. Every tap between "I want to understand my policy" and "I understand it" is a comprehension delay.

The solution is not fake data — it's **shortening the comprehension path**.

### 3.3 Coverage Summary Is Closer to the Wedge Than Q&A

`CoverageDetailsSummaryScreen` shows all extracted fields across all policy types. Q&A answers questions the summary doesn't cover. The first-principles ordering:

1. **Coverage overview first** — what you have, what it covers, what expires
2. **Q&A second** — for edge cases the overview doesn't address

The change "navigate to Q&A after upload" is correct directionally, but the coverage summary should be the actual destination.

### 3.4 What's Outside the Wedge (Cut / Don't Prioritize)

> **[CORRECTED 2026-07-29]** Two corrections from ADR-2026-07-29-02 §4.1 and §4.9/§4.10:
> - **Policy comparison is no longer wholly outside.** Neutral, source-cited, dimension-by-dimension comparison of policies the user **already owns** is **inside** the wedge (see §3.5). What remains outside is *shopping* comparison (which to buy, which is best, switching, ranking, adequacy).
> - **Demo policy and camera-first flow are reclassified as strategy decisions, not permanent principles.** They remain rejected for launch (see §4), but may be revisited through evidence.

These features were considered or suggested but fail the decision framework:

| Feature | Why It's Outside the Wedge |
|---------|---------------------------|
| **What-if calculator** | Speculative. Not grounded in actual coverage. Implies underwriting authority. User needs to know what they *have*, not what-if scenarios. (Constitutional — Gate C rejection; reaffirmed by ADR-2026-07-19-13.) |
| **Lead capture / "connect with an agent"** | Outside the personal-knowledge-base wedge. Implies brokering/referral. (Constitutional — Gate C.) |
| **Newsletter signup** | Outside the wedge. |
| **Shopping comparison across insurers** | "Which policy is best", "which insurer is better", "which to buy", "whether to switch/renew", value-for-money ranking, adequacy/suitability conclusions. (Constitutional — Gate C. See ADR-2026-07-29-02 §4.1.) |
| **Demo policy as default onboarding** | **Strategy decision (not permanent principle).** Rejected for launch per [ADR-2026-07-28-reject-demo-mode](../decisions/ADR-2026-07-28-reject-demo-mode.md); a clearly-labelled read-only marketing-site/onboarding-preview example remains an experiment, not a constitutional violation. See §4.1 and ADR-2026-07-29-02 §4.10. |
| **Camera-first as default flow** | **Strategy decision (not permanent principle).** Direct digital import is preferred; camera may remain an optional fallback for printed/inaccessible documents. See §4.2 and ADR-2026-07-29-02 §4.9. |

### 3.5 What's Inside the Wedge (Strengthen and Prioritize)

| Feature | Why It's Inside the Wedge |
|---------|--------------------------|
| **Upload → immediate coverage summary** | Shortest path to comprehension. The coverage summary (not Q&A) should be the post-upload destination. (Strategy hypothesis — see §3.3; validate via usability evidence.) |
| **Multi-policy aggregation** | Showing all coverages, expirations, and **coverage facts and verification prompts** in one view directly answers "what do I have?" |
| **Neutral owned-policy comparison** | **[CORRECTED 2026-07-29, now IN]** Source-cited, dimension-by-dimension comparison of policies the user already owns — no winner, no score, missing/conflicting shown honestly. See ADR-2026-07-29-02 §4.1. (Advanced comparison may be a paid candidate; shopping comparison remains out at any tier.) |
| **Coverage facts and verification prompts** | **[CORRECTED 2026-07-29]** Renamed from "proactive alerts". Evidence-state wording only — e.g., "Flood coverage was not found in the uploaded policy. This is not proof that it is excluded." Never "Your motor policy does not cover flood damage." See ADR-2026-07-29-02 §4.3. |
| **Family coverage organisation** | Already exists but buried. Organises members and cited policy relationships; does not declare household protection sufficiency. |
| **Honest evidence tiers / citation badges** | Already exists (fully_backed / partially_backed / abstained). This is the moat — "every answer cites its source." |

---

## 4. Strategy Decisions From Previous Analysis (reclassified 2026-07-29)

> **[CORRECTED 2026-07-29]** Both items below were previously framed as permanent first-principles rejections. Per ADR-2026-07-29-02 §4.9 and §4.10, they are **strategy decisions**: rejected for launch, but revisitable through evidence. They are not constitutional bans.

### 4.1 Demo Policy: Rejected for launch (strategy decision)

The original product audit recommended adding a "sample policy" for instant value. This was **wrong for launch** for two reasons:

1. **Fails the decision framework:** Fake data does not help the user understand *their* insurance situation. It delays real comprehension.
2. **Teaches wrong behavior:** Users who interact with a demo policy learn to explore fake data, not their own coverage. The mental model becomes "this app shows example info" not "this app shows MY info."

**The correct first-principles fix for launch:** Shorten the real-data comprehension path instead of creating fake-data shortcuts. Navigation optimization (fewer taps to Q&A/summary after upload) is the right solution.

**Revisit path (per ADR-2026-07-29-02 §4.10):** A clearly-labelled, read-only example on the marketing site or onboarding preview remains an experiment, not a constitutional violation. Any such example must be isolated from real user data and must not create fake citations, persistence, analytics, or ownership state. The launch rejection stands until evidence supports revisiting.

### 4.2 Camera-First Flow: Not the default (strategy decision)

The original audit suggested camera capture for printed policies. Direct digital import is preferred because:
- Most policies arrive as digital documents (email, portal downloads, messaging apps)
- Camera capture introduces OCR quality degradation vs direct file processing
- Camera flow adds friction (find policy → photograph → crop → confirm) that a direct import does not

**The correct strategy (per ADR-2026-07-29-02 §4.9):** Direct digital-document import is the preferred path. Camera capture is **not the default** but may remain an **optional fallback** for printed or otherwise inaccessible documents. Share sheet, file picker, email forwarding, insurer-portal import, and WhatsApp-related flows require actual user evidence before priority claims are made. Do not state that most Indian policies arrive through one channel unless supported by evidence.

---

## 5. Monetization Framework — durable principle only; exact limits/prices live in the commercial layer

> **[CORRECTED 2026-07-29]** Per ADR-2026-07-29-02 §4.6 and §4.7, this document no longer carries exact prices, exact tier limits, or the "PPP-adjusted" / "RevenueCat 2026 India median ₹300-315" claims. Those lacked sourcing and treated experiments as settled doctrine. The durable principle is retained here; all concrete limits and prices move to the commercial layer ([`FREE_VS_PAID_BOUNDARY.md`](./FREE_VS_PAID_BOUNDARY.md)) as **Proposed** until operator approval with unit economics and sourced benchmarks.

### Durable commercial principle (from the constitution)

> A user must receive enough source-verifiable comprehension to understand the product's value without paying. Paid tiers may charge for higher usage, capacity, convenience, household collaboration, storage, processing priority and advanced workflows. Essential safety information and the truth of an already processed policy must not become inaccessible solely because a subscription expires.

### The three value categories (spirit retained; concrete gates decided commercially)

| Category | Definition | Examples | Treatment |
|----------|------------|----------|-----------|
| **🧠 Comprehension** | Directly answers "what do my uploaded policies establish?" | Upload (≥1 policy), coverage summary, grounded Q&A, citation badges, essential emergency facts, source-page inspection | **Free baseline** (constitutional floor) |
| **⚡ Convenience** | Makes comprehension faster/easier; does not add understanding | Export, cloud sync, priority processing | **Paid candidate** |
| **🔬 Depth** | Adds organisation/analysis beyond single-policy comprehension | Advanced owned-policy comparison, family matrix, annual review | **Paid candidate** |

### Open commercial questions (decided in the commercial layer, not here)

The commercial layer must resolve, as Proposed until operator approval: free policy capacity · free Q&A allowance · emergency access classification · comparison treatment (basic free vs advanced paid) · family matrix vs family sharing · export · sync · priority processing · Q&A packs · restore/refund/entitlement recovery.

### Detailed per-feature classification

See [`FREE_VS_PAID_BOUNDARY.md`](./FREE_VS_PAID_BOUNDARY.md) for the per-feature analysis with gate questions, current-state alignment checks, and principle resolutions. All exact prices and limits there are **Proposed** pending operator approval and sourced evidence.

---

## 5.1 Product posture — consumer/household, not "not multi-tenant"

> **[CORRECTED 2026-07-29, added]** An earlier framing ("not multi-tenant") is removed from product doctrine per ADR-2026-07-29-02 §4.8. Use instead:
>
> > CoverWise is a consumer and household product, not a broker, employer, insurer or enterprise workspace. Its backend remains multi-user with strict principal isolation.
>
> The backend has always been multi-user (many principals, isolated workspaces). "Not multi-tenant" conflated product posture with infrastructure topology and could mislead future agents into thinking the backend is single-user.

---

## 6. Cut/Keep/Finish Summary

| Feature | Verdict | Rationale |
|---------|---------|-----------|
| Upload → Q&A flow | Keep, optimize | Correct direction; coverage summary should be destination |
| Coverage summary | Keep, strengthen | Closest to the wedge of any screen |
| Q&A interface | Keep, de-emphasize | Primary interface → fallback for edge cases |
| Citation badges | Keep, strengthen | The moat — differentiate from hallucination-prone AI |
| Multi-policy dashboard | Keep, strengthen | Answers "what do I have?" |
| Family coverage matrix | Keep, surface | Answers "does my family have X?" |
| Proactive gap alerts | **[RENAMED 2026-07-29]** "Coverage facts and verification prompts" — Keep, build | Evidence-state wording only; never "not covered" from absence. See ADR-2026-07-29-02 §4.3. |
| Renewal reminders | Keep, strengthen | Factual dates + reminders only; no "Start renewal" transaction. Already built. |
| **Neutral owned-policy comparison** | **[CHANGED 2026-07-29]** Keep (was Cut) | Source-cited, dimension-by-dimension, no winner. See ADR-2026-07-29-02 §4.1. |
| Demo policy | **[RECLASSIFIED 2026-07-29]** Cut for launch (strategy, not principle) | Revisit via evidence; see §4.1 and ADR-2026-07-29-02 §4.10. |
| Camera-first upload | **[RECLASSIFIED 2026-07-29]** Not the default (strategy, not principle) | Optional fallback allowed; see §4.2 and ADR-2026-07-29-02 §4.9. |
| What-if calculator | Cut | Speculative, not grounded in actual coverage. (Constitutional — Gate C.) |
| Lead capture / agent connect | Cut | Outside wedge; implies brokering. (Constitutional — Gate C.) |
| Newsletter signup | Cut | Outside wedge. |
| Cross-insurer **shopping** comparison | Cut | Which to buy/best/switch/renew/rank. (Constitutional — Gate C. Note: neutral owned-policy comparison is IN, see row above.) |

---

## 7. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-28 | Initial document created from first-principles analysis | motto_v4 §0.3.1 mandate: analysis from product audit session was only in chat; documented per "Everything Is a Documentation Candidate" rule |
| 2026-07-28 | Added §4 (Corrected Errors) documenting why demo policy and camera-first were wrong recommendations from the original audit | Self-correction during documentation — the original audit recommendations conflicted with the wedge; the wedge takes priority over the audit |
| 2026-07-29 | **Major revision per ADR-2026-07-29-02.** Document demoted to subordinate strategy layer beneath the Product Constitution. Eight clauses corrected (all marked `[CORRECTED 2026-07-29]` inline, original text preserved in spirit): (1) "single source of truth" → "source-verifiable workspace"; (2) single decision question → five-gate stack (Gate A–E); (3) evidence tier "Tier 4 runtime" → Tier 0 decision-grade reasoning; (4) policy comparison OUT → narrowed IN (neutral owned-policy comparison IN, shopping comparison OUT); (5) "proactive gap alerts" → "coverage facts and verification prompts" with evidence-state wording; (6) demo/camera reclassified from permanent principles to strategy decisions; (7) "not multi-tenant" → "consumer/household product, backend multi-user with principal isolation"; (8) exact prices/limits/PPP-claims removed, demoted to commercial layer as Proposed. Status changed from self-declared "Accepted" to Proposed (no sign-off evidence found — see ADR-2026-07-29-02 §4.12). | Operator direction: layered doctrine stack with constitution on top; ADR-2026-07-29-02 reconciliation. |

---

## 8. Anything else?

Yes. This document is now explicitly subordinate to the [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md). A future agent reading only this file must also read the constitution and [ADR-2026-07-29-02](../decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md); this file alone is not sufficient to make product-boundary decisions because the five gates (especially Gates B, C, D) live in the constitution. The corrections above are narrowing corrections, not rejections of the original analysis — the comprehension outcome, onboarding-friction reframing, and coverage-summary-first hypothesis all remain valid strategy.
