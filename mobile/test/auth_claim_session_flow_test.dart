import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coverwise/services/auth_service.dart';
import 'package:coverwise/services/app_state_store.dart';

Map<String, String> _secureStorage = {};

void _mockSecureStorage() {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;

  setUp(() async {
    _secureStorage = {};
    _mockSecureStorage();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp/coverwise-auth-tests',
    );
    final dir = Directory('/tmp/coverwise-auth-tests');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    await Hive.initFlutter(dir.path);
    if (!Hive.isBoxOpen(AppStateStore.boxName)) {
      await Hive.openBox(AppStateStore.boxName);
    }
    container = ProviderContainer();
    // Instantiate AuthNotifier so AuthService's static methods
    // delegate to a real notifier instead of short-circuiting.
    container.read(authServiceProvider.notifier);
  });

  tearDown(() async {
    _secureStorage = {};
    container.dispose();
    await Hive.close();
  });

  test('anonymous claim intent flag is single-use', () async {
    final notifier = container.read(authServiceProvider.notifier);
    await notifier.prepareAnonymousWorkspaceClaim();
    expect(notifier.consumeAnonymousWorkspaceClaim(), isFalse);

    _secureStorage['anonymous_auth_token'] = 'token-abc';
    await notifier.prepareAnonymousWorkspaceClaim();
    expect(notifier.consumeAnonymousWorkspaceClaim(), isTrue);
    expect(notifier.consumeAnonymousWorkspaceClaim(), isFalse);
  });

  test('anonymous claim intent remains false when no token exists', () async {
    _secureStorage = {};
    final notifier = container.read(authServiceProvider.notifier);
    await notifier.prepareAnonymousWorkspaceClaim();
    expect(notifier.consumeAnonymousWorkspaceClaim(), isFalse);
  });
}
