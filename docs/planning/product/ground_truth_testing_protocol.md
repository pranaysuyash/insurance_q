# Ground Truth Testing Protocol

## Overview

This protocol defines how to test the CoverWise app's core extraction and Q&A pipeline using **serve-sim** (iOS simulator) and **ground truth data** (known-good expected values for real policy documents).

The goal is to verify that:
1. **Document upload + extraction** produces the expected fields for each policy type
2. **Q&A** answers correctly reflect the policy content
3. **Verification badges** (`fully_backed`, `partially_backed`, `abstained`) render correctly

## Prerequisites

| Item | Status | Notes |
|------|--------|-------|
| Xcode 15+ | ✅ | iOS simulator runtime installed |
| Flutter SDK | ✅ | On PATH |
| iOS simulator | ⚠️ | Created (`iPhone 16`, iOS 18.x) |
| CoverWise API | ⚠️ | Running locally on port 8000 |
| `.env` file | ✅ | Supabase keys present |
| Policy PDFs | ⚠️ | Add more in `mobile/assets/ground_truth/` |
| Ground truth JSONs | ✅ | One per policy PDF in `mobile/assets/ground_truth/` |

## Quick Start

### 1. Start the API

```bash
cd /path/to/insurance_app
source .env
.venv/bin/uvicorn src.app.main:app --host 127.0.0.1 --port 8000
```

### 2. Run a ground truth check

```bash
python tools/verify_ground_truth.py \
  --ground-truth mobile/assets/ground_truth/health_01.json \
  --api-url http://127.0.0.1:8000
```

This uploads the document, polls for extraction, compares fields, asks sample questions, and reports pass/fail.

### 3. Launch on iOS Simulator

```bash
tools/run_ios_simulator.sh
```

Then manually:
- Navigate to the document upload screen
- Upload the demo policy
- Wait for extraction
- Compare the results to the ground truth JSON
- Ask the known-answer questions from the ground truth
- Verify the answer badges render correctly

## Ground Truth Format

Each policy document has a matching JSON file in `mobile/assets/ground_truth/`.

See [GROUND_TRUTH_SCHEMA.md](../../mobile/assets/ground_truth/GROUND_TRUTH_SCHEMA.md) for the full schema.

### Creating a ground truth entry

```
mobile/assets/ground_truth/
├── GROUND_TRUTH_SCHEMA.md
├── health_01.json          ← ICICI Lombard Complete Health
├── motor_01.json           ← Bajaj Allianz Motor Insurance
├── travel_01.json          ← Tata AIG Travel Insurance
└── ...
```

1. Add the PDF to `mobile/assets/ground_truth/`
2. Review the PDF and fill in the expected extraction values
3. Write 5–10 known-answer Q&A pairs
4. Run the verifier:
   ```bash
   python tools/verify_ground_truth.py --ground-truth mobile/assets/ground_truth/motor_01.json
   ```

## Test Areas

### Area 1: Extraction Accuracy

| Test | What to check | Passing criteria |
|------|---------------|------------------|
| Generic fields | policy_number, insurer, coverage_amount, dates | ≥ 80% match |
| Type-specific fields | health: room_rent_cap, co_pay; motor: VIN, NCB; etc. | ≥ 70% match |
| Key benefits | List matches policy wording | ≥ 3 expected items present |
| Executive summary | 3-bullet summary makes sense | No obvious contradictions |

### Area 2: Q&A Correctness

| Test | What to check | Passing criteria |
|------|---------------|------------------|
| Known answers | Questions from ground truth | ≥ 80% contain expected text |
| Verification status | Badge shows correctly | `fully_backed` for cited fields |
| Unknown fields | "Not found in your policy" | `abstained` or clear message |

### Area 3: UI Verification (Simulator)

| Test | What to check | Passing criteria |
|------|---------------|------------------|
| Policy detail screen | All fields render | No layout overflow |
| Coverage summary | Type-specific section visible | Tab appears for the policy type |
| Q&A screen | Badge shows | Verification status visible |
| Source references | Citations tappable | Opens document preview |

## Adding a new policy PDF

1. Drop the PDF into `mobile/assets/ground_truth/`
2. Create `mobile/assets/ground_truth/{type}_{seq}.json`
3. Fill in the expected fields (mark unknowns as `null`)
4. Add at least 5 known-answer questions
5. Run the verifier to confirm it passes initial checks:
   ```bash
   python tools/verify_ground_truth.py \
     --ground-truth mobile/assets/ground_truth/health_01.json \
     --api-url http://127.0.0.1:8000
   ```
6. Commit the PDF + ground truth JSON together

## Appendix: Useful simulator commands

```bash
# List available simulators
xcrun simctl list devices available

# Create a new simulator
xcrun simctl create "CoverWise iPhone" "iPhone 16" "iOS18.0"

# Boot a specific simulator
xcrun simctl boot <UDID>

# Open Simulator app
open -a Simulator

# Install app
cd mobile && flutter install

# View logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.coverwise.app"'
```
