# CoverWise auth + provider execution plan (2026-07-22)

## Decision baseline

- We are proceeding with the selected architecture in
  [`ADR-2026-07-22-08`](../decisions/ADR-2026-07-22-08-auth-and-provider-platform-strategy.md):
  managed Supabase as the production control plane, with explicit, staged migration
  paths to self-hosted Supabase or a split OSS stack later.
- Firebase is retained only as migration/compatibility history and is not allowed to
  become a production contract for web/product policy flows.

## Documentation-first status check (completed in this pass)

- New ADR created and registered:
  - `docs/decisions/ADR-2026-07-22-08-auth-and-provider-platform-strategy.md`
  - `docs/decisions/README.md` (index updated)
- Gap register updated with decision alignment:
  - `docs/review/coverwise_supabase_gap_register_2026-07-16.md` (2026-07-22 addendum)
- Storage doc clarified for legacy-vs-current path separation:
  - `docs/technical/data_storage/data_storage_and_management.md`
- Authoritative gap scan created for this pass:
  - `docs/planning/coverwise_auth_provider_platform_gap_scan_2026-07-22.md`

## What remains to close (gap map, by priority)

### P0 — Must not be bypassed

1. **Auth lifecycle runtime proof**
   - Real Supabase project proof for sign-up/confirm, sign-in/refresh, anonymous->account
     transfer, sign-out, password recovery, deletion/export.
   - Evidence target: staging auth flow evidence plus RLS owner checks and anti-abuse controls.

2. **Embedding + retrieval contract safety**
   - Single production embedding contract with hard-fail behavior on mismatch.
   - Rehearsed re-embedding and rollback path when model or dimension changes.

3. **Hybrid retrieval production behavior**
   - Representative-corpus run proving dense + lexical behavior, duplicate handling,
     citation correctness, and latency/quality deltas before launch claims.

### P1 — Required before full product promises

4. **Training execution path**
   - Execute model training provider run with credentialed environment.
   - Publish artifact integrity checks and model lineage.

5. **Outbox/risk recovery coverage**
   - Evidence that `qa_response`, `claim_verification`, and `renewal_diff` asynchronous
     paths are either implemented intentionally or explicitly deferred in canonical docs.

### P2 — Strategic migration hardening

6. **Restore/backup rehearsals**
   - Scheduled restore + orphan scans + deletion verification in staging.
7. **Self-hosted parity migration package**
   - Build and document once P0/P1 evidence gates above are stable.

## Implementation plan (ordered)

Phase 0 — Evidence lock (no behavior expansion)
- Finish auth runtime verification on a configured staging Supabase project.
- Add/refresh auth lifecycle evidence in gap register + cutover report.
- Execute gates via `docs/review/coverwise_runtime_gate_runbook_2026-07-22.md`.

Phase 1 — Retrieval integrity lock
- Execute representative corpus migration/baseline comparison.
- Add explicit migration checkpoints and rollback scripts for embedding/model changes.

Phase 2 — Execution lock
- Run training execution on real provider credentials and capture artifact lineage.
- Verify candidate/answer/audit chains in production-like conditions.

Phase 3 — Migration lock
- Publish parity runbook for self-hosted OSS migration.
- Keep Firebase out of active contracts; retain as archival/migration context only.

## Exit criteria

- No architecture claims are made in user-facing docs until the above P0/P1 gates are
re-verified with live-tier evidence.
- No new feature work proceeds until the gap register reflects the updated evidence state
  and the remaining open items are explicitly owned with owners and dates.

## Plan lock (2026-07-22): docs-first execution sequence

### 1) Baseline contract (must remain fixed before implementation)

- Canonical runtime control plane: **Supabase Auth + Postgres/pgvector + Supabase Storage + outbox**.
- Canonical architecture source: `docs/architecture/coverwise_canonical_architecture.md`.
- Platform decision source: `docs/decisions/ADR-2026-07-22-08-auth-and-provider-platform-strategy.md`.
- Gap and evidence source: `docs/review/coverwise_supabase_gap_register_2026-07-16.md`.

### 2) What we are authorizing in this cycle (documentation lock)

This cycle is **Documentation Lock + Evidence Definition** only. We are not yet changing runtime architecture in this pass.

- **Owner:** Pranay / architecture lane
- **Output required:** one updated execution plan + one cleaned canonical mobile architecture section.
- **Done definition:** no active doc claims a Firebase-auth/data contract as live.

Execution target for this run:
- `docs/review/coverwise_runtime_gate_runbook_2026-07-22.md`

### 3) Post-lock execution order (implementation + verification)

#### Phase A — Auth evidence pack (P0)
- Define and run a real Supabase staging matrix for:
  - sign-up + confirmation
  - sign-in + refresh
  - anonymous token bootstrap + claim transfer
  - sign-out + fresh session behavior
  - password recovery + deletion/export request
- Record explicit pass/fail evidence in the gap register.

#### Phase B — Retrieval + embedding lock (P0/P1)
- Define one production embedding contract checkpoint artifact.
- Define mismatch behavior (hard-fail + quarantine job + re-embed plan).
- Run representative corpus hybrid retrieval backfill + latency and correctness comparisons.

#### Phase C — Training execution + lineage (P1)
- Execute provider-gated training run in credentialed environment.
- Record lineage bundle: dataset release, model run manifest, provider/model versions, evaluator output.

#### Phase D — Migration hardening (P2)
- Publish self-hosted Supabase rehearsal playbook with:
  - auth migration replay,
  - RLS parity simulation,
  - storage restore + orphan scans,
  - restore/failback checklist.

## Current open gaps after docs-lock (status snapshot)

- **Open P0:** live auth lifecycle evidence (runtime), retrieval production parity against representative corpus, and deletion/export proof.
- **Open P1:** provider execution + training lineage with real credentials.
- **Open P2:** documented portability package (self-hosted/oss), and compatibility-document cleanup in remaining user-facing sections.

No code behavior changes are planned from this doc until this lock is explicit, owner-assigned, and evidence-backed.

## 2026-07-22 docs-first closure lanes (next iteration)

### Lane A — Documentation and contract coherence

- **Owner:** architecture lane
- **Goal:** one canonical claim source; everything else marked historical/archival
- **Output:** update remaining active-looking Firebase references in user-facing planning docs and add explicit addendum lines where needed
- **Done when:** no file in `docs/architecture`, `docs/technical`, and `docs/planning/product` includes a firebase-auth/data contract without a historical marker and a canonical reference

### Lane B — Auth runtime evidence

- **Owner:** auth + mobile lane
- **Goal:** close the real-runtime P0
- **Output:** staging auth matrix with outcomes for sign-up, confirmation, refresh, claim transfer, sign-out, recovery, deletion, and export
- **Done when:** matrix and logs are attached to `docs/review/coverwise_supabase_gap_register_2026-07-16.md`

### Lane C — Retrieval/retraining evidence

- **Owner:** retrieval + platform lane
- **Goal:** close the P0/P1 technical uncertainty
- **Output:** representative-corpus hybrid retrieval backfill + hard-fail/re-embed checkpoint + production-safe embedding contract test
- **Done when:** evidence of precision/recall deltas, duplicate handling, and rollback readiness is logged with timestamps in gap register

### Lane D — Training and portability readiness

- **Owner:** AI platform + ops lane
- **Goal:** P1/P2 evidence gate completion
- **Output:** provider-train run manifest, dataset+model lineage record, and self-hosted Supabase rehearsal checklist
- **Done when:** lineage + rehearsal artifacts are in `docs/review/coverwise_supabase_cutover_report_2026-07-21.md` or successor

## Addendum (2026-07-22) — plan lock and concrete provider-gap audit

We are choosing one decision path first and rejecting architecture drift-by-default:

### 1) Chosen plan (single path now)

- **Production control plane:** managed Supabase (Auth + Postgres/pgvector + Storage + RLS + RPC).
- **Reasoning:** same ownership and policy boundary already threaded through DB, retrieval, and training artifacts; zero translation layer for documents, consent, and evidence.
- **Firebase status:** historical/compatibility reference only, not active contract.
- **Evidence rule:** feature claims can only advance when auth lifecycle, retrieval, and training evidence are proven in a configured runtime.

### 2) If architecture were Firebase-first, required contract changes (high-cost, high-rewrite)

| Area | Current Supabase contract | Firebase-first change set required |
|---|---|---|
| Identity in DB | `auth.uid()` is the canonical owner in SQL | Introduce deterministic mapping `firebase_uid -> canonical_owner_id` plus migration discipline for every write path |
| Policy enforcement | SQL-level RLS + RPC authorization | Replace with service-owned session checks + per-query ownership filters; recreate equivalent guarantees without native policy guarantees |
| Anonymous→account transition | `POST /user/claim-anonymous` moves all owned rows atomically in one SQL boundary | Rebuild transition contract: session bootstrap, anonymous token lifecycle, idempotent ownership migration, rollback logs |
| Storage | RLS-backed private object policies on Supabase buckets | Rebuild storage policy layer (signed URLs/custom authorization middleware) per object type and route |
| Retrieval/search | Supabase hybrid: pgvector + owner-filtered FTS (single canonical corpus contract) | Rebuild ingestion + retrieval contracts for whichever Firebase-compatible vector/search path you choose (Firestore vector, external vector DB, or dual write) |
| Training/eval | Postgres-native lineage: documents/chunks/answers/metrics + artifact inventory | Build a new lineage bridge from Firebase exports to training corpus, plus provenance + rollback parity tests |
| Operator visibility | One DB + outbox + audit trail | Move operator workflows to Firebase-auth-gated claims and log replayable events with same observability envelope |

This is a full architectural rewrite, not a one-library replacement. The only reason to choose it is if product requirements force Firebase-native ecosystem features and you accept temporary policy risk during migration.

### 3) Current real gaps to close before the next stage (docs + runtime)

1. **Auth lifecycle runtime evidence (P0):** sign-up/confirm, sign-in, refresh, anonymous claim, sign-out, recovery, deletion/export against a real Supabase project.
2. **Search/retrieval parity evidence (P0/P1):** hybrid query behavior proof over a representative corpus and rollback checkpoint for embedding model dimension/family changes.
3. **Training execution evidence (P1):** real provider run with artifact lineage and publishable model outputs.
4. **Compatibility-doc cleanup (P2):** mark active Firebase references as historical only and keep one authoritative architecture source.
5. **Portability playbook (P2):** self-hosted Supabase migration rehearsal with auth export/import, RLS parity replay, storage restore, and operator runbook.

## Addendum (2026-07-22) — docs-first execution matrix for gap closure

### What is locked now

- Architecture decision is locked to managed Supabase as production control plane.
- Firebase remains historical/compatibility context only.
- No production behavior should be added before this lane is complete:
  1. P0 lifecycle correctness
  2. P0/P1 retrieval + retrieval-contract correctness
  3. P1 training and outbox/runtime evidence

### Gap matrix (current working set)

| Priority | Capability | Current gap type | What to close in this run | Evidence required | Owner |
|---|---|---|---|---|---|
| P0 | Auth lifecycle (Supabase) | Runtime proof | Run a real-account auth matrix against configured staging Supabase | Sign-up/confirm/sign-in/refresh/claim/claim-anon/recovery/sign-out/delete/export outcomes + RLS checks | Auth + mobile lane |
| P0 | Retrieval + hybrid search | Behavior proof | Run representative corpus hybrid backfill and quality/diff audit | Deterministic ranking deltas, duplicate handling, citation integrity, latency bands | Retrieval lane |
| P0 | Embedding/feature model drift | Contract safety | Lock provider-family behavior and version migration policy | Mismatch rejection test, re-embed checkpoint, rollback procedure | Platform + backend lane |
| P1 | Provider execution | Integration proof | Execute real credentialed training run and publish lineage | Model run manifest, dataset release linkage, evaluator bundle, artifact checksums | AI/provider lane |
| P1 | Async recovery resilience | Operations proof | Prove outbox risk-path recovery for critical channels | Replay runbook + failure logs + recovery outcome matrix | Backend + ops lane |
| P1 | Deletion/export/storage lifecycle | Runtime lifecycle proof | Stage recovery/orphan/delete proof in non-prod | Restore dry-run + orphan scan + deletion attestation | Storage + backend lane |
| P2 | Portability route | Strategy-to-runbook proof | Publish and rehearse self-hosted Supabase migration playbook | Auth export/import + RLS replay + storage restore checklist + failback log | Platform ops |

### Close order from this plan

1. **Close P0 items first** (auth lifecycle and retrieval behavior).  
   If any P0 fails, this plan pauses and evidence is reopened.
2. **Run P1 evidence loops** (provider/training and async recovery/storage lifecycle).
3. **Prepare P2 portability package** only after P0/P1 show stable passes from a reproducible staging trace.

### What counts as "gap closed"

An item is closed only when its evidence is logged in one canonical artifact:

- `docs/review/coverwise_supabase_gap_register_2026-07-16.md`
- `docs/review/coverwise_supabase_cutover_report_2026-07-21.md` (or successor)
- New or updated runbook artifacts under `docs/technical` and `tools/` as appropriate.
