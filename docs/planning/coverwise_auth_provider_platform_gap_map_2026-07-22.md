# CoverWise auth/provider platform gap map (2026-07-22)

**Date:** 2026-07-22  
**Goal:** keep one production control plane for identity + ownership + storage + retrieval, while keeping clear, staged portability options.

## 1) Strategic decision (re-stated)

We proceed with **managed Supabase as current production control plane**:

- Supabase Auth for identity/session
- Postgres + pgvector + FTS for retrieval and policy enforcement
- Supabase Storage for artifacts and retention/audit needs
- Outbox + durable SQL state for async workflows

Firebase and any other identity/storage options are explicitly deferred to portability lanes, not active production contracts.

## 2) Why this is not a “Firebase vs Supabase preference” call

This is an architecture-surface decision:

1. Product has canonical ownership/rules written into SQL (`auth.uid()` and policy checks).
2. We need one ownership boundary for documents, evidence, consent, and deletion.
3. Retrieval/training/studio artifacts currently expect a Postgres-auth boundary.

Adding Firebase as a second truth source requires a mapping seam (`Firebase UID -> canonical owner ID`) for every owned table and policy touchpoint. That increases blast radius, migration debt, and operator blast recovery complexity.

## 3) Alternatives considered (open-source and managed)

### 3.1 Split OSS stack (Auth + Postgres + vector + storage separated)

- Examples: Keycloak (auth), PostgreSQL/pgvector (retrieval), MinIO (object storage), separate worker layer for event policy enforcement.
- Benefit: maximal component independence and some on-prem control.
- Cost: highest integration and audit-contract complexity because ownership and policy are no longer native to one control plane.

### 3.2 Self-hosted Supabase OSS stack

- Examples: Supabase OSS deployment stack (Auth, PostgREST, Realtime, Storage, PostgreSQL).
- Benefit: keeps most product contracts unchanged; realistic portability path.
- Cost: operational lift is real (upgrades, backup/restore, networking, mail, monitoring, incident recovery).

### 3.3 Firebase-centric option (auth only + current Supabase/Postgres data)

- Benefit: familiar mobile auth UX.
- Cost: requires permanent identity translation layer plus RLS boundary remap and migration debt for all owner checks.

## 4) Gaps to close (docs-first audit)

This section is the active gap list, not completed work.

### P0 — Identity flow correctness (must close before launch claims)

1. **Google auth claims flow currently does not trigger claim orchestration** ✅
   - **Where:** `mobile/lib/screens/account_screen.dart::_signInWithGoogle` and `mobile/lib/services/auth_service.dart`.
   - **Issue:** email/password path calls `prepareAnonymousWorkspaceClaim()` + `claimAnonymousData()` when a session is available; Google path only initiates OAuth and relies on stream callback.
   - **Risk:** anonymous workspace may not be claimed consistently after Google sign-in; ownership and migration behavior can diverge.
   - **Status:** **Closed in code path** (`_signInWithGoogle` now prepares claim intent, and auth-state transition in `main.dart` performs claim after a successful authenticated transition).
   - **Evidence target:** **remaining:** targeted end-to-end mobile test + staging proof of anonymous workspace transfer.

2. **Runtime auth lifecycle evidence is still incomplete**
   - **Where:** docs gap register and ADR indicate live Auth/RLS coverage is pending.
   - **Issue:** code paths for sign-up, sign-in, refresh, recovery, sign-out, deletion, and export are present, but staging/production-tier evidence is not yet fully closed.
   - **Required:** environment-gated auth proof suite (Tier 3+, then Tier 4).

3. **Recovery after account sign-out is operationally incomplete for all auth methods**
   - **Where:** `mobile/lib/services/auth_service.dart` (`signOut`), `mobile/lib/screens/profile_screen.dart` (`_signOut`).
   - **Issue:** current behavior focuses on app workspace reset and auth client logout, but does not include an explicit anonymous-token state model transition for every session mode.
   - **Required:** explicit contract for what token is used post-sign-out and how workspace claim state is reset.

### P1 — Contract-proofing for portability

4. **Auth/identity portability migration artifacts are not a production playbook yet**
   - **Where:** ADR + execution plan plus gap register.
   - **Issue:** portability plan exists conceptually but not as rehearsed migration package with operator checkpoints.
   - **Required:** migration playbook + rehearsal logs for self-hosted Supabase and/or split stack.

5. **No auth-platform-independent acceptance matrix in tests**
   - **Where:** `mobile/test/migration_integrity_test.dart` covers principal transition mechanics, not all auth provider flows.
   - **Issue:** no integration test asserts Google + claim + auth listener behavior today.
   - **Status:** **In progress.** Added `mobile/test/auth_claim_session_flow_test.dart` for single-use claim-intent semantics; still need end-to-end auth-event orchestration.
   - **Required:** add integration test for canonical auth-event orchestration regardless of provider.

### P2 — Long-term architecture hygiene

6. **Need explicit deprecation of historical Firebase references**
   - **Where:** `docs/technical/data_storage/data_storage_and_management.md` already marks Firebase as legacy.
   - **Issue:** historical diagrams and text still read as active architecture in places, even if addendums exist.
   - **Required:** keep current architecture canonicalized and mark legacy paths as historical at the same place where product decisions are made.

## 5) Execution order (docs -> implementation -> verification)

1. **Plan lock (current stage):** keep changes in docs and gap register only until all owners agree with P0 sequence.
2. **Implementation lock (Phase 0):** fix auth completion/orchestration so every provider path funnels through one claim-consistent transition boundary.
3. **Verification lock (Phase 1):** build a staging auth runbook and record evidence for create/sign-in/refresh/claim/sign-out/recovery flows.
4. **Portability lock (Phase 2):** add rehearsed migration playbooks and acceptance criteria without changing production ownership contracts.

### 5.1 Documentation hygiene lane

Keep documentation truth coherent while we run evidence gates:

- Update/annotate the following as **historical or compatibility-only** until explicitly superseded:
  - `docs/technical/data_storage/data_storage_and_management.md` (already marked historical section exists; preserve/refresh)
  - `docs/technical/architecture/current_system_architecture.md`
  - `docs/technical/system_architecture/comprehensive_architecture.md`
  - `docs/technical/modern_stack_overview.md`
- Preserve all historical/archival docs, but add an explicit addendum date + active/inactive classification.

## 6) Decision to continue

This plan is aligned to `motto_v3`: one decision, one long-term direction, documented migration paths, and explicit verification gates.

- Decision remains: **managed Supabase now, OSS parity explicit and staged later**.
- Next concrete deliverable should be **P0 auth-flow implementation + evidence capture**.

### 6.1 2026-07-22 gap ledger (post-doc scan)

| ID | Gap area | Evidence status | What we still need |
|---|---|---|---|
| AUTH-01 | Live Supabase auth lifecycle verification | ⚪ Pending | Staging matrix for sign-up/sign-in/refresh/recovery/claim/sign-out/delete/export |
| AUTH-02 | Auth sign-out and token state contract | ⚪ Pending | Explicit post-sign-out auth-token state and workspace state transition definition |
| RETR-01 | Retrieval production parity | ⚪ Pending | Representative corpus hybrid backfill and quality/latency regression evidence |
| RETR-02 | Embedding contract migration | ⚪ Pending | Dimension/model-fingerprint fail-closed proof + re-embed rollback path |
| TRAIN-01 | Provider training execution | ⚪ Pending | Credentialed training run with run manifest + evaluator bundle |
| DOC-01 | Historical Firebase references | ⚪ In progress | Add addendum + legacy label in remaining user-facing docs where Firebase is described as active |
| PORT-01 | Portability playbook | ⚪ Pending | Self-hosted migration rehearsal with auth export/import, RLS parity, storage restore verification |
