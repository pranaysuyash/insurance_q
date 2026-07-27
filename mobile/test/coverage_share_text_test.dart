import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/screens/coverage_details_summary_screen.dart';

void main() {
  PolicySummary base({
    List<CoverageItem> coverageItems = const [],
  }) {
    return PolicySummary(
      documentId: 'doc1',
      policyNumber: 'POL-12345',
      insurer: 'Test Insurer',
      documentType: 'health',
      coverageAmount: 500000,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      keyBenefits: ['Hospitalization cover'],
      coverageItems: coverageItems,
      extractedAt: DateTime(2026, 7, 25),
    );
  }

  group('buildCoverageShareText — Coverage Items section', () {
    test('renders covered item with limitText', () {
      final summary = base(coverageItems: [
        CoverageItem(
          name: 'Room Rent',
          limitText: 'Up to sum insured',
          covered: true,
        ),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('✅ Room Rent'));
      expect(text, contains('(Up to sum insured)'));
      expect(text, contains('📋 Coverage Items:'));
    });

    test('renders covered item with numeric limit (formatted via fmt)', () {
      final summary = base(coverageItems: [
        CoverageItem(
          name: 'ICU Charges',
          limit: 5000,
          covered: true,
        ),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('✅ ICU Charges'));
      expect(text, contains('(₹5K)')); // fmt(5000) = '₹5K'
    });

    test('renders uncovered item with ❌ icon', () {
      final summary = base(coverageItems: [
        CoverageItem(
          name: 'Dental Cover',
          covered: false,
        ),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('❌ Dental Cover'));
    });

    test('prefers limitText over numeric limit when both are set', () {
      final summary = base(coverageItems: [
        CoverageItem(
          name: 'Ambulance',
          limit: 2000,
          limitText: 'Per event',
          covered: true,
        ),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('✅ Ambulance'));
      expect(text, contains('(Per event)'));
      expect(text, isNot(contains('₹2K'))); // limitText wins, numeric not shown
    });

    test('renders mixed covered and uncovered items', () {
      final summary = base(coverageItems: [
        CoverageItem(name: 'Room Rent', limit: 5000, covered: true),
        CoverageItem(name: 'Dental', covered: false),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('✅ Room Rent'));
      expect(text, contains('(₹5K)'));
      expect(text, contains('❌ Dental'));
    });

    test('large limit rendered with Cr format', () {
      final summary = base(coverageItems: [
        CoverageItem(
          name: 'Sum Insured',
          limit: 10000000,
          covered: true,
        ),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('✅ Sum Insured'));
      expect(text, contains('(₹1.0 Cr)'));
    });

    test('L format for 5L limit', () {
      final summary = base(coverageItems: [
        CoverageItem(
          name: 'Procedure Limit',
          limit: 500000,
          covered: true,
        ),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('✅ Procedure Limit'));
      expect(text, contains('(₹5.0 L)'));
    });

    test('no Coverage Items section when list is empty', () {
      final summary = base(coverageItems: []);

      final text = buildCoverageShareText(summary);

      expect(text, isNot(contains('📋 Coverage Items:')));
    });

    test('renders items on separate lines', () {
      final summary = base(coverageItems: [
        CoverageItem(name: 'A', limitText: 'L1', covered: true),
        CoverageItem(name: 'B', limitText: 'L2', covered: false),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('✅ A (L1)'));
      expect(text, contains('❌ B (L2)'));
      // Each item is on its own indented line (skip headers like ✅ Benefits:)
      final lines = text.split('\n');
      final coverageLines =
          lines.where((l) => l.startsWith('  ') && (l.contains('✅') || l.contains('❌'))).toList();
      expect(coverageLines.length, 2);
    });

    test('item with 999 limit renders without formatting', () {
      final summary = base(coverageItems: [
        CoverageItem(
          name: 'Small Cover',
          limit: 999,
          covered: true,
        ),
      ]);

      final text = buildCoverageShareText(summary);

      expect(text, contains('(₹999)'));
    });
  });

  group('fmt helper', () {
    test('formats core values correctly', () {
      expect(fmt(0), '₹0');
      expect(fmt(999), '₹999');
      expect(fmt(1000), '₹1K');
      expect(fmt(999999), '₹10.0 L'); // ≥100K → L format
      expect(fmt(100000), '₹1.0 L');
      expect(fmt(550000), '₹5.5 L');
      expect(fmt(10000000), '₹1.0 Cr');
      expect(fmt(12500000), '₹1.3 Cr');
    });
  });
}
