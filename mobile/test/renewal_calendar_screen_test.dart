import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/screens/renewal_calendar_screen.dart';
import 'package:coverwise/services/policy_extraction_service.dart';
import 'package:coverwise/services/query_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyExtractionService extends PolicyExtractionService {
  _EmptyExtractionService() : super(QueryService(Dio()));

  @override
  List<PolicySummary> getAllSummaries() => const [];
}

class _EmptyPolicySummaries extends PolicySummariesNotifier {
  _EmptyPolicySummaries() : super(_EmptyExtractionService());
}

void main() {
  testWidgets('empty renewal state offers the policy-file action',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          policySummariesProvider.overrideWith(
            (ref) => _EmptyPolicySummaries(),
          ),
        ],
        child: const MaterialApp(home: RenewalCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No policies tracked'), findsOneWidget);
    expect(find.text('Choose policy file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
