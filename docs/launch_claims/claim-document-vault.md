# Launch claim: Claim Document Vault auto-extracted fields

**Source ADR:** [ADR-2026-07-19-19](../decisions/ADR-2026-07-19-19-claim-document-vault-substrate-extension.md)

## Approved wording

CoverWise can automatically extract key details from uploaded claim documents
(discharge summaries, diagnosis info, treatment details).

## Explicit limitations

- Auto-extracted fields are substrate-grounded and subject to the four-face
  evidence-backed contract.
- User-assigned tags are NOT substrate-grounded. They are the user's own
  classification.
- The Claim Document Vault may contain medical records. The privacy policy
  covers: consent purpose (`medical_records`), retention period, encryption at
  rest, support-operator access (read-only, with reason, audit-logged),
  user's right to export (PDF) and delete.
- The formal consent purpose, retention enforcement, and per-document encryption
  are deferred to a future ADR (following the ADR-15 pattern).

## Implementation owners

- Auto-extraction pipeline: `src/services/evidence_pipeline.py` extension
- Privacy policy: In-app disclosure card, consent ledger `medical_records`
- UI vault surface: Claim Document Vault (per ADR-08 #7)

## Verification gates

| Component | Current evidence | Required before launch claim |
|-----------|-----------------|------------------------------|
| Auto-extraction | Tier 0: not implemented | Extractor + four-face contract |
| Privacy disclosure | Tier 0: not implemented | In-app disclosure card |
| Consent purpose | Tier 0: not registered | `medical_records` in consent ledger |
| No-share CI test | Tier 0: not implemented | Scans for data sharing outside vault |

## Revisit trigger

Revisit if the medical-records privacy policy is formalized, if a new
extraction field is added, or if support-operator access rules change.
