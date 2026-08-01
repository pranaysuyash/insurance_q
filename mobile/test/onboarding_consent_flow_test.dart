import 'package:coverwise/config/app_config.dart';
import 'package:coverwise/screens/onboarding_screen.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'helpers/hive_test_helper.dart';

/// Sets a taller viewport to accommodate the onboarding last page content.
void _setLargerViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 3600);
  addTearDown(() => tester.view.resetPhysicalSize());
}

/// Navigate to the last onboarding page (where checkboxes live).
Future<void> _navigateToLastPage(WidgetTester tester,
    {void Function({bool openFilePicker})? onComplete}) async {
  _setLargerViewport(tester);
  await tester.pumpWidget(MaterialApp(
    home: OnboardingScreen(
      onComplete: onComplete ?? ({bool openFilePicker = false}) {},
    ),
  ));
  await tester.pump();

  // Step 1 → 2
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  // Step 2 → 3 (last page)
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  setUp(() async {
    final box = Hive.box('consent_ledger');
    await box.clear();
    await AppConfig.init();
  });

  tearDownAll(() {
    HiveTestHelper.tearDown();
  });

  group('OnboardingScreen — consent checkboxes', () {
    testWidgets('both checkboxes unchecked: button is disabled', (tester) async {
      await _navigateToLastPage(tester);

      final addButton =
          find.widgetWithText(FilledButton, 'Add my first policy');
      expect(addButton, findsOneWidget);

      final button = tester.widget<FilledButton>(addButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('only privacy checked: button remains disabled', (tester) async {
      await _navigateToLastPage(tester);

      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      await tester.ensureVisible(checkboxes.first);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      final addButton =
          find.widgetWithText(FilledButton, 'Add my first policy');
      final button = tester.widget<FilledButton>(addButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('only terms checked: button remains disabled', (tester) async {
      await _navigateToLastPage(tester);

      final checkboxes = find.byType(Checkbox);
      await tester.ensureVisible(checkboxes.last);
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      final addButton =
          find.widgetWithText(FilledButton, 'Add my first policy');
      final button = tester.widget<FilledButton>(addButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('both checkboxes checked: button becomes enabled',
        (tester) async {
      await _navigateToLastPage(tester);

      final checkboxes = find.byType(Checkbox);

      await tester.ensureVisible(checkboxes.first);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      final addButton =
          find.widgetWithText(FilledButton, 'Add my first policy');
      final button = tester.widget<FilledButton>(addButton);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('unchecking one checkbox disables the button again',
        (tester) async {
      await _navigateToLastPage(tester);

      final checkboxes = find.byType(Checkbox);

      await tester.ensureVisible(checkboxes.first);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      var addButton =
          find.widgetWithText(FilledButton, 'Add my first policy');
      var button = tester.widget<FilledButton>(addButton);
      expect(button.onPressed, isNotNull);

      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      addButton = find.widgetWithText(FilledButton, 'Add my first policy');
      button = tester.widget<FilledButton>(addButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('skip button on first page navigates to last page',
        (tester) async {
      _setLargerViewport(tester);
      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(
          onComplete: ({bool openFilePicker = false}) {},
        ),
      ));
      await tester.pump();

      // Verify skip button is visible on first page.
      expect(find.text('Skip intro'), findsOneWidget);

      // Tap skip.
      await tester.tap(find.text('Skip intro'));
      await tester.pumpAndSettle();

      // Should now be on last page (checkboxes visible).
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
    });
  });

  group('OnboardingScreen — consent persistence', () {
    testWidgets('successful completion records privacy + terms consent and calls onComplete',
        (tester) async {
      bool onCompleteCalled = false;

      await _navigateToLastPage(tester, onComplete: ({bool openFilePicker = false}) {
        onCompleteCalled = true;
      });

      final checkboxes = find.byType(Checkbox);
      await tester.ensureVisible(checkboxes.first);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      await tester.tap(
          find.widgetWithText(FilledButton, 'Add my first policy'));
      await tester.pumpAndSettle();

      // Verify consent was recorded.
      final ledger = ConsentLedger();
      final privacyRecord =
          ledger.getLatestRecord(ConsentPurpose.privacyPolicy);
      expect(privacyRecord, isNotNull);
      expect(privacyRecord!.granted, isTrue);
      expect(privacyRecord.version, AppConfig.privacyPolicyVersion);

      final termsRecord =
          ledger.getLatestRecord(ConsentPurpose.termsOfService);
      expect(termsRecord, isNotNull);
      expect(termsRecord!.granted, isTrue);
      expect(termsRecord.version, AppConfig.privacyPolicyVersion);

      // Verify onComplete was called.
      expect(onCompleteCalled, isTrue);
    });

    testWidgets(
        'consent failure blocks onboarding (onComplete not called, error snackbar shown)',
        (tester) async {
      bool onCompleteCalled = false;

      // Close the consent ledger box so _requiredBox throws.
      final box = Hive.box('consent_ledger');
      await box.close();

      await _navigateToLastPage(tester,
          onComplete: ({bool openFilePicker = false}) {
        onCompleteCalled = true;
      });

      final checkboxes = find.byType(Checkbox);
      await tester.ensureVisible(checkboxes.first);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      await tester.tap(
          find.widgetWithText(FilledButton, 'Add my first policy'));
      await tester.pumpAndSettle();

      // onComplete should NOT have been called.
      expect(onCompleteCalled, isFalse);

      // Error snackbar should appear.
      expect(
        find.text(
            'Could not save your consent preferences. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
