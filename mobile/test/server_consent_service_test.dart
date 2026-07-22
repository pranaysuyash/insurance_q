import 'package:coverwise/services/server_consent_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Dio testDio() {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        ),
      ),
    ));
    return dio;
  }

  group('ServerConsentRecord', () {
    test('parses a known consent_type from JSON', () {
      final r = ServerConsentRecord.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'user_id': 'user-1',
        'consent_type': 'analytics',
        'granted': true,
        'policy_version': 'v1.0',
        'ip_address': '192.168.1.1',
        'user_agent': 'coverwise-mobile/0.1.2',
        'created_at': '2026-07-19T10:00:00+00:00',
      });
      expect(r.id, '00000000-0000-0000-0000-000000000001');
      expect(r.userId, 'user-1');
      expect(r.consentType, 'analytics');
      expect(r.granted, isTrue);
      expect(r.policyVersion, 'v1.0');
      expect(r.ipAddress, '192.168.1.1');
      expect(r.userAgent, 'coverwise-mobile/0.1.2');
      expect(r.createdAt.year, 2026);
      expect(r.createdAt.month, 7);
      expect(r.createdAt.day, 19);
    });

    test('handles a missing ip_address (the Flutter app may not have it)', () {
      final r = ServerConsentRecord.fromJson({
        'id': '00000000-0000-0000-0000-000000000001',
        'user_id': 'user-1',
        'consent_type': 'privacy_policy',
        'granted': true,
        'policy_version': 'v1.0',
        'ip_address': null,
        'user_agent': null,
        'created_at': '2026-07-19T10:00:00+00:00',
      });
      expect(r.ipAddress, isNull);
      expect(r.userAgent, isNull);
    });

    test('handles a revocation (granted=false)', () {
      final r = ServerConsentRecord.fromJson({
        'id': '00000000-0000-0000-0000-000000000002',
        'user_id': 'user-1',
        'consent_type': 'marketing_emails',
        'granted': false,
        'policy_version': 'v1.0',
        'ip_address': null,
        'user_agent': null,
        'created_at': '2026-07-19T10:10:00+00:00',
      });
      expect(r.granted, isFalse);
    });

    test('knownConsentTypes has exactly 7 types in v1', () {
      expect(ServerConsentRecord.knownConsentTypes.length, 7);
      expect(
        ServerConsentRecord.knownConsentTypes.contains('privacy_policy'),
        isTrue,
      );
      expect(
        ServerConsentRecord.knownConsentTypes.contains('document_processing'),
        isTrue,
      );
      expect(
        ServerConsentRecord.knownConsentTypes.contains('analytics'),
        isTrue,
      );
      expect(
        ServerConsentRecord.knownConsentTypes.contains('marketing_emails'),
        isTrue,
      );
      expect(
        ServerConsentRecord.knownConsentTypes.contains('camera_access'),
        isTrue,
      );
      expect(
        ServerConsentRecord.knownConsentTypes.contains('evaluation_dataset'),
        isTrue,
      );
      expect(
        ServerConsentRecord.knownConsentTypes.contains('model_improvement'),
        isTrue,
      );
    });

    test('rejects an unknown consent_type by surfacing the raw value', () {
      // The Flutter side does not enforce the consent_type
      // enum; the server is the source of truth. An unknown
      // type from the server is shown as-is. The cache
      // invalidation logic decides what to do with it.
      final r = ServerConsentRecord.fromJson({
        'id': '00000000-0000-0000-0000-000000000003',
        'user_id': 'user-1',
        'consent_type': 'biometric_data', // not in v1 enum
        'granted': true,
        'policy_version': 'v1.0',
        'ip_address': null,
        'user_agent': null,
        'created_at': '2026-07-19T10:00:00+00:00',
      });
      expect(r.consentType, 'biometric_data');
      expect(
        ServerConsentRecord.knownConsentTypes.contains(r.consentType),
        isFalse,
      );
    });
  });

  group('ServerConsentService type signature', () {
    test('recordConsent returns Future<String?>', () async {
      final svc = ServerConsentService(dio: testDio());
      final future = svc.recordConsent(
        consentType: 'analytics',
        granted: true,
        policyVersion: 'v1.0',
      );
      expect(future, isA<Future<String?>>());
      expect(await future, isNull);
    });

    test('getCurrentConsentAll returns Future<List<ServerConsentRecord>?>',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final future = svc.getCurrentConsentAll();
      expect(future, isA<Future<List<ServerConsentRecord>?>>());
      expect(await future, isNull);
    });
  });
}
