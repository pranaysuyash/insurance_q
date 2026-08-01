# Audit 7: Consent Activity, Contact Storage, Settings Lifecycle, Newsletter, and Lead Capture

**Date:** 2026-08-01
**Files reviewed:**
- `mobile/lib/screens/consent_activity_screen.dart`
- `mobile/lib/services/contact_service.dart`
- `mobile/lib/screens/settings_screen.dart` (clear-data, consent ledger section)
- `mobile/lib/screens/profile_screen.dart` (delete account, sign out)
- `mobile/lib/services/newsletter_service.dart`
- `mobile/lib/widgets/shared/newsletter_signup_sheet.dart`
- `mobile/lib/widgets/lead_capture_dialog.dart`
- `mobile/lib/services/consent_ledger.dart`
- `mobile/lib/services/hive_workspace_service.dart`
- `mobile/lib/services/auth_service.dart` (deleteAccount, signOut)

**Produced from:** ChatGPT Pro relational audit sessions (Audit 6 next-batch recommendation) + direct code review.
**Cross-references:** [Audit 5/6 cross-check](session_2026_07_31_audit_5_6_comprehensive_crosscheck.md), [Audit 6](audit_6_claim_consent_execution.md)

---

## Verdict

**The clear-data and sign-out flows are incomplete for a privacy-sensitive insurance app.** Clear data deletes files while Hive boxes are still open, does not sign out of Supabase, does not reset RevenueCat, and does not clear the analytics timer. Sign-out does not coordinate workspace teardown through a single path — the profile screen re-clears data that sign-out already cleared. The newsletter service silently fails on every write because its Hive box is never opened by the workspace service.

The consent activity screen and contact service are structurally sound but have defense-in-depth gaps around identity epoch validation and atomicity.

**Launch-blocking findings:** 6 P0s. **Deferred P1s:** 8.

---

## 1. Settings: Clear Data — Launch Blockers

### P0.1: Clear data deletes app documents directory while Hive boxes are still open

`_confirmClearData()` in `settings_screen.dart` executes this sequence:

```dart
// Step 1: Clear all Hive workspace boxes
await HiveWorkspaceService.clearLocalWorkspace();

// Step 3: Delete physical document files
final appDir = await getApplicationDocumentsDirectory();
if (appDir.existsSync()) {
  await appDir.delete(recursive: true);
  appDir.createSync(recursive: true);
}
```

`clearLocalWorkspace()` calls `box.clear()` on each open box — this empties the boxes but does NOT close them. The box handles remain open and registered in Hive's internal registry.

Then step 3 deletes the entire app documents directory, which includes the Hive `.hive` files on disk that the still-open box handles reference. This is a **use-after-delete** on the filesystem:

- The open box handles now reference deleted files.
- Any subsequent write to these boxes will either throw or silently create new files at the path (if the directory was recreated), but the in-memory state is from the old (deleted) files.
- Hive's internal WAL and compaction state becomes inconsistent.

**Required sequence:**
```dart
// 1. Close all Hive boxes first
await Hive.close();
// 2. Delete files
await appDir.delete(recursive: true);
appDir.createSync(recursive: true);
// 3. Reopen boxes for the fresh workspace
await HiveWorkspaceService.openForActivePrincipal(localPrincipal);
```

Or better: do NOT delete the directory. `clearLocalWorkspace()` already empties the boxes. Deleting the directory is redundant and destructive.

### P0.2: Clear data does not sign out of Supabase

`_confirmClearData()` clears local data but does NOT call `authService.signOut()`. After clearing:

- The Supabase session remains active.
- The user appears signed in with an empty workspace.
- The next automatic sync (reconciliation, claim sync, analytics flush) will re-populate the workspace from server data.
- The user believes their data is cleared but it reappears.

**Required:** Clear data must either sign out of Supabase or explicitly state that it only clears local cache (not server data). The current UI copy ("Clear local data") is ambiguous — users will expect a full wipe.

### P0.3: Clear data does not reset RevenueCat identity

Unlike `signOut()` which calls `BillingAdapter.clearAccountIdentity()`, `_confirmClearData()` does not. RevenueCat entitlements, customer identity, and purchase history persist. If the user then creates a new account, RevenueCat may associate the old entitlements with the new identity.

### P0.4: Clear data does not clear Sentry user identity

`signOut()` calls `Sentry.configureScope((scope) => scope.setUser(null))`. `_confirmClearData()` does not. Crash reports after clear-data are still attributed to the old user, which is a privacy leak for an insurance app.

### P0.5: Clear data does not cancel the analytics flush timer

`AnalyticsNotifier.resetForWorkspace()` is NOT called during clear-data (it IS called in `_clearWorkspaceData()` on sign-out, but not in `_confirmClearData()`). If a periodic flush is in-flight when the workspace is cleared:

- The flush reads from the (now-empty) analytics buffer.
- The flush sends events that may contain stale session IDs.
- The flush writes to a cleared Hive box.

**Required:** Call `AnalyticsNotifier.instance?.resetForWorkspace()` and cancel the sync timer before clearing data.

### P0.6: Clear data's consent ledger clear is redundant and potentially confusing

Step 1 (`clearLocalWorkspace`) already clears the `consent_ledger` box (it's in `boxNames`). Step 6 then calls `ConsentLedger().clear()` which clears the same box again. This is not a bug (it's idempotent) but it creates confusion about which step is authoritative. More importantly, if the box was somehow closed between steps 1 and 6, step 6 throws a `StateError` (via `_requiredBox`).

**Required:** Remove the redundant `ConsentLedger().clear()` call, or document that it's a defense-in-depth guarantee.

---

## 2. Contact Service — Findings

### P0.7: Contact data is not cleared during workspace transitions

`ContactService` stores email and phone in `AppStateStore.boxName` via keys `emailKey`, `phoneKey`, and `saveContactKey`. During a workspace transition (sign-out → sign-in as different account), `resetForPrincipal()` clears and reopens the `app_state_box`. This means contact data IS cleared during transitions.

However, `ContactService` uses static methods that access whichever box is currently open. There is no principal validation. If a read occurs during the brief window between `Hive.close()` and `openForActivePrincipal()`, the box is not open and `Hive.box()` throws a `HiveError`.

**Required:** Wrap `Hive.box()` accesses in try-catch or check `Hive.isBoxOpen()` before access, consistent with `_requiredBox` pattern in `ConsentLedger`.

### P1.1: Contact data writes are not atomic

`saveContact()` writes `saveContactKey`, `emailKey`, and `phoneKey` as three separate `box.put()` calls. A crash between them leaves inconsistent state (e.g., `saveContactKey=true` but `emailKey` is stale).

**Required:** Use `box.putAll()` for atomic multi-key writes:
```dart
await box.putAll({
  AppStateStore.saveContactKey: saveForFuture,
  if (saveForFuture && email != null) AppStateStore.emailKey: email,
  if (saveForFuture && phone != null) AppStateStore.phoneKey: phone,
});
```

### P1.2: Contact data is not cleared when user unlinks phone from profile

`profile_screen.dart` deletes the phone key directly:
```dart
await box.delete(AppStateStore.phoneNumberKey);
```

But `ContactService.clearSavedContact()` clears email, phone, AND the save-for-future flag. The profile screen's direct box access bypasses the `ContactService` abstraction, creating two code paths for the same operation.

**Required:** Route all contact modifications through `ContactService`.

### P1.3: `getSavedEmail()` and `getSavedPhone()` return `Future` but are synchronous

These methods are marked `async` but only do synchronous `box.get()` calls. The `Future` return type adds unnecessary micro-overhead and misleadingly suggests async behavior.

**Consider:** Make them synchronous (return `String?`) or document why the Future is needed for API stability.

---

## 3. Newsletter Service — Launch Blockers

### P0.8: Newsletter Hive box is never opened by the workspace service

`NewsletterService` uses a Hive box named `newsletter`. This box name is NOT in `HiveWorkspaceService.boxNames`:

```dart
static const List<String> boxNames = [
  LocalStorageService.documentsBoxName,
  AppStateStore.boxName,
  'resolved_gaps',
  'analytics_events',
  'consent_ledger',
  'qa_history',
  'field_overrides_box',
  'entitlements',
];
```

The `newsletter` box is never opened by `openForActivePrincipal()`. The `_box` getter catches the error:

```dart
Box<dynamic>? get _box {
  try {
    return Hive.box<dynamic>(_boxName);
  } catch (_) {
    return null;
  }
}
```

Every write is a silent no-op. `subscribe()` returns `true` after recording consent, but:
- The email was never persisted (write went to null box).
- The opted-in flag was never set.
- The consent ledger record IS written (ConsentLedger uses a different, opened box).
- The user sees "Subscribed!" but no data was saved.

**This is a false-completion claim.** The UI tells the user they subscribed when nothing was saved.

**Required options:**
1. **Add `newsletter` to `boxNames`** so it's opened with the workspace. This is the correct fix if newsletter state should be principal-scoped.
2. **Remove NewsletterService** until a real server subscription system exists. The current implementation is a local-only draft that lies to users.

### P0.9: Newsletter subscription records email before consent

`subscribe()` writes the email to the box BEFORE recording consent:

```dart
await _box?.put(_emailKey, email.trim().toLowerCase());
await _box?.put(_optedInKey, true);

final ledger = ConsentLedger();
if (!ledger.hasConsent(ConsentPurpose.marketingEmails)) {
  await ledger.recordConsent(...);
}
```

If the consent write fails (box unavailable, thrown error), the email is persisted but no consent record exists. The UI shows "subscribed" but there's no consent trail for the email storage.

**Required:** Record consent FIRST, then persist the email. If consent fails, do not save the email.

### P1.4: `unsubscribe()` only clears local state

If the user was previously synced to a server (future integration), `unsubscribe()` only clears local Hive data and revokes local consent. No server-side call is made. The server consent record for `marketingEmails` remains active.

**Required (when server integration exists):** Send a server-side unsubscribe request before clearing local state.

### P1.5: Newsletter signup checkbox is pre-unchecked but consent is recorded on subscribe

The `NewsletterSignupSheet` has a `_confirmed` checkbox that starts as `false`. The subscribe button is disabled until checked. This is correct UX. However, the consent is recorded inside `NewsletterService.subscribe()`, which is called AFTER the user clicks "Subscribe". The checkbox text says "I agree to receive emails" — this IS explicit marketing consent, which is correct per Audit 6 P0.19.

**Status:** This is correctly implemented. No finding.

---

## 4. Lead Capture Dialog — Findings

### P0.10: Consent write in dialog is not protected by try-catch

`LeadCaptureDialog` records processing consent:

```dart
final ledger = ConsentLedger();
await ledger.recordConsent(
  purpose: ConsentPurpose.documentProcessing,
  version: AppConfig.privacyPolicyVersion,
  granted: true,
);
```

If `recordConsent` throws (e.g., `_requiredBox` throws `StateError` when the Hive box is not open), the dialog crashes with an unhandled exception. The user sees a red error screen instead of a graceful error message.

**Required:** Wrap in try-catch:
```dart
try {
  await ledger.recordConsent(...);
} catch (e) {
  // Show error and do NOT return success
  if (mounted) {
    setState(() => _consentError = 'Failed to save consent. Please try again.');
  }
  return;
}
```

### P1.6: Contact details are returned but not saved by the dialog

The dialog returns `{ 'email': ..., 'phone': ..., 'save': ... }` in the result map. The caller (`documents_screen.dart`) must separately call `ContactService.saveContact()`. If any caller forgets, the contact details are silently lost.

**Required:** Either save contact details inside the dialog when `save: true`, or document the contract clearly.

### P1.7: Dialog does not show which privacy policy version the user is consenting to

The checkbox says "I agree to policy processing" and links to the privacy policy, but doesn't display the version number. If the policy changes, users re-consenting don't know they're agreeing to a different version.

**Required:** Show "Policy version X.Y.Z" near the checkbox.

---

## 5. Consent Activity Screen — Findings

### P1.8: No identity epoch guard after async server load

`_load()` fetches consent history from the server. The fetch is async and can take seconds. If the user signs out and signs in as a different account during the fetch, the returned data belongs to the old account but is displayed under the new account.

**Required:** Capture the identity epoch before the fetch, verify it after the fetch completes:
```dart
final epoch = ref.read(identityEpochProvider);
final result = await _service.getConsentHistory();
if (!mounted) return;
// Verify epoch hasn't changed
```

### P1.9: Hardcoded string matching for consent types

`_ConsentPresentation.from()` switches on raw strings:
```dart
return switch (record.consentType) {
  'privacy_policy' => ...,
  'document_processing' => ...,
  ...
  _ => ...,  // Falls through to generic _humanize()
};
```

If a new `ConsentPurpose` enum value is added but this switch is not updated, the new type displays with generic formatting. Not a bug today, but a maintenance hazard.

**Required:** Use `ConsentPurpose.values` iteration or a mapping function that stays in sync with the enum.

---

## 6. Profile Screen: Delete Account and Sign-Out — Findings

### P0.11: `deleteAccount()` does not clear local workspace after successful deletion

When `deleteAccount()` returns `isComplete`, it calls `signOut()` which:
- Clears Supabase session
- Clears anonymous token
- Clears DEK
- Resets analytics and Sentry

But it does NOT call `HiveWorkspaceService.clearLocalWorkspace()` or delete document files. The local workspace persists with stale data. If the user signs in again with a new account, the old workspace files are still on disk (though encrypted with a cleared key).

**Required:** After successful deletion, call `HiveWorkspaceService.clearLocalWorkspace()` and delete the workspace directory.

### P0.12: Profile screen's `_clearWorkspaceData()` re-clears what `signOut()` already cleared

`_signOut()` calls `signOut()` then `_clearWorkspaceData()`. `signOut()` already:
- Calls `PrincipalKeyService().clearKey()`
- Calls `AnalyticsNotifier.instance?.resetForWorkspace()`
- Calls `BillingAdapter.clearAccountIdentity()`

Then `_clearWorkspaceData()` calls:
- `BillingAdapter.clearAccountIdentity()` again (redundant)
- `AnalyticsNotifier.instance?.resetForWorkspace()` again (redundant but idempotent)
- `ContactService.clearSavedContact()` (new work)
- `HiveWorkspaceService.resetForPrincipal(LocalPrincipal(...))` (new work)

The workspace reset in `_clearWorkspaceData()` calls `resetForPrincipal()` which initializes a new DEK for the local principal and opens fresh boxes. This is the correct behavior — but it should happen inside `signOut()`, not in a separate method that only the profile screen calls.

**Required:** Move workspace teardown into `AuthNotifier.signOut()` so ALL sign-out paths (settings, profile, programmatic) get the same cleanup.

### P0.13: Account deletion does not verify local data purge

`deleteAccount()` calls the backend API which deletes server-side data. On success, it calls `signOut()`. But:
- Local Hive boxes are NOT cleared.
- Local document files are NOT deleted.
- Claim photos are NOT deleted.
- The consent ledger is NOT cleared.

The backend confirmed deletion of server data, but the local device retains everything. If the user expects "delete account" to mean "delete everything," this is a false completion.

**Required:** After successful backend deletion, clear the local workspace. The UI should clearly distinguish "delete account (server)" from "clear local data."

### P1.10: Deletion poller continues running after sign-out

`_deletionPoller` fires every 30 seconds. After sign-out, `_refreshDeletionStatus()` checks `auth.hasAccountSession` and returns early. But the timer continues until the widget is disposed. This is a minor resource leak and a code hygiene issue.

**Required:** Cancel `_deletionPoller` when `hasAccountSession` becomes false.

### P1.11: Account export sends data via SharePlus without plaintext warning

`_exportAccountData()` shares a JSON blob via `SharePlus.instance.share()`. The JSON may contain:
- Policy metadata
- Short-lived signed URLs to private source files
- Account identifiers

The share dialog doesn't warn that the data is plaintext and may contain sensitive insurance information.

**Required:** Add a warning in the confirmation dialog about the sensitivity of the exported data.

---

## 7. Consent Ledger: Clear Method — Finding

### P1.12: `ConsentLedger.clear()` is destructive with no recovery

`clear()` wipes all consent records from the Hive box. There is no:
- Backup before clear.
- Confirmation dialog integration.
- Audit trail of the clear event itself.

After `clear()`, the UI shows "No consent activity yet" — the user's entire consent history is gone. For an insurance app, consent audit trails may be legally required.

**Required:** Either:
1. Export records to a backup before clearing, or
2. Mark records as "cleared" instead of deleting them, or
3. Add a `clear` event to the ledger before wiping (append-only invariant).

---

## Summary

### What Was Fixed (Prior Sessions, Verified)

| Finding | Status | Evidence |
|---------|--------|----------|
| P0.18: Consent writes in dialog unawaited | ✅ FIXED | `lead_capture_dialog.dart`: `await ledger.recordConsent(...)` |
| P0.19: Contact entry → marketing consent | ✅ FIXED | `lead_capture_dialog.dart`: No marketing consent auto-grant |
| P0.20: Privacy policy conflated with consent | ✅ FIXED | `consent_ledger.dart`: Separate `privacyPolicy` and `documentProcessing` |
| P0.21: Onboarding completes on consent failure | ✅ FIXED | `onboarding_screen.dart`: `_recordConsentState()` throws on failure |
| P0.22: Terms not recorded separately | ✅ FIXED | `consent_ledger.dart`: `termsOfService` enum; `onboarding_screen.dart`: both recorded |

### Critical P0s Still Open

| ID | Finding | File | Why It's Launch-Blocking |
|----|---------|------|--------------------------|
| P0.1 | Clear data deletes files while Hive boxes open | `settings_screen.dart` | Filesystem use-after-delete; potential corruption |
| P0.2 | Clear data doesn't sign out of Supabase | `settings_screen.dart` | Data reappears on next sync; false wipe claim |
| P0.3 | Clear data doesn't reset RevenueCat | `settings_screen.dart` | Entitlement bleed across accounts |
| P0.4 | Clear data doesn't clear Sentry identity | `settings_screen.dart` | Privacy leak; crash attribution to wrong user |
| P0.5 | Clear data doesn't cancel analytics timer | `settings_screen.dart` | Stale events sent to cleared workspace |
| P0.8 | Newsletter Hive box never opened | `newsletter_service.dart` | Silent no-op on every write; false "subscribed" claim |
| P0.9 | Newsletter email persisted before consent | `newsletter_service.dart` | No consent trail for stored email |
| P0.10 | Lead capture consent write unprotected | `lead_capture_dialog.dart` | Dialog crash on box unavailable |
| P0.11 | Delete account doesn't clear local data | `auth_service.dart` / `profile_screen.dart` | Stale data persists after deletion |
| P0.12 | Sign-out doesn't coordinate workspace teardown | `profile_screen.dart` | Inconsistent cleanup across sign-out paths |
| P0.13 | Delete account doesn't verify local purge | `auth_service.dart` | False completion; user expects full wipe |

### P1s Deferred

| ID | Finding | File |
|----|---------|------|
| P1.1 | Contact writes not atomic | `contact_service.dart` |
| P1.2 | Profile bypasses ContactService | `profile_screen.dart` |
| P1.3 | Contact getters unnecessarily async | `contact_service.dart` |
| P1.4 | Newsletter unsubscribe is local-only | `newsletter_service.dart` |
| P1.6 | Lead capture doesn't save contact details | `lead_capture_dialog.dart` |
| P1.7 | Consent dialog doesn't show policy version | `lead_capture_dialog.dart` |
| P1.8 | Consent activity screen no epoch guard | `consent_activity_screen.dart` |
| P1.9 | Consent activity screen hardcoded strings | `consent_activity_screen.dart` |
| P1.10 | Deletion poller continues after sign-out | `profile_screen.dart` |
| P1.11 | Account export lacks plaintext warning | `profile_screen.dart` |
| P1.12 | Consent ledger clear is destructive | `consent_ledger.dart` |

### What Is Good

| Decision | Why It Should Be Preserved |
|----------|---------------------------|
| Consent activity screen uses server ledger, not local cache | Correct: server is authoritative for account-scoped consent history |
| Consent activity screen distinguishes unavailable vs empty | Honest UX: doesn't show partial record as complete |
| Lead capture dialog has explicit processing consent checkbox | Audit 6 P0.19 fix — contact entry ≠ marketing consent |
| Newsletter signup has explicit confirmation checkbox | Correct: marketing consent requires explicit opt-in |
| `_DeleteConfirmationDialog` requires typing "DELETE" | Good defense against accidental deletion |
| Account deletion checks in-flight documents | Prevents deletion during active processing |
| Deletion poller with 30s interval | Reasonable polling for async backend deletion |
| `ConsentRecord.fromJson` rejects unknown purposes | Audit 5 P0.15 fix — fail-closed on malformed data |
| `ConsentLedger._requiredBox` throws on unavailable box | Audit 5 P0.14 fix — no silent consent writes |

---

## Required Implementation Order

### 1. Fix clear-data lifecycle (P0.1–P0.5)
- Close Hive boxes before deleting files.
- Sign out of Supabase (or clarify "clear local only" in UI copy).
- Reset RevenueCat and Sentry.
- Cancel analytics timer.
- Remove redundant ConsentLedger.clear().

### 2. Fix newsletter service (P0.8, P0.9)
- Either add `newsletter` to `boxNames` or remove the service.
- Record consent before email if keeping the service.
- Add a clear warning that subscription is local-only.

### 3. Fix lead capture dialog (P0.10)
- Wrap consent write in try-catch.

### 4. Fix delete-account local cleanup (P0.11–P0.13)
- Clear local workspace after successful deletion.
- Move workspace teardown into `AuthNotifier.signOut()`.
- Distinguish "delete account (server)" from "clear local data" in UI.

### 5. Fix contact service atomicity (P1.1, P1.2)
- Use `putAll()` for multi-key writes.
- Route profile contact changes through `ContactService`.

### 6. Remaining P1s
- Identity epoch guard on consent activity screen.
- Consent ledger clear recovery.
- Account export plaintext warning.

---

## Test Matrix (After Fixes)

| Test | Priority |
|------|----------|
| Clear data: Hive boxes closed before file deletion | P0 |
| Clear data: Supabase session invalidated | P0 |
| Clear data: RevenueCat identity reset | P0 |
| Clear data: Sentry identity cleared | P0 |
| Clear data: Analytics timer cancelled | P0 |
| Clear data: Consent ledger empty after clear | P0 |
| Newsletter subscribe: email persisted only after consent | P0 |
| Newsletter subscribe: returns false when box unavailable | P0 |
| Newsletter unsubscribe: clears consent | P1 |
| Lead capture: consent failure shows error, not crash | P0 |
| Delete account: local workspace cleared after success | P0 |
| Delete account: sign-out clears workspace on all paths | P0 |
| Sign-out: Supabase session ended | P0 |
| Sign-out: workspace transitions to local principal | P0 |
| Contact save: atomic multi-key write | P1 |
| Contact read: handles box-unavailable gracefully | P1 |
| Consent activity: stale data after account switch | P1 |

---

## Next Audit Batch

Per the Audit 6 recommendation, the next files to review are:
- `mobile/android/app/src/main/AndroidManifest.xml` — backup/data-extraction flags
- `mobile/android/app/src/main/res/xml/backup_rules.xml` — cloud backup scope
- `mobile/ios/Runner/Info.plist` — iCloud backup, data protection
- `mobile/ios/Runner/*.entitlements` — keychain sharing, data protection
- `mobile/lib/screens/documents_screen.dart` — upload call sites, contact capture integration
- `mobile/lib/screens/onboarding_screen.dart` — consent flow integration
- `src/api/user.py` — backend account-deletion coordinator

---

*Created 2026-08-01 per motto §0.3. Append-only: original findings preserved; status updates appended.*
*Cross-reference: [Audit 5/6 cross-check](session_2026_07_31_audit_5_6_comprehensive_crosscheck.md)*
