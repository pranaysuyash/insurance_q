import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/emergency_screen.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/policy_providers.dart';

/// Minimal wrapper that provides a [ProviderScope] around the widget under test.
Widget _wrap(Widget child, {List<PolicySummary>? summaries}) {
  return ProviderScope(
    overrides: [
      if (summaries != null)
        policySummariesProvider.overrideWith(
          () => _FakeSummariesNotifier(summaries),
        ),
    ],
    child: MaterialApp(home: child),
  );
}

/// Minimal Notifier that returns a fixed list of summaries.
class _FakeSummariesNotifier extends PolicySummariesNotifier {
  _FakeSummariesNotifier(this._initial);

  final List<PolicySummary> _initial;

  @override
  List<PolicySummary> build() => _initial;
}

void main() {
  group('EmergencyScreen — empty state', () {
    testWidgets('shows empty state when no summaries exist', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmergencyScreen(),
        summaries: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('No policies loaded'), findsOneWidget);
      expect(
        find.text('Choose a policy file to keep emergency information ready.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.emergency), findsOneWidget);
    });

    testWidgets('empty state has correct app bar title', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmergencyScreen(),
        summaries: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Card'), findsOneWidget);
    });
  });

  group('EmergencyScreen — with data', () {
    testWidgets('shows emergency cards when summaries exist', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'ICICI Lombard',
          policyNumber: 'POL-12345',
          coverageAmount: 500000,
          insurerHelpline: '1800-266-6',
          insurerEmail: 'help@icicilombard.com',
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(
        const EmergencyScreen(),
        summaries: summaries,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Emergency details'), findsOneWidget);
      expect(find.text('Help at a glance'), findsOneWidget);
      expect(find.text('Health Insurance'), findsOneWidget);
      expect(find.text('ICICI Lombard'), findsOneWidget);
      expect(find.text('POL-12345'), findsOneWidget);
      expect(find.text('Call insurer • 1800-266-6'), findsOneWidget);
      expect(find.text('Email • help@icicilombard.com'), findsOneWidget);
    });

    testWidgets('shows multiple emergency cards for multiple policies', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'ICICI Lombard',
          coverageAmount: 500000,
          extractedAt: DateTime.now(),
        ),
        PolicySummary(
          documentId: 'doc-2',
          documentType: 'Auto Insurance',
          insurer: 'HDFC Ergo',
          coverageAmount: 300000,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(
        const EmergencyScreen(),
        summaries: summaries,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Health Insurance'), findsOneWidget);
      expect(find.text('Auto Insurance'), findsOneWidget);
      expect(find.text('ICICI Lombard'), findsOneWidget);
      expect(find.text('HDFC Ergo'), findsOneWidget);
    });

    testWidgets('hides policy number when null', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          policyNumber: null,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(
        const EmergencyScreen(),
        summaries: summaries,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Policy number'), findsNothing);
    });

    testWidgets('hides call button when helpline is null', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          insurerHelpline: null,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(
        const EmergencyScreen(),
        summaries: summaries,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Call insurer'), findsNothing);
    });

    testWidgets('hides email button when email is null', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test',
          coverageAmount: 500000,
          insurerEmail: null,
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(_wrap(
        const EmergencyScreen(),
        summaries: summaries,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Email'), findsNothing);
    });
  });
}
