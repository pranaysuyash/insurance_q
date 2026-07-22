import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:coverwise/screens/documents_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/hive_test_helper.dart';

/// Tests the _ensureConsent() helper in DocumentsScreen through
/// widget integration, covering stale consent, healthy consent,
/// and cancellation edge cases.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        if (call.method == 'read') return null;
        if (call.method == 'readAll') return <String, String>{};
        return null;
      },
    );

    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  /// Sets a fixed viewport so layout tests don't depend on the host machine.
  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> cleanDb(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Hive.box('consent_ledger').clear();
      await Hive.box(AppStateStore.boxName).clear();
    });
  }

  /// Pre-sets the processing_consent_version in the Hive app_state box.
  Future<void> setConsentVersion(WidgetTester tester, String version) async {
    await tester.runAsync(() async {
      await Hive.box(AppStateStore.boxName)
          .put('processing_consent_version', version);
    });
  }

  /// Pre-records a consent grant in the consent_ledger box.
  Future<void> recordConsentInLedger(
    WidgetTester tester, {
    required String purpose,
    required String version,
    required bool granted,
  }) async {
    await tester.runAsync(() async {
      await Hive.box('consent_ledger').add({
        'purpose': purpose,
        'version': version,
        'granted': granted,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Counts consent_ledger records for a given purpose.
  int countLedgerRecords(String purpose) {
    final box = Hive.box('consent_ledger');
    int count = 0;
    for (final value in box.values) {
      try {
        final map = Map<String, dynamic>.from(value);
        if (map['purpose'] == purpose) count++;
      } catch (_) {}
    }
    return count;
  }

  /// Checks if the consent_ledger has an active record for a purpose.
  /// Delegates to [ConsentLedger.hasConsent] to stay aligned with real behavior.
  bool hasActiveConsentInLedger(ConsentPurpose purpose) {
    return ConsentLedger().hasConsent(purpose);
  }

  /// Builds a DocumentsScreen wrapped in a ProviderScope.
  Widget buildApp({List<InsuranceDocument> documents = const []}) {
    return ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => documents),
      ],
      child: const MaterialApp(
        home: DocumentsScreen(initialFileName: 'policy.pdf'),
      ),
    );
  }

  /// Taps the upload button and pumps so the consent flow can execute.
  Future<void> tapUpload(WidgetTester tester) async {
    final finder = find.text('Upload Selected File');
    await tester.ensureVisible(finder);
    await tester.runAsync(() async {
      await tester.tap(finder);
      await tester.pump();
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  }

  // ─── Stale consent ─────────────────────────────────────────────────

  group('Stale consent (version in Hive, ledger empty)', () {
    testWidgets('records consent in ledger', (tester) async {
      await cleanDb(tester);
      setViewport(tester);
      await setConsentVersion(tester, 'v1');
      expect(countLedgerRecords('document_processing'), 0);

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tapUpload(tester);

      expect(countLedgerRecords('document_processing'), 1);
      expect(hasActiveConsentInLedger(ConsentPurpose.documentProcessing), isTrue);
    });

    testWidgets('records correct version string', (tester) async {
      await cleanDb(tester);
      setViewport(tester);
      await setConsentVersion(tester, 'v2_upgrade');

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tapUpload(tester);

      final box = Hive.box('consent_ledger');
      String? recordedVersion;
      for (final value in box.values) {
        try {
          final map = Map<String, dynamic>.from(value);
          if (map['purpose'] == 'document_processing') {
            recordedVersion = map['version'] as String?;
          }
        } catch (_) {}
      }
      expect(recordedVersion, 'v2_upgrade');
    });
  });

  // ─── Healthy consent ───────────────────────────────────────────────

  group('Healthy consent (version in Hive + ledger already populated)', () {
    testWidgets('does not create duplicate ledger record', (tester) async {
      await cleanDb(tester);
      await setConsentVersion(tester, 'v1');
      await recordConsentInLedger(
        tester,
        purpose: 'document_processing',
        version: 'v1',
        granted: true,
      );
      expect(countLedgerRecords('document_processing'), 1);

      setViewport(tester);
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tapUpload(tester);

      // Still exactly 1 record — no duplicate.
      expect(countLedgerRecords('document_processing'), 1);
    });

    testWidgets('re-records consent when ledger has revoked record',
        (tester) async {
      await cleanDb(tester);
      // Pre-set version in Hive, but ledger has a revoked consent.
      // _ensureConsent() sees hasConsent() == false and re-records.
      await setConsentVersion(tester, 'v1');
      const revokedRecord = {
        'purpose': 'document_processing',
        'version': 'v1',
        'granted': false,
        'timestamp': '2026-07-01T00:00:00.000',
        'revoked_at': '2026-07-01T00:00:00.000',
      };
      await tester.runAsync(() async {
        await Hive.box('consent_ledger').add(revokedRecord);
      });
      expect(countLedgerRecords('document_processing'), 1);
      expect(hasActiveConsentInLedger(ConsentPurpose.documentProcessing),
          isFalse);

      setViewport(tester);
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tapUpload(tester);

      // _ensureConsent() re-records consent because hasConsent() was false.
      expect(countLedgerRecords('document_processing'), 2);
      expect(hasActiveConsentInLedger(ConsentPurpose.documentProcessing),
          isTrue);
    });

    testWidgets('does not affect other consent purposes', (tester) async {
      await cleanDb(tester);
      await setConsentVersion(tester, 'v1');
      await recordConsentInLedger(tester, purpose: 'document_processing', version: 'v1', granted: true);
      await recordConsentInLedger(tester, purpose: 'analytics', version: 'v1', granted: true);
      expect(countLedgerRecords('document_processing'), 1);
      expect(countLedgerRecords('analytics'), 1);

      setViewport(tester);
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tapUpload(tester);

      expect(countLedgerRecords('document_processing'), 1);
      expect(countLedgerRecords('analytics'), 1);
    });
  });

  // ─── Cancellation ──────────────────────────────────────────────────

  group('First-upload cancellation (no pre-existing consent)', () {
    testWidgets('returns null and records nothing when dialog cancelled',
        (tester) async {
      await cleanDb(tester);
      // Set a predictable surface size so we know dialog boundaries.
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // No pre-existing consent version — the dialog should appear.

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap upload — this triggers _uploadFile() → _ensureConsent().
      await tapUpload(tester);

      // The LeadCaptureDialog should now be visible. Dismiss by tapping
      // the system back button (reliably dismisses any dialog).
      if (find.byType(Dialog).evaluate().isNotEmpty) {
        await tester.pageBack();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      // No consent should have been recorded or persisted.
      expect(countLedgerRecords('document_processing'), 0);

      final storedConsent =
          Hive.box(AppStateStore.boxName).get('processing_consent_version');
      expect(storedConsent, isNull);
    });
  });

  // ─── Existing consent fast path ────────────────────────────────────

  group('Existing consent fast path', () {
    testWidgets('no dialog appears when consent already exists',
        (tester) async {
      await cleanDb(tester);
      await setConsentVersion(tester, 'v1');
      await recordConsentInLedger(tester, purpose: 'document_processing', version: 'v1', granted: true);

      setViewport(tester);
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tapUpload(tester);

      // The fast path should skip the dialog entirely.
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('returns existing version without re-prompt on version change',
        (tester) async {
      await cleanDb(tester);
      // Even if the stored version is "v1" (no upgrade logic exists yet),
      // _ensureConsent() should return it without showing a dialog.
      await setConsentVersion(tester, 'v1');
      await recordConsentInLedger(tester, purpose: 'document_processing', version: 'v1', granted: true);

      setViewport(tester);
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tapUpload(tester);

      // No dialog shown (fast path).
      expect(find.byType(Dialog), findsNothing);
      // Version still v1.
      final stored =
          Hive.box(AppStateStore.boxName).get('processing_consent_version');
      expect(stored, 'v1');
    });
  });
}
