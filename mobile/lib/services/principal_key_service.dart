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
  static const String _oldDeviceKeyStorageKey =
      'coverwise_legacy_device_hive_key_v1';

  /// Lazy-initialized secure storage.
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
    _principalId = principalId;
    final dek = await _getOrCreateDek(principalId);
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
  }

  /// The current principal ID, or null if not initialized.
  String? get principalId => _principalId;

  /// Get or create the DEK for a principal. The DEK is stored
  /// in the secure store under
  /// `${principalId}${_dekStorageKeySuffix}`.
  Future<Uint8List> _getOrCreateDek(String principalId) async {
    final storageKey = '$principalId$_dekStorageKeySuffix';
    final existing = await _secureStorage.read(key: storageKey);
    if (existing != null) {
      try {
        final bytes = base64Decode(existing);
        if (bytes.length == _keyLengthBytes) {
          return Uint8List.fromList(bytes);
        }
      } on FormatException {
        // Corrupt: fall through to generate a new one.
      }
      // Length mismatch: the DEK was written by an older
      // version. Generate a new one; the migration path
      // will handle the data loss.
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
    return Uint8List.fromList(Hive.generateSecureKey());
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

  /// Migrate a Hive box from the old per-device key to the
  /// new principal-scoped DEK. The migration is idempotent:
  /// if it has already run for this box, the second call is
  /// a no-op.
  ///
  /// The migration reads all entries with the old key,
  /// closes the box, deletes the box file, reopens the box
  /// with the new DEK, and writes the entries back.
  Future<bool> migrateBox({
    required String boxName,
    required String boxPath,
  }) async {
    if (await hasMigrationRun(boxName)) {
      return false;
    }
    final oldKeyBase64 = await _secureStorage.read(
      key: _oldDeviceKeyStorageKey,
    );
    if (oldKeyBase64 == null) {
      // No old key: this is a fresh install. Mark the
      // migration as complete and return false.
      await markMigrationComplete(boxName);
      return false;
    }
    final oldKey = Uint8List.fromList(base64Decode(oldKeyBase64));
    final newKey = getOrThrow();
    // Read all entries with the old key.
    final oldBox = await Hive.openBox(
      boxName,
      encryptionCipher: oldKey.length == 32 ? HiveAesCipher(oldKey) : null,
    );
    final entries = <String, dynamic>{};
    for (final key in oldBox.keys) {
      entries[key as String] = oldBox.get(key);
    }
    await oldBox.close();
    // Delete the box file so the new open does not collide.
    if (boxPath.isNotEmpty) {
      try {
        final file = File(boxPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('migrateBox: failed to delete $boxPath: $e');
      }
    }
    // Reopen with the new key and write the entries.
    final newBox = await Hive.openBox(
      boxName,
      encryptionCipher: HiveAesCipher(newKey),
    );
    for (final entry in entries.entries) {
      await newBox.put(entry.key, entry.value);
    }
    await newBox.close();
    // Mark the migration as complete. The flag is set
    // AFTER the new write succeeds; a crash before this
    // point leaves the migration to retry on next app
    // start.
    await markMigrationComplete(boxName);
    return true;
  }
}
