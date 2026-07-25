import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/widgets/claims_workflow_sheet.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/widgets/shared/coverwise_snackbar.dart';
import 'package:coverwise/theme/coverwise_theme.dart';
import 'helpers/hive_test_helper.dart';

// ── Fake Notifier ──

class _FakeSummariesNotifier extends PolicySummariesNotifier {
  @override
  List<PolicySummary> build() => const [];
}

// ── Test Harness ──

Widget _buildTestApp({PolicySummary? preselectedPolicy}) {
  return ProviderScope(
    overrides: [
      policySummariesProvider.overrideWith(() => _FakeSummariesNotifier()),
    ],
    child: MaterialApp(
      scaffoldMessengerKey: CoverWiseSnackBar.scaffoldMessengerKey,
      theme: CoverWiseTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ClaimWizardSheet.show(
              context,
              preselectedPolicy: preselectedPolicy,
            ),
            child: const Text('Open Wizard'),
          ),
        ),
      ),
    ),
  );
}

/// Opens the wizard by tapping the button, then pumps through the animation.
Future<void> openWizard(WidgetTester tester) async {
  await tester.tap(find.text('Open Wizard'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

// ── Main ──

void main() {
  setUpAll(() async {
    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  group('ClaimWizardSheet — edge cases', () {
    testWidgets('renders without crash with preselectedPolicy', (tester) async {
      final preselected = PolicySummary(
        documentId: 'doc-p1',
        documentType: 'Health Insurance',
        insurer: 'ICICI Lombard',
        extractedAt: DateTime.now(),
      );
      await tester.pumpWidget(_buildTestApp(preselectedPolicy: preselected));
      await openWizard(tester);

      // Wizard should render with the preselected policy context
      expect(find.text('What happened?'), findsOneWidget);
      expect(find.byType(ClaimWizardSheet), findsOneWidget);
    });

    testWidgets('whitespace-only description keeps Save disabled',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Enter only whitespace
      await tester.enterText(
        find.widgetWithText(TextField, 'What happened? *'),
        '   ',
      );
      await tester.pumpAndSettle();

      // Save button should remain disabled (trim check)
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save to claim log'),
      );
      expect(saveButton.onPressed, isNull);
    });
  });

  group('ClaimWizardSheet — rendering and navigation', () {
    testWidgets('opens as a modal bottom sheet', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      expect(find.text('What happened?'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Private claim note'), findsOneWidget);
      expect(
        find.text(
          'This records information on this device only. It does not file, submit, or update a claim with an insurer.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows all 6 incident types', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      // The first row is visible immediately. The privacy boundary above the
      // incident choices is intentional, so the rest must remain reachable by
      // scrolling rather than being assumed to fit a fixed test viewport.
      expect(find.text('Hospitalization'), findsOneWidget);
      expect(find.text('Auto Accident'), findsOneWidget);

      // Later options are below the fold — scroll to reveal them.
      // Uses find.descendant to locate the internal Scrollable within the
      // keyed ListView, avoiding the fragile find.byType(Scrollable).last.
      final incidentList = find.byKey(const ValueKey('incident_type_list'));
      final incidentScrollable = find.descendant(
        of: incidentList,
        matching: find.byType(Scrollable),
      );

      await tester.scrollUntilVisible(
        find.text('Life Claim'),
        180,
        scrollable: incidentScrollable,
      );
      expect(find.text('Life Claim'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Property Damage'),
        180,
        scrollable: incidentScrollable,
      );
      expect(find.text('Property Damage'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Theft'),
        200,
        scrollable: incidentScrollable,
      );
      expect(find.text('Theft'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Other'),
        100,
        scrollable: incidentScrollable,
      );
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('step indicator shows 3 step labels', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Photos (optional)'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('default selection shows check icon on Hospitalization',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      // Default selection (Hospitalization) should show a check icon
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Tap different incident — check still present
      await tester.tap(find.text('Auto Accident'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('navigates to step 2 (photos) on Continue', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Photo evidence'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });

    testWidgets('navigates from step 2 to step 3 (review) on Continue',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Review & save'), findsOneWidget);
      expect(find.text('Save to claim log'), findsOneWidget);
    });

    testWidgets('Back button returns to previous step', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Photo evidence'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('What happened?'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses the bottom sheet on step 1',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('What happened?'), findsNothing);
    });
  });

  group('ClaimWizardSheet — save behavior', () {
    testWidgets('Save button is disabled when description is empty',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save to claim log'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Save button is enabled when description is filled',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'What happened? *'),
        'Car hit pole on Marine Drive',
      );
      await tester.pumpAndSettle();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save to claim log'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('tapping Save closes the bottom sheet', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'What happened? *'),
        'Car hit pole on Marine Drive',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save to claim log'));
      await tester.pumpAndSettle();

      // Hive is available (via HiveTestHelper), so save should persist
      // the claim record and close the sheet.
      expect(find.text('What happened?'), findsNothing);
    });

    testWidgets('review step shows incident type summary', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Auto Accident'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The review summary renders incident text across multiple widgets
      expect(find.textContaining('Auto Accident'), findsWidgets);
    });

    testWidgets('review step shows photo count', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Photo count rendered as "0 attached" in a separate Text widget
      expect(find.textContaining('0 attached'), findsOneWidget);
    });
  });

  group('ClaimWizardSheet — photo step', () {
    testWidgets('photo step shows camera, gallery, and info text',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await openWizard(tester);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.textContaining('Photos are optional'), findsOneWidget);
    });
  });

  group('ClaimWizardSheet — dark mode', () {
    testWidgets('renders in dark mode without hardcoded color issues',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            policySummariesProvider
                .overrideWith(() => _FakeSummariesNotifier()),
          ],
          child: MaterialApp(
            scaffoldMessengerKey: CoverWiseSnackBar.scaffoldMessengerKey,
            theme: CoverWiseTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ClaimWizardSheet.show(context),
                  child: const Text('Open Wizard'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('What happened?'), findsOneWidget);
      expect(find.byType(ClaimWizardSheet), findsOneWidget);
    });
  });
}
