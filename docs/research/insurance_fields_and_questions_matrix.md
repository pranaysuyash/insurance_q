# Insurance Fields & Questions Matrix — Complete Reference

> **Created:** 2026-07-25  
> **Purpose:** Single source of truth mapping every insurance type → its specific fields → what questions users ask → what we currently extract → what's missing  
> **Maintainer:** Engineering (solo founder)  
> **🔄 See also:** [`insurance_type_coverage_map.md`](./insurance_type_coverage_map.md) (summary), [`all_insurance_document_types.md`](./all_insurance_document_types.md) (codebase audit)  
> **Scope:** Indian market (IRDAI-regulated + common global formats)

---

## Table of Contents

1. [How to Read This Document](#1-how-to-read-this-document)
2. [Health Insurance](#2-health-insurance)
3. [Motor/Auto Insurance](#3-motorauto-insurance)
4. [Life Insurance](#4-life-insurance)
5. [Home/Property Insurance](#5-homeproperty-insurance)
6. [Travel Insurance](#6-travel-insurance)
7. [Marine/Cargo Insurance](#7-marinecargo-insurance)
8. [Cyber Insurance](#8-cyber-insurance)
9. [Liability/Professional Indemnity](#9-liabilityprofessional-indemnity)
10. [Commercial/Business Insurance](#10-commercialbusiness-insurance)
11. [Pet Insurance](#11-pet-insurance)
12. [Event Insurance](#12-event-insurance)
13. [Mobile/Device Insurance](#13-mobiledevice-insurance)
14. [Cross-Type Field Reference](#14-cross-type-field-reference)
15. [Type-Specific Question Catalog](#15-type-specific-question-catalog)
16. [Extraction Difficulty Matrix](#16-extraction-difficulty-matrix)
17. [Prioritized Build Roadmap](#17-prioritized-build-roadmap)

---

## 1. How to Read This Document

Each insurance type has a standard table with these columns:

| Column | Meaning |
|--------|---------|
| **Field** | The data field name (snake_case, matches our models) |
| **Example value** | Realistic Indian insurance example |
| **Currently extracted?** | ✅ Extracted / 🟡 Partial / ❌ Not extracted / N/A Not applicable |
| **Model location** | Which model file has this field |
| **Extraction difficulty** | Easy / Medium / Hard (see §16 for criteria) |
| **Top questions** | Common questions policyholders ask that NEED this field |

After the fields table, each type has:
- **Common clauses & wording patterns** — what the document actually says
- **Standard questions** — the top 10 questions users ask about this type
- **IRDAI / Indian-specific** — regulatory requirements
- **Extraction gotchas** — what makes this type tricky

---

## 2. Health Insurance

### 2.1 Current State

**Status:** ✅ Full support  
**Flagship type** — most common, most tested, most documentary evidence

### 2.2 Fields

| Field | Example | Extracted? | Model | Difficulty | Top Questions |
|-------|---------|:----------:|-------|:----------:|--------------|
| `policy_number` | HC-2024-12345-ABCDE | ✅ | Generic | Easy | "What's my policy number?" |
| `insurer` | ICICI Lombard | ✅ | Generic | Easy | "Who is my insurer?" |
| `insurer_helpline` | 1800-123-4567 | ✅ | Generic | Easy | "Who do I call for a claim?" |
| `insurer_email` | support@icicilombard.com | ✅ | Generic | Easy | "What's the insurer's email?" |
| `coverage_amount` | 500000 | ✅ | Generic | Medium | "What's my total coverage?" |
| `deductible` | 2500 | ✅ | Generic | Medium | "How much do I pay before coverage kicks in?" |
| `premium_amount` | 12500 | ✅ | Generic | Easy | "How much is my premium?" |
| `premium_frequency` | annually | ✅ | Generic | Easy | "How often do I pay?" |
| `effective_date` | 2026-03-01 | ✅ | Generic | Medium | "When does my policy start?" |
| `expiration_date` | 2027-02-28 | ✅ | Generic | Medium | "When does my policy expire?" |
| `key_benefits[]` | Hospitalization, Daycare, Ambulance | ✅ | Generic | Medium | "What does this policy cover?" |
| `exclusions[]` | Pre-existing diseases (1st 2 yrs), War, Nuclear | ✅ | Generic | Medium | "What's NOT covered?" |
| `waiting_periods[]` | PED waiting: 24 months, Maternity: 9 months | ✅ | Generic | Medium | "What waiting periods apply?" |
| `coverage_items[]` | Room rent: ₹5K/day, ICU: ₹15K/day | ✅ | Generic | Hard | "What are the individual coverage limits?" |
| `executive_summary[]` | 3-bullet plain-language summary | ✅ | Generic | Medium | "Give me the key facts" |
| `room_rent_cap` | 2% of sum insured, max ₹5,000/day | ✅ | Health | Medium | "Can I get a private room?" |
| `pre_existing_diseases[]` | Diabetes (24 months), Hypertension (24 months), Thyroid (12 months) | ✅ | Health | Hard | "When does my pre-existing condition get covered?" |
| `co_pay_percent` | 10.0 | ✅ | Health | Medium | "How much co-pay do I have?" |
| `network_hospitals` | 12,000+ hospitals nationwide | ✅ | Health | Medium | "Is Apollo Hospital in my network?" |
| `maternity_cover` | ₹50,000 after 9-month waiting period | ✅ | Health | Medium | "Does this cover maternity?" |
| `deductible_per_claim` | 2500.0 | ✅ | Health | Medium | "How much deductible per claim?" |
| `cumulative_bonus` | 50% increase, max 100% | ✅ | Health | Medium | "How does my No Claim Bonus work?" |
| `day_care_procedures` | 160+ day care procedures covered | ✅ | Health | Medium | "Are daycare procedures covered?" |
| `consumables_cover` | Up to ₹5,000 per claim | ✅ | Health | Medium | "Are surgical consumables covered?" |
| `ambulance_cover` | 2000.0 | ✅ | Health | Easy | "Is ambulance covered?" |
| `health_checkup_cover` | Once every 3 years, up to ₹5,000 | ✅ | Health | Medium | "Do I get free health checkups?" |
| `pre_post_hospitalization_days` | 30 days pre, 60 days post | ✅ Added 2026-07-25 | Health | Easy | "How many days before/after hospitalization are covered?" |
| `restoration_benefit` | Full SI restored once per year | ✅ Added 2026-07-25 | Health | Medium | "Does my sum insured restore after a claim?" |
| `critical_illness_list[]` | Cancer, Heart attack, Kidney failure | ✅ Added 2026-07-25 | Health | Medium | "Which critical illnesses are covered?" |
| `modern_treatment_cover` | Robotic surgery, Uterine artery embolization | ✅ Added 2026-07-25 | Health | Medium | "Does this cover modern treatments?" |
| `moratorium_period` | 5 years (IRDAI 2026) | ✅ Added 2026-07-25 | Health | Easy | "When does the no-contest period kick in?" |
| `pre_auth_time_limit` | 3 hours (IRDAI mandate) | ✅ Added 2026-07-25 | Health | Easy | "How fast must insurers approve cashless?" |

### 2.3 Fields NOT Yet Extracted

| Missing Field | Example | Difficulty | Priority | Why It Matters |
|--------------|---------|:----------:|:--------:|----------------|
| `opd_cover` | ₹5,000 per year for OPD | Medium | P2 | "Does this cover OPD visits?" |
| `dental_cover` | Not covered | Easy | P2 | "Does this cover dental?" |
| `vision_cover` | Not covered | Easy | P2 | "Does this cover vision/eyeglasses?" |
| `domiciliary_hospitalization` | Covered, max 7 days | Easy | P1 | "Can I get treated at home?" |
| `organ_transplant_cover` | Covered, up to ₹5L | Medium | P2 | "Does this cover organ transplant?" |
| `wellness_program` | Gym membership, yoga, health coaching | Medium | P3 | "Do I get wellness benefits?" |
| `cashless_vs_reimbursement` | Cashless at network, reimbursement at non-network | Easy | P2 | "Is this cashless or reimbursement?" |
| `claim_settlement_ratio` | 95.78% (ICICI Lombard) | Easy | P3 | "What's the insurer's claim settlement ratio?" |
| `network_hospital_list_url` | www.icicilombard.com/hospitals | Easy | P3 | "Where can I find the network hospital list?" |
| `sub_limits` | Room rent: 2% of SI, ICU: 4x room rent | Medium | P1 | "What are the sub-limits within my coverage?" |
| `no_claim_bonus_percent` | 50% | Medium | P1 | "How much does my NCB increase?" |

### 2.4 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Room rent cap | "Room, boarding and nursing expenses as per room rent sub-limit of 2% of sum insured" | Limits which room category you can choose |
| Pre-existing disease | "Pre-existing diseases shall be covered after a continuous waiting period of 24 months" | Waiting period before PED coverage starts |
| Co-pay | "Policyholder shall bear 10% of admissible claim amount" | You pay 10%, insurer pays 90% |
| Day care | "Day care procedures are covered as per the list of procedures" | No 24-hour hospitalization needed |
| Cumulative bonus | "For each claim-free year, sum insured increases by 10% up to 100%" | No-claim bonus increases coverage |
| Moratorium | "No policy condition shall be contested after 5 continuous years except fraud" | IRDAI 2026 mandate — no exclusions after 5 years |
| Restoration | "Sum insured shall be restored once during the policy period upon full exhaustion" | Coverage resets after a claim |
| Pre-auth time | "Cashless authorization shall be issued within 3 hours of request" | IRDAI 2026 mandate |

### 2.5 Top 10 Questions Users Ask About Health Insurance

| # | Question | Field(s) needed | Current support |
|---|----------|-----------------|:--------------:|
| 1 | "What's my total coverage / sum insured?" | `coverage_amount` | ✅ Generic |
| 2 | "Does this cover pre-existing conditions?" | `pre_existing_diseases[]`, `waiting_periods[]` | 🟡 Partial (waiting periods extracted, but PED list not reliably linked) |
| 3 | "Can I get a private room?" | `room_rent_cap` | ✅ Health model |
| 4 | "Is maternity covered?" | `maternity_cover` | ✅ Health model |
| 5 | "Which hospital is in the network?" | `network_hospitals` | ✅ Health model (text, not queryable list) |
| 6 | "How much co-pay do I have?" | `co_pay_percent` | ✅ Health model |
| 7 | "What waiting periods apply?" | `waiting_periods[]` | ✅ Generic |
| 8 | "Does this cover daycare procedures?" | `day_care_procedures` | ✅ Health model |
| 9 | "Do I get a free health checkup?" | `health_checkup_cover` | ✅ Health model |
| 10 | "What's NOT covered?" | `exclusions[]` | ✅ Generic |

### 2.6 Extraction Gotchas

- **Table-heavy formatting**: Room rent caps, co-pay tiers, and PED waiting periods are often in complex nested tables
- **Multiple schedules**: Health policies have separate benefit schedules for room rent, ICU, daycare, maternity
- **TPA involvement**: The Third-Party Administrator (TPA) details (name, phone, email) are often separate from the insurer
- **Mid-term endorsements**: Policy changes mid-term (add-ons, family additions) override the base document
- **Network hospital lists**: Often provided as separate PDFs or website URLs, not in the policy document itself
- **Waiting period semantics**: "24 months" can mean "from policy inception" or "from the date PED was diagnosed"

---

## 3. Motor/Auto Insurance

### 3.1 Current State

**Status:** ✅ Full support  
**Second most common type** — 10 motor-specific fields with `_VehicleDetailsCard`

### 3.2 Fields

| Field | Example | Extracted? | Model | Difficulty | Top Questions |
|-------|---------|:----------:|-------|:----------:|--------------|
| Generic fields (policy_number, insurer, dates, premium, etc.) | — | ✅ | Generic | Various | — |
| `vehicle_registration_number` | MH-01-AB-1234 | ✅ | Motor | Easy | "What's my vehicle registration?" |
| `VIN / chassis_number` | MABC1234567890XYZ | ✅ | Motor | Medium | "What's my chassis number?" |
| `engine_number` | E1234567890 | ✅ | Motor | Medium | "What's my engine number?" |
| `NCB_percent` | 50.0 | ✅ | Motor | Medium | "What's my No Claim Bonus?" |
| `IDV` | 550000.0 | ✅ | Motor | Medium | "What's the IDV of my vehicle?" |
| `vehicle_make_model` | Maruti Suzuki Swift VXI | ✅ | Motor | Easy | "What vehicle is insured?" |
| `vehicle_year` | 2023 | ✅ | Motor | Easy | "What year is my vehicle?" |
| `add_on_covers[]` | Zero Dep, Engine Protect, RSA | ✅ | Motor | Medium | "What add-ons do I have?" |
| `own_damage_premium` | 8200.0 | ✅ | Motor | Medium | "How much is my OD premium?" |
| `third_party_premium` | 2100.0 | ✅ | Motor | Medium | "How much is my TP premium?" |

### 3.3 Fields NOT Yet Extracted

| Missing Field | Example | Difficulty | Priority | Why It Matters |
|--------------|---------|:----------:|:--------:|----------------|
| `fuel_type` | Petrol, Diesel, CNG, Electric | Easy | P2 | "What fuel type is my vehicle?" |
| `personal_accident_cover_passenger` | ₹5,00,000 per person | Medium | P2 | "Is PA cover for passengers included?" |
| `previous_claim_history` | 0 claims in 5 years | Medium | P2 | "What's my claim history?" |
| `add_on_deductible` | Nil, ₹1,000, ₹2,500 (voluntary excess) | Easy | P2 | "Do I have a voluntary deductible?" |
| `hypothecation` | HDFC Bank | Medium | P2 | "Is this vehicle hypothecated to a bank?" |
| `depreciation` | 50% for tyres, 50% for battery | Medium | P3 | "How is depreciation calculated?" |
| `form_51_details` | Certificate of Insurance number | Medium | P2 | "What's my Certificate of Insurance number?" |

### 3.4 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| De-tariffed | "Premium is de-tariffed as per IRDAI guidelines" | Insurer can set their own rates |
| Zero Depreciation | "Zero depreciation cover — no deduction for depreciation on parts" | Full claim without depreciation deduction |
| NCB protection | "NCB protected — two claims allowed without affecting NCB" | Make 2 claims without losing no-claim bonus |
| Geographical extent | "Geographical area: India" | Coverage limited to India |
| Personal accident | "Personal accident cover for owner-driver: ₹15 lakhs" | PA cover mandated by IRDAI for own-damage policies |
| Compulsory deductible | "Compulsory deductible: ₹1,000" | Fixed amount you must pay per claim |
| Voluntary deductible | "Voluntary deductible: ₹2,500 — 10% discount on OD premium" | Higher deductible = lower premium |
| Hypothecation | "Hypothecation in favor of HDFC Bank" | Bank has ownership interest until loan repaid |

### 3.5 Top 10 Questions Users Ask About Motor Insurance

| # | Question | Field(s) needed | Current support |
|---|----------|-----------------|:--------------:|
| 1 | "Is my car insured?" | Generic presence check | ✅ |
| 2 | "Is this comprehensive or third-party only?" | `policy_type_detail` | ❌ Missing |
| 3 | "What's the IDV of my vehicle?" | `IDV` | ✅ Motor model |
| 4 | "What's my No Claim Bonus?" | `NCB_percent` | ✅ Motor model |
| 5 | "Is zero depreciation included?" | `add_on_covers[]` | ✅ Motor model |
| 6 | "Where is my vehicle covered?" | `geographical_limit` | ❌ Missing |
| 7 | "How much is my own damage premium?" | `own_damage_premium` | ✅ Motor model |
| 8 | "Is personal accident cover included?" | `personal_accident_cover_owner` | ❌ Missing |
| 9 | "What add-ons do I have?" | `add_on_covers[]` | ✅ Motor model |
| 10 | "When does my policy expire?" | `expiration_date` | ✅ Generic |

### 3.6 Extraction Gotchas

- **Form 51 (Certificate of Insurance)**: A separate legal document from the policy schedule — both have different fields
- **NCB is often expressed as text**: "50% NCB" vs "NCB rate: 0.50" vs "No claim bonus: 50%" — multiple formats
- **IDV calculation**: Often shown as a table with year-by-year IDV values
- **Add-on covers**: Listed in a separate schedule, sometimes as tick marks in a table
- **Depreciation schedule**: Separate table showing % depreciation by age and part type
- **Hypothecation clause**: Often in fine print at the bottom of the policy schedule

---

## 4. Life Insurance

### 4.1 Current State

**Status:** ✅ Full support  
16 life-specific fields with `_LifeDetailsCard`

### 4.2 Fields

| Field | Example | Extracted? | Model | Difficulty | Top Questions |
|-------|---------|:----------:|-------|:----------:|--------------|
| Generic fields | — | ✅ | Generic | Various | — |
| `life_assured_name` | Mr. Rajesh Kumar | ✅ | Life | Easy | "Who is insured under this policy?" |
| `sum_assured` | 5000000.0 | ✅ | Life | Medium | "What's my sum assured?" |
| `policy_term_years` | 20 | ✅ | Life | Medium | "How long is my policy term?" |
| `premium_paying_term_years` | 10 | ✅ | Life | Medium | "How long do I need to pay premiums?" |
| `nominee_name` | Mrs. Sunita Kumar | ✅ | Life | Easy | "Who is the nominee?" |
| `nominee_share` | 100% | ✅ | Life | Medium | "What share does each nominee get?" |
| `maturity_date` | 2044-05-31 | ✅ | Life | Medium | "When does my policy mature?" |
| `maturity_amount` | 5000000.0 | ✅ | Life | Medium | "What do I get at maturity?" |
| `accidental_death_benefit` | 2500000.0 | ✅ | Life | Medium | "Is accidental death covered?" |
| `terminal_illness_benefit` | Advance payout of 50% | ✅ | Life | Medium | "Does this cover terminal illness?" |
| `rider_details[]` | Critical Illness Rider, Waiver of Premium | ✅ | Life | Medium | "What riders do I have?" |
| `suicide_exclusion` | First 12 months | ✅ | Life | Easy | "Is suicide covered?" |
| `free_look_period` | 30 days | ✅ | Life | Easy | "Can I return the policy?" |
| `grace_period` | 30 days | ✅ | Life | Easy | "How late can I pay my premium?" |
| `surrender_value` | After 3 years, minimum GSV ₹XX | ✅ | Life | Hard | "What's my surrender value?" |
| `death_benefit_type` | Level | ✅ | Life | Medium | "Does the death benefit stay level or change?" |

### 4.3 Fields NOT Yet Extracted

| Missing Field | Example | Difficulty | Priority | Why It Matters |
|--------------|---------|:----------:|:--------:|----------------|
| `policy_type` (term/ULIP/endowment/whole life) | Term Plan | Easy | P1 | "What type of life policy is this?" |
| `premium_waiver_rider` | Waiver of premium on disability | Medium | P2 | "Is premium waived if I become disabled?" |
| `critical_illness_rider` | Covered — 12 critical illnesses | Medium | P1 | "Does my rider cover heart attack/stroke?" |
| `accidental_disability_benefit` | ₹25L for permanent total disability | Medium | P2 | "Does this cover disability from accident?" |
| `income_benefit_rider` | 10% of SA annually for 10 years | Medium | P3 | "Does this provide monthly income?" |
| `policy_loan_clause` | Loan available after 3 years at 9.5% p.a. | Hard | P3 | "Can I take a loan against my policy?" |
| `revival_clause` | Revival within 2 years with arrears + interest | Medium | P2 | "Can I revive a lapsed policy?" |
| `paid_up_value` | SA pro-rated based on premiums paid | Hard | P2 | "What's my paid-up value if I stop paying?" |
| `assignment_clause` | Policy can be assigned to a bank | Medium | P3 | "Can I assign this policy as collateral?" |
| `smoking_status` | Non-smoker | Easy | P2 | "Was the premium rated based on smoking?" |
| `date_of_birth` | 15-Aug-1985 | Easy | P2 | "Is the age correct on this policy?" |
| `profession_risk_class` | Standard / Preferred / High Risk | Easy | P3 | "Was my profession risk rated?" |

### 4.4 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Free look period | "You have 30 days from receipt of the policy document to review and return it" | Cooling-off period |
| Grace period | "A grace period of 30 days will be allowed for payment of premium" | Late payment buffer |
| Revival | "The policy can be revived within 2 years from the date of first unpaid premium" | Reactivate lapsed policy |
| Suicide exclusion | "If the life assured dies by suicide within 12 months..." | No payout for early suicide |
| Paid-up value | "If premiums are paid for at least 3 years, the policy acquires a paid-up value" | Reduced paid-up sum assured |
| Surrender value | "Guaranteed Surrender Value: 30% of premiums paid excluding first year" | Cash value you can withdraw |
| Policy loan | "Loan available up to 85% of surrender value at PLR + 2%" | Loan against the policy |
| Assignment | "The policy may be assigned under Section 38 of the Insurance Act" | Transfer policy ownership |
| Nomination | "The holder may nominate under Section 39 of the Insurance Act" | Nominee receives benefits |
| Riders | "Riders are subject to their own terms and conditions" | Separate rider T&Cs apply |

### 4.5 Top 10 Questions Users Ask About Life Insurance

| # | Question | Field(s) needed | Current support |
|---|----------|-----------------|:--------------:|
| 1 | "What's my sum assured / death benefit?" | `sum_assured` | ✅ Life model |
| 2 | "Who is the nominee?" | `nominee_name`, `nominee_share` | ✅ Life model |
| 3 | "What type of life policy is this (term/ULIP/endowment)?" | `policy_type` | ❌ Missing (relies on generic `document_type`) |
| 4 | "How long is my policy term?" | `policy_term_years` | ✅ Life model |
| 5 | "When does my policy mature?" | `maturity_date` | ✅ Life model |
| 6 | "Does this cover critical illness?" | `rider_details[]`, `critical_illness_rider` | 🟡 Partial (riders extracted but CI-specific not separated) |
| 7 | "Can I surrender my policy?" | `surrender_value` | ✅ Life model |
| 8 | "What's the maturity benefit?" | `maturity_amount` | ✅ Life model |
| 9 | "How long do I need to pay premiums?" | `premium_paying_term_years` | ✅ Life model |
| 10 | "What happens if I miss a premium?" | `grace_period`, `revival_clause` | 🟡 Partial (grace period extracted, revival not) |

### 4.6 Extraction Gotchas

- **ULIPs have investment components**: NAV, fund allocation, fund switches — fundamentally different from term/endowment
- **Sum assured changes**: Some policies have varying death benefits (increasing/decreasing term)
- **Rider schedules**: Each rider is a separate contract with its own terms
- **Bonus declarations**: With-profit policies declare annual bonuses — not in the base policy document
- **Policy schedules vs. Prospectus**: The policy schedule is the legal contract; the prospectus is marketing
- **Nominee vs. Assignee**: A nominee is a trustee for legal heirs; an assignee becomes the owner

---

## 5. Home/Property Insurance

### 5.1 Current State

**Status:** ✅ Full support  
10 home-specific fields with `_HomeDetailsCard`

### 5.2 Fields

| Field | Example | Extracted? | Model | Difficulty | Top Questions |
|-------|---------|:----------:|-------|:----------:|--------------|
| Generic fields | — | ✅ | Generic | Various | — |
| `property_address` | 42, Sunshine Apartments, Andheri West, Mumbai | ✅ | Home | Medium | "What property is insured?" |
| `building_sum_insured` | 5000000.0 | ✅ | Home | Medium | "How much is the building covered for?" |
| `contents_sum_insured` | 1500000.0 | ✅ | Home | Medium | "Are my belongings covered?" |
| `rebuild_cost` | 7500000.0 | ✅ | Home | Medium | "What's the rebuild cost of my home?" |
| `perils_covered[]` | Fire, Flood, Earthquake, Burglary, Storm | ✅ | Home | Medium | "What perils does this policy cover?" |
| `perils_excluded[]` | War, Nuclear, Terror, Wear and tear | ✅ | Home | Medium | "What perils are excluded?" |
| `add_on_covers[]` | Jewellery Cover, Domestic Help Cover, Pedal Cycle Cover | ✅ | Home | Medium | "What add-on covers do I have?" |
| `deductible` | 2500.0 | ✅ | Home | Medium | "What's my deductible?" |
| `structure_type` | Apartment | ✅ | Home | Easy | "What type of property is this?" |
| `policy_type` | Standard Fire | ✅ | Home | Medium | "What type of home insurance is this?" |

### 5.3 Fields NOT Yet Extracted

| Missing Field | Example | Difficulty | Priority | Why It Matters |
|--------------|---------|:----------:|:--------:|----------------|
| `loss_of_rent_cover` | ₹50,000 per month, max 6 months | Medium | P1 | "Does this cover loss of rent?" |
| `electrical_appliance_cover` | ₹3,00,000 sub-limit | Medium | P2 | "Are my appliances covered?" |
| `jewellery_cover` | ₹2,00,000 sub-limit, valuables clause | Medium | P2 | "Is my jewellery covered?" |
| `cash_cover` | ₹25,000 | Easy | P3 | "Is cash in the premises covered?" |
| `public_liability_cover` | ₹5,00,000 | Medium | P2 | "Is someone injured at my property covered?" |
| `reinstatement_value` | "Full reinstatement as per original specification" | Hard | P2 | "Is this reinstatement or market value basis?" |
| `malicious_damage_cover` | Not covered | Medium | P2 | "Is malicious damage by vandals covered?" |
| `terrorism_cover` | Included (in peril list) | Medium | P3 | "Is terrorism covered?" |
| `rent_cover_during_repair` | Actual rent up to ₹50K/month for 6 months | Medium | P2 | "Can I claim rent while my home is rebuilt?" |
| `architect_fees` | Included up to 5% of SI | Medium | P3 | "Are architect fees covered for rebuilding?" |
| `debris_removal_cover` | Up to 5% of claim amount | Easy | P3 | "Is debris removal covered?" |

### 5.4 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Reinstatement | "The company agrees to make good the loss on a reinstatement basis" | Pay to rebuild, not pay market value |
| Underinsurance / Coinsurance | "Average clause applies — if sum insured is less than 85% of value, claim is proportionately reduced" | Penalty for underinsurance |
| Escalation | "Sum insured shall escalate by 10% compound every policy year" | Coverage auto-increases |
| Loss of rent | "Loss of rent cover: 1/12th of total rent for every 15 days the premises are uninhabitable" | Pays alternative accommodation |
| Exclusion: Wear & tear | "Gradual deterioration, wear and tear, and inherent vice are not covered" | Normal aging not covered |
| Contents definition | "Contents include household goods, appliances, furniture, carpets, and personal effects" | What counts as "contents" |
| Jewellery sub-limit | "Jewellery covered up to ₹2,00,000 per item subject to production of valuation certificate" | Limit on valuables |
| Flood/Storm | "Flood, storm, tempest, and inundation are covered perils" | Weather-related damage |
| Earthquake | "Earthquake fire and shock are covered as standard perils" | Earthquake damage included |
| Bomb blast / Terror | "Loss due to terrorist activity is covered up to the sum insured" | Terrorism included (after 2006 insurance pool) |

### 5.5 Top 10 Questions Users Ask About Home Insurance

| # | Question | Field(s) needed | Current support |
|---|----------|-----------------|:--------------:|
| 1 | "What perils does my home insurance cover?" | `perils_covered[]` | ✅ Home model |
| 2 | "How much is my building covered for?" | `building_sum_insured` | ✅ Home model |
| 3 | "Are my contents (furniture, electronics) covered?" | `contents_sum_insured` | ✅ Home model |
| 4 | "Is earthquake covered?" | `perils_covered[]` | ✅ Home model |
| 5 | "Is flood/water damage covered?" | `perils_covered[]` | ✅ Home model |
| 6 | "Is my jewellery covered?" | `add_on_covers[]` | 🟡 Partial (listed in add-ons but sub-limit not extracted) |
| 7 | "What's the deductible?" | `deductible` | ✅ Home model |
| 8 | "Is this reinstatement value or market value?" | `reinstatement_value` | ❌ Missing |
| 9 | "Am I covered if someone gets injured on my property?" | `public_liability_cover` | ❌ Missing |
| 10 | "What's NOT covered?" | `perils_excluded[]` | ✅ Home model |

### 5.6 Extraction Gotchas

- **Peril lists**: Often in the policy wording, not the schedule — requires identifying which perils are "covered" vs "excluded" from the entire policy text
- **Sub-limits**: Jewellery, cash, electrical appliances all have sub-limits listed in a separate table
- **Underinsurance clause**: The "average clause" wording is dense legal text — hard to parse reliably
- **Occupancy changes**: If a property changes from self-occupied to rented, coverage changes
- **Home vs. Fire policy**: In India, "fire insurance" covers the building; "home insurance" covers building + contents + liability — subtle naming difference

---

## 6. Travel Insurance

### 6.1 Current State

**Status:** ✅ Full support  
16 travel-specific fields with `_TravelDetailsCard`

### 6.2 Fields

| Field | Example | Extracted? | Model | Difficulty | Top Questions |
|-------|---------|:----------:|-------|:----------:|--------------|
| Generic fields | — | ✅ | Generic | Various | — |
| `traveller_name` | Mr. Amit Sharma | ✅ | Travel | Easy | "Who is the insured traveller?" |
| `destination` | Thailand (Bangkok, Phuket) | ✅ | Travel | Easy | "What destination is covered?" |
| `trip_duration_days` | 15 | ✅ | Travel | Easy | "How long is my trip covered?" |
| `trip_start_date` | 2026-11-10 | ✅ | Travel | Easy | "When does my travel cover start?" |
| `trip_end_date` | 2026-11-24 | ✅ | Travel | Easy | "When does my travel cover end?" |
| `trip_type` | Single trip | ✅ | Travel | Easy | "Is this a single trip or annual policy?" |
| `trip_cost_covered` | 75000.0 | ✅ | Travel | Medium | "How much trip cost is covered for cancellation?" |
| `medical_expenses_cover` | 100000.0 | ✅ | Travel | Easy | "How much medical coverage do I have?" |
| `medical_evacuation_cover` | 500000.0 | ✅ | Travel | Easy | "Is medical evacuation covered?" |
| `personal_accident_cover` | 50000.0 | ✅ | Travel | Medium | "Is personal accident covered?" |
| `baggage_loss_cover` | 2000.0 | ✅ | Travel | Medium | "How much for lost baggage?" |
| `baggage_delay_cover` | 200.0 | ✅ | Travel | Medium | "How much for delayed baggage?" |
| `trip_cancellation_cover` | 75000.0 | ✅ | Travel | Medium | "Is trip cancellation covered?" |
| `flight_delay_cover` | 200.0 | ✅ | Travel | Medium | "Is flight delay covered?" |
| `add_on_covers[]` | Passport Loss Assistance, Adventure Sports | ✅ | Travel | Medium | "What additional covers do I have?" |
| `emergency_assistance_phone` | +66-800-123-4567 | ✅ | Travel | Easy | "Who do I call in an emergency?" |

### 6.3 Fields NOT Yet Extracted

| Missing Field | Example | Difficulty | Priority | Why It Matters |
|--------------|---------|:----------:|:--------:|----------------|
| `missed_connection_cover` | ₹5,000 if missed connecting flight | Medium | P2 | "What if I miss my connecting flight?" |
| `curtailment_cover` | ₹35,000 if trip cut short | Medium | P2 | "Can I claim if I return early?" |
| `compassionate_visit_cover` | Return airfare for family emergency | Medium | P3 | "Can the insurer fly me home for a family emergency?" |
| `personal_liability_cover` | USD 250,000 worldwide | Medium | P2 | "Am I liable if I accidentally injure someone?" |
| `sports_equipment_cover` | Skis, golf clubs, surfboard — upto USD 500 | Medium | P3 | "Is my sports equipment covered?" |
| `24hr_assistance_company` | Bupa Assistance Services Ltd. | Easy | P2 | "Which company provides 24x7 assistance?" |

### 6.4 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Geographical zone | "Cover is valid for travel in Zone A (Asia) excluding China" | Defines where coverage applies |
| Adventure sports | "Adventure sports cover is available on payment of additional premium" | Optional add-on |
| Pre-existing conditions | "No cover for any pre-existing medical condition unless specifically waived" | Usually excluded |
| Baggage delay threshold | "Baggage delayed by more than 6 hours from arrival" | Minimum delay before claim |
| Flight delay threshold | "Flight delayed by more than 6 consecutive hours" | Minimum delay before payout |
| Trip cancellation reasons | "Cancellation due to illness, death of family member, natural disaster, or visa denial" | Only covered reasons |
| Medical evacuation | "Evacuation must be pre-authorised by the assistance company" | DO NOT arrange yourself |
| Hijack | "₹15,000 for each completed 24-hour period of hijack, max 7 days" | Payout per day of hijacking |
| Missed connection | "If airline schedule change causes you to miss a connecting flight" | Airline must be the cause |
| Single trip vs. Annual | "Annual multi-trip policy — maximum 30 consecutive days per trip" | Per-trip limit for annual policies |

### 6.5 Top 10 Questions Users Ask About Travel Insurance

| # | Question | Field(s) needed | Current support |
|---|----------|-----------------|:--------------:|
| 1 | "Does this cover medical expenses abroad?" | `medical_expenses_cover` | ✅ Travel model |
| 2 | "Is medical evacuation covered?" | `medical_evacuation_cover` | ✅ Travel model |
| 3 | "Is trip cancellation covered?" | `trip_cancellation_cover` | ✅ Travel model |
| 4 | "Is baggage loss covered?" | `baggage_loss_cover` | ✅ Travel model |
| 5 | "What destination is covered?" | `destination` | ✅ Travel model |
| 6 | "Does this cover adventure sports?" | `add_on_covers[]` | 🟡 Partial (adventure sports listed in add-ons if present) |
| 7 | "What geographical zone am I covered in?" | `geographical_zone` | ❌ Missing |
| 8 | "Does this cover pre-existing conditions?" | `preexisting_condition_waiver` | ❌ Missing |
| 9 | "What's the deductible?" | `deductible_per_claim_travel` | ❌ Missing |
| 10 | "Is this single trip or annual multi-trip?" | `trip_type` | ✅ Travel model |

### 6.6 Extraction Gotchas

- **"Worldwide excluding USA/Canada"**: Common zone definition that's hard to normalize
- **Multiple currency values**: Covers listed in USD, EUR, INR simultaneously
- **Cover tables**: The key part of travel insurance is a table showing benefits vs. limits vs. sub-limits
- **Excess/deductible per section**: Medical excess might be $50, baggage excess $25, cancellation excess $100
- **Pre-existing condition waiver**: Usually implied by absence of exclusion, not explicitly stated
- **Annual multi-trip vs. single trip**: The entire structure of the policy changes between these two

---

## 7. Marine/Cargo Insurance

### 7.1 Current State

**Status:** ❌ Not supported (falls to `other`)

### 7.2 Fields Needed

| Field | Example | Difficulty | Priority | Top Questions |
|-------|---------|:----------:|:--------:|--------------|
| `policy_type_marine` | Marine Cargo, Hull, Freight | Medium | P2 | "What type of marine insurance is this?" |
| `vessel_name` | MV Ocean Queen | Easy | P2 | "Which vessel is insured?" |
| `voyage_details` | Mumbai to Singapore via Colombo | Medium | P2 | "What's the transit route?" |
| `cargo_description` | Electronic components, 50 cartons | Medium | P2 | "What cargo is insured?" |
| `cargo_value` | USD 250,000 FOB | Medium | P2 | "What's the value of the cargo?" |
| `incoterms` | CIF, FOB, CFR, EXW | Medium | P2 | "What INCO terms apply?" |
| `basis_of_valuation` | CIF value plus 10% | Medium | P3 | "How is the insured value calculated?" |
| `institute_clauses` | Institute Cargo Clauses (A) | Hard | P2 | "Which institute clauses apply?" |
| `voyage_from` | Mumbai Port, India | Easy | P2 | "Where is the voyage starting?" |
| `voyage_to` | Singapore Port | Easy | P2 | "Where is the destination?" |
| `transit_start_date` | 2026-07-01 | Easy | P2 | "When does transit start?" |
| `transit_end_date` | 2026-07-07 | Easy | P2 | "When does transit end?" |
| `conveyance` | MV Ocean Queen / Air India AI-101 | Easy | P3 | "How is the cargo transported?" |
| `packing_type` | 50 cartons on pallets, shrink-wrapped | Medium | P3 | "How is the cargo packed?" |
| `general_average_clause` | York Antwerp Rules 2016 | Hard | P2 | "Is general average covered?" |
| `particular_average` | 3% franchise | Hard | P3 | "What's the PA franchise?" |
| `sue_and_labour_clause` | Reasonable costs to prevent loss covered | Hard | P3 | "Are mitigation costs covered?" |
| `salvage_charge` | Covered in full | Medium | P3 | "Are salvage charges covered?" |
| `war_risk_clause` | Excluded by standard ICC clauses | Medium | P2 | "Is war risk covered?" |
| `strikes_riots_clause` | Excluded by standard ICC clauses | Medium | P2 | "Are strikes and riots covered?" |
| `transhipment_clause` | Covered including temporary storage | Hard | P3 | "Is transhipment covered?" |
| `warehouse_to_warehouse` | Covered, max 60 days at destination | Medium | P2 | "Is warehouse-to-warehouse cover included?" |
| `marine_insurance_certificate_no` | MIC-2024-001234 | Easy | P2 | "What's the marine certificate number?" |

### 7.3 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Institute Cargo Clauses (A) | "All risks of loss or damage to the subject-matter insured" | Broadest cover (all risks) |
| ICC (B) | "Loss or damage reasonably attributable to fire, explosion, stranding" | Named perils (narrower) |
| ICC (C) | "Loss or damage reasonably attributable to fire, explosion" | Very narrow (major perils only) |
| Warehouse to warehouse | "Cover attaches from the time the goods leave the warehouse at the place named in the policy" | Coverage from seller's to buyer's warehouse |
| General average | "The insured shall pay the proportion of general average" | Share of sacrificed cargo (shippers share the loss) |
| Sue and labour | "It is the duty of the insured to take measures to avert or minimize loss" | Must try to save the cargo |
| 3% franchise | "No claim payable if loss is less than 3% of insured value" | Small losses not covered |
| War exclusion | "In no case shall this insurance cover loss caused by war, civil war, revolution" | Standard exclusion |
| Strikes exclusion | "In no case shall this insurance cover loss caused by strikers, locked-out workmen" | Standard exclusion |
| FOB/CIF/CFR | INCO terms defining who arranges insurance | Buyer (FOB) vs. Seller (CIF) arranges insurance |

### 7.4 Top 10 Questions Users Ask About Marine/Cargo Insurance

| # | Question | Field(s) needed |
|---|----------|-----------------|
| 1 | "What cargo is insured?" | `cargo_description`, `cargo_value` |
| 2 | "Which ports are covered?" | `voyage_from`, `voyage_to` |
| 3 | "What Institute Cargo Clauses apply?" | `institute_clauses` |
| 4 | "What perils are covered?" | `institute_clauses` (determines this) |
| 5 | "Is war risk covered?" | `war_risk_clause` |
| 6 | "Is general average covered?" | `general_average_clause` |
| 7 | "What's the valuation basis?" | `basis_of_valuation` |
| 8 | "What transport mode is covered?" | `conveyance` |
| 9 | "Is warehouse-to-warehouse included?" | `warehouse_to_warehouse` |
| 10 | "Are strikes and riots covered?" | `strikes_riots_clause` |

### 7.5 Extraction Gotchas

- **INCO terms**: Different terms (FOB, CIF, CFR, EXW) fundamentally change who arranges insurance
- **Institute Clauses**: The specific clause version (ICC A/B/C, Institute War, Institute Strikes) determines almost all coverage questions
- **General Average**: The most complex clause — involves all cargo owners splitting the loss proportionally
- **Dual currency**: Values often in USD with INR conversion tables
- **Multiple goods**: A single policy may cover multiple shipments simultaneously (open cover / floating policy)

---

## 8. Cyber Insurance

### 8.1 Current State

**Status:** ❌ Not supported (falls to `other`)

### 8.2 Fields Needed

| Field | Example | Difficulty | Priority | Top Questions |
|-------|---------|:----------:|:--------:|--------------|
| `cyber_policy_type` | Standalone, Package, Add-on | Medium | P3 | "What type of cyber insurance is this?" |
| `data_breach_response_limit` | ₹5,00,000 | Medium | P3 | "How much for data breach response?" |
| `cyber_extortion_limit` | ₹2,00,000 | Medium | P3 | "Is ransomware covered?" |
| `business_interruption_hours` | 12-hour waiting period, max 72 hours | Hard | P3 | "How long before BI kicks in?" |
| `business_interruption_limit` | ₹10,00,000 | Medium | P3 | "How much BI cover do I have?" |
| `forensic_investigation_costs` | Included within policy limit | Medium | P3 | "Are forensic investigation costs covered?" |
| `notification_costs` | Included, up to ₹500 per affected individual | Medium | P3 | "Are notification costs covered?" |
| `crisis_management_costs` | Included, up to ₹3,00,000 | Medium | P3 | "Are PR/crisis management costs covered?" |
| `regulatory_defence_costs` | In addition to policy limit, up to ₹5,00,000 | Hard | P3 | "Are regulatory fines and defence covered?" |
| `third_party_liability_limit` | ₹25,00,000 aggregate | Medium | P3 | "Am I covered for third-party claims?" |
| `network_security_liability` | Included, ₹25,00,000 | Medium | P3 | "Is network security liability covered?" |
| `privacy_liability` | Included, ₹25,00,000 | Medium | P3 | "Is privacy liability covered?" |
| `retroactive_date` | 01-Apr-2025 | Medium | P3 | "What's the retroactive date?" |
| `waiting_period_cyber` | 12 hours for BI | Easy | P3 | "What's the waiting period?" |
| `sub_limit_social_engineering` | ₹1,00,000 | Medium | P3 | "Is social engineering fraud covered?" |
| `sub_limit_media_liability` | ₹5,00,000 | Medium | P3 | "Is media liability covered?" |
| `sub_limit_pci_dss_penalty` | ₹2,00,000 | Medium | P3 | "Are PCI DSS penalties covered?" |
| `extended_reporting_period` | 60 days | Easy | P3 | "Can I report claims after policy expiry?" |

### 8.3 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Claims-made basis | "This policy is on a claims-made and reported basis" | Claim must be made during policy period |
| Retroactive date | "Cover applies only to claims arising from incidents after the retroactive date" | No cover for incidents before this date |
| Extortion | "Cover for threat to commit or threaten to commit a cyber extortion event" | Ransomware coverage |
| Waiting period | "No cover for the first 12 hours of business interruption" | BI doesn't start immediately |
| Sub-limits | "Social engineering fraud is covered up to ₹1,00,000" | Separate caps per type of loss |
| Defence costs | "Defence costs are in addition to the limit of liability" | Legal defence doesn't erode coverage limit |
| Regulatory proceedings | "Cover for defence of regulatory proceedings including PCI DSS penalties" | Fines and penalties |
| Notification | "Costs incurred in notifying affected individuals as required by law" | Breach notification expenses |

### 8.4 Top Questions Users Ask About Cyber Insurance

| # | Question | Field(s) needed |
|---|----------|-----------------|
| 1 | "Is ransomware covered?" | `cyber_extortion_limit` |
| 2 | "What's the data breach response limit?" | `data_breach_response_limit` |
| 3 | "Does this cover regulatory fines (e.g., DPDPA penalties)?" | `regulatory_defence_costs` |
| 4 | "What's the retroactive date — are past incidents covered?" | `retroactive_date` |
| 5 | "Is business interruption from cyber events covered?" | `business_interruption_limit`, `waiting_period_cyber` |
| 6 | "Are forensic investigation costs included?" | `forensic_investigation_costs` |
| 7 | "Is social engineering fraud covered?" | `sub_limit_social_engineering` |
| 8 | "What's the waiting period for business interruption?" | `waiting_period_cyber` |
| 9 | "Am I covered for third-party claims from a data breach?" | `third_party_liability_limit` |
| 10 | "Can I report claims after policy expiry?" | `extended_reporting_period` |

### 8.5 Extraction Gotchas

- **Claims-made vs. occurrence**: Critical distinction — most Indian policies are claims-made
- **Sub-limits galore**: Cyber policies have 8+ sub-limits, making the limit structure complex
- **New regulation**: India's DPDPA (Digital Personal Data Protection Act) is new — policy wording is still evolving
- **Add-on vs. standalone**: Cyber insurance can be a standalone policy or an add-on to a business package policy
- **Ransomware exclusions**: Some policies now exclude ransomware explicitly (post-2024 hardening)

---

## 9. Liability / Professional Indemnity

### 9.1 Current State

**Status:** ❌ Not supported (falls to `other`)

### 9.2 Fields Needed

| Field | Example | Difficulty | Priority | Top Questions |
|-------|---------|:----------:|:--------:|--------------|
| `liability_type` | Professional Indemnity, Public Liability, Product Liability, D&O, Employer's Liability | Medium | P3 | "What type of liability insurance is this?" |
| `limit_per_claim` | ₹25,00,000 | Medium | P3 | "What's the limit per claim?" |
| `aggregate_limit` | ₹75,00,000 | Medium | P3 | "What's the aggregate limit?" |
| `defence_costs_outside_limits` | Yes | Hard | P3 | "Are legal defence costs in addition to the limit?" |
| `retroactive_date` | 01-Apr-2024 | Medium | P3 | "What's the retroactive date for cover?" |
| `policy_period` | 01-Apr-2025 to 31-Mar-2026 | Easy | P3 | "What's the policy period?" |
| `jurisdiction` | India | Easy | P3 | "Which jurisdiction applies?" |
| `deductible_liability` | ₹25,000 per claim | Medium | P3 | "What's the deductible?" |
| `claims_made_basis` | Yes | Medium | P3 | "Is this claims-made or occurrence-based?" |
| `extended_reporting_period` | 60 days after expiry | Medium | P3 | "What's the extended reporting period?" |
| `professional_service_scope` | Medical practitioner, Chartered Accountant, Architect | Medium | P3 | "What professional services are covered?" |
| `territorial_scope` | Worldwide excluding USA/Canada | Easy | P3 | "Where does cover apply?" |
| `prior_acts_cover` | Yes, from inception | Medium | P3 | "Are prior acts covered?" |
| `number_of_employees_covered` | 25 | Easy | P3 | "How many employees are covered?" |
| `cross_liability` | Included | Medium | P3 | "Are claims between insureds covered?" |
| `dishonesty_exclusion` | Excluded | Easy | P3 | "Are dishonest acts excluded?" |
| `punitive_damages_exclusion` | Excluded | Easy | P3 | "Are punitive damages excluded?" |
| `pollution_exclusion` | Excluded | Easy | P3 | "Is pollution excluded?" |
| `cyber_exclusion` | Excluded unless cyber add-on purchased | Easy | P3 | "Is cyber excluded from liability policy?" |

### 9.3 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Claims-made | "This policy covers claims first made against the insured during the policy period" | Claim must be made while policy is active |
| Retroactive date | "Cover applies only to claims arising from acts that occurred after the retroactive date" | No cover for past acts |
| Defence costs | "Defence costs are in addition to the limit of liability" | Legal fees don't reduce coverage |
| Prior acts | "Cover extends to acts committed prior to the policy inception date" | Retroactive cover for past acts |
| Cross liability | "Each insured shall be treated as a separate insured" | One partner can sue another (covered) |
| Dishonesty exclusion | "No cover for dishonest, fraudulent, criminal or malicious acts" | Fraud is not covered |
| Pollution exclusion | "This policy does not cover claims arising from pollution or contamination" | Environmental damage not covered |
| Claims notification | "The insured shall notify the insurer in writing as soon as practicable" | Must report claims promptly |
| Queen's / King's Bench | "The policy is subject to the law of England and Wales" | Common for international policies |

### 9.4 Top Questions Users Ask About Liability Insurance

| # | Question | Field(s) needed |
|---|----------|-----------------|
| 1 | "What's my limit of liability?" | `limit_per_claim`, `aggregate_limit` |
| 2 | "What's the deductible / excess?" | `deductible_liability` |
| 3 | "Is this claims-made or occurrence-based?" | `claims_made_basis` |
| 4 | "What's the retroactive date?" | `retroactive_date` |
| 5 | "Are legal defence costs covered in addition to the limit?" | `defence_costs_outside_limits` |
| 6 | "Where does this cover apply?" | `territorial_scope` |
| 7 | "What professional services are covered?" | `professional_service_scope` |
| 8 | "Are prior acts covered?" | `prior_acts_cover` |
| 9 | "Can I report claims after expiry?" | `extended_reporting_period` |
| 10 | "Is fraud excluded?" | `dishonesty_exclusion` |

### 9.5 Extraction Gotchas

- **Claims-made vs. occurrence**: The single most important distinction — fundamentally changes claim eligibility
- **Multiple sub-limits**: Defence costs, aggregate, per-claim — three different limit numbers
- **Retroactive date**: Might be multiple years before policy inception — critical for D&O policies
- **"Pay on behalf" vs. "Indemnity"**: Two different settlement mechanisms
- **Legal jargon heavy**: Liability policies have the densest legal language of all types

---

## 10. Commercial / Business Insurance

### 10.1 Current State

**Status:** ❌ Not supported (falls to `other`)

### 10.2 Fields Needed

| Field | Example | Difficulty | Priority | Top Questions |
|-------|---------|:----------:|:--------:|--------------|
| `commercial_policy_type` | Business Interruption, Commercial Property, Fidelity, Keyman, Marine | Medium | P3 | "What type of commercial insurance is this?" |
| `business_name` | Sunshine Trading Pvt. Ltd. | Easy | P3 | "What business is insured?" |
| `business_address` | 15, Industrial Area, Bhiwandi | Easy | P3 | "Where is the business located?" |
| `business_activity` | Garment manufacturing, wholesale trading | Medium | P3 | "What does the business do?" |
| `indemnity_period` | 12 months | Medium | P3 | "How long does BI cover last?" |
| `gross_profit_sum_insured` | ₹50,00,000 | Medium | P3 | "How much gross profit is covered?" |
| `standard_turnover` | ₹2,00,00,000 | Medium | P3 | "What's the standard turnover?" |
| `reinstatement_of_si` | Included | Medium | P3 | "Does SI reinstate after a claim?" |
| `fidelity_guarantee_limit` | ₹5,00,000 | Medium | P3 | "Is employee fraud covered?" |
| `fidelity_number_of_employees` | 25 | Easy | P3 | "How many employees covered for fidelity?" |
| `keyman_sum_assured` | ₹25,00,000 | Medium | P3 | "How much keyman cover?" |
| `keyman_name` | Mr. Rajesh Patel | Easy | P3 | "Who is the key person insured?" |
| `money_insurance_limit` | ₹2,00,000 in transit, ₹1,00,000 on premises | Medium | P3 | "Is cash in transit covered?" |
| `burglary_limit` | ₹10,00,000 | Medium | P3 | "Is burglary covered?" |
| `fire_limits` | ₹1,00,00,000 building + contents | Medium | P3 | "What are the fire limits?" |
| `machinery_breakdown_limit` | ₹25,00,000 | Medium | P3 | "Is machinery breakdown covered?" |
| `electronic_equipment_limit` | ₹15,00,000 | Medium | P3 | "Are electronics covered?" |
| `riot_strike_civil_commotion` | Included | Easy | P3 | "Are riots covered?" |
| `terrorism_cover` | Included | Medium | P3 | "Is terrorism covered?" |
| `business_continuation_expenses` | ₹5,00,000 additional | Medium | P3 | "Are extra expenses covered to keep running?" |

### 10.3 Common Clauses & Wording

| Clause | Typical wording | What it means |
|--------|----------------|---------------|
| Indemnity period | "The indemnity period shall not exceed 12 months from the date of damage" | Max period of BI coverage |
| Gross profit | "Gross Profit means turnover less specified working expenses" | Definition of insured profit |
| Reinstatement | "The Sum Insured shall be reinstated automatically upon payment of a pro-rata premium" | Coverage resets after claim |
| Average clause | "If the Sum Insured is less than 85% of the gross profit, the claim is proportionately reduced" | Underinsurance penalty for BI |
| Fidelity | "Cover for direct pecuniary loss from dishonest acts of employees" | Employee theft coverage |
| Keyman | "Payable to the insured on the death or permanent disablement of the key person" | Life insurance for key employee |
| Money clause | "Cover for loss of money within the premises and in transit" | Cash coverage |
| Brands clause | "Brands clause applicable for fire policies with plate glass, neon signs" | Fixed glass/signs covered |
| Riot / Strike | "Loss directly caused by riot, strike, malicious damage, or civil commotion" | Political violence cover |

### 10.4 Top Questions Users Ask About Commercial Insurance

| # | Question | Field(s) needed |
|---|----------|-----------------|
| 1 | "What type of commercial insurance is this?" | `commercial_policy_type` |
| 2 | "How long does business interruption cover last?" | `indemnity_period` |
| 3 | "Is employee theft (fidelity) covered?" | `fidelity_guarantee_limit` |
| 4 | "Is keyman insurance included?" | `keyman_sum_assured`, `keyman_name` |
| 5 | "What's the sum insured for my building & contents?" | `fire_limits` |
| 6 | "Is machinery breakdown covered?" | `machinery_breakdown_limit` |
| 7 | "Are riots and strikes covered?" | `riot_strike_civil_commotion` |
| 8 | "Is terrorism covered?" | `terrorism_cover` |
| 9 | "Is cash in transit covered?" | `money_insurance_limit` |
| 10 | "Does the sum insured reinstate after a claim?" | `reinstatement_of_si` |

### 10.5 Extraction Gotchas

- **Package policies**: Commercial insurance often bundles 5+ covers into one "Business Package Policy"
- **Multiple schedules**: Each cover (fire, burglary, fidelity, keyman) has its own schedule with limits
- **Gross profit calculation**: The definition of "gross profit" varies by policy — critical for BI claims
- **Endorsements**: Commercial policies have frequent mid-term changes for stock declarations, new locations
- **Loss prevention warranties**: Usually have mandatory conditions (e.g., fire extinguishers, burglar alarms)

---

## 11. Pet Insurance

### 11.1 Current State

**Status:** ❌ Not supported (falls to `other`)

### 11.2 Fields Needed

| Field | Example | Difficulty | Priority |
|-------|---------|:----------:|:--------:|
| `pet_type` | Dog, Cat | Easy | P3 |
| `pet_breed` | Labrador Retriever, Persian Cat | Easy | P3 |
| `pet_name` | Max | Easy | P3 |
| `pet_age_years` | 3 | Easy | P3 |
| `pet_gender` | Male, Female | Easy | P3 |
| `pet_microchip_id` | 982000364123456 | Medium | P3 |
| `pet_vet_bills_cover` | ₹50,000 per year | Medium | P3 |
| `pet_accident_cover` | ₹25,000 per incident | Medium | P3 |
| `pet_illness_cover` | ₹25,000 per incident | Medium | P3 |
| `pet_third_party_liability` | ₹5,00,000 | Medium | P3 |
| `pet_waiting_period` | 14 days for illness | Easy | P3 |
| `pet_exclusions` | Pre-existing conditions, Routine dental, Grooming | Easy | P3 |
| `pet_deductible` | ₹1,000 per claim | Easy | P3 |

### 11.3 Common Questions

| # | Question | Field(s) needed |
|---|----------|-----------------|
| 1 | "Is my dog/cat covered?" | `pet_type`, `pet_breed` |
| 2 | "Are vet bills covered?" | `pet_vet_bills_cover` |
| 3 | "Is accidental injury covered?" | `pet_accident_cover` |
| 4 | "Is illness covered?" | `pet_illness_cover` |
| 5 | "Is there a waiting period?" | `pet_waiting_period` |
| 6 | "Are pre-existing conditions excluded?" | `pet_exclusions` |
| 7 | "What's the deductible?" | `pet_deductible` |
| 8 | "Is third-party liability (if my dog bites someone) covered?" | `pet_third_party_liability` |

---

## 12. Event Insurance

### 12.1 Current State

**Status:** ❌ Not supported (falls to `other`)

### 12.2 Fields Needed

| Field | Example | Difficulty | Priority |
|-------|---------|:----------:|:--------:|
| `event_type` | Wedding, Conference, Concert, Sports | Easy | P3 |
| `event_name` | Sharma-Williams Wedding | Easy | P3 |
| `event_date` | 2026-12-15 | Easy | P3 |
| `event_venue` | Grand Hyatt Mumbai | Easy | P3 |
| `event_cancellation_cover` | ₹25,00,000 | Medium | P3 |
| `event_postponement_cover` | ₹15,00,000 | Medium | P3 |
| `event_liability_cover` | ₹10,00,000 | Medium | P3 |
| `event_equipment_cover` | ₹5,00,000 | Medium | P3 |
| `event_deposit_lost` | ₹2,50,000 | Medium | P3 |
| `event_weather_cover` | Included — rain cover | Medium | P3 |
| `event_covered_reasons` | Death, illness, natural disaster, venue damage | Medium | P3 |

---

## 13. Mobile / Device Insurance

### 13.1 Current State

**Status:** ❌ Not supported (falls to `other`)

### 13.2 Fields Needed

| Field | Example | Difficulty | Priority |
|-------|---------|:----------:|:--------:|
| `device_type` | Smartphone, Laptop, Tablet | Easy | P3 |
| `device_brand` | Apple, Samsung, Dell | Easy | P3 |
| `device_model` | iPhone 16 Pro Max, Galaxy S26 | Easy | P3 |
| `device_imei` | 352656123456789 | Easy | P3 |
| `device_purchase_value` | ₹1,29,900 | Easy | P3 |
| `device_cover_type` | Screen damage, Theft, Liquid damage, Comprehensive | Medium | P3 |
| `device_deductible_screen` | ₹2,000 | Easy | P3 |
| `device_deductible_theft` | ₹5,000 | Easy | P3 |
| `device_warranty_period` | 1 year | Easy | P3 |
| `device_claim_limit` | 2 claims per year | Easy | P3 |

---

## 14. Cross-Type Field Reference

### 14.1 Fields Common to ALL Types (Currently Extracted)

| Field | Type | Notes |
|-------|------|-------|
| `policy_number` | string | Alphanumeric, 5-25 chars |
| `insurer` | string | Company name |
| `insurer_helpline` | string | Phone number |
| `insurer_email` | string | Email address |
| `coverage_amount` | float | Sum insured / limit |
| `deductible` | float | Common to most types |
| `premium_amount` | float | Premium paid |
| `premium_frequency` | string | Monthly to annual |
| `effective_date` | date | Policy start |
| `expiration_date` | date | Policy end |
| `key_benefits` | string[] | Top 5 covered items |
| `exclusions` | string[] | Top 5 not covered |
| `waiting_periods` | string[] | Applicable periods |
| `coverage_items` | object[] | Individual line items |
| `executive_summary` | string[] | 3-bullet summary |

### 14.2 Field Naming Conflicts (Watch Out!)

| Field | Means different things per type | Risk |
|-------|-------------------------------|:----:|
| `coverage_amount` | Health: SI / Life: Sum Assured / Motor: IDV / Home: Building SI / Travel: varies | **HIGH** — Each type interprets this differently |
| `deductible` | Health: per claim / Motor: compulsory + voluntary / Travel: per section | **HIGH** — Deductible structure varies |
| `effective_date` | Health: policy start / Travel: trip start / Marine: voyage start | **MEDIUM** — Same label, different meaning |
| `expiration_date` | Health: policy end / Travel: trip end / Marine: transit end | **MEDIUM** — Travel has ~30 day gap between trip end and policy end |

### 14.3 Hierarchical Field Structure

```
PolicySummary
├── Generic fields (15 fields — all types)
├── MotorPolicyFields (10 fields — auto only)
├── TravelPolicyFields (16 fields — travel only)
├── LifePolicyFields (16 fields — life only)
├── HomePolicyFields (10 fields — home only)
├── HealthPolicyFields (11 fields — health only)
├── 🚧 MarinePolicyFields (22 fields — marine only) [NOT IMPLEMENTED]
├── 🚧 CyberPolicyFields (18 fields — cyber only) [NOT IMPLEMENTED]
├── 🚧 LiabilityPolicyFields (19 fields — liability only) [NOT IMPLEMENTED]
├── 🚧 CommercialPolicyFields (21 fields — commercial only) [NOT IMPLEMENTED]
└── 🚧 PetPolicyFields (13 fields — pet only) [NOT IMPLEMENTED]
```

---

## 15. Type-Specific Question Catalog

### 15.1 Current Standard Questions

We currently have **22 standard questions** across 6 categories. ALL are generic — none are type-specific.

| Category | # Questions | Examples |
|----------|:-----------:|----------|
| Policy Basics | 5 | "What is my policy number?" |
| Coverage Details | 5 | "What is the total coverage amount?" |
| Premiums & Payments | 3 | "What is my premium amount?" |
| Claims | 3 | "How do I file a claim?" |
| Exclusions & Limitations | 3 | "What is not covered by this policy?" |
| Benefits | 3 | "Does this policy include dental coverage?" |

### 15.2 Gap: No Type-Specific Questions

The current standard questions are **type-agnostic**. A health policy user gets the same questions as a motor policy user. The question "Does this policy include dental coverage?" only makes sense for health insurance. "Does this cover accidental damage?" has completely different answers for auto vs. pet vs. mobile device insurance.

### 15.3 Recommended Type-Specific Questions

#### Health-Specific Questions

| # | Question | Answers from |
|---|----------|--------------|
| 1 | "Does this policy cover room rent?" | `room_rent_cap` |
| 2 | "What's the room rent cap per day?" | `room_rent_cap` |
| 3 | "Does this cover pre-existing conditions?" | `pre_existing_diseases[]`, `waiting_periods[]` |
| 4 | "What's my co-pay percentage?" | `co_pay_percent` |
| 5 | "Is maternity covered?" | `maternity_cover` |
| 6 | "How many network hospitals are there?" | `network_hospitals` |
| 7 | "Are daycare procedures covered?" | `day_care_procedures` |
| 8 | "What's the cumulative bonus / NCB?" | `cumulative_bonus` |
| 9 | "Is ambulance cover included?" | `ambulance_cover` |
| 10 | "Do I get a free health checkup?" | `health_checkup_cover` |
| 11 | "Does my sum insured restore after a claim?" | `restoration_benefit` |
| 12 | "What critical illnesses are covered?" | `critical_illness_list` |
| 13 | "How many days pre/post hospitalization are covered?" | `pre_post_hospitalization_days` |
| 14 | "Are modern treatments (robotic surgery, etc.) covered?" | `modern_treatment_cover` |
| 15 | "Is consumables cover included?" | `consumables_cover` |

#### Motor-Specific Questions

| # | Question | Answers from |
|---|----------|--------------|
| 1 | "What vehicle is insured?" | `vehicle_make_model`, `vehicle_registration_number` |
| 2 | "Is this comprehensive or third-party only?" | `policy_type_detail` |
| 3 | "What's the IDV of my vehicle?" | `IDV` |
| 4 | "What's my No Claim Bonus?" | `NCB_percent` |
| 5 | "What add-on covers do I have?" | `add_on_covers[]` |
| 6 | "What's the breakdown of my premium?" | `own_damage_premium`, `third_party_premium` |
| 7 | "Where is my vehicle covered?" | `geographical_limit` |
| 8 | "What's my vehicle's engine CC?" | `cubic_capacity` |
| 9 | "Is personal accident cover included?" | `personal_accident_cover_owner` |
| 10 | "Is zero depreciation included?" | `add_on_covers[]` |

#### Life-Specific Questions

| # | Question | Answers from |
|---|----------|--------------|
| 1 | "What's my sum assured / death benefit?" | `sum_assured` |
| 2 | "What type of life policy is this?" | `policy_type` (term/ULIP/endowment) |
| 3 | "Who is the nominee?" | `nominee_name`, `nominee_share` |
| 4 | "How long is my policy term?" | `policy_term_years` |
| 5 | "When does my policy mature (if applicable)?" | `maturity_date`, `maturity_amount` |
| 6 | "Does this cover critical illness?" | `rider_details[]` |
| 7 | "Can I surrender this policy?" | `surrender_value` |
| 8 | "Is accidental death covered?" | `accidental_death_benefit` |
| 9 | "How long do I need to pay premiums?" | `premium_paying_term_years` |
| 10 | "What happens if I miss a premium payment?" | `grace_period`, `revival_clause` |

#### Home-Specific Questions

| # | Question | Answers from |
|---|----------|--------------|
| 1 | "What property is insured?" | `property_address` |
| 2 | "How much is the building covered for?" | `building_sum_insured` |
| 3 | "Are my contents / belongings covered?" | `contents_sum_insured` |
| 4 | "What perils are covered?" | `perils_covered[]` |
| 5 | "Is earthquake covered?" | `perils_covered[]` |
| 6 | "Is flood / water damage covered?" | `perils_covered[]` |
| 7 | "What's NOT covered?" | `perils_excluded[]`, `exclusions[]` |
| 8 | "Add-on covers that I have?" | `add_on_covers[]` |
| 9 | "What's the deductible?" | `deductible` |
| 10 | "Is this reinstatement value or market value?" | `reinstatement_value` |

#### Travel-Specific Questions

| # | Question | Answers from |
|---|----------|--------------|
| 1 | "What destination is covered?" | `destination` |
| 2 | "How much medical coverage do I have?" | `medical_expenses_cover` |
| 3 | "Is medical evacuation covered?" | `medical_evacuation_cover` |
| 4 | "Is trip cancellation covered?" | `trip_cancellation_cover` |
| 5 | "How much for lost baggage?" | `baggage_loss_cover` |
| 6 | "Is flight delay covered?" | `flight_delay_cover` |
| 7 | "Does this cover adventure sports?" | `add_on_covers[]` |
| 8 | "Is this single trip or annual multi-trip?" | `trip_type` |
| 9 | "What geographical zone am I covered in?" | `geographical_zone` |
| 10 | "Who do I call in an emergency?" | `emergency_assistance_phone` |

---

## 16. Extraction Difficulty Matrix

### 16.1 Difficulty Criteria

| Level | Criterion | Example fields |
|:-----:|-----------|----------------|
| **Easy** | Single value, consistent format, near table cell or labeled field | `insurer`, `policy_number`, `effective_date`, `premium_amount`, `vehicle_make_model`, `destination`, `traveller_name` |
| **Medium** | Multiple formats, needs semantic understanding, in narrative text | `room_rent_cap`, `NCB_percent`, `perils_covered[]`, `maternity_cover`, `trip_cancellation_cover` |
| **Hard** | Needs cross-reference, legal interpretation, or multiple pages | `surrender_value`, `general_average_clause`, `death_benefit_type`, `reinstatement_value`, `institute_clauses` |

### 16.2 Difficulty Distribution by Type

| Type | Easy fields | Medium fields | Hard fields | Total fields |
|------|:-----------:|:-------------:|:-----------:|:------------:|
| Health | 2 | 8 | 1 | 11 |
| Motor | 4 | 4 | 1 | 9 (missing) |
| Life | 5 | 8 | 3 | 16 |
| Home | 3 | 7 | 2 | 12 (missing) |
| Travel | 5 | 8 | 0 | 13 (missing) |
| Marine | 5 | 8 | 5 | 18 (all missing) |
| Cyber | 2 | 10 | 6 | 18 (all missing) |
| Liability | 4 | 9 | 6 | 19 (all missing) |
| Commercial | 4 | 10 | 7 | 21 (all missing) |

### 16.3 Currently Implemented vs. Missing Fields

| Type | Implemented | Missing | Completeness |
|------|:-----------:|:-------:|:------------:|
| **Health** | 26 | 16 | **62%** |
| **Motor** | 20 (10 generic + 10 motor) | 13 | **61%** |
| **Life** | 26 (10 generic + 16 life) | 12 | **68%** |
| **Home** | 20 (10 generic + 10 home) | 16 | **56%** |
| **Travel** | 26 (10 generic + 16 travel) | 13 | **67%** |

---

## 17. Prioritized Build Roadmap

### Phase 1: Fill Existing Model Gaps (P1 — 1-2 days)

| # | Task | Type | Fields | Effort |
|---|------|------|--------|:------:|
| 1 | Add `pre_post_hospitalization_days` to Health model + prompt | Health | 2 | 30 min |
| 2 | Add `restoration_benefit` to Health model + prompt | Health | 1 | 15 min |
| 3 | Add `critical_illness_list` to Health model + prompt | Health | 1 | 30 min |
| 4 | Add `modern_treatment_cover` to Health model + prompt | Health | 1 | 15 min |
| 5 | Add `policy_type_detail` (comprehensive/TP) to Motor model + prompt | Motor | 1 | ✅ Done 2026-07-25 |
| 6 | Add `geographical_limit` to Motor model + prompt | Motor | 1 | ✅ Done 2026-07-25 |
| 7 | Add `personal_accident_cover_owner` to Motor model + prompt | Motor | 1 | ✅ Done 2026-07-25 |
| 8 | Add `cubic_capacity` to Motor model + prompt | Motor | 1 | ✅ Done 2026-07-25 |
| 9 | Add `policy_type_detail` (term/ULIP/endowment) to Life model + prompt | Life | 1 | ✅ Done 2026-07-25 |
| 10 | Add `occupancy_type` to Home model + prompt | Home | 1 | ✅ Done 2026-07-25 |
| 11 | Add `construction_type` to Home model + prompt | Home | 1 | ✅ Done 2026-07-25 |
| 12 | Add `underinsurance_clause` to Home model + prompt | Home | 1 | ✅ Done 2026-07-25 |
| 13 | Add `geographical_zone` to Travel model + prompt | Travel | 1 | ✅ Done 2026-07-25 |
| 14 | Add `preexisting_condition_waiver` to Travel model + prompt | Travel | 1 | ✅ Done 2026-07-25 |
| 15 | Add `adventure_sports_cover` to Travel model + prompt | Travel | 1 | ✅ Done 2026-07-25 |
| | **Total P1** | | **16 fields** | **✅ All 16 done (2026-07-25)** |

### Phase 2: Type-Specific Question Routing (P2 — 1-2 days)

| # | Task | Effort |
|---|------|:------:|
| 1 | Add `type` field to `StandardQuestion` model (health/auto/life/etc.) | 15 min |
| 2 | Create type-specific question lists (5 types × 10 questions each = 50 questions) | 1 hour |
| 3 | Route question suggestions based on `PolicyType` of selected document | 30 min |
| 4 | Show type-agnostic generic questions as fallback for `other` type | 15 min |
| 5 | Write tests for type-specific question routing | 30 min |

### Phase 3: Type-Specific Claim Guides (P2 — 1 day)

| # | Task | Effort |
|---|------|:------:|
| 1 | Add auto theft claim guide | 30 min |
| 2 | Add home fire claim guide (already done) | ✅ Done |
| 3 | Add home burglary claim guide (already done) | ✅ Done |
| 4 | Add travel medical claim guide (already done) | ✅ Done |
| 5 | Add travel baggage claim guide (already done) | ✅ Done |
| 6 | Add travel cancellation claim guide (already done) | ✅ Done |
| 7 | Add travel flight delay claim guide (already done) | ✅ Done |
| 8 | Add life disability / critical illness claim guide | 30 min |
| 9 | Add health maternity claim guide | 30 min |

### Phase 4: Missing Model Support (P3 — 1-2 weeks)

| # | Task | Type | Fields | Effort |
|---|------|------|:------:|:------:|
| 1 | Add `MarinePolicyDetails` model + prompt routing | Marine | 22 | 4 hours |
| 2 | Add marine test fixture + UI card | Marine | — | 2 hours |
| 3 | Add `CyberPolicyDetails` model + prompt routing | Cyber | 18 | 4 hours |
| 4 | Add cyber test fixture + UI card (if scope includes) | Cyber | — | 2 hours |
| 5 | Add `LiabilityPolicyDetails` model + prompt routing | Liability | 19 | 4 hours |
| 6 | Add `CommercialPolicyDetails` model + prompt routing | Commercial | 21 | 4 hours |

### Phase 5: Smart Question Answering (Long-term vision)

| # | Task | Value |
|---|------|-------|
| 1 | Use type-specific fields to answer generic questions intelligently | "What's my coverage?" → auto shows IDV, health shows SI, life shows SA |
| 2 | Intelligent "What changed?" on renewal | Compare fields year-over-year |
| 3 | Coverage gap detection per type | "Your auto policy doesn't have zero depreciation" |
| 4 | What-If calculator for all types | Premium estimation for auto, life, home, travel |

---

## Appendix A: Claim Guides by Incident Type (Current Mapping)

| Incident Type | Claim Guide | Type | Status |
|--------------|-------------|:----:|:------:|
| `hospitalization` / `health` | Hospitalization Claim | Health | ✅ |
| `accident` / `auto` / `motor` | Auto Insurance Claim | Auto | ✅ |
| `death` / `life` | Life Insurance Death Claim | Life | ✅ |
| `fire` / `home` | Home — Fire & Allied Perils | Home | ✅ |
| `burglary` / `theft` | Home — Burglary & Theft | Home | ✅ |
| `flood` / `earthquake` / `natural disaster` | Home — Natural Disaster | Home | ✅ |
| `medical emergency` / `travel medical` | Travel — Medical Emergency | Travel | ✅ |
| `baggage` / `baggage loss` / `baggage delay` | Travel — Baggage | Travel | ✅ |
| `trip cancellation` / `cancellation` | Travel — Trip Cancellation | Travel | ✅ |
| `flight delay` | Travel — Flight Delay | Travel | ✅ |
| `travel` | Travel — General | Travel | ✅ |
| everything else | General Insurance Claim | Fallback | ✅ |

## Appendix B: File Reference

| File | Role |
|------|------|
| `docs/research/insurance_fields_and_questions_matrix.md` | **This document** — comprehensive fields + questions + roadmap |
| `docs/research/insurance_type_coverage_map.md` | Summary coverage map (one-page reference) |
| `docs/research/all_insurance_document_types.md` | Codebase-wide audit of all types |
| `src/models/extraction.py` | Backend Pydantic models (generic + type-specific) |
| `mobile/lib/models/policy_summary.dart` | Mobile PolicySummary + type-specific field classes |
| `mobile/lib/utils/policy_type.dart` | PolicyType enum + classification + icons/colors |
| `mobile/lib/providers/questions_provider.dart` | Standard questions (currently 22 generic) |
| `mobile/lib/services/policy_extraction_service.dart` | Claim guides + coverage gap analysis |
| `mobile/lib/screens/policy_detail_screen.dart` | Type-specific UI cards (×5) |
| `src/services/policy_extraction_service.py` | Backend extraction prompt routing (type-specific) |

---

*End of document. Last updated: 2026-07-25.*
