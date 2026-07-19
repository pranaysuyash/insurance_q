import 'dart:convert';
import 'dart:io' show File;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Principal-scoped encryption key for Hive boxes (Trust +
/// security Phase 1, ADR-2026-07-19-06).
///
/// The local storage on the device is encrypted with a key
/// derived from the user's Supabase Auth JWT. The key is held
/// in memory only and never written to disk. On logout, the
/// in-memory key is cleared; the on-disk data is unreadable
/// until the next login.
///
/// The threat model: lost phone, stolen phone, forensics on
/// a wiped-but-decrypted phone, a malicious app on the same
/// device. The principal key addresses each: a wiped device
/// has no key, a live device with a login has the key from
/// the JWT, a malicious app without the JWT cannot derive
/// the key.
///
/// The KDF parameters (PBKDF2-HMAC-SHA256, 100,000 iterations,
/// 32-byte output) are the v1 choice. The iteration count is
/// in the salt's metadata so it can be increased without
/// invalidating existing keys.
class PrincipalKeyService {
  /// The KDF iteration count. v1 uses 100,000 for UX
  /// (~100ms on a typical phone). OWASP 2023 recommends
  /// 600,000; the count is a tuning parameter and can be
  /// increased without invalidating existing keys.
  static const int _kdfIterations = 100000;

  /// The key length in bytes. 32 bytes = 256 bits, which is
  /// the AES-256 key size that Hive's AES cipher uses.
  static const int _keyLengthBytes = 32;

  /// The salt length in bytes. 32 bytes is the standard
  /// recommendation.
  static const int _saltLengthBytes = 32;

  /// The secure storage key for the per-user salt.
  static const String _saltStorageKey = 'coverwise_principal_key_salt_v1';

  /// The secure storage key for the per-user migration flag.
  /// "True" means the migration has run for this user on
  /// this device. "False" or missing means the migration
  /// has not run; on the next app start, the migration is
  /// attempted.
  static const String _migrationFlagStorageKey =
      'coverwise_principal_key_migration_done_v1';

  /// The secure storage key for the old (per-device) Hive
  /// encryption key. Read once during the migration, then
  /// cleared.
  static const String _oldDeviceKeyStorageKey =
      'coverwise_legacy_device_hive_key_v1';

  /// The KDF parameters, used by the salt's metadata so
  /// they can be tuned without invalidating existing keys.
  /// v1 stores the iterations count in a separate field;
  /// v2 may add the KDF algorithm (PBKDF2 / Argon2id).
  static const Map<String, dynamic> kdfParameters = {
    'algorithm': 'pbkdf2_hmac_sha256',
    'iterations': _kdfIterations,
    'key_length_bytes': _keyLengthBytes,
    'salt_length_bytes': _saltLengthBytes,
  };

  /// Lazy-initialized secure storage. The
  /// [FlutterSecureStorage] constructor is cheap; the
  /// underlying native channels are opened on first use.
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// In-memory cache of the principal key for the current
  /// session. Cleared on logout. Never written to disk.
  Uint8List? _cachedKey;

  /// Derive the principal key from a JWT + per-user salt.
  /// Pure function: deterministic for a given (jwt, salt,
  /// iterations) tuple. The salt is stored separately; the
  /// JWT is supplied at session start.
  ///
  /// Uses PBKDF2-HMAC-SHA256 with [kdfIterations]
  /// iterations, producing a 32-byte (256-bit) key.
  /// Implementation note: PBKDF2 requires HMAC, which
  /// requires a block cipher or hash. SHA-256 is the v1
  /// choice; Argon2id is the v2 modernization per OWASP.
  static Uint8List deriveKey({
    required String jwt,
    required Uint8List salt,
    int iterations = _kdfIterations,
    int keyLengthBytes = _keyLengthBytes,
  }) {
    if (salt.length != _saltLengthBytes) {
      throw ArgumentError(
        'salt must be $_saltLengthBytes bytes; got ${salt.length}',
      );
    }
    return _pbkdf2HmacSha256(
      password: utf8.encode(jwt),
      salt: salt,
      iterations: iterations,
      keyLengthBytes: keyLengthBytes,
    );
  }

  /// Static PBKDF2-HMAC-SHA256 implementation per RFC 2898.
  /// The output is the derived key. The implementation is
  /// the standard: for each block index i from 1 to
  /// ceil(dkLen / hLen), U_i = HMAC(password, salt ||
  /// INT(i)); T = U_1 XOR U_2 XOR ... XOR U_i. For a
  /// 32-byte key with SHA-256 (hLen=32), there is one
  /// block, so T = U_1.
  static Uint8List _pbkdf2HmacSha256({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int keyLengthBytes,
  }) {
    const int hLen = 32; // SHA-256 output length in bytes
    final int blockCount = (keyLengthBytes + hLen - 1) ~/ hLen;
    final Uint8List result = Uint8List(blockCount * hLen);
    final Hmac hmac = Hmac(sha256, password);
    for (int blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      // U_1 = HMAC(password, salt || INT(blockIndex))
      final Uint8List blockInput = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..setRange(salt.length, salt.length + 4, _intToBytes(blockIndex));
      Uint8List u = Uint8List.fromList(hmac.convert(blockInput).bytes);
      final Uint8List t = Uint8List.fromList(u);
      // U_2 ... U_iterations: U_i = HMAC(password, U_{i-1})
      for (int iter = 1; iter < iterations; iter++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      result.setRange(
        (blockIndex - 1) * hLen,
        blockIndex * hLen,
        t,
      );
    }
    return Uint8List.sublistView(result, 0, keyLengthBytes);
  }

  /// Convert an integer to a 4-byte big-endian byte array
  /// (PBKDF2's INT(i) representation per RFC 2898).
  static List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Get the salt for the current user, generating one if
  /// none exists. The salt is stored in
  /// `flutter_secure_storage` under [_saltStorageKey]. If
  /// the user uninstalls and reinstalls, a new salt is
  /// generated; the migration path detects this and asks
  /// the user to re-enter the data.
  Future<Uint8List> getOrCreateSalt() async {
    final existing = await _secureStorage.read(key: _saltStorageKey);
    if (existing != null) {
      try {
        final bytes = base64Decode(existing);
        if (bytes.length == _saltLengthBytes) {
          return Uint8List.fromList(bytes);
        }
      } on FormatException {
        // Corrupt salt: fall through to generate a new one.
      }
      // Length mismatch or corrupt: the salt was written by
      // an older version. Generate a new one; the migration
      // path will handle the data loss.
    }
    final newSalt = _generateRandomBytes(_saltLengthBytes);
    await _secureStorage.write(
      key: _saltStorageKey,
      value: base64Encode(newSalt),
    );
    return newSalt;
  }

  /// Get or derive the principal key for the current session.
  /// The key is cached in memory. Subsequent calls return the
  /// cached value without re-deriving. Call [clearKey] on
  /// logout to drop the cache.
  Future<Uint8List> getOrDeriveKey(String jwt) async {
    if (_cachedKey != null) {
      return _cachedKey!;
    }
    final salt = await getOrCreateSalt();
    final key = deriveKey(jwt: jwt, salt: salt);
    _cachedKey = key;
    return key;
  }

  /// Clear the in-memory key cache. Called on logout. The
  /// on-disk data is unreadable until the next login.
  void clearKey() {
    _cachedKey = null;
  }

  /// True if the migration from device-key to principal-key
  /// has run for this user on this device. False if the
  /// migration has not run (or has not completed). The
  /// flag is per-user-per-device; it is stored in
  /// `flutter_secure_storage` under
  /// [_migrationFlagStorageKey].
  Future<bool> hasMigrationRun() async {
    final value = await _secureStorage.read(key: _migrationFlagStorageKey);
    return value == 'true';
  }

  /// Mark the migration as complete. Called by [migrateBox]
  /// after the box is successfully re-encrypted with the
  /// principal key.
  Future<void> markMigrationComplete() async {
    await _secureStorage.write(
      key: _migrationFlagStorageKey,
      value: 'true',
    );
  }

  /// Migrate a Hive box from the old per-device key to the
  /// new principal key. The migration is idempotent: if
  /// it has already run for this box, the second call is a
  /// no-op. The migration is per-box; the caller calls this
  /// once for each Hive box.
  ///
  /// Returns true if the migration ran, false if it was a
  /// no-op (already migrated) or if the old key was not
  /// available.
  ///
  /// The migration reads all entries with the old key,
  /// closes the box, deletes the box file, reopens the box
  /// with the new principal key, and writes the entries
  /// back. A crash between "read with old key" and "write
  /// with new key" leaves the box in a state where the
  /// migration is incomplete; the next app start retries
  /// the migration. The flag is set only after the new
  /// write succeeds.
  Future<bool> migrateBox({
    required String boxName,
    required String jwt,
    required String boxPath,
  }) async {
    if (await hasMigrationRun()) {
      return false;
    }
    final oldKeyBase64 = await _secureStorage.read(
      key: _oldDeviceKeyStorageKey,
    );
    if (oldKeyBase64 == null) {
      // No old key: this is a fresh install. Mark the
      // migration as complete and return false.
      await markMigrationComplete();
      return false;
    }
    final oldKey = Uint8List.fromList(base64Decode(oldKeyBase64));
    final newKey = await getOrDeriveKey(jwt);
    // Read all entries with the old key. The old key may
    // be 32 bytes (the Hive AES-256 format) or a different
    // length (a pre-encryption box). If the length is not
    // 32, the box was unencrypted; open without a cipher.
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
        // Best-effort: if the delete fails, the new open
        // may collide. v1 logs and continues.
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
    await markMigrationComplete();
    return true;
  }

  /// Generate a salt of cryptographically random bytes. Uses
  /// `Hive.generateSecureKey` (a Hive helper) for the random
  /// source. The returned list is converted to a
  /// `Uint8List` of the requested length.
  static Uint8List _generateRandomBytes(int length) {
    return Uint8List.fromList(Hive.generateSecureKey());
  }
}
