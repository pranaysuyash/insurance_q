import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/services/analytics_service.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:coverwise/services/app_state_store.dart';

void main() {
  late Box box;

  setUp(() async {
    // Initialize Hive for tests.
    if (!Hive.isBoxOpen(AppStateStore.boxName)) {
      Hive.init('test_analytics_gate_hive');
      box = await Hive.openBox(AppStateStore.boxName);
    } else {
      box = Hive.box(AppStateStore.boxName);
    }
    // Clear consent and analytics buffer before each test.
    await box.delete('consent_ledger_v1');
    await box.delete(AppStateStore.analyticsEventsKey);
    AnalyticsService.clear();
  });

  tearDown(() async {
    await box.delete('consent_ledger_v1');
    await box.delete(AppStateStore.analyticsEventsKey);
    AnalyticsService.dispose();
    // Close Hive to prevent test pollution across test files.
    if (Hive.isBoxOpen(AppStateStore.boxName)) {
      await Hive.close();
    }
  });

  group('AnalyticsService track() consent gating', () {
    test('events flow when analytics consent is granted', () async {
      final ledger = ConsentLedger();
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: true,
      );
      AnalyticsService.refreshConsentCache();

      AnalyticsService.track('test_event', {'key': 'value'});
      expect(AnalyticsService.queuedCount, 1);
    });

    test('events are dropped when analytics consent is revoked', () async {
      final ledger = ConsentLedger();
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: true,
      );
      await ledger.revokeConsent(ConsentPurpose.analytics);
      AnalyticsService.refreshConsentCache();

      AnalyticsService.track('test_event', {'key': 'value'});
      expect(AnalyticsService.queuedCount, 0);
    });

    test('events resume after consent is re-enabled', () async {
      final ledger = ConsentLedger();
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: true,
      );
      await ledger.revokeConsent(ConsentPurpose.analytics);
      AnalyticsService.refreshConsentCache();

      // Track while revoked — dropped.
      AnalyticsService.track('revoked_event');
      expect(AnalyticsService.queuedCount, 0);

      // Re-grant consent.
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: true,
      );
      AnalyticsService.refreshConsentCache();

      // Track after re-grant — should flow.
      AnalyticsService.track('re_enabled_event');
      expect(AnalyticsService.queuedCount, 1);
    });

    test('first launch: events flow immediately (no record defaults to true)',
        () async {
      // On first launch, no consent record exists. _checkConsentFresh()
      // returns true (fail-open) so analytics flow from the start.
      final ledger = ConsentLedger();
      expect(ledger.hasConsent(ConsentPurpose.analytics), isFalse);

      AnalyticsService.refreshConsentCache();

      // Events should flow immediately — no record defaults to true.
      AnalyticsService.track('first_launch_event');
      expect(AnalyticsService.queuedCount, 1);
    });

    test('events flow when ledger is corrupted (fallback to true)', () async {
      // Corrupt the consent ledger data.
      await box.put('consent_ledger_v1', 'not-valid-json');

      // _checkConsentFresh catches the error and defaults to true.
      AnalyticsService.refreshConsentCache();

      // Track an event — should flow because fallback is true.
      AnalyticsService.track('corrupted_ledger_event');
      expect(AnalyticsService.queuedCount, 1);
    });
  });
}
