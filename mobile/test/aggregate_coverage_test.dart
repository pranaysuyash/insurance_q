import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/providers/aggregate_coverage_provider.dart';
import 'helpers/policy_detail_test_helpers.dart';

void main() {
  test('aggregateCoverageProvider calculates total sum insured and grouping', () {
    final summaries = [
      PolicySummary(
        documentId: 'doc-1',
        documentType: 'Health Insurance',
        coverageAmount: 500000.0,
        insurer: 'Star Health',
        extractedAt: DateTime(2026, 1, 1),
      ),
      PolicySummary(
        documentId: 'doc-2',
        documentType: 'Health Insurance',
        coverageAmount: 1500000.0,
        insurer: 'HDFC ERGO',
        extractedAt: DateTime(2026, 1, 1),
      ),
      PolicySummary(
        documentId: 'doc-3',
        documentType: 'Term Life Insurance',
        coverageAmount: 10000000.0,
        insurer: 'Tata AIA',
        extractedAt: DateTime(2026, 1, 1),
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        policySummariesProvider.overrideWith(() => FakeSummariesNotifier(summaries)),
      ],
    );

    final state = container.read(aggregateCoverageProvider);
    expect(state.totalPolicies, 3);
    expect(state.totalSumInsured, 12000000.0);
    expect(state.formattedTotal, '₹1.2 Cr');
    expect(state.coverageByType['Health Insurance'], 2000000.0);
    expect(state.coverageByType['Life Insurance'], 10000000.0);
    expect(state.coordinationNotes.length, 1);
  });
}
