# ADR-2026-07-19-11: Substrate is a primary deliverable, not a behind-the-scenes detail

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** **The substrate is a primary deliverable.** The user sees the source text directly. The "open page" action shows the actual OCR'd page. The citation points to the page, not to a chunk. The system uses `retrieval_text` (the LLM-augmentable contextualized chunk) internally for retrieval, but **citations may quote only `source_text`**. The two columns are separate at the schema, the chunk model, the citation model, the citation verifier, and the UI. The launch-claim registry (per ADR-2026-07-19-09) records the claim "the user can verify every citation" and links to the tests that gate it.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** **Accepted (revision 1, operator sign-off 2026-07-19).** The substrate is a primary deliverable. The user sees the source text directly. The "open page" action shows the actual OCR'd page. Citations may quote only `source_text`. The five layers (schema, chunk, citation, page artifact, UI) enforce the contract. The wider wedge from ADR-2026-07-19-08 revision 2 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault) does not change the contract — every new surface renders substrate-grounded content that the user can verify by opening the page. The page artifact coverage is wider (more page types, more citation patterns). The Family Coverage Map depends on a substrate extension (per-member sum insured, exclusions, dependents-cant-have-policies signal); the extension is a future ADR and a prerequisite for the Family surface. The five layers are the contract; the page artifact coverage is the implementation. See "Update log" below for the full decision history.
- **Related artifacts:** [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md), [canonical architecture doc](../../architecture/coverwise_canonical_architecture.md), `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` P0-02, P0-03, P0-08, P1-15.

---

## Update log

- **2026-07-19 (original)**: Initial proposal. The substrate is a primary deliverable; `source_text` and `retrieval_text` separated at five layers; "open page" action lets the user verify. Status: Proposed.
- **2026-07-19 (operator sign-off, revision 1)**: **Accepted.** The operator reviewed and signed off. The wider wedge from ADR-2026-07-19-08 revision 2 (Coverage Check-in, Coverage Adequacy, Family Coverage Map, Claim Document Vault) does not change the contract — every new surface renders substrate-grounded content (observations, scenario answers, per-member observations, document descriptions) that the user can verify by opening the page. The five layers (schema split, chunk model split, citation model field, page artifact persistence, "open page" UI) are the contract; the page artifact coverage is the implementation. The page artifact coverage is wider now: more page types (Coverage Check-in observation citations, Coverage Adequacy answer citations, Family Coverage Map per-member observation citations, Claim Document Vault description citations) and more citation patterns (the user can open the page from any of the new surfaces). The Family Coverage Map depends on a substrate extension (per-member sum insured, per-member exclusions, dependents-cant-have-policies signal); the extension is a future ADR and a prerequisite for the Family surface. The "open page" action becomes the verification surface for every surface in the wedge. The contract is unchanged; the surface area is larger.

---

## Context

The current state, from the code archaeology pass and the audits:

- **`_extract_text()` flattens pages into a single string.** The page artifact is destroyed before chunking. The vector store receives no reliable page number. Source cards cannot point to the exact page. Citations cannot be independently checked. (Trust audit P0-02.)
- **`_contextualize_chunks()` overwrites `block["text"]` with LLM-generated context.** The modified text is embedded, stored as chunk content, returned as source text, and available for model citations. An LLM-generated sentence becomes indistinguishable from policy text. The answer model can cite a generated context sentence as if it were in the policy. (Trust audit P0-03.)
- **The user cannot verify a citation.** The citation card shows a quote and a page number. The user has no way to open the page and check that the quote is actually in the page. The system has not verified either (per ADR-2026-07-19-09, the citation face is not implemented).
- **The "evidence-backed" claim is hollow.** The user sees a citation. The system has not verified the citation. The page is not reachable. The substrate is a behind-the-scenes detail that the user trusts without being able to verify.

The audits converge on a single fix: **separate `source_text` from `retrieval_text`, persist page artifacts, make the page reachable, and gate the citation on the source text.** This is the engineering answer to the audit's NO-GO: the system shows the source, the user verifies the source, the substrate is a primary deliverable.

The decision is binary: substrate as primary deliverable (the user sees the source) or substrate as behind-the-scenes detail (the system verifies, the user trusts). This ADR chooses primary deliverable because the audit's acceptance criteria is "mobile can open the exact page for each evidence card" and the operator's product principle is "real evidence, not vibes."

---

## Options considered

### Option A: Substrate as behind-the-scenes detail. REJECTED.

- **How it works:** the system uses the substrate internally. The user sees a "verified" badge (per ADR-2026-07-19-09 face 1-3). The user does not see the source text. The user does not open the page. The system is the verifier.
- **Why rejected:** the audit's NO-GO is "the system says one thing and does another." If the substrate is behind-the-scenes, the user has no way to verify the system. The system must be trustworthy, and the only way to be trustworthy is to be verifiable. The audit's P0-03 acceptance criteria is "no customer-visible quote can originate from generated context." That acceptance criteria is met by Shape B (the system uses retrieval_text internally and never quotes it) but the user cannot verify that the system is doing what it says. The audit's NO-GO is about the user-visible claim, not the system-internal claim. The user-visible claim in Shape B is "verified by us." The user has no recourse if the system is wrong.
- **Mitigation that was considered and rejected:** add a "show me the source" button. The button is the escape hatch from Shape B to Shape A. If the button exists, the substrate is a primary deliverable for users who want to verify. If the button does not exist, the substrate is behind-the-scenes for all users.

### Option B: Substrate as primary deliverable. CHOSEN.

- **How it works:** the user sees the source text directly. The "open page" action shows the actual OCR'd page. The citation points to the page, not to a chunk. The system uses `retrieval_text` internally for retrieval, but citations may quote only `source_text`. The two columns are separate at every layer.
- **Why chosen:** the audit's acceptance criteria is "mobile can open the exact page for each evidence card." That criteria is the definition of primary deliverable. The user can verify. The system can be wrong (the page may not say what the citation says) and the user can catch it. The substrate is the UI.
- **Cost:** 1-2 weeks of work: separate the columns, persist the page artifacts, build the "open page" action, gate the citation on source_text. The audit's P0-02 + P0-03 fixes.
- **Quality:** every citation points to a page the user can open. The substrate is the source of truth. The system is verifiable.

### Option C: Substrate as primary deliverable, with a "trust the system" mode. REJECTED.

- **How it works:** the default is primary deliverable (the user sees the page). The user can opt into a "trust the system" mode that hides the page and shows only the verified badge. The mode is per-user, per-question.
- **Why rejected:** the mode adds complexity without solving a real problem. The user who wants to trust the system can ignore the page; the user who wants to verify opens the page. The mode is a UI affordance, not an architecture decision. The decision is the architecture: substrate as primary deliverable. The mode is a future UI feature.
- **Mitigation that was considered and rejected:** build the mode now to avoid retrofitting later. The mode is a 1-day UI feature; retrofitting is also a 1-day feature. The retrofit risk is small.

---

## The substrate visibility contract

The substrate is a primary deliverable. The contract is enforced at five layers:

### Layer 1: Schema (the substrate table)

- **What it is:** every `extracted_field` row has a `source_text` column (immutable, the OCR'd page text) and a separate `retrieval_text` column (the LLM-augmentable contextualized chunk). The two columns are never the same. The `evidence_link` row points to the source text only.
- **Migration:** `supabase/migrations/2026_07_19_substrate_source_retrieval_split.sql` (new). The migration adds the `retrieval_text` column, backfills it from the existing `text` column, and renames the existing column to `source_text`. The migration is reversible (the old column is preserved as `source_text_legacy` for one release).
- **Effort:** S. 0.5 day.
- **Source:** trust audit P0-03.

### Layer 2: Chunk model (the in-memory chunk)

- **What it is:** every `Chunk` object has `source_text: str` and `retrieval_text: str` as separate attributes. The `RAGPipeline._contextualize_chunks()` method sets `retrieval_text` to the LLM-generated context; it does NOT modify `source_text`. The `Chunk.source_text` is set once at extraction time and never modified.
- **Code change:** `src/services/rag_pipeline.py` (modify `_contextualize_chunks` and `Chunk` class). The change is local: 10-20 lines.
- **Effort:** S. 0.5 day.
- **Source:** trust audit P0-03.

### Layer 3: Citation model (the citation the user sees)

- **What it is:** the `RAGCitation` model has a `quote_source: Literal["source_text", "retrieval_text"]` field. The citation verifier (per ADR-2026-07-19-09 face 2) rejects any citation with `quote_source == "retrieval_text"`. The `RAGPipeline` only produces citations with `quote_source == "source_text"`.
- **Code change:** `src/models/rag.py` (add the field). The change is additive.
- **Effort:** S. 0.5 day.
- **Source:** trust audit P0-03 + ADR-2026-07-19-09 face 2.

### Layer 4: Page artifact (the page the user opens)

- **What it is:** every chunk has a `page_artifact_id` that resolves to a `page_artifacts` row. The row contains the OCR'd page text, the page number, the document version, and the parser method. The "open page" action fetches the `page_artifacts` row and renders it. The user sees the actual page.
- **Schema change:** `page_artifacts` table already exists (per the substrate migration). The `chunks` table needs a `page_artifact_id` foreign key.
- **Migration:** extend `supabase/migrations/2026_07_18_evidence_substrate.sql` (or a new migration). The `chunks` table gets the foreign key. The backfill is a one-time SQL script.
- **Code change:** `src/services/document_processing_service.py` (modify `_extract_text` to persist page artifacts). The change is local: 20-40 lines.
- **Effort:** M. 1-2 days.
- **Source:** trust audit P0-02.

### Layer 5: UI (the "open page" action)

- **What it is:** the citation card (per ADR-2026-07-19-09 face 4) has an "open page" button. The button opens the `page_artifact` in a viewer. The viewer shows the OCR'd page text (or, in a future iteration, the actual image of the page with the quote highlighted). The user can verify the citation by reading the page.
- **Code change:** `mobile/lib/widgets/field_citations_card.dart` (add the button) and `mobile/lib/screens/page_artifact_viewer.dart` (new, the page viewer). The change is local: 50-100 lines.
- **Tests:** widget tests for the button + the viewer.
- **Effort:** M. 1-2 days.
- **Source:** trust audit P0-02 acceptance criteria.

---

## The contract in detail

Every citation has the following properties:

- `quote_source: "source_text"` — the citation quotes the immutable source text, not the LLM-generated context. (Layer 3 + ADR-2026-07-19-09 face 2.)
- `page_artifact_id: UUID` — the citation points to a specific page in a specific document version. (Layer 4.)
- `quote: str` — the quote is a substring of the `source_text` of the `page_artifact`. (ADR-2026-07-19-09 face 2 condition 3.)
- `document_id: UUID` — the citation belongs to the same document as the answer. (ADR-2026-07-19-09 face 2 condition 2.)
- `verification_state: "verified" | "unverified" | "rejected"` — the citation face verifier sets this state. (ADR-2026-07-19-09 face 2.)

The "open page" action:

- The user taps the button on the citation card.
- The viewer opens with the `page_artifact` text.
- The viewer highlights the `quote` in the page text (or, in a future iteration, shows the page image with the quote highlighted).
- The user can read the page and verify the quote is in the page.

The "verified" state:

- A citation is `verified` if and only if the citation face (ADR-2026-07-19-09 face 2) returns True.
- The UI shows a green badge for `verified`, a yellow badge for `unverified`, and a red badge for `rejected`.
- The user sees the badge; the user can open the page; the user can verify.

---

## Chosen path

**The substrate is a primary deliverable.** The five layers enforce the contract. The launch-claim registry records the claim "the user can verify every citation" and links to the tests that gate it.

The work to implement:

1. **Schema split** (Layer 1) — 0.5 day. The migration.
2. **Chunk model split** (Layer 2) — 0.5 day. The `RAGPipeline` change.
3. **Citation model field** (Layer 3) — 0.5 day. The `RAGCitation` change.
4. **Page artifact persistence** (Layer 4) — 1-2 days. The `document_processing_service` change + the backfill migration.
5. **"Open page" UI** (Layer 5) — 1-2 days. The button + the viewer + the widget tests.
6. **Launch-claim registry entry** — 0.5 day. The entry records the claim and links to the five layers.
7. **Canonical doc update** — 0.5 day. The doc defines substrate as primary deliverable.

**Effort:** 1-2 weeks. The audit's P0-02 + P0-03 fixes, plus the UI work.

**Sequence:**
1. Schema split (the foundation for the rest).
2. Chunk model split (the in-memory contract).
3. Page artifact persistence (the page is reachable).
4. Citation model field (the citation points to the source).
5. "Open page" UI (the user can verify).
6. Launch-claim registry entry (the claim is recorded).
7. Canonical doc update (the doc is current).

The release happens after the launch-claim registry entry is in place and the launch playbook's Step 8 (real-device end-to-end) validates the "open page" action.

---

## Why this path

### 1st-principle argument

The substrate is the user's policy. The user has the right to read their policy. The product's job is to make the policy readable, not to make the system trustworthy. If the user can open the page and read the policy, the system does not need to be trustworthy — the system is just a reader. If the user cannot open the page, the system must be trustworthy, and the only way to be trustworthy is to be verifiable. Shape A is the answer that makes the system a reader, not a verifier.

### Anti-lying-UI argument (motto v3 §0.7, trust audit NO-GO)

The trust audit's NO-GO is "the system says one thing and does another." The "one thing" in Shape A is "the user can verify." The "does another" in Shape B is "the user cannot verify." Shape A is the answer that does what it says.

### Anti-context-contamination argument (trust audit P0-03)

The contextual retrieval feature is a real feature: it improves retrieval quality. But it contaminates the source text. The fix is to keep the feature (use `retrieval_text` for retrieval) and protect the source text (cite only `source_text`). The two are separate columns. The user sees the source; the system uses the retrieval.

### Anti-page-loss argument (trust audit P0-02)

The page artifact is the user's verification surface. Losing the page artifact loses the verification. The fix is to persist the page artifact at extraction time, link every chunk to a page, and make the page reachable from the citation card.

### Operator-decision-required argument

This ADR is **proposed, not accepted**. The substrate-as-primary-deliverable answer is a recommendation grounded in the audits. The operator may want the behind-the-scenes answer; the operator may want a different split between source and retrieval; the operator may want to defer the migration. The reason this is an ADR and not a code change is that the substrate visibility is load-bearing and the operator should sign off on it.

---

## Tradeoffs

- **The "open page" viewer is a new UI surface.** The user has another button to learn. The mitigation is the existing citation card pattern; the button is an addition, not a replacement.
- **The schema split is a migration with a backfill.** The migration is reversible (the old column is preserved). The backfill is a one-time SQL script. The mitigation is the migration's reversibility.
- **The chunk model split is a breaking change for any code that reads `chunk.text`.** The change is to `RAGPipeline._contextualize_chunks` and the `Chunk` class. The mitigation is the audit's P0-03 acceptance criteria: "contextualization can be disabled independently." The disable flag is preserved.
- **The "open page" viewer may show low-quality OCR.** The OCR is the same OCR the system uses internally. If the OCR is wrong, the page is wrong. The mitigation is the audit's T-7-1 (make document state capability-derived; mark unreadable pages as unreadable). The viewer shows the unreadable badge for pages that failed OCR.
- **The substrate-as-primary-deliverable answer requires the user to read.** The user who wants to trust the system without reading can ignore the page. The audit's T-7-8 (citation verifier) is the trust fallback: the system verifies the citation even if the user does not. The user has a choice.
- **The five layers are 1-2 weeks of work.** The launch slips. The operator's call. The substrate visibility is the cost of having a verifiable contract.

---

## Assumptions

- **The audit's P0-02 + P0-03 fixes are the right contract.** This ADR implements the fixes as the five layers. The operator may want a different contract; the ADR is the place to discuss.
- **The schema split is reversible.** The migration preserves the old column as `source_text_legacy` for one release. The operator may want a different migration strategy; the ADR is the place to discuss.
- **The "open page" viewer shows the OCR'd text, not the page image.** A future iteration can show the image with the quote highlighted. The first version shows the text. The operator may want the image version from the start; the ADR is the place to discuss.
- **The launch-claim registry entry is the customer-facing record of the claim.** The claim is "the user can verify every citation." The entry links to the five layers and the tests. The operator may want a different claim; the ADR is the place to discuss.
- **The canonical doc's definition of "substrate" is the primary-deliverable answer.** The doc update is a 1-day pass. The operator may want a different definition; the ADR is the place to discuss.

---

## Risks

- **The operator disagrees with the primary-deliverable answer.** This is a feature of the decisions-first process, not a bug. The mitigation is to make the binary choice explicit and easy to revisit.
- **The schema migration breaks a query the audit did not flag.** The audits are comprehensive but not exhaustive. The mitigation is the migration's reversibility + a CI test that asserts every `chunk.text` access is replaced with `chunk.source_text` or `chunk.retrieval_text`.
- **The "open page" viewer is too complex for the first version.** The mitigation is to start with the text viewer; the image viewer is a future iteration.
- **The OCR is wrong for some pages.** The mitigation is the audit's T-7-1: pages that failed OCR are marked unreadable; the viewer shows the unreadable badge.
- **The user does not want to read.** The mitigation is the audit's T-7-8 citation verifier: the system verifies the citation even if the user does not. The user has a choice.
- **The five layers are not picked up.** 1-2 weeks of work is a lot. The mitigation is the launch-claim registry: the "evidence-backed" claim cannot be made until the five layers pass.

---

## Validation plan

- **For the schema split:** a migration test that asserts the new columns exist and the backfill is correct.
- **For the chunk model split:** a unit test that asserts `Chunk.source_text` is never modified after extraction.
- **For the citation model field:** a unit test that asserts the citation face (per ADR-2026-07-19-09 face 2) rejects citations with `quote_source == "retrieval_text"`.
- **For the page artifact persistence:** an integration test that asserts every chunk has a `page_artifact_id` and the artifact is reachable.
- **For the "open page" UI:** a widget test that asserts the button is present and the viewer opens with the page text.
- **For the launch-claim registry:** a CI test that asserts the registry entry exists and links to the five layers.
- **For the canonical doc:** a doc-lint test that asserts the substrate is defined as primary deliverable.
- **End-to-end:** the launch playbook's Step 8 (real-device end-to-end) runs after the five layers are implemented. The validation includes: upload policy → extract fields → cite source_text → user opens page → user verifies the quote is in the page.

---

## Rollback or migration path

The five layers are additive. The schema split is reversible. The chunk model split is local. The citation model field is additive. The page artifact persistence is local. The "open page" UI is a new widget.

If a layer turns out to be wrong:
- The schema split can be reverted by removing the new columns (the old column is preserved).
- The chunk model split can be reverted by reverting the `RAGPipeline` change.
- The citation model field can be removed (the citations revert to the old shape).
- The page artifact persistence can be reverted (the chunks lose the `page_artifact_id` link).
- The "open page" UI can be hidden by removing the button.

The launch-claim registry entry is updated when a layer changes. The CI gate fails if the entry is not updated.

---

## What would cause this decision to be revisited

- **The operator wants the behind-the-scenes answer.** Shape B is a recommendation. A future ADR can switch the substrate to behind-the-scenes; the launch-claim registry entry is updated.
- **The audit's P0-02 + P0-03 fixes are updated.** If the audit's recommended contract changes, the five layers change. The launch-claim registry entry is updated.
- **The OCR quality improves.** A future ADR can switch the "open page" viewer from text to image. The five layers are unchanged.
- **The market changes.** A competitor claims "evidence-backed" without the page. The operator may decide to drop the page. The launch-claim registry entry is updated.
- **The substrate grows to include new field types.** The five layers are extensible. The launch-claim registry entry is updated.

---

## Links

- **Affected files (this ADR, after operator sign-off):**
  - `supabase/migrations/2026_07_19_substrate_source_retrieval_split.sql` (new: the schema split)
  - `src/services/rag_pipeline.py` (modify: the chunk model split)
  - `src/services/document_processing_service.py` (modify: the page artifact persistence)
  - `src/models/rag.py` (modify: the citation model field)
  - `src/services/citation_verifier.py` (per ADR-2026-07-19-09: enforce `quote_source == "source_text"`)
  - `mobile/lib/widgets/field_citations_card.dart` (modify: add the "open page" button)
  - `mobile/lib/screens/page_artifact_viewer.dart` (new: the page viewer)
  - `tests/test_chunk_source_text_immutable.py` (new: the immutability test)
  - `tests/test_citation_rejects_retrieval_text.py` (new: the citation face test)
  - `tests/test_page_artifact_persistence.py` (new: the persistence integration test)
  - `mobile/test/page_artifact_viewer_test.dart` (new: the viewer widget test)
  - `docs/launch_claims/evidence-backed.md` (per ADR-2026-07-19-09: add the "user can verify" claim)
  - `docs/architecture/coverwise_canonical_architecture.md` (add the substrate-as-primary-deliverable definition)
  - `docs/decisions/README.md` (add this ADR to the index)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-09](./ADR-2026-07-19-09-evidence-backed-release-grade-definition.md) (the four faces; the citation face enforces `quote_source == "source_text"`)
  - [ADR-2026-07-19-08](./ADR-2026-07-19-08-cut-keep-finish-half-built-features.md) (the cuts and finishes that this ADR depends on)
  - [ADR-2026-07-19-10](./ADR-2026-07-19-10-outbox-only-durable-work-primitive.md) (the outbox that processes the page artifacts)
  - [Canonical architecture doc](../../architecture/coverwise_canonical_architecture.md) (target of the doc update)
  - `docs/audits/coverwise_document_intelligence_trust_audit_2026-07-18.md` P0-02, P0-03, P0-08, P1-15 (the audit findings)
- **Related code (current state):**
  - `src/services/rag_pipeline.py` (the `Chunk` class and `_contextualize_chunks`)
  - `src/services/document_processing_service.py` (the `_extract_text` that flattens pages)
  - `src/models/rag.py` (the `RAGCitation` model)
  - `mobile/lib/widgets/field_citations_card.dart` (the citation card UI)
  - `supabase/migrations/2026_07_18_evidence_substrate.sql` (the substrate schema)
- **Motto v3 alignment:** §0.1 (no parallel systems; the five layers are the single substrate contract), §0.4 (acceptance contract; the substrate is verifiable), §0.5 (evidence tiers; the page artifact is a tier), §0.7 (AI output boundary; the `source_text` vs `retrieval_text` split is the engineering answer to the NO-GO), §0.11 (customer-facing claims; the "user can verify" claim is a customer right), §0.12 (this document).
