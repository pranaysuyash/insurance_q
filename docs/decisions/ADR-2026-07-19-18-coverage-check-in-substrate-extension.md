# ADR-2026-07-19-18: Coverage Check-in substrate extension — per-life-event fields for the "is your coverage keeping up?" tool

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Coverage Check-in tool (per ADR-2026-07-19-08 #1) requires a substrate extension.** The current 7 substrate fields do not record life-event signals (policy age, medical inflation since purchase, family size change, sum insured trend, lifestyle change). The extension adds **4 per-life-event substrate fields** to the existing `extracted_fields` table. The parser pipeline gains 2 new extractors (1 deterministic, 1 LLM with honesty check) and integrates with the user's manual life-event input. The parser pipeline bumps to v4. The four-face contract (per ADR-2026-07-19-09) applies. The Coverage Check-in tool is unblocked once the extension is in place.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Coverage Check-in tool substrate extension adds 4 per-life-event fields (`life_event_policy_age_years` computed, `life_event_medical_inflation_rate` lookup, `life_event_family_size_at_purchase` and `life_event_current_family_size` manual input) to the existing `extracted_fields` table. The parser pipeline gains 2 new extractors (1 deterministic, 1 LLM with honesty check) and integrates with the user's manual life-event input. The parser pipeline bumps to v4. The four-face contract applies to the auto-generated observations; the user-input life events are stored locally and are not substrate claims. The Coverage Check-in tool surface (per ADR-2026-07-19-08 #1) is unblocked once this ADR is implemented. The pattern follows ADR-14. Implementation may begin in dependency order: migration → policy_age computation → inflation lookup → manual input UI → tests → launch-claim registry entry → canonical doc update. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #1 (the Coverage Check-in tool that this ADR unblocks), [ADR-2026-07-19-14](./ADR-2026-07-19-14-family-coverage-map-substrate-extension.md) (the precedent: columns on `extracted_fields`, parser pipeline v2, four-face contract), [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md) (the four-face contract).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Coverage Check-in tool requires per-life-event substrate fields. 4 new columns on the existing `extracted_fields` table. 2 new parser pipeline extractors + manual life-event input. Parser pipeline v4. Four-face contract. The Coverage Check-in tool is unblocked. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Coverage Check-in tool substrate extension adds 4 per-life-event fields (`life_event_policy_age_years` computed, `life_event_medical_inflation_rate` lookup, `life_event_family_size_at_purchase` and `life_event_current_family_size` manual input) to the existing `extracted_fields` table. The parser pipeline gains 2 new extractors (1 deterministic, 1 LLM with honesty check) and integrates with the user's manual life-event input. The parser pipeline bumps to v4. The four-face contract applies to the auto-generated observations; the user-input life events are stored locally and are not substrate claims. The Coverage Check-in tool surface (per ADR-2026-07-19-08 #1) is unblocked once this ADR is implemented. The pattern follows ADR-14. Implementation may begin in dependency order: migration → policy_age computation → inflation lookup → manual input UI → tests → launch-claim registry entry → canonical doc update.


---

## Context

The Coverage Check-in tool (per ADR-2026-07-19-08 #1) is a periodic surface that helps the user notice when their coverage is keeping up with their life. The operator's per-feature thinking was: "people have an insurance but under the coverage do they know how their health fares etc? maybe to build a regular checkin tool etc."

The Check-in has two kinds of inputs:
- **Substrate-grounded observations** (auto-generated from the policy + life-event signals + inflation data). Examples: "your sum insured has not changed in 3 years, but medical inflation has been ~14% per year; your real coverage is lower than when you bought it."
- **User-input life events** (manually entered by the user). Examples: "new baby," "new job," "new house," "new diagnosis," "age change."

The current 7 substrate fields do not record life-event signals. The Check-in cannot generate the auto-observations without this data.

This ADR extends the substrate with 4 per-life-event fields. The extension is the prerequisite for the Coverage Check-in tool. The pattern follows ADR-14 (Family substrate extension) and ADR-17 (Coverage Adequacy substrate extension).

---

## The 4 per-life-event fields

| Column | Type | Extractor | Description |
|---|---|---|---|
| `life_event_policy_age_years` | INT, nullable | Deterministic (computed from `policy_start_date`) | The age of the policy in years. Computed at substrate access time, not extracted. |
| `life_event_medical_inflation_rate` | NUMERIC(5, 4), nullable | Lookup table | The medical inflation rate since the policy was purchased. Default 14% per year (Indian medical inflation average; configurable). |
| `life_event_family_size_at_purchase` | INT, nullable | Manual input | The family size when the policy was purchased. Entered by the user. |
| `life_event_current_family_size` | INT, nullable | Manual input | The current family size. Entered by the user. |

**Why these 4:** The Check-in's auto-observations are grounded in 4 inputs:
- Policy age (when was the policy bought?)
- Medical inflation since purchase (how much has the real coverage eroded?)
- Family size at purchase (how big was the family when the policy was bought?)
- Current family size (how big is the family now?)

These 4 directly answer "is your coverage keeping up with your life?" A future ADR can add more (e.g. `life_event_lifestyle_change`, `life_event_new_diagnosis`, `life_event_new_job_with_group_coverage`).

**Why a mix of computed, lookup, and manual:** Policy age is computed (no extraction needed; the substrate already has `policy_start_date`). Medical inflation is a lookup (a small table of historical inflation rates; not extracted from the policy). Family size at purchase and current family size are manual (the user knows; the policy does not).

**The manual input surface:** The Check-in tool has a small "what changed in your life?" input. The user can enter: new baby, new job, new house, new diagnosis, age change, family member added/removed. The input is stored locally on the device, encrypted with the principal encryption. The input is the user's own record; the substrate does not see it.

**The four-face contract applies:** The auto-generated observations are substrate-grounded (they cite the policy, the inflation source, the date). The user-input life events are stored locally; the four-face contract does not apply to them (they are not substrate claims). The Check-in tool's "open page" action lets the user verify the substrate-grounded observations; the user-input life events are not verifiable (they are the user's own record).

**The launch-claim registry entry:** "Coverage Check-in observations are substrate-grounded for the auto-generated observations; user-input life events are stored locally and are not substrate claims."

**The parser pipeline v4:** The current parser_version is `evidence-pipeline-v3` (per ADR-17). The new extractors are `evidence-pipeline-v4`. The pipeline runs v1, v2, v3, and v4 in sequence. The v4 extractors are simpler (the deterministic policy_age is computed, the inflation is a lookup, the family size is manual input). The v4 "extractor" is mostly a UI surface (the manual input) plus a computation (policy_age from policy_start_date).

**Backward compatibility:** The new columns are nullable. The Check-in tool shows a "not yet entered" honest-empty state for existing documents until the user enters life events.

**Effort:** S-M. 1-2 weeks (4 columns + policy_age computation + inflation lookup + manual input UI + tests + launch-claim registry entry + canonical doc update).

**Anything else flagged:** The "substrate extension" pattern is now well-established. The 3 substrate extensions (Family, Coverage Adequacy, Coverage Check-in) together with the Claim Document Vault substrate extension form the substrate's per-scenario, per-life-event, per-document coverage.

**The privacy policy for the Coverage Check-in tool:** The user's life events (new baby, new diagnosis, etc.) are sensitive personal data. The privacy policy: the events are stored locally on the device, encrypted with the principal encryption, never shared with anyone. The future ADR "Coverage Check-in privacy policy" will formalize this. The pattern is the same as ADR-15: consent + retention + encryption + access rules + user's right to export/delete + no-share.
