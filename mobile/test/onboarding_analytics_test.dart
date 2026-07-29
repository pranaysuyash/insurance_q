import 'package:coverwise/screens/onboarding_screen.dart';
import 'package:coverwise/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/hive_test_helper.dart';

/// Builds the onboarding screen for testing.
Widget buildTestApp({void Function({bool openFilePicker})? onComplete}) {
  return MaterialApp(
    home: OnboardingScreen(
      onComplete: onComplete ?? ({bool openFilePicker = false}) {},
    ),
  );
}

/// Sets a taller viewport to accommodate the onboarding last page content
/// (analytics toggle, privacy links, terms checkbox, disclaimer, button).
/// Must be called before each test that navigates to the last page.
/// Registers a tear-down to reset the view.
void _setLargerViewport(WidgetTester tester) {
  // Default DPR is 3.0, so physical 2400×3600 = logical 800×1200
  // Width matches default (800), height is doubled for last-page content
  tester.view.physicalSize = const Size(2400, 3600);
  addTearDown(() => tester.view.resetPhysicalSize());
}

void main() {
  late List<Map<String, dynamic>> capturedEvents;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  setUp(() {
    capturedEvents = AnalyticsService.enableFallbackBuffer();
  });

  tearDown(() {
    capturedEvents.clear();
    AnalyticsService.dispose();
  });

  tearDownAll(() {
    HiveTestHelper.tearDown();
  });

  group('OnboardingScreen — analytics events', () {
    testWidgets('onboarding_started is fired on mount', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final started = capturedEvents.firstWhere(
        (e) => e['event'] == 'onboarding_started',
        orElse: () => <String, dynamic>{},
      );
      expect(started, isNotEmpty);
      expect(started['event'], 'onboarding_started');
    });

    testWidgets('onboarding_step_viewed is fired when tapping Continue',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Tap "Continue" to go to step 2 — use pumpAndSettle for animation
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final stepEvent = capturedEvents.firstWhere(
        (e) => e['event'] == 'onboarding_step_viewed',
        orElse: () => <String, dynamic>{},
      );
      expect(stepEvent, isNotEmpty);
      final props = stepEvent['props'] as Map<String, dynamic>;
      expect(props['step'], 2);
      expect(props['total_steps'], 3);
    });

    testWidgets('onboarding_step_viewed is fired for each step',
        (tester) async {
      _setLargerViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Step 1 → 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      // Step 2 → 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final stepEvents =
          capturedEvents.where((e) => e['event'] == 'onboarding_step_viewed');
      expect(stepEvents.length, 2);
    });

    testWidgets('onboarding_completed is not fired before reaching last page',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Should be on step 1, "Continue" button visible, not "Add my first policy"
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Add my first policy'), findsNothing);

      // Verify no completed event yet
      final completed =
          capturedEvents.where((e) => e['event'] == 'onboarding_completed');
      expect(completed, isEmpty);
    });

    testWidgets(
        'accept terms checkbox enables the add policy button on last page',
        (tester) async {
      _setLargerViewport(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Navigate to last page via animated page transitions
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Find the FilledButton — it's in the fixed bottom section
      final addButton = find.widgetWithText(FilledButton, 'Add my first policy');
      expect(addButton, findsOneWidget);

      // Button should be disabled because terms checkbox is unchecked
      final button = tester.widget<FilledButton>(addButton);
      expect(button.onPressed, isNull);

      // Check the checkbox to enable the button
      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.pump();
      await tester.tap(checkbox);
      await tester.pump();

      // Now the button should be enabled
      final buttonAfter = tester.widget<FilledButton>(addButton);
      expect(buttonAfter.onPressed, isNotNull);
    });
  });
}
