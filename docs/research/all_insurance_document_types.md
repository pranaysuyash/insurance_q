# All Insurance Document Types — Complete Reference

> **Created:** 2026-07-25  
> **Source:** Codebase-wide audit (mobile Flutter, Python backend, tests, docs)  
> **Maintainer:** Engineering (solo founder)  
> **Next review:** When adding a new insurance type or modifying any classifier  
> **Related:** `insurance_type_coverage_map.md` (summary), `BR-02 corpus`, `policy_type.dart`

---

## Table of Contents

1. [Coverage Overview](#1-coverage-overview)
2. [Type-by-Type Deep Dives](#2-type-by-type-deep-dives)
3. [Classifier Logic Reference](#3-classifier-logic-reference)
4. [UI Representation Reference](#4-ui-representation-reference)
5. [Field Extraction Reference](#5-field-extraction-reference)
6. [Test Fixture Reference](#6-test-fixture-reference)
7. [Claim Guide Reference](#7-claim-guide-reference)
8. [What-If Calculator Reference](#8-what-if-calculator-reference)
9. [Coverage Type Explorer Reference](#9-coverage-type-explorer-reference)
10. [Gap Summary: What to Add Next](#10-gap-summary-what-to-add-next)
11. [Known Insurance Types Not Yet Supported](#11-known-insurance-types-not-yet-supported)

---

## 1. Coverage Overview

### Legend

| Symbol | Meaning |
|--------|---------|
| ✅ **Full** | Classifier, UI, extraction, test fixture, and claim guide all present |
| ✅ **Good** | Classifier + UI + extraction present; no type-specific extraction |
| 🟡 **Partial** | Classifier + UI present; no type-specific extraction or test fixture |
| ⚪ **Minimal** | Classifier recognizes it (maybe); UI falls to `other`; no extraction |
| ❌ **None** | Not recognized; no UI; no extraction; no tests |

### Current Coverage

| # | Type | Backend | Mobile | UI | Extraction | Fixture | Claim Guide | Overall |
|---|------|---------|--------|----|-----------|---------|-------------|---------|
| 1 | **Health** | ✅ 15+ keywords | ✅ 9+ keywords | ✅ heart/red | ✅ Generic + type‑aware scaffold | ✅ BR-02 | ✅ Hospitalization | **✅ Full** |
| 2 | **Auto/Motor** | ✅ 12 keywords | ✅ 8 keywords | ✅ car/blue | ✅ Generic + `MotorPolicyDetails` | ✅ BR-02 | ✅ Accident | **✅ Full** |
| 3 | **Life** | ✅ 15 keywords | ✅ 7 keywords | ✅ person/purple | ✅ Generic (no type‑specific) | ✅ BR-02 | ✅ Death claim | **✅ Good** |
| 4 | **Home** | ✅ 9 keywords | ✅ 4 keywords | ✅ home/indigo | ✅ Generic (no type‑specific) | ✅ BR-02 | ❌ Falls to General | **✅ Good** |
| 5 | **Travel** | ✅ 27 keywords | ✅ 3 keywords | ✅ flight/orange | ✅ Generic (no type‑specific) | ✅ BR-02 | ❌ Falls to General | **✅ Good** |
| 6 | **Other** | — | — | 📦 inventory/bluegrey | ✅ Generic only | ❌ None | ❌ General | **✅ Baseline** |

### Known Types Not Yet Supported

| # | Type | Backend | Mobile | UI | Extraction | Fixture | Notes |
|---|------|---------|--------|----|-----------|---------|-------|
| 7 | **Liability** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers public, product, professional indemnity |
| 8 | **Marine/Cargo** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers hull, cargo, freight |
| 9 | **Cyber** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers data breach, cyber extortion |
| 10 | **Pet** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers vet bills, third-party liability |
| 11 | **Event** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers cancellation, postponement |
| 12 | **Mobile/Device** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers screen damage, theft |
| 13 | **Commercial** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers business interruption |
| 14 | **Engineering** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Covers contractors all risk, erection |
| 15 | **Aviation** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Aircraft hull, passenger liability |
| 16 | **Agriculture** | ❌ None | ❌ Falls to `other` | ❌ inventory icon | ❌ None | ❌ None | Crop insurance, livestock |

---

## 2. Type-by-Type Deep Dives

### 2.1 Health Insurance

**Status:** ✅ Full support (flagship type)

**Source of truth coverage:**
- Backend classifier: 15+ keywords in `document_classifier.py`
- Mobile classifier: 9+ tokens in `policy_type.dart`
- UI: `monitor_heart_rounded` icon, red (`#B52F4B`)
- Extraction: Generic pipeline with type-aware scaffold (placeholder for health-specific)
- BR-02 fixture: Star Health policy (₹5L sum insured, waiting periods, room rent cap, daycare)
- Claim guide: Full hospitalization claim flow (4 steps, 9 required documents)

**Unique extraction fields (today):**
```
policy_number, insurer, insurer_helpline, insurer_email, document_type,
coverage_amount, deductible, premium_amount, premium_frequency,
effective_date, expiration_date, key_benefits, exclusions,
waiting_periods, coverage_items, executive_summary
```

**Fields that SHOULD be extracted per type but are not:**
| Missing field | Example | Effort |
|--------------|---------|--------|
| `room_rent_cap` | ₹5,000/day | ✅ Already has `RoomRentCapExtraction` model |
| `pre_existing_diseases` | Diabetes, hypertension | Medium (LLM prompt change) |
| `waiting_period_remaining` | 18 months left out of 24 | Medium |
| `network_hospitals` | Apollo, Fortis, Max | Medium |
| `co_pay_percentage` | 10% after age 60 | Medium |
| `maternity_cover_details` | 90-day waiting, ₹40k limit | Medium |
| `daycare_procedures_list` | 48 procedures covered | Medium |
| `cashless_vs_reimbursement` | Available at network hospitals | Medium |
| `ambulance_cover_limit` | ₹2,000 per hospitalization | Easy |
| `pre_post_hospital_days` | 30 days pre, 60 days post | Easy |

**Coverage Explorer description:** "Hospital care, treatment and medical expenses."

**Coverage Gap detection:**
- Detects missing health policy → warns "no health policy found"
- For health policies: checks maternity coverage, critical illness coverage
- Checks policy expiry dates

---

### 2.2 Auto/Motor Insurance

**Status:** ✅ Full support (only type with dedicated type-specific extraction)

**Source of truth coverage:**
- Backend classifier: 12 keywords in `document_classifier.py`
- Mobile classifier: 8 tokens in `policy_type.dart`
- UI: `directions_car_filled_rounded` icon, blue (`#2466B8`)
- Extraction: Generic + `MotorPolicyDetails` (type-specific)
- BR-02 fixture: ICICI Lombard motor policy (IDV ₹5.5L, NCB 50%, Swift VXI)
- Claim guide: Full accident claim flow (5 steps, 7 required documents)

**Unique extraction fields (generic + motor-specific):**

*Generic (shared with all types):*
```
policy_number, insurer, insurer_helpline, insurer_email, document_type,
coverage_amount, deductible, premium_amount, premium_frequency,
effective_date, expiration_date, key_benefits, exclusions,
waiting_periods, coverage_items, executive_summary
```

*Motor-specific (`MotorPolicyDetails`):*
| Field | Example | Implemented |
|-------|---------|-------------|
| `vehicle_registration_number` | MH-01-AB-1234 | ✅ |
| `VIN / chassis_number` | MABC1234567890XYZ | ✅ |
| `engine_number` | E1234567890 | ✅ |
| `NCB_percent` | 50.0 (50%) | ✅ |
| `IDV` | 550000.0 | ✅ |
| `vehicle_make_model` | Maruti Suzuki Swift VXI | ✅ |
| `vehicle_year` | 2023 | ✅ |
| `add_on_covers` | ["Zero Dep", "Roadside Assistance"] | ✅ |
| `own_damage_premium` | 8200.0 | ✅ |
| `third_party_premium` | 2100.0 | ✅ |

**Fields that SHOULD be extracted but are not:**
| Missing field | Example | Effort |
|--------------|---------|--------|
| `fuel_type` | Petrol, Diesel, CNG | Easy |
| `cubic_capacity` | 1197 cc | Easy |
| `seating_capacity` | 5 | Easy |
| `policy_type_detail` | Comprehensive, Third Party, Third Party + Theft | Easy |
| `geographical_limit` | All India | Easy |
| `garaging_address` | City pincode | Easy |
| `previous_claim_history` | 0 claims in 5 years | Medium |
| `add_on_deductible` | Nil, ₹1,000, ₹2,500 | Easy |
| `personal_accident_cover_owner` | ₹15,00,000 included | Easy |
| `personal_accident_cover_passenger` | ₹5,00,000 per person | Easy |

**Coverage Explorer description:** "Car, bike and vehicle protection."

**Coverage Gap detection:**
- Detects missing auto policy → warns "no auto policy found"
- No auto-specific gap detection (e.g., missing NCB, low IDV)

---

### 2.3 Life Insurance

**Status:** ✅ Good support (no type-specific extraction yet)

**Source of truth coverage:**
- Backend classifier: 15 keywords in `document_classifier.py`
- Mobile classifier: 7 tokens in `policy_type.dart`
- UI: `person_rounded` icon, purple (`#7B459C`)
- Extraction: Generic pipeline only (no type-specific fields)
- BR-02 fixture: HDFC term life (20-yr term, nominee, terminal illness benefit)
- Claim guide: Full death claim flow (4 steps, 7 required documents)

**Unique extraction fields (today):**
Same generic fields as health (policy_number, insurer, dates, premium, benefits, etc.)

**Fields that SHOULD be extracted per type:**
| Missing field | Example | Effort |
|--------------|---------|--------|
| `life_assured_name` | Mr. Rajesh Kumar | Easy |
| `sum_assured` | ₹50,00,000 | Medium (already in coverage_amount?) |
| `policy_term_years` | 20 years | Easy |
| `premium_paying_term` | 10 years | Easy |
| `nominee_name` + `nominee_share` | Mrs. Sunita Kumar (100%) | Medium |
| `maturity_date` | 31-May-2044 | Already in expiration_date? |
| `maturity_amount` | ₹50,00,000 | Medium |
| `accidental_death_benefit` | ₹25,00,000 additional | Medium |
| `terminal_illness_benefit` | Advance payout of 50% | Medium |
| `suicide_exclusion` | First 12 months | Easy |
| `free_look_period` | 30 days | Easy |
| `grace_period` | 30 days | Easy |
| `surrender_value` | After 3 years | Medium |
| `rider_details` | Critical illness rider, Waiver of premium | Medium |
| `death_benefit_type` | Level, Increasing, Decreasing | Medium |

**Coverage Explorer description:** "Financial protection for the people you love."

**Coverage Gap detection:**
- Detects missing life policy → warns "no life policy found"
- No life-specific gap detection (e.g., missing nominee)

**Claim Guide:** Supported. Death claim flow with nominee payout.

---

### 2.4 Home/Property Insurance

**Status:** ✅ Good support (classified + test fixture, but no type-specific extraction)

**Source of truth coverage:**
- Backend classifier: 9 keywords in `document_classifier.py`
- Mobile classifier: 4 keywords in `policy_type.dart`
- UI: `home_rounded` icon, indigo (`#6046AF`)
- Extraction: Generic pipeline only
- BR-02 fixture: New India Assurance home policy (structure ₹50L, contents ₹15L, fire/burglary/flood/earthquake)
- Claim guide: Falls to generic "General Insurance Claim" flow

**Fields that SHOULD be extracted per type:**

*Structure & Property:*
| Missing field | Example | Effort |
|--------------|---------|--------|
| `property_address` | 42, Sunshine Apartments, Andheri West | Medium |
| `property_type` | Apartment, House, Villa, Commercial | Easy |
| `building_sum_insured` | ₹50,00,000 | Medium (separate from contents) |
| `contents_sum_insured` | ₹15,00,000 | Medium |
| `year_built` | 2018 | Easy |
| `construction_type` | RCC, Load Bearing | Easy |
| `occupancy_type` | Self-occupied, Rented, Tenant | Easy |

*Covers:*
| Missing field | Example | Effort |
|--------------|---------|--------|
| `fire_allied_perils` | Included | Easy |
| `burglary_theft` | Included | Easy |
| `earthquake` | Included | Easy |
| `flood` | Included | Easy |
| `electrical_appliance_cover` | ₹3,00,000 | Medium |
| `jewellery_cover` | ₹2,00,000 (with valuables clause) | Medium |
| `rent_cover` | Not covered | Medium |
| `malicious_damage_cover` | Not covered | Medium |

*Policy details:*
| Missing field | Example | Effort |
|--------------|---------|--------|
| `deductible_per_claim` | ₹2,500 | Easy (already generic field) |
| `escalation_clause` | 10% annual automatic | Medium |
| `underinsurance_clause` | Coinsurance 85% | Medium |

**Coverage Explorer description:** "Your home, belongings and property cover."

**Coverage Gap detection:** None specific to home.

---

### 2.5 Travel Insurance

**Status:** ✅ Good support (classified + test fixture, but no type-specific extraction)

**Source of truth coverage:**
- Backend classifier: 27 keywords in `document_classifier.py`
- Mobile classifier: 3 keywords in `policy_type.dart`
- UI: `flight_rounded` icon, orange (`#A94E00`)
- Extraction: Generic pipeline only
- BR-02 fixture: Bajaj Allianz travel policy (Thailand, medical USD 100K, evacuation USD 500K, baggage, cancellation)
- Claim guide: Falls to generic "General Insurance Claim" flow

**Fields that SHOULD be extracted per type:**

*Trip details:*
| Missing field | Example | Effort |
|--------------|---------|--------|
| `traveller_name` | Mr. Amit Sharma | Easy |
| `destination` | Thailand (Bangkok, Phuket) | Easy |
| `trip_duration` | 15 days | Easy |
| `trip_dates` | 10-Nov-2024 to 24-Nov-2024 | Easy |
| `trip_type` | Single trip, Annual multi-trip | Easy |
| `trip_cost_covered` | ₹75,000 | Medium |
| `policy_term` | Single trip / 1 year | Easy (already generic) |

*Covers:*
| Missing field | Example | Effort |
|--------------|---------|--------|
| `medical_expenses_cover` | USD 100,000 | Easy |
| `medical_evacuation` | USD 500,000 | Easy |
| `personal_accident_cover` | USD 50,000 | Medium |
| `baggage_loss_cover` | USD 2,000 | Easy |
| `baggage_delay_cover` | USD 200 after 6 hours | Medium |
| `trip_cancellation_cover` | ₹75,000 | Easy |
| `trip_delay_cover` | USD 200 after 6 hours | Medium |
| `passport_loss_assistance` | Included | Easy |
| `emergency_assistance` | 24x7 toll-free number | Easy |
| `adventure_sports_cover` | Not covered | Medium |
| `preexisting_condition_waiver` | Not covered | Easy |

**Coverage Explorer description:** "Protection for trips away from home."

**Coverage Gap detection:** None specific to travel.

---

### 2.6 Other / Unclassified

**Status:** ✅ Baseline (catch-all)

**Source of truth coverage:**
- Backend classifier: Returns "Insurance Policy" when no keywords match
- Mobile classifier: `PolicyType.other` catch-all
- UI: `inventory_2_rounded` icon, blue-grey (`#40556D`)
- Extraction: Generic pipeline only
- BR-02 fixture: None
- Claim guide: Falls to generic "General Insurance Claim" flow

**Coverage Explorer description:** "Other policies kept safely in one place."

**How documents end up here:**
1. Empty/null document type from backend or file name inference
2. Document type string has no matching classifier keywords
3. Backend classifier confidence < 30% and LLM fallback also fails
4. LLM classifier returns a type outside the known 5

**Coverage Gap detection:** Only generic expiry/expired detection.

---

## 3. Classifier Logic Reference

### 3.1 Backend: `src/utils/document_classifier.py`

Two-tier: keyword matching → LLM fallback (confidence < 30%).

#### Keywords by Type

| Type | Keywords | Sensitivity Notes |
|------|----------|-------------------|
| **Health** | `health, mediclaim, medical, hospital, surgical, prescription, diagnostic, outpatient, inpatient, pre-existing, co-pay, family floater, critical illness, wellness, preventive care, emergency room` | Comprehensively covers Indian and US terminology |
| **Auto** | `auto, vehicle, car, collision, VIN, odometer, liability, comprehensive, deductible, no-claim, NCB, IDV` | `comprehensive` also matches health terms — may conflict for blended docs |
| **Home** | `home, property, dwelling, fire, theft, flood, earthquake, mortgage, contents, burglary` | `theft` also matches auto theft — could conflict |
| **Life** | `life, beneficiary, term life, cash value, death benefit, maturity, premium waiver, terminal illness, nominee, surrender` | Longest keyword list — best precision |
| **Travel** | `travel, overseas, trip, itinerary, journey, tour, flight, baggage, luggage, cancellation, trip cancellation, medical evacuation, repatriation, personal accident, destination, passport, visa, travel delay, baggage loss, baggage delay, emergency assistance, travel medical, travel insurance, travel protection, foreign travel, international travel, abroad` | 27 keywords (recently added) |

#### Insurer Detection

30+ insurers recognized via regex + name dictionary:
- Indian: ICICI Lombard, HDFC ERGO, Bajaj Allianz, Star Health, Niva Bupa, New India Assurance, Oriental, United India, National, SBI General, Reliance General, Tata AIG, LIC, SBI Life, HDFC Life, ICICI Prudential, Birla Sun Life, Kotak
- US: State Farm, Allstate, Geico, Progressive, Liberty Mutual, Nationwide, Travelers, MetLife, Aetna, Cigna, UnitedHealthcare, Humana, Anthem, Kaiser, Blue Cross, Blue Shield
- Generic: patterns like "issued by", "Insurer:", "policy issued by"

#### Confidence Calculation

```
keyword_density = matches / total_keywords   (weight: 70%)
text_density = min(matches / word_count, 1.0) (weight: 30%)
confidence = keyword_density * 0.7 + text_density * 0.3
```

- Confidence < 0.3 → triggers LLM fallback (GPT-4o-mini)
- LLM classifies into one of: Health Insurance, Auto Insurance, Home Insurance, Life Insurance, Travel Insurance, or Unknown
- LLM output gets confidence 0.7 (override default)

#### LLM Fallback Prompt

```
"You are an insurance document classifier. Based on the document text below,
determine the document type (one of: Health Insurance, Auto Insurance,
Home Insurance, Life Insurance, Travel Insurance, or Unknown), the insurance
company name, and the policy number if present. Respond in JSON."
```

### 3.2 Fallback: `src/services/document_processing_job.py`

When the classifier throws an exception, a simple text fallback runs:

```python
if "health" in text or "medical" in text:
    document.document_type = "Health Insurance"
elif "auto" in text or "vehicle" in text:
    document.document_type = "Auto Insurance"
elif "life" in text:
    document.document_type = "Life Insurance"
else:
    document.document_type = "Insurance Policy"
```

Note: No `travel` or `home` fallback here — they fall through to "Insurance Policy".

### 3.3 Mobile: `mobile/lib/utils/policy_type.dart`

```dart
enum PolicyType { health, auto, life, home, travel, other }
```

**Input → Type mapping (lowercased):**

| Input contains | → Type | Examples |
|---------------|--------|---------|
| `health`, `mediclaim`, `medical`, `family floater`, `group medical`, `hospital`, `critical illness`, `healthguard` | **health** | "Health Insurance", "Mediclaim Family Floater", "Group Medical", "Critical Illness Policy" |
| `auto`, `motor`, `car`, `vehicle`, `two wheeler`, `two-wheeler`, `bike`, `commercial vehicle` | **auto** | "Auto Insurance", "Comprehensive Two Wheeler", "Commercial Vehicle Policy" |
| `life`, `term`, `ulip`, `endowment`, `pension`, `annuity` | **life** | "Life Insurance", "Term Plan", "ULIP Fund" |
| `home`, `house`, `property`, `fire`, `burglary` | **home** | "Home Insurance", "Fire Insurance" |
| `travel`, `overseas`, `trip` | **travel** | "Travel Insurance", "Overseas Travel" |
| Everything else | **other** | "Pet Insurance", "Cyber Policy" |

### 3.4 Mobile: `mobile/lib/services/document_service.dart` — filename inference

When no backend classification exists, `_inferDocumentType(filePath)` runs `classifyPolicyType(filePath)` on the filename — useful for files like `health_policy.pdf` → health.

---

## 4. UI Representation Reference

### 4.1 Icons and Colors (from `policy_type.dart`)

| PolicyType | Icon | Light Color | Dark Color |
|-----------|------|-------------|------------|
| `health` | `monitor_heart_rounded` | `#B52F4B` | `#FF879A` |
| `auto` | `directions_car_filled_rounded` | `#2466B8` | `#83B6FF` |
| `life` | `person_rounded` | `#7B459C` | `#D7A0F5` |
| `home` | `home_rounded` | `#6046AF` | `#B9A5FF` |
| `travel` | `flight_rounded` | `#A94E00` | `#FFB976` |
| `other` | `inventory_2_rounded` | `#40556D` | `#A8BED8` |

### 4.2 Coverage Type Explorer Descriptions

From `coverage_type_explorer.dart`:

| Type | Description (shown in app) |
|------|---------------------------|
| Health | "Hospital care, treatment and medical expenses." |
| Auto | "Car, bike and vehicle protection." |
| Life | "Financial protection for the people you love." |
| Home | "Your home, belongings and property cover." |
| Travel | "Protection for trips away from home." |
| Other | "Other policies kept safely in one place." |

### 4.3 Document Type Picker

The `showDocumentTypePicker` dialog shows all 6 `PolicyType.values` with their icon + name. User can manually override the type when automatic classification is wrong.

### 4.4 Policy Type Icon Widget

`PolicyTypeIcon` renders a colored circle icon with a verified-user badge overlay. Used on:
- Coverage Type Explorer (dashboard)
- `DocumentThumbnail` widgets
- `PolicyTypeIcon` standalone widget
- Search results
- Document list
- Family member detail screen
- Insurance card screen

### 4.5 Canonical Display Names

| Type | Display name |
|------|-------------|
| health | "Health Insurance" |
| auto | "Auto Insurance" |
| life | "Life Insurance" |
| home | "Home Insurance" |
| travel | "Travel Insurance" |
| other | "Other Insurance" |

---

## 5. Field Extraction Reference

### 5.1 Generic Pipeline (all types)

Backend (`src/services/policy_extraction_service.py`) extracts these fields for every document type via a single LLM call:

```
policy_number, insurer, insurer_helpline, insurer_email, document_type,
coverage_amount, deductible, premium_amount, premium_frequency,
effective_date, expiration_date, key_benefits[], exclusions[],
waiting_periods[], coverage_items[] (name, limit, limit_text, covered, notes),
executive_summary[]
```

Mobile fallback (`policy_extraction_service.dart`) extracts via 13 sequential Q&A queries when the backend summary endpoint is unavailable.

### 5.2 Motor-Specific Fields

Only type-specific extraction implemented. `MotorPolicyDetails` model with 10 fields (VIN, registration, NCB, IDV, etc.) — wired into backend prompt routing and mobile `PolicySummary` model.

### 5.3 Health-Specific Fields

Only `RoomRentCapExtraction` model exists. NOT wired into production pipeline. The backend extraction prompt has a health-specific scaffold that currently adds nothing:

```python
elif any(kw in doc_type_lower for kw in ("health", "mediclaim", "medical")):
    type_specific_fields = ""  # Placeholder — currently adds nothing
```

### 5.4 Life/Home/Travel-Specific Fields

None implemented. The extraction prompt uses only base fields for these types.

### 5.5 What-If Calculator Fields

The `WhatIfCalculator` (mobile) uses these configurable parameters:
- `coverageMultiplier` (0.5×–3.0×)
- `deductibleMultiplier` (0.5×–2.0×)
- `includeMaternity`, `includeDaycare`, `includePrePostHospital` (toggles)
- Base premium from the summary

Available types for What-If: Health only (design issue — should work for any type).

---

## 6. Test Fixture Reference

### 6.1 BR-02 Representative Corpus

| Key | Type | Insurer | Fixture Text | Verified Fields | Unsupported Fields | Tests |
|-----|------|---------|-------------|----------------|-------------------|-------|
| `health_insurance` | Health | Star Health | ₹5L sum insured, room rent cap, waiting periods, daycare | `policy_number, sum_insured, premium, policy_term` | `no_claim_bonus, maternity_cover` | 2 (faces + unsupported) |
| `motor_insurance` | Motor | ICICI Lombard | Swift VXI, IDV ₹5.5L, NCB 50%, OD ₹8.2k, TP ₹2.1k | `policy_number, idv, premium, ncb` | `add_on_deductible, personal_accident_cover` | 2 |
| `term_life` | Life | HDFC Life | ₹50L sum assured, 20yr term, nominee, terminal illness | `policy_number, sum_assured, premium, policy_term, nominee` | `critical_illness_cover, waiver_of_premium` | 2 |
| `travel_insurance` | Travel | Bajaj Allianz | Thailand, 15 days, USD 100K medical, evacuation | `policy_number, sum_insured, premium, policy_term` | `adventure_sports_cover, preexisting_condition_waiver` | 2 |
| `home_insurance` | Home | New India Assurance | Mumbai, ₹50L structure, ₹15L contents, fire/flood/quake | `policy_number, sum_insured, premium, policy_term` | `rent_cover, malicious_damage_cover` | 2 |

**Totals:** 5 entries, 10 face tests + 2 integrity tests = **12 tests**.

### 6.2 Policy Type Unit Tests

From `mobile/test/policy_type_test.dart`:
- Indian product names classified correctly (Mediclaim → health, Two Wheeler → auto, Term Plan → life)
- Canonical English types classified correctly (Home Insurance, Travel Insurance, null → other)

### 6.3 Motor Fields Unit Tests

From `mobile/test/motor_policy_fields_test.dart`: 10 tests covering:
- Full parsing with realistic values
- Null handling for each optional field
- Empty add-on covers list
- Round-trip JSON serialization
- `hasAnyFields` helper
- Backward compatibility with missing `motor_fields` key
- Non-motor policy (health) should not have motor_fields
- Partial data

### 6.4 Extraction Tests

From `tests/test_policy_extraction.py`:
- Default extraction returns null fields
- Full extraction with all fields populated
- Coverage items including uncovered items
- Backend service post-processing validation
- Field-level cleanup (whitespace, null, negative values)

### 6.5 Missing Fixtures

| Type | What's missing | Priority |
|------|---------------|----------|
| Any type | Real PDF/synthetic PDF fixtures (beyond corpus text) | Medium |
| Commercial | Any test data | Low |
| Liability | Any test data | Low |
| Cyber | Any test data | Low |
| Pet | Any test data | Low |

---

## 7. Claim Guide Reference

### 7.1 Supported Claim Guides

From `mobile/lib/services/policy_extraction_service.dart` → `getClaimGuide()`:

| Incident Type | Claim Guide Title | Steps | Required Documents | Mapped to Policy Type |
|--------------|-------------------|-------|-------------------|----------------------|
| `hospitalization` / `health` | Hospitalization Claim | 4 | 9 | health |
| `accident` / `auto` / `motor` | Auto Insurance Claim | 5 | 7 | auto |
| `death` / `life` | Life Insurance Death Claim | 4 | 7 | life |
| everything else | General Insurance Claim | 3 | 3 | fallback |

### 7.2 Missing Claim Guides

| Policy Type | Incident | Steps Available? |
|-------------|----------|-----------------|
| Home | Fire | ❌ Falls to General |
| Home | Burglary | ❌ Falls to General |
| Home | Natural disaster | ❌ Falls to General |
| Travel | Medical emergency | ❌ Falls to General |
| Travel | Baggage loss | ❌ Falls to General |
| Travel | Trip cancellation | ❌ Falls to General |
| Travel | Flight delay | ❌ Falls to General |
| Auto | Theft | ❌ Falls to General (despite auto having accident guide) |

---

## 8. What-If Calculator Reference

From `mobile/lib/utils/what_if_calculator.dart`:

**Purpose:** Estimate premium changes when adjusting coverage parameters.

**Parameters:**
- `coverageMultiplier` (0.5–3.0): How much coverage changes
- `deductibleMultiplier` (0.5–2.0): How much deductible changes
- `includeMaternity`, `includeDaycare`, `includePrePostHospital`: Toggle specific benefits on/off

**Current limitation:** Only works with health policies. Base premium is extracted from the generic pipeline. The model assumes health-specific fields — doesn't work for auto (IDV-based premium), life (age/gender-based), home (property value-based), or travel (destination/duration-based).

**What needs to happen for type-aware calculation:**
- Auto: Premium = f(IDV, NCB, add-on covers, vehicle age)
- Life: Premium = f(age, sum assured, term, smoking status)
- Home: Premium = f(sum insured, construction type, location)
- Travel: Premium = f(destination, duration, age, covers selected)

---

## 9. Coverage Type Explorer Reference

From `mobile/lib/widgets/dashboard/coverage_type_explorer.dart`:

**What it shows:**
- A row/column of clickable type cards (Health, Auto, Life, Home, Travel, Other)
- Each card shows: icon, short name, document count
- When tapped: selected card highlights, detail panel shows description

**Data source:** `InsuranceDocument.documentType` → `classifyPolicyType()` → count per type

**Analytics event:** `dashboard_coverage_type_tapped` with `type_name` and `document_count`

---

## 10. Gap Summary: What to Add Next

### P0: Needed for type completeness

| Gap | Where | Effort | Why P0 |
|-----|-------|--------|--------|
| No home specific-field extraction | `policy_extraction_service.py` | Medium | Home BR-02 fixture exists but pipeline ignores type-specific fields |
| No travel specific-field extraction | `policy_extraction_service.py` | Medium | Travel BR-02 fixture exists but pipeline ignores type-specific fields |
| No life specific-field extraction | `policy_extraction_service.py` | Medium | Life BR-02 fixture has nominee, term length but pipeline ignores them |
| No health specific-field extraction (beyond RoomRentCap model) | `policy_extraction_service.py` | Medium | Health is the most common type but pipeline doesn't extract waiting periods, co-pay, network hospitals |

### P1: Important but not blocking

| Gap | Where | Effort | Why P1 |
|-----|-------|--------|--------|
| Missing claim guides for home/travel | `policy_extraction_service.dart` | Medium | These are the next most common claims after health/auto/life |
| No fallback for travel/home in `document_processing_job.py` | `document_processing_job.py` | Easy | Currently only health/auto/life have text fallback |
| What-If calculator only works for health | `what_if_calculator.dart` | Large | Only type-specific What-If models would enable this |
| Missing 5+ PolicyType enum values | `policy_type.dart` | Medium | liability, marine, cyber, pet, commercial have no dedicated PolicyType |
| LLM classifier prompt only lists 5 types | `document_classifier.py` | Easy | Should mention: Liability, Marine, Cyber, Pet, Event as possible values |

### P2: Polish / long-term

| Gap | Where | Effort | Why P2 |
|-----|-------|--------|--------|
| Type-specific UI cards (show VIN for auto, destination for travel) | `policy_detail_screen.dart` | Medium | Currently shows generic fields for all types |
| Real PDF fixtures per type | `tests/` | Medium | Would need synthetic PDF generators per type |
| International format support | classifier + extraction | Large | Indian-market-heavy; non-Indian policies may not extract correctly |
| Type-aware Gap detection (missing NCB for auto, etc.) | `policy_extraction_service.dart` | Medium | Currently only checks for missing type presence, not field quality |

### P3: Exploratory / out of scope

| Gap | Where | Effort | Why P3 |
|-----|-------|--------|--------|
| Full support for all 16 known insurance types | System-wide | Massive | Requires classifiers, UI, extraction, fixtures, claim guides |
| What-If for non-health types | `what_if_calculator.dart` | Large | Requires actuarial-like models per type |

---

## 11. Known Insurance Types Not Yet Supported

### 11.1 Liability Insurance

**What it covers:** Legal liability to third parties for bodily injury or property damage.

| Sub-type | Description | Common in India |
|----------|-------------|-----------------|
| Public Liability | Injury to public on premises | Yes (Public Liability Act) |
| Product Liability | Defective products cause harm | Yes |
| Professional Indemnity | Negligence in professional services | Yes (doctors, lawyers, CA) |
| Directors & Officers | Wrongful acts by board members | Yes (listed companies) |
| Employers Liability | Injury to employees at work | Yes (Employees Compensation Act) |
| Pollution Liability | Environmental damage | Emerging |

**Why not supported:** Not a priority for individual policyholders. Corporate product.

### 11.2 Marine / Cargo Insurance

**What it covers:** Loss/damage to ships, cargo, and freight.

| Sub-type | Description |
|----------|-------------|
| Hull Insurance | Damage to the ship/vessel |
| Cargo Insurance | Loss/damage to goods in transit |
| Freight Insurance | Loss of freight revenue |
| Marine Liability | Third-party claims from shipping operations |

**Why not supported:** Niche business-to-business product. Individual policyholders rarely need it.

### 11.3 Cyber Insurance

**What it covers:** Data breaches, cyber extortion, business interruption from cyber events.

| Sub-type | Description |
|----------|-------------|
| Data Breach Response | Notification costs, credit monitoring |
| Cyber Extortion | Ransomware payments |
| Business Interruption | Revenue loss from IT shutdown |
| Network Security Liability | Lawsuits from third-party data exposure |
| Regulatory Defense | Fines and penalties from data protection authorities |

**Why not supported:** Emerging market in India. Post-personal-data-protection-bill adoption is low for individuals. Corporate product.

### 11.4 Pet Insurance

**What it covers:** Veterinary bills, third-party liability for pet-caused damage, loss/theft.

| Sub-type | Description |
|----------|-------------|
| Accident-only | Vet bills from accidents |
| Comprehensive | Accidents + illness |
| Wellness | Vaccinations, checkups |
| Third-party Liability | Pet causes injury or property damage |

**Why not supported:** Very low penetration in India. Available but niche.

### 11.5 Event Insurance

**What it covers:** Cancellation, postponement, abandonment of events.

| Sub-type | Description |
|----------|-------------|
| Event Cancellation | Losses from cancelling weddings, conferences, concerts |
| Event Liability | Injury to attendees |
| Equipment Cover | Damage to rented/owned event equipment |

**Why not supported:** Niche. Single-use product.

### 11.6 Mobile / Device Insurance

**What it covers:** Screen damage, theft, liquid damage for phones/laptops.

| Sub-type | Description |
|----------|-------------|
| Accidental Damage | Screen/body damage |
| Theft | Theft of device |
| Liquid Damage | Water damage |
| Extended Warranty | Beyond manufacturer warranty |

**Why not supported:** Usually bundled with credit cards or sold as add-ons. Not a traditional "policy document."

### 11.7 Commercial Insurance (Business)

**What it covers:** Business interruption, property, liability, and employee-related risks.

| Sub-type | Description |
|----------|-------------|
| Business Interruption | Revenue loss from shutdown |
| Commercial Property | Physical assets of the business |
| Commercial General Liability | Third-party claims against the business |
| Workers Compensation | Employee injury |
| Fidelity Guarantee | Employee fraud/theft |
| Keyman Insurance | Death of key employee |

**Why not supported:** Corporate product. Out of scope for individual policyholders.

### 11.8 Engineering Insurance

**What it covers:** Construction and engineering project risks.

| Sub-type | Description |
|----------|-------------|
| Contractors All Risk | Building/project damage during construction |
| Erection All Risk | Plant/machinery erection |
| Machinery Breakdown | Infrastructure breakdown |
| Electronic Equipment | Equipment damage |
| Boiler & Pressure Vessel | Explosion/rupture |
| Delay in Start-up | Revenue loss from project delays |

**Why not supported:** Corporate/institutional product. Niche.

### 11.9 Aviation Insurance

**What it covers:** Aircraft hull, passenger liability, cargo.

| Sub-type | Description |
|----------|-------------|
| Hull Insurance | Aircraft damage |
| Passenger Liability | Injury/death to passengers |
| Cargo Liability | Damaged/lost air cargo |
| Ground Risk | Damage on the ground |
| Hangar Keepers | Damage while in hangar |
| Aviation Product Liability | Defective aircraft parts |

**Why not supported:** Corporate/airline product. Niche.

### 11.10 Agriculture Insurance

**What it covers:** Crop yield loss, livestock death, farm equipment.

| Sub-type | Description |
|----------|-------------|
| Crop Insurance | Yield loss from weather/pests |
| Livestock Insurance | Death of cattle/poultry |
| Aquaculture Insurance | Fish/shrimp farming loss |
| Forestry Insurance | Timber loss |
| Farm Equipment Insurance | Tractor/harvester damage |
| Weather Index Insurance | Payout based on weather index |

**Why not supported:** Government-supported (PMFBY) in India but requires different UX (mandatory enrollment, village-level data, multiple crops). Entirely different product flow.

---

## Appendix A: File Reference

| File | Role |
|------|------|
| `mobile/lib/utils/policy_type.dart` | Mobile-side classification, icons, colors (6 types) |
| `mobile/lib/utils/document_icons.dart` | Re-exports from policy_type.dart |
| `mobile/lib/models/policy_summary.dart` | Mobile policy model (generic + MotorPolicyFields) |
| `mobile/lib/services/policy_extraction_service.dart` | Mobile extraction + claim guides + coverage gaps |
| `mobile/lib/services/policy_extraction_helpers.dart` | Pure helper functions (clean, parse) |
| `mobile/lib/services/document_service.dart` | Document upload + type inference from filename |
| `mobile/lib/widgets/document_type_picker.dart` | Manual type override dialog |
| `mobile/lib/widgets/dashboard/coverage_type_explorer.dart` | Dashboard type explorer |
| `mobile/lib/widgets/shared/policy_type_icon.dart` | Icon widget |
| `mobile/lib/widgets/document_thumbnail.dart` | Thumbnail with type icon |
| `mobile/lib/utils/what_if_calculator.dart` | Premium estimator (health only) |
| `src/utils/document_classifier.py` | Backend classifier (2-tier: keywords → LLM) |
| `src/models/extraction.py` | Backend extraction models (generic + MotorPolicyDetails + RoomRentCapExtraction) |
| `src/services/policy_extraction_service.py` | Backend extraction service (type-aware prompt routing) |
| `src/services/document_processing_job.py` | Processing job + fallback classification |
| `tests/test_br02_representative_corpus.py` | 5-type representative corpus (12 tests) |
| `mobile/test/policy_type_test.dart` | Mobile classification unit tests |
| `mobile/test/motor_policy_fields_test.dart` | Motor fields parsing tests |
| `tests/test_policy_extraction.py` | Extraction pipeline tests |
| `docs/research/insurance_type_coverage_map.md` | Summary coverage map |

## Appendix B: How to Add a New Insurance Type

1. **Backend classifier:** Add keyword list to `src/utils/document_classifier.py::type_keywords`
2. **Mobile classifier:** Add keyword conditions to `classifyPolicyType()` in `policy_type.dart`
3. **UI enum:** Add value to `PolicyType` enum (if not covered by `other`)
4. **UI icon/color:** Add `iconForPolicyType()` / `colorForPolicyType()` / `canonicalTypeName()` cases
5. **UI description:** Add to `_typeDescriptions` in `coverage_type_explorer.dart`
6. **Extraction model:** Add Pydantic model in `src/models/extraction.py` (e.g., `TravelPolicyDetails`)
7. **Backend prompt routing:** Add type-specific fields in `src/services/policy_extraction_service.py`
8. **Mobile model:** Add fields to `PolicySummary` in `policy_summary.dart` + `toJson`/`fromJson`
9. **Test fixture:** Add corpus entry in `tests/test_br02_representative_corpus.py`
10. **Unit tests:** Add `mobile/test/{type}_fields_test.dart` + update `policy_type_test.dart`
11. **Claim guide:** Add case to `getClaimGuide()` in `policy_extraction_service.dart`
12. **Coverage gaps:** Add type-specific gap detection to `analyzeCoverageGaps()`
13. **Fallback:** Update text fallback in `document_processing_job.py`
14. **What-If:** Extend calculator if the type supports premium modelling
15. **Coverage map:** Update `docs/research/insurance_type_coverage_map.md`
16. **This document:** Update this reference
