import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'helpers/hive_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Box consentBox;

  setUpAll(() async {
    await HiveTestHelper.setUp();
  });

  setUp(() async {
    consentBox = Hive.box('consent_ledger');
    await consentBox.clear();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  group('ConsentPurpose', () {
    test('fromString returns correct purpose', () {
      expect(ConsentPurpose.fromString('document_processing'),
          ConsentPurpose.documentProcessing);
      expect(ConsentPurpose.fromString('analytics'),
          ConsentPurpose.analytics);
      expect(ConsentPurpose.fromString('marketing_emails'),
          ConsentPurpose.marketingEmails);
      expect(ConsentPurpose.fromString('privacy_policy'),
          ConsentPurpose.privacyPolicy);
    });

    test('fromString returns null for unknown purpose', () {
      expect(ConsentPurpose.fromString('unknown'), isNull);
      expect(ConsentPurpose.fromString(''), isNull);
    });

    test('value getter returns correct string', () {
      expect(ConsentPurpose.documentProcessing.value, 'document_processing');
      expect(ConsentPurpose.analytics.value, 'analytics');
      expect(ConsentPurpose.marketingEmails.value, 'marketing_emails');
      expect(ConsentPurpose.privacyPolicy.value, 'privacy_policy');
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
        'purpose': 'marketing_emails',
        'version': 'v1',
        'granted': true,
        'timestamp': '2026-07-15T12:30:00.000',
      };
      final record = ConsentRecord.fromJson(json);
      expect(record.purpose, ConsentPurpose.marketingEmails);
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
      expect(ledger.hasConsent(ConsentPurpose.marketingEmails), isFalse);
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
      await Future.delayed(const Duration(milliseconds: 15));
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'v1',
        granted: true,
      );

      final records = ledger.getAllRecords();
      expect(records.length, 2);
      // Sorted descending by timestamp — analytics (recorded later) comes first.
      expect(records[0].purpose, ConsentPurpose.analytics);
      expect(records[1].purpose, ConsentPurpose.documentProcessing);
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
      // The ledger is append-only: each operation adds a new record.
      // grant v1 + revoke v1 + grant v2 = 3 records total.
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
      // Sorted descending by timestamp: grant v2, revoke v1, grant v1.
      expect(records.length, 3);
      expect(records[0].version, 'v2');
      expect(records[0].isActive, isTrue);
      expect(records[1].version, 'v1');
      expect(records[1].isRevoked, isTrue);
      expect(records[2].version, 'v1');
      expect(records[2].isActive, isTrue);
    });

    test('hasConsent returns the latest state after grant then revoke', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.marketingEmails,
        version: 'v1',
        granted: true,
      );
      await ledger.revokeConsent(ConsentPurpose.marketingEmails);
      expect(ledger.hasConsent(ConsentPurpose.marketingEmails), isFalse);
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
      // Ensure clean state — the outer setUp already clears consent_ledger,
      // but we double-check to prevent cross-test leakage.
      await consentBox.clear();
      ledger = ConsentLedger();
    });

    test('handles null value in Hive gracefully', () async {
      // The consent_ledger box uses _box.add() which stores individual items.
      // Writing null as a raw value to simulate corruption.
      await consentBox.add(null);

      // Should not throw — corrupted items are skipped.
      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
      expect(ledger.getLatestRecord(ConsentPurpose.documentProcessing), isNull);
    });

    test('handles non-map value in Hive gracefully', () async {
      // Write an integer instead of a JSON map.
      await consentBox.add(42);

      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles invalid data gracefully', () async {
      // Write a string that is not a valid map.
      await consentBox.add('not-a-map');

      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles non-map value gracefully', () async {
      // Write a list instead of a map — fromJson expects Map<String, dynamic>.
      await consentBox.add(['not', 'a', 'map']);

      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles empty box gracefully', () async {
      // Box is already cleared by setUp.
      expect(ledger.getAllRecords(), isEmpty);
      expect(ledger.hasConsent(ConsentPurpose.documentProcessing), isFalse);
    });

    test('handles corrupted record alongside valid records', () async {
      // Add one valid record and one corrupted record via _box.add().
      final validRecord = {
        'purpose': 'document_processing',
        'version': 'v1',
        'granted': true,
        'timestamp': '2026-07-15T00:00:00.000',
      };
      await consentBox.add(validRecord);
      await consentBox.add('corrupted-not-a-map');

      // Should not throw — corrupted record is skipped by fromJson catch.
      final records = ledger.getAllRecords();
      expect(records.length, 1);
      expect(records[0].purpose, ConsentPurpose.documentProcessing);
      expect(records[0].version, 'v1');
    });

    test('can write new records after corrupted data recovery', () async {
      // Add corrupted data.
      await consentBox.add('not-a-map');

      // Should recover gracefully — corrupted items are skipped.
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
      // Add corrupted data.
      await consentBox.add('bad-data');

      // Should not throw on clear.
      await ledger.clear();
      expect(ledger.getAllRecords(), isEmpty);
    });

    test('isPrivacyPolicyAccepted returns false when no record exists', () {
      ledger.clear();
      expect(ledger.isPrivacyPolicyAccepted('v1'), isFalse);
    });

    test('isPrivacyPolicyAccepted returns true when version matches', () async {
      await ledger.recordPolicyAcceptance(version: 'v2');
      expect(ledger.isPrivacyPolicyAccepted('v2'), isTrue);
    });

    test('isPrivacyPolicyAccepted returns false when version differs', () async {
      await ledger.recordPolicyAcceptance(version: 'v1');
      expect(ledger.isPrivacyPolicyAccepted('v2'), isFalse);
    });

    test('isPrivacyPolicyAccepted returns false when revoked', () async {
      await ledger.recordPolicyAcceptance(version: 'v1');
      await ledger.revokeConsent(ConsentPurpose.privacyPolicy);
      expect(ledger.isPrivacyPolicyAccepted('v1'), isFalse);
    });

    test('recordPolicyAcceptance stores correct version', () async {
      await ledger.recordPolicyAcceptance(version: '2026-07-22');
      final record = ledger.getLatestRecord(ConsentPurpose.privacyPolicy);
      expect(record, isNotNull);
      expect(record!.version, '2026-07-22');
      expect(record.granted, isTrue);
    });

    test('isPrivacyPolicyAccepted updates when new version is recorded', () async {
      await ledger.recordPolicyAcceptance(version: 'v1');
      expect(ledger.isPrivacyPolicyAccepted('v1'), isTrue);
      expect(ledger.isPrivacyPolicyAccepted('v2'), isFalse);

      await ledger.recordPolicyAcceptance(version: 'v2');
      expect(ledger.isPrivacyPolicyAccepted('v1'), isFalse);
      expect(ledger.isPrivacyPolicyAccepted('v2'), isTrue);
    });
  });
}
