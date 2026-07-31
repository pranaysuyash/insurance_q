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

  Dio responseDio(Object? data, {int statusCode = 200}) {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: statusCode,
          data: data,
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
    test('recordConsent returns ConsentNetworkError when request is cancelled',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final result = await svc.recordConsent(
        consentType: 'analytics',
        granted: true,
        policyVersion: 'v1.0',
      );
      expect(result, isA<ConsentNetworkError>());
    });

    test('recordConsent returns ConsentTypeRejected for unknown type',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final result = await svc.recordConsent(
        consentType: 'totally_unknown_type',
        granted: true,
        policyVersion: 'v1.0',
      );
      expect(result, isA<ConsentTypeRejected>());
    });

    test(
        'recordConsent returns ConsentTypeRejected for typo "analytic" (missing s)',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final result = await svc.recordConsent(
        consentType: 'analytic',
        granted: true,
        policyVersion: 'v1.0',
      );
      expect(result, isA<ConsentTypeRejected>());
    });

    test(
        'recordConsent returns ConsentTypeRejected for typo "document_processsing" (triple s)',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final result = await svc.recordConsent(
        consentType: 'document_processsing',
        granted: true,
        policyVersion: 'v1.0',
      );
      expect(result, isA<ConsentTypeRejected>());
    });

    test('recordConsent returns ConsentTypeRejected for empty string',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final result = await svc.recordConsent(
        consentType: '',
        granted: true,
        policyVersion: 'v1.0',
      );
      expect(result, isA<ConsentTypeRejected>());
    });

    test('recordConsent returns ConsentTypeRejected for whitespace-only type',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final result = await svc.recordConsent(
        consentType: '  ',
        granted: true,
        policyVersion: 'v1.0',
      );
      expect(result, isA<ConsentTypeRejected>());
    });

    test(
        'recordConsent returns ConsentRecorded for all 7 known types',
        () async {
      // Use responseDio to simulate server acceptance (201).
      final svc = ServerConsentService(
        dio: responseDio(
          {
            'id': '00000000-0000-0000-0000-000000000099',
            'consent_type': 'analytics',
          },
          statusCode: 201,
        ),
      );
      final knownTypes = ServerConsentRecord.knownConsentTypes.toList();
      expect(knownTypes, hasLength(7));
      for (final type in knownTypes) {
        final result = await svc.recordConsent(
          consentType: type,
          granted: true,
          policyVersion: 'v1.0',
        );
        expect(
          result,
          isA<ConsentRecorded>(),
          reason: 'Expected ConsentRecorded for known type "$type"',
        );
      }
    });

    test('getCurrentConsentAll returns ConsentSnapshotUnavailable on cancel',
        () async {
      final svc = ServerConsentService(dio: testDio());
      final result = await svc.getCurrentConsentAll();
      expect(result, isA<ConsentSnapshotUnavailable>());
    });

    test('getConsentHistory reads typed newest-first ledger entries', () async {
      final svc = ServerConsentService(
        dio: responseDio([
          {
            'id': '00000000-0000-0000-0000-000000000004',
            'user_id': 'user-1',
            'consent_type': 'analytics',
            'granted': false,
            'policy_version': 'analytics-v1',
            'ip_address': null,
            'user_agent': null,
            'created_at': '2026-07-25T08:30:00+00:00',
          },
          {
            'id': '00000000-0000-0000-0000-000000000005',
            'user_id': 'user-1',
            'consent_type': 'privacy_policy',
            'granted': true,
            'policy_version': '1.2',
            'ip_address': null,
            'user_agent': null,
            'created_at': '2026-07-24T08:30:00+00:00',
          },
        ]),
      );

      final result = await svc.getConsentHistory(limit: 20);

      expect(result, isA<ConsentSnapshotLoaded>());
      final records = (result as ConsentSnapshotLoaded).records;
      expect(records, hasLength(2));
      expect(records.first.consentType, 'analytics');
      expect(records.first.granted, isFalse);
      expect(records.last.policyVersion, '1.2');
    });

    test('getConsentHistory returns ConsentSnapshotUnavailable when ledger is unavailable',
        () async {
      final svc = ServerConsentService(dio: testDio());

      final result = await svc.getConsentHistory();
      expect(result, isA<ConsentSnapshotUnavailable>());
    });
  });
}
