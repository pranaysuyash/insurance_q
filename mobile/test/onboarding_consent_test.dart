import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coverwise/config/app_config.dart';
import 'package:coverwise/services/consent_ledger.dart';

void main() {
  late ConsentLedger ledger;
  late Directory hiveTestDir;

  setUpAll(() {
    hiveTestDir = Directory.systemTemp.createTempSync('onboarding_consent_test_');
    Hive.init(hiveTestDir.path);
  });

  tearDownAll(() async {
    if (Hive.isBoxOpen('consent_ledger')) {
      await Hive.box('consent_ledger').close();
    }
    if (hiveTestDir.existsSync()) {
      hiveTestDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    if (Hive.isBoxOpen('consent_ledger')) {
      await Hive.box('consent_ledger').close();
    }
    await Hive.openBox('consent_ledger');
    // Clear any records from the previous test — Hive persists data
    // across close/reopen cycles, so we must explicitly clear.
    await Hive.box('consent_ledger').clear();
    ledger = ConsentLedger();
  });

  tearDown(() async {
    if (Hive.isBoxOpen('consent_ledger')) {
      await Hive.box('consent_ledger').close();
    }
  });

  // ── P0.22: Terms of Service recorded separately ──────────────────────

  group('Audit 6 P0.22 — terms recorded separately from privacy policy', () {
    test('termsOfService is a distinct ConsentPurpose value', () {
      expect(ConsentPurpose.termsOfService, isNotNull);
      expect(ConsentPurpose.termsOfService.value, 'terms_of_service');
    });

    test('recording privacyPolicy does NOT create a termsOfService record',
        () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.privacyPolicy,
        version: AppConfig.privacyPolicyVersion,
        granted: true,
      );

      // Only privacyPolicy should be recorded.
      expect(ledger.hasConsent(ConsentPurpose.privacyPolicy), isTrue);
      expect(ledger.hasConsent(ConsentPurpose.termsOfService), isFalse);
    });

    test('recording termsOfService does NOT create a privacyPolicy record',
        () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.termsOfService,
        version: AppConfig.privacyPolicyVersion,
        granted: true,
      );

      expect(ledger.hasConsent(ConsentPurpose.termsOfService), isTrue);
      expect(ledger.hasConsent(ConsentPurpose.privacyPolicy), isFalse);
    });

    test('both can be recorded independently and tracked separately',
        () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.privacyPolicy,
        version: 'v1',
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.termsOfService,
        version: 'v1',
        granted: true,
      );

      // Both active.
      expect(ledger.hasConsent(ConsentPurpose.privacyPolicy), isTrue);
      expect(ledger.hasConsent(ConsentPurpose.termsOfService), isTrue);

      // Revoke privacy policy — terms should remain.
      await ledger.revokeConsent(ConsentPurpose.privacyPolicy);
      expect(ledger.hasConsent(ConsentPurpose.privacyPolicy), isFalse);
      expect(ledger.hasConsent(ConsentPurpose.termsOfService), isTrue);
    });

    test('both are recorded with the same version (coupled lifecycle)', () async {
      final version = AppConfig.privacyPolicyVersion;
      await ledger.recordConsent(
        purpose: ConsentPurpose.privacyPolicy,
        version: version,
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.termsOfService,
        version: version,
        granted: true,
      );

      final ppRecord = ledger.getLatestRecord(ConsentPurpose.privacyPolicy);
      final tosRecord = ledger.getLatestRecord(ConsentPurpose.termsOfService);
      expect(ppRecord?.version, version);
      expect(tosRecord?.version, version);
    });

    test('getAllRecords returns both purposes in the same ledger', () async {
      await ledger.recordConsent(
        purpose: ConsentPurpose.privacyPolicy,
        version: 'v1',
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.termsOfService,
        version: 'v1',
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: false,
      );

      final allPurposes =
          ledger.getAllRecords().map((r) => r.purpose).toSet();
      expect(allPurposes, containsAll([
        ConsentPurpose.privacyPolicy,
        ConsentPurpose.termsOfService,
        ConsentPurpose.analytics,
      ]));
    });
  });

  // ── P0.21: Onboarding blocks on consent failure ──────────────────────

  group('Audit 6 P0.21 — consent write failure blocks onboarding', () {
    test('recordConsent throws when Hive box is unavailable', () async {
      // Close the box to simulate workspace-not-open.
      await Hive.box('consent_ledger').close();

      // This is the same pattern onboarding uses:
      //   await ledger.recordConsent(purpose: ..., version: ..., granted: true);
      // If the box is closed, it must throw — not silently succeed.
      expect(
        () => ledger.recordConsent(
          purpose: ConsentPurpose.privacyPolicy,
          version: AppConfig.privacyPolicyVersion,
          granted: true,
        ),
        throwsA(isA<StateError>()),
      );

      // Re-open for tearDown — wrap in try/catch in case reopen fails.
      try {
        await Hive.openBox('consent_ledger');
      } catch (_) {}
    });

    test('required consent records are durable after write', () async {
      // Simulate onboarding writing required consent.
      await ledger.recordConsent(
        purpose: ConsentPurpose.privacyPolicy,
        version: AppConfig.privacyPolicyVersion,
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.termsOfService,
        version: AppConfig.privacyPolicyVersion,
        granted: true,
      );

      // Verify both are durable (not just in-memory).
      expect(ledger.hasConsent(ConsentPurpose.privacyPolicy), isTrue);
      expect(ledger.hasConsent(ConsentPurpose.termsOfService), isTrue);

      // Re-create the ledger — records should persist via same Hive box.
      final ledger2 = ConsentLedger();
      expect(ledger2.hasConsent(ConsentPurpose.privacyPolicy), isTrue);
      expect(ledger2.hasConsent(ConsentPurpose.termsOfService), isTrue);
    });

    test('privacyPolicy can be revoked independently after onboarding', () async {
      // Onboarding records both.
      await ledger.recordConsent(
        purpose: ConsentPurpose.privacyPolicy,
        version: AppConfig.privacyPolicyVersion,
        granted: true,
      );
      await ledger.recordConsent(
        purpose: ConsentPurpose.termsOfService,
        version: AppConfig.privacyPolicyVersion,
        granted: true,
      );

      // User revokes privacy policy later.
      await ledger.revokeConsent(ConsentPurpose.privacyPolicy);

      expect(ledger.hasConsent(ConsentPurpose.privacyPolicy), isFalse);
      expect(ledger.hasConsent(ConsentPurpose.termsOfService), isTrue);
    });
  });
}
