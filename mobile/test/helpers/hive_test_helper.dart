import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coverwise/models/identity.dart';
import 'package:coverwise/services/analytics_service.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/hive_workspace_service.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/principal_key_service.dart';

/// Shared Hive test helper that provides consistent initialization and cleanup
/// for all test files. Eliminates lock contention by ensuring boxes are opened
/// once per test suite and closed properly in tearDownAll.
///
/// Handles:
/// - Path provider mock (required for Hive.initFlutter in tests)
/// - Hive initialization with a dedicated temp directory
/// - Opening all common box names
/// - Clean teardown
///
/// Usage in test files:
/// ```dart
/// import 'helpers/hive_test_helper.dart';
///
/// void main() {
///   setUpAll(() async => await HiveTestHelper.setUp());
///   tearDownAll(() async => await HiveTestHelper.tearDown());
///   // ... tests
/// }
/// ```
class HiveTestHelper {
  HiveTestHelper._();

  static Directory? _testDirectory;
  static const _pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  /// All box names that tests may need.
  static const _boxNames = <String>[
    LocalStorageService.documentsBoxName,
    AppStateStore.boxName,
    'resolved_gaps',
    'analytics_events',
    'consent_ledger',
    'qa_history',
    'field_overrides_box',
    'entitlements',
    'agent_requests',
    'newsletter',
  ];

  /// Initialize Hive and open all required boxes.
  /// Mocks the path_provider channel so Hive.initFlutter works in tests.
  /// Safe to call multiple times — will skip if already initialized.
  static Future<void> setUp() async {
    // Mock path_provider for Hive.initFlutter
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (call) async {
      return _testDirectory!.path;
    });

    _testDirectory ??=
        await Directory.systemTemp.createTemp('coverwise-hive-tests-');
    await Hive.initFlutter(_testDirectory!.path);

    for (final name in _boxNames) {
      if (!Hive.isBoxOpen(name)) {
        // Match production openForActivePrincipal() type signatures.
        // app_state_box and consent_ledger are Box<dynamic>; all others are Box<String>.
        if (name == AppStateStore.boxName || name == 'consent_ledger' || name == 'agent_requests' || name == 'newsletter') {
          await Hive.openBox(name);
        } else {
          await Hive.openBox<String>(name);
        }
      }
    }
  }

  /// Close all open Hive boxes and shut down Hive.
  /// Also cancels the analytics sync timer so the test isolate can exit.
  /// Safe to call even if boxes aren't open.
  static Future<void> tearDown() async {
    AnalyticsService.dispose();
    // Do not close boxes individually, and do not await recursive deletion of
    // an open Hive directory. Both operations can deadlock the test isolate.
    // The directory is intentionally process-scoped temporary test data; the
    // OS/test runner owns its cleanup after the isolate exits.
    _testDirectory = null;
  }

  /// In-memory flutter_secure_storage backing store for [_mockSecureStorage].
  static final Map<String, String> _secureStorage = {};

  /// Mocks flutter_secure_storage so a principal DEK can be created without
  /// a platform channel. Used by [openTestWorkspace] and by test files that
  /// exercise [PrincipalKeyService] directly.
  ///
  /// In tests without this mock, `FlutterSecureStorage.read()` (used by
  /// [PrincipalKeyService.initForPrincipal] and the AuthInterceptor) waits
  /// for a platform response that never arrives and hangs the test isolate.
  static void mockSecureStorage() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'read':
            final key = (call.arguments as Map)['key'] as String;
            return _secureStorage[key];
          case 'write':
            final args = call.arguments as Map;
            _secureStorage[args['key'] as String] = args['value'] as String;
            return null;
          case 'readAll':
            return Map<String, String>.from(_secureStorage);
          case 'delete':
            _secureStorage.remove((call.arguments as Map)['key'] as String);
            return null;
          case 'deleteAll':
            _secureStorage.clear();
            return null;
          case 'containsKey':
            final key = (call.arguments as Map)['key'] as String;
            return _secureStorage.containsKey(key);
          default:
            return null;
        }
      },
    );
  }

  /// Opens a principal-scoped test workspace so that
  /// [LocalStorageService.saveDocument] (which requires an active workspace
  /// for the encrypted attachment store — CW-P0-002) works in unit tests.
  ///
  /// Hive 2.x returns already-open boxes as-is from `Hive.openBox` (path and
  /// cipher are ignored), so pre-opened boxes from [setUp] keep working while
  /// `HiveWorkspaceService.workspacePath` becomes available for file writes.
  ///
  /// Call in `setUpAll` alongside [setUp], and [closeTestWorkspace] in
  /// `tearDownAll`.
  static Future<void> openTestWorkspace({
    String principalId = 'test-principal',
  }) async {
    mockSecureStorage();
    await PrincipalKeyService().initForPrincipal(principalId);
    await HiveWorkspaceService.openForActivePrincipal(
      LocalPrincipal(principalId),
    );
  }

  /// Tears down the in-memory principal key and resets the secure-storage
  /// mock so it does not leak into other tests in the same isolate.
  static void closeTestWorkspace() {
    PrincipalKeyService().clearKey();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  }
}
