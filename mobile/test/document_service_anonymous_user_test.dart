import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/local_storage_service.dart';

/// Fake Supabase User for testing anonymous vs registered classification.
///
/// Overrides [email] and [phone] to control whether the user appears
/// anonymous (no email, no phone) or registered (at least one credential).
class _FakeUser extends User {
  _FakeUser({String? testEmail, String? testPhone})
      : _testEmail = testEmail,
        _testPhone = testPhone,
        super(
          id: 'test-user-id',
          aud: 'authenticated',
          appMetadata: const {},
          userMetadata: const {},
          createdAt: '2026-01-01T00:00:00Z',
        );

  final String? _testEmail;
  final String? _testPhone;

  @override
  String? get email => _testEmail;

  @override
  String? get phone => _testPhone;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDirectory;

  setUpAll(() async {
    testDirectory = await Directory.systemTemp.createTemp(
      'coverwise-anonymous-test-',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => testDirectory.path);
    await Hive.initFlutter(testDirectory.path);
    await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    await Hive.openBox(AppStateStore.boxName);
    await Hive.openBox('consent_ledger');
    await ConsentLedger().recordConsent(
      purpose: ConsentPurpose.documentProcessing,
      version: 'test',
      granted: true,
    );
  });

  tearDownAll(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  // ── _isAnonymousUser classification ────────────────────────────────

  group('DocumentService.isAnonymousUser', () {
    test('returns true for a user with no email and no phone', () {
      final user = _FakeUser();
      expect(DocumentService.isAnonymousUser(user), isTrue);
    });

    test('returns true for a user with empty email and no phone', () {
      final user = _FakeUser(testEmail: '');
      expect(DocumentService.isAnonymousUser(user), isTrue);
    });

    test('returns true for a user with no email and empty phone', () {
      final user = _FakeUser(testPhone: '');
      expect(DocumentService.isAnonymousUser(user), isTrue);
    });

    test('returns true for a user with both email and phone empty', () {
      final user = _FakeUser(testEmail: '', testPhone: '');
      expect(DocumentService.isAnonymousUser(user), isTrue);
    });

    test('returns false for a user with an email but no phone', () {
      final user = _FakeUser(testEmail: 'user@example.com');
      expect(DocumentService.isAnonymousUser(user), isFalse);
    });

    test('returns false for a user with a phone but no email', () {
      final user = _FakeUser(testPhone: '+919876543210');
      expect(DocumentService.isAnonymousUser(user), isFalse);
    });

    test('returns false for a user with both email and phone', () {
      final user = _FakeUser(
        testEmail: 'user@example.com',
        testPhone: '+919876543210',
      );
      expect(DocumentService.isAnonymousUser(user), isFalse);
    });
  });

  // ── getDocuments() reconciliation guard ────────────────────────────

  group('DocumentService.getDocuments() — reconciliation skip', () {
    test(
      'returns local-only documents when Supabase is not initialized '
      '(no account reconciliation attempted)',
      () async {
        final storage = LocalStorageService();
        final file = File(
          '${testDirectory.path}/coverwise-anon-local.pdf',
        );
        await file.writeAsBytes(<int>[1, 2, 3]);
        final saved = await storage.saveDocument(file);

        try {
          // Supabase is not initialized in this test harness, so
          // Supabase.instance.client.auth throws inside getDocuments().
          // The catch block sets isRegisteredAccount = false, meaning
          // syncAccountDocuments() is never called and local docs are
          // returned directly.
          //
          // Audit 5 P1.9: An anonymous Supabase session (or a missing
          // session) must not trigger account-level reconciliation.
          final docs = await DocumentService(Dio()).getDocuments();

          expect(docs, hasLength(1));
          expect(docs.first.id, saved.id);
          expect(docs.first.filename, 'coverwise-anon-local.pdf');
        } finally {
          await storage.deleteDocument(saved.id);
        }
      },
    );

    test(
      'returns local-only documents when Supabase has no session '
      '(anonymous / logged-out user)',
      () async {
        final storage = LocalStorageService();
        final file = File(
          '${testDirectory.path}/coverwise-anon-no-session.pdf',
        );
        await file.writeAsBytes(<int>[4, 5, 6]);
        final saved = await storage.saveDocument(file);

        try {
          // Same as above: Supabase.instance.client.auth.currentSession
          // is either null or throws because Supabase is not initialized.
          // isRegisteredAccount stays false.
          final docs = await DocumentService(Dio()).getDocuments();

          expect(docs, hasLength(1));
          expect(docs.first.id, saved.id);
        } finally {
          await storage.deleteDocument(saved.id);
        }
      },
    );

    test(
      'does not call the /documents API when Supabase throws',
      () async {
        final storage = LocalStorageService();
        final file = File(
          '${testDirectory.path}/coverwise-anon-no-network.pdf',
        );
        await file.writeAsBytes(<int>[7, 8, 9]);
        final saved = await storage.saveDocument(file);

        // Track whether the Dio instance receives any GET /documents
        // request. If reconciliation is properly skipped, no such
        // request should be made.
        var networkRequestMade = false;
        final dio = Dio();
        dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/documents')) {
              networkRequestMade = true;
            }
            handler.reject(DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ));
          },
        ));

        try {
          final docs = await DocumentService(dio).getDocuments();

          // Local docs should be returned without any network call.
          expect(docs, hasLength(1));
          expect(docs.first.id, saved.id);
          expect(networkRequestMade, isFalse);
        } finally {
          await storage.deleteDocument(saved.id);
        }
      },
    );
  });
}
