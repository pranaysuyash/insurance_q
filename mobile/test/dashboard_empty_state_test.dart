import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyPolicySummaries extends PolicySummariesNotifier {
  @override
  List<PolicySummary> build() => const [];
}

void main() {
  testWidgets('empty home offers a bounded first-policy action', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => const []),
        policySummariesProvider.overrideWith(() => _EmptyPolicySummaries()),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No policies yet'), findsOneWidget);
    expect(find.text('Add policy'), findsOneWidget);
    expect(find.text('Coverage details'), findsNothing);
  });
}
