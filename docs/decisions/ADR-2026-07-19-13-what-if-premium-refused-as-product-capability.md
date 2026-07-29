# ADR-2026-07-19-13: What-If Premium = explore, not ship; the right answer is a deep-link or a vetted partner, not a fabricated number

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The "What-If Premium" question ("if I change my sum insured by Y, what would my premium be?") is NOT answered inside the product.** The product refuses to fabricate a premium number. The product offers three honest options: (a) a deep-link to the insurer's own premium calculator (when the insurer publishes one), (b) an opt-in to a vetted partner quote aggregator (per the Value-Add Partnerships framework in ADR-2026-07-19-08 #5), or (c) "ask your insurer" with the insurer's contact card from the substrate. The chosen path is **(a) by default, (b) when the user opts in to partnerships, (c) as the always-available fallback.** The product does not invent, estimate, or approximate premium numbers. The user gets the real number, from a real source, or the user gets an honest "we don't know; ask your insurer."
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** The "What-If Premium" question is refused as a product capability. The product offers three honest options: (a) deep-link to the insurer's calculator (default), (b) opt-in to a vetted partner quote aggregator (when opted in, per ADR-16), (c) "ask your insurer" (always-available fallback). The launch-claim registry entry is "CoverWise does not fabricate premium numbers." Implementation may begin in dependency order: option A + C land first (1-2 weeks), option B lands after the Value-Add Partnerships framework (ADR-16) is in place (2-3 days). The "what would X cost" pattern is reusable for future ADRs (e.g. "what would my tax savings be?"). See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #2 (the Coverage Adequacy tool that this ADR complements; same screen, different question), [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #5 (the Value-Add Partnerships framework that option (b) depends on), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The "What-If Premium" question is separated from the Coverage Adequacy tool (ADR-08 #2) and explicitly refused as a product capability. The product offers a deep-link, a vetted partner, or an honest "ask your insurer" — never a fabricated number. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The three-option contract (deep-link + vetted partner + ask your insurer) is the contract. The launch-claim registry entry is "CoverWise does not fabricate premium numbers." Implementation order: option A + C land first (1-2 weeks), option B lands after ADR-16. The "what would X cost" pattern is reusable for future ADRs (e.g. "what would my tax savings be?").

---

## Context

The operator's per-feature thinking (per ADR-2026-07-19-08 revision 2) distinguished between two "what-if" questions:

1. **"Am I covered for scenario X?"** (the Coverage Adequacy question). This is a substrate-grounded question: the policy says X about C-sections, knee replacements, ICU, etc. The product can answer it honestly because the substrate has the data. This is the Coverage Adequacy tool (ADR-08 #2).

2. **"If I change my sum insured by Y, what would my premium be?"** (the What-If Premium question). This is NOT a substrate-grounded question: the premium depends on the insurer's underwriting model, the user's age, medical history, location, claim history, discounts, taxes, and a dozen other factors the product does not have. The product cannot answer it honestly. The original What-If Premium Calculator (now removed per ADR-08 #2) fabricated numbers with hardcoded multipliers — that was the lying UI the audit flagged.

The operator said "we need to explore" on the What-If Premium question. This ADR is the exploration.

The product's role with respect to the What-If Premium question is **intermediary, not answerer.** The product does not have the underwriting data. The product does not have a license to sell insurance. The product does not have a regulatory mandate to give premium advice. The product's job is to connect the user to the right source, with a clear "this is the source's number, not ours" label.

---

## Options considered

### Option A: Deep-link to the insurer's premium calculator. CHOSEN (default).

- **How it works:** the per-insurer URL lookup table (already in `mobile/lib/screens/claim_assistance_screen.dart:313-341` per bc16e9e) is extended with a `premium_calculator_url` field. The user opens the Coverage Adequacy screen, picks a scenario, and the screen shows a "What would this cost?" button. The button opens the insurer's premium calculator in an in-app browser with a clear "you're now on your insurer's site; CoverWise is not responsible for the numbers" banner.
- **Why chosen:** the insurer's calculator is the authoritative source. The number is real. The user is the verifier. The product is the bridge.
- **Cost:** S. 1-2 days to extend the URL lookup table + the in-app browser integration.
- **Quality:** the user gets a real number, from a real source. The "not our number" label is honest.

### Option B: Opt-in to a vetted partner quote aggregator. CHOSEN (when the user opts in to partnerships).

- **How it works:** the Value-Add Partnerships framework (per ADR-08 #5) includes a "quote aggregator" partner category. The partner is vetted per the partner-vetting policy (a future ADR; the framework is built; the policy is the next step). The user opts in to partnerships, the product shares the user's opt-in signal with the partner (not the user's documents), the partner sends a quote back through the opt-in webhook. The quote is displayed with a clear "this is [Partner Name]'s quote, not CoverWise's" label.
- **Why chosen:** some users want to compare quotes from multiple insurers. The partner is the comparison engine. The product is the intermediary. The user opted in.
- **Cost:** the framework is already in the workstream; the partner onboarding is a future ADR. The quote-aggregator category is a 1-day addition to the partner-vetting policy.
- **Quality:** the user gets multiple real quotes, from real sources, through a real opt-in. The partner is vetted. The "not our quote" label is honest.

### Option C: "Ask your insurer" with the insurer's contact card. CHOSEN (always-available fallback).

- **How it works:** the substrate already extracts the insurer's name and the per-insurer URL lookup table provides the insurer's claim process URL. The "ask your insurer" card shows: the insurer's name, the claim helpline, the email, the process URL, and a "call your insurer to ask about premium changes" prompt. The card is always available, even if option A or B is not configured.
- **Why chosen:** the user always has a way to ask. The product is the source of the contact card. The user is the actor.
- **Cost:** 0. The card is already in the substrate + the URL lookup table.
- **Quality:** the user gets a real contact, for a real purpose, with a real action.

### Option D: Fabricate a number. REJECTED.

- **How it works:** the product uses LLM to estimate the premium based on the substrate + general market data. The number is shown with a disclaimer.
- **Why rejected:** the audit's NO-GO is exactly this. A fabricated premium number is the worst possible outcome: the user acts on a number that came from nowhere. Disclaimers do not fix lying UI. The original What-If Premium Calculator was option D; it was cut per ADR-08 #2.

### Option E: Refuse entirely. REJECTED.

- **How it works:** the product says "we don't know; ask your insurer" with no other options.
- **Why rejected:** too restrictive. The user has a real question. The product can connect the user to the real answer (insurer's calculator, vetted partner) without fabricating. Option C is the always-available fallback; options A and B are the preferred paths.

---

## The contract in detail

### The "What-If Premium" question is separated from the Coverage Adequacy question.

- **Coverage Adequacy** (ADR-08 #2): "Am I covered for scenario X?" — answered from the substrate. The answer is "yes" / "no" / "not in the substrate" / "your policy excludes this; here is the exclusion clause."
- **What-If Premium** (this ADR): "What would my premium be if I change X?" — NOT answered from the substrate. The product offers a deep-link, a partner, or an honest "ask your insurer."

The two questions live on the same screen (the Coverage Adequacy tool), but they are visually separated. The Coverage Adequacy section shows the substrate-grounded answer. The What-If Premium section shows the three options. The user sees both.

### Option A: deep-link to insurer's calculator (default)

- **What the user sees:** a "What would this cost?" button below the Coverage Adequacy answer. The button is enabled when the per-insurer URL lookup table has a `premium_calculator_url` for the user's insurer.
- **What happens when the user taps:** an in-app browser opens the insurer's calculator. A banner at the top says "You're on [Insurer Name]'s site. CoverWise is not responsible for the numbers shown here."
- **What the user does:** uses the calculator. The user may screenshot the result and bring it back to the Coverage Adequacy screen. The product does not capture the result.
- **When the button is disabled:** when the URL lookup table has no `premium_calculator_url` for the user's insurer. The button is replaced with the option C card ("ask your insurer").

### Option B: opt-in to vetted partner quote aggregator

- **What the user sees:** a "Compare quotes from vetted partners" toggle below the option A button. The toggle is disabled by default. The toggle is enabled when (a) the user has opted in to Value-Add Partnerships (per ADR-08 #5), and (b) the partner-vetting policy (future ADR) has approved at least one quote-aggregator partner.
- **What happens when the user toggles on:** the product shares the user's opt-in signal with the partner (not the user's documents). The partner sends a quote back through the opt-in webhook. The quote is displayed in the Coverage Adequacy screen with a clear "[Partner Name]'s quote; CoverWise has not verified this number" label.
- **What happens when the user toggles off:** the partner stops receiving the opt-in signal. The user can opt out at any time.
- **What "vetted" means:** the partner-vetting policy (future ADR) defines the criteria. The criteria are public. The partner is listed on the marketing site with the criteria they met. The user can audit the criteria.

### Option C: "ask your insurer" (always-available fallback)

- **What the user sees:** a card with the insurer's name, claim helpline, email, process URL, and a "Call your insurer to ask about premium changes" prompt. The card is always visible, even if options A and B are not configured.
- **What the user does:** calls, emails, or visits the insurer's process page. The user is the actor.
- **What the product does:** the product is the source of the contact card. The product does not follow up, does not track the call, does not capture the result.

### The product never fabricates a premium number.

- **The rule:** the product does not display a premium number that the product generated. The number must come from the insurer (option A), a vetted partner (option B), or the user's own conversation with the insurer (option C). The product does not estimate, approximate, or LLM-generate.
- **The enforcement:** the Coverage Adequacy screen has no text field or display that can show a fabricated number. The only numbers shown are the substrate's existing numbers (sum insured, room rent cap, etc.).
- **The launch-claim registry:** the claim "CoverWise does not fabricate premium numbers" is in the launch-claim registry (per ADR-2026-07-19-09). The claim is tested by an automated test that scans the Coverage Adequacy screen for any number-rendering widget that is not bound to a substrate field.

---

## Chosen path

**Option A (default) + Option B (when opted in) + Option C (always-available fallback).** The product refuses to fabricate a premium number. The product offers three honest paths to a real number.

**Work to implement:**

1. **Extend the per-insurer URL lookup table** with a `premium_calculator_url` field. The field is nullable; missing means option A is disabled for that insurer. Effort: S. 0.5 day.
2. **Add the "What would this cost?" button** to the Coverage Adequacy screen. The button is enabled when the URL is configured. The in-app browser opens the URL with the "you're on the insurer's site" banner. Effort: S. 1-2 days.
3. **Add the "Compare quotes" toggle** to the Coverage Adequacy screen. The toggle is enabled when (a) the user has opted in to partnerships, and (b) a vetted quote-aggregator partner is available. Effort: M. 2-3 days (depends on the Value-Add Partnerships framework from ADR-08 #5).
4. **Add the "ask your insurer" card** (option C) to the Coverage Adequacy screen. The card is always visible. The card uses the substrate's insurer name and the URL lookup table's claim helpline + email. Effort: S. 0.5 day.
5. **Add the launch-claim registry entry** "CoverWise does not fabricate premium numbers." The entry includes the test that scans for fabricated-number widgets. Effort: S. 0.5 day.
6. **Update the canonical doc** to define the What-If Premium contract: refused as a product capability, offered as three honest paths. Effort: S. 0.5 day.

**Total effort:** S-M. 1-2 weeks (option A + option C) + 2-3 days (option B, depends on partnerships framework).

**Sequence:**

1. Option A (deep-link) + Option C (ask your insurer) — the foundational paths. Land together as a single feature.
2. Option B (partner) — depends on the Value-Add Partnerships framework and the partner-vetting policy (future ADRs).
3. Launch-claim registry entry + canonical doc update — at the end, after options A and C are tested.

**Dependency:** option B depends on the Value-Add Partnerships framework (ADR-08 #5) and the partner-vetting policy (future ADR). The framework and the policy are a separate workstream. Option B can land later, after the partner-vetting policy is in place.

---

## Why this path

### 1st-principle argument

The product does not have the data to answer the What-If Premium question. The premium depends on underwriting data the product does not have. Fabricating a number is a lie. The honest answer is: the product is an intermediary, not an answerer. The product connects the user to the real source.

The same argument as the trust audit's NO-GO: stop showing what the system does not know. The What-If Premium number is something the system does not know. The system shows the user where to find the real number, with a clear "this is the source's number, not ours" label.

### Anti-lying-UI argument (motto v3 §0.7, trust audit NO-GO)

A fabricated premium number is the worst possible outcome. The user acts on a number that came from nowhere. The user may change their coverage based on the number, then find out the real number is different. The trust damage is severe and durable. The audit's NO-GO is exactly this.

### Anti-disclaimer argument (motto v3 §0.4 acceptance contract)

A disclaimer ("this is an estimate, not a quote") does not fix a lying UI. The acceptance contract for "ship a feature" is "the user who uses this feature is not deceived." A fabricated number with a disclaimer is still a fabricated number. The user sees a number and acts on it; the disclaimer is small print.

### Anti-single-source argument (motto v3 §13 scope control)

The three-option contract (insurer deep-link, vetted partner, ask your insurer) is broader than a single option. The user has a choice. The user can compare. The user can opt out. The user is the actor, not the recipient.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The three-option contract is a recommendation. The operator may want a different mix (e.g. only option C, refuse entirely); the operator may want to defer option B until a partner is actually vetted; the operator may want the partner-vetting policy first. The reason this is an ADR and not a code change is that the What-If Premium contract is load-bearing and the operator should sign off on it.

---

## Tradeoffs

- **The user may not have an insurer with a public premium calculator.** Option A is disabled for those users; they fall back to option C. The per-insurer URL lookup table is small (29 Indian insurers per bc16e9e); not all insurers have public calculators. The mitigation is option C is always available.
- **The partner-vetting policy is a future ADR.** Option B depends on the policy. Until the policy is in place, option B is not enabled. The mitigation is the Value-Add Partnerships framework (ADR-08 #5) is built first; the partner-vetting policy is the next step.
- **The "ask your insurer" card is generic.** The card has the insurer's name, helpline, email, and process URL. The card does not have a "premium change" specific action. The user has to call and ask. The mitigation is the card is the honest fallback; the user is the actor.
- **The launch-claim registry test may catch legitimate numbers.** The test scans for number-rendering widgets. Some legitimate numbers (e.g. the substrate's sum insured) are bound to substrate fields and pass. Some test fixtures may render numbers; the test must exclude test code. The mitigation is the test's exclusion list.
- **The product does not capture the user's call or email.** The product does not track whether the user called the insurer. The product does not store the quote. The user is the actor. The mitigation is the consent ledger (per ADR-2026-07-19-07) records the partnership opt-in; the user can opt out at any time.

---

## Assumptions

- **The per-insurer URL lookup table is the right place for the `premium_calculator_url` field.** The table is small (29 Indian insurers); extending it with one more field is a 0.5-day change. The operator may want a separate table; the ADR is the place to discuss.
- **The in-app browser is the right UX for option A.** The user sees the insurer's site with a "you're on the insurer's site" banner. The user does not have to leave the app. The operator may want a different UX (e.g. a modal with the calculator embedded); the ADR is the place to discuss.
- **The Value-Add Partnerships framework (ADR-08 #5) is the right place for option B.** The framework is built first; the quote-aggregator partner category is a 1-day addition. The operator may want a separate framework; the ADR is the place to discuss.
- **The "ask your insurer" card is always visible.** The card is a fallback, not a primary action. The user can ignore it; the user can use it. The operator may want the card to be more prominent or less prominent; the ADR is the place to discuss.
- **The launch-claim registry entry "CoverWise does not fabricate premium numbers" is enforceable.** The test scans for number-rendering widgets. The test is a grep + a render test. The operator may want a different test; the ADR is the place to discuss.

---

## Risks

- **The operator disagrees with the three-option contract.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the options explicit and easy to revisit.
- **The per-insurer URL lookup table becomes stale.** Insurers change their calculators. The table needs to be updated quarterly. The mitigation is a quarterly review process; the operator is the author.
- **A partner is vetted and the user opts in, but the partner's quote is wrong.** The product is not responsible for the partner's quote; the label says so. The mitigation is the partner-vetting policy; the user can report a bad quote; the partner can be un-vetted.
- **The "ask your insurer" card is ignored.** The user prefers a fabricated number to a phone call. The mitigation is the card is the honest fallback; the user is the actor. The product does not chase the user.
- **The launch-claim registry test is too strict.** Some legitimate numbers are flagged. The mitigation is the test's exclusion list and a manual review process.

---

## Validation plan

- **For option A:** an integration test that asserts the per-insurer URL lookup table has a `premium_calculator_url` for at least 5 major insurers (the table starts with 29; the test ensures the field is populated for the most-used insurers).
- **For option A:** a widget test that asserts the "What would this cost?" button is enabled when the URL is configured and disabled when it is not.
- **For option B:** a unit test that asserts the "Compare quotes" toggle is enabled only when (a) the user has opted in to partnerships, and (b) a vetted quote-aggregator partner is available.
- **For option C:** a widget test that asserts the "ask your insurer" card is always visible, even when options A and B are not configured.
- **For the launch-claim registry:** a CI test that scans the Coverage Adequacy screen for any number-rendering widget that is not bound to a substrate field. The test fails if a fabricated-number widget is found.
- **For the canonical doc:** a doc-lint test that asserts the What-If Premium contract is defined.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the three options are implemented. The validation includes: user opens Coverage Adequacy → sees the answer → taps "What would this cost?" → opens the insurer's calculator → sees the banner → returns to the app.

---

## Rollback or migration path

The three options are additive. The per-insurer URL lookup table extension is reversible. The widget changes are local. The launch-claim registry entry is removable.

If an option turns out to be wrong:
- Option A can be disabled by setting all `premium_calculator_url` fields to null. The button is replaced with option C.
- Option B can be disabled by removing the toggle. The option is hidden.
- Option C is always available and cannot be disabled.

The launch-claim registry entry is updated when an option changes. The CI gate fails if the entry is not updated.

---

## What would cause this decision to be revisited

- **The operator wants a different mix.** A future ADR can add option D (refuse entirely), can remove option A or B, or can change the default. The contract is the three options; the mix is configurable.
- **The partner-vetting policy lands and approves a quote-aggregator partner.** Option B activates. The launch-claim registry entry is updated.
- **An insurer publishes a more accurate calculator.** Option A's URL is updated. The per-insurer URL lookup table is the source.
- **A regulator requires the product to display a premium estimate.** A future ADR can add a regulated estimate path. The launch-claim registry entry would then describe the regulated estimate, not the refused-fabrication rule.
- **The market changes.** A competitor fabricates premium numbers. The operator may decide to compete. This ADR's revisit trigger would note the change but the original 1st-principle argument stands.

---

## Anything else? (operator's standing review prompt)

The What-If Premium question raises a more general question: **what other "what would X cost" questions does the product refuse to answer?** The pattern is: the product refuses to fabricate numbers it does not have the data for, and offers honest paths to the real source.

- **"What would my claim payout be?"** — depends on the claim, the policy's terms, the insurer's claims process. The product refuses to estimate. The product offers the claim-assistance flow (the new `claim_assistance_screen.dart` per ADR-08 #3) and the IRDAI escalation card. The pattern is the same.
- **"What would my tax savings be?"** — depends on the user's tax bracket, the policy's tax treatment (80D for health, 80C for life), the user's other deductions. The product refuses to estimate. The product offers a deep-link to a tax calculator (similar to option A) and a vetted partner (similar to option B). The pattern is the same. **Future ADR: "What would my tax savings be?"** — same three-option contract.
- **"What would my coverage be in retirement?"** — depends on the policy's terms, the user's retirement age, inflation, life expectancy. The product refuses to estimate. The product offers the Coverage Check-in (per ADR-08 #1) as a periodic reflection surface. The pattern is the same. **Future ADR: "What would my coverage be in retirement?"** — answered by the Coverage Check-in, not by a fabricated number.

The three-option contract (deep-link, vetted partner, ask the source) is a reusable pattern for any question the product does not have the data to answer honestly. The pattern is in the launch-claim registry; the per-question ADRs are the implementation.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `mobile/lib/screens/claim_assistance_screen.dart` (extend the per-insurer URL lookup table with `premium_calculator_url`)
  - `mobile/lib/screens/coverage_adequacy_screen.dart` (new, the screen that hosts options A, B, C; depends on ADR-08 #2)
  - `mobile/lib/widgets/what_would_this_cost_button.dart` (new, option A button)
  - `mobile/lib/widgets/compare_quotes_toggle.dart` (new, option B toggle)
  - `mobile/lib/widgets/ask_your_insurer_card.dart` (new, option C card)
  - `mobile/lib/widgets/in_app_browser_banner.dart` (new, the "you're on the insurer's site" banner)
  - `tests/test_premium_calculator_url.py` (new, the URL lookup table test)
  - `tests/test_what_if_premium_widgets.py` (new, the widget tests for options A, B, C)
  - `tests/test_no_fabricated_premium_numbers.py` (new, the launch-claim registry test)
  - `docs/launch_claims/no-fabricated-premium-numbers.md` (new, the launch-claim registry entry)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the What-If Premium contract to the doc)
  - `docs/decisions/README.md` (add this ADR to the index)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #2 (the Coverage Adequacy tool that this ADR complements)
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #5 (the Value-Add Partnerships framework that option B depends on)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` (the audit's NO-GO on fabricated numbers)
  - `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` (the product boundary that the What-If Premium question sits on)
- **Related code (current state):**
  - `mobile/lib/screens/claim_assistance_screen.dart:313-341` (the per-insurer URL lookup table, the foundation for option A)
  - `mobile/lib/screens/coverage_adequacy_screen.dart` (the screen that will host options A, B, C; per ADR-08 #2)
- **Motto v3 alignment:** §0.4 (acceptance contract; the user who uses the What-If Premium feature is not deceived), §0.7 (AI output boundary; the product refuses to fabricate premium numbers), §0.11 (customer-facing claims; the "ask your insurer" card is a customer right), §0.12 (this document), §0.13 (scope control; the three-option contract is a deliberate broadening, not a reactive triage).

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | **Reaffirmed + partner-path clarification per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) §7.** The no-fabricated-premium decision stands (Gate C in the constitution). The partner/insurer quote-aggregator path explored in this ADR is **not authorized for launch** by this ADR; it requires a separate accepted ADR covering regulatory role, compensation, consent, disclosures, data flow, withdrawal, deletion, and legal review. Original reasoning preserved. | Operator direction: layered doctrine stack; ADR-2026-07-29-02 reconciliation. |


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Reaffirmed (no fabricated premium stands, Gate C); partner/insurer quote-aggregator path is NOT authorized for launch by this ADR and requires a separate accepted ADR (regulatory role, compensation, consent, disclosures, data flow, withdrawal, deletion, legal review).
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
