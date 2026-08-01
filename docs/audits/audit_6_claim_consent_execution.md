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

---

## 2. Claim Flow — Launch Blockers

### P0.1: Product tells users claims are device-only while automatically syncing them

**Status:** ❌ OPEN — requires product decision
**Files:** `main.dart` (startup sync calls), `claims_sync_service.dart`

The claim wizard says it saves to an on-device claim log. It repeatedly says photos and claim information stay on the device. The tracking screen says the claim log is private and stored on the device.

That is not the implemented behavior. `main.dart` automatically starts claims synchronization at app startup, when connectivity returns, and after authentication events.

**Decision required — choose one honest contract:**

| Option | Description | Recommendation |
|--------|-------------|----------------|
| **A: Local-only** | No backend sync. Encrypted principal-scoped storage. Clear device-only copy. | ✅ Best for launch |
| **B: Optional backup** | Explicit user opt-in. Sync status per claim. Separate photo handling. Cross-device conflict protocol. | Later iteration |

### P0.2: Revised sync cannot create claims against current backend

**Status:** ❌ OPEN
**Files:** `claims_sync_service.dart`, `src/api/claim.py`

The mobile service sends `'id': claim.id` but `CreateClaimRequest` does not define `id` and uses `model_config = {"extra": "forbid"}`. The backend will reject with HTTP 422.

### P0.3: Sync service corrupts insurer's claim reference number

**Status:** ❌ OPEN — remove immediately
**Files:** `claims_sync_service.dart`

When the server returns a different ID, the mobile code stores it as `referenceNumber: remoteId`. `referenceNumber` is user-visible insurer data (e.g., `CLM-2026-00421`). It must never be repurposed as an internal database identifier.

### P0.4: Attempted remote-ID workaround does not prevent repeated pushes

**Status:** ❌ OPEN
**Files:** `claims_sync_service.dart`

`fullSync()` checks `serverIds.contains(claim.id)` but the local ID is never changed to the server ID. The claim is pushed again every sync cycle.

### P0.5: Claimed principal-epoch protection does nothing

**Status:** ❌ OPEN
**Files:** `claims_sync_service.dart`, `main.dart`

`fullSync()` accepts an `epoch` parameter that is never read. `main.dart` calls `fullSync()` without providing one. Account A's request can finish after Account B becomes active.

### P0.6: Local edits are not synchronized and can be overwritten

**Status:** ❌ OPEN
**Files:** `claims_sync_service.dart`

The tracking screen updates status through `AppStateRepository` but never sends PATCH requests. The sync service pulls server records first and treats them as authoritative. User edits are silently lost on next sync.

### P0.7: Deleting a claim locally does not delete it remotely

**Status:** ❌ OPEN
**Files:** `claims_tracking_screen.dart`, `claims_sync_service.dart`

`AppStateRepository.deleteClaimRecord()` does not call `DELETE /claims/{claim_id}`. The backend record remains and can recreate the deleted claim locally.

### P0.8: Flutter and backend status values are incompatible

**Status:** ❌ OPEN
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

**Status:** ❌ OPEN
**Files:** `claims_sync_service.dart`

Backend defaults to 50 records per request. The mobile service never uses `limit` or `offset`. Users with >50 records get incomplete snapshots.

### P0.10: Invalid server response treated as authoritative emptiness

**Status:** ❌ OPEN
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

### P0.17: Revoked processing consent is automatically re-granted ✅ FIXED

**Status:** ✅ FIXED
**Files:** `documents_screen.dart`

`_ensureConsent()` now checks `ledger.hasConsent(ConsentPurpose.documentProcessing)` and only proceeds if active. If revoked, shows dialog again.

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

Current implementation contradicts this:
- Claims sync automatically (P0.1)
- Policy upload is server processing, not optional sync
- Source documents and claim photos are plaintext outside principal encryption
- Analytics includes stable install/session identifiers (pseudonymous, not anonymous)

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
| **P0.17** Auto-regrant | `_ensureConsent()` checks ledger before upload | `documents_screen.dart` | Existing consent tests |
| **P0.18** Unawaited writes | Both dialog buttons `await` consent write | `lead_capture_dialog.dart` | Existing consent tests |
| **P0.19** Marketing conflation | Removed auto-grant of `marketingEmails` | `lead_capture_dialog.dart` | Existing consent tests |
| **P0.21** Onboarding blocks on failure | Required writes throw; `_complete()` catches | `onboarding_screen.dart` | 9 new tests in `onboarding_consent_test.dart` |
| **P0.22** Terms separate | New `termsOfService` enum; both recorded | `consent_ledger.dart`, `onboarding_screen.dart`, `settings_screen.dart` | 9 new tests in `onboarding_consent_test.dart` |

---

## 9. What Remains Open

### Critical P0s (Launch-blocking)

| ID | Finding | Blocker |
|----|---------|---------|
| P0.1 | Claims auto-sync contradicts "device-only" copy | Product decision required |
| P0.2-P0.10 | Claim model/sync redesign | Requires backend schema change |
| P0.11-P0.12 | Claim photos plaintext + orphans | Requires encrypted blob storage |
| P0.14-P0.16 | Backend schema lacks idempotency/ownership | Requires backend migration |
| P0.23-P0.24 | Consent sync not convergence | Requires immutable event protocol |

### Blocked on External Dependencies

| Finding | Blocker |
|---------|---------|
| P0.11, 4-P0.4 | Encrypted blob storage (Hive 2.x limitation) |
| P0.14-P0.16 | Backend schema migration |
| P0.1 | Product decision on local-only vs optional backup |

---

## 10. Required Implementation Order

1. **Product decision:** Claims local-only vs optional backup (P0.1)
2. **Disable claim sync:** Remove automatic `_syncClaims()` calls
3. **Fix consent flow:** Remove auto-regrant, separate marketing, await writes (P0.17-P0.22 ✅ DONE)
4. **Replace claim model:** Add localId, remoteId, revisions, syncState, tombstones
5. **Replace photo storage:** Principal-scoped encrypted attachment directory
6. **Redesign backend schema:** Idempotency, revisions, tombstones, account deletion
7. **Rebuild consent sync:** Immutable event protocol, server authority

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
