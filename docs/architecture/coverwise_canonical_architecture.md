# CoverWise Canonical Architecture

**Status:** Living document. Updated when the system changes.
**Last updated:** 2026-07-19 (added §5.1 substrate is a primary deliverable, per ADR-2026-07-19-11 Layers 1-3)
**Maintainer:** Pranay (operator) + every agent/engineer who changes the system
**Decision record:** [ADR-2026-07-19-05](../decisions/ADR-2026-07-19-05-canonical-architecture-doc-location.md)

This is the canonical architecture for CoverWise. It is the **map of the system**, not the territory. The territory is the code; the map is this document. If they disagree, the code is right; this doc is updated in the next commit.

For the end-to-end person and operator journeys that this architecture supports, use the canonical [CoverWise User Journey Map](../user_experience/coverwise_user_journey_map.md), governed by [ADR-2026-07-21-01](../decisions/ADR-2026-07-21-01-canonical-user-journey-map.md).

The doc answers 5 questions a new engineer needs to understand the system in 30 minutes:

1. What are the 5 main components?
2. What are the 5 async paths?
3. What happens when a user uploads a PDF? (the data flow)
4. What is the trust + security boundary?
5. What is the substrate and how is it populated?

---

## 1. What are the 5 main components?

CoverWise is built from 5 main components. Each is a small surface with a clear contract.

### 1.1 The mobile app (`mobile/`)

- **Stack:** Flutter / Dart / Riverpod / Dio.
- **Auth:** Supabase Auth (anonymous + email/password + OAuth).
- **Storage:** Hive boxes (local; device-scoped) for offline + policy summaries.
- **Key screens:** dashboard, policy detail, documents list, processing status, settings, profile, qa.
- **Substrate consumers:** the policy detail screen reads cited fields via the `EvidenceService` (GET `/evidence/{document_id}/field-citations`).
- **Honest UI pattern:** the "Not yet verified" scaffold (Phase 0 P0-0.4) when the substrate has no verified data; the `NotYetExtractedSection` widget when a surface does not have its full data.

### 1.2 The FastAPI backend (`src/`)

- **Runtime:** Cloud Run (single service, scale-to-zero, `min-instances=0`).
- **Routes:** `src/api/` (user, document, family, policy, analytics, **evidence**).
- **Document processing:** `src/services/document_processing_service.py` (the state machine via `derive_document_state()`).
- **Evidence pipeline:** `src/services/evidence_pipeline.py` (6 deterministic + 1 LLM extractor).
- **Substrate access:** `src/services/evidence_substrate_service.py` (typed Pydantic + supabase-py).
- **Outbox:** `src/services/job_outbox_service.py` + `src/services/job_dispatcher.py` + `src/workers/outbox_worker.py` (the durable work queue; see ADR-2026-07-19-01).
- **LLM client:** `src/llm/client.py` (gpt-4o-mini default; gpt-5+/o1+/o3+ compatibility).
- **RAG pipeline:** `src/rag/pipeline.py` (CONTEXTUAL_RETRIEVAL_ENABLED=false by default; see ADR-2026-07-19-03).
- **Operator gate:** `src/api/analytics.py` (X-Operator-Token shared secret; see ADR-2026-07-19-04 ADR-2026-07-18-04 for the Phase 0 minimum).

### 1.3 Supabase (`supabase/` + `infra/supabase/`)

- **Postgres** for relational data (`documents`, `document_chunks` with `pgvector` 1536d, plus the RevOps tables and the evidence substrate tables).
- **Storage** (`coverwise-documents` bucket, private) for raw PDFs + rendered page images.
- **Auth** for user identity.
- **Migrations:**
  - `supabase/migrations/20260717000000_coverwise_schema.sql` — base schema (documents, document_chunks, match_document_chunks).
  - `supabase/migrations/20260717010000_document_processing_leases.sql` — processing lease functions.
  - `supabase/migrations/20260717020000_rate_limit_windows.sql` — rate limit RPCs.
  - `supabase/migrations/20260718000000_analytics_supabase.sql` — `analytics_events` + dashboard views.
  - `supabase/migrations/20260718010000_evidence_substrate.sql` — Trust Phase 1 evidence substrate.
  - `supabase/migrations/20260718020000_revops_tables.sql` — RevOps tables + `profiles.role`.
  - `supabase/migrations/20260719000000_consent_ledger.sql` — append-only consent ledger.
  - `supabase/migrations/20260719010000_job_outbox.sql` — the durable work queue.
  - `supabase/migrations/20260720000000_chunk_links.sql`, `20260720010000_chunk_type.sql`, `20260720020000_rag_fts.sql`, and `20260720030000_rag_traces.sql` — retrieval and trace extensions.
  - `supabase/migrations/20260721061309_secure_analytics_views.sql` — analytics view hardening.
  - `supabase/migrations/20260721070000_retrieval_contract.sql` — immutable source/retrieval text and embedding identity.
  - `supabase/migrations/20260721071000_job_outbox_atomic_claims.sql` — atomic claim/reclaim functions.
  - `supabase/migrations/20260721072000_storage_owner_policies.sql` — private bucket ownership policies.
  - `supabase/migrations/20260721073000_evaluation_dataset_registry.sql` — consent-aware evaluation/training registry.
  - `supabase/migrations/20260721074000_identity_aliases.sql` — durable anonymous-to-account identity links.
  - `supabase/migrations/20260721075000_account_lifecycle.sql` — outbox-backed account deletion requests.
  - `supabase/migrations/20260721076100_retrieval_audit.sql` — privacy-safe retrieval candidates, answer lineage, and citation evidence.
  - `supabase/migrations/20260721077000_document_artifacts.sql` — source/derived object inventory and deletion state.
  - `supabase/migrations/20260721078000_model_lineage.sql` — approved-release model runs and artifact checksums.
  - `supabase/migrations/20260721079000_processing_events.sql` — append-only processing stage history.
  - `supabase/migrations/20260721080000_policy_domain_model.sql` — normalized policy identity, versions, and document sections.
  - `supabase/migrations/20260721081000_artifact_lifecycle_audit.sql` — audited retention and orphan transitions.
  - `supabase/migrations/20260721082000_analytics_retention.sql` — service-role-only analytics retention purge.
  - `supabase/migrations/20260721083000_policy_summaries.sql` — durable structured policy-summary projection.
  - `supabase/migrations/20260721084000_fts_source_text_contract.sql` — FTS retrieval with immutable source-text citations.
  - `supabase/migrations/20260721084800_billing_ledger.sql` — server-side entitlement state and ordered webhook RPC.
  - `supabase/migrations/20260721084857_add_foreign_key_indexes.sql` — indexes for remaining FK join/cascade paths.
  - `supabase/migrations/20260721090703_analytics_event_idempotency.sql` — stable replay identity for canonical analytics ingestion.

  `infra/supabase/001_*.sql` through `003_*.sql` are retained as SQL-editor-compatible historical snapshots. They are not a second migration runner or an independently editable schema source.

### 1.4 The evidence substrate (`supabase/migrations/2026_07_18_evidence_substrate.sql` + `src/services/evidence_substrate_service.py` + `src/services/evidence_pipeline.py`)

The substrate is the **truth layer for everything claim-shaped in CoverWise.** It is 4 append-only tables (`page_artifacts`, `source_spans`, `extracted_fields`, `field_evidence`), 1 read view (`v_field_citations`), and 1 cost-tracking table (`evidence_extraction_costs`). The substrate is the source of truth for every UI surface that says "your policy says X."

**Why it exists:** the trust audit's NO-GO is that LLM-extracted policy summaries are not grounded in the source text. The substrate is the fix: every cited field is grounded in a specific page and span, with a citation string the user can verify.

**The 7 fields the pipeline currently extracts:**
- `policy_number` (deterministic_regex)
- `policy_holder_name` (deterministic_regex)
- `sum_insured` (deterministic_regex; rendered in Indian-grouped rupees)
- `policy_start_date` (deterministic_regex; ISO + DD/MM/YYYY)
- `premium_amount` (deterministic_regex)
- `insurer_name` (deterministic_lookup; 35 Indian insurers)
- `room_rent_cap` (llm_extract; with the honesty check that rejects fabricated citations)

### 1.5 The durable outbox (`supabase/migrations/2026_07_19_job_outbox.sql` + `src/services/job_outbox_service.py` + `src/services/job_dispatcher.py` + `src/workers/outbox_worker.py`)

The outbox is the **truth layer for every async path in CoverWise.** It is a single `job_outbox` table with `enqueue`, `claim`, `complete`, `fail`, and `reclaim_stuck_leases` operations, plus 2 operator views (`v_outbox_health`, `v_outbox_dead_letter`).

**Why it exists:** the architecture audit's ADR-03 said CoverWise needs a durable work queue. The outbox is the choice (see ADR-2026-07-19-01) — Supabase outbox over Cloud Tasks, because durable work must live where the durable state already lives.

**The 8 job types:** `document_processing`, `substrate_extraction`, `qa_response`, `webhook_reconciliation`, `subscription_writeback`, `claim_verification`, `renewal_diff`, `account_deletion`. Document upload now enqueues `document_processing` in production; substrate extraction remains inline, and the remaining job types still require deliberate handler adoption.

---

## 2. What are the 5 async paths?

Every durable async work in CoverWise falls into one of 5 paths. The outbox is the contract for all of them (per ADR-2026-07-19-01); document processing, substrate extraction, and account deletion are adopted in production, while the remaining paths still have explicit migration work.

| # | Path | Current implementation | Outbox job_type |
|---|---|---|---|
| 1 | Document processing | `document_processing_service.py` runs in-process; state in `documents.processing_attempts` and `processing_lease_expires_at` | `document_processing` |
| 2 | Evidence substrate extraction | `evidence_pipeline.py` runs in-process after document processing; cost rows to `evidence_extraction_costs` | `substrate_extraction` |
| 3 | Q&A response generation | `query_service.py` runs in-process; RAG pipeline + LLM call synchronously | `qa_response` |
| 4 | Webhook reconciliation | `src/api/webhooks.py`; idempotency via `processed_webhook_events` (in RevOps migration) | `webhook_reconciliation` |
| 5 | Subscription writeback | When webhook handler updates `subscriptions` and write fails, row to `failed_subscription_writes` (in RevOps migration) | `subscription_writeback` |

The 2 future paths (ADR-2026-07-19-01 enumeration):

| 6 | Claim verification | Future: a guided workflow that helps the user file a claim | `claim_verification` |
| 7 | Renewal diff | Future: a diff between the old and new policy at renewal time | `renewal_diff` |

---

## 3. What happens when a user uploads a PDF? (the data flow)

End-to-end, the 6-step flow:

1. **User picks a PDF in the Flutter app.** The app validates the file (`src/utils/upload_validation.py`: PDF, not encrypted, ≤ 50 MB, etc.). The Phase 0 P0-0.5 fix: if the PDF is encrypted, the user provides a password, the validator unlocks in-memory, the password is never logged or persisted.

2. **App uploads to the FastAPI service.** The endpoint `POST /documents/upload` (in `src/api/document.py`) accepts the file, creates a `documents` row with `status='received'`, stores the file in the `coverwise-documents` Supabase Storage bucket.

3. **Document processing runs.** The state machine `derive_document_state()` (`src/services/document_processing_service.py`) drives the document through stages: `received → uploading → uploaded → parsing → parsed → embedding → embedded → ready` (or `failed`/`completed_with_errors` per capability). A processing lease prevents two workers from running on the same document.

4. **Evidence pipeline runs.** When parsing is done, `EvidencePipeline` (`src/services/evidence_pipeline.py`) takes the parsed text, runs the 6 deterministic + 1 LLM extractor, and writes to the substrate via `EvidenceSubstrateService` (`src/services/evidence_substrate_service.py`). Each extracted field gets a citation via `field_evidence`. LLM extractors are checked for honesty (the cited clause must exist on the cited page; otherwise `evidence_strength=0.0` and the UI does not show the field).

5. **Policy detail screen renders.** When the user opens the policy detail screen, the screen calls `EvidenceService.getFieldCitations(documentId)` (the Flutter service in `mobile/lib/services/evidence_service.dart`), which calls `GET /evidence/{document_id}/field-citations` (the FastAPI route in `src/api/evidence.py`). The route reads from `v_field_citations` (the SQL view) and returns typed `FieldCitation` JSON. The Flutter `FieldCitationsCard` widget renders each citation with the human label, the display value, and a tap target to the source page.

6. **User asks a question.** The Q&A flow runs through the RAG pipeline (`src/rag/pipeline.py`), which embeds the query (default model: `text-embedding-3-small` per ADR-2026-07-19-03), retrieves the top-3 chunks from `document_chunks`, and sends them to the LLM (default: `gpt-4o-mini`). The answer is grounded in the retrieved chunks.

The coverage-gap + claim-assistance thin-slice screens (per ADR-2026-07-19-04) hook into step 5: the policy detail screen has two buttons that open `CoverageGapScreen` and `ClaimAssistanceScreen`, both of which read from the same substrate data.

---

## 4. What is the trust + security boundary?

The system has 3 trust tiers, ordered from highest to lowest:

### Tier 1: service_role (the backend, via SUPABASE_SERVICE_ROLE_KEY)

- **Can read and write all RLS-protected tables.**
- **The substrate, RevOps tables, outbox, and the `documents` table are service-role-only** in the RLS policies (the API enforces owner-scoping at the route boundary, not in RLS).
- **This tier is held by the FastAPI service only.** The key is in GCP Secret Manager; the service reads it from the runtime env.

### Tier 2: anon + authenticated (the mobile app, via SUPABASE_PUBLISHABLE_KEY / anon key)

- **Can read what RLS allows.** For the `documents` table, the `documents` RLS policy is owner-scoped via `auth.uid()`.
- **The substrate, RevOps tables, and outbox are NOT accessible from this tier.** The RLS policies explicitly `revoke all ... from anon, authenticated`.
- **This tier is held by the Flutter app** via the `SUPABASE_PUBLISHABLE_KEY` (a `sb_publishable_...` key, not a secret).

### Tier 3: operator (X-Operator-Token)

- **A shared-secret header (`X-Operator-Token`) checked against `OPERATOR_DASHBOARD_TOKEN`** (Phase 0 P0-08 minimum per ADR-2026-07-18-04).
- **Used for the operator dashboard's read endpoints** (`/api/analytics/summary`, `/health`, `/errors`).
- **Fail-closed if the env var is missing.** The deployment must set `OPERATOR_DASHBOARD_TOKEN` or the operator dashboard endpoints return 401/403.
- **Long-term, this becomes RBAC via `profiles.role='operator'`** (Security Phase 1, deferred per ADR-2026-07-19-04's #23).

### Tier 4: principal-scoped encryption (local device)

- **The Hive boxes on the device are encrypted with a key derived from the user's Supabase Auth JWT** via PBKDF2-HMAC-SHA256 (100,000 iterations, 32-byte output, per-user salt). The key is held in memory only and never written to disk. See [`mobile/lib/services/principal_key_service.dart`](../../mobile/lib/services/principal_key_service.dart) and ADR-2026-07-19-06.
- **The threat model: lost phone, stolen phone, forensics on a wiped device, a malicious app on the same device.** The principal key addresses each: a wiped device has no key, a live device with a login has the key from the JWT, a malicious app without the JWT cannot derive the key.
- **The migration from per-device key to principal key is per-box** (each Hive box is migrated on the user's first login after the change). The migration is idempotent. The follow-up session migrates each existing box.
- **The salt is per-user, stored in `flutter_secure_storage`.** If the user uninstalls and reinstalls, a new salt is generated and the local data is lost (the new salt makes the old data undecryptable). This is the cost of "no server-stored key."

### Tier 5: server-side append-only consent ledger

- **The user's consent record is server-side, in `public.consent_ledger`**, a Postgres table with a trigger that raises an exception on UPDATE and DELETE for ALL roles, including service_role. The Flutter app's local Hive box is a cache, not the source of truth. See [`supabase/migrations/2026_07_19_consent_ledger.sql`](../../../supabase/migrations/2026_07_19_consent_ledger.sql) and ADR-2026-07-19-07.
- **The compliance posture: DPDP Act 2023, GDPR if applicable.** A local Hive box is not auditable. The server-side append-only ledger is. The pattern is the same as Stripe's `events` table and GitHub's audit log.
- **A revocation is a new row with `granted=false`**; the "current" state for a (user_id, consent_type) is the most recent row, read via the `v_current_consent` view.
- **The Flutter app calls `POST /consent`** to record events; the user_id is extracted from the Supabase Auth token (not from the body) to prevent spoofing. The local cache is updated after the server confirms.

### Cross-tier boundaries

- **The mobile app cannot reach the service_role tier.** The publishable key is in the app; the service_role key is not. The app's only path to write to the substrate is through the FastAPI service (which is service-role).
- **The operator token is not the same as the service_role key.** The operator token is a separate env var; rotating it does not rotate the service_role key.
- **No data flow from Tier 1 to Tier 2 without explicit user/owner scope.** The API enforces owner-scoping in the WHERE clause of every query (e.g. `repo.get(document_id, current_user.id)` in `src/api/document.py`).

---

## 5. What is the substrate and how is it populated?

The substrate is the **append-only data layer that the UI reads from to make claims about a policy.** Every cited field in the UI is grounded in a row in the substrate.

### The 4 substrate tables

| Table | What it holds | Lifecycle |
|---|---|---|
| `page_artifacts` | One row per (document, page). `image_uri`, `ocr_text`, `layout_json`, `sha256`. | Append-only; deleted only via document cascade. |
| `source_spans` | One row per logical region within a page. `span_text`, `bbox_json`, `span_type` (paragraph / table_cell / header / footer / list_item / other), `confidence`, `parser_version`. | Append-only; deleted only via page cascade. |
| `extracted_fields` | One row per (document, field, parser_version). `value` (the three-layer wrapper: raw, normalized, display), `value_type`, `confidence`, `parser_kind` (deterministic_regex / deterministic_lookup / llm_extract). | Append-only; "changing" a field means writing a new row with a new parser_version. |
| `field_evidence` | One row per (field, page, span) link. `cite_string` (the human-readable citation the UI shows), `evidence_strength`. | Append-only; deleted only via field or page cascade. |

Plus 1 view: `v_field_citations` returns, per (document, field), the strongest evidence row. This is the single read path the UI uses.

Plus 1 cost-tracking table: `evidence_extraction_costs` records every extracted field's parser_kind, model, token count, and USD cost. The operator dashboard reads it.

### How it is populated

1. The document processing service finishes parsing. The parsed text is available.
2. The evidence pipeline runs the 6 deterministic + 1 LLM extractor on the parsed text. Each extractor returns an `ExtractorResult` (field_name, value, value_type, confidence, page_artifact_id, source_span_id_or_None, evidence_strength, cite_string).
3. For each extractor result, the pipeline:
   - Resolves the page_artifact_id from the cite_string.
   - Writes a row to `extracted_fields` with a fresh parser_version (timestamp-based, e.g. `evidence-pipeline-v1-2026-07-19T10:00:00Z`).
   - If `evidence_strength > 0.0` AND the cite_string is valid, writes a row to `field_evidence`.
   - Writes a row to `evidence_extraction_costs` (zero cost for deterministic, real cost for LLM).
4. The substrate is now populated. The policy detail screen reads it via `v_field_citations`.

### How the LLM honesty check works

Every LLM-extracted field is verified against the source text before the citation is written. The LLM is asked to return the cited clause text. The pipeline searches every page for the first 80 characters of that clause. If the clause does not appear on any page, the field is recorded with `evidence_strength=0.0` and an empty `cite_string`. The `v_field_citations` view's `WHERE evidence_strength = (SELECT max(...))` filter is paired with the app-side filter (in `FieldCitation.isVisible`) to ensure the UI does not show unverified fields. The substrate still keeps the row for audit.

### How the substrate is used (the consumer)

- The policy detail screen shows cited fields via `FieldCitationsCard`.
- The coverage-gap thin-slice screen shows the `room_rent_cap` and `insurer_name` (per ADR-2026-07-19-04).
- The claim-assistance thin-slice screen shows the `insurer_name` (per ADR-2026-07-19-04).
- Future Trust Phase 1 features (claim verification, renewal diff) will read the same substrate.
- Future Q&A enhancement will cite the same substrate chunks (cite the field_evidence, not just the document_chunks).

### 5.1 The substrate is a primary deliverable (per ADR-2026-07-19-11)

Per ADR-2026-07-19-11 (substrate as primary deliverable), the user sees the source text directly. The "open page" action shows the actual OCR'd page. Citations may quote only `source_text` (immutable, OCR'd page text), never `retrieval_text` (LLM-augmented contextualized chunk, used only for embedding).

**The five layers:**

1. **Schema (substrate):** `extracted_fields.value.raw` is the `source_text`. The substrate does not need a separate `retrieval_text` column because the substrate IS the source. The LLM augmentation happens at the chunk layer, not the substrate.
2. **Chunk model (`src/rag/pipeline.py`):** every chunk has `source_text` (immutable, set at extraction time) and `retrieval_text` (mutable, initially equal to `source_text`, may be overwritten by `_contextualize_chunks`). Embedding uses `retrieval_text`; citation uses `source_text`. The split is the central trust contract.
3. **Citation model (`src/models/rag.py`):** `RAGCitation` has a `quote_source: Literal["source_text", "retrieval_text"]` field. The default is `source_text`. The `document_id` and `page_number` fields are required so the "open page" action can find the source.
4. **Citation verifier (`src/services/citation_verifier.py`):** the runtime check (per ADR-2026-07-19-09 face 2). Rejects citations where `quote_source != "source_text"`, where the quote is not a substring of `source_text` (after whitespace normalization), where the `source_index` is out of bounds, where the `document_id` doesn't match the answer, or where the `page_number` is out of bounds.
5. **UI (`mobile/lib/widgets/field_citations_card.dart` + future "open page" action):** the citation card shows the verification badge (per ADR-2026-07-19-09 face 4) and the "open page" action that navigates to the OCR'd page (per ADR-2026-07-19-11 Layer 5).

**Why this matters:** the trust audit's P0-03 said `_contextualize_chunks` contaminates source text with model output; the citation cannot be verified against generated text. The substrate-as-primary-deliverable fix is the engineering answer: the contamination is contained to `retrieval_text` (used only for embedding), and `source_text` is preserved untouched for citation.

---

## Appendix A: Directory map (what's where)

```
medpiper/insurance_app/
├── mobile/                          # Flutter app
│   ├── lib/
│   │   ├── models/                  # field_citation.dart, evidence.dart
│   │   ├── providers/               # Riverpod providers
│   │   ├── services/                # evidence_service.dart, analytics_service.dart, ...
│   │   ├── screens/                 # policy_detail_screen.dart, coverage_gap_screen.dart, claim_assistance_screen.dart, ...
│   │   └── widgets/                 # field_citations_card.dart, not_yet_extracted_section.dart, ...
│   └── test/                        # widget tests
├── src/                             # FastAPI backend
│   ├── api/                         # user.py, document.py, analytics.py, evidence.py
│   ├── services/                    # document_processing_service.py, evidence_pipeline.py, evidence_substrate_service.py, job_outbox_service.py, job_dispatcher.py
│   ├── workers/                     # outbox_worker.py
│   ├── llm/                         # client.py
│   ├── rag/                         # pipeline.py
│   ├── models/                      # job_outbox.py, evidence.py, ...
│   ├── utils/                       # upload_validation.py, supabase_auth.py, ...
│   └── app/main.py                  # FastAPI app; includes the evidence router
├── supabase/migrations/             # 2026_07_18_*.sql, 2026_07_19_*.sql
├── infra/supabase/                  # 001_*, 002_*, 003_*.sql (the base schema)
├── tools/                           # benchmark_embedding_models.py, deploy_cloud_run.sh, ...
├── docs/                            # All documentation
│   ├── README.md                    # meta-table-of-contents
│   ├── planning/                    # dated planning docs (historical inputs)
│   ├── audits/                      # 4 NO-GO audits from 2026-07-18
│   ├── decisions/                   # ADRs (motto v3 §0.12 format)
│   ├── architecture/                # THIS FILE + methodology docs
│   ├── technical/                   # deployment + monitoring
│   ├── context/                     # agent-start context
│   ├── user_experience/             # UX docs
│   ├── reference/                   # glossaries
│   └── review/                      # exploration map + review docs
├── tools/embedding_benchmark/       # benchmark tool's cache + results
├── motto_v3.md                      # the working contract
├── AGENTS.md / CLAUDE.md            # agent instructions
└── docs/technical/deployment/launch_playbook_2026-07-18.md
                                    # the launch plan
```

## Appendix B: The decision records (motto v3 §0.12)

| ID | Decision | File |
|---|---|---|
| ADR-2026-07-19-01 | Durable work queue = Supabase outbox | [link](../decisions/ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md) |
| ADR-2026-07-19-02 | Outbox migration of existing 5 async paths deferred | [link](../decisions/ADR-2026-07-19-02-outbox-migration-deferred.md) |
| ADR-2026-07-19-03 | Embedding model = `text-embedding-3-small` (default) | [link](../decisions/ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md) |
| ADR-2026-07-19-04 | Coverage-gap + claim-assistance = thin slice from existing 7 substrate fields | [link](../decisions/ADR-2026-07-19-04-coverage-gap-claim-assistance-thin-slice.md) |
| ADR-2026-07-19-05 | Canonical architecture doc = `docs/architecture/coverwise_canonical_architecture.md` (this file) | [link](../decisions/ADR-2026-07-19-05-canonical-architecture-doc-location.md) |
| ADR-2026-07-19-06 | Security Phase 1 = principal-scoped encrypted local storage (JWT-derived key) | [link](../decisions/ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) |
| ADR-2026-07-19-07 | Security Phase 2 = server-side append-only consent ledger (Postgres table with trigger-enforced append-only) | [link](../decisions/ADR-2026-07-19-07-security-phase-2-server-side-consent-ledger.md) |

Plus 9 retroactive decision records (for Phase 0, RevOps R1, payment provider, operator auth, scaffold, substrate design, LLM honesty, contextual retrieval, LLM client fix) listed in [`docs/decisions/README.md`](../decisions/README.md).

## Appendix C: The 4 NO-GO audits (2026-07-18)

| Audit | Path |
|---|---|
| Trust + document intelligence | [`docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md`](../../audits/coverwise_document_intelligence_trust_audit_2026-07-18.md) |
| Security + privacy + identity + data lifecycle | [`docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md`](../../audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md) |
| Architecture | [`docs/audits/coverwise_architecture_audit_2026-07-18.docx`](../../audits/coverwise_architecture_audit_2026-07-18.docx) |
| Policy detail screen | [`docs/audits/policy_detail_screen_audit.md`](../audits/policy_detail_screen_audit.md) |

## Appendix D: The launch plan

The launch playbook (the operational source of truth for "how to go from where the repo is to a live app") is at [`docs/technical/deployment/launch_playbook_2026-07-18.md`](../technical/deployment/launch_playbook_2026-07-18.md). Its migration step must apply the complete ordered `supabase/migrations/` chain (32 files currently present), not a fixed historical count; fresh-reset and deployed-history verification remain required.

## Appendix E: What's deferred (the follow-up backlog)

Per the ADRs and the launch playbook, the following are deferred to follow-up sessions:

- **Outbox migration of the remaining async paths** (ADR-2026-07-19-02): document processing, substrate extraction, and account deletion are adopted; the remaining handlers follow staged live verification.
- **Embedding model switch** (ADR-2026-07-19-03): the default is `text-embedding-3-small`; the 30-day benchmark may recommend switching to `voyage-3`.
- **Coverage-gap + claim-assistance full features** (ADR-2026-07-19-04): the thin slice is shipped; the full features require 5-7 new parser extractors.
- **Security Phase 1 migration** (ADR-2026-07-19-06): the KDF + Hive re-encryption API is shipped. The per-box migration (each existing Hive box migrated to the new principal key) is a follow-up session.
- **Security Phase 2 migration** (ADR-2026-07-19-07): the server-side consent ledger + trigger-enforced append-only + FastAPI endpoint + Flutter client are shipped. The Flutter cache invalidation (the local Hive box becomes a cache, with the server as the source of truth) is a follow-up session.
- **Security Phase 3** (durable deletion job with retries + tombstone; `delete_account` returns 202 + per-stage status but the back-end job is Phase 3).

These are tracked in [`docs/planning/coverwise_audit_task_classification_2026-07-18.md`](../planning/coverwise_audit_task_classification_2026-07-18.md) (Bucket 5 + Bucket 6 + Bucket 7) and the launch playbook's "Out of scope" section.

---

**This doc is the map, not the territory. The territory is the code. The map is updated when the territory changes, not the other way around.**
