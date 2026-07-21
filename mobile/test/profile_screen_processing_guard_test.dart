import 'dart:io';

import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/auth_provider.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/screens/profile_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper to create an InsuranceDocument with a specific processingState.
InsuranceDocument _doc(
  String id, {
  String filename = 'test.pdf',
  String processingState = 'ready',
}) {
  return InsuranceDocument(
    id: id,
    filename: filename,
    uploadedOn: DateTime(2026, 7, 10),
    processingState: processingState,
  );
}

/// Fake User for mocking Supabase auth.
/// Uses the standard User constructor from gotrue 2.25.0.
class _FakeUser extends User {
  _FakeUser()
      : super(
          id: 'test-user-id',
          aud: 'authenticated',
          appMetadata: const {},
          userMetadata: const {},
          createdAt: '2026-01-01T00:00:00Z',
        );

  @override
  String? get email => 'test@example.com';
}

/// Pump the tester to settle animations and then resolve any pending
/// FutureProvider futures. After `pumpAndSettle()`, Riverpod's
/// [FutureProvider] is still in [AsyncLoading] — an extra `pump()`
/// drives the microtask that delivers the [AsyncData].
Future<void> _pumpAndResolve(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Extra pump to resolve FutureProvider's async future from
  // AsyncLoading → AsyncData. Without this, ref.read(provider)
  // returns .valueOrNull == null.
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '/tmp/coverwise-profile-guard-tests';
    });
    final dir = Directory('/tmp/coverwise-profile-guard-tests');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    await dir.create(recursive: true);
    await Hive.initFlutter(dir.path);
    if (!Hive.isBoxOpen(LocalStorageService.documentsBoxName)) {
      await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    }
    if (!Hive.isBoxOpen(AppStateStore.boxName)) {
      await Hive.openBox(AppStateStore.boxName);
    }
    if (!Hive.isBoxOpen('resolved_gaps')) {
      await Hive.openBox('resolved_gaps');
    }
    if (!Hive.isBoxOpen('analytics_events')) {
      await Hive.openBox('analytics_events');
    }
    if (!Hive.isBoxOpen('consent_ledger')) {
      await Hive.openBox('consent_ledger');
    }
  });

  tearDownAll(() async {
    try {
    } catch (_) {}
  });

  /// Build a ProfileScreen with overridden providers.
  ///
  /// ProfileScreen now reads documents via ref.watch(documentsProvider) in
  /// build() and passes them to _confirmDeleteAccount. The FutureProvider
  /// override still needs to resolve, so we pump extra frames after build.
  Widget buildProfile({
    required List<InsuranceDocument> documents,
    bool hasAccount = true,
  }) {
    return ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => documents),
        if (hasAccount)
          currentUserProvider.overrideWithValue(_FakeUser())
        else
          currentUserProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(home: ProfileScreen()),
    );
  }

  group('ProfileScreen — pending-processing guard', () {
    testWidgets('describes local cache without claiming all data stays local',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(documents: []));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Device-first storage'), 200);
      expect(
        find.textContaining('account data may also be stored securely for sync'),
        findsOneWidget,
      );
      expect(find.text('Your policy workspace and personal details stay local.'),
          findsNothing);
    });

    testWidgets(
        'blocks deletion when a document is in "processing" state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'health.pdf', processingState: 'processing'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.textContaining('still processing'), findsOneWidget);
      expect(find.textContaining('health.pdf'), findsOneWidget);
      expect(find.text('Delete account permanently?'), findsNothing);
    });

    testWidgets(
        'blocks deletion when a document is in "received" state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'auto.pdf', processingState: 'received'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.textContaining('still processing'), findsOneWidget);
      expect(find.textContaining('auto.pdf'), findsOneWidget);
      expect(find.text('Delete account permanently?'), findsNothing);
    });

    testWidgets(
        'blocks deletion when a document is in "pending" state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'life.pdf', processingState: 'pending'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.textContaining('still processing'), findsOneWidget);
      expect(find.textContaining('life.pdf'), findsOneWidget);
      expect(find.text('Delete account permanently?'), findsNothing);
    });

    testWidgets(
        'blocks deletion with plural message when multiple documents are in-flight',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'health.pdf', processingState: 'processing'),
          _doc('doc-2', filename: 'auto.pdf', processingState: 'received'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.textContaining('2 documents are still processing'),
          findsOneWidget);
      expect(find.textContaining('health.pdf'), findsOneWidget);
      expect(find.textContaining('auto.pdf'), findsOneWidget);
    });

    testWidgets(
        'shows singular "is" when exactly one document is in-flight',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'travel.pdf', processingState: 'pending'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.textContaining('1 document is still processing'),
          findsOneWidget);
    });

    testWidgets(
        'allows deletion when all documents are in "ready" state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'health.pdf', processingState: 'ready'),
          _doc('doc-2', filename: 'auto.pdf', processingState: 'ready'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.text('Delete account permanently?'), findsOneWidget);
      expect(find.textContaining('still processing'), findsNothing);
    });

    testWidgets(
        'allows deletion when all documents are in "completed" state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'health.pdf', processingState: 'completed'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.text('Delete account permanently?'), findsOneWidget);
      expect(find.textContaining('still processing'), findsNothing);
    });

    testWidgets(
        'allows deletion when documents list is empty (no in-flight docs)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(documents: []));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.text('Delete account permanently?'), findsOneWidget);
      expect(find.textContaining('still processing'), findsNothing);
    });

    testWidgets(
        'blocks deletion only for in-flight docs, allows for ready docs in mixed list',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [
          _doc('doc-1', filename: 'ready.pdf', processingState: 'ready'),
          _doc('doc-2', filename: 'processing.pdf',
              processingState: 'processing'),
        ],
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.textContaining('still processing'), findsOneWidget);
      expect(find.textContaining('processing.pdf'), findsOneWidget);
      expect(find.text('Delete account permanently?'), findsNothing);
    });

    testWidgets(
        'shows "Create an account first" snackbar when no account',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildProfile(
        documents: [_doc('doc-1')],
        hasAccount: false,
      ));
      await _pumpAndResolve(tester);

      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.tap(find.text('Delete account'));
      await _pumpAndResolve(tester);

      expect(find.text('Create an account first to delete it'), findsOneWidget);
      expect(find.text('Delete account permanently?'), findsNothing);
    });
  });
}
