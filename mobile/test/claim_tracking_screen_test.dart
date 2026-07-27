import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'package:coverwise/models/claim_record.dart';
import 'package:coverwise/screens/claim_tracking_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/theme/coverwise_theme.dart';

/// Test claim shared across tests.
final _testClaim = ClaimRecord(
  id: 'test-1',
  documentId: 'doc-1',
  policyType: 'Health Insurance',
  insurer: 'ICICI Lombard',
  incidentType: 'Hospitalization',
  description: 'Car hit pole on Marine Drive',
  filedDate: DateTime(2026, 7, 23),
);

/// Seed claim records into the Hive box before a test.
Future<void> _seedClaims(List<ClaimRecord> claims) async {
  final box = Hive.box(AppStateStore.boxName);
  await box.put(
    AppStateStore.claimRecordsKey,
    jsonEncode(claims.map((c) => c.toJson()).toList()),
  );
}

/// Clear seeded claims from the Hive box.
Future<void> _clearClaims() async {
  final box = Hive.box(AppStateStore.boxName);
  await box.delete(AppStateStore.claimRecordsKey);
}

/// Build the widget inside ProviderScope + MaterialApp.
Widget _buildTestApp() {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates:
          AppLocalizationsGen.localizationsDelegates,
      supportedLocales: AppLocalizationsGen.supportedLocales,
      theme: CoverWiseTheme.light(),
      home: const ClaimTrackingScreen(),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => testDir.path,
    );
    testDir = await Directory.systemTemp.createTemp('claim-track-tests-');
    await Hive.initFlutter(testDir.path);
    await Hive.openBox(AppStateStore.boxName);
  });

  tearDown(() async {
    await _clearClaims();
  });

  // ─────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────
  group('ClaimTrackingScreen — empty state', () {
    testWidgets('shows empty state widget with CTA when no claims exist',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('No claims logged yet'), findsOneWidget);
      expect(find.text('Log a claim'), findsWidgets);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('shows app bar title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('Claim log'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────
  // List with claims
  // ─────────────────────────────────────────────────────
  group('ClaimTrackingScreen — claim card rendering', () {
    setUp(() async {
      await _seedClaims([_testClaim]);
    });

    testWidgets('renders claim card with incident type and description',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('Hospitalization'), findsOneWidget);
      expect(find.text('Car hit pole on Marine Drive'), findsOneWidget);
    });

    testWidgets('renders metadata chips: insurer, date, reference prompt',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('ICICI Lombard'), findsOneWidget);
      expect(find.text('23/7/2026'), findsOneWidget);
      expect(find.text('Add ref. no.'), findsOneWidget);
    });

    testWidgets('shows page header and section label', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('Your claim notes'), findsOneWidget);
      expect(find.text('LOGGED CLAIMS'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────
  // Expand / collapse timeline
  // ─────────────────────────────────────────────────────
  group('ClaimTrackingScreen — expand/collapse timeline', () {
    setUp(() async {
      await _seedClaims([_testClaim]);
    });

    testWidgets('tapping "View status timeline" expands the timeline',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('View status timeline'), findsOneWidget);
      expect(find.text('Hide status timeline'), findsNothing);

      await tester.tap(find.text('View status timeline'));
      await tester.pumpAndSettle();

      expect(find.text('Hide status timeline'), findsOneWidget);
      expect(find.text('Your recorded status history'), findsWidgets);
    });

    testWidgets('tapping "Hide status timeline" collapses the timeline',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('View status timeline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide status timeline'));
      await tester.pumpAndSettle();

      expect(find.text('View status timeline'), findsOneWidget);
      expect(find.text('Hide status timeline'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────
  // Reference number editing
  // ─────────────────────────────────────────────────────
  group('ClaimTrackingScreen — reference number editing', () {
    setUp(() async {
      await _seedClaims([_testClaim]);
    });

    testWidgets('tapping "Add ref. no." opens reference number dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('Add ref. no.'));
      await tester.pumpAndSettle();

      expect(find.text('Claim reference number'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('saving a reference number closes the dialog', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('Add ref. no.'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Dialog closed after Save (empty text → no save, but dialog closes)
      expect(find.text('Claim reference number'), findsNothing);
      expect(find.text('Add ref. no.'), findsOneWidget);
    });

    testWidgets('cancel does not change reference number', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.text('Add ref. no.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add ref. no.'), findsOneWidget);
      expect(find.text('Ref:'), findsNothing);
    });
  });

  // ─────────────────────────────────────────────────────
  // Status update tracking
  // ─────────────────────────────────────────────────────
  group('ClaimTrackingScreen — status update', () {
    setUp(() async {
      await _seedClaims([_testClaim]);
    });

    testWidgets('status popup menu opens and shows options', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      expect(find.text('Recorded as filed'), findsWidgets);

      await tester.tap(find.text('Recorded as filed').first);
      await tester.pumpAndSettle();

      expect(find.text('Recorded as in review'), findsWidgets);
      expect(find.text('Recorded as approved'), findsWidgets);
      expect(find.text('Recorded as rejected'), findsWidgets);
      expect(find.text('Recorded as paid'), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────
  // Delete confirmation
  // ─────────────────────────────────────────────────────
  group('ClaimTrackingScreen — delete claim', () {
    setUp(() async {
      await _seedClaims([_testClaim]);
    });

    testWidgets('tapping delete icon shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.byTooltip('Delete Hospitalization claim record'));
      await tester.pumpAndSettle();

      expect(find.text('Delete claim record?'), findsOneWidget);
      expect(find.textContaining('Delete the claim'), findsOneWidget);
    });

    // NOTE: A 'confirming delete closes the dialog' test is intentionally
    // omitted because it triggers Hive I/O (_deleteClaim → deleteClaimRecord)
    // which writes to disk via dart:io in the fake async zone. This causes
    // a 'Cannot close sink' stream channel error during test shutdown.
    // The Hive delete operation is tested separately in
    // app_state_repository_test.dart (unit tests, no fake async zone).

    testWidgets('cancelling delete keeps the claim card', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();

      await tester.tap(find.byTooltip('Delete Hospitalization claim record'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Hospitalization'), findsOneWidget);
      expect(find.text('No claims logged yet'), findsNothing);
    });
  });
}

/// Temporary directory for Hive storage (defined here so setUpAll can access it).
late Directory testDir;
