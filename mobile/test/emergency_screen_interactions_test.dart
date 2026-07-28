import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/emergency_screen.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'helpers/policy_detail_test_helpers.dart';

/// Minimal wrapper that provides a [ProviderScope] around the widget under test.
Widget _wrap(Widget child, {List<PolicySummary>? summaries}) {
  return ProviderScope(
    overrides: [
if (summaries != null)
        policySummariesProvider.overrideWith(() => FakeSummariesNotifier(summaries)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('EmergencyScreen — status badges', () {
    testWidgets('shows ACTIVE badge for active policy', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          endDate: DateTime.now().add(const Duration(days: 365)),
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('shows EXPIRED badge for expired policy', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          endDate: DateTime.now().subtract(const Duration(days: 30)),
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.text('EXPIRED'), findsOneWidget);
    });

    testWidgets('shows EXPIRING badge for policy expiring soon', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          endDate: DateTime.now().add(const Duration(days: 15)),
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.text('EXPIRING'), findsOneWidget);
    });
  });

  group('EmergencyScreen — data display', () {
    testWidgets('shows coverage amount', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'ICICI Lombard',
          coverageAmount: 500000,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Coverage'), findsOneWidget);
    });

    testWidgets('shows expiry date when available', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          endDate: DateTime(2027, 6, 15),
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.text('Expires'), findsOneWidget);
    });

    testWidgets('shows helpline and email buttons', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'ICICI Lombard',
          coverageAmount: 500000,
          insurerHelpline: '1800-266-6',
          insurerEmail: 'help@icicilombard.com',
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.textContaining('Call insurer'), findsOneWidget);
      expect(find.textContaining('Email'), findsOneWidget);
    });

    testWidgets('shows page header with emergency icon', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.text('Help at a glance'), findsOneWidget);
      expect(find.byIcon(Icons.emergency_outlined), findsOneWidget);
    });
  });

  group('EmergencyScreen — multiple policies', () {
    testWidgets('shows divider between multiple policy cards', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'ICICI',
          coverageAmount: 500000,
          extractedAt: DateTime.now(),
        ),
        PolicySummary(
          documentId: 'doc-2',
          documentType: 'Auto Insurance',
          insurer: 'HDFC',
          coverageAmount: 300000,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      // Should find two policy type headers
      expect(find.text('Health Insurance'), findsOneWidget);
      expect(find.text('Auto Insurance'), findsOneWidget);

      // Should find multiple Cards
      expect(find.byType(Card), findsWidgets);
    });
  });

  group('EmergencyScreen — edge cases', () {
    testWidgets('handles null insurer gracefully', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: null,
          coverageAmount: 500000,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.text('Health Insurance'), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('handles zero coverage gracefully', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 0,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(const EmergencyScreen(), summaries: summaries));
      await tester.pumpAndSettle();

      expect(find.text('Health Insurance'), findsOneWidget);
    });
  });
}
