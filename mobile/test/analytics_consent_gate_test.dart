import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/services/analytics_service.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'helpers/hive_test_helper.dart';

void main() {
  late Box<dynamic> box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  setUp(() async {
    box = Hive.box<dynamic>(AppStateStore.boxName);
    final consentBox = Hive.box<dynamic>('consent_ledger');
    // Clear consent and analytics buffer before each test.
    await consentBox.clear();
    await box.delete(AppStateStore.analyticsEventsKey);
    AnalyticsService.clear();
    AnalyticsService.refreshConsentCache();
  });

  tearDown(() async {
    await Hive.box<dynamic>('consent_ledger').clear();
    await box.delete(AppStateStore.analyticsEventsKey);
    AnalyticsService.dispose();
  });

  tearDownAll(HiveTestHelper.tearDown);

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

    test('first launch: events are dropped (no record defaults to false per security audit P0-10)',
        () async {
      // On first launch, no consent record exists. _checkConsentFresh()
      // returns false (fail-closed) per security audit P0-10. The user
      // must explicitly grant analytics through the privacy screen.
      final ledger = ConsentLedger();
      expect(ledger.hasConsent(ConsentPurpose.analytics), isFalse);

      AnalyticsService.refreshConsentCache();

      // Events should be dropped — no record defaults to false (fail-closed).
      AnalyticsService.track('first_launch_event');
      expect(AnalyticsService.queuedCount, 0);
    });

    test('events are dropped when ledger is corrupted (fail-closed per P0-10)', () async {
      // Corrupt the consent ledger data.
      await Hive.box<dynamic>('consent_ledger').add('not-valid-json');

      // _checkConsentFresh catches the error and defaults to false (fail-closed).
      AnalyticsService.refreshConsentCache();

      // Track an event — should be dropped because fallback is false.
      AnalyticsService.track('corrupted_ledger_event');
      expect(AnalyticsService.queuedCount, 0);
    });
  });
}
