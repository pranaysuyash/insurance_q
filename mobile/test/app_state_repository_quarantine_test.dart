import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coverwise/models/claim_record.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/services/app_state_repository.dart';
import 'package:coverwise/services/app_state_store.dart';

/// Directory for Hive storage, reused across tests in this suite.
late Directory tempDir;

/// Helper: seed raw JSON into a Hive key.
Future<void> _seedRaw(String key, String raw) async {
  final box = Hive.box(AppStateStore.boxName);
  await box.put(key, raw);
}

/// Helper: create a valid claim JSON map.
Map<String, dynamic> _validClaimJson(String id) => {
      'id': id,
      'document_id': 'doc-$id',
      'policy_type': 'Health',
      'insurer': 'Test',
      'incident_type': 'Hospitalization',
      'description': 'Test claim $id',
      'filed_date': '2026-07-23T00:00:00.000',
      'status': 'filed',
    };

/// Helper: create a valid family member JSON map.
Map<String, dynamic> _validFamilyJson(String name) => {
      'name': name,
      'relationship': 'Spouse',
    };

/// Helper: create a valid resolved gap JSON map.
Map<String, dynamic> _validGapJson(String notes) => {
      'resolvedAt': '2026-07-23T00:00:00.000',
      'notes': notes,
    };

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
    tempDir = await Directory.systemTemp.createTemp('quarantine-tests-');
    await Hive.initFlutter(tempDir.path);
    await Hive.openBox(AppStateStore.boxName);
  });

  tearDown(() async {
    final box = Hive.box(AppStateStore.boxName);
    await box.clear();
  });

  tearDownAll(() async {
    if (Hive.isBoxOpen(AppStateStore.boxName)) {
      await Hive.box(AppStateStore.boxName).close();
    }
  });

  // ---------------------------------------------------------------------------
  // Claim record quarantine
  // ---------------------------------------------------------------------------
  group('getClaimRecords quarantine', () {
    test('quarantines non-Map values and preserves valid records', () async {
      // Non-Map values (int, String, null) cause a cast exception and are
      // quarantined. Maps with missing/wrong fields are parsed with defaults
      // (ClaimRecord.fromJson is lenient on field presence).
      final data = jsonEncode([
        _validClaimJson('c1'),
        42, // not a Map — quarantined
        'also bad', // not a Map — quarantined
        _validClaimJson('c2'),
      ]);
      await _seedRaw(AppStateStore.claimRecordsKey, data);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 2);
      expect(records[0].id, 'c1');
      expect(records[1].id, 'c2');
    });

    test('returns all records when none are malformed', () async {
      final data = jsonEncode([
        _validClaimJson('c1'),
        _validClaimJson('c2'),
        _validClaimJson('c3'),
      ]);
      await _seedRaw(AppStateStore.claimRecordsKey, data);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 3);
    });

    test('returns empty when every record is a non-Map type', () async {
      final data = jsonEncode([42, true, 'bad']);
      await _seedRaw(AppStateStore.claimRecordsKey, data);

      final records = AppStateRepository.getClaimRecords();
      expect(records, isEmpty);
    });

    test('returns empty when top-level JSON is not a list', () async {
      await _seedRaw(
          AppStateStore.claimRecordsKey, '{"not": "a list"}');

      final records = AppStateRepository.getClaimRecords();
      expect(records, isEmpty);
    });

    test('returns empty when top-level JSON is corrupt', () async {
      await _seedRaw(
          AppStateStore.claimRecordsKey, '{invalid json!!!');

      final records = AppStateRepository.getClaimRecords();
      expect(records, isEmpty);
    });

    test('quarantines non-Map record at the beginning', () async {
      final data = jsonEncode([
        42, // not a Map
        _validClaimJson('c1'),
      ]);
      await _seedRaw(AppStateStore.claimRecordsKey, data);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 1);
      expect(records.first.id, 'c1');
    });

    test('quarantines non-Map record at the end', () async {
      final data = jsonEncode([
        _validClaimJson('c1'),
        42, // wrong type — not a Map
      ]);
      await _seedRaw(AppStateStore.claimRecordsKey, data);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 1);
      expect(records.first.id, 'c1');
    });

    test('quarantines multiple non-adjacent non-Map records', () async {
      final data = jsonEncode([
        _validClaimJson('c1'),
        true, // not a Map
        _validClaimJson('c2'),
        'also bad', // not a Map
        _validClaimJson('c3'),
      ]);
      await _seedRaw(AppStateStore.claimRecordsKey, data);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 3);
      expect(records.map((r) => r.id), ['c1', 'c2', 'c3']);
    });

    test('quarantines mixed non-Map types', () async {
      final data = jsonEncode([
        _validClaimJson('c1'),
        'not a map at all',
        _validClaimJson('c2'),
      ]);
      await _seedRaw(AppStateStore.claimRecordsKey, data);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Manual family members quarantine
  // ---------------------------------------------------------------------------
  group('getManualFamilyMembers quarantine', () {
    test('returns valid members and skips non-Map entries', () async {
      final data = jsonEncode([
        _validFamilyJson('Priya'),
        42, // not a Map — quarantined
        _validFamilyJson('Aarav'),
      ]);
      await _seedRaw(AppStateStore.manualFamilyMembersKey, data);

      final members = AppStateRepository.getManualFamilyMembers();

      expect(members.length, 2);
      expect(members[0].name, 'Priya');
      expect(members[1].name, 'Aarav');
    });

    test('returns all members when none are malformed', () async {
      final data = jsonEncode([
        _validFamilyJson('Priya'),
        _validFamilyJson('Aarav'),
      ]);
      await _seedRaw(AppStateStore.manualFamilyMembersKey, data);

      final members = AppStateRepository.getManualFamilyMembers();
      expect(members.length, 2);
    });

    test('returns empty when every entry is a non-Map type', () async {
      final data = jsonEncode([42, true, 'bad']);
      await _seedRaw(AppStateStore.manualFamilyMembersKey, data);

      final members = AppStateRepository.getManualFamilyMembers();
      expect(members, isEmpty);
    });

    test('returns empty when top-level JSON is not a list', () async {
      await _seedRaw(
          AppStateStore.manualFamilyMembersKey, '{"not": "a list"}');

      final members = AppStateRepository.getManualFamilyMembers();
      expect(members, isEmpty);
    });

    test('returns empty when Hive key is absent', () {
      final members = AppStateRepository.getManualFamilyMembers();
      expect(members, isEmpty);
    });

    test('quarantines non-adjacent non-Map entries', () async {
      final data = jsonEncode([
        _validFamilyJson('Priya'),
        null, // null is not a Map — quarantined
        _validFamilyJson('Anika'),
        42, // not a Map — quarantined
        _validFamilyJson('Rahul'),
      ]);
      await _seedRaw(AppStateStore.manualFamilyMembersKey, data);

      final members = AppStateRepository.getManualFamilyMembers();
      expect(members.length, 3);
      expect(members.map((m) => m.name), ['Priya', 'Anika', 'Rahul']);
    });
  });

  // ---------------------------------------------------------------------------
  // Resolved gaps quarantine
  // ---------------------------------------------------------------------------
  group('getResolvedGaps quarantine', () {
    test('returns valid entries and skips a malformed entry', () async {
      // Hive stores Map directly, not as JSON string.
      final box = Hive.box(AppStateStore.boxName);
      await box.put(AppStateStore.resolvedGapsKey, {
        'gap-1': _validGapJson('Fixed roof'),
        'gap-2': 'not a map',
        'gap-3': _validGapJson('Added coverage'),
      });

      final gaps = AppStateRepository.getResolvedGaps();

      expect(gaps.length, 2);
      expect(gaps.containsKey('gap-1'), isTrue);
      expect(gaps.containsKey('gap-3'), isTrue);
      expect(gaps.containsKey('gap-2'), isFalse);
    });

    test('returns all entries when none are malformed', () async {
      final box = Hive.box(AppStateStore.boxName);
      await box.put(AppStateStore.resolvedGapsKey, {
        'gap-1': _validGapJson('Notes 1'),
        'gap-2': _validGapJson('Notes 2'),
      });

      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps.length, 2);
    });

    test('returns empty when every entry is malformed', () async {
      final box = Hive.box(AppStateStore.boxName);
      await box.put(AppStateStore.resolvedGapsKey, {
        'gap-1': 'bad value',
        'gap-2': 42,
      });

      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps, isEmpty);
    });

    test('returns empty when Hive key is not a map', () async {
      final box = Hive.box(AppStateStore.boxName);
      await box.put(AppStateStore.resolvedGapsKey, 'not a map');

      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps, isEmpty);
    });

    test('returns empty when Hive key is absent', () {
      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps, isEmpty);
    });

    test('preserves valid entries with null values in map', () async {
      // A map entry where the value is null should be quarantined
      // (cannot cast null to Map).
      final box = Hive.box(AppStateStore.boxName);
      await box.put(AppStateStore.resolvedGapsKey, {
        'gap-1': _validGapJson('Valid'),
        'gap-2': null,
      });

      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps.length, 1);
      expect(gaps.containsKey('gap-1'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // addClaimRecord serialization (P0.9)
  // ---------------------------------------------------------------------------
  group('addClaimRecord serialization', () {
    test('serialized adds do not lose records', () async {
      // Fire 3 addClaimRecord calls concurrently. The write lock should
      // serialize them so all 3 records end up in Hive.
      final claim1 = _claimRecord('s1');
      final claim2 = _claimRecord('s2');
      final claim3 = _claimRecord('s3');

      await Future.wait([
        AppStateRepository.addClaimRecord(claim1),
        AppStateRepository.addClaimRecord(claim2),
        AppStateRepository.addClaimRecord(claim3),
      ]);

      final records = AppStateRepository.getClaimRecords();
      expect(records.length, 3);
      final ids = records.map((r) => r.id).toSet();
      expect(ids, containsAll(['s1', 's2', 's3']));
    });
  });

  // ---------------------------------------------------------------------------
  // addManualFamilyMember serialization (P0.9)
  // ---------------------------------------------------------------------------
  group('addManualFamilyMember serialization', () {
    test('serialized adds do not lose members', () async {
      await Future.wait([
        AppStateRepository.addManualFamilyMember(
            _familyMember('Priya')),
        AppStateRepository.addManualFamilyMember(
            _familyMember('Aarav')),
        AppStateRepository.addManualFamilyMember(
            _familyMember('Anika')),
      ]);

      final members = AppStateRepository.getManualFamilyMembers();
      expect(members.length, 3);
      final names = members.map((m) => m.name).toSet();
      expect(names, containsAll(['Priya', 'Aarav', 'Anika']));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers that create real model objects for the write-lock tests.
// ---------------------------------------------------------------------------

ClaimRecord _claimRecord(String id) => ClaimRecord(
      id: id,
      documentId: 'doc-$id',
      policyType: 'Health',
      insurer: 'Test',
      incidentType: 'Hospitalization',
      description: 'Test $id',
      filedDate: DateTime(2026, 7, 23),
    );

PolicyHolder _familyMember(String name) => PolicyHolder(
      name: name,
      relationship: 'Spouse',
    );
