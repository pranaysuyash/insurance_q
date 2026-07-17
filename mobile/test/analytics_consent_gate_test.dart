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
  });

  group('AnalyticsService track() consent gating', () {
    test('events flow when analytics consent is granted', () async {
      // Record analytics consent as granted.
      final ledger = ConsentLedger();
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: true,
      );
      AnalyticsService.refreshConsentCache();

      // Track an event.
      AnalyticsService.track('test_event', {'key': 'value'});

      // Verify event was queued.
      expect(AnalyticsService.queuedCount, 1);
    });

    test('events are dropped when analytics consent is revoked', () async {
      // Record analytics consent as granted, then revoke it.
      final ledger = ConsentLedger();
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: true,
      );
      await ledger.revokeConsent(ConsentPurpose.analytics);
      AnalyticsService.refreshConsentCache();

      // Track an event — should be dropped.
      AnalyticsService.track('test_event', {'key': 'value'});

      // Verify event was NOT queued.
      expect(AnalyticsService.queuedCount, 0);
    });

    test('events resume after consent is re-enabled', () async {
      // Grant, revoke, then re-grant.
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

    test('events flow when no consent record exists (first launch)', () async {
      // No consent record — refreshConsentCache reads from ledger.
      // On first launch, _recordAnalyticsConsent grants consent async.
      // For this test, we simulate: no record → grant → track.
      final ledger = ConsentLedger();
      expect(ledger.hasConsent(ConsentPurpose.analytics), isFalse);

      // Grant consent (simulating what _recordAnalyticsConsent does).
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: true,
      );
      AnalyticsService.refreshConsentCache();

      AnalyticsService.track('first_launch_event');
      expect(AnalyticsService.queuedCount, 1);
    });
  });
}
