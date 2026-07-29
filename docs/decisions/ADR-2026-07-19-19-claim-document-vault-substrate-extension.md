# ADR-2026-07-19-19: Claim Document Vault substrate extension — per-document fields for the "your claim paperwork" filing cabinet

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The Claim Document Vault (per ADR-2026-07-19-08 #3) requires a substrate extension for the document metadata.** The vault stores claim paperwork (discharge summaries, approval letters, settlement statements, denial letters, follow-up emails, photos of receipts). The metadata per document is: document type, document date, document issuer, document amount, claim status. The extension adds **5 per-document substrate fields** to the existing `extracted_fields` table. The parser pipeline gains 3 new extractors (1 deterministic, 2 LLM with honesty check). The parser pipeline bumps to v5. The four-face contract (per ADR-2026-07-19-09) applies to the auto-extracted fields. The user-assigned tags are not substrate-grounded; they are user metadata. The Claim Document Vault is unblocked once the extension is in place.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** the Claim Document Vault substrate extension adds 5 per-document fields (`document_type`, `document_date`, `document_issuer`, `document_amount`, `claim_status`) to the existing `extracted_fields` table. The parser pipeline gains 3 new LLM extractors and bumps to v5. The four-face contract applies to the auto-extracted fields; the user-assigned tags are not substrate-grounded. The Claim Document Vault surface (per ADR-2026-07-19-08 #3) is unblocked once this ADR is implemented. The vault ships with the minimum-viable privacy stance (per ADR-15's deferred state: no-share + principal encryption at rest + user's right to delete). The pattern follows ADR-14. Implementation may begin in dependency order: migration → 3 LLM extractors → parser pipeline v5 → tests → launch-claim registry entry → canonical doc update. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) #3 (the Claim Document Vault that this ADR unblocks), [ADR-2026-07-19-15](./ADR-2026-07-19-15-claim-document-vault-privacy-policy.md) (the deferred privacy policy), [ADR-2026-07-19-14](./ADR-2026-07-19-14-family-coverage-map-substrate-extension.md) (the precedent: columns on `extracted_fields`, parser pipeline v2, four-face contract).

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The Claim Document Vault requires per-document substrate fields. 5 new columns on the existing `extracted_fields` table. 3 new parser pipeline extractors. Parser pipeline v5. The four-face contract applies to auto-extracted fields. User-assigned tags are not substrate-grounded. The vault is unblocked with a minimum-viable privacy stance (per ADR-15's deferred state). Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** Operator reviewed and signed off. The Claim Document Vault substrate extension adds 5 per-document fields (`document_type`, `document_date`, `document_issuer`, `document_amount`, `claim_status`) to the existing `extracted_fields` table. The parser pipeline gains 3 new LLM extractors and bumps to v5. The four-face contract applies to the auto-extracted fields; the user-assigned tags are not substrate-grounded. The Claim Document Vault surface (per ADR-2026-07-19-08 #3) is unblocked once this ADR is implemented. The vault ships with the minimum-viable privacy stance (per ADR-15's deferred state: no-share + principal encryption at rest + user's right to delete). The pattern follows ADR-14. Implementation may begin in dependency order: migration → 3 LLM extractors → parser pipeline v5 → tests → launch-claim registry entry → canonical doc update.


---

## Context

The Claim Document Vault (per ADR-2026-07-19-08 #3) is the user's filing cabinet for claim paperwork. The operator's per-feature thinking was: "we can help them track their old claims docs they submitted, the discharge, approvals etc."

The vault needs per-document metadata to support:
- **Search** ("show me all discharge summaries from 2024")
- **Filter** ("show me only approved claims")
- **Sort** ("show me the most recent documents first")
- **Group by claim** ("show me all documents for this claim")
- **Status tracking** ("this claim was approved on 2024-03-15, settled on 2024-04-01")

The current substrate does not record this metadata. The vault is unblocked once the metadata is recorded.

This ADR extends the substrate with 5 per-document fields. The extension is the prerequisite for the Claim Document Vault. The pattern follows ADR-14, ADR-17, and ADR-18.

---

## The 5 per-document fields

| Column | Type | Extractor | Description |
|---|---|---|---|
| `document_type` | TEXT, nullable | LLM with honesty check | The type of document: "discharge_summary", "approval_letter", "settlement_statement", "denial_letter", "follow_up_email", "receipt", "prescription", "diagnostic_report", "other". NULL when the type is ambiguous. |
| `document_date` | DATE, nullable | LLM with honesty check | The date on the document. NULL when no date is visible. |
| `document_issuer` | TEXT, nullable | LLM with honesty check | The issuer of the document (hospital name, insurer name, etc.). NULL when the issuer is ambiguous. |
| `document_amount` | NUMERIC(12, 2), nullable | LLM with honesty check | The amount on the document (claim amount, settlement amount, receipt amount). NULL when no amount is visible. |
| `claim_status` | TEXT, nullable | LLM with honesty check | The claim status from the document: "filed", "in_review", "approved", "denied", "settled", "withdrawn". NULL when no status is visible. |

**Why these 5:** The user's most-asked vault questions are: "what is this document?" (type), "when is it from?" (date), "who issued it?" (issuer), "how much?" (amount), "what's the status?" (claim_status). These 5 directly answer the questions. A future ADR can add more (e.g. `document_expiry_date`, `document_renewal_required`).

**Why LLM for all 5:** Document metadata is varied (different hospitals use different formats, different insurers use different letterheads, different receipts have different layouts). A deterministic regex is too brittle; an LLM with honesty check is the right tool.

**The user-assigned tags:** The user can also assign their own tags to documents ("this is the discharge for my father's knee surgery"). The tags are not substrate-grounded; they are user metadata. The tags are stored on the document record, not in `extracted_fields`. The four-face contract does not apply to the tags.

**The minimum-viable privacy stance (per ADR-15's deferred state):** The vault ships with the no-share rule, the principal encryption at rest, the user's right to delete. The formal `medical_records` consent purpose, the formal 7-year retention enforcement, the formal support-operator access rules, and the formal export-as-PDF are deferred. When the operator revisits ADR-15, the formal privacy work is added.

**The four-face contract applies to the auto-extracted fields:** The auto-extracted fields (type, date, issuer, amount, claim_status) have an `evidence_strength`, a `parser_version`, and citations. The substrate face, citation face, answer face, and UI face (per ADR-2026-07-19-09) all check the auto-extracted fields. The user can open the document and verify the auto-extracted metadata.

**The launch-claim registry entry:** "Claim Document Vault auto-extracted fields are substrate-grounded, evidence-backed, and verified by the four-face contract. User-assigned tags are not substrate-grounded."

**The parser pipeline v5:** The current parser_version is `evidence-pipeline-v4` (per ADR-18). The new extractors are `evidence-pipeline-v5`. The pipeline runs v1, v2, v3, v4, and v5 in sequence. The v5 extractors are LLM-based (per-document metadata).

**Backward compatibility:** The new columns are nullable. The vault shows a "not yet extracted" honest-empty state for existing documents until the document is processed with v5.

**Effort:** M. 2-3 weeks (5 columns + 3 LLM extractors + parser pipeline v5 + tests + launch-claim registry entry + canonical doc update).

**Anything else flagged:** The "substrate extension" pattern is now well-established. The 4 substrate extensions (Family, Coverage Adequacy, Coverage Check-in, Claim Document Vault) together form the substrate's per-scenario, per-life-event, per-document coverage.

**The privacy policy for the Claim Document Vault (per ADR-15, deferred):** The full privacy policy (consent + retention + encryption + access rules + export/delete + no-share) is deferred per ADR-15. The minimum-viable privacy stance (no-share + principal encryption at rest + user's right to delete) is the launch state.

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-07-29 | **Reaffirmed per [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md).** Substrate extension remains valid technically. Semantics constrained: private organisation of user-provided documents with complete lifecycle controls; not claims consultancy or default medical-record expansion (Gate C). Original reasoning preserved. | Operator direction: layered doctrine stack. |


---

## Doctrine reconciliation note (2026-07-29)

> Append-only note added 2026-07-29. This section does not modify any prior
> content in this ADR; the original decision, reasoning, and existing update
> logs above remain intact and authoritative for their date.

- **Date:** 2026-07-29
- **Governing ADR:** [ADR-2026-07-29-02 (doctrine stack reconciliation)](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md)
- **What changed:** [ADR-2026-07-29-02](./ADR-2026-07-29-02-doctrine-stack-reconciliation.md) establishes a layered doctrine stack. The [Product Constitution](../planning/product/PRODUCT_FIRST_PRINCIPLES.md) (`docs/planning/product/PRODUCT_FIRST_PRINCIPLES.md`) now sits above feature ADRs, with a five-gate stack (Gates A-E: Outcome, Truth, Product role, Lifecycle, Strategy/commercial). Reaffirmed: substrate extension remains valid technically. Semantics constrained: private organisation of user-provided documents with complete lifecycle controls; not claims consultancy or default medical-record expansion (Gate C).
- **Why:** Operator direction to unify two competing uncommitted first-principles documents into one layered stack before any boundary-shaped code changes.
- **What triggered it:** Discovery that the repository held conflicting uncommitted doctrine (Principles vs Wedge) and that ADR-2026-07-29-01 self-declared "Accepted" without sign-off evidence.
- **What original reasoning remains valid:** All prior reasoning in this ADR is preserved unchanged. This note only constrains surface semantics where they intersect the constitution's gates.
- **Status change for this ADR:** None (this ADR's own status is unchanged by this note).
- **Operator sign-off:** None required for this note; it records the reconciliation linkage. The reconciliation ADR itself remains Proposed pending operator sign-off.
- **Code authorization:** None. No code, route, entitlement, pricing, comparison, claims, renewal, camera, demo, or onboarding change is authorized by this note.
