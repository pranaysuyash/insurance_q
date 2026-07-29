# ADR-2026-07-29-02: Doctrine Stack Reconciliation — Constitution, Wedge, and Commercial Boundary

**Status:** Proposed, awaiting operator sign-off
**Date:** 2026-07-29
**Updated:** 2026-07-29 (initial)
**Governing doctrine:** [`motto_v4.md`](../../motto_v4.md)
**Prepared against:** `main` at `755df24be171b87fc1d5f66eceb25d3909d2784d` (working tree includes the uncommitted doctrine files named below)
**Owner / next reviewer:** Pranay

> This ADR remains **Proposed** until the operator reviews its final text and signs off.
> It does not authorize code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding changes.
> Per operator direction, sign-off is required on this exact ADR before any implementation inventory is produced.

---

## 0. Why this ADR exists

The repository currently holds **two uncommitted first-principles documents that do not cite each other and that conflict on at least one material surface** (policy comparison), plus a third tracked UX first-principles audit (2026-07-23) whose recommendations have since been rejected. A commercial-boundary draft (`FREE_VS_PAID_BOUNDARY.md`) carries exact prices and limits that no operator has approved. One ADR (`ADR-2026-07-29-01`) self-declares "Accepted" but contains **no operator sign-off evidence** in the repository and is not tracked by git. Another (`ADR-2026-07-28-03`, currently in `coverwise_product_first_principles_bundle/`) is Proposed.

Without one governing hierarchy, the next agent can cite any of these to justify opposite conclusions. This ADR exists to:

1. establish **one layered doctrine hierarchy** with explicit precedence;
2. adopt **one canonical product statement**;
3. replace the Wedge's single decision question with a **five-gate stack** that does not reject necessary infrastructure or permit advisory features;
4. resolve **thirteen material conflicts** with final rules;
5. record exactly which clauses of earlier documents are preserved, narrowed, superseded, or demoted to a lower layer — **without rewriting any history**;
6. require operator sign-off on this ADR before any boundary-shaped code changes.

---

## 1. Local doctrine inventory

| File | Local state | Declared status | Sign-off evidence? | Conflicts | Required treatment |
| ---- | ----------- | --------------- | ------------------ | --------- | ------------------ |
| `coverwise_product_first_principles_bundle/PRODUCT_FIRST_PRINCIPLES.md` | Untracked | Proposed (via ADR-03 in same bundle) | No | Boundary test is strong; lacks comprehension framing, 5 gates, comparison-IN | Move to `docs/planning/product/`; revise into constitution per §5 |
| `coverwise_product_first_principles_bundle/ADR-2026-07-28-03-product-first-principles-and-boundary.md` | Untracked | Proposed | No | Older ADR set; unaware of Wedge | Keep as historical proposal; supersede conflicting clauses via this ADR's update-log append |
| `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` | Untracked | "Accepted (2026-07-28)" self-declared | **No** | Comparison=OUT (conflicts with Principles); "actual situation"; "not multi-tenant"; camera/demo absolutes; exact pricing; evidence-tier misuse | Revise into subordinate strategy; append correction; correct clauses per §4 |
| `docs/architecture/FREE_VS_PAID_BOUNDARY.md` | Untracked | "Draft" self-declared | No | Exact prices (₹149/₹999/₹249/₹1,799) as settled doctrine; comparison simultaneously OUT and paid; emergency free and paid; "PPP-adjusted" w/o method | Revise into commercial/experiment layer; demote all exact limits/prices to Proposed |
| `docs/decisions/ADR-2026-07-29-01-first-principles-product-wedge.md` | Untracked (no git history) | "Accepted" self-declared | **No — grep for sign-off/operator/accepted returned no evidence; untracked** | Same conflicts as Wedge (it formalizes the Wedge) | Append correction noting no sign-off evidence found; supersede in part by this ADR; status treated as Proposed until operator sign-off on this ADR |
| `docs/decisions/ADR-2026-07-28-reject-demo-mode.md` | Untracked | "Accepted" self-declared | No explicit sign-off text | Camera-to-answer later removed by founder challenge (per its own update log); demo rejection stands | Append: reclassify camera as strategy (not permanent principle); demo stays rejected for launch but is a revisitable strategy decision |
| `docs/decisions/ADR-2026-07-19-08-cut-keep-finish-half-built-features.md` | Tracked (committed) | Accepted rev 2 | Yes (per its text) | Widened wedge items (Coverage Check-in, Adequacy, Family, Claim Vault, partnerships) treated as keep/finish | Append: widened wedge remains an exploration inventory; product inclusion requires passing the gate stack in this ADR |
| `docs/decisions/ADR-2026-07-19-13-what-if-premium-refused-as-product-capability.md` | Tracked | Accepted rev 1 | Yes | Explores partner/insurer quote paths | Append: no-fabricated-premium stands; partner quote path not authorized for launch by this ADR |
| `docs/decisions/ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md` | Tracked | Accepted | Yes | Claim-assistance thin slice | Append: claim-assistance must be reframed per §4.4 (process/contacts only, not consultancy) |
| `docs/decisions/ADR-2026-07-23-01-evidence-backed-policy-readiness.md` | Tracked | Accepted for staged impl | Yes | Neutral readiness — aligned with constitution | Append: aligned; reaffirmed by this ADR |
| `docs/decisions/ADR-2026-07-24-02-personal-claim-log-boundary.md` | Tracked | Accepted | Yes | Personal claim log — aligned | Append: reaffirmed; status semantics must remain `Recorded as ...` |
| `docs/review/product_audit_6month.md` | Untracked | Analysis | n/a | Recommends camera-first, demo policy, literacy feed — all rejected | Add dated supersession addendum (Phase 7) |
| `UX_AUDIT_FIRST_PRINCIPLES.md` (repo root, tracked) | Tracked | Analysis dated 2026-07-23 | n/a | Recommends demo policy, camera-first, what-if calculator, advisor marketplace, claim assistant — all rejected | Add dated supersession addendum (Phase 7) |
| `docs/review/exploration_map.md` | Tracked | Living | n/a | Line 311 lists `what_if_calculator_screen.dart` for removal; line 312 renewal "Start renewal" → neutral; line 328 describes comparison pipeline as in-product | Append addendum pointing to this ADR as governing |

**ADR ID confirmation:** `ADR-2026-07-29-02` is free across the entire repository (grep returned no references). `ADR-2026-07-28-03` exists only inside the uncommitted bundle, not in `docs/decisions/`.

---

## 2. Decision

Adopt a **layered doctrine stack** with this precedence (top wins conflicts):

```text
motto_v4.md                                  (operating rules; always top)
  └─ Product constitution                    (PRODUCT_FIRST_PRINCIPLES.md)
      └─ First-principles wedge & strategy   (FIRST_PRINCIPLES_WEDGE.md)
          └─ Free vs paid commercial boundary (FREE_VS_PAID_BOUNDARY.md)
              └─ Feature ADRs                (docs/decisions/ADR-*)
                  └─ Architecture, code, tests, ops, launch claims
```

A lower layer may not contradict a higher layer. Where a lower layer currently does, the higher layer governs and the lower layer is corrected by dated addendum (Phase 5/6).

### Canonical product statement (adopted verbatim from operator direction)

> CoverWise is a private, source-verifiable personal insurance knowledge workspace that helps people understand and organise policies they already own. It reports what the uploaded policy workspace establishes, what it does not establish, and where each material fact comes from. It does not recommend, quote, underwrite, broker, transact, or represent claims.

Important distinctions:

- The insurance policy is the authoritative source.
- CoverWise is the interpretation and organisation workspace, not the legal source of truth.
- CoverWise knows only what the user has uploaded, what was successfully processed, and what remains current and verifiable.
- Missing information must remain missing or unknown. It must not become a negative conclusion.

---

## 3. The decision-gate stack (replaces the Wedge's single question)

The Wedge's single question — "Does this directly help the user understand their insurance situation better?" — is useful but insufficient. It would reject necessary infrastructure (consent, deletion, observability) while potentially permitting advisory features that appear helpful. Every feature and engineering decision must pass **all applicable gates**.

### Gate A — Outcome

Does this materially reduce the effort, time, or uncertainty required to understand or organise user-owned insurance policies?

For infrastructure, ask: is this necessary to deliver that outcome **safely, privately, reliably, recoverably, or sustainably**?

### Gate B — Truth

Can every material policy-specific statement be grounded in **current owned-source evidence**?

Does the feature explicitly handle: found · not found · unverified · incomplete · stale · conflicting · unsupported · abstained?

**Hard rule:** "not found in the uploaded policy" must never silently become "not covered." Absence of extraction is not absence of coverage.

### Gate C — Product role

Does the activity remain within: **explanation · evidence · organisation · retrieval · reminders · user-authored recordkeeping**?

Reject by default when the activity becomes: recommendation · suitability or adequacy judgement · premium quoting or underwriting · insurer or product ranking · purchase, switching, or renewal facilitation · claim filing, representation, adjudication, or insurer-status assertion · sensitive-data-driven lead generation.

### Gate D — Lifecycle and operations

Are these defined and enforceable: canonical principal · consent and purpose · access · retention · correction · export · replacement · deletion · failure · retry · idempotency · observability · operator recovery · public launch claims?

### Gate E — Strategy and commercial fit

Is the feature inside the current wedge? Is the free or paid treatment **separately decided** without contradicting the product constitution?

---

## 4. Conflict resolutions (thirteen final rules)

Each rule below governs. Lower-layer documents are corrected by addendum to match.

### 4.1 Policy comparison — **IN (narrowed), with a hard boundary**

**Inside the product:** neutral, factual, source-cited, dimension-by-dimension comparison of policies the user already owns and has uploaded. Requirements: no overall winner, no suitability score, missing/conflicting fields shown honestly, no purchase/switch/cancel/renewal recommendation.

Allowed example:

> Policy A states a ₹5 lakh sum insured. Policy B states ₹10 lakh. A room-rent cap was verified in Policy A. No equivalent clause was verified in Policy B.

**Outside the product:** which policy is best · which insurer is better · which policy to buy · whether to switch · whether to renew · value-for-money ranking · adequacy or suitability conclusions.

**Wording correction (Wedge §3.4):** change "policy comparison is outside" to:

> Purchase, switching, ranking, suitability, and recommendation comparison are outside. Neutral source-cited comparison of policies already owned is inside.

**Commercial correction:** "comparison" may not simultaneously be outside the product boundary and sold in a paid tier. Advanced owned-policy factual comparison may be a paid candidate (§4.6); shopping comparison is not in the product at any tier.

### 4.2 "Actual insurance situation" and "single source of truth"

Remove language implying CoverWise knows the user's complete real-world insurance position.

Use: *"What do the uploaded policies establish, what remains unknown, and where does each fact come from?"*

Do **not** use: *"CoverWise is the source of truth for the user's actual insurance situation."*

The source policies are authoritative. CoverWise is the source-verifiable workspace.

### 4.3 Coverage gaps and proactive alerts

Absence from extracted data must never become "not covered."

Replace negative-conclusion examples (e.g., "Your motor policy does not cover flood damage.") with **evidence-state wording**:

- "The uploaded policy contains a flood-damage exclusion on page 14."
- "Flood damage is listed under covered perils on page 9."
- "Flood coverage was not found in the uploaded policy. This is not proof that it is excluded."
- "Flood coverage could not be verified because processing is incomplete."
- "The uploaded documents contain conflicting flood-coverage wording."

Rename generic "gap alerts" to **"Coverage facts and verification prompts"** unless a separate evidence-safe gap definition is approved by its own ADR.

### 4.4 Claims and escalation

**Inside:** policy-stated claim process (with citations) · insurer contacts found in the policy or a clearly-sourced reference dataset · user-authored claim records, documents, notes, dates, reference numbers · neutral document checklist only when explicitly grounded in the user's policy · static external public-resource links in Help, clearly labelled external.

**Outside by default:** guided claim filing · personalised incident advice · claim-denial strategy · personalised IRDAI/Ombudsman escalation workflow · claim representation · insurer-status assertions · adjudication · negotiation · filing on the user's behalf.

"What to do when something happens" means: **find the policy-stated process, evidence and contacts**. It must not mean CoverWise directs or manages the claim.

Reconciles with `ADR-2026-07-19-04` (claim-assistance thin slice) and `ADR-2026-07-24-02` (personal claim log).

### 4.5 Renewal

**Inside:** expiry dates · factual reminders · source policy · read-only insurer contact information · questions the user may choose to ask.

**Outside:** "Start renewal" · "Renew now" · recommended renewal · switching · transaction initiation or facilitation.

### 4.6 Free and paid boundaries — durable principle only; exact limits demoted

The product constitution does not decide exact limits or prices. The durable commercial principle is:

> A user must receive enough source-verifiable comprehension to understand the product's value without paying. Paid tiers may charge for higher usage, capacity, convenience, household collaboration, storage, processing priority and advanced workflows. Essential safety information and the truth of an already processed policy must not become inaccessible solely because a subscription expires.

**Free baseline (constitutional floor):** verified summary and citations for at least one policy · limited grounded Q&A · essential emergency facts from already-processed policies · source-page inspection · honest unknown/abstention states.

**Paid candidates (commercial layer decides):** increased policy capacity · higher Q&A allowance · exports · cloud sync · household sharing and collaboration · priority processing · advanced owned-policy factual comparison · annual workspace review · expanded history and organisation.

The commercial document must resolve (as Proposed until operator approval): free policy capacity · free Q&A allowance · emergency access classification · comparison treatment · family matrix vs family sharing · export · sync · priority processing · Q&A packs · restore/refund/entitlement recovery.

### 4.7 Pricing evidence

Audit every pricing benchmark and source. Do not retain unsourced claims (e.g., "RevenueCat 2026 India median monthly price is ₹300–315") unless the exact source supports that geography, store, category, currency and number. Do not call prices "PPP-adjusted" without an actual PPP method.

For each price, record: source URL/durable citation · source date · geography · store · app category · original currency · exchange/PPP methodology · whether it is a market fact or an internal hypothesis. Treat all exact prices as **experiments** until supported by unit economics and user evidence.

### 4.8 "Not multi-tenant" — corrected

Remove this phrase from product doctrine. Replace with:

> CoverWise is a consumer and household product, not a broker, employer, insurer or enterprise workspace. Its backend remains multi-user with strict principal isolation.

### 4.9 Camera import — strategy, not permanent principle

Direct digital-document import is the preferred path. Camera capture is not the default. Camera capture may remain an **optional fallback** for printed or otherwise inaccessible documents. Direct PDF/image files should preserve better source quality where available. Share sheet, file picker, email forwarding, insurer-portal import, and WhatsApp-related flows require **actual user evidence** before priority claims are made.

Do not state that most Indian policies arrive through one channel unless that is supported by evidence.

### 4.10 Demo or sample policy — strategy, not permanent principle

Do not create fake policy data inside the user's real workspace. Strategy:

- No demo workspace as the default onboarding solution.
- A clearly labelled, read-only example on the marketing site or onboarding preview remains an **experiment**, not a constitutional violation.
- Any example must be isolated from real user data and must not create fake citations, persistence, analytics, or ownership state.
- Retain the current rejection for launch (per `ADR-2026-07-28-reject-demo-mode`), but classify it as a strategy decision revisitable through evidence.

### 4.11 Coverage summary first — strategy hypothesis, not universal proof

Preserve as a strategy hypothesis: the user should not need to know the correct question before getting value; after successful processing, the default useful destination should generally be a verified overview; Q&A handles edge cases and user-specific intent. Exact navigation and prominence must be validated through usability and product evidence. Do not describe this as universally proven.

### 4.12 Accepted status — sign-off evidence required

`ADR-2026-07-29-01` self-declares "Accepted" but the repository contains **no operator sign-off evidence** (grep for sign-off/operator/accepted in the file returned nothing; the file is untracked with no git history). Per operator direction:

- Do not silently rewrite the original status.
- Append a correction explaining that acceptance evidence was not found.
- Treat this reconciliation ADR as Proposed until the operator signs off.

Same treatment applies to any commercial or demo ADR lacking sign-off evidence.

### 4.13 Evidence tier — do not mislabel conceptual reasoning

Do not call conceptual product reasoning runtime evidence. Use:

> Decision-grade product reasoning informed by repository review; not yet validated by representative user research or production behaviour.

This aligns with the repository's canonical evidence tiers in `docs/launch_claims/README.md` (Tier 0 = no evidence / not implemented). The Wedge's current "Tier 4 (runtime/manual reasoning)" self-label for its framework is incorrect and is corrected in Phase 5b.

---

## 5. Options considered

| Option | Description | Verdict |
|--------|-------------|---------|
| **A: Pick one document, demote the other** | Commit either Principles or Wedge as sole canonical; trim the other to align | Rejected. Each document owns material the other lacks (Principles: trust/lifecycle/consent/launch-claims; Wedge: comprehension outcome, onboarding-friction reframing, concrete tier table). Picking one loses useful doctrine. |
| **B: Keep both as peers** | Commit both unchanged; let context decide | Rejected. They conflict on comparison, "actual situation", camera/demo absolutes, and pricing. Peer status preserves the conflict the doctrine exists to prevent. |
| **C: Layered stack with one reconciliation ADR (CHOSEN)** | Constitution on top, Wedge as strategy, Commercial as separate layer; this ADR resolves conflicts and sets precedence | **Chosen.** One hierarchy, no history rewritten, every conflict has a final rule, lower layers corrected by addendum. |
| **D: Merge into one mega-document** | Collapse all three into a single file | Rejected. Creates a sprawling doc that no one reads; loses the strategy/commercial separation the operator explicitly required. |

---

## 6. Chosen path

Option C. Execute in this order (all gated on operator sign-off of this ADR):

1. **Sign-off gate (this ADR).** No code changes until accepted.
2. **Phase 5:** Revise the three doctrine files to match this ADR (constitution gains comprehension + 5 gates + comparison-IN; Wedge corrected on 8 clauses; Commercial demotes prices to Proposed).
3. **Phase 6:** Append-only update-log entries to every affected ADR.
4. **Phase 7:** Dated supersession addenda to stale analyses.
5. **Phase 8:** Doctrine index + canonical cross-links.
6. **Post-sign-off, separate task:** Implementation inventory of every reachable surface classified against the gate stack. Only then may boundary-shaped code change.

---

## 7. Supersession and preservation map

### Preserved and strengthened (unchanged in substance)

- `ADR-2026-07-19-09`: four-face evidence-backed contract.
- `ADR-2026-07-19-10`: outbox-only durable work.
- `ADR-2026-07-19-11`: substrate as primary deliverable; `source_text` vs `retrieval_text` separation.
- `ADR-2026-07-19-12`: operator trust model.
- `ADR-2026-07-23-01`: neutral evidence-backed policy readiness.
- `ADR-2026-07-24-02`: personal claim log, not insurer workflow.
- Principal ownership, consent, privacy, deletion, evidence, and launch-claim contracts.

### Superseded where conflicting (append-only; originals preserved)

| Source | Clause | Final rule (this ADR §) |
|--------|--------|--------------------------|
| `FIRST_PRINCIPLES_WEDGE.md` §3.4 | "Policy comparison is outside the wedge" | §4.1: neutral owned-policy comparison IN; shopping comparison OUT |
| `FIRST_PRINCIPLES_WEDGE.md` §1 | "single source of truth for what does my insurance actually cover" | §4.2: source-verifiable workspace, not source of truth |
| `FIRST_PRINCIPLES_WEDGE.md` §3.5 | "Your motor policy doesn't cover flood damage" alert framing | §4.3: evidence-state wording; renamed to "Coverage facts and verification prompts" |
| `FIRST_PRINCIPLES_WEDGE.md` + `ADR-29-01` | "Not multi-tenant" | §4.8: consumer/household product; backend multi-user with principal isolation |
| `FIRST_PRINCIPLES_WEDGE.md` §4.2 + `ADR-28-reject-demo` | Camera rejection as permanent principle | §4.9: strategy, not principle; optional fallback allowed |
| `ADR-28-reject-demo` | Demo rejection as permanent | §4.10: rejected for launch; strategy decision revisitable through evidence |
| `FREE_VS_PAID_BOUNDARY.md` | Exact prices (₹149/₹999/₹249/₹1,799) as settled doctrine | §4.6/§4.7: demoted to Proposed experiments; require source + unit economics |
| `FREE_VS_PAID_BOUNDARY.md` | Comparison as paid tier feature while Wedge says comparison OUT | §4.1: advanced owned-policy comparison may be paid candidate; shopping comparison not in product |
| `FREE_VS_PAID_BOUNDARY.md` | "PPP-adjusted" without method | §4.7: require actual PPP method + source |
| `FIRST_PRINCIPLES_WEDGE.md` | "Tier 4 (runtime/manual reasoning)" evidence label | §4.13: corrected to decision-grade reasoning, Tier 0 per registry |
| `ADR-2026-07-29-01` | Self-declared "Accepted" | §4.12: no sign-off evidence found; treat as Proposed until this ADR signed |
| `ADR-2026-07-19-08` rev 2 | Widened-wedge items as keep/finish | Widened wedge remains exploration inventory; product inclusion requires passing gate stack |
| `ADR-2026-07-19-13` | Partner/insurer quote path exploration | No-fabricated-premium stands; partner quote not authorized for launch |
| `ADR-2026-07-19-04` | Claim-assistance thin slice | Reframe per §4.4: process/contacts only, not consultancy |

No historical ADR is deleted or rewritten. Every change is a dated update-log append pointing to this ADR.

---

## 8. Tradeoffs

- **Two-step cost.** Operator must sign this ADR, then a separate implementation inventory before any code changes. Slower than acting immediately, but prevents boundary drift.
- **Strategy-vs-constitution ambiguity.** Some calls (e.g., is "coverage summary first" a principle or a hypothesis?) require judgement. Mitigation: §4.11 explicitly marks it a hypothesis.
- **Commercial layer now has open questions.** Demoting prices to Proposed leaves the tier model partially unresolved. Mitigation: the open questions are listed explicitly in Phase 5c; they become a tracked decision list, not hidden assumptions.
- **Camera/demo reclassification may read as backsliding.** They remain rejected for launch; the reclassification only prevents them from becoming permanent constitutional bans that survive evidence to the contrary.

---

## 9. Assumptions

- The founder's intended role remains a non-regulated policy-information product.
- The product does not currently have authoritative insurer transaction, underwriting, or claim-status integrations.
- The user-owned policy remains the primary source of policy-specific truth.
- The evidence substrate and source-verification direction remain strategic.
- The product may be renamed without changing this doctrine.
- External legal review remains appropriate before enabling any boundary-adjacent capability.
- A fresh code/route audit will be run before implementation because parallel work may have changed current head.
- Operator sign-off on this ADR is the only acceptance path; nothing in the working tree counts as implicit acceptance.

---

## 10. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| ADR signed but not enforced | High | Phase 8 cross-links + future forbidden-semantics regression tests (post-sign-off) |
| Useful surfaces over-cut | Medium | §4.1–4.5 narrow rather than remove; allowed-contract framing preserved |
| Commercial layer left unresolved | Medium | Open questions explicitly listed in Phase 5c as a decision backlog |
| Older ADRs cited as authorization | High | Phase 6 appends + supersession map in this ADR §7 |
| Sign-off confusion (29-01 vs this ADR) | High | §4.12 + Phase 6 correction on 29-01; this ADR is the only sign-off gate |
| Doctrine mistaken for legal certification | Low | State clearly it is a product/risk boundary, not legal advice |

---

## 11. Validation plan

### Documentation gate (this task)

- Reconciliation ADR (this file) exists and is Proposed.
- Three doctrine files revised to match (Phase 5).
- All affected ADRs have dated update-log appends (Phase 6).
- Stale analyses have dated addenda (Phase 7).
- Doctrine index + cross-links in README, decisions/README, architecture, journey map, exploration map, launch_claims (Phase 8).
- Conflict-closure matrix produced (Deliverable 9).

### Sign-off gate

- Operator reviews this ADR's final text.
- Operator answers the single sign-off question (Accept / not yet).
- Only on Accept does this ADR become Accepted and implementation proceed.

### Post-sign-off gates (separate task, not authorized by this ADR)

- Current-surface inventory of every reachable mobile route and backend capability, classified against the 5 gates.
- Forbidden-semantics regression tests (no generated premium; no "Start renewal"; no claim filing/insurer-status; no "best policy"/"underinsured"; personal claim states remain `Recorded as ...`; unsupported claims cannot render verified).
- Launch-claim registry reconciliation against the gate stack.

---

## 12. Rollback

If the operator does not accept this ADR:

- Retain it as Rejected with a dated update-log entry and the operator's reasoning.
- Continue using existing ADRs and drafts, while explicitly recording the unresolved doctrine conflict.
- Do not silently implement whichever document is convenient.

If accepted and later revised:

- Do not delete or rewrite this ADR.
- Append the revision and trigger.
- Create a new superseding ADR for a material product-role change.
- Migrate code, copy, tests, data, and launch claims deliberately.

---

## 13. Revisit triggers

- Operator intentionally changes the company into a licensed or partnered insurance intermediary.
- Authoritative insurer integrations provide transaction, underwriting, or claim-status truth.
- External legal review establishes a different safe operating boundary.
- Representative user research shows the comprehension wedge does not solve a valuable problem.
- A new evidence contract supports a stronger claim without advice or inference.
- The business model depends on commissions, referrals, or partner offers.
- The product begins storing medical records or other materially more sensitive data by default.

A revisit requires a new or appended decision record. It does not occur through implementation drift.

---

## 14. Affected files

Primary (this task touches):

- `docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md` (moved from bundle, revised)
- `docs/architecture/FIRST_PRINCIPLES_WEDGE.md` (revised)
- `docs/architecture/FREE_VS_PAID_BOUNDARY.md` (revised)
- `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md` (this file)
- `docs/decisions/README.md` (index + cross-link)
- `README.md` (doctrine pointer)
- `docs/architecture/coverwise_canonical_architecture.md` (cross-link)
- `docs/user_experience/coverwise_user_journey_map.md` (cross-link)
- `docs/review/exploration_map.md` (addendum + cross-link)
- `docs/launch_claims/README.md` (cross-link)
- `docs/review/product_audit_6month.md` (supersession addendum)
- `UX_AUDIT_FIRST_PRINCIPLES.md` (supersession addendum)

Append-only updates (Phase 6):

- `ADR-2026-07-29-01`, `ADR-2026-07-28-03` (in bundle), `ADR-2026-07-28-reject-demo-mode`, `ADR-2026-07-28-01`, `ADR-2026-07-19-04`, `ADR-2026-07-19-08`, `ADR-2026-07-19-13`, `ADR-2026-07-19-14`, `ADR-2026-07-19-15`, `ADR-2026-07-19-16`, `ADR-2026-07-19-17`, `ADR-2026-07-19-18`, `ADR-2026-07-19-19`, `ADR-2026-07-19-20`, `ADR-2026-07-19-21`, `ADR-2026-07-19-22`, `ADR-2026-07-19-23`, `ADR-2026-07-19-24`, `ADR-2026-07-19-25`, `ADR-2026-07-23-01`, `ADR-2026-07-24-02`

---

## 15. Anything else?

Yes.

This ADR resolves the doctrine-level contradiction, but it does **not** prove the current app conforms to the decision. The first implementation artifact after sign-off must be a fresh current-head surface inventory classified against the five gates. No launch-readiness conclusion should be derived from this document alone.

A second concern: the repository has **three** first-principles-shaped documents (Principles, Wedge, and `UX_AUDIT_FIRST_PRINCIPLES.md`), not two. The UX audit is tracked and predates both; its recommendations (demo policy, camera-first, what-if calculator, advisor marketplace, claim assistant) have been rejected by later doctrine but the audit does not say so. Phase 7 adds the addendum; future agents must not cite it as current.

A third concern: the in-flight analytics work (`docs/analysis/ANALYTICS_STRATEGY_2026-07-28.md`, `docs/analysis/ONBOARDING_FUNNEL.md`, modified `src/api/analytics.py`, `mobile/lib/services/analytics_schema.dart`, `tests/test_analytics_funnel.py`, `mobile/test/onboarding_analytics_test.dart`, `mobile/test/first_question_asked_test.dart`, modified `docs/review/coverwise_play_store_listing.md`, untracked `docs/planning/payments/india_payment_landscape_2026-07-28.md`) is **unrelated to this doctrine task** and is preserved untouched per operator direction. It does not encode disputed product semantics (it is decision-enabling instrumentation). It is explicitly out of scope for this ADR.

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | Initial ADR created. Establishes layered doctrine stack (constitution → wedge → commercial → feature ADRs → code), adopts canonical product statement, replaces single-question gate with 5-gate stack, resolves 13 conflicts, marks ADR-29-01 as lacking sign-off evidence. Status: Proposed, awaiting operator sign-off on this exact text. | Operator direction: layered doctrine stack, one reconciliation ADR, Proposed until reviewed. Discovery that ADR-29-01 has no sign-off evidence and that three (not two) first-principles docs exist. |
| 2026-07-29 | Added §16 conflict-closure matrix (Deliverable 9). | Phase 9 deliverable of the operator task. |

---

## 16. Conflict-closure matrix (Deliverable 9)

| # | Conflict | Previous documents | Final rule | Governing document | Status | Remaining implementation work |
|---|----------|-------------------|------------|-------------------|--------|-------------------------------|
| 1 | Policy comparison in/out | Wedge §3.4 said OUT; Principles §4 table said IN (neutral) | Neutral owned-policy comparison IN (basic free / advanced paid candidate); shopping comparison OUT at every tier | This ADR §4.1; Constitution Principle 4; Wedge §3.4/§3.5 corrected | Resolved (doctrine) | Post-sign-off: split basic/advanced in code (FREE_VS_PAID G4) |
| 2 | "Actual insurance situation" / "single source of truth" | Wedge §1 | CoverWise = source-verifiable workspace, not source of truth | This ADR §4.2; Wedge §1 corrected | Resolved (doctrine) | Post-sign-off: audit copy for "source of truth" claims |
| 3 | Coverage gaps / proactive alerts | Wedge §3.5 ("doesn't cover flood") | "Coverage facts and verification prompts"; evidence-state wording; absence ≠ not covered | This ADR §4.3; Constitution Gate B; Wedge §3.5 corrected | Resolved (doctrine) | Post-sign-off: rename + reword alert logic |
| 4 | Claims scope | ADR-19-04 thin slice; audit recommendations | Policy-stated process/contacts/records IN; filing/representation/adjudication OUT | This ADR §4.4; ADR-19-04 appended; ADR-24-02 reaffirmed | Resolved (doctrine) | Post-sign-off: reframe claim-assist surface |
| 5 | Renewal | Exploration map §312; audit | Factual reminders IN; "Start renewal"/transaction OUT | This ADR §4.5 | Resolved (doctrine) | Post-sign-off: neutralize renewal CTAs |
| 6 | Free vs paid contradictions | FREE_VS_PAID (prices as settled; emergency both free+paid; comparison out+paid) | Durable principle only in constitution; exact limits/prices demoted to Proposed in commercial layer; emergency facts = free floor | This ADR §4.6; FREE_VS_PAID revised | Resolved (doctrine); 5 commercial decisions open (G1-G5) | Post-sign-off: operator approves commercial model + sourcing |
| 7 | Pricing evidence | FREE_VS_PAID ("PPP-adjusted", "RevenueCat ₹300-315") | Unsourced claims flagged; evidence-audit skeleton required; prices = experiments | This ADR §4.7; FREE_VS_PAID §7 revised | Resolved (doctrine); evidence audit open | Post-sign-off: source each benchmark |
| 8 | "Not multi-tenant" | Wedge (implied) | "Consumer/household product; backend multi-user with principal isolation" | This ADR §4.8; Wedge §5.1 added | Resolved (doctrine) | None (wording) |
| 9 | Camera import absolute | Wedge §4.2; ADR-28-reject-demo | Strategy decision (not permanent principle); direct import preferred, camera optional fallback | This ADR §4.9; Wedge §4.2 corrected; ADR-28-reject-demo appended | Resolved (doctrine) | Post-sign-off: keep camera as optional fallback |
| 10 | Demo policy absolute | Wedge §4.1; ADR-28-reject-demo | Strategy decision; rejected for launch; marketing-site read-only example = experiment | This ADR §4.10; Wedge §4.1 corrected; ADR-28-reject-demo appended | Resolved (doctrine) | Post-sign-off: decide on isolated preview example |
| 11 | Coverage summary first | Wedge §3.3 (as proven) | Strategy hypothesis, not universal proof | This ADR §4.11; Wedge §3.3 marked hypothesis | Resolved (doctrine) | Post-sign-off: validate via usability evidence |
| 12 | ADR-29-01 "Accepted" status | ADR-29-01 self-declared | No sign-off evidence found; treat as Proposed until this ADR signed | This ADR §4.12; ADR-29-01 appended | Resolved (doctrine) | Operator signs this ADR |
| 13 | Evidence tier mislabel | Wedge ("Tier 4 runtime") | Decision-grade reasoning (Tier 0 per registry) | This ADR §4.13; Wedge §2 corrected | Resolved (doctrine) | None |
| 14 | Widened-wedge items as keep/finish | ADR-19-08 rev 2 | Exploration inventory; product inclusion requires gate stack | This ADR §7; ADR-19-08 appended | Resolved (doctrine) | Post-sign-off: classify each surface against gates |
| 15 | Partner/quote path | ADR-19-13 exploration | Not authorized for launch; requires separate ADR | This ADR §7; ADR-19-13 appended | Resolved (doctrine) | Post-sign-off: separate ADR if pursued |
| 16 | Three competing first-principles docs | Principles (bundle), Wedge, UX_AUDIT_FIRST_PRINCIPLES | One layered stack; UX audit + 6-month audit get supersession addenda | This ADR; Phase 7 addenda | Resolved (doctrine) | None (docs reconciled) |

**Status key:** "Resolved (doctrine)" = the conflict has a final rule in this ADR and the lower-layer docs are corrected by addendum. None authorize code changes; all implementation work is post-sign-off.
