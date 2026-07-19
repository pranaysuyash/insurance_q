# ADR-2026-07-19-17: Coverage Adequacy substrate extension — per-scenario fields for the "am I covered for X?" tool

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Coverage Adequacy tool (per ADR-2026-07-19-08 #2) requires a substrate extension.** The current 7 substrate fields do not record per-scenario data (maternity covered, dental covered, OPD covered, ICU sublimit, day-care covered, pre-existing disease waiting period, network hospital list). The extension adds **7 per-scenario substrate fields** to the existing `extracted_fields` table. The parser pipeline gains 7 new extractors (4 deterministic regex, 3 LLM with honesty check). The parser pipeline bumps to v3. The four-face contract (per ADR-2026-07-19-09) applies. The Coverage Adequacy tool is unblocked once the extension is in place.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Coverage Adequacy tool substrate extension adds 7 per-scenario fields (`scenario_maternity_covered`, `scenario_dental_covered`, `scenario_opd_covered`, `scenario_day_care_covered`, `scenario_icu_sublimit`, `scenario_pre_existing_disease_waiting_period_days`, `scenario_network_hospital_list_url`) to the existing `extracted_fields` table. The parser pipeline gains 7 new extractors and bumps to v3. The four-face contract applies. The Coverage Adequacy tool surface (per ADR-2026-07-19-08 #2) is unblocked once this ADR is implemented. The launch-claim registry entry is "per-scenario fields are substrate-grounded, evidence-backed, and verified by the four-face contract." The pattern follows ADR-14 (Family substrate extension). Implementation may begin in dependency order: migration → 4 deterministic regex extractors → 3 LLM extractors → parser pipeline v3 → tests → launch-claim registry entry → canonical doc update. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #2 (the Coverage Adequacy tool that this ADR unblocks), [ADR-2026-07-19-14](./ADR-2026-07-19-14-family-coverage-map-substrate-extension.md) (the precedent: columns on `extracted_fields`, parser pipeline v2, four-face contract), [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md) (the four-face contract).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Coverage Adequacy tool requires per-scenario substrate fields. 7 new columns on the existing `extracted_fields` table. 7 new parser pipeline extractors. Parser pipeline v3. Four-face contract. The Coverage Adequacy tool is unblocked. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Coverage Adequacy tool substrate extension adds 7 per-scenario fields (`scenario_maternity_covered`, `scenario_dental_covered`, `scenario_opd_covered`, `scenario_day_care_covered`, `scenario_icu_sublimit`, `scenario_pre_existing_disease_waiting_period_days`, `scenario_network_hospital_list_url`) to the existing `extracted_fields` table. The parser pipeline gains 7 new extractors and bumps to v3. The four-face contract applies. The Coverage Adequacy tool surface (per ADR-2026-07-19-08 #2) is unblocked once this ADR is implemented. The launch-claim registry entry is "per-scenario fields are substrate-grounded, evidence-backed, and verified by the four-face contract." The pattern follows ADR-14 (Family substrate extension). Implementation may begin in dependency order: migration → 4 deterministic regex extractors → 3 LLM extractors → parser pipeline v3 → tests → launch-claim registry entry → canonical doc update.


---

## Context

The Coverage Adequacy tool (per ADR-2026-07-19-08 #2) answers "am I covered for scenario X?" for user-picked scenarios (C-section, knee replacement, day-care procedures, ICU, dental, maternity, OPD, pre-existing disease, etc.). The operator's per-feature thinking was: "what if scenarios that the user wants to know if he has enough coverage or not etc."

The current 7 substrate fields do not record per-scenario data. The substrate knows the user's sum insured, room rent cap, insurer, etc. — but it does not know whether the user's policy covers maternity, dental, OPD, ICU sublimit, day-care procedures, pre-existing disease waiting period, or the network hospital list. The Coverage Adequacy tool cannot answer the user's question without this data.

This ADR extends the substrate with 7 per-scenario fields. The extension is the prerequisite for the Coverage Adequacy tool. The pattern follows ADR-2026-07-19-14 (Family substrate extension): new columns on `extracted_fields`, new extractors, four-face contract.

---

## The 7 per-scenario fields

| Column | Type | Extractor | Description |
|---|---|---|---|
| `scenario_maternity_covered` | BOOLEAN, nullable | Deterministic regex | Whether maternity is covered. NULL when not mentioned. |
| `scenario_dental_covered` | BOOLEAN, nullable | Deterministic regex | Whether dental is covered. |
| `scenario_opd_covered` | BOOLEAN, nullable | Deterministic regex | Whether OPD is covered. |
| `scenario_day_care_covered` | BOOLEAN, nullable | Deterministic regex | Whether day-care procedures are covered. |
| `scenario_icu_sublimit` | NUMERIC(12, 2), nullable | LLM with honesty check | The ICU sublimit (e.g. 2% of sum insured, capped at ₹X). NULL when no sublimit. |
| `scenario_pre_existing_disease_waiting_period_days` | INT, nullable | LLM with honesty check | The pre-existing disease waiting period in days (e.g. 730 days = 2 years, 1095 days = 3 years, 1460 days = 4 years). NULL when not mentioned. |
| `scenario_network_hospital_list_url` | TEXT, nullable | LLM with honesty check | The URL of the network hospital list. NULL when not in the policy. |

**Why these 7:** The user's most-asked coverage questions are: "am I covered for X?" (maternity, dental, OPD, day-care), "what's the ICU limit?" (ICU sublimit), "how long is the waiting period?" (pre-existing disease waiting period), "where can I go?" (network hospital list). These 7 fields directly answer the questions. A future ADR can add more (e.g. `scenario_organ_donor_covered`, `scenario_ayush_covered`, etc.).

**Why a mix of deterministic regex and LLM:** Boolean "is X covered?" questions are usually answered with a clear "yes" or "no" or "excluded" in the policy text; a deterministic regex is sufficient. Numeric "what's the limit?" or URL "where's the list?" questions are more complex (the policy may use natural-language phrasing like "ICU charges are limited to 2% of the sum insured or ₹1 lakh, whichever is lower"); an LLM with honesty check is the right tool.

**The four-face contract applies:** The new fields have an `evidence_strength`, a `parser_version`, and citations. The substrate face, citation face, answer face, and UI face (per ADR-2026-07-19-09) all check the new fields.

**The launch-claim registry entry:** "per-scenario fields are substrate-grounded, evidence-backed, and verified by the four-face contract."

**The parser pipeline v3:** The current parser_version is `evidence-pipeline-v2` (per ADR-14). The new extractors are `evidence-pipeline-v3`. The pipeline runs v1, v2, and v3 in sequence. Re-processing existing documents with v3 is a manual operation via the operator CLI (per ADR-12).

**Backward compatibility:** The new columns are nullable. The Coverage Adequacy tool shows a "not yet extracted" honest-empty state for existing documents until the document is re-processed with v3.

**Effort:** M. 2-3 weeks (migration + 7 extractors + parser pipeline v3 + tests + launch-claim registry entry + canonical doc update).

**Anything else flagged:** The "substrate extension" pattern (per ADR-14) is now well-established. Coverage Check-in substrate extension (per ADR-08 #1) and Claim Document Vault substrate extension (per ADR-08 #3) follow the same pattern. The 3 substrate extensions together form the substrate's per-scenario, per-life-event, per-document coverage.

**The privacy policy for the Coverage Adequacy tool (per ADR-15's "anything else?"):** The user's scenario picks (C-section, knee replacement, etc.) are sensitive personal data (the user is interested in a specific medical event). The privacy policy: the picks are stored locally on the device, encrypted with the principal encryption, never shared with anyone. The future ADR "Coverage Adequacy privacy policy" will formalize this. The pattern is the same as ADR-15: consent + retention + encryption + access rules + user's right to export/delete + no-share.
