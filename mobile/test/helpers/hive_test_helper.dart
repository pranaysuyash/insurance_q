import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coverwise/services/analytics_service.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';

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
        if (name == LocalStorageService.documentsBoxName) {
          await Hive.openBox<String>(name);
        } else {
          await Hive.openBox(name);
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
}
