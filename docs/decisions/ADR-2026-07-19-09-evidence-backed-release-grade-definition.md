# ADR-2026-07-19-09: "Evidence-backed" — a release-grade definition

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **"Evidence-backed" is a release-grade term with four faces: substrate, citation, answer, and UI.** Each face has a contract. An answer is "evidence-backed" if and only if all four faces pass. The four faces are defined in §"The four faces" below. The substrate face is implemented in `src/services/evidence_substrate_service.py` (already there, contract to be tightened). The citation face is implemented in `src/services/citation_verifier.py` (new). The answer face is implemented in `src/services/answer_verifier.py` (new). The UI face is implemented in `mobile/lib/widgets/field_citations_card.dart` (already there) and `mobile/lib/widgets/answer_verification_badge.dart` (new). The marketing claim "evidence-backed" is restricted to answers that pass all four faces; the launch-claim registry (T-5-14) records the claim and the tests that gate it.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** The four-face contract is the release-grade definition of "evidence-backed." The implementation work (citation verifier, answer verifier, UI badge, launch-claim registry entries) may begin in dependency order. Implementation order: substrate face tightening → citation face → answer face → UI face → launch-claim registry entries (per surface) → canonical doc update → CI gate. The launch-claim registry gains entries for the new surfaces added in revision 2 of ADR-2026-07-19-08 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault descriptions). See "Update log" below for the full decision history.
- **Related artifacts:** [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md), [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md), [ADR-2026-07-19-04](./ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md), `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` P0-12, P0-13, P0-15, P1-15.

## Update log

- **2026-07-19 (original)**: Initial proposal. The four faces (substrate, citation, answer, UI) defined. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** The operator reviewed and signed off. The wider wedge from ADR-2026-07-19-08 revision 2 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault) does not change the four-face contract — every new surface renders substrate-grounded content (observations, scenario answers, per-member observations) that is exactly the kind of "answer" the four faces are designed for. The Claim Document Vault's document tags are user-assigned or LLM-classified metadata (not claims about the policy); the tags themselves are not evidence-backed, but any auto-generated description of a document (e.g. "this is a discharge summary dated 2024-01-15") is. The launch-claim registry gains entries for each new surface; the per-surface entries are new work, not contract changes. The Family Coverage Map per-member observations depend on a substrate extension (per-member sum insured, exclusions, dependents-cant-have-policies signal); the substrate extension is a future ADR and a prerequisite for the Family surface. The four faces are the contract; the registry is the implementation.

---

## Context

The trust audit is unambiguous: "evidence-backed" is used as a marketing claim and an engineering claim and a UI claim, and it doesn't mean the same thing in any two of them. The current state, from the code archaeology pass:

- **Marketing** (e.g. `coverwise_monetization_ads_responsible_data_research_2026-07-16.md`, the launch copy, the README) says: "grounded answers," "evidence-backed," "real evidence, not vibes." No definition.
- **The substrate** (`src/services/evidence_substrate_service.py`) says: every extracted field has an `evidence_strength: float` in [0.0, 1.0]. The substrate contract is "the parser's confidence in the extracted value." No threshold for "backed."
- **The parser pipeline** (`src/services/evidence_pipeline.py`) says: a field has an `evidence_strength > 0.0` if and only if the LLM honesty check passed. A field with `evidence_strength = 0.0` is rejected. The UI excludes 0.0 fields. But "evidence_strength > 0.0" is not "evidence-backed"; it is "not zero."
- **The citation** (`src/models/rag.py::RAGCitation`) says: a citation is `(index: int >= 1, quote: str)`. There is no post-generation check that the quote is contained in the source text. The trust audit's P0-12 is exactly this: "RAGCitation validates only source index is at least 1 and quote is a string."
- **The UI** (`mobile/lib/widgets/field_citations_card.dart`) says: shows the citation card when the field has a citation. The user sees a card that says "this came from page X, paragraph Y." The user has no way to verify; the system has not verified.
- **Support** has no script for "why does this answer say X?" because the answer is not verified.

The result is: the user sees a UI that says "evidence-backed." The system has not verified. The marketing claim is not enforced. The audit's NO-GO is: "the system says one thing and does another."

This ADR defines "evidence-backed" as a release-grade term with four faces. Each face has a contract. The four faces are enforced by code, tests, and a release-claim registry. The marketing claim is restricted to answers that pass all four faces.

---

## Options considered

### Option A: Leave "evidence-backed" as a marketing term with no engineering contract. REJECTED.

- **How it works:** the marketing says "evidence-backed" and the engineering does whatever it does. The launch-claim registry is optional. The UI shows what it shows. The user trusts the brand.
- **Why rejected:** this is the failure mode the trust audit's NO-GO is specifically about. The audit's argument is correct: a marketing claim that is not enforced by the system is a lie, and a lie is worse than no claim. The first version of ADR-2026-07-19-08 (cut/keep/finish) almost did this for the Insurance Health Score and the What-If Calculator: it accepted the marketing framing and tried to make the engineering match. The cuts were the right answer for those features; for "evidence-backed" the right answer is to define the term, not to remove the claim.

### Option B: Define "evidence-backed" as a single boolean. REJECTED.

- **How it works:** every answer is either evidence-backed or not. The boolean is computed by a single verifier. The UI shows a green check or a red X. Marketing says "evidence-backed" and the boolean is the gate.
- **Why rejected:** a single boolean hides the four different things the term can mean. The substrate cares about parser confidence. The citation cares about quote-in-source. The answer cares about claim coverage. The UI cares about user-visible verification state. A single boolean collapses all four into one, and the collapse is where the lying starts. The audit's P0-12 required fix is a 5-step contract (validate source index, substring match, reject generated context, identify uncited claims, reduce confidence or abstain). A boolean is a 1-step contract. The 1-step contract is not the audit's recommendation.

### Option C: Define "evidence-backed" as a four-face contract. CHOSEN.

- **How it works:** an answer is "evidence-backed" if and only if all four faces pass: substrate face, citation face, answer face, UI face. Each face has a verifier. Each verifier is a release-claim-gated test. The marketing claim is restricted to answers that pass all four. The launch-claim registry records the claim, the four faces, the verifiers, and the tests.
- **Why chosen:** this is the audit's recommended fix, applied as a contract rather than as a single check. Each face is enforced independently. The four verifiers are the release-claim-gated tests. The marketing claim is a function of the four faces, not a separate thing.
- **Cost:** 1-2 weeks of work: the citation verifier (the audit's P0-12 fix), the answer verifier (the audit's P0-15 fix), the UI badge (small), the launch-claim registry entry (small). The substrate face is already in place; the tightening is a 0.5 day.
- **Quality:** every "evidence-backed" claim is enforced. The user can see the verification state. Support has a script. Marketing has a contract.

---

## The four faces

### Face 1: Substrate face — "the field exists in the substrate with a confidence above the threshold"

- **Definition:** an extracted field is "evidence-backed at the substrate face" if:
  1. The field exists in the substrate's `extracted_fields` table (or a successor).
  2. The field's `evidence_strength` is `>= 0.7` (the substrate threshold; defined here as the cutoff for "backed" at the substrate face).
  3. The field's `parser_version` matches the current production parser (no stale fields from a deprecated parser).
  4. The field's owner is the current principal (no cross-principal leaks; per T-8-1).
  5. The field has at least one linked `field_evidence` row (the citation pointer).
- **Verifier:** `src/services/evidence_substrate_service.py::is_substrate_backed(field_id)`. Already partially implemented; this ADR tightens the contract to include parser_version, owner, and field_evidence.
- **Threshold:** 0.7. Justification: the parser pipeline's LLM extractor produces `evidence_strength` in 0.0-1.0 with honesty checks; values below 0.7 are usually either ambiguous or LLM-honest-rejected. The 0.7 threshold is recorded in the launch-claim registry. The threshold is configurable per-field-type in a future ADR (e.g. monetary fields may want a higher threshold).
- **Failure mode:** if a field fails any of the 5 conditions, the substrate face returns False, and the field is excluded from the "evidence-backed" answer. The UI shows the field with a "not yet verified" badge (the Phase 0 P0-0.4 pattern).

### Face 2: Citation face — "the quote is actually in the source text"

- **Definition:** a citation is "evidence-backed at the citation face" if:
  1. The citation's `source_index` is in bounds (1 to N where N is the number of retrieved sources).
  2. The citation's `document_id` matches the answer's `document_id` (no cross-document citations).
  3. The citation's `quote` is contained in the immutable `source_text` of the cited page (substring match after whitespace normalization; this is the audit's P0-12 fix).
  4. The citation's `quote` is NOT contained in the `retrieval_text` (the LLM-generated context; per T-7-3, source_text and retrieval_text are separate columns, and citations to retrieval_text are rejected).
  5. The citation's `page_number` exists in the document's `page_artifacts` (the page must have been OCR'd; the citation cannot point to a page that does not exist).
- **Verifier:** `src/services/citation_verifier.py::verify_citation(citation, source_text, retrieval_text)`. New module. The audit's P0-12 5-step fix.
- **Failure mode:** if a citation fails any of the 5 conditions, the citation is rejected. The answer either drops the claim (if no other citation supports it) or marks the claim as "unsupported" (the answer face below).

### Face 3: Answer face — "every material claim has a verified citation"

- **Definition:** an answer is "evidence-backed at the answer face" if:
  1. Every material claim in the answer (a sentence or clause that states a fact about the policy) is followed by a citation marker.
  2. Every citation marker resolves to a citation that passes the citation face.
  3. The answer's `verification_status` is one of: `fully_backed` (every claim cited and verified), `partially_backed` (some claims cited and verified, some marked "unsupported"), or `abstained` (the system declines to answer because no claims can be backed).
  4. The answer never returns `verification_status = unverified` — that state is reserved for the UI badge to render a warning, and the answer text is gated to refuse to show the unverified claims.
- **Verifier:** `src/services/answer_verifier.py::verify_answer(answer_text, citations, source_text)`. New module. The audit's P0-15 fix (the eval runner is the long-term test harness; the verifier is the runtime check).
- **Failure mode:** if a claim has no citation, the answer marks it "unsupported" and reduces confidence. If a citation fails the citation face, the answer drops the claim. If every claim drops, the answer abstains.

### Face 4: UI face — "the user sees the verification state, not just the answer"

- **Definition:** a UI surface is "evidence-backed at the UI face" if:
  1. The answer text is rendered alongside a verification badge (`fully_backed` / `partially_backed` / `abstained` / `not_yet_extracted`).
  2. Each citation is rendered with: the document name, the page number, the source excerpt, an "open page" action, and the citation face's verification state.
  3. "Unsupported" claims are rendered in a visually distinct style (e.g. greyed out, with a "verify in your policy" label) — not as if they were verified.
  4. The UI never renders a number, a fact, or a recommendation as "verified" without the badge.
- **Verifier:** widget tests in `mobile/test/field_citations_card_test.dart` (already there for the citation card; this ADR adds the badge test) and `mobile/test/answer_verification_badge_test.dart` (new).
- **Failure mode:** if the UI renders a claim as verified without the badge, the UI face fails. The release-claim-gated test catches this.

### Composite: "evidence-backed" = substrate ∧ citation ∧ answer ∧ UI

- **Definition:** an answer is "evidence-backed" if and only if all four faces pass.
- **Marketing claim:** the marketing claim "evidence-backed" is restricted to answers with `verification_status = fully_backed`. The launch-claim registry records the claim and links to the four verifiers.
- **Partial state:** `partially_backed` is NOT "evidence-backed." The UI renders it as "some of this answer is verified, some is not." The marketing does not claim it.
- **Abstain state:** `abstained` is "the system declined to answer." The UI renders the reason. The marketing does not claim it.

---

## Chosen path

**The four-face contract is the release-grade definition of "evidence-backed."** The four verifiers are the runtime checks. The four verifiers are the release-claim-gated tests. The marketing claim is a function of the four faces.

The work to implement:

1. **Tighten the substrate face** in `src/services/evidence_substrate_service.py`. Add `is_substrate_backed(field_id)` that returns True only if the 5 conditions are met. The 0.7 threshold is a constant; the parser_version, owner, and field_evidence checks are new.
2. **Implement the citation face** in `src/services/citation_verifier.py` (new). The 5 conditions are the audit's P0-12 fix. The verifier is called on every retrieved citation before the answer is generated.
3. **Implement the answer face** in `src/services/answer_verifier.py` (new). The 4 conditions are the audit's P0-15 fix (runtime). The verifier is called after the answer is generated and before the answer is returned to the client.
4. **Implement the UI face** in `mobile/lib/widgets/answer_verification_badge.dart` (new). The 4 conditions are the widget tests. The badge is rendered on every answer.
5. **Add the launch-claim registry entry** in `docs/launch_claims/evidence-backed.md` (new directory). The entry records the claim, the four faces, the verifiers, the tests, and the failure modes.
6. **Update the canonical doc** to define "evidence-backed" with the four faces. The definition is the operator-facing map; the verifiers are the implementation.
7. **Add release-claim-gated tests** in CI. The tests fail if any of the four faces regress. The CI gate is the release guard.

**Effort:** 1-2 weeks. The substrate face is a tightening. The citation face is a new module. The answer face is a new module. The UI face is a new widget + tests. The launch-claim registry is a new file. The canonical doc update is a 1-day pass. The CI gate is a 0.5 day.

**Sequence:**
1. Substrate face tightening (0.5 day, mostly the parser_version + owner + field_evidence checks).
2. Citation face module (2-3 days, the 5 conditions + tests).
3. Answer face module (2-3 days, the 4 conditions + tests, integration with the LLM answer generator).
4. UI face widget + tests (1-2 days).
5. Launch-claim registry entry (0.5 day).
6. Canonical doc update (1 day).
7. CI gate (0.5 day).

The four faces can be implemented in parallel by different engineers; the integration is the answer_verifier + UI badge. The launch happens after the CI gate is green and the launch playbook's Step 8 (real-device end-to-end) validates the four faces.

---

## Why this path

### 1st-principle argument

The marketing claim "evidence-backed" is a load-bearing promise. The user trusts the claim when they see the UI. The system must enforce the claim in code, not in copy. The four faces are the enforcement. Each face is independent; each face is testable; each face is a release gate. The composite "evidence-backed" is a function of the four faces, not a separate thing.

The same argument as ADR-2026-07-19-08: stop showing what the system does not know. The "evidence-backed" claim is the system telling the user "this is verified." If the system has not verified, the claim is a lie. The four faces are the verification.

### Anti-lying-UI argument (motto v3 §0.7, trust audit NO-GO)

The trust audit's NO-GO is about claim-shaped UI. The "evidence-backed" claim is exactly the kind of claim-shaped UI the audit flags. The four-face contract is the engineering answer to the NO-GO: the system verifies the claim, and the claim is rendered only if verified.

### Anti-single-boolean argument (motto v3 §0.5 evidence tiers)

A single boolean "evidence-backed" hides the four faces. The audit's 5-step fix for P0-12 is not a boolean; it is a contract. The four-face definition respects the audit's recommendation.

### Anti-marketing-without-engineering argument (motto v3 §0.11 customer-facing claims)

The launch-claim registry (T-5-14) is the customer's claim record. The "evidence-backed" entry in the registry is the customer's right: "this is what the term means, and these are the tests that gate it." The four faces are the tests.

### Anti-undefined-term argument (motto v3 §0.4 acceptance contract)

The acceptance contract for "ship a feature" includes "the terms the user sees are defined and enforced." "Evidence-backed" is a term the user sees. The four-face contract is the definition. The release-claim-gated test is the enforcement.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The 0.7 substrate threshold is a recommendation; the four faces are a recommendation; the launch-claim registry entry is a recommendation. The operator may disagree on the threshold, on the face definitions, or on the launch-claim registry. The reason this is an ADR and not a code change is that "evidence-backed" is a load-bearing term and the operator should sign off on its definition.

---

## Tradeoffs

- **The 0.7 threshold excludes some fields that are technically correct.** A field with `evidence_strength = 0.65` is excluded from the substrate face. The UI shows it as "not yet verified" even though the LLM honesty check passed. The mitigation is the launch-claim registry: the operator can adjust the threshold per-field-type in a future ADR.
- **The citation face's substring match is brittle.** A quote with a hyphen vs. an em-dash will fail the substring match. The mitigation is whitespace normalization + fuzzy match (the audit's P0-12 fix mentions "substring/fuzzy match"). The fuzzy match threshold is a constant; the launch-claim registry records it.
- **The answer face's "every material claim has a citation" is hard to enforce automatically.** The answer face uses a heuristic to identify material claims (sentences that state a fact, not sentences that say "let me check"). The heuristic is imperfect. The mitigation is the audit's P0-15 recommendation: the eval runner (T-7-13) is the long-term test harness; the runtime verifier is a fast check.
- **The UI face adds a badge to every answer.** The user sees more information; the screen is busier. The mitigation is the existing "not yet verified" pattern (Phase 0 P0-0.4); the badge is the same pattern, generalized.
- **The four faces add 1-2 weeks of work.** The launch slips. The operator's call. The four faces are the cost of having a load-bearing marketing claim.
- **The four faces are not the same as the eval runner.** The eval runner (T-7-13) is the long-term test harness that benchmarks the four faces against a labeled corpus. The four faces are the runtime checks. The eval runner is the test of the tests.

---

## Assumptions

- **The audit's P0-12 5-step fix is the right contract.** This ADR implements the 5 steps as the citation face. The operator may want a different contract; the ADR is the place to discuss.
- **The 0.7 substrate threshold is acceptable.** The threshold is a constant; the launch-claim registry records it. The operator may want a different threshold (e.g. 0.8 for monetary fields, 0.6 for descriptive fields).
- **The four faces are independent.** Each face has its own verifier. The composite is a function of the four. The operator may want a different composition (e.g. citation face is a precondition for substrate face). The ADR is the place to discuss.
- **The launch-claim registry is a directory in `docs/launch_claims/`.** The entry for "evidence-backed" is the first one. The pattern is reusable for "real-time," "offline-ready," "family-aware," etc. The operator may want the registry to live elsewhere; the ADR is the place to discuss.
- **The CI gate is a release-claim-gated test.** The test fails if any face regresses. The operator may want a different gate (e.g. a manual review for marketing claims). The ADR is the place to discuss.
- **The canonical doc's definition of "evidence-backed" is the four faces.** The doc update is a 1-day pass. The operator may want a different definition; the ADR is the place to discuss.

---

## Risks

- **The operator disagrees with a face.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the face definitions explicit and easy to revisit.
- **The four faces are not picked up.** 1-2 weeks of work is a lot. The mitigation is the launch-claim registry: the marketing claim cannot be made until the four faces pass.
- **The 0.7 threshold is wrong for some field types.** The mitigation is the launch-claim registry: the threshold is configurable per-field-type in a future ADR. The first version uses 0.7 for all fields.
- **The citation face's substring match is too brittle.** The mitigation is whitespace normalization + fuzzy match. The fuzzy match threshold is a constant; the launch-claim registry records it.
- **The answer face's "every material claim has a citation" is hard to enforce.** The mitigation is the audit's P0-15 recommendation: the eval runner is the long-term test harness. The runtime verifier is a fast check, not a perfect one.
- **The UI face's badge is too busy.** The mitigation is the existing "not yet verified" pattern. The badge is generalized from that pattern.
- **The launch-claim registry is not maintained.** The mitigation is the CI gate: the test fails if the registry is not updated when a face changes.

---

## Validation plan

- **For the substrate face:** unit tests in `tests/test_evidence_substrate_service.py` that assert `is_substrate_backed` returns True for a field with `evidence_strength = 0.7` and parser_version = current, and False otherwise.
- **For the citation face:** unit tests in `tests/test_citation_verifier.py` (new) that assert each of the 5 conditions is checked. The audit's P0-12 acceptance criteria: "invalid citations never render."
- **For the answer face:** unit tests in `tests/test_answer_verifier.py` (new) that assert the 4 conditions are checked. The audit's P0-15 acceptance criteria: "answer output includes a verification status."
- **For the UI face:** widget tests in `mobile/test/field_citations_card_test.dart` (extend) and `mobile/test/answer_verification_badge_test.dart` (new) that assert the badge is rendered and the verification state is shown.
- **For the launch-claim registry:** a CI test that asserts the registry entry exists and links to the four verifiers. The test fails if the entry is missing or stale.
- **For the canonical doc:** a doc-lint test that asserts the four faces are defined in the doc. The test fails if a face is missing or stale.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the four faces are implemented. The validation includes: upload policy → extract field → verify citation → verify answer → render badge → user sees verification state.

---

## Rollback or migration path

The four faces are additive. The substrate face is a tightening of an existing check. The citation face is a new module that wraps the existing retrieval. The answer face is a new module that wraps the existing answer generator. The UI face is a new widget that wraps the existing citation card.

If a face turns out to be wrong:
- The substrate face's 0.7 threshold can be raised or lowered by changing a constant.
- The citation face can be bypassed (return True for all citations) by changing a config flag; the bypass is logged.
- The answer face can be bypassed (return `fully_backed` for all answers) by changing a config flag; the bypass is logged.
- The UI face can be hidden by removing the badge widget; the marketing claim is then withdrawn.

The launch-claim registry entry is updated when a face changes. The CI gate fails if the entry is not updated.

---

## What would cause this decision to be revisited

- **The operator wants a different threshold.** The 0.7 substrate threshold is a recommendation. A future ADR can change it per-field-type.
- **The audit's P0-12 fix is updated.** If the audit's recommended contract changes, the citation face changes. The launch-claim registry entry is updated.
- **The eval runner (T-7-13) lands and benchmarks the four faces against a labeled corpus.** The thresholds are adjusted based on the benchmark. The launch-claim registry entry is updated.
- **The market changes.** A competitor claims "evidence-backed" without the four faces. The operator may decide to drop the claim. The marketing claim is a function of the four faces, not a separate thing.
- **The substrate grows to include new field types.** The 0.7 threshold may need to be adjusted per-field-type. The launch-claim registry entry is updated.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `src/services/evidence_substrate_service.py` (tighten `is_substrate_backed`)
  - `src/services/citation_verifier.py` (new, the 5 conditions)
  - `src/services/answer_verifier.py` (new, the 4 conditions)
  - `mobile/lib/widgets/answer_verification_badge.dart` (new, the badge widget)
  - `tests/test_evidence_substrate_service.py` (extend, the 5 conditions)
  - `tests/test_citation_verifier.py` (new, the 5 conditions)
  - `tests/test_answer_verifier.py` (new, the 4 conditions)
  - `mobile/test/field_citations_card_test.dart` (extend, the badge)
  - `mobile/test/answer_verification_badge_test.dart` (new, the badge)
  - `docs/launch_claims/evidence-backed.md` (new, the registry entry)
  - `docs/launch_claims/README.md` (new, the registry index)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the four faces to the doc)
  - `.github/workflows/ci.yml` (replace, add the release-claim-gated test)
  - `docs/decisions/README.md` (add this ADR to the index)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-04](./ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md) (the "not yet extracted" pattern, the UI face's precedent)
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) (the cuts and finishes that this ADR depends on)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` P0-12, P0-13, P0-15, P1-15 (the audit findings)
  - `docs/audits/coverwise_product_strategy_monetization_scope_compliance_marketing_audit_2026-07-18.md` §P0-11, T-5-14 (the launch-claim registry)
- **Related code (current state):**
  - `src/services/evidence_substrate_service.py` (the substrate face, partial)
  - `src/services/evidence_pipeline.py` (the parser pipeline that produces `evidence_strength`)
  - `src/models/rag.py::RAGCitation` (the citation model, the citation face's input)
  - `mobile/lib/widgets/field_citations_card.dart` (the citation card, the UI face's precedent)
- **Motto v3 alignment:** §0.4 (acceptance contract; the four faces are the contract), §0.5 (evidence tiers; the four faces are the tiers), §0.7 (AI output boundary; the citation face is the engineering answer to the NO-GO), §0.11 (customer-facing claims; the launch-claim registry is the customer's claim record), §0.12 (this document).
