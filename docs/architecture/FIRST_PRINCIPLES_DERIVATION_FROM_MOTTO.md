# First-Principles Derivation: From motto_v4 to CoverWise Product Decisions

> **Status:** Accepted (2026-07-29)
> **Source:** motto_v4 §0, §0.0.1, §0.3.1, §0.12.4, §11, §21 analysis
> **Relation:** Sits alongside the [Product Wedge](FIRST_PRINCIPLES_WEDGE.md) as the meta-framework — *how* to derive first-principles decisions, not the decisions themselves.
> **Evidence tier:** Decision-grade product reasoning (Tier 0)

---

## 1. What "First-Principles" Means (from the Motto)

motto_v4 §11 says: *"Think from first principles. Focus on root-cause analysis, not surface-level fixes."*

§0 says: *"Build for the **best app**, not the safest small change. Prefer bold, durable, first-principles solutions over narrow patchwork."*

§0.0.1 says: *"Do the whole right answer, not the small sprint."*

§21 says: *"Existing code is evidence of an earlier stage or an earlier decision, not a constraint on what is possible or correct."*

**Synthesis:** First-principles means starting from first causes (the irreducible truths about the user, the problem, and the delivery channel), deriving the architecture from those causes, then letting code follow the derivation — not the other way around. Existing code is never a constraint on what is correct.

---

## 2. The Four First Causes for CoverWise

### First Cause #1: The user has insurance policies and needs to understand what they cover.

**Root:** This is the only reason the app exists. Not upload. Not chat. Not Q&A. The outcome is comprehension — the user walks away understanding their insurance situation.

**Consequences that follow:**
- The coverage summary is the primary output, not Q&A
- Every tap between "I want to understand" and "I understand" is friction
- The free tier must include full comprehension of at least one policy
- Gating comprehension itself (summary, citation badges, ability to ask basic questions) would violate the root cause

### First Cause #2: Policies arrive as PDFs via email, insurer portals, or WhatsApp.

**Root:** This is the actual delivery channel for insurance policies in India. Not printed paper handed to the user.

**Consequences that follow:**
- The import path must match the actual delivery channel: share sheet, file picker, email forwarding
- Camera-first upload as a default flow was correctly rejected — it doesn't match how policies arrive
- Camera capture may remain an optional fallback for printed/inaccessible documents, but it is never the primary path

### First Cause #3: Comprehension is a one-time need per policy, but insurance is recurring (renewals, claims, life changes).

**Root:** The user needs the app once to understand a new policy, then again at renewal, then again at claim time. These are the only moments of need. The app cannot rely on daily engagement models.

**Consequences that follow:**
- The app must earn re-engagement at key moments (renewal, claim, life event)
- Proactive gap alerts, renewal reminders, and claim-time assistance are not "growth hacks" — they are structural consequences of the use case
- Monetization cannot rely on high-frequency engagement
- "Retention" means "useful at the moments that matter," not "daily active users"

### First Cause #4: The user trusts the app with sensitive personal data (policy numbers, sum insured, family member details, medical history).

**Root:** Insurance data is among the most sensitive personal information a user shares. Policy numbers, sum insured amounts, nominee details, medical history — all of it goes into the app. Trust is the binding constraint, not a feature.

**Consequences that follow:**
- Citation verification badges are not optional UI — they are the minimum viable trust mechanism
- The "not an insurer, broker, or adviser" disclaimer is not legal boilerplate — it is a trust boundary
- Every answer must show its source. This is not a premium feature
- Without trust mechanisms, the app cannot exist regardless of feature quality
- Analytics events must never leak policy content or PII

---

## 3. Applying motto_v4 Clauses to These Causes

### §0.0.1 — Whole-Answer Mandate

Applied: When fixing onboarding, don't reduce 3 pages to 1 page as a cosmetic change. Fix the root cause: the user should see their coverage immediately, not navigate through screens. The whole answer is: upload → coverage summary → done. Not: upload → loading → Q&A → question → answer.

**Test:** Does the implementation shorten the comprehension path, or does it just make the existing path slightly faster?

### §0.3.1 — Everything Is a Documentation Candidate

Applied: Every analysis, decision, redirect, and audit must go to a durable doc, not stay in chat. This includes:
- The first-principles wedge analysis (→ `FIRST_PRINCIPLES_WEDGE.md`)
- The free vs paid boundary (→ `FREE_VS_PAID_BOUNDARY.md`)
- The motto-to-product derivation (→ this document)
- Onboarding redesign analysis
- Dashboard redesign analysis
- Any product audit, competitor analysis, or strategic assessment

**Test:** If this conversation vanished, could the next agent reconstruct why decisions were made?

### §0.12.4 — Cut/Keep/Finish Anchored to Long-Term Shape

Applied: Features that belong in the long-term wedge are finished properly even when expensive. Features outside the wedge are cut, not deferred. Features that are honest thin slices of the wedge are scoped down to the honest minimum.

**Decision procedure:**
1. Does the feature pass the decision gate? ("Does this directly help the user understand their insurance situation better?")
2. If yes → it's in the wedge. Finish it properly. Do the whole answer.
3. If no → cut it. Don't defer it. Don't deprioritize it. Cut it.
4. If maybe → it's a strategy decision. Decide explicitly for launch, document the reopen conditions.

### §21 — Code Is Evidence, Not a Boundary

Applied: Existing navigation routes to Q&A after upload? That's evidence of an earlier decision. If the first-principles derivation says coverage summary should be the destination, refactor the navigation regardless of how much code already routes to Q&A.

**Decision procedure:**
1. Identify the old decision encoded in the current code
2. Compare against the current first-principles derivation
3. If they conflict, the code must be refactored — this is part of the work, not deferred debt

### §0.5 — Evidence Tiers

Applied: All first-principles derivations in this document are Tier 0 (decision-grade product reasoning). They are not validated against real user behavior. Every claim about user needs must be treated as a hypothesis until validated.

**What this means in practice:**
- "Upload friction matters because comprehension is blocked" — Tier 0 hypothesis, not proven
- "Most policies arrive as PDFs via email" — Tier 0 assumption, not validated against real user data
- "The coverage summary should be the post-upload destination" — Tier 0 hypothesis to be tested
- "Citation badges build trust" — Tier 0 product reasoning, not validated

---

## 4. The Decision Framework

From motto_v4 §11 ("Think from first principles") applied to the four first causes:

**The gate question for every feature, screen, prompt, and marketing claim:**

> *"Does this directly help the user understand their insurance situation better?"*

If no → cut it.
If yes → do the whole answer (not the smallest patch), document the decision, refactor the old code (rule 21), test the new behavior, wire observability (rule 0.10).

### Four supplementary questions (for edge cases):

1. **Infrastructure/ops:** "Is this necessary to deliver comprehension safely, privately, reliably, or sustainably?" (passes gate for consent, deletion, analytics, error tracking)
2. **Trust mechanism:** "Does this make the user more or less confident that their data is handled correctly?" (passes gate for citation badges, privacy policy, data deletion)
3. **Monetization boundary:** "If I gate this, does the user lose access to understanding their own policy?" (if yes → free; if no → paid candidate)
4. **Strategy vs principle:** "Is this rejection permanent, or could evidence change it?" (if evidence could change it → it's a strategy decision with reopen conditions)

---

## 5. What Gets Built, What Gets Cut

### Inside the wedge (per the four first causes)

- Upload → immediate coverage summary
- Multi-policy dashboard showing coverages, expirations, gaps
- Proactive coverage facts and verification prompts (evidence-state wording only)
- Citation verification badges on every answer
- Type-specific extraction (motor VIN, health room rent cap, travel destination, etc.)
- Renewal reminders + claim support
- Multi-language support (Hindi, Gujarati, Marathi)
- Neutral owned-policy comparison (dimension-by-dimension, no winner)

### Outside the wedge (cuts from first causes, not from convenience)

- Demo/bootstrap policy as default onboarding (fake data doesn't help comprehension of *your* situation)
- What-if calculator (speculative, not grounded in actual coverage)
- Shopping comparison across insurers (implies recommendation — outside knowledge-base boundary)
- Lead capture / "connect with an agent" (implies brokering)
- Insurance literacy quizzes (education ≠ comprehension of *your* policy)

### Paid candidates (comprehension is free; convenience and depth are paid)

- Export/share (convenience — info is already on screen)
- Cloud sync (convenience — single-device comprehension is full comprehension)
- Policy comparison across your own policies (depth analysis)
- Family cross-policy matrix (depth aggregation)
- Annual review report (depth analysis)

---

## 6. How This Document Is Used

Before any feature, screen, prompt, or marketing claim, run this checklist:

1. **Identify the first cause** — which of the four irreducible truths does this serve?
2. **Apply the gate question** — does it directly help the user understand their insurance situation?
3. **Check motto clause compliance:**
   - §0: Is this the best app solution or the safest patch?
   - §0.0.1: Am I doing the whole answer or cutting scope?
   - §0.3.1: Is this decision documented?
   - §0.12.4: Does this belong in the long-term wedge?
   - §21: Am I treating old code as a constraint?
   - §0.5: What evidence tier supports this claim?
4. **Classify the outcome:** build (inside wedge) / cut (outside wedge) / paid (convenience/depth) / strategy (evidence-dependent)

---

## 7. Update Log

| Date | Change | Trigger |
|------|--------|---------|
| 2026-07-29 | Initial document — derived from motto_v4 clauses applied to CoverWise's four first causes | Operator correction: first-principles analysis was given in chat but not documented per §0.3.1 |

---

## 8. Anything Else?

**Yes.** This document exists because I gave a detailed first-principles analysis in chat and the operator correctly called out that it was undocumented. That itself is evidence that §0.3.1 is a learned behavior, not a natural one. Every agent must internalize: chat is ephemeral; the repo is durable. An analysis that informs product direction for weeks must not live in a conversation that vanishes at session end.
