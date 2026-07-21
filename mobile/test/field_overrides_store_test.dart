import 'dart:convert';
import 'package:coverwise/services/field_overrides_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'helpers/hive_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FieldOverridesStore store;

  setUpAll(() async {
    await HiveTestHelper.setUp();
  });

  setUp(() {
    store = FieldOverridesStore();
  });

  tearDown(() async {
    await store.clearAll();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  group('setOverride and getOverride', () {
    test('sets and retrieves a single override', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'New Insurer',
        originalValue: 'Old Insurer',
      );

      final value = await store.getOverride('doc-1', 'insurer');
      expect(value, 'New Insurer');
    });

    test('returns null for non-existent override', () async {
      final value = await store.getOverride('doc-1', 'insurer');
      expect(value, isNull);
    });

    test('preserves originalValue on re-edit', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'First Edit',
        originalValue: 'Original',
      );
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'Second Edit',
      );

      final overrides = await store.getOverrides('doc-1');
      expect(overrides['insurer']!.value, 'Second Edit');
      expect(overrides['insurer']!.originalValue, 'Original');
    });
  });

  group('getOverrides', () {
    test('returns empty map for document with no overrides', () async {
      final overrides = await store.getOverrides('doc-1');
      expect(overrides, isEmpty);
    });

    test('returns all overrides for a document', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'ICICI',
      );
      await store.setOverride(
        documentId: 'doc-1',
        field: 'policy_number',
        value: 'POL-123',
      );

      final overrides = await store.getOverrides('doc-1');
      expect(overrides.length, 2);
      expect(overrides.containsKey('insurer'), isTrue);
      expect(overrides.containsKey('policy_number'), isTrue);
    });

    test('does not mix overrides across documents', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'ICICI',
      );
      await store.setOverride(
        documentId: 'doc-2',
        field: 'insurer',
        value: 'HDFC',
      );

      final overrides1 = await store.getOverrides('doc-1');
      final overrides2 = await store.getOverrides('doc-2');
      expect(overrides1['insurer']!.value, 'ICICI');
      expect(overrides2['insurer']!.value, 'HDFC');
    });
  });

  group('removeOverride', () {
    test('removes a specific override', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'ICICI',
      );
      await store.setOverride(
        documentId: 'doc-1',
        field: 'policy_number',
        value: 'POL-123',
      );

      await store.removeOverride('doc-1', 'insurer');

      final overrides = await store.getOverrides('doc-1');
      expect(overrides.containsKey('insurer'), isFalse);
      expect(overrides.containsKey('policy_number'), isTrue);
    });

    test('deletes document entry when all overrides removed', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'ICICI',
      );
      await store.removeOverride('doc-1', 'insurer');

      final overrides = await store.getOverrides('doc-1');
      expect(overrides, isEmpty);
    });
  });

  group('clearDocument', () {
    test('clears all overrides for a document', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'ICICI',
      );
      await store.setOverride(
        documentId: 'doc-1',
        field: 'policy_number',
        value: 'POL-123',
      );

      await store.clearDocument('doc-1');

      final overrides = await store.getOverrides('doc-1');
      expect(overrides, isEmpty);
    });
  });

  group('clearAll', () {
    test('clears all overrides across all documents', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'ICICI',
      );
      await store.setOverride(
        documentId: 'doc-2',
        field: 'insurer',
        value: 'HDFC',
      );

      await store.clearAll();

      expect(await store.getOverrides('doc-1'), isEmpty);
      expect(await store.getOverrides('doc-2'), isEmpty);
    });
  });

  group('OverrideRecord', () {
    test('hasOriginal is true when original differs from value', () {
      final record = OverrideRecord(
        value: 'New',
        originalValue: 'Original',
        timestamp: DateTime.now(),
      );
      expect(record.hasOriginal, isTrue);
    });

    test('hasOriginal is false when original is null', () {
      final record = OverrideRecord(
        value: 'New',
        originalValue: null,
        timestamp: DateTime.now(),
      );
      expect(record.hasOriginal, isFalse);
    });

    test('toJson/fromJson round-trip', () {
      final record = OverrideRecord(
        value: 'ICICI',
        originalValue: 'HDFC',
        timestamp: DateTime(2026, 7, 19, 12, 0, 0),
      );
      final json = record.toJson();
      final restored = OverrideRecord.fromJson(json);

      expect(restored.value, 'ICICI');
      expect(restored.originalValue, 'HDFC');
      expect(restored.timestamp, DateTime(2026, 7, 19, 12, 0, 0));
    });
  });

  group('corrupted data handling', () {
    test('handles invalid JSON gracefully', () async {
      final box = await Hive.openBox<String>('field_overrides_box');
      await box.put('doc-corrupted', 'not-valid-json{{{');

      final overrides = await store.getOverrides('doc-corrupted');
      expect(overrides, isEmpty);
    });

    test('handles missing fields in JSON gracefully', () async {
      final box = await Hive.openBox<String>('field_overrides_box');
      await box.put('doc-partial', jsonEncode({'insurer': {'value': 'ICICI'}}));

      final overrides = await store.getOverrides('doc-partial');
      // Should parse what it can, missing timestamp defaults to now
      expect(overrides.containsKey('insurer'), isTrue);
    });
  });

  group('hasOverride', () {
    test('returns true when override exists', () async {
      await store.setOverride(
        documentId: 'doc-1',
        field: 'insurer',
        value: 'ICICI',
      );

      expect(await store.hasOverride('doc-1', 'insurer'), isTrue);
      expect(await store.hasOverride('doc-1', 'policy_number'), isFalse);
    });
  });
}
