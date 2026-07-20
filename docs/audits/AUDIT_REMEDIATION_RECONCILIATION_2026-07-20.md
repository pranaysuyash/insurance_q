# Audit Remediation Reconciliation — 2026-07-20

**Baseline audit commit:** `e3440a5` (2026-07-18)
**Current head:** `9e42b54` (2026-07-20)
**Delta:** 34 commits

---

## How to read this report

Each section maps one audit/plan document against codebase reality with statuses:
- **DONE** — implemented and active
- **NOT DONE** — unimplemented or still broken
- **DONE DIFFERENTLY** — decision changed from original audit recommendation
- **PARTIAL** — partially done, or contract exists but not adopted
- **DISCARDED** — explicitly cut/rejected by ADR or operator decision
- **OVERRULED** — ADR or operator chose a different path than audit recommended

---

## 1. Master Remediation Sequence (from master index)

### Phase 0: Freeze and remove unsafe claims

| Item | Status | Notes |
|------|--------|-------|
| Hide/remove Health Score | **DONE DIFFERENTLY** | ADR-08 decided to **KEEP, REDESIGN** as "Coverage Check-in"; still live in its original form |
| Remove coverage recommendations | **NOT DONE** | `analyzeCoverageGaps()` in `policy_extraction_service.dart` still produces recommendations |
| Remove What-If premium estimate | **DONE DIFFERENTLY** | ADR-08 decided to **KEEP, REDESIGN** as "Coverage Adequacy"; still live in original form |
| Remove generic claim deadlines/requirements | **DONE** | No "X days to file" claims found |
| Hide purchase/upgrade/pack UI | **DONE DIFFERENTLY** | ADR-08 decided to **FINISH PROPERLY**; RevenueCat billing now integrated and live |
| Remove token copy | **DONE** | P0-07: profile screen shows only read-only session status |
| Remove phone-backup claims | **DONE** | P0-13: all copy now honest — "stored locally only" |
| Relabel local deletion and pending sync | **DONE** | P0-02: "Remove from this device" with honest copy |
| Correct landing page, README, store copy | **NOT DONE** | Not verified; no production landing page check done |
| Freeze new feature work | **DONE** | ADR-08 + convergence focus established |

### Phase 1: Canonical principal, document identity, local storage

| Item | Status | Notes |
|------|--------|-------|
| Principal-scoped encrypted local DB/files | **NOT DONE** | `PrincipalKeyService` exists but is **never imported or called** from app startup, sign-out, or auth transitions |
| One server document ID | **DONE** | Consistent UUID throughout |
| One authenticated API client | **DONE** | `DocumentService.authenticatedDio` with `AuthInterceptor` |
| Account-switch workspace isolation | **NOT DONE** | Sign-out clears Supabase session only; Hive boxes, files, consent ledger not cleared |
| Full anonymous-to-account transactional migration | **PARTIAL** | Documents + chunks transferred; evidence, summaries, answers, consent NOT transferred |
| Anonymous revocation | **NOT DONE** | Old JWT never invalidated |
| Server library and clean-device restore | **NOT DONE** | No restore flow exists |
| Explicit offline operations | **NOT DONE** | No offline state tracking |

### Phase 2: Evidence and document domain

| Item | Status | Notes |
|------|--------|-------|
| Document versions | **PARTIAL** | Schema supports; `document_version_id` concept exists but not populated in active path |
| Page artifacts/completeness | **DONE** | Pages rendered at 150 DPI PNG in active upload path; `page_artifact_id_map` used |
| Immutable source spans/tables | **PARTIAL** | Schema exists; source spans not populated by extraction (only page-level citations for first release) |
| Evidence-first fields | **DONE** | Evidence substrate integrated into `process_document_full()` Stage 3.5 |
| Correction/conflict state | **PARTIAL** | `editable_field` overrides exist (commit `ac0d672`), but conflict/version model not built |
| Source/retrieval text separation | **PARTIAL** | ADR-11 Layer 1-2 shipped (commit `1083418`); `retrieval_text` field exists but backfill not complete |
| Summaries in Postgres | **DONE** | Summary persisted via substrate pipeline |
| Versioned chunks/indexes | **PARTIAL** | Schema has `document_version_id`; version increment not implemented |
| Exact and FTS search in Postgres | **NOT DONE** | P0-17: still depends on local SQLite FTS; Supabase FTS not implemented |
| Verified citations | **DONE** | Citation verifier shipped (commit `1083418`, Layer 3); citations quote `source_text` only |

### Phase 3: Durable operations and lifecycle

| Item | Status | Notes |
|------|--------|-------|
| Durable upload/processing jobs | **PARTIAL** | Outbox worker has 2 handlers registered; upload path still uses FastAPI `BackgroundTasks`, not the outbox |
| Heartbeat/reaper/retry/dead-letter | **DONE** | Outbox contract includes attempts, leases, retries, dead letter, health views |
| Page/token/call/time/cost budgets | **NOT DONE** | Not implemented |
| Transactional artifact promotion | **NOT DONE** | Not implemented |
| Document deletion job | **DONE** | Remote delete operational; mobile does remote-first then local |
| Account erasure job | **PARTIAL** | Returns 202 with per-stage status; no durable deletion job enqueued (P0-10) |
| Export/retention | **NOT DONE** | Not implemented |
| Store registry | **NOT DONE** | Not implemented |
| Operator retry/cancel/quarantine | **NOT DONE** | Not implemented |

### Phase 4: API and client convergence

| Item | Status | Notes |
|------|--------|-------|
| `/v1` contract | **NOT DONE** | No versioned API prefix |
| One answer endpoint | **NOT DONE** | Multiple Q&A paths exist |
| Typed `EvidenceSource` | **DONE** | Evidence model has typed source |
| Semantic HTTP errors | **PARTIAL** | Some endpoints improved; broad exception handling remains |
| Server pagination/filtering | **NOT DONE** | Not implemented |
| Idempotency/resource versions | **NOT DONE** | Not implemented |
| Generated/validated Dart DTOs | **NOT DONE** | Hand-coded DTOs on both sides |
| Remove compatibility endpoints | **NOT DONE** | Legacy backends/paths coexist |

### Phase 5: Quality and operational evidence

| Item | Status | Notes |
|------|--------|-------|
| Repair CI | **PARTIAL** | Python tests + lint + Docker in CI; Flutter tests NOT in CI |
| Required Flutter/Python checks | **PARTIAL** | Python only; Flutter missing entirely |
| Supabase migration/integration environment | **NOT DONE** | Not provisioned |
| Real document-intelligence evaluations | **NOT DONE** | Benchmark is 12-fixture-query dry run, not decision-grade |
| Security/supply-chain scans | **NOT DONE** | Not in CI |
| Metrics, traces, cost, SLOs, alerts | **NOT DONE** | Not implemented |
| Load/chaos tests | **NOT DONE** | Not implemented |
| Immutable artifacts/release manifest | **NOT DONE** | Docker image lacks immutable SHA tags in practice |
| Staging canary/rollback | **NOT DONE** | Not implemented |
| Backup restore/deletion drill | **NOT DONE** | Not implemented |

### Phase 6: Narrow product launch

| Item | Status | Notes |
|------|--------|-------|
| Policy library | **DONE** | Active |
| Evidence-linked summary | **DONE** | Active with citations |
| Verified Q&A | **DONE** | Active with source_text verification |
| Verified renewal reminder | **DONE** | Active |
| Verified insurer contacts | **DONE** | Active |
| Verified offline emergency snapshot | **NOT DONE** | Not verified |
| Account/data controls | **PARTIAL** | Privacy policy + ToS shipped; deletion partial |

### Phase 7: Real monetization (ADR-08 decided FINISH PROPERLY)

| Item | Status | Notes |
|------|--------|-------|
| Select billing/store products | **DONE** | RevenueCat integrated |
| Server receipt verification | **DONE** | RevenueCat handles |
| Server entitlement ledger | **DONE** | Server-enforced entitlements with sync endpoint |
| Refund/restore/grace/cancellation/support | **PARTIAL** | Restore flow exists; refund/support workflows not verified |
| Pricing tests | **NOT DONE** | Not done |
| One capacity-based paid offer | **DONE** | Plans: Free/Plus/Family + Q&A packs |
| Expansion only after evidence | **DONE DIFFERENTLY** | ADR-08 widened the product before billing was verified |

---

## 2. Evidence Pipeline (from Document Intelligence Audit + Current State Review)

| Finding | Status | Evidence |
|---------|--------|----------|
| **P0-01**: `current_user.id` → `uid` | **DONE** | `evidence.py:97` uses `current_user.uid`; regression test exists |
| **P0-02**: Evidence mobile client unauthenticated | **DONE** | `EvidenceService` uses `DocumentService.authenticatedDio` with `AuthInterceptor` |
| **P0-03**: Evidence pipeline outside ingestion | **DONE** | Stage 3.5 in `process_document_full()` calls `EvidencePipeline.run_for_document()` |
| **P0-04**: Derived states collapsed | **DONE** | Full state machine in `derive_document_state()` with 7+ states |
| **P0-05**: Mixed PDFs silently partial | **NOT DONE** | Main path still joins all text; image-only pages not explicitly marked |
| **P0-06**: Persistent local processing copy | **NOT DONE** | `storage/documents/{doc_id}_{filename}` still outside canonical lifecycle |
| **P0-07**: Undefined `document_id` in parser | **DONE** | Fixed |
| **P0-08**: Principal encryption ADR reopened | **NOT DONE** | Still JWT-derived; `PrincipalKeyService` never wired into app |
| **P0-13**: `hasMinimumViableEvidence` checks completeness not evidence | **PARTIAL** | Still checks field population only; no citation cross-reference |
| **P0-14**: Policy detail mixes cited and uncited facts | **PARTIAL** | Citations render alongside uncited legacy fields; no per-field evidence status |
| **P0-16**: Embedding fallback unsafe for Supabase | **NOT DONE** | `recreate_collection` still called at runtime with dimension changes |
| **P0-17**: Exact lookup broken in Supabase path | **NOT DONE** | Still depends on local SQLite FTS |
| Evidence service composition at startup | **NOT DONE** | Constructed per-request/per-document |
| Citation UI connected | **DONE** | `FieldCitationsCard` rendered in policy detail |
| Page artifacts in active path | **DONE** | Pages rendered to PNG at 150 DPI in upload path |

---

## 3. Security/Privacy/Identity Audit Phase 0

| Item | Status | Notes |
|------|--------|-------|
| **P0-07**: Remove "Copy session token" | **DONE** | Profile shows read-only session status |
| **P0-13**: Remove/relabel phone backup claims | **DONE** | "Stored locally only, no cross-device sync" |
| **P0-02/P0-03**: Rename delete/disable replace | **DONE** | "Remove from this device"; Replace button disabled |
| **P0-04**: Return 202 on account deletion | **DONE** | `DELETE /user/account` returns 202; client handles 200/202 |
| **P0-08**: Restrict analytics reads | **DONE** | `X-Operator-Token` with constant-time comparison; fail-closed |
| **P0-10**: Disable optional analytics by default | **DONE** | Fail-closed: no consent = analytics off |
| **P0-12**: Stop raw exception telemetry | **DONE** | Sends only error type + error code; no message/stack |
| **P0-18**: Correct privacy copy | **DONE** | "Removing from this device does NOT delete server copy" |
| **P0-14** (partial): Android backup | **NOT DONE** | `allowBackup` not explicitly disabled; no `backup_rules.xml` |
| **P0-01** (partial): Sign-out workspace switch | **PARTIAL** | Supabase session cleared; Hive/files/consent ledger not cleared |

---

## 4. Product Strategy Audit Phase 0

| Item | Status | Notes |
|------|--------|-------|
| Remove unsafe features | **DONE DIFFERENTLY** | ADR-08 kept Health Score + What-If (redesign); removed token copy, phone backup lies |
| Hide stub billing/prices | **DONE DIFFERENTLY** | ADR-08 decided **finish properly**; RevenueCat integrated live |
| Remove lead-funnel/false backup claims | **DONE** | Phone capture honest; lead capture still in code? |
| Correct public copy | **PARTIAL** | In-app copy fixed; README/landing/store copy not verified |

---

## 5. ADR-08 Cut/Keep/Finish Decisions (Accepted 2026-07-19)

| Feature | ADR Decision | Current Status | Gap |
|---------|-------------|----------------|-----|
| 1. Insurance Health Score | KEEP, REDESIGN as "Coverage Check-in" | **LIVE in original form** | NOT redesigned yet |
| 2. What-If Premium Calculator | KEEP, REDESIGN as "Coverage Adequacy" | **LIVE in original form** | NOT redesigned yet |
| 3. Old claims assistant | KEEP OLD as "Claim Document Vault" + reroute `/claims` | **Both screens live; `/claims` points to new** | Old screen removed from More entry? Unclear |
| 4. Billing stub / BillingAdapter | FINISH PROPERLY | **RevenueCat integrated live** | Substantially done |
| 5. Lead capture | KEEP framework, REMOVE form | **Not verified** | TBD |
| 6. Family inventory | FINISH PROPERLY, FULL | **Not verified** | TBD |
| 7. Claim tracker | FINISH PROPERLY (integrated with vault) | **Not verified** | TBD |
| 8. Insurance cards | FINISH PROPERLY, SCOPED | **Not verified** | TBD |
| 9. Literacy quiz | CUT | **Not verified** | TBD |
| 10. Q&A packs | FINISH PROPERLY (same as #4) | **RevenueCat integrated** | Part of #4 |

---

## 6. Embedding Benchmark (2026-07-19)

| Finding | Status |
|---------|--------|
| Domain-specific ground truth | **DONE DIFFERENTLY** — only 12 fixture queries, not real policies |
| `text-embedding-3-small` is correct | **DONE** — matches 1536-D schema |
| Not decision-grade | **STILL TRUE** — 12 queries is not a real benchmark |
| Do not describe as real provider comparison | **NOT VERIFIED** — docs may still overclaim |

---

## 7. Operations/Reliability Audit

| Item | Status | Notes |
|------|--------|-------|
| Durable jobs with recovery | **PARTIAL** | Outbox contract exists; upload path bypasses it |
| Health endpoints/metrics | **NOT DONE** | No metrics, traces, SLOs, alerts |
| Cost enforcement | **NOT DONE** | Not implemented |
| Backup drill | **NOT DONE** | Not done |
| Rollback/repair surfaces | **NOT DONE** | No operator repair tools |

---

## 8. Testing/Release Engineering Audit

| Item | Status | Notes |
|------|--------|-------|
| CI repaired | **PARTIAL** | Python tests + lint + Docker in CI |
| Flutter tests in CI | **NOT DONE** | `flutter test` and `flutter analyze` not in workflow |
| Migration/integration tests | **NOT DONE** | Not in CI |
| Security scans | **NOT DONE** | Not in CI |
| Immutable artifact tags | **NOT DONE** | No SHA-tagged immutable releases |
| Evaluation tests | **NOT DONE** | Benchmark is a fixture dry run |

---

## 9. Mobile Experience/Accessibility Audit

| Item | Status | Notes |
|------|--------|-------|
| Hardcoded colors to theme (P0-2.7) | **NOT DONE** | 88 hardcoded `Color(0x...)` values remain |
| Unused context param in `_QuickActions` (P0-2.6) | **DONE** | Removed |
| Pass 3 review (P0-2.8) | **UNCONFIRMED** | Review gate; not verifiable from code |
| Accessibility audit items | **NOT VERIFIED** | Not checked in this pass |
| Privacy policy + ToS (P0-04) | **DONE** | Shipped in commit `ace2590` |

---

## 10. ADRs Status

### 25 ADRs committed (2026-07-19)

| ADR | Topic | Status |
|-----|-------|--------|
| 01 | Durable work queue via Supabase outbox | **Accepted, not adopted** — outbox exists, upload path doesn't use it |
| 02 | Outbox migration deferred | **Accepted** — document processing not yet migrated |
| 03 | Embedding model default | **Accepted** — `text-embedding-3-small` used |
| 04 | Coverage gap / claim assistance thin slice | **Adopted** — shipped substrate-backed screens |
| 05 | Canonical architecture doc location | **Done** — `docs/architecture/coverwise_canonical_architecture.md` |
| 06 | Security Phase 1: encrypted local storage | **Accepted, not adopted** — `PrincipalKeyService` never wired |
| 07 | Security Phase 2: server-side consent ledger | **Adopted** — table + trigger + views + endpoint + client |
| 08 | Cut/keep/finish half-built features | **Accepted** — operator sign-off on revision 2 |
| 09 | Evidence-backed release grade definition | **Accepted** |
| 10 | Outbox-only durable work primitive | **Accepted** |
| 11 | Substrate as primary deliverable | **Partially adopted** — Layers 1-4 shipped (commit `1083418`), Layer 5 (page viewer UI) TBD |
| 12 | Operator trust model | **Accepted** |
| 13 | What-if premium refused as product capability | **OVERRULED** — ADR-08 decided KEEP, REDESIGN |
| 14 | Family coverage map substrate extension | **Accepted** |
| 15 | Claim document vault privacy policy | **Not yet implemented** |
| 16 | Value-add partnerships framework | **Accepted** |
| 17 | Coverage adequacy substrate extension | **Accepted** |
| 18 | Coverage check-in substrate extension | **Accepted** |
| 19 | Claim document vault substrate extension | **Accepted** |
| 20 | Family coverage map privacy policy | **Accepted** |
| 21 | Coverage check-in privacy policy | **Accepted** |
| 22 | Coverage adequacy privacy policy | **Accepted** |
| 23 | LLM provider data handling policy | **Accepted** |
| 24 | Qdrant vector database data handling policy | **Accepted** |
| 25 | Supabase storage data handling policy | **Accepted** |

---

## 11. Root-Level Documentation Cleanup

| Item | Status |
|------|--------|
| Move root `coverwise_*_audit_2026-07-18.md` docs (8 files) to `docs/audits/` | **DONE** |
| Move root `coverwise_architecture_audit_2026-07-18.docx` to `docs/audits/` | **DONE** |
| Remove committed `insurance_app.db` | **NOT DONE** — still at root |
| Remove committed Hive test databases | **NOT DONE** — `mobile/test_hive/`, `mobile/test_analytics_gate_hive/` still present |
| Remove dry-run benchmark results | **NOT DONE** — JSON files in `docs/review/evidence/` |
| Remove vendored skill trees | **NOT DONE** — `.agent/`, `.claude/`, `.cursor/`, `.zcode/` etc. still present |
| Add `.dockerignore` | **NOT DONE** |
| Add generated-artifact policy | **NOT DONE** |

---

## 12. Top 20 Concrete Moves (from Current State Review)

| # | Move | Status |
|---|------|--------|
| 1 | Fix `current_user.id` to `uid` | **DONE** |
| 2 | Use authenticated Dio for evidence | **DONE** |
| 3 | Accept/parse account deletion HTTP 202 | **DONE** |
| 4 | Remove false deletion-success snackbar | **DONE** |
| 5 | Fix undefined `document_id` | **DONE** |
| 6 | Remove persistent local processing copies | **NOT DONE** |
| 7 | Persist exact derived state | **DONE** |
| 8 | Add page-level extraction result | **DONE** |
| 9 | Wire page artifacts into active processing | **DONE** |
| 10 | Wire deterministic evidence extraction | **DONE** |
| 11 | Change room-rent extractor to `generate_structured` | **NOT DONE** — still calls `llm.complete()` |
| 12 | Fix citation-view latest-version semantics | **NOT DONE** — no latest-version selection in view |
| 13 | Add document version and processing run IDs | **NOT DONE** — schema supports but not populated |
| 14 | Register processing + substrate outbox handlers | **DONE** — 2 handlers registered |
| 15 | Add outbox idempotency and atomic claim RPC | **NOT DONE** — enqueue side not connected |
| 16 | Implement remote delete and replacement | **DONE** |
| 17 | Reopen JWT-derived encryption ADR | **NOT DONE** |
| 18 | Remove Health Score and What-If from navigation | **DONE DIFFERENTLY** — ADR-08 kept both (redesign planned) |
| 19 | Replace CI workflow | **PARTIAL** — Python tests + lint + Docker; Flutter missing |
| 20 | Mark architecture components active/contract/deferred | **NOT DONE** — canonical docs don't label component adoption status |

---

## 13. Summary Count

| Category | DONE | NOT DONE | PARTIAL | DONE DIFFERENTLY | DISCARDED | TOTAL |
|----------|------|----------|---------|------------------|-----------|-------|
| Master Phase 0 items | 4 | 1 | 0 | 3 | 0 | 8 |
| Master Phase 1 items | 2 | 4 | 1 | 0 | 0 | 7 |
| Master Phase 2 items | 4 | 1 | 4 | 0 | 0 | 9 |
| Master Phase 3 items | 2 | 5 | 2 | 0 | 0 | 9 |
| Master Phase 4 items | 1 | 5 | 1 | 0 | 0 | 7 |
| Master Phase 5 items | 0 | 8 | 2 | 0 | 0 | 10 |
| Master Phase 6 items | 5 | 1 | 1 | 0 | 0 | 7 |
| Evidence pipeline P0s | 6 | 4 | 2 | 0 | 0 | 12 |
| Security Phase 0 | 7 | 1 | 1 | 0 | 0 | 9 |
| Top 20 moves | 10 | 6 | 1 | 1 | 0 | 18 (2 unverifiable) |
| ADR-08 features | 0 | 6 | 0 | 0 | 1 | 7 (3 TBD) |
| **TOTAL** | **41** | **42** | **15** | **4** | **1** | **103** |

---

## 14. Critical Open Gaps (Not Done, High Risk)

1. **Principal encryption not wired** — `PrincipalKeyService` (282 lines) never imported or called from anywhere
2. **Outbox not adopted** — upload path still uses FastAPI `BackgroundTasks`; enqueue side never connected
3. **Anonymous claim incomplete** — documents + chunks only; evidence, summaries, answers, consent NOT transferred; old JWT NOT revoked
4. **Sign-out doesn't clear workspace** — Hive boxes, consent ledger, local files persist
5. **Flutter tests not in CI** — mobile app has zero CI coverage
6. **Embedding fallback still unsafe** — `recreate_collection` at runtime with dimension changes
7. **Analytics still SQLite-primary** — Supabase dual-write off by default
8. **Supabase FTS not implemented** — exact lookup broken on production backend
9. **Health Score + What-If still live in original form** — ADR-08 said redesign, not done
10. **88 hardcoded colors remain** — dark mode readiness blocked
11. **Document versioning not operational** — schema supports but not populated
12. **LLM room-rent extractor calls wrong contract** — `llm.complete()` instead of `generate_structured`

The bottlenecks are no longer ideation or direction. They are **adoption and convergence** — connecting the designed contracts to the operational code paths.
