# ADR-2026-07-19-14: Family Coverage Map substrate extension — per-member sum insured, per-member exclusions, dependents-can't-have-policies signal

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Family Coverage Map (per ADR-2026-07-19-08 #6) requires a substrate extension.** The current `policyHolders` field in the substrate is per-policy, not per-member: it lists who is on a policy but does not record per-member sum insured, per-member exclusions, or whether a member can have their own policy (a "dependents" signal). The extension adds three per-member substrate fields: `member_sum_insured`, `member_exclusions`, `member_can_have_own_policy`. The extension is implemented as new columns on the existing `extracted_fields` table (no schema migration to a new table; the columns are nullable for fields that don't apply to the current 7 fields). The parser pipeline gains three new deterministic extractors (one per field) and one LLM extractor for the complex `member_exclusions` field, all with the LLM honesty check from ADR-2026-07-19-07. The Family Coverage Map surface (per ADR-2026-07-19-08 #6) is unblocked once the extension is in place.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** The Family Coverage Map substrate extension adds three per-member fields (`member_sum_insured`, `member_exclusions`, `member_can_have_own_policy`) to the existing `extracted_fields` table. The parser pipeline gains three new extractors and bumps to v2. The four-face contract applies. The launch-claim registry entry is "per-member fields are substrate-grounded, evidence-backed, and verified by the four-face contract." The Family Coverage Map surface (per ADR-08 #6) is unblocked once this ADR is implemented. Implementation may begin in dependency order: migration → simplest extractors → LLM extractor → parser pipeline v2 → tests → launch-claim registry entry → canonical doc update. The "substrate extension" pattern is reusable for future ADRs (Coverage Adequacy per-scenario, Coverage Check-in per-life-event, Claim Document Vault per-document). See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #6 (the Family Coverage Map that this ADR unblocks), [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md) (the four-face contract that the new fields must satisfy), [ADR-2026-07-19-11](./ADR-2026-07-19-11-substrate-as-primary-deliverable.md) (the substrate visibility that the Family Coverage Map renders), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Family Coverage Map requires per-member substrate fields (sum insured, exclusions, dependents signal). The extension is implemented as new columns on the existing `extracted_fields` table. The parser pipeline gains three new extractors. The Family Coverage Map is unblocked. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The three-column extension is the contract. The "substrate extension" pattern is reusable for future ADRs (Coverage Adequacy per-scenario, Coverage Check-in per-life-event, Claim Document Vault per-document). Implementation order: migration → simplest extractors → LLM extractor → parser pipeline v2 → tests → launch-claim registry entry → canonical doc update.

---

## Context

The Family Coverage Map (per ADR-2026-07-19-08 #6) shows the user how each family member is covered by each of the user's policies. The operator's per-feature thinking emphasized two things:

1. **"I have a family floater; I should know how each member is covered."** The family floater is a single policy that covers multiple members with a shared sum insured. The user needs to know: which members are on the floater, what the effective per-member sum insured is (the shared sum insured divided by the number of members, or the floater's per-member sub-limit if specified), and what the per-member exclusions are.
2. **"My dependents can't have their own policies."** Some family members (minors, elderly, disabled) cannot easily get their own insurance. The product should signal this: "your 8-year-old cannot get their own health insurance; they must be on a family floater or a parent-sponsored policy."

The current substrate does not record this data. The `policyHolders` field is a list of names; the per-member sum insured is not recorded; the per-member exclusions are not recorded; the "can this member have their own policy" signal is not recorded. The Family Coverage Map cannot be built on the current substrate.

This ADR extends the substrate with three new fields. The extension is the prerequisite for the Family Coverage Map surface.

---

## Options considered

### Option A: Add new columns to the existing `extracted_fields` table. CHOSEN.

- **How it works:** the `extracted_fields` table (already in `supabase/migrations/2026_07_18_evidence_substrate.sql`) gains three new nullable columns: `member_sum_insured`, `member_exclusions`, `member_can_have_own_policy`. The columns are nullable because the fields don't apply to the current 7 fields (policy_number, policy_holder_name, sum_insured, policy_start_date, premium_amount, insurer_name, room_rent_cap). The columns are populated when the parser pipeline extracts the new fields from a policy document.
- **Why chosen:** the existing table is the substrate. Adding columns is the standard substrate extension. The alternative (a new table) adds join complexity and breaks the existing queries.
- **Cost:** M. 1-2 weeks. The migration, the parser pipeline changes, the tests.
- **Quality:** the substrate is extended; the Family Coverage Map is unblocked; the existing substrate is unchanged.

### Option B: Add a new `member_coverages` table. REJECTED.

- **How it works:** a new table `member_coverages` with columns `(member_id, policy_id, sum_insured, exclusions, can_have_own_policy)`. The Family Coverage Map joins this table to the substrate's `policyHolders`.
- **Why rejected:** the new table is a separate concern from the substrate. The substrate is the source of truth; the new table is a derived view. The join complexity is unnecessary. The substrate can hold the per-member fields directly.
- **Cost:** similar to option A, but with more code and more migrations.

### Option C: Store per-member data in JSONB on the existing `extracted_fields` table. REJECTED.

- **How it works:** add a single `member_data` JSONB column. The JSON holds the per-member fields.
- **Why rejected:** the audit's P0-7 (per the API audit) is "Normalise first-class fields into columns; reserve bounded JSON for true extension metadata." Per-member data is first-class; it should be columns, not JSONB. The JSONB approach also breaks the four-face contract (ADR-2026-07-19-09) because the JSONB payload is not a typed substrate field.

---

## The substrate extension

### Three new columns on `extracted_fields`

| Column | Type | Nullable | Description |
|---|---|---|---|
| `member_sum_insured` | NUMERIC(12, 2) | Yes | The per-member sum insured for a family floater. NULL for non-floater policies or for the primary holder. |
| `member_exclusions` | JSONB | Yes | A list of per-member exclusions (e.g. "dental", "maternity", "pre-existing diabetes"). NULL when no per-member exclusions. The JSONB shape is `{"exclusions": [{"type": "dental", "evidence_page": 4, "evidence_quote": "..."}]}`. |
| `member_can_have_own_policy` | BOOLEAN | Yes | Whether the member can have their own policy. NULL when not applicable (e.g. for the primary holder). FALSE for minors, elderly, disabled; TRUE for adults with no special circumstances. |

The columns are nullable because the existing 7 fields don't have per-member data. The columns are populated when the parser pipeline extracts them from a policy document.

### Three new parser pipeline extractors

1. **`MemberSumInsuredExtractor`** (deterministic regex). The extractor parses the policy text for patterns like "per member sum insured: ₹X" or "sub-limit per member: ₹X" or "floater per member: ₹X". The regex is policy-document-aware (Indian English, common Indian insurer formats). The honesty check is the substring match from the audit's P0-12.
2. **`MemberExclusionsExtractor`** (LLM with honesty check). The extractor uses the LLM to identify per-member exclusions. The LLM is prompted to cite the page and quote for each exclusion. The honesty check rejects the extraction if the citation is not in the source text. The JSONB shape is enforced.
3. **`MemberCanHaveOwnPolicyExtractor`** (deterministic rules). The extractor uses simple rules: if the member is a minor (age < 18) or elderly (age > 65) or has a disability indicator, the field is FALSE. The rules are conservative: the field is TRUE only when the member is an adult with no special circumstances. The honesty check is a manual review (the LLM honesty check is not applicable to deterministic rules).

### The four-face contract applies to the new fields

- **Substrate face (ADR-2026-07-19-09 face 1):** the new fields have an `evidence_strength` (already on the `extracted_fields` table) and a `parser_version`. The substrate face tightening (per ADR-2026-07-19-09) includes the new fields.
- **Citation face (ADR-2026-07-19-09 face 2):** the new fields have citations. The citation verifier (per ADR-2026-07-19-09) checks the citations against the source text.
- **Answer face (ADR-2026-07-19-09 face 3):** any answer that uses the new fields (e.g. "your mother's per-member sum insured is ₹X") is verified by the answer verifier. The Family Coverage Map observations are exactly the kind of "answer" the answer face is designed for.
- **UI face (ADR-2026-07-19-09 face 4):** the Family Coverage Map renders the new fields with a verification badge. The "open page" action (per ADR-2026-07-19-11) lets the user verify the citation.

### The parser_version is bumped

- The current parser_version is `evidence-pipeline-v1`. The new extractors are `evidence-pipeline-v2`. The substrate records the parser_version per field; the substrate face tightening (per ADR-2026-07-19-09) rejects fields from deprecated parsers.
- The migration adds the new columns; the parser pipeline bump is a code change. Existing fields keep their `parser_version`; new fields are `v2`.

### Backward compatibility

- The new columns are nullable. Existing fields (the 7 from the current substrate) are not affected.
- The Family Coverage Map checks for the new fields' presence before rendering. If the fields are absent (e.g. the policy was parsed by `v1`), the Family Coverage Map shows a "not yet extracted" honest-empty state (per the Phase 0 P0-0.4 pattern).
- The parser pipeline runs `v1` and `v2` in sequence: `v1` for the existing 7 fields, `v2` for the new 3 fields. Re-processing an existing document with `v2` is a manual operation (the operator triggers it via the operator CLI per ADR-2026-07-19-12).

---

## Chosen path

**Option A: three new columns on the existing `extracted_fields` table.** The extension is the prerequisite for the Family Coverage Map. The parser pipeline gains three new extractors. The four-face contract applies.

**Work to implement:**

1. **Migration** — add three new columns to `extracted_fields`. Effort: S. 0.5 day.
2. **`MemberSumInsuredExtractor`** — deterministic regex. Effort: M. 1-2 days (the regex is policy-document-aware).
3. **`MemberExclusionsExtractor`** — LLM with honesty check. Effort: M. 2-3 days (the LLM prompt, the JSONB shape enforcement, the honesty check).
4. **`MemberCanHaveOwnPolicyExtractor`** — deterministic rules. Effort: S. 1 day (the rules are conservative; the manual review process is the safeguard).
5. **Parser pipeline v2** — bump the parser_version, run v1 and v2 in sequence. Effort: S. 1-2 days.
6. **Tests** — unit tests for each extractor, integration tests for the parser pipeline, the four-face tests. Effort: M. 2-3 days.
7. **Launch-claim registry entry** — "per-member fields are substrate-grounded, evidence-backed, and verified by the four-face contract." Effort: S. 0.5 day.
8. **Canonical doc update** — define the three new fields, the parser pipeline v2, the Family Coverage Map's dependency. Effort: S. 0.5 day.

**Total effort:** M. 2-3 weeks.

**Sequence:**

1. Migration (the foundation).
2. `MemberSumInsuredExtractor` (the simplest extractor first).
3. `MemberCanHaveOwnPolicyExtractor` (the second simplest).
4. `MemberExclusionsExtractor` (the LLM extractor, depends on the LLM honesty check from ADR-2026-07-19-07).
5. Parser pipeline v2 (the integration).
6. Tests (the verification).
7. Launch-claim registry entry + canonical doc update (the record).

**Dependency:** the Family Coverage Map surface (per ADR-2026-07-19-08 #6) is unblocked after this ADR is implemented. The Family Coverage Map is a separate workstream that depends on this ADR.

---

## Why this path

### 1st-principle argument

The user has a family. The user has a family floater. The user does not know how each member is covered. The substrate is the source of truth; the substrate must record the per-member data. The extension is the foundation; the Family Coverage Map is the application.

The same argument as the trust audit's NO-GO: the substrate must record what the system claims. A Family Coverage Map that shows "your mother's per-member sum insured is ₹X" without the substrate recording the per-member sum insured is a lying UI. The extension is the substrate's response.

### Anti-lying-UI argument (motto v3 §0.7)

The Family Coverage Map cannot ship without the substrate extension. Shipping it without the extension would mean: the system shows per-member data that the substrate does not have. The system is fabricating. The audit's NO-GO is exactly this.

### Anti-JSONB argument (audit P0-7, API audit)

Per-member data is first-class. First-class data goes in columns, not JSONB. The audit's P0-7 is explicit: "Normalise first-class fields into columns; reserve bounded JSON for true extension metadata." The columns are the right place.

### Anti-new-table argument (motto v3 §0.1, no parallel paths)

A new `member_coverages` table is a parallel system. The substrate is the source of truth. The new table is a derived view. The parallel system is unnecessary. The columns are the right place.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The three-column extension is a recommendation. The operator may want a different shape (e.g. a separate table, a JSONB column, a different set of fields). The reason this is an ADR and not a code change is that the substrate extension is load-bearing and the operator should sign off on it.

---

## Tradeoffs

- **The new columns are nullable for the existing 7 fields.** The existing data does not have per-member data. The Family Coverage Map shows a "not yet extracted" state for existing documents until the document is re-processed with `v2`. The mitigation is the manual re-process via the operator CLI.
- **The `member_exclusions` JSONB shape is bounded.** The shape is `{"exclusions": [{"type": "dental", "evidence_page": 4, "evidence_quote": "..."}]}`. The shape is enforced by the parser pipeline. The mitigation is the parser pipeline rejects malformed JSONB.
- **The `member_can_have_own_policy` rules are conservative.** The rules say FALSE for minors, elderly, disabled. The rules say TRUE only for adults with no special circumstances. The rules may be wrong for some edge cases (e.g. a 17-year-old employed and eligible for their own policy). The mitigation is the manual review process; the operator can override.
- **The parser pipeline v2 is a breaking change for any code that reads `parser_version`.** The code must handle both `v1` and `v2`. The mitigation is the parser pipeline runs both; the code is updated to handle both.
- **The Family Coverage Map depends on the extension.** The Family Coverage Map is blocked until this ADR is implemented. The mitigation is the Family Coverage Map is a separate workstream; the extension is the prerequisite.
- **The extension is 2-3 weeks of work.** The launch slips. The operator's call. The extension is the cost of having a Family Coverage Map that is honest.

---

## Assumptions

- **The three fields (member_sum_insured, member_exclusions, member_can_have_own_policy) are the right set for the launch.** A future ADR can add more fields (e.g. member_premium, member_renewal_date). The three fields are the minimum for the Family Coverage Map.
- **The deterministic regex for `member_sum_insured` is sufficient.** LLM extraction is not needed for this field; the patterns are common enough for a regex. The operator may want LLM extraction; the ADR is the place to discuss.
- **The LLM honesty check (per ADR-2026-07-19-07) applies to `member_exclusions`.** The LLM is prompted to cite the page and quote; the honesty check rejects the extraction if the citation is not in the source text. The operator may want a different approach (e.g. a separate LLM for verification); the ADR is the place to discuss.
- **The deterministic rules for `member_can_have_own_policy` are sufficient.** The rules are conservative. The operator may want a more sophisticated approach (e.g. an LLM that considers more context); the ADR is the place to discuss.
- **The parser pipeline v2 is the right name.** The operator may want a different naming convention; the ADR is the place to discuss.

---

## Risks

- **The operator disagrees with the field set.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the three fields explicit and easy to revisit.
- **The deterministic regex for `member_sum_insured` is brittle.** Insurance documents have many formats. The regex may miss valid patterns. The mitigation is the parser pipeline logs missed patterns; the operator can update the regex; the LLM extractor is a fallback for missed patterns.
- **The LLM extractor for `member_exclusions` is hallucinating.** The LLM may invent exclusions that are not in the policy. The mitigation is the LLM honesty check; the audit's P0-12 fix (per ADR-2026-07-19-09) is the foundation.
- **The deterministic rules for `member_can_have_own_policy` are wrong.** The rules may be too conservative or too permissive. The mitigation is the manual review process; the operator can override.
- **The Family Coverage Map is delayed.** The extension is 2-3 weeks. The Family Coverage Map is blocked. The mitigation is the Family Coverage Map is a separate workstream; the extension is the prerequisite.

---

## Validation plan

- **For the migration:** a migration test that asserts the three new columns exist with the right types and nullability.
- **For `MemberSumInsuredExtractor`:** a unit test that asserts the regex extracts the right values from sample policy documents. The samples are real Indian insurance documents (anonymized).
- **For `MemberExclusionsExtractor`:** a unit test that asserts the LLM extractor cites the right page and quote. The honesty check rejects the extraction if the citation is not in the source text.
- **For `MemberCanHaveOwnPolicyExtractor`:** a unit test that asserts the rules produce the right values for sample member profiles (minor, elderly, disabled, adult with no special circumstances).
- **For the parser pipeline v2:** an integration test that asserts the parser pipeline runs `v1` and `v2` in sequence, the new fields are populated, the `parser_version` is correct.
- **For the four-face contract:** the new fields are subject to the substrate, citation, answer, and UI faces (per ADR-2026-07-19-09). The launch-claim registry entry tests this.
- **For the launch-claim registry:** a CI test that asserts the entry exists and links to the tests.
- **For the canonical doc:** a doc-lint test that asserts the three new fields are defined.
- **End-to-end:** the Family Coverage Map (per ADR-2026-07-19-08 #6) runs after this ADR is implemented. The validation includes: user uploads policy → parser pipeline v2 extracts per-member data → Family Coverage Map renders per-member observations → user opens the page → user verifies the citation.

---

## Rollback or migration path

The extension is additive. The new columns are nullable. The parser pipeline v2 is a code change that runs alongside v1. The Family Coverage Map is a separate workstream that depends on the extension.

If the extension turns out to be wrong:
- The migration can be reversed (the columns are dropped). The existing 7 fields are unaffected.
- The parser pipeline v2 can be disabled (the new extractors are not run). The new fields are not populated; the Family Coverage Map shows the "not yet extracted" state.
- The Family Coverage Map can be hidden (the surface is not rendered).

The launch-claim registry entry is updated when the extension changes. The CI gate fails if the entry is not updated.

---

## What would cause this decision to be revisited

- **The operator wants a different field set.** A future ADR can add or remove fields. The columns are the source of truth.
- **The Family Coverage Map is redesigned.** A future ADR can change the Family Coverage Map's requirements, which may require different or additional fields.
- **The parser pipeline is rewritten.** A future ADR can replace the deterministic + LLM extractors with a different approach. The columns are unchanged.
- **A regulator requires additional fields.** A future ADR can add regulator-mandated fields. The columns are extensible.
- **The market changes.** A competitor offers a different family-coverage feature. The operator may decide to add or remove fields. The columns are the source of truth.

---

## Anything else? (operator's standing review prompt)

The Family Coverage Map substrate extension raises a more general question: **what other per-member, per-policy, or per-scenario fields does the substrate need?** The pattern is: when a new surface requires data the substrate does not have, the substrate is extended. The extension is a substrate ADR, not a per-surface ADR.

- **Per-scenario fields for Coverage Adequacy (per ADR-2026-07-19-08 #2).** The Coverage Adequacy tool asks "am I covered for scenario X?" The substrate needs per-scenario fields: `scenario_maternity_covered`, `scenario_dental_covered`, `scenario_opd_covered`, `scenario_icu_sublimit`, `scenario_day_care_covered`. The extension follows the same pattern (new columns, new extractors, four-face contract). **Future ADR: Coverage Adequacy substrate extension.** Estimated 1-2 weeks.
- **Per-life-event fields for Coverage Check-in (per ADR-2026-07-19-08 #1).** The Coverage Check-in tool asks "is your coverage keeping up with your life?" The substrate needs life-event signals: `policy_age_years`, `medical_inflation_since_purchase`, `family_size_change`, `sum_insured_per_member_trend`. The extension follows the same pattern. **Future ADR: Coverage Check-in substrate extension.** Estimated 1-2 weeks.
- **Per-document fields for Claim Document Vault (per ADR-2026-07-19-08 #3).** The Claim Document Vault stores claim paperwork. The substrate needs per-document fields: `document_type`, `document_date`, `document_issuer`, `document_amount`. The extension follows the same pattern. **Future ADR: Claim Document Vault substrate extension.** Estimated 1 week.

The pattern is reusable: any new surface that requires data the substrate does not have triggers a substrate-extension ADR. The extensions are the foundation; the surfaces are the application. The four-face contract applies to all extensions.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `supabase/migrations/2026_07_19_family_coverage_substrate.sql` (new: the three new columns)
  - `src/services/evidence_pipeline.py` (extend: the three new extractors; parser pipeline v2)
  - `src/extractors/member_sum_insured_extractor.py` (new: the deterministic regex extractor)
  - `src/extractors/member_exclusions_extractor.py` (new: the LLM extractor)
  - `src/extractors/member_can_have_own_policy_extractor.py` (new: the deterministic rules extractor)
  - `tests/test_member_sum_insured_extractor.py` (new)
  - `tests/test_member_exclusions_extractor.py` (new)
  - `tests/test_member_can_have_own_policy_extractor.py` (new)
  - `tests/test_parser_pipeline_v2.py` (new: the integration test)
  - `tests/test_family_coverage_substrate_extension.py` (new: the migration test)
  - `docs/launch_claims/family-coverage-substrate-extension.md` (new: the launch-claim registry entry)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the three new fields to the doc)
  - `docs/decisions/README.md` (add this ADR to the index)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #6 (the Family Coverage Map that this ADR unblocks)
  - [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md) (the four-face contract that the new fields must satisfy)
  - [ADR-2026-07-19-11](./ADR-2026-07-19-11-substrate-as-primary-deliverable.md) (the substrate visibility that the Family Coverage Map renders)
  - [ADR-2026-07-19-07](./ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md) (the LLM honesty check that the new extractors use)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` P0-07 (the evidence-aware field model that the new fields extend)
  - `docs/audits/coverwise_api_domain_data_consistency_integration_audit_2026-07-18.md` P0-07 (the normalised columns vs JSONB rule)
- **Related code (current state):**
  - `supabase/migrations/2026_07_18_evidence_substrate.sql` (the substrate table that the new columns extend)
  - `src/services/evidence_pipeline.py` (the parser pipeline that gains the new extractors)
  - `src/services/evidence_substrate_service.py` (the substrate access layer that the new fields use)
- **Motto v3 alignment:** §0.1 (no parallel paths; the new columns are the single substrate), §0.4 (acceptance contract; the Family Coverage Map is honest because the substrate is extended), §0.5 (evidence tiers; the new fields are T2-verifiable via the four-face contract), §0.7 (AI output boundary; the LLM honesty check applies to the new extractors), §0.12 (this document).
