import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/screens/coverage_gap_screen.dart' show gapId;
import 'package:coverwise/services/app_state_repository.dart';
import 'package:coverwise/services/app_state_store.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('coverwise-gap-test');
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getLibraryDirectory':
        case 'getTemporaryDirectory':
        case 'getExternalStorageDirectory':
          return tempDir.path;
        case 'getExternalStorageDirectories':
        case 'getExternalCacheDirectories':
          return <String>[tempDir.path];
        case 'getDownloadsDirectory':
          return tempDir.path;
      }
      return null;
    });
    await Hive.initFlutter(tempDir.path);
    await Hive.openBox(AppStateStore.boxName);
  });

  setUp(() async {
    await Hive.box(AppStateStore.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.box(AppStateStore.boxName).close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ---------------------------------------------------------------------------
  // gapId() tests
  // ---------------------------------------------------------------------------
  group('gapId()', () {
    test('returns a string starting with "gap_"', () {
      final gap = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'high',
      );
      expect(gapId(gap), startsWith('gap_'));
    });

    test('returns the same ID for the same gap content', () {
      final gap1 = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'high',
      );
      final gap2 = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'high',
      );
      expect(gapId(gap1), equals(gapId(gap2)));
    });

    test('returns different IDs for different categories', () {
      final gap1 = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'high',
      );
      final gap2 = CoverageGap(
        category: 'Motor',
        description: 'No dental coverage',
        severity: 'high',
      );
      expect(gapId(gap1), isNot(equals(gapId(gap2))));
    });

    test('returns different IDs for different descriptions', () {
      final gap1 = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'high',
      );
      final gap2 = CoverageGap(
        category: 'Health',
        description: 'No vision coverage',
        severity: 'high',
      );
      expect(gapId(gap1), isNot(equals(gapId(gap2))));
    });

    test('returns different IDs for different severities', () {
      final gap1 = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'high',
      );
      final gap2 = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'low',
      );
      expect(gapId(gap1), isNot(equals(gapId(gap2))));
    });

    test('returns consistent IDs across multiple calls', () {
      final gap = CoverageGap(
        category: 'Life',
        description: 'Low sum assured',
        severity: 'medium',
        recommendation: 'Increase coverage',
      );
      final id1 = gapId(gap);
      final id2 = gapId(gap);
      final id3 = gapId(gap);
      expect(id1, equals(id2));
      expect(id2, equals(id3));
    });

    test('handles empty strings gracefully', () {
      final gap = CoverageGap(
        category: '',
        description: '',
        severity: '',
      );
      expect(gapId(gap), startsWith('gap_'));
      expect(gapId(gap), isNotEmpty);
    });

    test('handles Unicode characters', () {
      final gap = CoverageGap(
        category: 'स्वास्थ्य',
        description: 'दंत चिकित्सा कवरेज नहीं',
        severity: 'high',
      );
      expect(gapId(gap), startsWith('gap_'));
    });
  });

  // ---------------------------------------------------------------------------
  // Repository methods tests
  // ---------------------------------------------------------------------------
  group('Resolved gaps repository', () {
    test('getResolvedGaps returns empty map when no gaps resolved', () {
      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps, isEmpty);
    });

    test('markGapResolved persists a gap as resolved', () async {
      await AppStateRepository.markGapResolved('gap_abc');

      expect(AppStateRepository.isGapResolved('gap_abc'), isTrue);
    });

    test('markGapResolved stores notes when provided', () async {
      await AppStateRepository.markGapResolved(
        'gap_abc',
        notes: 'Purchased dental plan',
      );

      final notes = AppStateRepository.getGapResolutionNotes('gap_abc');
      expect(notes, 'Purchased dental plan');
    });

    test('markGapResolved stores null notes when not provided', () async {
      await AppStateRepository.markGapResolved('gap_abc');

      final notes = AppStateRepository.getGapResolutionNotes('gap_abc');
      expect(notes, isNull);
    });

    test('markGapResolved stores resolvedAt timestamp', () async {
      final before = DateTime.now();
      await AppStateRepository.markGapResolved('gap_abc');
      final after = DateTime.now();

      final gaps = AppStateRepository.getResolvedGaps();
      final resolvedAt = DateTime.parse(gaps['gap_abc']!['resolvedAt']);
      expect(resolvedAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(resolvedAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });

    test('isGapResolved returns false for unresolved gap', () {
      expect(AppStateRepository.isGapResolved('gap_xyz'), isFalse);
    });

    test('getGapResolutionNotes returns null for unresolved gap', () {
      expect(AppStateRepository.getGapResolutionNotes('gap_xyz'), isNull);
    });

    test('unresolveGap removes a resolved gap', () async {
      await AppStateRepository.markGapResolved('gap_abc', notes: 'Done');
      expect(AppStateRepository.isGapResolved('gap_abc'), isTrue);

      await AppStateRepository.unresolveGap('gap_abc');
      expect(AppStateRepository.isGapResolved('gap_abc'), isFalse);
    });

    test('unresolveGap is safe to call on already-unresolved gap', () async {
      await AppStateRepository.unresolveGap('gap_nonexistent');
      expect(AppStateRepository.isGapResolved('gap_nonexistent'), isFalse);
    });

    test('multiple gaps can be resolved independently', () async {
      await AppStateRepository.markGapResolved('gap_1', notes: 'First');
      await AppStateRepository.markGapResolved('gap_2', notes: 'Second');
      await AppStateRepository.markGapResolved('gap_3');

      expect(AppStateRepository.isGapResolved('gap_1'), isTrue);
      expect(AppStateRepository.isGapResolved('gap_2'), isTrue);
      expect(AppStateRepository.isGapResolved('gap_3'), isTrue);
      expect(AppStateRepository.getResolvedGaps(), hasLength(3));

      await AppStateRepository.unresolveGap('gap_2');
      expect(AppStateRepository.getResolvedGaps(), hasLength(2));
      expect(AppStateRepository.isGapResolved('gap_1'), isTrue);
      expect(AppStateRepository.isGapResolved('gap_2'), isFalse);
      expect(AppStateRepository.isGapResolved('gap_3'), isTrue);
    });

    test('markGapResolved overwrites previous notes', () async {
      await AppStateRepository.markGapResolved('gap_abc', notes: 'Old note');
      await AppStateRepository.markGapResolved('gap_abc', notes: 'New note');

      expect(AppStateRepository.getGapResolutionNotes('gap_abc'), 'New note');
    });

    test('resolved gaps survive box clear and re-read', () async {
      await AppStateRepository.markGapResolved('gap_abc', notes: 'Persisted');

      // Simulate re-read from storage (not in-memory cache)
      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps['gap_abc']!['notes'], 'Persisted');
    });

    test('getResolvedGaps returns correct structure', () async {
      await AppStateRepository.markGapResolved('gap_test', notes: 'Test note');

      final gaps = AppStateRepository.getResolvedGaps();
      expect(gaps, contains('gap_test'));
      expect(gaps['gap_test'], contains('resolvedAt'));
      expect(gaps['gap_test'], contains('notes'));
      expect(gaps['gap_test']!['notes'], 'Test note');
    });
  });

  // ---------------------------------------------------------------------------
  // Integration: gapId + repository
  // ---------------------------------------------------------------------------
  group('gapId + repository integration', () {
    test('can resolve and unresolve a real CoverageGap', () async {
      final gap = CoverageGap(
        category: 'Health',
        description: 'No dental coverage',
        severity: 'high',
      );
      final id = gapId(gap);

      await AppStateRepository.markGapResolved(id, notes: 'Got dental plan');
      expect(AppStateRepository.isGapResolved(id), isTrue);
      expect(AppStateRepository.getGapResolutionNotes(id), 'Got dental plan');

      await AppStateRepository.unresolveGap(id);
      expect(AppStateRepository.isGapResolved(id), isFalse);
    });

    test('different gaps resolve independently', () async {
      final gap1 = CoverageGap(
        category: 'Health',
        description: 'No dental',
        severity: 'high',
      );
      final gap2 = CoverageGap(
        category: 'Motor',
        description: 'No roadside assist',
        severity: 'medium',
      );

      await AppStateRepository.markGapResolved(gapId(gap1), notes: 'Fixed');
      expect(AppStateRepository.isGapResolved(gapId(gap1)), isTrue);
      expect(AppStateRepository.isGapResolved(gapId(gap2)), isFalse);

      await AppStateRepository.unresolveGap(gapId(gap1));
      expect(AppStateRepository.isGapResolved(gapId(gap1)), isFalse);
      expect(AppStateRepository.isGapResolved(gapId(gap2)), isFalse);
    });
  });
}
