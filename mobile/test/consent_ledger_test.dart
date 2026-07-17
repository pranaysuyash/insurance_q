import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:coverwise/services/app_state_store.dart';

void main() {
  late Box box;

  setUp(() async {
    // Initialize Hive for tests if not already done.
    if (!Hive.isBoxOpen(AppStateStore.boxName)) {
      Hive.init('test_hive');
      box = await Hive.openBox(AppStateStore.boxName);
    } else {
      box = Hive.box(AppStateStore.boxName);
    }
    // Clear the consent ledger before each test.
    await box.delete('consent_ledger_v1');
  });

  tearDown(() async {
    await box.delete('consent_ledger_v1');
  });

  group('ConsentPurpose', () {
    test('fromString returns correct purpose', () {
      expect(ConsentPurpose.fromString('document_processing'),
          ConsentPurpose.documentProcessing);
      expect(ConsentPurpose.fromString('analytics'),
          ConsentPurpose.analytics);
      expect(ConsentPurpose.fromString('lead_capture'),
          ConsentPurpose.leadCapture);
    });

    test('fromString returns null for unknown purpose', () {
      expect(ConsentPurpose.fromString('unknown'), isNull);
      expect(ConsentPurpose.fromString(''), isNull);
    });

    test('value getter returns correct string', () {
      expect(ConsentPurpose.documentProcessing.value, 'document_processing');
      expect(ConsentPurpose.analytics.value, 'analytics');
      expect(ConsentPurpose.leadCapture.value, 'lead_capture');
    });
  });

  group('ConsentRecord', () {
    test('isActive returns true when granted and not revoked', () {
      final record = ConsentRecord(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(record.isActive, isTrue);
      expect(record.isRevoked, isFalse);
    });

    test('isActive returns false when granted but revoked', () {
      final record = ConsentRecord(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
        timestamp: DateTime(2026, 1, 1),
        revokedAt: DateTime(2026, 6, 1),
      );
      expect(record.isActive, isFalse);
      expect(record.isRevoked, isTrue);
    });

    test('isActive returns false when not granted', () {
      final record = ConsentRecord(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: false,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(record.isActive, isFalse);
      expect(record.isRevoked, isFalse);
    });

    test('toJson serializes correctly', () {
      final record = ConsentRecord(
        purpose: ConsentPurpose.analytics,
        version: 'v2',
        granted: true,
        timestamp: DateTime(2026, 7, 15, 12, 30),
      );
      final json = record.toJson();
      expect(json['purpose'], 'analytics');
      expect(json['version'], 'v2');
      expect(json['granted'], true);
      expect(json['timestamp'], '2026-07-15T12:30:00.000');
      expect(json.containsKey('revoked_at'), isFalse);
    });

    test('toJson includes revoked_at when revoked', () {
      final record = ConsentRecord(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
        timestamp: DateTime(2026, 1, 1),
        revokedAt: DateTime(2026, 6, 1),
      );
      final json = record.toJson();
      expect(json.containsKey('revoked_at'), isTrue);
      expect(json['revoked_at'], '2026-06-01T00:00:00.000');
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'purpose': 'lead_capture',
        'version': 'v1',
        'granted': true,
        'timestamp': '2026-07-15T12:30:00.000',
      };
      final record = ConsentRecord.fromJson(json);
      expect(record.purpose, ConsentPurpose.leadCapture);
      expect(record.version, 'v1');
      expect(record.granted, isTrue);
      expect(record.revokedAt, isNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final record = ConsentRecord.fromJson({});
      expect(record.purpose, ConsentPurpose.documentProcessing);
      expect(record.version, 'unknown');
      expect(record.granted, isFalse);
      expect(record.revokedAt, isNull);
    });

    test('fromJson handles revoked_at', () {
      final json = {
        'purpose': 'analytics',
        'version': 'v1',
        'granted': true,
        'timestamp': '2026-01-01T00:00:00.000',
        'revoked_at': '2026-06-01T00:00:00.000',
      };
      final record = ConsentRecord.fromJson(json);
      expect(record.revokedAt, isNotNull);
      expect(record.isRevoked, isTrue);
    });

    test('round-trip serialization preserves data', () {
      final original = ConsentRecord(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v3',
        granted: true,
        timestamp: DateTime(2026, 7, 15),
        revokedAt: DateTime(2026, 8, 1),
      );
      final restored = ConsentRecord.fromJson(original.toJson());
      expect(restored.purpose, original.purpose);
      expect(restored.version, original.version);
      expect(restored.granted, original.granted);
      expect(restored.isRevoked, original.isRevoked);
    });
  });

  group('ConsentLedger', () {
    late ConsentLedger ledger;

    setUp(() {
      ledger = ConsentLedger();
    });

    test('hasConsent returns false when no records exist', () {
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
      expect(ledger.hasConsent(ConsentPurpose.analytics), isFalse);
    });

    test('recordConsent stores a grant', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isTrue);
    });

    test('recordConsent stores a revoke', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: false,
      );
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('hasConsent returns true only for the specified purpose', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isTrue);
      expect(ledger.hasConsent(ConsentPurpose.analytics), isFalse);
      expect(ledger.hasConsent(ConsentPurpose.leadCapture), isFalse);
    });

    test('revokeConsent revokes the latest active record', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isTrue);

      await ledger.revokeConsent(ConsentPurpose.documentProcessing);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('revokeConsent does nothing when no active record exists', () async {
      // Revoke when no consent was ever granted — should not throw.
      await ledger.revokeConsent(ConsentPurpose.analytics);
      expect(ledger.hasConsent(ConsentPurpose.analytics), isFalse);
    });

    test('revokeConsent only revokes the latest active record', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'v1',
        granted: true,
      );

      await ledger.revokeConsent(ConsentPurpose.documentProcessing);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
      expect(ledger.hasConsent(ConsentPurpose.analytics), isTrue);
    });

    test('getLatestRecord returns the most recent record for a purpose', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v2',
        granted: true,
      );

      final latest = ledger.getLatestRecord(ConsentPurpose.documentProcessing);
      expect(latest, isNotNull);
      expect(latest!.version, 'v2');
    });

    test('getLatestRecord returns null when no records exist', () {
      final latest = ledger.getLatestRecord(ConsentPurpose.documentProcessing);
      expect(latest, isNull);
    });

    test('getAllRecords returns all records', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'v1',
        granted: true,
      );

      final records = ledger.getAllRecords();
      expect(records.length, 2);
      expect(records[0].purpose, ConsentPurpose.documentProcessing);
      expect(records[1].purpose, ConsentPurpose.analytics);
    });

    test('clear removes all records', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'v1',
        granted: true,
      );

      await ledger.clear();
      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('multiple grants and revokes maintain correct history', () async {
      // Grant → Revoke → Grant cycle.
      // revokeConsent replaces the record in-place (adds revokedAt),
      // so the total count is: 1 grant + 1 revoke + 1 grant = 3 records.
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isTrue);

      await ledger.revokeConsent(ConsentPurpose.documentProcessing);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);

      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v2',
        granted: true,
      );
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isTrue);

      final records = ledger.getAllRecords();
      // revokeConsent replaces the record in-place, so we get:
      // [grant v1 (revoked), grant v2 (active)] = 2 records
      expect(records.length, 2);
      expect(records[0].version, 'v1');
      expect(records[0].isRevoked, isTrue);
      expect(records[1].version, 'v2');
      expect(records[1].isActive, isTrue);
    });

    test('hasConsent returns the latest state after grant then revoke', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.leadCapture,
        version: 'v1',
        granted: true,
      );
      await ledger.revokeConsent(ConsentPurpose.leadCapture);
      expect(ledger.hasConsent(ConsentPurpose.leadCapture), isFalse);
    });

    test('consent persists across ConsentLedger instances', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );

      // Create a new instance — it reads from the same Hive box.
      final ledger2 = ConsentLedger();
      expect(ledger2.hasConsent(ConsentPurpose.documentProcessing), isTrue);
    });
  });

  group('ConsentLedger — corrupted data handling', () {
    late ConsentLedger ledger;

    setUp(() async {
      // Ensure clean state — the outer setUp already deletes the key,
      // but we double-check to prevent cross-test leakage.
      await box.delete('consent_ledger_v1');
      ledger = ConsentLedger();
    });

    test('handles null value in Hive gracefully', () async {
      // Write null directly to the Hive key.
      await box.put('consent_ledger_v1', null);

      // Should not throw — returns empty list.
      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
      expect(ledger.getLatestRecord(ConsentPurpose.documentProcessing), isNull);
    });

    test('handles non-string value in Hive gracefully', () async {
      // Write an integer instead of a JSON string.
      await box.put('consent_ledger_v1', 42);

      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles invalid JSON string gracefully', () async {
      // Write a string that is not valid JSON.
      await box.put('consent_ledger_v1', '{corrupted json!!!');

      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles non-list JSON gracefully', () async {
      // Write valid JSON but not a list (e.g., an object).
      await box.put('consent_ledger_v1', '{"not": "a list"}');

      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles empty JSON array gracefully', () async {
      await box.put('consent_ledger_v1', '[]');

      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles corrupted record within valid array', () async {
      // Write an array with one valid and one corrupted record.
      final validRecord = {
        'purpose': 'document_processing',
        'version': 'v1',
        'granted': true,
        'timestamp': '2026-07-15T00:00:00.000',
      };
      final corruptedRecord = {
        'purpose': 'not_a_real_purpose',
        'version': 'v1',
        'granted': true,
        'timestamp': 'invalid-date',
      };
      final jsonArray = jsonEncode([validRecord, corruptedRecord]);
      await box.put('consent_ledger_v1', jsonArray);

      // Should not throw — corrupted record gets defaults from fromJson.
      final records = ledger.getAllRecords();
      expect(records.length, 2);
      // Corrupted purpose 'not_a_real_purpose' falls back to documentProcessing.
      // Version 'v1' is preserved because fromJson only defaults version to 'unknown' when null.
      expect(records[1].purpose, ConsentPurpose.documentProcessing);
      expect(records[1].version, 'v1');
      // Invalid timestamp falls back to DateTime.now().
      expect(records[1].timestamp, isNotNull);
    });

    test('can write new records after corrupted data recovery', () async {
      // Corrupt the data.
      await box.put('consent_ledger_v1', 'not-json');

      // Should recover gracefully.
      expect(ledger.getAllRecords(), isEmpty);

      // Should be able to write new records after recovery.
      await ledger.recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: 'v1',
        granted: true,
      );
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isTrue);

      // Verify persistence works after recovery.
      final ledger2 = ConsentLedger();
      expect(ledger2.hasConsent(ConsentPurpose.documentProcessing), isTrue);
    });

    test('clear works after corrupted data recovery', () async {
      // Corrupt the data.
      await box.put('consent_ledger_v1', 'bad-data');

      // Should not throw on clear.
      await ledger.clear();
      expect(ledger.getAllRecords(), isEmpty);
    });
  });
}
