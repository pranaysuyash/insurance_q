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
  testWidgets('empty home leads with one complete first-policy action',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) async => const []),
          policySummariesProvider.overrideWith(
            () => _EmptyPolicySummaries(),
          ),
          recentQuestionsProvider.overrideWithValue(const []),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Turn your first policy into clear answers'),
      findsOneWidget,
    );
    expect(find.text('Choose policy file'), findsOneWidget);
    expect(find.text('Your cover, at a glance'), findsNothing);
    // The header is capitalized by CoverWiseSectionLabel
    expect(find.text('YOUR POLICY HUB'), findsNothing);
    expect(find.text('Coverage health'), findsNothing);

    final actionRect = tester.getRect(find.text('Choose policy file'));
    expect(actionRect.bottom, lessThan(tester.view.physicalSize.height));
    expect(tester.takeException(), isNull);
  });
}
