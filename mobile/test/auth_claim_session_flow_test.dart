import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/services/auth_service.dart';

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

  setUp(() {
    _secureStorage = {};
    _mockSecureStorage();
  });

  tearDown(() {
    _secureStorage = {};
  });

  test('anonymous claim intent flag is single-use', () async {
    await AuthService.prepareAnonymousWorkspaceClaim();
    expect(AuthService.consumeAnonymousWorkspaceClaim(), isFalse);

    _secureStorage['anonymous_auth_token'] = 'token-abc';
    await AuthService.prepareAnonymousWorkspaceClaim();
    expect(AuthService.consumeAnonymousWorkspaceClaim(), isTrue);
    expect(AuthService.consumeAnonymousWorkspaceClaim(), isFalse);
  });

  test('anonymous claim intent remains false when no token exists', () async {
    _secureStorage = {};
    await AuthService.prepareAnonymousWorkspaceClaim();
    expect(AuthService.consumeAnonymousWorkspaceClaim(), isFalse);
  });
}
