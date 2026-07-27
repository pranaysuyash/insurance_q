import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/screens/renewal_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyPolicySummaries extends PolicySummariesNotifier {
  @override
  List<PolicySummary> build() => const [];
}

void main() {
  testWidgets('empty renewal state offers the policy-file action',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policySummariesProvider.overrideWith(
            () => _EmptyPolicySummaries(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
          supportedLocales: AppLocalizationsGen.supportedLocales,
          home: const RenewalCalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No policies tracked'), findsOneWidget);
    expect(find.text('Choose policy file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
