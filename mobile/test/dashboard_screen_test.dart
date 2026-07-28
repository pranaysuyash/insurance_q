import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/screens/dashboard_screen.dart';
import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/policy_detail_test_helpers.dart';

InsuranceDocument _document(String id) => InsuranceDocument(
      id: id,
      filename: '$id.pdf',
      uploadedOn: DateTime(2026, 7, 10),
      status: 'completed',
      documentType: 'Health Insurance',
    );

PolicySummary _summary({DateTime? endDate}) => PolicySummary(
      documentId: 'doc-1',
      documentType: 'Health Insurance',
      insurer: 'Test Insurer',
      endDate: endDate,
      extractedAt: DateTime(2026, 7, 10),
    );

Widget _dashboard({
  List<InsuranceDocument> documents = const [],
  List<PolicySummary> summaries = const [],
}) => ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => documents),
        policySummariesProvider.overrideWith(
          () => FakeSummariesNotifier(summaries),
        ),
      ],child: MaterialApp(
          localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
          home: const DashboardScreen()),
    );

  void main() {
  testWidgets('renders the evidence-bound populated dashboard', (tester) async {
    await tester.pumpWidget(_dashboard(
      documents: [_document('doc-1'), _document('doc-2')],
      summaries: [_summary()],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Your cover, at a glance'), findsOneWidget);
    expect(find.text('Review your coverage'), findsOneWidget);
    expect(find.text('Coverage details'), findsOneWidget);
    expect(find.text('Review cited policy fields'), findsOneWidget);
    expect(find.text('Policy status'), findsOneWidget);
    expect(find.text('Coverage summary'), findsOneWidget);
  });

  testWidgets('tapping Coverage summary navigates to CoverageDetailsSummaryScreen',
      (tester) async {
    await tester.pumpWidget(_dashboard(
      documents: [_document('doc-1')],
      summaries: [_summary()],
    ));
    await tester.pumpAndSettle();

    // Scroll down to the Quick Tools section where Coverage summary button lives
    final coverageSummaryFinder = find.text('Coverage summary');
    await tester.ensureVisible(coverageSummaryFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap the Coverage summary button
    await tester.tap(coverageSummaryFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we landed on the Coverage Details Summary screen
    expect(find.text('Coverage Details Summary'), findsOneWidget);
    expect(find.text('Policy Basics'), findsOneWidget);
  });

  testWidgets('Coverage summary button is tappable when summaries exist',
      (tester) async {
    await tester.pumpWidget(_dashboard(
      documents: [_document('doc-1')],
      summaries: [],
    ));
    await tester.pumpAndSettle();

    // The button should still be visible even without summaries
    final finder = find.text('Coverage summary');
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(finder, findsOneWidget);
    
    // Tapping when no summaries should not crash (no-op)
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 100));
    // Still on the dashboard
    expect(find.text('Your cover, at a glance'), findsOneWidget);
  });

  testWidgets('Coverage summary button is tappable when summaries exist',
      (tester) async {
    await tester.pumpWidget(_dashboard(
      documents: [_document('doc-1')],
      summaries: [],
    ));
    await tester.pumpAndSettle();

    // The button should still be visible even without summaries
    expect(find.text('Coverage summary'), findsOneWidget);
    
    // Tapping when no summaries should not crash (no-op)
    await tester.tap(find.text('Coverage summary'));
    await tester.pump(const Duration(milliseconds: 100));
    // Still on the dashboard
    expect(find.text('Your cover, at a glance'), findsOneWidget);
  });

  testWidgets('prioritizes an expiring policy', (tester) async {
    await tester.pumpWidget(_dashboard(
      documents: [_document('doc-1')],
      summaries: [_summary(endDate: DateTime.now().add(const Duration(days: 15)))],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Renew expiring policy'), findsOneWidget);
    expect(find.text('View renewals'), findsOneWidget);
  });

  testWidgets('shows the first-policy action when no document exists', (tester) async {
    await tester.pumpWidget(_dashboard());
    await tester.pumpAndSettle();

    expect(find.text('No policies yet'), findsOneWidget);
    expect(find.text('Add policy'), findsOneWidget);
    expect(find.text('Your cover, at a glance'), findsNothing);
  });

  testWidgets('shows a retryable error when document loading fails', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => throw Exception('Network error')),
        policySummariesProvider.overrideWith(() => FakeSummariesNotifier(const [])),
      ],
      child: MaterialApp(
          localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
          home: const DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not load'), findsOneWidget);
  });
}
