# ADR-2026-07-19-04: Coverage-gap + claim-assistance = thin slice from the existing 7 substrate fields, full features deferred

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** Ship a **thin slice** of the coverage-gap + claim-assistance features in this session, grounded in the 7 fields the evidence substrate's parser pipeline currently extracts (`policy_number`, `policy_holder_name`, `sum_insured`, `policy_start_date`, `premium_amount`, `insurer_name`, `room_rent_cap`). Defer the full features to a follow-up session that extends the parser pipeline with the additional extractors needed (`maternity_covered`, `dental_covered`, `opd_covered`, `pre_existing_disease_waiting_period`, `network_hospital_list_url`, `claim_helpline`, `claim_email`).
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** Accepted.
- **Related artifacts:** [embedding model ADR](./ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md), [outbox migration ADR](./ADR-2026-07-19-02-outbox-migration-deferred.md), [`mobile/lib/widgets/field_citations_card.dart`](../../../mobile/lib/widgets/field_citations_card.dart) (the existing substrate-grounded widget; the thin-slice features reuse this pattern).

---

## Context

The architecture audit flagged this as ADR-09. The question is whether to ship the **coverage-gap** feature (a UI that shows "your policy doesn't cover X" for common gaps like maternity, dental, OPD) and the **claim-assistance** feature (a guided walkthrough that helps the user file a claim with their insurer) **now**, or **defer** until the evidence substrate (Trust Phase 1) is fully populated and can ground these features in real extracted data.

The features have obvious user value. But the features are also **claim-shaped**: they answer questions about the user's policy. Per the trust audit, every claim about a policy must be grounded in the substrate. The features without the substrate ARE the failure mode the audit flagged.

Today's substrate status:

- The substrate SQL contract is in place (4 tables + view + cost table) — `supabase/migrations/2026_07_18_evidence_substrate.sql`.
- The Python access layer is in place — `src/services/evidence_substrate_service.py`.
- The parser pipeline runs 6 deterministic + 1 LLM extractor — `src/services/evidence_pipeline.py`.
- The 7 fields extracted are: `policy_number`, `policy_holder_name`, `sum_insured`, `policy_start_date`, `premium_amount`, `insurer_name`, `room_rent_cap`.

The 7 fields do **not** include the coverage-gap fields (maternity, dental, OPD, etc.) or the claim-assistance inputs (network hospital list, claim helpline, document checklist).

---

## Options considered

### Option A: Ship LLM-based coverage-gap + claim-assistance with disclaimers. REJECTED.

- **How it works:** the coverage-gap feature uses the LLM to guess at common gaps; the claim-assistance feature uses the LLM to walk the user through a generic process. The UI shows a disclaimer: "based on the document, not a substitute for insurer confirmation."
- **Cost:** 3-5 days for coverage-gap; 5-7 days for claim-assistance. Total: 1-2 weeks.
- **Quality:** the LLM's guesses are wrong ~30% of the time (per the trust audit's estimate of LLM extraction error rate). The wrong guesses will hurt users ("your policy covers dental" when it doesn't → user goes to the dentist, gets a bill, is upset).
- **Trust audit alignment:** the disclaimers do not fix the lying UI. The audit is explicit: the only fix is to refuse to show what the system does not know.
- **Technical debt:** when the substrate lands, the features must be rewritten to read from the substrate. The LLM-based version is throwaway code.
- **Why rejected:** this is the failure mode the trust audit's NO-GO is specifically about.

### Option B: Defer the full features until the parser pipeline is extended with 5-7 more extractors. PARTIALLY REJECTED.

- **How it works:** the parser pipeline gains 5-7 more extractors (`maternity_covered`, `dental_covered`, `opd_covered`, `pre_existing_disease_waiting_period`, `network_hospital_list_url`, `claim_helpline`, `claim_email`). The features then read from the substrate and are grounded in real data.
- **Cost:** 5-7 days to extend the pipeline; 1-2 days for coverage-gap; 3-5 days for claim-assistance. Total: 9-14 days.
- **Quality:** the features are grounded in the user's actual policy. They are honest about what they know (the substrate's `evidence_strength` field tells the UI when to show "not verified").
- **Trust audit alignment:** perfect.
- **Why partially rejected:** the substrate already has 7 fields. Some of those 7 are exactly what the coverage-gap + claim-assistance features would show. Deferring the full features makes sense; deferring the thin slice does not.

### Option C: Ship a thin slice from the existing 7 substrate fields; defer the full features. CHOSEN.

- **How it works:** the thin slice uses only the 7 fields the substrate already extracts. The coverage-gap view shows the `room_rent_cap` (the most-asked-about coverage gap) and the `insurer_name` (for context). The claim-assistance entry point shows the insurer's name (from substrate) and a deep-link to the insurer's claim process (generic for now; the substrate-grounded version ships with the pipeline extension).
- **What the thin slice does NOT do:** it does not show maternity, dental, OPD, pre-existing disease waiting period, network hospital list, claim helpline, or claim email. Those are deferred.
- **Honesty contract:** the thin slice tells the user: "This is what your policy says; the substrate did not extract dental, maternity, OPD, etc. Those gaps are not in the system yet." This is the "not yet verified" scaffold pattern from Trust Phase 0 P0-0.4, applied to a new surface.
- **Cost:** 1-2 days for the thin slice; the full features ship in a follow-up session per the deferred work.
- **Quality:** the thin slice is grounded in the substrate. It is honest. It is limited.
- **Trust audit alignment:** the thin slice is honest. The deferred full features are a planned gap, not a hidden one.
- **Why chosen:** the same pattern as ADR-2026-07-19-03 (ship the contract, defer the consumer; the thin slice is the contract, the full features are the consumer).

---

## Chosen path

**Option C: ship a thin slice from the existing 7 substrate fields; defer the full features.**

The thin slice:

1. **Coverage-gap view** in the policy detail screen (or a new tab). Shows:
   - The `room_rent_cap` field as a coverage gap ("your policy has a room rent cap of X").
   - The `insurer_name` as context ("this is your insurer").
   - An honest "not yet extracted" section listing the gaps the substrate does not currently cover (maternity, dental, OPD, mental health, cosmetic, pre-existing conditions, network hospital list, claim helpline, claim email).
2. **Claim-assistance entry point** in the policy detail screen (or a new tab). Shows:
   - The `insurer_name` (from substrate).
   - A "View insurer's claim process" deep-link to the insurer's website (the URL is a per-insurer lookup table; v1 is a generic insurer-claims-process page).
   - An honest "claim document checklist" placeholder that says the substrate will provide the per-policy checklist once the pipeline extension lands.

Both are honest because both are grounded in the substrate. Both are limited because both use only the existing 7 fields. Both ship in this session.

The full features (maternity, dental, OPD, pre-existing disease waiting period, network hospital list, claim helpline, claim email, full claim-assistance flow) are deferred to a follow-up session that:

1. Extends the parser pipeline with 5-7 new extractors.
2. Updates the substrate schema (if needed) for the new fields.
3. Updates the coverage-gap view to read the new fields.
4. Updates the claim-assistance flow to use the network hospital list, helpline, email, and per-insurer claim process.

---

## Why this path

### 1st-principle argument

The features are claim-shaped. The trust audit's NO-GO is about claim-shaped UI. The features without the substrate ARE the failure mode the audit flagged. The features with the substrate are the honest version.

The same argument as Trust Phase 1 itself: "stop the false claims before adding capability." The features are the capability; the false claims are the LLM guesses. The substrate is the contract that turns the capability into a product that is honest about what it knows.

The thin slice is the application of this argument to the existing 7 fields. The full features are the application of this argument to the extended pipeline.

### Anti-parallel-paths argument (motto v3 §0.1)

The thin slice reuses the existing `FieldCitationsCard` widget pattern. There is no parallel UI for "show me what my policy says" — the thin slice is the same surface that the policy detail screen already shows, with two new tabs. The full features, when they ship, will reuse the same pattern.

### Anti-disclaimer argument (motto v3 §0.4 acceptance contract)

The trust audit's NO-GO is explicit: a disclaimer does not fix a lying UI. The only fix is to refuse to show what the system does not know. The thin slice shows what the substrate knows; the "not yet extracted" section is honest about what the substrate does not know. The full features, when they ship, will show the same honest pattern.

### Anti-stubs argument

A stub that looks like a feature but does nothing is worse than no feature at all. The thin slice is not a stub; it is a real, substrate-grounded, useful view. The full features are not a stub; they are deferred because the substrate does not yet have the data.

### Honesty-as-a-feature argument

The thin slice's "not yet extracted" section is itself a feature: it tells the user what the system does not know, which is more honest than a feature that pretends to know everything. The same pattern is in the Phase 0 P0-0.4 "Not yet verified" scaffold.

### Anti-defer-all argument

Deferring the full features is the right call. Deferring the thin slice would be a different mistake: it would say "we have 7 fields of real data and we cannot show any of them in a useful way." That is a failure of imagination, not a failure of the substrate.

---

## Tradeoffs

- **The thin slice shows only 1-2 of the ~10 things a full coverage-gap feature would show.** This is honest, but it is also limited. The user may want to know about maternity or dental; the thin slice does not show those.
- **The thin slice's claim-assistance flow is a deep-link to a generic insurer page, not the user's insurer's specific claim process.** The per-insurer process URL is a future extraction. The thin slice is honest: it shows the insurer's name (from substrate) and a generic deep-link.
- **The "not yet extracted" section is a new UI pattern.** It tells the user what the system does not know. The pattern is established in Trust Phase 0 P0-0.4; the thin slice extends it to a new surface.
- **The deferred full features have a 2-3 week cost.** This is the price of doing it right. The trust audit's NO-GO is the warning; the cost of NOT doing it right is the trust damage from a lying feature.
- **The thin slice is a "marketing risk."** Users may see the coverage-gap view and think "this app only tells me about room rent" — a misperception. The "not yet extracted" section mitigates this; the launch messaging is the operator's job.

---

## Assumptions

- **The 7 fields the substrate currently extracts are enough for a useful thin slice.** The `room_rent_cap` is the most-asked-about coverage gap; the `insurer_name` is the foundation of the claim-assistance flow. This is a minimum, but it is grounded.
- **The operator will apply the launch playbook's 7 migrations before the thin slice is useful in production.** Without the substrate, the thin slice has no data. The launch playbook is the prerequisite.
- **The 5-7 new extractors can be added to the parser pipeline in 5-7 days.** This is an estimate; the actual time may vary. The extractors are the same shape as the existing 7 (deterministic_regex for pattern fields, llm_extract for clause_text fields with the honesty check).
- **The per-insurer claim-process URL is a small lookup table** (a JSON map in the codebase, not a substrate field). The lookup table is honest about being a small static table; it is not a claim about a specific policy.

---

## Risks

- **The thin slice is too thin and the user is disappointed.** Mitigation: the "not yet extracted" section is honest about what is missing. The launch messaging is the operator's job.
- **The thin slice is misinterpreted as "the app only does room rent."** Mitigation: the thin slice is one of two new tabs; the policy detail screen's existing 18 widgets (header, money row, dates card, key benefits, exclusions, etc.) are still there. The coverage-gap tab is an addition, not a replacement.
- **The full features, when they ship, require a parser pipeline extension that takes 5-7 days.** This is the price. The follow-up session has a clear acceptance contract.
- **The parser pipeline extension may surface new truth-vs-lying edge cases.** The trust audit's LLM honesty check pattern is reusable; the new extractors follow the same pattern.

---

## Validation plan

- **For the thin slice (shipped):**
  - Widget tests for the coverage-gap view: shows the room_rent_cap when present; shows the "not yet extracted" section when other fields are absent.
  - Widget tests for the claim-assistance entry point: shows the insurer_name; shows the deep-link.
  - Dark-mode tests (per Trust audit P0-2.7, no hardcoded colors).
- **For the deferred full features:**
  - The follow-up session runs the launch playbook's Step 8 (real-device end-to-end test) for the new features.
  - The 5-7 new extractors have unit tests in `tests/test_evidence_pipeline.py` (the existing test file pattern, extended).
  - The new fields are queryable via `v_field_citations` (the existing view; no schema change needed if the new fields follow the existing shape).

---

## Rollback or migration path

The thin slice is additive: it adds two new tabs to the policy detail screen. Removing the tabs is a 1-commit revert. The deferred full features, when they ship, are also additive.

If the thin slice turns out to be the wrong shape (e.g. the user wanted a single "summary" view, not tabs), the follow-up session refactors the tabs into the summary view. The substrate is unchanged.

---

## What would cause this decision to be revisited

- **The thin slice proves to be insufficient** (the operator's data shows users want more than 1-2 coverage-gap fields). The follow-up session extends the pipeline.
- **The 5-7 new extractors are harder than estimated** (the LLM honesty check rejects too many fields, or the regex patterns are too brittle). The follow-up session re-estimates.
- **A new insurer-specific claim-process URL table emerges** (e.g. from a partner integration). The thin slice's lookup table grows; the claim-assistance flow gets per-insurer URLs.
- **The market changes** (a competitor ships coverage-gap + claim-assistance without grounding). The operator may decide to ship a less-honest version to compete. This ADR's revisit triggers would note the change but the original 1st-principle argument stands.

---

## Links

- **Affected files (this commit):**
  - `mobile/lib/screens/coverage_gap_screen.dart` (new, the coverage-gap view)
  - `mobile/lib/screens/claim_assistance_screen.dart` (new, the claim-assistance entry point)
  - `mobile/lib/widgets/not_yet_extracted_section.dart` (new, the honest "what the substrate does not know" widget)
  - `mobile/test/coverage_gap_screen_test.dart` (new, widget tests)
  - `mobile/test/claim_assistance_screen_test.dart` (new, widget tests)
  - `mobile/test/not_yet_extracted_section_test.dart` (new, widget tests)
  - `mobile/lib/screens/policy_detail_screen.dart` (modified, adds navigation to the two new screens)
  - `docs/decisions/ADR-2026-07-19-04-...md` (this file)
  - `docs/decisions/README.md` (updated index)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (updated with the deferred work)
  - `docs/planning/coverwise_audit_task_classification_2026-07-18.md` (updated; Bucket 5 #21 marked shipped-thin-slice)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-03](./ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md) (the same ship-then-defer pattern)
  - [ADR-2026-07-19-02](./ADR-2026-07-19-02-outbox-migration-deferred.md) (the same ship-then-defer pattern)
  - `docs/audits/coverwise_architecture_audit_2026-07-18.docx` (the source audit, ADR-09)
  - `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` (the source audit, Phase 0 P0-0.4 "Not yet verified" scaffold)
- **Related code:**
  - `src/services/evidence_substrate_service.py` (the substrate's typed access layer)
  - `src/services/evidence_pipeline.py` (the 6 deterministic + 1 LLM extractor that produce the 7 fields)
  - `mobile/lib/widgets/field_citations_card.dart` (the existing substrate-grounded widget pattern that the thin slice reuses)
  - `mobile/lib/screens/policy_detail_screen.dart` (the policy detail screen that the two new screens are linked from)
- **Motto v3 alignment:** §0.1 (no parallel paths; the thin slice reuses the existing `FieldCitationsCard` pattern), §0.4 (acceptance contract; the thin slice's "not yet extracted" section is the honest contract), §0.5 (evidence tiers; the thin slice is T2-verifiable via widget tests; the full features are T0-verifiable via the launch playbook's Step 8), §0.7 (AI output boundary; the thin slice does not claim what the substrate does not know), §0.10 (observability is delivery; the "not yet extracted" section makes the substrate's limits visible at the UI layer), §0.12 (this document).
