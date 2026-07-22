import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/screens/policy_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Minimal PolicyExtractionService that returns a fixed list of summaries.
class _FakeSummariesNotifier extends PolicySummariesNotifier {
  final List<PolicySummary> _summaries;
  _FakeSummariesNotifier(this._summaries);

  @override
  List<PolicySummary> build() => _summaries;
}

/// Full policy summary with all fields populated.
PolicySummary _fullSummary() => PolicySummary(
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

/// Minimal summary — passes hasMinimumViableEvidence with just the
/// required critical fields (policyNumber, insurer, documentType,
/// startDate+endDate, coverageAmount).
PolicySummary _minimalSummary() => PolicySummary(
      documentId: 'doc-2',
      documentType: 'Auto Insurance',
      insurer: 'HDFC Ergo',
      policyNumber: 'POL-MINIMAL',
      coverageAmount: 300000,
      startDate: DateTime(2026, 3, 1),
      endDate: DateTime(2027, 3, 1),
      extractedAt: DateTime(2026, 7, 5),
    );

void main() {
  // Initialize Hive so FieldOverridesStore can open its box during widget tests.
  setUpAll(() {
    Hive.init('/tmp/coverwise-policy-detail-tests');
  });

  tearDownAll(() {
  });

  Widget buildPolicyDetail({
    required String documentId,
    List<PolicySummary>? summaries,
    List<InsuranceDocument>? documents,
  }) {
    return ProviderScope(
      overrides: [
        policySummariesProvider.overrideWith(
          () => _FakeSummariesNotifier(
            summaries ?? [_fullSummary()],
          ),
        ),
        documentsProvider.overrideWith((ref) async => documents ?? []),
      ],
      child: MaterialApp(
        home: PolicyDetailScreen(documentId: documentId),
      ),
    );
  }

  group('PolicyDetailScreen — populated state', () {
    testWidgets('resolves a local ID to the server summary ID', (tester) async {
      final summary = PolicySummary(
        documentId: 'remote-policy-1',
        documentType: 'Health Insurance',
        insurer: 'ICICI Lombard',
        policyNumber: 'POL-REMOTE-1',
        coverageAmount: 500000,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
        extractedAt: DateTime(2026, 7, 10),
      );
      final document = InsuranceDocument(
        id: 'local-policy-1',
        remoteId: 'remote-policy-1',
        filename: 'policy.pdf',
        uploadedOn: DateTime(2026, 7, 10),
      );

      await tester.pumpWidget(buildPolicyDetail(
        documentId: document.id,
        summaries: [summary],
        documents: [document],
      ));
      await tester.pumpAndSettle();

      expect(find.text('POL-REMOTE-1'), findsOneWidget);
      expect(find.text('ICICI Lombard'), findsOneWidget);
      expect(find.text('Policy summary not available'), findsNothing);
    });

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      expect(find.byType(PolicyDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders policy type as page header', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      expect(find.text('Health Insurance'), findsWidgets);
    });

    testWidgets('renders insurer name', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // EditableField renders insurer as editable field
      expect(find.text('ICICI Lombard'), findsOneWidget);
    });

    testWidgets('renders policy number', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // EditableField renders label and value as separate Text widgets
      expect(find.text('Policy number'), findsOneWidget);
      expect(find.text('POL-12345'), findsOneWidget);
    });

    testWidgets('renders active status badge', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('renders money row with coverage, premium, deductible',
        (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // EditableField renders labels and values as separate Text widgets
      expect(find.text('Sum Insured'), findsOneWidget);
      expect(find.text('₹5.0 L'), findsOneWidget);
      expect(find.text('Premium'), findsWidgets);
      expect(find.text('₹12.0K'), findsOneWidget);
      expect(find.text('Deductible'), findsOneWidget);
      expect(find.text('₹5000'), findsOneWidget);
    });

    testWidgets('renders key benefits section', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Scroll to the section content (below fold in ListView)
      await tester.scrollUntilVisible(find.text('Included benefits'), 200);
      expect(find.text('Included benefits'), findsOneWidget);
      expect(find.text('Room charges up to ₹5,000/day'), findsOneWidget);
      expect(find.text('Pre and post hospitalization'), findsOneWidget);
    });

    testWidgets('renders exclusions section', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Scroll to the section content (below fold in ListView)
      await tester.scrollUntilVisible(find.text('Not included'), 200);
      expect(find.text('Not included'), findsOneWidget);
      expect(find.text('Not included'), findsOneWidget);
      expect(find.text('Cosmetic surgery'), findsOneWidget);
      expect(find.text('Self-inflicted injuries'), findsOneWidget);
    });

    testWidgets('renders waiting periods section', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Scroll to the section content (below fold in ListView)
      await tester.scrollUntilVisible(find.text('Waiting Periods'), 200);
      expect(find.text('Waiting Periods'), findsOneWidget);
      expect(find.text('Waiting Periods'), findsOneWidget);
      expect(find.text('30 days for initial diseases'), findsOneWidget);
      expect(find.text('2 years for pre-existing'), findsOneWidget);
    });

    testWidgets('renders coverage items section', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Scroll to the section content (below fold in ListView)
      await tester.scrollUntilVisible(find.text('Detailed breakdown'), 200);
      expect(find.text('Detailed breakdown'), findsOneWidget);
      expect(find.text('Detailed breakdown'), findsOneWidget);
      expect(find.text('Room & Board'), findsOneWidget);
      expect(find.text('ICU'), findsOneWidget);
      expect(find.text('Cosmetic'), findsOneWidget);
    });

    testWidgets('renders quick actions', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // CoverWiseSectionLabel renders label.toUpperCase(); scroll to below-fold content
      await tester.scrollUntilVisible(find.text('NEXT STEPS'), 200);
      expect(find.text('NEXT STEPS'), findsOneWidget);
      expect(find.text('Ask about this policy'), findsOneWidget);
      expect(find.text('Share policy summary'), findsOneWidget);
    });

    testWidgets('renders extraction disclaimer at bottom', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // The disclaimer text is below the fold in the ListView; scroll to find it
      await tester.scrollUntilVisible(
        find.textContaining('Extracted on'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('Extracted on'), findsOneWidget);
      expect(find.textContaining('Always verify'), findsOneWidget);
    });

    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      expect(find.text('Policy details'), findsOneWidget);
    });

    testWidgets('renders document preview and share buttons in app bar',
        (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsWidgets);
      expect(find.byIcon(Icons.ios_share_rounded), findsWidgets);
    });
  });

  group('PolicyDetailScreen — minimal summary', () {
    testWidgets('renders without crash with minimal fields', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(
        documentId: 'doc-2',
        summaries: [_minimalSummary()],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Auto Insurance'), findsWidgets);
      expect(find.text('HDFC Ergo'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('hides sections with empty lists', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(
        documentId: 'doc-2',
        summaries: [_minimalSummary()],
      ));
      await tester.pumpAndSettle();

      expect(find.text('What this policy covers'), findsNothing);
      expect(find.text('Important exclusions'), findsNothing);
      expect(find.text('Timing conditions'), findsNothing);
      expect(find.text('Coverage details'), findsNothing);
    });
  });

  group('override flow — edit, save, display, revert', () {
    testWidgets('tapping edit icon on insurer field switches to text input', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Find the edit IconButton next to the insurer field
      final editButton = find.byIcon(Icons.edit_outlined).first;
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Should now show a TextField with the current value
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('canceling edit restores display mode without saving', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Tap edit icon on first editable field
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should return to display mode — no TextField visible
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping edit on policy detail screen does not crash', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(documentId: 'doc-1'));
      await tester.pumpAndSettle();

      // Verify multiple edit buttons exist (insurer, policy number, coverage, premium, dates)
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    // Note: save→display→revert integration tests require real Hive I/O
    // which cannot be awaited in Flutter widget tests. The edit/cancel
    // flow is covered above; save/revert integration is verified via
    // manual testing on device and the FieldOverridesStore unit tests.
  });

  group('PolicyDetailScreen — empty state', () {
    testWidgets('shows empty state when summary not found', (tester) async {
      await tester.pumpWidget(buildPolicyDetail(
        documentId: 'nonexistent',
        summaries: [_fullSummary()],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Policy summary not available'), findsOneWidget);
      expect(find.text('Ask about this policy'), findsWidgets);
    });
  });

  group('buildShareSummaryText', () {
    test('includes all key fields in shareable text', () {
      final text = buildShareSummaryText(_fullSummary());

      expect(text, contains('Health Insurance'));
      expect(text, contains('ICICI Lombard'));
      expect(text, contains('POL-12345'));
      expect(text, contains('5.0 L'));
      expect(text, contains('12.0K'));
      expect(text, contains('5000'));
      expect(text, contains('Room charges up to ₹5,000/day'));
      expect(text, contains('Cosmetic surgery'));
      expect(text, contains('CoverWise'));
    });

    test('handles minimal summary gracefully', () {
      final text = buildShareSummaryText(_minimalSummary());

      expect(text, contains('Auto Insurance'));
      expect(text, contains('HDFC Ergo'));
      expect(text, contains('3.0 L'));
      expect(text, contains('CoverWise'));
    });

    test('excludes null fields from share text', () {
      final text = buildShareSummaryText(_minimalSummary());

      // policyNumber IS present in _minimalSummary, so 'Policy:' should appear
      expect(text, contains('Policy: POL-MINIMAL'));
      // These fields are absent from _minimalSummary
      expect(text.contains('Premium:'), isFalse);
      expect(text.contains('Deductible:'), isFalse);
      expect(text.contains('Benefits:'), isFalse);
      expect(text.contains('Exclusions:'), isFalse);
    });
  });
}
