import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/policy_detail_screen.dart';
import 'package:coverwise/models/policy_summary.dart';

PolicySummary _makeSummary({
  String documentType = 'Health Insurance',
  String? insurer = 'ICICI Lombard',
  String? policyNumber = 'POL-12345',
  double? coverageAmount = 2500000,
  double? premiumAmount = 31705,
  double? deductible = 5000,
  DateTime? startDate,
  DateTime? endDate,
  List<String> keyBenefits = const ['In-patient hospitalization', 'Daycare procedures'],
  List<String> exclusions = const ['Cosmetic treatments', 'Self-inflicted injuries'],
}) {
  return PolicySummary(
    documentId: 'doc-123',
    policyNumber: policyNumber,
    insurer: insurer,
    insurerHelpline: '1800 2666',
    insurerEmail: 'support@icici.com',
    documentType: documentType,
    coverageAmount: coverageAmount,
    deductible: deductible,
    premiumAmount: premiumAmount,
    premiumFrequency: 'annually',
    startDate: startDate ?? DateTime(2025, 8, 27),
    endDate: endDate ?? DateTime(2026, 8, 26),
    keyBenefits: keyBenefits,
    exclusions: exclusions,
    waitingPeriods: const ['Initial 30 days'],
    coverageItems: const [],
    extractedAt: DateTime(2026, 7, 15),
  );
}

void main() {
  group('buildShareSummaryText', () {
    test('includes document type', () {
      final summary = _makeSummary(documentType: 'Motor Insurance');
      final text = buildShareSummaryText(summary);
      expect(text, contains('Motor Insurance'));
    });

    test('includes insurer name', () {
      final summary = _makeSummary(insurer: 'HDFC ERGO');
      final text = buildShareSummaryText(summary);
      expect(text, contains('HDFC ERGO'));
    });

    test('includes policy number', () {
      final summary = _makeSummary(policyNumber: 'POL-99887');
      final text = buildShareSummaryText(summary);
      expect(text, contains('POL-99887'));
    });

    test('includes coverage amount', () {
      final summary = _makeSummary(coverageAmount: 5000000);
      final text = buildShareSummaryText(summary);
      expect(text, contains('50.0 L'));
    });

    test('includes premium amount', () {
      final summary = _makeSummary(premiumAmount: 12500);
      final text = buildShareSummaryText(summary);
      expect(text, contains('12.5K'));
    });

    test('includes deductible', () {
      final summary = _makeSummary(deductible: 10000);
      final text = buildShareSummaryText(summary);
      expect(text, contains('₹10000'));
    });

    test('includes start and end dates', () {
      final summary = _makeSummary(
        startDate: DateTime(2025, 1, 15),
        endDate: DateTime(2026, 1, 14),
      );
      final text = buildShareSummaryText(summary);
      expect(text, contains('From: 15/1/2025'));
      expect(text, contains('Until: 14/1/2026'));
    });

    test('includes days remaining for active policy', () {
      final futureDate = DateTime.now().add(const Duration(days: 45));
      final summary = _makeSummary(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: futureDate,
      );
      final text = buildShareSummaryText(summary);
      expect(text, contains('days remaining'));
    });

    test('includes key benefits', () {
      final summary = _makeSummary(
        keyBenefits: ['Maternity benefit', 'Pre-hospitalization'],
      );
      final text = buildShareSummaryText(summary);
      expect(text, contains('Benefits:'));
      expect(text, contains('Maternity benefit'));
      expect(text, contains('Pre-hospitalization'));
    });

    test('includes exclusions', () {
      final summary = _makeSummary(
        exclusions: ['War-related injuries', 'Dental'],
      );
      final text = buildShareSummaryText(summary);
      expect(text, contains('Exclusions:'));
      expect(text, contains('War-related injuries'));
      expect(text, contains('Dental'));
    });

    test('includes CoverWise branding footer', () {
      final summary = _makeSummary();
      final text = buildShareSummaryText(summary);
      expect(text, contains('Shared via CoverWise'));
    });

    test('handles null insurer gracefully', () {
      final summary = _makeSummary(insurer: null);
      final text = buildShareSummaryText(summary);
      expect(text, isNot(contains('🏢')));
    });

    test('handles null policy number gracefully', () {
      final summary = _makeSummary(policyNumber: null);
      final text = buildShareSummaryText(summary);
      expect(text, isNot(contains('🔢')));
    });

    test('handles null coverage amount gracefully', () {
      final summary = _makeSummary(coverageAmount: null);
      final text = buildShareSummaryText(summary);
      expect(text, isNot(contains('🛡️')));
    });

    test('handles null premium amount gracefully', () {
      final summary = _makeSummary(premiumAmount: null);
      final text = buildShareSummaryText(summary);
      expect(text, isNot(contains('💰')));
    });

    test('handles null deductible gracefully', () {
      final summary = _makeSummary(deductible: null);
      final text = buildShareSummaryText(summary);
      expect(text, isNot(contains('📉')));
    });

    test('handles null dates gracefully', () {
      final summary = _makeSummary();
      // Override startDate/endDate to null by creating a new summary
      final nullDateSummary = PolicySummary(
        documentId: summary.documentId,
        documentType: summary.documentType,
        insurer: summary.insurer,
        policyNumber: summary.policyNumber,
        coverageAmount: summary.coverageAmount,
        premiumAmount: summary.premiumAmount,
        premiumFrequency: summary.premiumFrequency,
        deductible: summary.deductible,
        startDate: null,
        endDate: null,
        keyBenefits: summary.keyBenefits,
        exclusions: summary.exclusions,
        extractedAt: summary.extractedAt,
      );
      final text = buildShareSummaryText(nullDateSummary);
      expect(text, isNot(contains('📅')));
    });

    test('handles empty benefits and exclusions', () {
      final summary = _makeSummary(
        keyBenefits: const [],
        exclusions: const [],
      );
      final text = buildShareSummaryText(summary);
      expect(text, isNot(contains('Benefits:')));
      expect(text, isNot(contains('Exclusions:')));
    });

    test('formats large coverage as Cr', () {
      final summary = _makeSummary(coverageAmount: 15000000);
      final text = buildShareSummaryText(summary);
      expect(text, contains('1.5 Cr'));
    });

    test('formats small premium correctly', () {
      final summary = _makeSummary(premiumAmount: 500);
      final text = buildShareSummaryText(summary);
      expect(text, contains('₹500'));
    });

    test('includes all benefits when more than one', () {
      final summary = _makeSummary(
        keyBenefits: ['A', 'B', 'C'],
      );
      final text = buildShareSummaryText(summary);
      expect(text, contains('• A'));
      expect(text, contains('• B'));
      expect(text, contains('• C'));
    });
  });
}
