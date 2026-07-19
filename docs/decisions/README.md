# Decision Records Index

This file lists every architectural, product, integration, data-pipeline, payment, customer-facing, or operational decision made in CoverWise, with a link to the full decision record. Records follow the `motto_v3.md` §0.12 schema (decision, date, context, options, chosen path, why, tradeoffs, assumptions, risks, validation, rollback, revisit triggers, links).

A decision that is not recorded will be rediscovered and debated again.

---

## Active ADRs

| ID | Date | Decision | Status | File |
|---|---|---|---|---|
| ADR-2026-07-19-01 | 2026-07-19 | Durable work queue = Supabase outbox (not Cloud Tasks) | Accepted | [link](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md) |
| ADR-2026-07-19-02 | 2026-07-19 | Outbox migration of existing 5 async paths deferred to a follow-up session | Accepted | [link](./ADR-2026-07-19-02-outbox-migration-deferred.md) |
| ADR-2026-07-19-03 | 2026-07-19 | Embedding model = `text-embedding-3-small` (default), with 30-day benchmark for `voyage-3` | Accepted | [link](./ADR-2026-07-19-03-embedding-model-text-embedding-3-small-default.md) |

---

## Decision records (retroactive, from work shipped in commit `fa02854` and earlier)

These records are written after the fact to satisfy the "every decision is documented" rule (the user instruction on 2026-07-19). The code is on `main`; the rationale is captured here so future readers do not have to re-derive it.

### Decision 2026-07-18-01: Phase 0 of the 4 audits (Trust, Security, Architecture, Policy detail)

- **Decision:** Implement the security audit's Phase 0 AND the trust audit's Phase 0 in the same commit. Defer the architecture audit's Phase 0 (queue, model pin, observability substrate) and the policy detail audit's P1+ polish.
- **Context:** 4 NO-GO audits from 2026-07-18; the operator said "all of them"; the working tree had parallel-agent work in flight.
- **Options considered:**
  - (A) Do security Phase 0 only (the highest-leverage slice per the security audit's own Phase 0 rationale).
  - (B) Do trust Phase 0 only (the first slice the planning doc recommended).
  - (C) Do both Phase 0s in the same commit. CHOSEN.
  - (D) Defer all and do multi-day architecture work first.
- **Chosen path:** Option C. The operator's "all of them" ruled out (A) and (B). Option (D) violates motto v3 §0 (build the best, not the safest small change). The combined commit is implementation-complete and unit-tested; the policy detail audit's P1+ items are in Bucket 4 for follow-up.
- **Tradeoffs:** Larger commit, harder to revert one audit's work without the other. Mitigated by the launch playbook (Step 8 verify) which exercises the customer-visible Phase 0 fixes.
- **Files:** commit `fa02854`. See commit message for the per-audit breakdown.

### Decision 2026-07-18-02: RevOps R1 (observability substrate) shipped in the same commit as Phase 0

- **Decision:** Treat the RevOps R1 work (9 Supabase tables, 16 events, 3 dashboard views, dual-write) as Phase 0 of the RevOps track, not as a follow-up. Ship in the same commit as the audit Phase 0s.
- **Context:** Without R1, the Phase 0 fixes have no observability; the operator cannot see whether the work shipped correctly. The audit fixes are claims; R1 is the evidence. Per motto v3 §0.10 (observability is delivery), claims without evidence are not delivery.
- **Options considered:**
  - (A) R1 first, then Phase 0. CHOSEN semantically (the migration files are in `2026_07_18_revops_tables.sql` and `2026_07_18_analytics_supabase.sql`, ordered before the Phase 0 audit fixes in the launch playbook).
  - (B) Phase 0 first, then R1 as follow-up. The launch playbook is wrong until R1 ships; the customer sees the audit fixes without the operator dashboard to verify them.
- **Chosen path:** R1 is part of the same commit (`fa02854`); the launch playbook order is "apply all 5 migrations, deploy, then verify Phase 0 on a real device."
- **Files:** `supabase/migrations/2026_07_18_revops_tables.sql`, `supabase/migrations/2026_07_18_analytics_supabase.sql`, `tools/migrate/sqlite_analytics_to_supabase.py`.

### Decision 2026-07-18-03: Dodo Payments primary + Razorpay secondary (payment provider choice)

- **Decision:** Make Dodo Payments the primary payment provider for CoverWise subscriptions, with Razorpay as a secondary provider for Indian-specific payment methods (UPI, NetBanking).
- **Context:** Indian insurance customers primarily pay via UPI and NetBanking; international customers (the operator's English-speaking audience) use cards. Dodo Payments supports international cards; Razorpay supports UPI/NetBanking.
- **Options considered:**
  - (A) Razorpay only. Rejected: international cards have higher decline rates in India; the operator's English-speaking audience may not have Indian bank accounts.
  - (B) Dodo only. Rejected: no UPI support, no NetBanking.
  - (C) Dodo primary + Razorpay secondary. CHOSEN.
  - (D) Stripe Connect with India. Rejected: Stripe does not officially support India; the operator would need a US LLC, increasing setup cost and time.
- **Chosen path:** Option C. The payment adapter (`mobile/lib/services/billing_adapter.dart`) routes by currency and payment method: UPI/NetBanking → Razorpay; cards → Dodo.
- **Risks:** Dodo Payments is a newer provider; downtime affects international customers. Mitigation: the adapter is pluggable; swapping providers is a 1-file change.
- **Files:** `mobile/lib/services/billing_adapter.dart`, `docs/planning/coverwise_revops_system_2026-07-18.md` (R3 design).

### Decision 2026-07-18-04: Operate-by-shared-secret for the analytics dashboard (Phase 0 minimum)

- **Decision:** Phase 0 of the security audit's P0-08 fix uses a shared-secret `X-Operator-Token` header checked against `OPERATOR_DASHBOARD_TOKEN` env var. The operator must set the env var; missing env means fail-closed.
- **Context:** The security audit's full recommendation is principal-scoped role-based access via Supabase Auth (`profiles.role='operator'`). Implementing that is Security Phase 1 (Bucket 5 decision #23). The Phase 0 minimum is the shared secret.
- **Options considered:**
  - (A) Full RBAC via Supabase Auth roles. Correct long-term, but requires profiles.role enforcement in the API + Flutter client changes + migration of existing operators. Rejected for Phase 0 because it does not ship this session.
  - (B) Shared secret `X-Operator-Token`. CHOSEN. Fail-closed if env var missing; constant-time comparison; documented in the launch playbook.
  - (C) No gate at all. Rejected: the security audit's NO-GO is specifically about the lack of a gate.
- **Chosen path:** Option B. The full RBAC is a follow-up ADR when Security Phase 1 lands.
- **Files:** `src/api/analytics.py` (`require_operator` dependency), `tests/test_analytics_errors.py` (3 new tests for the gate).
- **Migration path:** when Security Phase 1 lands, `require_operator` reads `profiles.role='operator'` instead of the env var; the route's signature does not change; the operator dashboard's `X-Operator-Token` header is replaced by a Supabase Auth session.

### Decision 2026-07-18-05: "Not yet verified" scaffold as the honest UI for partial evidence

- **Decision:** The policy detail screen shows a "Not yet verified" scaffold (with the specific missing-field reason) when the substrate has no verified data. The scaffold is kept indefinitely; the cited-field card overlays it when the substrate has data.
- **Context:** The trust audit's NO-GO on document state derivation said a partial summary is a lying product. The previous behavior was to show a confident-looking summary even when OCR had failed on 30% of pages.
- **Options considered:**
  - (A) Show the partial summary with a small "may be incomplete" disclaimer. Rejected: the audit's central point is that disclaimers do not fix lying UI; the only fix is to refuse to show.
  - (B) Show the scaffold only when extraction has 100% completed. Rejected: the scaffold is needed when extraction completes with partial data, not just when it is in-progress.
  - (C) Show the scaffold whenever the substrate lacks minimum-viable evidence. CHOSEN. The `hasMinimumViableEvidence` predicate on `PolicySummary` is the gate.
- **Chosen path:** Option C. The scaffold is the honest UI for an empty or incomplete substrate.
- **Files:** `mobile/lib/models/policy_summary.dart` (`hasMinimumViableEvidence` + `missingEvidenceReason`), `mobile/lib/screens/policy_detail_screen.dart` (`_buildUnverifiedSummaryScaffold`), `tests/test_document_state_derivation.py` (the 11 unit tests for `derive_document_state`).
- **Revisit when:** the substrate is populated end-to-end and real-device UX testing shows the scaffold is too prominent or the cite-card is too small.

### Decision 2026-07-18-06: Trust Phase 1 evidence substrate = 4 tables (page_artifacts, source_spans, extracted_fields, field_evidence)

- **Decision:** The evidence substrate is exactly 4 immutable append-only tables (plus a cost-tracking table and a single read view). Not 5, not 3; the decomposition is per the trust audit's Phase 1 design.
- **Context:** The trust audit identified 4 logical tables; the operator chose "build now" for the substrate.
- **Options considered:**
  - (A) Single `evidence` table with JSONB payload. Rejected: no referential integrity, no typed columns, no per-table RLS, no queryable page/span/field distinctions.
  - (B) 4 tables (the audit's design). CHOSEN. Each table has a clear invariant; the cascade rules are the truth.
  - (C) 5 tables with a separate `extraction_jobs` table. Rejected: the cost-tracking table covers it; the outbox ADR (`ADR-2026-07-19-01`) will own the job-queue concern.
- **Chosen path:** Option B. The contract is in `supabase/migrations/2026_07_18_evidence_substrate.sql` (commit `ecab0ba`).
- **Tradeoffs:** 4 tables means 4 RLS policies, 4 cascade paths, 4 partial indexes. The cost is real; the benefit is per-table invariant enforcement.
- **Revisit when:** a fifth invariant emerges (e.g. multi-document cross-reference, span-level search) that the existing 4 tables cannot express.

### Decision 2026-07-18-07: LLM honesty check on every extracted field

- **Decision:** Every field produced by an LLM extractor is verified against the source text before the citation is written. If the LLM cites a clause not on any page, the field is recorded with `evidence_strength=0.0` and an empty `cite_string`. The UI does not show it; the substrate keeps the row for audit.
- **Context:** The trust audit's NO-GO is partly driven by LLM hallucinations: the LLM says "the cap is on page 4" but the page text does not contain the claim. Showing the user a citation that does not exist is the worst possible outcome.
- **Options considered:**
  - (A) Trust the LLM's cited page; do not re-verify. Rejected: this is the failure mode the audit flags.
  - (B) Re-verify every claim. CHOSEN. The cost is one string-search per field; the benefit is a substrate that never lies.
  - (C) Use a separate LLM to re-verify. Rejected: introduces a second LLM with the same failure mode at 2x the cost.
- **Chosen path:** Option B. The `RoomRentCapExtractor.extract()` method does the verification; `test_room_rent_cap_extractor_rejects_hallucinated_clause` is the regression test.
- **Files:** `src/services/evidence_pipeline.py` (the `RoomRentCapExtractor.extract()` method), `tests/test_evidence_pipeline.py` (the honesty-check test).

### Decision 2026-07-18-08: `CONTEXTUAL_RETRIEVAL_ENABLED=false` by default (Trust P0-0.6)

- **Decision:** The contextual retrieval feature in the RAG pipeline is disabled by default via the `CONTEXTUAL_RETRIEVAL_ENABLED` env var. To enable, the operator must set the env var to `true` and accept the contamination risk.
- **Context:** Contextual retrieval (Anthropic's pattern) augments each chunk with an LLM-generated context before embedding. The trust audit flagged this as contaminating source text with model output: the citation cannot be verified against generated text.
- **Options considered:**
  - (A) Enable contextual retrieval. Rejected: violates the citation contract.
  - (B) Disable by default. CHOSEN. Re-enable when a future Trust phase separates source_text from retrieval_text and re-verifies the contract.
  - (C) Remove the feature entirely. Rejected: the feature is useful; the disable is the right balance.
- **Chosen path:** Option B. The env var defaults to `false`; the launch playbook documents the disable.
- **Files:** `src/rag/pipeline.py` (`CONTEXTEXTUAL_RETRIEVAL_ENABLED` env var), `docs/technical/deployment/launch_playbook_2026-07-18.md` (Step 5 env).

### Decision 2026-07-18-09: gpt-5+/o1+/o3+ model compatibility fix in the LLM client

- **Decision:** When the configured model is gpt-5+, o1+, or o3+, the LLM client omits the `temperature` parameter (only default=1 is supported) and uses `max_completion_tokens` instead of `max_tokens`. Other models (gpt-4o, gpt-4.1-nano, Ollama, Groq) retain the previous behavior.
- **Context:** The OpenAI Python SDK does not raise a clear error for unsupported params; the LLM call silently returns empty or unexpected results. The fix is conditional on the model name.
- **Options considered:**
  - (A) Use a different model. Rejected: gpt-5+ is the cost-perf sweet spot for many use cases.
  - (B) Branch on model name. CHOSEN. The fix is local to `src/llm/client.py`; no new abstraction layer.
  - (C) Use a model-agnostic client library. Rejected: existing OpenAI SDK is the path of least resistance.
- **Chosen path:** Option B. The change is 11 lines; the regression test is a manual one (no gpt-5+ test call in CI).
- **Files:** `src/llm/client.py` (the conditional kwargs block).
- **Risks:** when OpenAI ships gpt-6, the model prefix list may need updating. Mitigation: the model name detection is in one place.

---

## How to add a new ADR

1. Use the next sequential ID in the format `ADR-YYYY-MM-DD-NN`.
2. Place the file in `docs/decisions/` with the same filename pattern.
3. Follow the 15-field schema in `motto_v3.md` §0.12: decision, date, context, options considered, chosen path, why this path, tradeoffs, assumptions, risks, validation plan, rollback or migration path, owner / next reviewer, links, related docs/tests/configs, what would cause this decision to be revisited.
4. Add a row to the "Active ADRs" table at the top of this file.
5. Reference the ADR from any commit that lands work flowing from the decision. The commit message's "Refs:" section should include the ADR filename.

A decision that is not recorded will be rediscovered and debated again.
