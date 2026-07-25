# Insurance Type Coverage Map

> **Created:** 2026-07-25  
> **Source:** Codebase analysis (mobile `policy_type.dart`, backend `document_classifier.py`, extraction pipeline, test fixtures, UI components)  
> **Purpose:** Summary reference for what insurance types CoverWise supports today.  
> **🔄 See also:** 
> - [`docs/research/all_insurance_document_types.md`](./all_insurance_document_types.md) — codebase-wide audit (classifier, UI, extraction, fixtures, claim guides)
> - [`docs/research/insurance_fields_and_questions_matrix.md`](./insurance_fields_and_questions_matrix.md) — **complete** field-by-type + question-by-type reference (the place to start before building any type-specific feature)
> **Maintainers:** Engineering (solo founder)  
> **Next review:** When adding a new insurance type or classifier keyword.

---

## 1. Current Coverage by Insurance Type

| Type | Backend classifier | Mobile classifier | UI icon + color | Test fixtures | Extraction pipeline | Status |
|------|-------------------|-------------------|-----------------|---------------|-------------------|--------|
| **Health** | ✅ 15+ keywords (health, mediclaim, medical, family floater, critical illness, healthguard, etc.) | ✅ health, mediclaim, medical, family floater, critical illness, healthguard | Monitor heart icon, red color | ✅ ICICI Lombard health policy (BR-02 corpus) | ✅ Full pipeline — fields extracted: policy number, insurer, dates, premium, sum insured, waiting periods, exclusions, coverage items | **Full support** |
| **Auto/Motor** | ✅ 15+ keywords | ✅ auto, motor, car, vehicle, two wheeler, bike, commercial vehicle | Car icon, blue color | ✅ ICICI Lombard motor policy (IDV, NCB fields) | ✅ **Type-specific:** VIN, registration, NCB %, IDV, add-on covers via `MotorPolicyDetails` + `_VehicleDetailsCard` | **Full support** |
| **Life** | ✅ Keywords (life, beneficiary, term life, cash value, etc.) | ✅ life, term, ULIP, endowment, pension, annuity | Person icon, purple color | ✅ HDFC term life policy (20-yr term, nominee, terminal illness benefit) | ✅ **Type-specific:** Life assured, sum assured, policy term, nominee, riders, provisions via `LifePolicyDetails` + `_LifeDetailsCard` | **Full support** |
| **Home/Property** | ✅ Keywords (home, property, dwelling, fire, theft, flood, earthquake, mortgage) | ✅ home, house, property, fire, burglary | Home icon, indigo | ❌ None | ✅ **Type-specific:** Property address, building/contents sum insured, rebuild cost, perils, add-on covers via `HomePolicyDetails` + `_HomeDetailsCard` | **Full support** |
| **Travel** | ✅ 27 keywords added (2026-07-25) | ✅ travel, overseas, trip, itinerary | Flight icon, orange | ✅ Synthetic travel policy in BR-02 corpus | ✅ **Type-specific:** Destination, trip dates, covers (medical, baggage, cancellation, flight delay) via `TravelPolicyDetails` + `_TravelDetailsCard` | **Full support** |
| **Asset/Property** | Via "home" keywords above | Via "home" classification above | Home icon | ❌ None | ✅ Generic pipeline only | **Minimal — gap** |
| **Liability** | ❌ None | Falls to `other` | Inventory icon | ❌ None | ❌ No specific extraction | **Not supported** |
| **Marine/Cargo** | ❌ None | Falls to `other` | Inventory icon | ❌ None | ❌ No specific extraction | **Not supported** |
| **Cyber** | ❌ None | Falls to `other` | Inventory icon | ❌ None | ❌ No specific extraction | **Not supported** |
| **Pet** | ❌ None | Falls to `other` | Pets icon | ❌ None | ❌ No specific extraction | **Not supported** |
| **Event/Cancellation** | ❌ None | Falls to `other` | Inventory icon | ❌ None | ❌ No specific extraction | **Not supported** |
| **Mobile/Device** | ❌ None | Falls to `other` | Inventory icon | ❌ None | ❌ No specific extraction | **Not supported** |

---

## 2. Backend Classification: `src/utils/document_classifier.py`

### Keywords by type

| Type | Keywords |
|------|----------|
| **Health** | `health`, `mediclaim`, `medical`, `hospital`, `surgical`, `prescription`, `diagnostic`, `outpatient`, `inpatient`, `pre-existing`, `co-pay`, `family floater`, `critical illness`, `wellness`, `preventive care`, `emergency room` |
| **Auto** | `auto`, `vehicle`, `car`, `collision`, `VIN`, `odometer`, `liability`, `comprehensive`, `deductible`, `no-claim`, `NCB`, `IDV` |
| **Home** | `home`, `property`, `dwelling`, `fire`, `theft`, `flood`, `earthquake`, `mortgage`, `contents`, `burglary` |
| **Life** | `life`, `beneficiary`, `term life`, `cash value`, `death benefit`, `maturity`, `premium waiver`, `terminal illness`, `nominee`, `surrender` |
| **Travel** | ❌ **No keywords defined** |

### Insurer detection

Covers 30+ Indian and US insurers (ICICI Lombard, HDFC ERGO, Bajaj Allianz, Star Health, New India Assurance, United India, Oriental, National, Max Bupa, Apollo Munich, Religare, Cigna TTK, SBI Life, LIC, HDFC Life, ICICI Prudential, Birla Sun Life, Kotak, State Farm, Allstate, Geico, Progressive, Liberty Mutual, Nationwide, Travelers, MetLife, Aflac, Cigna, Aetna, UnitedHealthcare, Humana, Anthem, Kaiser, Blue Cross, Blue Shield, etc.)

Source: `_extract_insurer()` method using regex patterns + company name dictionary.

---

## 3. Mobile Classification: `mobile/lib/utils/policy_type.dart`

### `classifyPolicyType(String documentType) → PolicyType enum`

| Input string (lowercased) | Classification |
|--------------------------|----------------|
| `health`, `mediclaim`, `medical`, `family floater`, `critical illness`, `healthguard` | `PolicyType.health` |
| `life`, `term`, `ULIP`, `endowment`, `pension`, `annuity` | `PolicyType.life` |
| `auto`, `motor`, `car`, `vehicle`, `two wheeler`, `bike`, `commercial vehicle` | `PolicyType.auto` |
| `home`, `house`, `property`, `fire`, `burglary` | `PolicyType.home` |
| `travel`, `overseas`, `trip`, `itinerary` | `PolicyType.travel` |
| Everything else | `PolicyType.other` |

### Missing from mobile classification

- No `Asset` type (falls to `other`)
- No `Liability` type (falls to `other`)
- No `Marine` type (falls to `other`)
- No `Cyber` type (falls to `other`)
- No `Pet` type (falls to `other`)
- No `Event` type (falls to `other`)

### UI mapping

| `PolicyType` | Icon | Color |
|-------------|------|-------|
| `health` | `Icons.monitor_heart_outlined` | `Color(0xFFD32F2F)` (red) |
| `auto` | `Icons.directions_car_outlined` | `Color(0xFF1565C0)` (blue) |
| `life` | `Icons.person_outline` | `Color(0xFF7B1FA2)` (purple) |
| `home` | `Icons.home_outlined` | `Color(0xFF5E35B1)` (indigo) |
| `travel` | `Icons.flight_takeoff` | `Color(0xFFE65100)` (orange) |
| `other` | `Icons.inventory_2_outlined` | `Color(0xFF546E7A)` (blue-grey) |

---

## 4. Extraction Pipeline Capabilities

The pipeline (`evidence_pipeline.py`) is **generic** — it extracts the same set of fields regardless of document type:

| Field | All types |
|-------|-----------|
| Policy number | ✅ |
| Insurer name | ✅ |
| Policy start/end dates | ✅ |
| Premium amount | ✅ |
| Sum insured / cover amount | ✅ |
| Policy holder name | ✅ |
| Nominee | ✅ (if present) |

### ✅ Type-specific extractors (resolved 2026-07-25)

The pipeline now extracts type-specific fields for 4 types:

| Type | Fields extracted | Backend model | Mobile model | Test coverage |
|------|-----------------|--------------|-------------|---------------|
| **Auto** | VIN, registration number, NCB %, IDV, add-on covers, own/TP premium | `MotorPolicyDetails` | `MotorPolicyFields` | 9 tests |
| **Life** | Life assured, sum assured, policy term, nominee, riders, provisions | `LifePolicyDetails` | `LifePolicyFields` | 12 tests |
| **Home** | Property address, building/contents sum insured, rebuild cost, perils, add-on covers | `HomePolicyDetails` | `HomePolicyFields` | 8 tests |
| **Travel** | Destination, trip dates, covers (medical, baggage, cancellation, flight delay), add-ons | `TravelPolicyDetails` | `TravelPolicyFields` | 10 tests |
| **Health** | Room rent cap, pre-existing diseases, co-pay %, network hospitals, maternity, ambulance cover, cumulative bonus, pre/post hospitalization days, restoration benefit, critical illness list, modern treatment cover, moratorium period, pre-auth time limit | `HealthPolicyDetails` | `HealthPolicyFields` | 14 tests |

---

## 5. Test Fixtures by Insurance Type

| Type | Fixture file | What it covers |
|------|-------------|----------------|
| **Health** | BR-02 corpus | ICICI Lombard health policy — standard fields, waiting periods, exclusions |
| **Auto** | BR-02 corpus | ICICI Lombard motor policy — IDV, NCB, vehicle details |
| **Life** | BR-02 corpus | HDFC term life — 20-yr term, nominee, terminal illness benefit |
| **Home** | ❌ None | — |
| **Travel** | ❌ None | — |
| Other types | ❌ None | — |

---

## 6. Gaps Summary

### 🔴 Critical gaps (blocks new type support)

| Gap | Affects | Level of effort |
|-----|---------|-----------------|
| No auto/life/home/travel test fixtures beyond BR-02 corpus synthetic entries | Non-medical types | Medium (create real fixtures) |

### 🟡 Medium gaps (improves existing support)

| Gap | Affects | Level of effort |
|-----|---------|-----------------|
| Mobile classifier missing several policy types (asset, liability, marine, cyber, pet) | Those types default to `other` | Easy (add enum values + icon/color) |
| No exploration/research on non-Indian policy formats | All types | Research task |

### 🟢 Resolved gaps (✅ DONE 2026-07-25)

| Gap | Resolution |
|-----|-----------|
| No travel keywords in backend `document_classifier.py` | ✅ 27 travel keywords added |
| No travel/home/liability/marine/cyber test fixtures | ✅ Travel + home synthetic fixtures in BR-02 corpus |
| Generic extraction pipeline doesn't extract type-specific fields | ✅ Type-aware extractors for Auto, Life, Home, Travel, Health |
| No type-specific UI cards (e.g., auto: show VIN; travel: show destination) | ✅ `_VehicleDetailsCard`, `_LifeDetailsCard`, `_HomeDetailsCard`, `_TravelDetailsCard`, `_HealthDetailsCard` |
| No extraction test for home/travel/health documents | ✅ 8 home + 10 travel + 8 health model tests |
| No travel insurance recognition despite mobile UI having the icon + color | ✅ Travel classifier keywords + backend extraction + UI card |
| BR-02 fixtures have type-specific fields but pipeline ignores them | ✅ Pipeline now routes type-specific fields for 5 types |
| No type-specific extraction for Health (waiting period, co-pay, network hospitals, pre-existing diseases) | ✅ `HealthPolicyDetails` model, health prompt routing, `_HealthDetailsCard` UI card, 8 tests |

---

## 7. Architecture: Separation of Concerns

Per motto §0.15 (Third-Layer Rule), the three layers for insurance type support:

| Layer | Current state | Gap |
|-------|--------------|-----|
| **1. Model (LLM + classification)** | Classification works for 5 types via keyword + LLM fallback. LLM can theoretically classify any type. | No travel keywords in classifier. LLM-based classification is a fallback, not primary path. |
| **2. Pipeline (extraction, validation, routing)** | Single generic pipeline for all types. No type-aware routing. | No `extract_type_specific_fields()` per type. No validation rules per type. |
| **3. Data/configuration layer** | Keywords, insurer dictionary, icon/color maps exist for 5 types. | Missing travel keywords. No type-specific extraction schemas. No type-specific test fixtures. |

---

## 8. Recommended Next Steps

### ✅ P0 Done (2026-07-25)

1. ✅ **Add travel keywords** to `src/utils/document_classifier.py` — 27 keywords added
2. ✅ **Add travel test fixture** — created travel/synthetic travel policy in BR-02 corpus
3. ✅ **Add home test fixture** — created home insurance entry in BR-02 corpus

### ✅ P2 Done (2026-07-25)

4. ✅ **Type-aware extraction pipeline** — per-type extractors for Auto, Life, Home, Travel, Health with backend prompt routing + mobile model + tests
5. ✅ **Type-specific UI cards** — `_VehicleDetailsCard`, `_LifeDetailsCard`, `_HomeDetailsCard`, `_TravelDetailsCard`, `_HealthDetailsCard` — all in `policy_detail_screen.dart`

### Remaining (not yet done)

6. **Add missing PolicyType enum values** to `mobile/lib/utils/policy_type.dart` — `asset`, `liability`, `marine`, `cyber`, `pet` — with icon/color mappings (or decide scope: does the product need these?)

---

## 9. Related Files

| File | Role |
|------|------|
| `src/utils/document_classifier.py` | Backend document type + insurer classification |
| `mobile/lib/utils/policy_type.dart` | Mobile-side classification, icons, colors |
| `mobile/lib/widgets/document_type_picker.dart` | UI for manually changing document type |
| `mobile/lib/utils/document_icons.dart` | Re-export for backward compatibility |
| `src/services/policy_extraction_service.py` | Extraction service (type-aware logic lives here) |
| `mobile/assets/demo/policy.pdf` | Demo health policy PDF |
| `docs/planning/product/testing_strategy.md` | Test strategy document |
| `docs/technical/document_intelligence_capability_matrix_2026-07-21.md` | Capability matrix |

---

## 10. Anything Else?

- **Indian market focus**: The insurer detection dictionary and test fixtures are heavily India-focused. Non-Indian policy formats may not be classified correctly. If the app targets global users, this needs research.
- **No exploration map exists for non-medical types**: This document serves as that map going forward. Future agents should check here before adding new type support.
- **The mobile UI already has icons and colors for travel** (`flight_takeoff` icon, orange color) — but the backend classifier doesn't recognize travel keywords. This is an inconsistency — the UI is ahead of the backend for travel type.
- **Type-aware extraction is the biggest lift**: Adding classification keywords is easy (minutes). Adding type-specific extraction modules is a multi-commit effort with tests, validation, and evidence tiers.
