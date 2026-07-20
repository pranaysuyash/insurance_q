# ADR-2026-07-19-07: Security Phase 2 = server-side append-only consent ledger (Postgres table with RLS-deny-UPDATE-and-DELETE)

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** CoverWise's consent record lives in a server-side Postgres table (`public.consent_ledger`) that is **append-only by database enforcement** (RLS denies UPDATE and DELETE; only INSERT is allowed for the service_role). The Flutter app's existing local Hive box (`mobile/lib/services/consent_ledger.dart`) becomes a cache, not the source of truth. The server-side ledger is the source of truth for audit, regulatory compliance (DPDP Act 2023 / GDPR if applicable), and durability across device loss.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** Accepted.
- **Related artifacts:** [`supabase/migrations/2026_07_19_consent_ledger.sql`](../../../supabase/migrations/2026_07_19_consent_ledger.sql) (the table), [`src/services/consent_ledger_service.py`](../../../src/services/consent_ledger_service.py) (the typed access), [`src/api/consent.py`](../../../src/api/consent.py) (the FastAPI endpoint), [`mobile/lib/services/server_consent_service.dart`](../../../mobile/lib/services/server_consent_service.dart) (the Flutter client), [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (the principal-scoped key that encrypts the local cache).

---

## Context

The security audit flagged this as Security Phase 2. The question is: how do we record user consent in a way that is immutable, auditable, and verifiable? Today the consent ledger lives in the Flutter app's Hive boxes (a local device-scoped log of consent events like "I accept the privacy policy" or "I grant analytics consent"). The audit says this is insufficient:

1. **A lost phone is a lost consent record.** The local Hive box is gone; the consent record is gone. The user is now in a state where the system does not know whether they consented.
2. **A malicious app on the device can edit the local ledger.** The Hive box is encrypted with the principal key (Security Phase 1), but a sophisticated attacker with the user's credentials can still rewrite the local file. The server-side record is the canonical truth.
3. **Regulators (DPDP Act 2023 for India, GDPR for EU users) require auditable consent records.** A local Hive box is not auditable. A server-side append-only ledger is.

The current state of the repo (before this ADR):

- `mobile/lib/services/consent_ledger.dart` — the Flutter-side consent ledger, a Hive box on the device.
- `mobile/test/consent_ledger_test.dart` — the existing tests.
- The trust audit's Phase 0 P0-10 (per `docs/decisions/README.md` retroactive entries) made the Flutter consent collection fail-closed on missing consent. The server-side record is the missing piece: the audit's NO-GO on consent is that the record is device-scoped, not user-scoped.

---

## Options considered

### Option A: Append-only Postgres table with RLS-deny-UPDATE-and-DELETE. CHOSEN.

- **How it works:** a new `consent_ledger` table with columns `(id, user_id, consent_type, granted, policy_version, ip_address, user_agent, created_at)`. RLS enables the table; INSERT is allowed for the service_role; UPDATE and DELETE are denied via RLS policies with `using (false)`. The Flutter app POSTs consent events to a FastAPI endpoint, which inserts rows. The local Hive box is a cache.
- **Pros:**
  - The append-only contract is enforced at the database level, not in application code. A bug in the application cannot rewrite history.
  - The standard pattern for audit ledgers (used by Stripe, GitHub, etc.). Auditors recognize the pattern.
  - The migration is straightforward: 1 SQL migration + 1 Python service + 1 FastAPI endpoint + 1 Flutter client.
  - The Flutter cache keeps the UI fast (no network round-trip per consent check).
  - The schema is small (~5 columns + 1 timestamp).
- **Cons:**
  - A new table is a new attack surface. Mitigation: RLS denies UPDATE and DELETE; only INSERT is allowed; the service_role is the only writer.
  - The ledger grows over time. Mitigation: a follow-up retention policy (e.g. 7 years per regulatory requirements) deletes rows older than the retention period. The deletion is done via a server-side job, NOT by the application.
  - The Flutter cache can drift from the server. Mitigation: the Flutter app's consent-state UI shows the timestamp and policy_version from the cache, with a "last verified at" indicator. A follow-up session can add a "pull from server" refresh button.

### Option B: Use the existing `events_unrouted` table (the RevOps catch-all). REJECTED.

- **How it works:** consent events are recorded as analytics events in `events_unrouted`. The existing analytics pipeline handles them.
- **Pros:** no new table.
- **Cons:**
  - `events_unrouted` is the catch-all for analytics events; consent is not analytics. Mixing them is the parallel-paths anti-pattern.
  - The `events_unrouted` schema is not designed for audit (no `policy_version`, no `ip_address`, no `user_agent`).
  - The analytics pipeline may delete or aggregate old events; consent events must be retained for the regulatory period.
- **Why rejected:** the wrong shape for the wrong purpose.

### Option C: Use a managed service (e.g. OneTrust, Cookiebot). REJECTED.

- **How it works:** a third-party consent management platform records consent events. CoverWise reads the current state from the platform's API.
- **Pros:** the platform is purpose-built for consent; the regulatory compliance is the platform's problem.
- **Cons:**
  - A new vendor dependency. CoverWise is a solo-founder project; vendor lock-in is a real cost.
  - The cost is per-user, per-event. At CoverWise's scale (projected 10K users), the cost is significant.
  - The data is on the platform's servers, not CoverWise's. For DPDP Act 2023 compliance, the data should be in India (or at least under the operator's control). A US-based platform may not satisfy this.
- **Why rejected:** the cost, the vendor lock-in, and the data-residency concerns. The append-only Postgres table is the right shape for CoverWise's scale.

---

## Chosen path

**Option A: server-side append-only consent ledger (Postgres table with RLS-deny-UPDATE-and-DELETE).**

The implementation:

1. **`supabase/migrations/2026_07_19_consent_ledger.sql`** — the table.
   - Columns: `id` (uuid primary key), `user_id` (text, the Supabase Auth user ID), `consent_type` (text, e.g. `privacy_policy`, `analytics`, `marketing_emails`, `camera_access`), `granted` (boolean), `policy_version` (text, the version of the document the user consented to), `ip_address` (text, optional, for audit), `user_agent` (text, optional, for audit), `created_at` (timestamptz, the timestamp of the consent event).
   - RLS: enabled. INSERT allowed for service_role. UPDATE and DELETE denied with `using (false)`.
   - Indexes: `(user_id, consent_type, created_at desc)` for the "current consent" query.
   - View: `v_current_consent` — for each (user_id, consent_type), the most recent row. This is the "current state" the UI reads.

2. **`src/services/consent_ledger_service.py`** — the typed access layer.
   - `record_consent(user_id, consent_type, granted, policy_version, ip_address, user_agent) -> UUID` — inserts a row.
   - `get_current_consent(user_id, consent_type) -> Optional[ConsentRecord]` — reads the most recent row.
   - `get_current_consent_all(user_id) -> list[ConsentRecord]` — reads the most recent row for each consent_type for the user.

3. **`src/api/consent.py`** — the FastAPI endpoint.
   - `POST /consent` — records a consent event. Body: `consent_type`, `granted`, `policy_version`. The endpoint extracts the user_id from the Supabase Auth token (not from the body, to prevent spoofing); records `ip_address` and `user_agent` from the request.
   - `GET /consent/current` — returns the current consent state for the authenticated user.

4. **`mobile/lib/services/server_consent_service.dart`** — the Flutter client.
   - `recordConsent(consentType, granted, policyVersion)` — calls POST /consent, then updates the local Hive cache.
   - `getCurrentConsent(consentType)` — reads the local cache; on miss, falls back to GET /consent/current.

5. **Tests:**
   - SQL: the RLS-deny-UPDATE-and-DELETE is enforceable (a direct UPDATE or DELETE via the service_role is rejected by RLS — wait, no, RLS only applies to non-service-role roles. The service_role bypasses RLS. The append-only enforcement must be at the table level or via a trigger. v1 uses a Postgres trigger that raises an exception on UPDATE and DELETE).
   - Python: the service is testable with a mocked supabase client.
   - FastAPI: the endpoint is testable with a mocked service.
   - Flutter: the client is testable with a mocked HTTP layer.

---

## Why this path

### 1st-principle argument

The consent record is a legal artifact, not a UX artifact. The law (DPDP Act 2023, GDPR if applicable) requires the record to be auditable, durable, and immutable. A local Hive box is none of these. A server-side append-only table is all three.

The append-only contract is enforced at the database level, not in application code. A bug in the application cannot rewrite history. This is the difference between "the code says the ledger is append-only" and "the database says the ledger is append-only." The latter is the only one that holds.

### Anti-parallel-paths argument (motto v3 §0.1)

The Flutter cache and the server ledger are not parallel paths; the server is the truth, the cache is the speed. The Flutter app writes to the server first, then updates the cache. On read, the cache is the primary; the server is the fallback. One path, two roles.

### Anti-vendor-lock-in argument (motto v3 §0)

Option C (managed service) introduces a new vendor. Option A is owned code. Per the audit's "no new vendor without justification," Option A wins.

### Compliance posture argument

The DPDP Act 2023 (and GDPR if applicable) requires auditable consent records. The append-only Postgres table satisfies the standard pattern: INSERT-only, RLS-deny-UPDATE-and-DELETE, a trigger that raises an exception on UPDATE/DELETE attempts, an index for the "current state" query, a view for the operator's audit dashboard. The pattern is the same as Stripe's `events` table and GitHub's audit log; auditors recognize it.

### Anti-rewriting-history argument (motto v3 §0.7)

The ledger is the user's proof of consent. If the ledger is editable, the proof is not proof. The append-only contract is not a feature; it is the foundation of the entire consent model.

### Anti-staleness argument (motto v3 §0.4)

The Flutter cache can drift from the server. The "last verified at" indicator in the consent UI makes the staleness visible. A follow-up session can add a "pull from server" refresh. The v1 contract is honest about the limitation.

### Long-term 1st-principle argument

The consent ledger is the source of truth for the user's privacy decisions. The source of truth must be:
- **Durable:** survives device loss, app uninstall, account deletion (per the user's data lifecycle).
- **Auditable:** an operator or regulator can read the history.
- **Immutable:** cannot be rewritten by anyone, including the operator.

The append-only Postgres table is the smallest change that satisfies all three. The alternative (Option C, managed service) is bigger and adds vendor lock-in. The middle path (Option B, use events_unrouted) is the wrong shape for the wrong purpose.

---

## Tradeoffs

- **A new table is a new attack surface.** Mitigation: RLS denies UPDATE and DELETE; only INSERT is allowed; the service_role is the only writer. The audit log of consent events is the audit log, not the editable state.
- **The ledger grows over time.** Mitigation: a follow-up retention policy deletes rows older than the regulatory period (typically 7 years for financial records; the exact period is a regulatory question). The deletion is done via a server-side job, NOT by the application.
- **The Flutter cache can drift from the server.** Mitigation: the consent UI shows the "last verified at" timestamp; a follow-up session adds a refresh button.
- **The append-only enforcement requires a Postgres trigger, not just RLS.** RLS only applies to non-service-role roles; the service_role bypasses RLS. The trigger raises an exception on UPDATE and DELETE for ALL roles, including service_role. This is the standard pattern for append-only tables.
- **The schema does not include a "revocation" flag.** A revocation is a new row with `granted=false`; the "current" row for a (user, consent_type) is the most recent. The schema is unchanged.

---

## Assumptions

- **The DPDP Act 2023 retention period is 7 years for financial records.** The exact period for consent records is a regulatory question; v1 uses 7 years. The follow-up retention policy uses this value.
- **The Flutter app's consent state is a cache, not the source of truth.** The user can grant or revoke consent in the UI; the Flutter app calls POST /consent; the server records the event; the Flutter cache is updated.
- **The service_role is the only writer.** The RLS policies deny INSERT for anon and authenticated. The application (via the service_role) is the only writer. The user cannot write to the ledger directly.
- **The trigger is the right enforcement mechanism.** RLS bypasses for the service_role; the trigger does not. The trigger is the append-only enforcement.

---

## Risks

- **The trigger is bypassed by a future database admin who has SUPERUSER.** Mitigation: the append-only contract is a security policy; a future operator with SUPERUSER can disable the trigger. The audit log records the disable event. The risk is acceptable; the alternative (no SUPERUSER) is operationally infeasible.
- **A Flutter cache miss shows stale data.** Mitigation: the "last verified at" indicator; a follow-up refresh button.
- **The retention policy is not implemented in this commit.** Mitigation: the schema has a `created_at` column, so the retention policy is a future DELETE job; the schema does not need to change.
- **The Flutter app's existing `consent_ledger.dart` (the Hive box) is still the primary read path.** The cache + server pattern is a follow-up session; v1 ships the contract and the cache invalidation is documented.

---

## Validation plan

- **SQL (T1):** the migration is testable via `pg_query` or a local Postgres. The trigger is testable: an UPDATE attempt raises an exception; a DELETE attempt raises an exception. The view `v_current_consent` is queryable.
- **Python (T2):** the service is testable with a mocked supabase client. The `record_consent` returns the new row's id; the `get_current_consent` returns the most recent row.
- **FastAPI (T2):** the endpoint is testable with a mocked service. The `POST /consent` returns 201 + the new row's id; the `GET /consent/current` returns the current state.
- **Flutter (T2):** the client is testable with a mocked HTTP layer. The `recordConsent` calls POST /consent and updates the cache. The `getCurrentConsent` reads the cache; on miss, falls back to GET /consent/current.
- **Real-device test (T0, in the launch playbook's Step 8):** the user grants consent in the Flutter app; the consent event appears in the operator's `v_current_consent` view; the consent UI shows the "last verified at" timestamp. The user revokes consent; the new row has `granted=false`; the UI shows the revocation.

---

## Rollback or migration path

The append-only contract is a security policy. If the contract is wrong (e.g. a future regulatory requirement requires the user to be able to delete their consent history), the rollback is:

1. Disable the trigger (`alter table public.consent_ledger disable trigger ...`).
2. Run a DELETE job to remove the user's history.
3. Re-enable the trigger.

The schema does not change; the policy does. The policy change is logged.

If a future audit requires server-managed keys (the Security Phase 1 rollback path), the consent ledger is unaffected: the keys are for local storage; the consent ledger is server-side.

---

## What would cause this decision to be revisited

- **The regulatory retention period changes.** The schema has `created_at`; the retention job is a follow-up. The schema does not change.
- **The DPDP Act 2023 requires data residency in India.** CoverWise's Supabase project is in a US region (per the current setup). A follow-up migration moves the data to a Supabase region in India. The schema does not change.
- **A future audit requires the consent UI to show the policy text that was consented to.** The schema has `policy_version`; the policy text is in a separate table. A follow-up migration adds the `consent_policy_text` table; the consent_ledger references it.
- **A future operator wants to add consent types (e.g. "biometric data" or "third-party data sharing").** The schema's `consent_type` is text; new types are added without schema change. The Flutter app adds the new UI.
- **The Flutter cache drift becomes a real problem.** A follow-up session adds a "pull from server" refresh on the consent UI.

---

## Links

- **Affected files (this commit):**
  - `supabase/migrations/2026_07_19_consent_ledger.sql` (new, the table + view + trigger)
  - `src/models/consent.py` (new, the typed models)
  - `src/services/consent_ledger_service.py` (new, the typed access)
  - `src/api/consent.py` (new, the FastAPI endpoint)
  - `mobile/lib/services/server_consent_service.dart` (new, the Flutter client)
  - `tests/test_consent_ledger_service.py` (new, the Python tests)
  - `mobile/test/server_consent_service_test.dart` (new, the Flutter tests)
  - `docs/decisions/ADR-2026-07-19-07-...md` (this file)
  - `docs/decisions/README.md` (updated index)
  - `docs/architecture/coverwise_canonical_architecture.md` (updated; the consent ledger is the 4th audit-log artifact)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (updated; the launch playbook's apply-migrations step is now 8 migrations)
  - `docs/planning/coverwise_audit_task_classification_2026-07-18.md` (updated; Bucket 5 #24 marked shipped)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-06](./ADR-2026-07-19-06-security-phase-1-principal-scoped-encrypted-local-storage.md) (the principal-scoped key that encrypts the local cache)
  - [ADR-2026-07-19-01](./ADR-2026-07-19-01-durable-work-queue-supabase-outbox.md) (the outbox pattern; the consent ledger uses the same append-only + RLS-deny-UPDATE-and-DELETE pattern)
  - `docs/audits/coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` (the source audit, Phase 2)
- **Related code:**
  - `mobile/lib/services/consent_ledger.dart` (the existing local Hive box; the follow-up session migrates the read path to the server-first + cache-fallback pattern)
  - `src/app/main.py` (the FastAPI app; the new `consent_router` is added to the includes)
- **Motto v3 alignment:** §0.1 (no parallel paths; the server is the truth, the cache is the speed), §0.4 (acceptance contract; the append-only enforcement is the contract), §0.5 (evidence tiers; T1 SQL + T2 service + T0 real-device), §0.7 (AI output boundary; the trigger is a standard Postgres primitive, not an invented one), §0.10 (observability is delivery; the `v_current_consent` view is the operator's read path), §0.12 (this document).
