import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/documents_list.dart';
import 'package:coverwise/models/document_model.dart';

/// Helper to create a test document with configurable fields.
InsuranceDocument _doc({
  required String filename,
  required DateTime uploadedOn,
  String? documentType,
}) {
  return InsuranceDocument(
    id: filename.hashCode.toString(),
    filename: filename,
    uploadedOn: uploadedOn,
    documentType: documentType,
  );
}

void main() {
  // canonicalTypeName returns: 'Health Insurance', 'Auto Insurance',
  // 'Life Insurance', 'Travel Insurance', etc.
  final docs = [
    _doc(
        filename: 'Health_Policy.pdf',
        uploadedOn: DateTime(2025, 6, 1),
        documentType: 'Health'),
    _doc(
        filename: 'Motor_Insurance.pdf',
        uploadedOn: DateTime(2025, 3, 15),
        documentType: 'Motor'),
    _doc(
        filename: 'Life_Cover.pdf',
        uploadedOn: DateTime(2025, 8, 20),
        documentType: 'Life'),
    _doc(
        filename: 'Another_Health.pdf',
        uploadedOn: DateTime(2025, 1, 10),
        documentType: 'Health'),
    _doc(
        filename: 'Travel_Policy.pdf',
        uploadedOn: DateTime(2025, 7, 5),
        documentType: 'Travel'),
  ];

  // ── applySort ─────────────────────────────────────────────────────

  group('applySort', () {
    test('dateDesc puts newest first', () {
      final sorted = applySort(docs, DocsSortMode.dateDesc);
      expect(sorted.first.filename, 'Life_Cover.pdf');
      expect(sorted.last.filename, 'Another_Health.pdf');
    });

    test('dateAsc puts oldest first', () {
      final sorted = applySort(docs, DocsSortMode.dateAsc);
      expect(sorted.first.filename, 'Another_Health.pdf');
      expect(sorted.last.filename, 'Life_Cover.pdf');
    });

    test('nameAsc sorts alphabetically A-Z', () {
      final sorted = applySort(docs, DocsSortMode.nameAsc);
      expect(sorted.first.filename, 'Another_Health.pdf');
      expect(sorted.last.filename, 'Travel_Policy.pdf');
    });

    test('nameDesc sorts alphabetically Z-A', () {
      final sorted = applySort(docs, DocsSortMode.nameDesc);
      expect(sorted.first.filename, 'Travel_Policy.pdf');
      expect(sorted.last.filename, 'Another_Health.pdf');
    });

    test('type groups by canonical type name, newest first within group', () {
      final sorted = applySort(docs, DocsSortMode.type);
      // 'Auto Insurance' comes before 'Health Insurance' alphabetically
      expect(sorted[0].documentType, 'Motor'); // → Auto Insurance
      // Both Health docs should be grouped together
      final healthDocs =
          sorted.where((d) => d.documentType == 'Health').toList();
      expect(healthDocs.length, 2);
      // Within Health group, newest (June) comes before oldest (Jan)
      expect(healthDocs[0].filename, 'Health_Policy.pdf');
      expect(healthDocs[1].filename, 'Another_Health.pdf');
    });

    test('does not mutate the original list', () {
      final original = List<InsuranceDocument>.from(docs);
      applySort(docs, DocsSortMode.nameAsc);
      expect(docs.map((d) => d.filename).toList(),
          original.map((d) => d.filename).toList());
    });

    test('empty list returns empty list', () {
      final sorted = applySort([], DocsSortMode.dateDesc);
      expect(sorted, isEmpty);
    });

    test('single item returns that item', () {
      final sorted = applySort([docs.first], DocsSortMode.nameAsc);
      expect(sorted.length, 1);
      expect(sorted.first.filename, docs.first.filename);
    });
  });

  // ── applyFilter ───────────────────────────────────────────────────

  group('applyFilter', () {
    test('null filter returns all documents', () {
      final filtered = applyFilter(docs, null);
      expect(filtered.length, docs.length);
    });

    test('empty string filter returns all documents', () {
      final filtered = applyFilter(docs, '');
      expect(filtered.length, docs.length);
    });

    test('filters by document type (case-insensitive)', () {
      // canonicalTypeName('Health') → 'Health Insurance'
      final filtered = applyFilter(docs, 'Health Insurance');
      expect(filtered.length, 2);
      expect(
          filtered.every((d) => d.documentType == 'Health'), isTrue);
    });

    test('filters by partial type match via canonical name', () {
      // canonicalTypeName('Motor') → 'Auto Insurance'
      final filtered = applyFilter(docs, 'Auto Insurance');
      expect(filtered.length, 1);
      expect(filtered.first.documentType, 'Motor');
    });

    test('returns empty for non-existent type', () {
      final filtered = applyFilter(docs, 'Pet Insurance');
      expect(filtered, isEmpty);
    });

    test('does not mutate the original list', () {
      final original = List<InsuranceDocument>.from(docs);
      applyFilter(docs, 'Health Insurance');
      expect(docs.length, original.length);
    });
  });

  // ── distinctTypes ─────────────────────────────────────────────────

  group('distinctTypes', () {
    test('returns sorted canonical type names', () {
      final types = distinctTypes(docs);
      expect(types, [
        'Auto Insurance',
        'Health Insurance',
        'Life Insurance',
        'Travel Insurance',
      ]);
    });

    test('returns empty for empty list', () {
      expect(distinctTypes([]), isEmpty);
    });

    test('handles single type', () {
      final single = [
        _doc(
            filename: 'a.pdf',
            uploadedOn: DateTime.now(),
            documentType: 'Health'),
      ];
      expect(distinctTypes(single), ['Health Insurance']);
    });

    test('deduplicates types', () {
      final dupes = [
        _doc(
            filename: 'a.pdf',
            uploadedOn: DateTime.now(),
            documentType: 'Health'),
        _doc(
            filename: 'b.pdf',
            uploadedOn: DateTime.now(),
            documentType: 'Health'),
      ];
      expect(distinctTypes(dupes), ['Health Insurance']);
    });

    test('handles null documentType via classifyPolicyType fallback', () {
      final withNull = [
        _doc(
            filename: 'a.pdf',
            uploadedOn: DateTime.now(),
            documentType: null),
      ];
      final types = distinctTypes(withNull);
      // classifyPolicyType(null) falls back to PolicyType.other
      // canonicalTypeName(other) → 'Other Insurance'
      expect(types, ['Other Insurance']);
    });
  });

  // ── DocsSortMode.fromString ───────────────────────────────────────

  group('DocsSortMode.fromString', () {
    test('parses valid values', () {
      expect(DocsSortMode.fromString('date_desc'), DocsSortMode.dateDesc);
      expect(DocsSortMode.fromString('date_asc'), DocsSortMode.dateAsc);
      expect(DocsSortMode.fromString('name_asc'), DocsSortMode.nameAsc);
      expect(DocsSortMode.fromString('name_desc'), DocsSortMode.nameDesc);
      expect(DocsSortMode.fromString('type'), DocsSortMode.type);
    });

    test('defaults to dateDesc for null', () {
      expect(DocsSortMode.fromString(null), DocsSortMode.dateDesc);
    });

    test('defaults to dateDesc for unknown value', () {
      expect(DocsSortMode.fromString('garbage'), DocsSortMode.dateDesc);
    });
  });
}
