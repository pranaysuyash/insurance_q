# Audit 6: Claim Sync, Consent Flow, and Execution Integrity

**Date:** 2026-07-31
**Scope:** Claim synchronization protocol, claim photo storage, document-consent flow, backend schema, and privacy-copy accuracy.
**Baseline:** Produced from ChatGPT Pro relational audit sessions covering models, repositories, capabilities, server consent, claim execution, and consent execution.
**Status:** Living document — append-only updates per motto §0.3.

---

## 1. Verdict

**Do not ship claim synchronization in its current form.** The safest launch decision is to keep the claim log explicitly local-only until the local model, backend schema, attachment storage, and sync protocol are redesigned together.

**Do not ship the current document-consent flow either.** It can silently recreate consent after revocation and automatically treats contact entry as marketing consent.

Tests can come later. Writing tests around these contracts now would harden the wrong architecture.

> **Status pointer (2026-08-03):** The consent-flow findings P0.17-P0.22 are resolved, and P0.17 now includes exact-version currency enforcement. The claim-flow verdict stands: claims are **local-only** for launch (P0.1 resolved — see Update Log), and P0.2-P0.10 remain prerequisites for any future sync re-enable. Do not read this verdict without the Update Log.

---

## 2. Claim Flow — Launch Blockers

### P0.1: Product tells users claims are device-only while automatically syncing them ✅ FIXED (2026-08-03)

**Status:** ✅ FIXED — Option A (local-only) chosen for launch
**Files:** `mobile/lib/sync/reconciliation_coordinator.dart`, `mobile/lib/services/claims_sync_service.dart`, `docs/decisions/ADR-2026-07-24-02-personal-claim-log-boundary.md`

The claim wizard says it saves to an on-device claim log. It repeatedly says photos and claim information stay on the device. The tracking screen says the claim log is private and stored on the device.

That was not the implemented behavior. `main.dart` automatically started claims synchronization at app startup, when connectivity returns, and after authentication events.

**Decision recorded (2026-08-03, ADR-2026-07-24-02 update log):** Option **A — local-only claim log** for launch.

**Implementation:**
- `ReconciliationCoordinator.scheduleReconciliation()` no longer calls `_syncClaims()`; the debounced reconciliation (startup, connectivity restore, auth events) now retries **document uploads only**.
- The dead `_syncClaims()` method was removed entirely.
- `ClaimsSyncService` is marked DORMANT for launch; `setClaimsSyncEpoch`/`invalidateClaimsSync` remain as defensive guards during principal transitions.
- No claim data is sent to `/claims` by the app. Backend `/claims` remains experimental, not a launch dependency.
- Contract test added in `reconciliation_coordinator_test.dart`: `scheduleReconciliation` must not contain `_syncClaims`/`.fullSync(` and must only retry uploads.

**Future re-enable prerequisites (Option B):** explicit user opt-in + redesigned contract (idempotency keys, tombstones, revisions, pagination, wire-status mapping) + attachment ID protocol. See P0.2-P0.10.

### P0.2: Revised sync cannot create claims against current backend

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1); must fix before any re-enable
**Files:** `claims_sync_service.dart`, `src/api/claim.py`

The mobile service sends `'id': claim.id` but `CreateClaimRequest` does not define `id` and uses `model_config = {"extra": "forbid"}`. The backend will reject with HTTP 422.

### P0.3: Sync service corrupts insurer's claim reference number

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1)
**Files:** `claims_sync_service.dart`

When the server returns a different ID, the mobile code stores it as `referenceNumber: remoteId`. `referenceNumber` is user-visible insurer data (e.g., `CLM-2026-00421`). It must never be repurposed as an internal database identifier.

### P0.4: Attempted remote-ID workaround does not prevent repeated pushes

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1)
**Files:** `claims_sync_service.dart`

`fullSync()` checks `serverIds.contains(claim.id)` but the local ID is never changed to the server ID. The claim is pushed again every sync cycle.

### P0.5: Claimed principal-epoch protection does nothing

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1); epoch wiring exists in `ReconciliationCoordinator`/`ClaimsSyncService` and must be enforced at re-enable
**Files:** `claims_sync_service.dart`, `main.dart`

`fullSync()` accepts an `epoch` parameter that is never read. `main.dart` calls `fullSync()` without providing one. Account A's request can finish after Account B becomes active.

### P0.6: Local edits are not synchronized and can be overwritten

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1)
**Files:** `claims_sync_service.dart`

The tracking screen updates status through `AppStateRepository` but never sends PATCH requests. The sync service pulls server records first and treats them as authoritative. User edits are silently lost on next sync.

### P0.7: Deleting a claim locally does not delete it remotely

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1)
**Files:** `claims_tracking_screen.dart`, `claims_sync_service.dart`

`AppStateRepository.deleteClaimRecord()` does not call `DELETE /claims/{claim_id}`. The backend record remains and can recreate the deleted claim locally.

### P0.8: Flutter and backend status values are incompatible

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1); wire mapping below is the required pattern for re-enable
**Files:** `claim_record.dart`

Flutter serializes `inReview` (camelCase). Backend expects `in_review` (snake_case). A server claim in review appears as filed in the app.

**Required fix — wire mapping:**
```dart
extension ClaimStatusWire on ClaimStatus {
  String get wireValue => switch (this) {
    ClaimStatus.filed => 'filed',
    ClaimStatus.inReview => 'in_review',
    ClaimStatus.approved => 'approved',
    ClaimStatus.rejected => 'rejected',
    ClaimStatus.paid => 'paid',
  };
}
```

### P0.9: Pull and index operations are not paginated

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1)
**Files:** `claims_sync_service.dart`

Backend defaults to 50 records per request. The mobile service never uses `limit` or `offset`. Users with >50 records get incomplete snapshots.

### P0.10: Invalid server response treated as authoritative emptiness

**Status:** ⏸️ DEFERRED — sync disabled for launch (P0.1)
**Files:** `claims_sync_service.dart`

A malformed 200 response from `_fetchServerIds()` is treated as an empty server. Should return invalid/unavailable and block mutations.

---

## 3. Claim Photo Storage — Launch Blockers

### P0.11: Claim photos are plaintext and not principal-scoped

**Status:** ❌ OPEN — blocked on encrypted blob storage
**Files:** `claim_wizard.dart`

Photos are copied into `<Application Documents>/claim_photos/` without encryption, principal scoping, or backup exclusion.

### P0.12: Cancelling or editing the wizard leaves orphan photos

**Status:** ❌ OPEN
**Files:** `claim_wizard.dart`

Photos are copied immediately on selection. Removing from the wizard only removes the path from `_photoPaths`. The file remains on disk.

**Required fix:** Use temporary staging area; move to permanent store only on commit; delete on cancel.

### P0.13: Raw paths remain in backend and database contracts

**Status:** ⚠️ PARTIAL — mobile no longer sends `photo_paths`, but server schema still accepts them
**Files:** Backend API models, database schema

Remove `photo_paths` from server contract. Use opaque server IDs: `{"attachment_ids": ["att_..."]}`.

---

## 4. Backend Schema Problems

### P0.14: No idempotency contract

**Status:** ❌ OPEN — backend change required
**Files:** `src/api/claim.py`, database schema

The schema lacks `client_claim_id`, `client_mutation_id`, unique owner-scoped constraints, revision numbers, and tombstone state.

### P0.15: Schema still describes agent-filed claims

**Status:** ❌ OPEN — product boundary drift
**Files:** Database schema, API models

The product says "self-recorded personal log." The database still includes `initiated_by = user | agent` and `agent_id`. Remove unless there's an approved ADR requiring them.

### P0.16: Account deletion not protected by schema ownership

**Status:** ❌ OPEN
**Files:** Database schema

`owner_id` has no foreign key or cascade. Claim records survive auth-user deletion unless manually removed.

---

## 5. Consent Flow — Launch Blockers

### P0.17: Revoked processing consent is automatically re-granted ✅ FIXED (with exact-version currency, 2026-08-03)

**Status:** ✅ FIXED
**Files:** `documents_screen.dart`, `document_service.dart`, `consent_ledger.dart`

`_ensureConsent()` now checks `ledger.hasConsent(ConsentPurpose.documentProcessing)` and only proceeds if active. If revoked, shows dialog again. The auto-grant-from-stored-version branch was removed entirely.

**Version-currency enforcement (2026-08-03):**
- New `ConsentLedger.hasConsentForVersion(purpose, version)` — active consent **and exact-version** check. A grant recorded under an old policy version no longer silently authorizes uploads under a new one.
- `DocumentsScreen._ensureConsent()` fast path now uses `hasConsentForVersion(ConsentPurpose.documentProcessing, AppConfig.privacyPolicyVersion)` — stale grants (any version mismatch) re-prompt the authorization dialog.
- `DocumentService._hasDocumentProcessingConsent()` is version-aware (defense in depth at the data-egress boundary): the upload gate, the retry gate, and `_retryOnePendingUpload` all require current-version consent.
- Retry payloads send the current `AppConfig.privacyPolicyVersion` rather than a possibly-stale stored value.
- Tests: stale-version re-prompt + re-grant-then-fast-path in `consent_upload_flow_test.dart`; `hasConsentForVersion` unit tests in `consent_ledger_test.dart`; document-service and sync-integration tests updated to record current-version consent.

### P0.18: Consent writes in the dialog are unawaited ✅ FIXED

**Status:** ✅ FIXED
**Files:** `lead_capture_dialog.dart`

Both "Skip" and "Continue" buttons now `await ledger.recordConsent(...)` before returning success.

### P0.19: Providing contact details silently grants marketing consent ✅ FIXED

**Status:** ✅ FIXED
**Files:** `lead_capture_dialog.dart`

No auto-grant of `ConsentPurpose.marketingEmails`. Comment documents: "Entering an email is not marketing consent."

### P0.20: Privacy policy acceptance and processing authorization conflated

**Status:** ✅ FIXED (doc-level) / ⚠️ OPEN (UI-level)
**Files:** `consent_ledger.dart`

The `privacyPolicy` purpose now has documentation explaining the distinction from `documentProcessing` (§5 of consent_ledger.dart). Full UI separation requires showing them as separate checkboxes on the last onboarding page — the current single checkbox covers both.

### P0.21: Onboarding completes when required consent storage fails ✅ FIXED

**Status:** ✅ FIXED
**Files:** `onboarding_screen.dart`

`_recordConsentState()` now throws on failure for required writes (privacyPolicy, termsOfService). `_complete()` catches and shows SnackBar. Onboarding does NOT set `onboarding_complete` on failure.

### P0.22: Terms acceptance is not recorded separately ✅ FIXED

**Status:** ✅ FIXED
**Files:** `consent_ledger.dart`, `onboarding_screen.dart`, `settings_screen.dart`

New `ConsentPurpose.termsOfService` enum value. Onboarding records both `privacyPolicy` and `termsOfService`. Settings screen displays both with separate labels and icons.

### P0.23: Consent synchronization is not convergence ❌ OPEN

**Status:** ❌ OPEN
**Files:** `consent_sync_service.dart`

`ConsentSyncService` reads only the latest local record per purpose and pushes blindly to the server. A stale device can overwrite a newer decision made on another device.

### P0.24: Offline consent history is collapsed ❌ OPEN

**Status:** ❌ OPEN
**Files:** `consent_sync_service.dart`

The signature contains only `type : version : granted`. An offline grant→revoke→grant sequence loses the revocation event. Server never receives it.

**Required fix:** Sync immutable consent events by event ID, not just latest boolean.

---

## 6. Privacy Copy Inaccuracies

The privacy screen says:
- Claims and records are local
- The local cache is protected
- Analytics are anonymous
- Policies are synced when the user "chooses to sync"

**Status 2026-08-03:**
- ✅ Claims are now actually local-only (P0.1 fixed) — the "claims are local" copy is now accurate.
- ⚠️ Policy upload is server processing, not optional sync — copy must describe this.
- ⚠️ Source documents and claim photos were plaintext outside principal encryption — addressed by CW-P0-002 (principal-scoped encrypted attachment store, AES-GCM at rest, legacy migrations); copy should be re-verified against the implemented store.
- ⚠️ Analytics includes stable install/session identifiers (pseudonymous, not anonymous) — copy must say "pseudonymous".

**Copy must describe actual architecture, not intended architecture.**

---

## 7. P1 Findings (Deferred)

### P1.1: Status-history timestamps use local time
**Status:** ❌ OPEN
**Files:** `claim_record.dart`
`StatusUpdate` uses `DateTime.now()` instead of `DateTime.now().toUtc()`. Distributed conflict handling is clearer with UTC.

### P1.2: Nullable fields cannot be explicitly cleared
**Status:** ❌ OPEN
**Files:** `claim_record.dart`
`copyWith()` uses `referenceNumber ?? this.referenceNumber` — no way to intentionally clear a value. Use `Optional<String?>` or dedicated methods.

### P1.3: Attachment paths embedded in domain model
**Status:** ❌ OPEN
**Files:** `claim_record.dart`
`List<String> photoPaths` couples the claim domain to one device's filesystem. Use opaque attachment identities.

### P1.4: Document references not cleared by deletion
**Status:** ❌ OPEN
**Files:** `app_state_repository.dart`, `document_service.dart`
`clearDocumentReferences()` exists but `deleteDocument()` does not call it. Stale selected/last-uploaded document references persist.

### P1.5: Phantom resolved_gaps store
**Status:** ❌ OPEN
**Files:** `app_state_repository.dart`, `hive_workspace_service.dart`
`AppStateRepository` stores resolved gaps inside `app_state_box[resolved_gaps]`. `HiveWorkspaceService` separately opens and migrates a box named `resolved_gaps`. One canonical storage registry needed.

### P1.6: Malformed consent row invalidates whole response
**Status:** ❌ OPEN
**Files:** `server_consent_service.dart`
One malformed row in `getCurrentConsentAll()` throws during `.map().toList()`. The outer catch turns the entire response into `null`. Per-record quarantine needed for history; strict whole-response rejection defensible for current consent.

### P1.7: History limits rely on debug-only assertion
**Status:** ❌ OPEN
**Files:** `server_consent_service.dart`
`assert(limit > 0)` disappears in release builds. Use runtime validation with upper bound.

### P1.8: NewsletterService Hive box absent from registry
**Status:** ❌ OPEN
**Files:** `newsletter_service.dart`
The service uses a Hive box named `newsletter` absent from the workspace-opening registry. Its `_box` getter catches the failure and returns null. Null-aware writes do nothing while `subscribe()` returns true. Rename to `NewsletterInterestDraft` until a real server subscription exists.

---

## 8. What Was Fixed (This Session)

| Finding | Fix | Files | Tests |
|---------|-----|-------|-------|
| **P0.17** Auto-regrant | `_ensureConsent()` checks ledger before upload; **version-currency added** (`hasConsentForVersion`, version-aware service gate, stale-version re-prompt) | `documents_screen.dart`, `document_service.dart`, `consent_ledger.dart` | `consent_upload_flow_test.dart` (stale re-prompt + re-grant), `consent_ledger_test.dart` (unit), `document_service_delete_test.dart`, `document_service_anonymous_user_test.dart`, `sync_integration_test.dart` — **90/90 pass** |
| **P0.1** Claims auto-sync | Local-only for launch; `_syncClaims()` removed from `scheduleReconciliation()`; service marked DORMANT; ADR-2026-07-24-02 decision recorded | `reconciliation_coordinator.dart`, `claims_sync_service.dart` | Contract test in `reconciliation_coordinator_test.dart` (43/43 pass) |
| **P0.18** Unawaited writes | Both dialog buttons `await` consent write | `lead_capture_dialog.dart` | Existing consent tests |
| **P0.19** Marketing conflation | Removed auto-grant of `marketingEmails` | `lead_capture_dialog.dart` | Existing consent tests |
| **P0.21** Onboarding blocks on failure | Required writes throw; `_complete()` catches | `onboarding_screen.dart` | 9 new tests in `onboarding_consent_test.dart` |
| **P0.22** Terms separate | New `termsOfService` enum; both recorded | `consent_ledger.dart`, `onboarding_screen.dart`, `settings_screen.dart` | 9 new tests in `onboarding_consent_test.dart` |

---

## 9. What Remains Open

### Critical P0s (Launch-blocking)

| ID | Finding | Status |
|----|---------|--------|
| P0.1 | Claims auto-sync contradicts "device-only" copy | ✅ FIXED — local-only for launch (2026-08-03) |
| P0.2-P0.10 | Claim model/sync redesign | ⏸️ Deferred — sync disabled; must fix before any re-enable |
| P0.11-P0.12 | Claim photos plaintext + orphans | ⚠️ In progress — principal-scoped encrypted attachment store landed (CW-P0-002); claim-photo migration/validation pending |
| P0.14-P0.16 | Backend schema lacks idempotency/ownership | ⏸️ Deferred with sync; requires backend migration |
| P0.23-P0.24 | Consent sync not convergence | ❌ OPEN — requires immutable event protocol |

### Blocked on External Dependencies

| Finding | Blocker |
|---------|---------|
| P0.11, 4-P0.4 | Encrypted blob storage (Hive 2.x limitation) |
| P0.14-P0.16 | Backend schema migration |
| P0.1 | Product decision on local-only vs optional backup |

---

## 10. Required Implementation Order

1. **Product decision:** Claims local-only vs optional backup (P0.1) ✅ **DECIDED 2026-08-03 — Option A local-only**
2. **Disable claim sync:** Remove automatic `_syncClaims()` calls ✅ **DONE** (reconciliation retries uploads only; service DORMANT)
3. **Fix consent flow:** Remove auto-regrant, separate marketing, await writes, **enforce exact-version currency** (P0.17-P0.22 ✅ DONE)
4. **Replace claim model:** Add localId, remoteId, revisions, syncState, tombstones (⏸️ deferred with sync)
5. **Replace photo storage:** Principal-scoped encrypted attachment directory (landed for documents via CW-P0-002; claim-photo migration pending)
6. **Redesign backend schema:** Idempotency, revisions, tombstones, account deletion (⏸️ deferred with sync)
7. **Rebuild consent sync:** Immutable event protocol, server authority (❌ P0.23-P0.24 remaining)

---

## 11. Next Audit Batch

The next precise batch should be:
- `mobile/lib/screens/consent_activity_screen.dart`
- `mobile/lib/services/contact_service.dart`
- Settings "Clear local data" and account-delete implementation
- `src/api/user.py`
- Backend account-deletion coordinator/service
- `mobile/android/app/src/main/AndroidManifest.xml`
- Android backup/data-extraction XML files
- `mobile/ios/Runner/Info.plist`
- iOS entitlements

---

## 12. Test Matrix (After Contract Redesign)

| Test | Priority |
|------|----------|
| Claim create idempotency | P0 |
| Local edit followed by pull | P0 |
| Local delete followed by pull | P0 |
| Account switch during claim sync | P0 |
| Claim status wire-value compatibility | P0 |
| Photo cancellation and orphan cleanup | P0 |
| Photo deletion path containment | P0 |
| Consent revoke followed by upload | P0 |
| Policy-version change followed by upload | P0 |
| Offline grant→revoke→re-grant sync | P0 |
| Marketing opt-in independence | P0 |
| Required onboarding acceptance persistence failure | P0 |

---

Created 2026-07-31 per motto §0.3 ("if it was worth saying, it is worth documenting"). Original findings from ChatGPT Pro relational audit sessions preserved; status updates appended as fixes land. Cross-reference: [session cross-check report](session_2026_07_31_audit_5_6_comprehensive_crosscheck.md).

---

## Update Log

| Date | Entry | Trigger |
|------|-------|---------|
| 2026-08-03 | **P0.1 resolved (Option A local-only).** Claims sync disabled for launch: `_syncClaims()` removed from `scheduleReconciliation()`, `ClaimsSyncService` marked DORMANT, decision recorded in ADR-2026-07-24-02. P0.2-P0.10 reclassified ⏸️ deferred (must pass before any sync re-enable). **P0.17 hardened with exact-version currency:** `hasConsentForVersion()` on the ledger, version-aware `DocumentService` gate + retry payload, stale-version re-prompt in `DocumentsScreen`. Validation: 90/90 tests pass across the consent/document-service/sync batch; `flutter analyze` clean. | Operator direction: audit backlog execution; motto §0.3 durable documentation. |
| 2026-08-03 | **Device-only claim copy verified accurate after sync disable.** Confirmed `ClaimsSyncService.fullSync()` has **zero call sites** (only `invalidateClaimsSync()` remains); a contract test asserts `.fullSync(` absent from the reconciliation coordinator. Copy audit: claim tracking empty state ("private, on-device record… CoverWise does not submit claims or receive insurer updates"), claim log header ("personal record stored on this device… update statuses yourself"), wizard ("records information on this device only… does not file, submit, or update"), photo copy ("stored on-device"), description copy ("stays on your device"), and claims assistant ("does not file or manage the claim") all match the local-only implementation. `privacy_policy.md` (authoritative) contains zero claim references — nothing to correct. **Two privacy-screen inaccuracies fixed** (independent of claims): (1) "Policy documents" said "when you choose to sync a policy" — upload is immediate server processing, rewording to "stored on your device and sent to CoverWise… if you are offline, the file stays on your device until the upload retries"; (2) Analytics copy said "anonymous event counts" — events carry install/session IDs, rewording to "random install identifier, not your name or email". **Onboarding copy fixed for consistency** — same analytics wording ("Anonymous usage stats" → "Usage stats… random install identifier, not your name or email. Policy content is not included"). **Pre-existing test failures noted (not caused by copy change, verified by stash-run):** `onboarding_analytics_test.dart` "accept terms checkbox enables the add policy button" fails with "Too many elements" on `find.byType(Checkbox)` (multiple checkboxes on last page); `onboarding_consent_flow_test.dart` has 2 failures incl. a teardown hang. These predate the copy fix and are tracked separately. | Operator direction: verify copy accuracy after sync disable; motto §0.3. |
| 2026-08-04 | **Workspace path anchored to Hive homePath — CWD-relative pollution and lock collisions eliminated.** Root cause: `HiveWorkspaceService._workspacePath()` returned a **CWD-relative** `workspaces/<principal>` path. Hive 2.2.3 uses an explicit `path:` param verbatim (`_manager.open(name, path ?? homePath, …)`), so relative paths resolve against the process working directory. Impact: (a) in tests (CWD=`mobile/`) every workspace opened by `openForActivePrincipal()`/`openTestWorkspace()` wrote under `mobile/workspaces/` (~7.7 MB of Hive boxes/locks) and two test isolates sharing a principal collided on the same `.lock` file → `FileSystemException: lock failed`; (b) in production `Hive.initFlutter()` sets homePath to the app documents directory but it was bypassed — on iOS/Android (CWD=`/`) the path resolves to `/workspaces/...`, which is unwritable (latent real-device crash, masked because no release binary has run). **Fix:** `_workspacePath()` now anchors to Hive's home path (set by `Hive.init()`/`Hive.initFlutter()`) via a typed private helper `_hiveHomePath`. Because hive 2.2.3 exposes `homePath` only on `HiveImpl` (not the exported `HiveInterface`), the helper uses a single isolated dynamic access and degrades to the relative-path fallback if the field shape ever changes on upgrade. Workspace paths are now `<appDocs>/workspaces/<principal>` in production and `<testTempDir>/workspaces/<principal>` in tests — each test isolate isolated, nothing written into the repo. **Test hardening:** `encrypted_attachment_store_test.dart` legacy-file tests previously relied on the polluted directory already existing; they now create the attachments directory explicitly via a `writeLegacyAttachment()` helper (clean-state correctness). **Validation:** 9 workspace-touching test files run in one process (encrypted_attachment_store, local_storage_service, document_service_delete, account_document_reconciliation, archive_restore_flow, document_library_no_hidden_query, sync_integration, migration_integrity, principal_key_service) = **103/103 pass**; `mobile/workspaces/` verified **not recreated** after the run; `flutter analyze` clean on the edited files. Note: existing installs cannot have data at the old CWD-relative location (it is unwritable on devices), so no migration is needed. | Operator direction: delete `mobile/workspaces/` pollution and confirm nothing recreates it; motto §0.3, §0.1 (single source of truth for the storage base). |
| 2026-08-04 | **P0.23 addressed: consent sync now pulls server authority before pushing local state.** `_syncAll()` calls `pullFromServer()` before iterating local consent records. This prevents a stale local grant (e.g., offline grant followed by server-side revocation on another device) from overwriting the server's current state. The pull is wrapped in a try/catch so offline startup still pushes local state as a fallback. `pullFromServer()` is idempotent and debounced via `_pullInFlight`. Validation: consent sync integration tests (4/4 pass), consent upload flow tests (71/71 pass), consent ledger tests (dedicated test file, also passes). `flutter analyze` clean. P0.24 (offline grant/revoke/re-grant collapsed) remains open — it requires immutable event IDs and an append-only event protocol, which is a future backend schema change. | Operator direction: audit backlog execution; motto §0.3. |