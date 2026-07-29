import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coverwise/models/entitlement.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/entitlement_provider.dart';
import 'package:coverwise/screens/coverage_details_summary_screen.dart';
import 'package:coverwise/services/analytics_service.dart';
import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'helpers/hive_test_helper.dart';

/// Returns a minimal PolicySummary for testing.
PolicySummary _testSummary() => PolicySummary(
      documentId: 'test_doc_1',
      documentType: 'health_insurance',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      extractedAt: DateTime(2026, 7, 29),
      keyBenefits: const ['Cashless hospitalization', 'Day care procedures'],
      exclusions: const ['Pre-existing diseases for 2 years'],
    );

/// Creates a test app wrapping the screen with a given entitlement state.
Widget _buildTestApp({required Entitlement entitlement}) {
  // Override the entitlement provider to return the test state.
  return ProviderScope(
    overrides: [
      entitlementProvider
          .overrideWith(() => EntitlementNotifierTest(entitlement)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
      supportedLocales: AppLocalizationsGen.supportedLocales,
      home: Scaffold(
        body: CoverageDetailsSummaryScreen(summary: _testSummary()),
      ),
    ),
  );
}

/// Test notifier that returns a fixed entitlement.
class EntitlementNotifierTest extends EntitlementNotifier {
  final Entitlement _fixed;
  EntitlementNotifierTest(this._fixed);

  @override
  Entitlement build() => _fixed;
}

void main() {
  setUpAll(() async {
    await HiveTestHelper.setUp();
    SharedPreferences.setMockInitialValues({});
    // Ensure analytics doesn't throw during tests
    AnalyticsService.enableFallbackBuffer();
  });

  tearDownAll(() {
    HiveTestHelper.tearDown();
    AnalyticsService.dispose();
  });

  testWidgets('free user sees share button but export is gated with snackbar',
      (tester) async {
    await tester.pumpWidget(_buildTestApp(
      entitlement: const Entitlement(planTier: PlanTier.free),
    ));

    // Wait for the screen to render
    await tester.pumpAndSettle();

    // Verify the share button exists (visible but gated)
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);

    // Tap the share button — should show a snackbar instead of sharing
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    // Verify the snackbar appears with upgrade messaging
    expect(find.textContaining('Export is available on Plus'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });

  testWidgets('plus user can share without gating', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      entitlement: const Entitlement(planTier: PlanTier.plus),
    ));

    await tester.pumpAndSettle();

    // Share button should be present
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);

    // Verify the snackbar does NOT appear — user can share directly
    expect(find.textContaining('Export is available on Plus'), findsNothing);
  });

  testWidgets('family user can share without gating', (tester) async {
    await tester.pumpWidget(_buildTestApp(
      entitlement: const Entitlement(planTier: PlanTier.family),
    ));

    await tester.pumpAndSettle();

    // Share button should be present
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);

    // Verify the snackbar does NOT appear
    expect(find.textContaining('Export is available on Plus'), findsNothing);
  });

  test('free tier has allowExport=false in PlanLimits', () {
    final limits = planLimits[PlanTier.free]!;
    expect(limits.allowExport, isFalse);
  });

  test('plus tier has allowExport=true in PlanLimits', () {
    final limits = planLimits[PlanTier.plus]!;
    expect(limits.allowExport, isTrue);
  });

  test('family tier has allowExport=true in PlanLimits', () {
    final limits = planLimits[PlanTier.family]!;
    expect(limits.allowExport, isTrue);
  });
}
