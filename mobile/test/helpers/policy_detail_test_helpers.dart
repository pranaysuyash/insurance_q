/// Shared test helpers for policy detail and analytics widget tests.
///
/// Extracts the most commonly duplicated helpers:
///   - ``_FakeSummariesNotifier`` — minimal ``PolicySummariesNotifier``
///   - ``_fullSummary()`` — a ``PolicySummary`` with all fields populated
///   - ``_minimalSummary()`` — a ``PolicySummary`` with just the critical
///     fields (passes ``hasMinimumViableEvidence``)
///
/// These are defined as top-level public symbols so test files can import
/// them directly without redefining the same boilerplate.
library;

import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/policy_providers.dart';

// ---------------------------------------------------------------------------
// Fake Notifier
// ---------------------------------------------------------------------------

/// Minimal implementation of [PolicySummariesNotifier] that returns a fixed
/// list of summaries.  Use in provider overrides:
///
/// ```dart
/// policySummariesProvider.overrideWith(
///   () => FakeSummariesNotifier([_fullSummary()]),
/// ),
/// ```
class FakeSummariesNotifier extends PolicySummariesNotifier {
  final List<PolicySummary> _summaries;

  FakeSummariesNotifier([this._summaries = const []]);

  @override
  List<PolicySummary> build() => _summaries;
}

// ---------------------------------------------------------------------------
// Summary factories
// ---------------------------------------------------------------------------

/// A [PolicySummary] with all fields populated, suitable for testing render
/// states that expect key benefits, exclusions, waiting periods, and coverage
/// items.
PolicySummary fullSummary() => PolicySummary(
      documentId: 'doc-1',
      documentType: 'Health Insurance',
      insurer: 'ICICI Lombard',
      policyNumber: 'POL-12345',
      coverageAmount: 500000,
      premiumAmount: 12000,
      deductible: 5000,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1),
      keyBenefits: ['Room charges up to ₹5,000/day', 'Pre and post hospitalization'],
      exclusions: ['Cosmetic surgery', 'Self-inflicted injuries'],
      waitingPeriods: ['30 days for initial diseases', '2 years for pre-existing'],
      coverageItems: [
        CoverageItem(name: 'Room & Board', covered: true, limitText: '₹5,000/day'),
        CoverageItem(name: 'ICU', covered: true, limit: 100000),
        CoverageItem(name: 'Cosmetic', covered: false),
      ],
      extractedAt: DateTime(2026, 7, 10),
    );

/// A [PolicySummary] with only the critical fields required to pass
/// ``hasMinimumViableEvidence``.  All optional fields (premium, deductible,
/// benefits, exclusions, waiting periods, coverage items) are omitted.
PolicySummary minimalSummary() => PolicySummary(
      documentId: 'doc-2',
      documentType: 'Auto Insurance',
      insurer: 'HDFC Ergo',
      policyNumber: 'POL-MINIMAL',
      coverageAmount: 300000,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2027, 3, 1),
      extractedAt: DateTime(2026, 7, 5),
    );

/// An expired [PolicySummary] (endDate in the past).
PolicySummary expiredSummary() => PolicySummary(
      documentId: 'doc-expired',
      documentType: 'Motor Insurance',
      insurer: 'Test Insurer',
      policyNumber: 'POL-EXPIRED',
      coverageAmount: 200000,
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime(2025, 1, 1),
      extractedAt: DateTime(2026, 7, 10),
    );
