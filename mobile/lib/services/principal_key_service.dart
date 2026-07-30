import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Principal-scoped encryption key for Hive boxes (Trust +
/// security Phase 1, ADR-2026-07-19-06).
///
/// **REOPENED 2026-07-19 per the current-state review.** The
/// original implementation derived the key from the user's
/// Supabase Auth JWT (PBKDF2 over the JWT text). This was
/// wrong: Supabase access JWTs rotate (typically hourly), and
/// a refreshed or newly issued JWT produces a different
/// encryption key, which would render the local Hive data
/// unreadable.
///
/// **The corrected contract (this version):** the encryption
/// key is a stable random 256-bit data-encryption key (DEK),
/// stored in `flutter_secure_storage` (the iOS Keychain /
/// Android Keystore), namespaced by the stable principal ID.
/// The DEK is generated once per principal (on first login
/// after this change ships) and persists across JWT rotations
/// and across app restarts. The principal ID is the stable
/// Supabase user UUID; it does not change across JWT rotations.
///
/// The threat model: lost phone, stolen phone, forensics on a
/// wiped device, a malicious app on the same device. The
/// principal key addresses each: a wiped device has no key
/// (the DEK is in the secure store, which is wiped with the
/// device; a forensic recovery is bounded by the secure
/// store's encryption). A live device with a login has the
/// key from the secure store. A malicious app with secure
/// store permissions can read the DEK — that is the same
/// threat model as a malicious app reading the JWT, and the
/// secure store's hardware-backed encryption (StrongBox /
/// Secure Enclave) is the standard mitigation.
///
/// Migration: on the first login after this change ships,
/// the old device-key-encrypted Hive boxes are decrypted
/// with the old key, re-encrypted with the new DEK, and the
/// old key is cleared from the secure store. The migration
/// is per-box and idempotent.
class PrincipalKeyService {
  PrincipalKeyService._internal();
  static final PrincipalKeyService _instance = PrincipalKeyService._internal();

  /// All callers must share the in-memory DEK for the active principal.
  /// The service is intentionally a process-local singleton; constructing a
  /// new instance after initialization would otherwise lose the cached key
  /// before encrypted Hive boxes are opened.
  factory PrincipalKeyService() => _instance;

  /// The key length in bytes. 32 bytes = 256 bits, which is
  /// the AES-256 key size that Hive's AES cipher uses.
  static const int _keyLengthBytes = 32;

  /// The secure storage key for the DEK. Namespaced by
  /// `principal_id` at runtime; the suffix `_v1` is the
  /// schema version (bump on key-format change).
  static const String _dekStorageKeySuffix = '_coverwise_dek_v1';

  /// The secure storage key for the per-box migration flag.
  /// v1: the legacy device key was stored under a fixed
  /// name; v2 (this) stores the DEK per principal and the
  /// migration flag per box.
  static const String _migrationFlagStorageKeySuffix =
      '_coverwise_dek_migration_done_v1';

  /// The secure storage key for the old (per-device) Hive
  /// encryption key. Read once during the migration, then
  /// cleared. The name is preserved for v1->v2 migration
  /// compatibility.
  static const String oldDeviceKeyStorageKey =
      'coverwise_legacy_device_hive_key_v1';

  /// Lazy-initialized secure storage.
  ///
  /// The `encryptedSharedPreferences` parameter was removed because the
  /// Jetpack Security library is deprecated by Google. Data auto-migrates
  /// to custom ciphers on first access. See the deprecation notice in
  /// flutter_secure_storage v11.
  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  /// In-memory cache of the DEK for the current session.
  /// Cleared on logout. Never written to disk.
  Uint8List? _cachedKey;

  /// The stable principal ID. Set by [initForPrincipal] at
  /// session start (typically in the Flutter app's auth
  /// bootstrap). Must NOT change during the session.
  String? _principalId;

  /// Initialize the service for a specific principal. Called
  /// at session start, after the user is authenticated.
  /// The principal ID is the stable Supabase user UUID; it
  /// does NOT change across JWT rotations.
  ///
  /// This method:
  ///   1. Stores the principal ID for the current session.
  ///   2. Reads the DEK from the secure store; if missing,
  ///      generates a new 256-bit DEK and stores it.
  ///   3. Holds the DEK in memory for fast access.
  ///
  /// On logout, call [clearKey] to drop the in-memory cache.
  /// The on-disk DEK is kept (the user may log in again on
  /// the same device and expect their local data to be
  /// accessible).
  Future<void> initForPrincipal(String principalId) async {
    if (principalId.isEmpty) {
      throw ArgumentError('principalId must not be empty');
    }
    final dek = await _getOrCreateDek(principalId);
    // Publish the new principal only after secure-storage initialization has
    // succeeded. A failed read/write must not leave callers with a principal
    // label whose cached key is still null or belongs to the previous user.
    _principalId = principalId;
    _cachedKey = dek;
  }

  /// Get the DEK for the current session. Throws if
  /// [initForPrincipal] has not been called. The DEK is
  /// cached in memory; subsequent calls return the cached
  /// value without re-reading the secure store.
  Uint8List getOrThrow() {
    if (_cachedKey == null) {
      throw StateError(
        'PrincipalKeyService not initialized; '
        'call initForPrincipal(principalId) at session start.',
      );
    }
    return _cachedKey!;
  }

  /// Clear the in-memory key cache. Called on logout. The
  /// on-disk DEK is kept (the user may log in again on the
  /// same device and expect their local data to be
  /// accessible).
  void clearKey() {
    _cachedKey = null;
    _principalId = null;
  }

  /// The current principal ID, or null if not initialized.
  String? get principalId => _principalId;

  /// Whether this install still carries the pre-principal device key.
  /// Startup uses this single secure-store read to avoid performing a
  /// read/modify/write migration check for every Hive box on fresh installs.
  Future<bool> hasLegacyDeviceKey() async =>
      await _secureStorage.read(key: oldDeviceKeyStorageKey) != null;

  /// Get or create the DEK for a principal. The DEK is stored
  /// in the secure store under
  /// `${principalId}${_dekStorageKeySuffix}`.
  Future<Uint8List> _getOrCreateDek(String principalId) async {
    final storageKey = '$principalId$_dekStorageKeySuffix';
    final existing = await _secureStorage.read(key: storageKey);
    if (existing != null) {
      Uint8List? decoded;
      try {
        final raw = base64Decode(existing);
        decoded = Uint8List.fromList(raw);
      } on FormatException {
        // P0.7: A corrupt DEK must throw, not silently replace.
        // Silently generating a new key would make the old encrypted Hive
        // boxes permanently unreadable, losing the user's data without
        // warning. Instead, let the caller surface the error so the user
        // can be informed and given a recovery path.
        throw StateError(
          'Corrupt encryption key for principal $principalId. '
          'The stored DEK is not valid base64 and cannot be decoded. '
          'Local data may be unrecoverable.',
        );
      }
      if (decoded.length == _keyLengthBytes) {
        return decoded;
      }
      // Length mismatch: the DEK was written by an incompatible version.
      // This is also unrecoverable — throwing avoids silent data loss.
      throw StateError(
        'Encryption key for principal $principalId has unexpected length '
        '(${decoded.length} bytes, expected $_keyLengthBytes). '
        'The key format may be from an incompatible version. '
        'Local data may be unrecoverable.',
      );
    }
    final newDek = _generateRandomBytes(_keyLengthBytes);
    await _secureStorage.write(
      key: storageKey,
      value: base64Encode(newDek),
    );
    return newDek;
  }

  /// Generate a salt of cryptographically random bytes. Uses
  /// `Hive.generateSecureKey` (a Hive helper) for the random
  /// source. The returned list is converted to a `Uint8List`
  /// of the requested length.
  static Uint8List _generateRandomBytes(int length) {
    final generated = Hive.generateSecureKey();
    if (generated.length == length) {
      return Uint8List.fromList(generated);
    }
    return Uint8List.fromList(generated.take(length).toList());
  }

  // --- migration ---

  /// True if the migration from device-key to principal-key
  /// has run for this principal on this device. False if the
  /// migration has not run (or has not completed).
  Future<bool> hasMigrationRun(String boxName) async {
    if (_principalId == null) return false;
    final storageKey = '$_principalId$_migrationFlagStorageKeySuffix';
    final value = await _secureStorage.read(key: storageKey);
    if (value == null) return false;
    // The value is a JSON object: `{"boxName1": true, "boxName2": true}`.
    // Per-box granularity: a failed migration on one box does
    // not require re-migrating the others.
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      return map[boxName] == true;
    } on FormatException {
      return false;
    }
  }

  /// Mark the migration as complete for a specific box.
  /// Per-box granularity: a successful migration on one
  /// box does not mark the others as complete.
  Future<void> markMigrationComplete(String boxName) async {
    if (_principalId == null) {
      throw StateError('initForPrincipal must be called first');
    }
    final storageKey = '$_principalId$_migrationFlagStorageKeySuffix';
    // Read-modify-write the JSON object.
    String currentJson = '{}';
    final existing = await _secureStorage.read(key: storageKey);
    if (existing != null) {
      try {
        final parsed = jsonDecode(existing);
        if (parsed is Map<String, dynamic>) {
          currentJson = jsonEncode(parsed);
        }
      } on FormatException {
        // Corrupt; start fresh.
      }
    }
    final current = (jsonDecode(currentJson) as Map<String, dynamic>)
        .cast<String, dynamic>();
    current[boxName] = true;
    await _secureStorage.write(
      key: storageKey,
      value: jsonEncode(current),
    );
  }

  /// The secure storage key suffix for the migration journal checkpoint.
  /// Written BEFORE the old box is deleted, cleared AFTER verification.
  /// A stale checkpoint on startup means the migration was interrupted
  /// and should be retried.
  static const String _migrationJournalKeySuffix =
      '_coverwise_migration_journal_v1';

  /// Check if a migration journal checkpoint exists for any box.
  /// If true, a previous migration attempt was interrupted (process crash,
  /// app kill) between deleting the old box and completing verification.
  /// The caller should retry the migration for the journaled box.
  Future<String?> readMigrationJournal() async {
    if (_principalId == null) return null;
    return _secureStorage.read(
      key: '$_principalId$_migrationJournalKeySuffix',
    );
  }

  /// Clear the migration journal checkpoint.
  Future<void> clearMigrationJournal() async {
    if (_principalId == null) return;
    await _secureStorage.delete(
      key: '$_principalId$_migrationJournalKeySuffix',
    );
  }

  /// Migrate a Hive box from the old per-device key to the
  /// new principal-scoped DEK. The migration is idempotent:
  /// if it has already run for this box, the second call is
  /// a no-op.
  ///
  /// P0.8 safety improvements:
  ///  - Writes a migration journal checkpoint BEFORE deleting the old
  ///    box, so a process crash between delete and verification can be
  ///    detected on next startup via [readMigrationJournal].
  ///  - Handles non-string Hive keys gracefully (skips them with a
  ///    warning instead of crashing the entire migration).
  ///  - Retains existing safety: entry count verification, round-trip
  ///    decrypt check, per-box completion flags, and old key retention.
  ///
  /// P0.5: Accepts an optional [targetPath] for principal-namespaced storage.
  /// When provided, the migrated data is written to `<targetPath>/` instead
  /// of the default Hive path. The old box (at the default or [boxPath])
  /// is NOT deleted — it remains on disk as a legacy source since it lives
  /// at a different location.
  ///
  /// Safety properties:
  ///  - Entry count is verified before and after write.
  ///  - A round-trip read after write confirms the new key
  ///    can actually decrypt the data.
  ///  - The old key is NOT deleted by this method; the
  ///    caller is responsible for clearing it only after
  ///    ALL boxes have been migrated successfully.
  ///  - A crash before markMigrationComplete leaves the
  ///    migration retryable on next launch.
  Future<bool> migrateBox({
    required String boxName,
    required String boxPath,
    String? targetPath, // P0.5: optional namespaced target path
  }) async {
    if (await hasMigrationRun(boxName)) {
      return false;
    }
    final oldKeyBase64 = await _secureStorage.read(
      key: oldDeviceKeyStorageKey,
    );
    if (oldKeyBase64 == null) {
      // No old key: this is a fresh install. Mark the
      // migration as complete and return false.
      await markMigrationComplete(boxName);
      return false;
    }
    final oldKey = Uint8List.fromList(base64Decode(oldKeyBase64));
    final newKey = getOrThrow();

    // Step 1: Write migration journal BEFORE any destructive operation.
    await _secureStorage.write(
      key: '$_principalId$_migrationJournalKeySuffix',
      value: boxName,
    );

    // Step 2: Read all entries with the old key.
    final oldBox = await Hive.openBox(
      boxName,
      encryptionCipher: oldKey.length == 32 ? HiveAesCipher(oldKey) : null,
    );
    final entries = <String, dynamic>{};
    int skippedNonStringKeys = 0;
    for (final key in oldBox.keys) {
      if (key is String) {
        entries[key] = oldBox.get(key);
      } else {
        skippedNonStringKeys++;
      }
    }
    final sourceCount = entries.length;
    await oldBox.close();

    if (skippedNonStringKeys > 0) {
      debugPrint(
        'migrateBox: skipped $skippedNonStringKeys non-string key(s) '
        'in box "$boxName" during migration',
      );
    }

    // Step 3: Delete the old box from disk ONLY when targetPath is NOT
    // provided (legacy flat-path migration). When targetPath IS provided
    // (P0.5 namespaced storage), the old box lives at a different path and
    // should NOT be deleted — it remains as a legacy source.
    if (targetPath == null) {
      if (boxPath.isNotEmpty) {
        try {
          final file = File(boxPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('migrateBox: failed to delete $boxPath: $e');
          await clearMigrationJournal();
          rethrow;
        }
      } else {
        await Hive.deleteBoxFromDisk(boxName);
      }
    }

    // Step 4: Reopen with the new key at the target path (or default path
    // if no targetPath is given).
    final newBox = await Hive.openBox(
      boxName,
      path: targetPath, // P0.5: write to namespaced path, or null = default
      encryptionCipher: HiveAesCipher(newKey),
    );
    for (final entry in entries.entries) {
      await newBox.put(entry.key, entry.value);
    }

    // Step 5: Verify the write succeeded by reading back the
    // entry count. This catches silent write failures.
    if (newBox.length != sourceCount) {
      await newBox.close();
      await clearMigrationJournal();
      throw StateError(
        'Migration verification failed for $boxName: '
        'wrote $sourceCount entries but box has ${newBox.length}',
      );
    }

    // Step 6: Verify a round-trip decrypt by reading the
    // first entry back. A wrong key would cause Hive to throw
    // on read (decryption failure), not return null.
    if (sourceCount > 0) {
      final firstKey = newBox.keys.first;
      try {
        // ignore: unnecessary_statements
        newBox.get(firstKey); // will throw if decrypt fails
      } catch (e) {
        await newBox.close();
        await clearMigrationJournal();
        throw StateError(
          'Migration round-trip decrypt failed for $boxName: '
          'entry at key $firstKey threw $e',
        );
      }
    }

    await newBox.close();

    // Step 7: Mark complete first, then clear the migration journal.
    // P0.8: Order matters — the completion flag must be written BEFORE the
    // journal is cleared. If the process crashes between these two writes:
    //  - Completion flag IS set → migrateBox returns early via hasMigrationRun()
    //  - Stale journal is present but harmless (no-op on retry)
    // If we cleared the journal first and crashed before markComplete, both
    // the journal AND the completion flag would be absent, causing a retry
    // with the wrong decryption key.
    await markMigrationComplete(boxName);
    await clearMigrationJournal();
    return true;
  }
}
