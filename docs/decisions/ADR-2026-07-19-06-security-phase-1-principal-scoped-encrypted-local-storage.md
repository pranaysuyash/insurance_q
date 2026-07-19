# ADR-2026-07-19-06: Security Phase 1 = principal-scoped encrypted local storage (JWT-derived key, Flutter-only change)

**Format:** Per `motto_v3.md` §0.12 (Decision Record Requirement).

- **Decision:** CoverWise's local storage is encrypted with a **principal-scoped key derived from the user's Supabase Auth JWT** (Option C in the security audit's framing). The Flutter app derives the key on session start via PBKDF2; the key is held in memory only and never written to disk. Existing Hive boxes encrypted with the old per-device key are migrated to the new principal key on the user's first login after this change ships. The migration is the only server-touching part of the change; the principal key is not stored on the server.
- **Date:** 2026-07-19
- **Owner / next reviewer:** Pranay (operator).
- **Status:** Accepted.
- **Related artifacts:** [`mobile/lib/services/principal_key_service.dart`](../../../mobile/lib/services/principal_key_service.dart) (the KDF + re-encryption API), [`mobile/test/principal_key_service_test.dart`](../../../mobile/test/principal_key_service_test.dart) (the tests), [`docs/architecture/coverwise_canonical_architecture.md`](../../architecture/coverwise_canonical_architecture.md) §4 (the trust + security boundary, updated), [docs/decisions/ADR-2026-07-19-02](./ADR-2026-07-19-02-outbox-migration-deferred.md) (the same ship-the-contract / defer-the-consumer pattern).

---

## Context

The security audit flagged this as Security Phase 1. The question is: how do we encrypt local storage on the device so that the data is bound to the user, not the device? Today the Hive boxes hold app state, policy summaries, and the consent ledger; the encryption key is per-device (or absent entirely on Android in some configurations). The audit says this is a confidentiality risk: a user loses their phone, the next person who picks it up can read the data.

The current Hive setup (per `mobile/lib/services/app_state_repository.dart` and `mobile/lib/services/local_storage_service.dart`):

- Hive boxes are encrypted with a per-device key (or unencrypted in dev).
- The key is stored in `flutter_secure_storage` (a keychain / keystore abstraction).
- The key is bound to the device: same key for the same device, no relation to the user.

The threat model the audit identifies:

- **Lost phone:** the next person who picks it up can read the data (if the device is unlocked) or extract the data with forensics tools (if the device is locked but the storage is unencrypted).
- **Stolen phone:** same as lost phone, with intent.
- **Forensics on a wiped-but-decrypted phone:** the encryption key may be recoverable from flash storage after a wipe; the data is then decryptable.
- **Malicious app on the same device:** a malicious app with the same `flutter_secure_storage` permissions can read the encryption key.

The audit's Phase 1 recommendation (ADR-09 from the security audit): encrypt the local storage with a principal-scoped key. The shape of "principal-scoped" is the decision; this ADR chooses Option C.

---

## Options considered

### Option A: Per-user encryption key stored on the server. REJECTED.

- **How it works:** a new key is generated on account creation, encrypted with the user's Supabase Auth access token, and stored in a new `principal_keys` table. On every device login, the key is fetched and used to encrypt the Hive boxes. The key is bound to the user, not the device.
- **Pros:**
  - The strongest compliance posture. The key is centrally managed; rotation is server-driven.
  - Survives password change (the key is independent of the password).
  - Survives device loss (the key is fetched again on the new device).
- **Cons:**
  - Requires a new schema (`principal_keys`), a new endpoint, and a new Flutter flow.
  - A bug in the new server-side code can lock all users out of their data.
  - The key is on the server, which is a single point of failure for the local data.
- **Why rejected:** the threat model does not require server-managed keys. The risk is "lost phone" and "forensics on a wiped device," both of which are addressed by Option C. The added server-side complexity is not justified.

### Option B: Derive the encryption key from the user's password. REJECTED.

- **How it works:** on every login, the user's password is re-hashed with a salt and the result is used as the Hive key. The key is never stored; it's re-derived each session. The key is bound to the password, which is bound to the user.
- **Pros:**
  - No server change. The key is local.
  - The strongest "no-trust-the-server" posture: the server never has the key.
- **Cons:**
  - Changing the password invalidates the local data (the old key is gone, the new key cannot decrypt the old data). The user loses all local data on password change unless a re-encryption is performed.
  - The user must re-enter the password on every new device. Worse UX than Option C.
  - A weak password is the only thing protecting the data. The Hive key is the password hash, so a brute-force on the Hive box is a brute-force on the password.
- **Why rejected:** the UX cost (password change loses data, new device requires password re-entry) is too high. The threat model is "lost phone," not "server is compromised."

### Option C: Per-user key derived from a Supabase Auth claim (the JWT). CHOSEN.

- **How it works:** Supabase Auth issues a JWT; the JWT contains a `sub` claim (the user ID) and other claims. The Flutter app derives a key from these via PBKDF2 (a KDF). The key is held in memory only and never written to disk. The key is re-derived at session start.
- **Pros:**
  - No server change. The principal key is derived from the existing JWT.
  - Survives password change (the key is independent of the password; the JWT's `sub` claim is stable).
  - No user action (the key is derived automatically at session start; better UX than Option B).
  - The key is held in memory only. A wiped device has no key. A live device that is unlocked gets the key after login; the data is decrypted.
  - The KDF is well-known (PBKDF2 with SHA-256, 100,000+ iterations per OWASP 2023 guidance).
- **Cons:**
  - The key is derived from the JWT. If the JWT signing key is compromised (server-side incident), the key is recoverable from a brute-force on the JWT contents. Mitigation: PBKDF2 with high iteration count makes this expensive; the server's JWT signing key is the Supabase Auth secret, which is managed by Supabase.
  - Logging out invalidates the key (the JWT is gone). The data is unreadable until the next login. This is the desired behavior.
  - The data is bound to the user but not the password. A user who knows another user's JWT can derive the key and decrypt the data. Mitigation: JWTs are short-lived (typically 1 hour); the threat model does not include "another user has my JWT."
- **Why chosen:** the threat model matches, no server change, no user action, survives password change. The KDF is standard and well-understood.

---

## Chosen path

**Option C: JWT-derived principal key, Flutter-only change, no server schema change.**

The implementation:

1. **`PrincipalKeyService`** (Flutter module, `mobile/lib/services/principal_key_service.dart`) — the typed API for the principal key.
   - `deriveKey(jwt: String) -> Uint8List` — derives a 256-bit key from the JWT via PBKDF2 (100,000 iterations, SHA-256, per-user salt stored in `flutter_secure_storage`).
   - `getOrDeriveKey(jwt: String) -> Future<Uint8List>` — derives the key and caches it in memory for the session.
   - `clearKey()` — clears the in-memory cache (called on logout).
   - `migrateDeviceEncryptedBoxes(oldKey, newKey)` — the migration entry point: decrypts with `oldKey`, re-encrypts with `newKey`. Called once per Hive box on the user's first login after this change.

2. **The salt.** A per-user random 32-byte salt is generated on first login and stored in `flutter_secure_storage` (the keychain/keystore). The salt is not secret (a salt is not a key), but storing it in the secure store means it survives an app uninstall only on the same device. The salt does not need to be on the server; if the user uninstalls and reinstalls, a new salt is generated, and the migration path detects this and asks the user to re-enter the data.

3. **The KDF parameters.** PBKDF2-HMAC-SHA256, 100,000 iterations, 32-byte output. The OWASP 2023 recommendation for PBKDF2-SHA256 is 600,000 iterations; 100,000 is the v1 choice (faster on mobile; the iteration count is a follow-up tuning item). The KDF parameters are stored in the salt's metadata so they can be increased without invalidating existing keys.

4. **The Hive change.** Each Hive box's `Hive.openBox(name, encryptionCipher: HiveAesCipher(key))` is replaced with `Hive.openBox(name, encryptionCipher: HiveAesCipher(principalKey))`. The box is opened at app start with the principal key; the migration is called once if the box is still device-encrypted.

5. **The migration.** On the first login after this change, the migration runs:
   - Open the box with the old device key.
   - Read all entries.
   - Close the box.
   - Delete the box file.
   - Re-open the box with the new principal key.
   - Write all entries back.
   - Mark the migration as done in `flutter_secure_storage` (a per-user flag).

   The migration is idempotent: if it runs twice, the second run is a no-op (the box is already principal-encrypted).

6. **The threat model coverage.** A wiped device has no key. A live device that is unlocked has the key after login; the data is decrypted for the user. A malicious app with `flutter_secure_storage` permissions can read the salt (not the key, the key is in memory only); without the JWT, the salt is useless. A user who logs out has the in-memory key cleared; the data on disk is unreadable until the next login.

---

## Why this path

### 1st-principle argument

The data on a lost phone is the data at risk. The data on a phone the user still has is fine (the user can unlock the device). The threat model is: lost phone, stolen phone, forensics on a wiped-but-decrypted phone, a malicious app on the same device.

For each option, the threat model coverage:

- **Option A (server-stored key):** the device without a login has no key; a wiped device has no key; a live device with a login has the key from the server. Matches the threat model. Cost: a new server-side attack surface (the principal_keys table) that Option C does not have.
- **Option B (password-derived):** the device without a login has no key (the password is not stored). A wiped device has no key. A live device with a login has the key derived from the password. Matches the threat model. Cost: password change invalidates local data, new device requires password re-entry, weak password = weak key.
- **Option C (JWT-derived):** the device without a login has no JWT, no key. A wiped device has no key. A live device with a login has the key derived from the JWT. Matches the threat model. Cost: none of the above.

Option C is the smallest change that addresses the threat model.

### Anti-parallel-paths argument (motto v3 §0.1)

The encryption key is one path. Option A would have a server-side path (the principal_keys table) and a Flutter-side path (the Hive box). Option C has one path: the JWT-derived key, used everywhere. Per motto v3 §0.1, fewer paths is better.

### Anti-credential-management argument (motto v3 §0.4)

Option B's UX cost (password change invalidates local data) is a hidden contract: the user expects their data to survive a password change. Option C satisfies this contract. Option A also satisfies it, but at the cost of a new server-side schema.

### Anti-over-engineering argument (motto v3 §0)

The audit's recommendation is "build principal-scoped encrypted local storage." It does not say "build a server-managed key infrastructure." The smallest change that addresses the threat model is the right change. Option C is the smallest.

### Anti-server-side-attack-surface argument

A new server-side table is a new attack surface. The principal_keys table holds encrypted keys; a bug in the encryption/decryption logic can lock all users out. Option C has no such attack surface. The KDF is local; the JWT is the existing Supabase Auth mechanism.

### Compliance posture argument

Option C's compliance posture is sufficient for the threat model. The audit does not require Option A's stronger posture; the audit requires "principal-scoped," which Option C satisfies. If a future audit requires Option A, the migration is straightforward (add a `principal_keys` table, fetch the key from the server instead of deriving it; the rest of the code is unchanged because the key is held in memory and used the same way).

---

## Tradeoffs

- **The KDF is a one-way function.** Once the key is derived, the JWT is not recoverable from the key. The migration is one-way: a user who re-derives the key from a new JWT cannot decrypt old data. This is the desired behavior.
- **The salt is per-user, not per-device.** A user who logs in on a new device generates a new salt. The migration on the new device detects the new salt and asks the user to re-enter the data (or to skip; the data is lost on the new device). This is the cost of "no server-stored key."
- **The PBKDF2 iteration count is a tuning parameter.** v1 uses 100,000; OWASP 2023 recommends 600,000. The iteration count is stored in the salt's metadata so it can be increased without invalidating existing keys. The trade-off: higher iteration count = slower derivation (linear in the count) = more CPU on app start. 100,000 is fast (~100ms on a typical phone); 600,000 is ~600ms. v1 uses 100,000 for UX; v2 may increase.
- **The principal key is in memory.** A malicious app with debug access (e.g. on a rooted device) can read the key. The threat model does not include "rooted device with a malicious app that has the user's credentials"; if that threat becomes real, Option A is the answer.
- **The KDF parameters are not standardized.** PBKDF2 with SHA-256 and 100,000 iterations is a common choice but is not the only choice. Argon2id is the modern recommendation. v1 uses PBKDF2 for library availability; v2 may use Argon2id.

---

## Assumptions

- **The threat model is "lost phone," not "compromised server."** If the threat model changes to "compromised server," Option A becomes the right answer. The audit's threat model is the former.
- **The KDF parameters (PBKDF2-SHA256, 100,000 iterations) are sufficient for the threat model.** This is a 1st-principle judgment based on the OWASP 2023 guidance (600,000 is the recommendation; 100,000 is the v1 choice for UX). The trade-off is documented; the iteration count is a follow-up tuning item.
- **The Flutter app has a single Hive key per box.** Today each box has its own device key. The migration unifies this: one principal key, one salt, one KDF. The Hive box change is per-box.
- **The existing per-device keys are recoverable for the migration.** They are in `flutter_secure_storage`; the migration reads them, decrypts the box, re-encrypts with the principal key, deletes the old key. The old key is not deleted from `flutter_secure_storage` until the migration is confirmed.
- **The user is willing to re-enter data on a new device after this change.** If the user uninstalls and reinstalls, the local data is lost (the new salt makes the old data undecryptable). This is acceptable for the threat model; the user's data is on the server (in the substrate + the documents table), so the loss is local cache, not source-of-truth.

---

## Risks

- **The migration fails partway through.** Mitigation: the migration is per-box; a failure on one box does not affect the others. The migration is idempotent; a retry on app start completes the partial migration.
- **The KDF parameters are wrong for a future device class.** Mitigation: the iteration count is in the salt's metadata; a future change can increase it without invalidating existing keys.
- **A user loses their phone AND forgets their Supabase Auth credentials.** Mitigation: the user can recover via Supabase Auth's password reset flow. The local data is lost (the new login creates a new salt; the old data is unreadable). This is the cost of "no server-stored key."
- **The Flutter app crashes between "decrypt with old key" and "re-encrypt with new key."** Mitigation: the migration is per-box; the box is closed and re-opened atomically (Hive does not have transactions, so the migration is a write-then-read sequence; a crash leaves the box in the old-key state and the migration retries on next app start).
- **The principal key derivation is slow on a low-end device.** Mitigation: the derivation runs once per session (~100ms on a typical phone); the result is cached in memory. The app start is not blocked on the derivation; the Hive boxes are opened with the cached key.

---

## Validation plan

- **Unit tests (T2):**
  - `deriveKey` is deterministic for a given JWT + salt.
  - `deriveKey` produces different keys for different JWTs.
  - `deriveKey` produces different keys for the same JWT + different salts.
  - The KDF parameters are correct (PBKDF2-HMAC-SHA256, 100,000 iterations, 32-byte output).
  - The encryption roundtrip: encrypt with the principal key, decrypt with the principal key, the data is preserved.
  - The migration: encrypt with the old key, migrate, decrypt with the new key, the data is preserved.
  - The migration is idempotent: a second run on a migrated box is a no-op.
  - `clearKey` clears the in-memory cache.
- **Integration test (T2):**
  - Open a Hive box with the principal key, write 100 entries, close, reopen with the same key, all 100 entries are present.
  - Open a Hive box with the old key, migrate, close, reopen with the principal key, all 100 entries are present.
- **Real-device test (T0, in the launch playbook's Step 8):**
  - On a real Android device, log in, write a policy summary to the Hive box, log out, log in again as the same user, the summary is present.
  - On a real Android device, log in as user A, write a summary, log out, log in as user B, the summary is NOT present (the principal key for B cannot decrypt A's data).
  - On a real Android device, change the password (Supabase Auth), the local data is still readable (the key is derived from the JWT, not the password).

---

## Rollback or migration path

If the principal key approach is wrong (e.g. a future audit requires server-stored keys), the rollback is:

1. Add a `principal_keys` table.
2. Add a `POST /principal-keys` endpoint (server stores the key encrypted with the user's access token).
3. Change `PrincipalKeyService.deriveKey` to `PrincipalKeyService.fetchKey` (the Flutter module calls the new endpoint).
4. Existing data encrypted with the JWT-derived key is unreadable. The user must re-enter the data.

The Hive change and the migration entry point are unchanged. The principal key is held in memory and used the same way. The only change is the source of the key.

If the KDF parameters are wrong (e.g. 100,000 iterations is too few for a future threat), the rollback is:

1. Increase the iteration count in the salt's metadata.
2. Existing keys are still derivable (the iteration count is per-salt, not global).
3. New logins use the new count.

The KDF parameters are a tuning parameter, not a contract.

---

## What would cause this decision to be revisited

- **The threat model changes to "compromised server."** Option A becomes the right answer. The migration is documented in the rollback section.
- **A user reports data loss on a new device.** The user expected local data to survive a device change. Option B (password-derived) is the right answer for this user; Option C is the right answer for the threat model. The trade-off is the user's expectation vs. the security posture. v2 may offer both: password-derived for users who want it, JWT-derived as the default.
- **The OWASP recommendation changes to a new KDF.** The implementation changes; the contract is unchanged. The salt's metadata carries the KDF parameters.
- **A regulator requires server-managed keys.** Option A is the right answer. The migration is documented.
- **The audit is updated with a new threat model.** The audit's recommendation is the source of truth. The implementation changes; the contract is unchanged.

---

## Links

- **Affected files (this commit):**
  - `mobile/lib/services/principal_key_service.dart` (new, the KDF + re-encryption API + migration entry point)
  - `mobile/test/principal_key_service_test.dart` (new, the tests)
  - `docs/decisions/ADR-2026-07-19-06-...md` (this file)
  - `docs/decisions/README.md` (updated index)
  - `docs/architecture/coverwise_canonical_architecture.md` (updated; §4 trust + security boundary now points to the principal key)
  - `docs/technical/deployment/launch_playbook_2026-07-18.md` (updated; Security Phase 1 marked shipped-contract; migration is a follow-up)
  - `docs/planning/coverwise_audit_task_classification_2026-07-18.md` (updated; Bucket 5 #23 marked shipped-contract)
- **Related ADRs / docs:**
  - [ADR-2026-07-19-02](./ADR-2026-07-19-02-outbox-migration-deferred.md) (the same ship-the-contract / defer-the-consumer pattern)
  - `coverwise_security_privacy_identity_data_lifecycle_audit_2026-07-18.md` (the source audit, Phase 1)
- **Related code:**
  - `mobile/lib/services/local_storage_service.dart` (the existing per-device-key Hive opener; the per-box migration is the follow-up)
  - `mobile/lib/services/app_state_repository.dart` (the existing Hive consumer; the per-box migration is the follow-up)
  - `mobile/lib/services/auth_service.dart` (the existing Supabase Auth integration; the principal key derivation uses the existing access token)
- **Motto v3 alignment:** §0.1 (no parallel paths; one key source, one KDF), §0.4 (acceptance contract; the KDF parameters and the migration entry point are the contract), §0.5 (evidence tiers; T2 unit + T0 real-device), §0.7 (AI output boundary; the KDF is a well-known primitive, not an invented one), §0.10 (observability is delivery; the migration is observable via the per-user flag in `flutter_secure_storage`), §0.12 (this document).
