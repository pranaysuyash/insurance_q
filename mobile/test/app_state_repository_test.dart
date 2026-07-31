import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coverwise/models/claim_record.dart';
import 'package:coverwise/services/app_state_repository.dart';
import 'package:coverwise/services/app_state_store.dart';

/// Directory for Hive storage, reused across tests in this suite.
late Directory tempDir;

/// Test claim used across tests.
final _testClaim = ClaimRecord(
  id: 'test-1',
  documentId: 'doc-1',
  policyType: 'Health Insurance',
  insurer: 'ICICI Lombard',
  incidentType: 'Hospitalization',
  description: 'Test claim for unit tests',
  filedDate: DateTime(2026, 7, 23),
);

/// Helper: seed a claim directly into Hive without going through AppStateRepository.
Future<void> _seedClaim(ClaimRecord claim) async {
  final box = Hive.box(AppStateStore.boxName);
  final encoded = jsonEncode([claim.toJson()]);
  await box.put(AppStateStore.claimRecordsKey, encoded);
}

/// Helper: clear all claims from Hive.
Future<void> _clearClaims() async {
  final box = Hive.box(AppStateStore.boxName);
  await box.delete(AppStateStore.claimRecordsKey);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    tempDir = await Directory.systemTemp.createTemp('app-state-repo-tests-');
    await Hive.initFlutter(tempDir.path);
    await Hive.openBox(AppStateStore.boxName);
  });

  tearDown(() async {
    await _clearClaims();
  });

  tearDownAll(() async {
    if (Hive.isBoxOpen(AppStateStore.boxName)) {
      await Hive.box(AppStateStore.boxName).close();
    }
  });

  group('AppStateRepository — getClaimRecords', () {
    test('returns empty list when no records exist', () async {
      final records = AppStateRepository.getClaimRecords();
      expect(records, isEmpty);
    });

    test('returns seeded records', () async {
      await _seedClaim(_testClaim);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 1);
      expect(records.first.id, 'test-1');
      expect(records.first.incidentType, 'Hospitalization');
    });
  });

  group('AppStateRepository — updateClaimRecord', () {
    test('updates the reference number on an existing record', () async {
      await _seedClaim(_testClaim);

      final updated = _testClaim.copyWith(referenceNumber: 'CLM-2026-00421');
      await AppStateRepository.updateClaimRecord(updated);

      final records = AppStateRepository.getClaimRecords();
      expect(records.first.referenceNumber, 'CLM-2026-00421');
      // Other fields unchanged
      expect(records.first.insurer, 'ICICI Lombard');
    });

    test('updates the status on an existing record', () async {
      await _seedClaim(_testClaim);

      final updated = _testClaim.withStatusUpdate(ClaimStatus.inReview);
      await AppStateRepository.updateClaimRecord(updated);

      final records = AppStateRepository.getClaimRecords();
      // statusHistory is chronological: [Filed, InReview].
      // toJson → fromJson round-trip infers status from the latest entry.
      expect(records.first.statusHistory.length, 2);
      expect(records.first.statusHistory.last.status, ClaimStatus.inReview);
      expect(records.first.status, ClaimStatus.inReview);
    });

    test('ignores update when record id is not found', () async {
      await _seedClaim(_testClaim);

      final orphan = ClaimRecord(
        id: 'orphan-id',
        documentId: 'doc-99',
        policyType: 'Health',
        insurer: 'None',
        incidentType: 'Other',
        description: 'Orphan record',
        filedDate: DateTime(2026, 7, 23),
      );
      await AppStateRepository.updateClaimRecord(orphan);

      // Original record unchanged
      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 1);
      expect(records.first.id, 'test-1');
    });
  });

  group('AppStateRepository — replaceClaimRecords', () {
    test('replaces all records with new list', () async {
      await _seedClaim(_testClaim);

      final secondClaim = ClaimRecord(
        id: 'test-2',
        documentId: 'doc-2',
        policyType: 'Motor Insurance',
        insurer: 'Bajaj Allianz',
        incidentType: 'Accident',
        description: 'Rear-ended at signal',
        filedDate: DateTime(2026, 7, 24),
        referenceNumber: 'CLM-2026-002',
      );
      await AppStateRepository.replaceClaimRecords([secondClaim]);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 1);
      expect(records.first.id, 'test-2');
      expect(records.first.referenceNumber, 'CLM-2026-002');
    });

    test('saving empty list removes all records', () async {
      await _seedClaim(_testClaim);

      await AppStateRepository.replaceClaimRecords([]);

      final records = AppStateRepository.getClaimRecords();
      expect(records, isEmpty);
    });
  });

  group('AppStateRepository — deleteClaimRecord', () {
    test('removes a specific record by id', () async {
      await _seedClaim(_testClaim);
      expect(AppStateRepository.getClaimRecords(), isNotEmpty);

      await AppStateRepository.deleteClaimRecord('test-1');

      final records = AppStateRepository.getClaimRecords();
      expect(records, isEmpty);
    });

    test('does not throw when record id does not exist', () async {
      await _seedClaim(_testClaim);

      // Should not throw
      await AppStateRepository.deleteClaimRecord('nonexistent-id');

      // Other records remain
      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 1);
    });

    test('removes only the targeted record when multiple exist', () async {
      await _seedClaim(_testClaim);
      final claim2 = ClaimRecord(
        id: 'test-2',
        documentId: 'doc-2',
        policyType: 'Motor Insurance',
        insurer: 'Bajaj Allianz',
        incidentType: 'Accident',
        description: 'Another claim',
        filedDate: DateTime(2026, 7, 24),
      );
      // Seed both
      final box = Hive.box(AppStateStore.boxName);
      await box.put(
        AppStateStore.claimRecordsKey,
        jsonEncode([_testClaim.toJson(), claim2.toJson()]),
      );

      await AppStateRepository.deleteClaimRecord('test-1');

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 1);
      expect(records.first.id, 'test-2');
    });
  });
}
