# Ground Truth Schema — Policy Document Extraction Testing

## Purpose

Each ground truth JSON file captures the **expected extraction result** for a specific policy PDF document. The ground truth runner (`tools/verify_ground_truth.py`) uploads the document, fetches the extraction, and compares actual vs expected values, reporting passes and failures.

## File naming convention

```
mobile/assets/ground_truth/{policy_type}_{sequence}.json
```

Examples:
- `health_01.json`
- `motor_01.json`
- `travel_01.json`
- `life_01.json`
- `home_01.json`

## Schema

```json
{
  "$schema": "Ground truth schema for policy document extraction testing",
  "version": "1.0.0",

  "meta": {
    "policy_document": "assets/demo/policy.pdf",
    "policy_type": "health|motor|travel|life|home|cyber|marine|liability|pet",
    "insurer": "Insurance company name",
    "description": "One-line description of this policy document",
    "added_by": "CoverWise team",
    "added_date": "2026-07-28"
  },

  "expected_extraction": {
    "policy_number": "Expected policy number or null",
    "insurer": "Expected insurer name or null",
    "insurer_helpline": "Expected helpline or null",
    "insurer_email": "Expected email or null",
    "document_type": "Expected document type string",
    "coverage_amount": 5000000.0,
    "deductible": null,
    "premium_amount": null,
    "premium_frequency": null,

    "key_benefits": [
      "Expected benefit 1",
      "Expected benefit 2"
    ],
    "exclusions": [
      "Expected exclusion 1"
    ],
    "waiting_periods": [
      "Expected waiting period 1"
    ],
    "coverage_items": [
      {
        "name": "Room Rent",
        "limit": 5000,
        "limit_text": null,
        "covered": true,
        "notes": null
      }
    ],
    "executive_summary": [
      "Expected executive summary point 1",
      "Expected executive summary point 2",
      "Expected executive summary point 3"
    ],

    "type_specific": {
      "health": {
        "room_rent_cap": "Expected room rent cap or null",
        "co_pay_percent": 10.0,
        "network_hospitals": "Expected network info or null",
        ...
      },
      "motor": {
        "vehicle_registration_number": "Expected reg number or null",
        ...
      },
      "travel": {
        "destination": "Expected destination or null",
        ...
      },
      "life": {
        "sum_assured": 1000000.0,
        ...
      },
      "home": {
        "property_address": "Expected address or null",
        ...
      }
    }
  },

  "expected_questions": {
    "known_answers": [
      {
        "question": "What is my sum insured?",
        "expected_answer_contains": "50 lakhs",
        "citation_page": null,
        "verification_status": "fully_backed|partially_backed|abstained|unverified"
      },
      {
        "question": "Is maternity covered?",
        "expected_answer_contains": "waiting period of 9 months",
        "verification_status": "fully_backed"
      }
    ],
    "known_fields_not_present": [
      "This policy does NOT have a specific field"
    ]
  },

  "expected_badges": {
    "policy_detail": "fully_backed|partially_backed|abstained|unverified",
    "question_answer": {
      "typical": "fully_backed|partially_backed|abstained"
    }
  }
}
```

## Validation

Each ground truth file should:
1. Have a unique `meta.policy_document` path
2. Specify the `meta.policy_type` correctly
3. Mark truly unknown fields as `null` (not empty string or 0)
4. Provide at least 5 `expected_questions.known_answers`
5. Include type-specific fields in `expected_extraction.type_specific` matching the policy type

## Adding a new ground truth entry

1. Upload the PDF to `mobile/assets/ground_truth/`
2. Create the JSON file following this schema
3. Verify by running:
   ```bash
   python tools/verify_ground_truth.py --ground-truth mobile/assets/ground_truth/{file}.json --api-url http://127.0.0.1:8000
   ```
