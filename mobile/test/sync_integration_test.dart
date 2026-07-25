import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:coverwise/services/consent_sync_service.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/local_storage_service.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  tearDown(() async {
    await Hive.box<dynamic>(AppStateStore.boxName).clear();
    await Hive.box<String>(LocalStorageService.documentsBoxName).clear();
    await Hive.box<dynamic>('consent_ledger').clear();
  });

  group('ConsentSyncService', () {
    test('syncs new consent records', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {'id': 'server-consent-id-1'},
          ));
        },
      ));

      await ConsentLedger().recordConsent(
        purpose: ConsentPurpose.analytics,
        version: '1.0',
        granted: true,
      );

      final synced = await ConsentSyncService(dio: dio).syncAll();

      expect(synced, greaterThanOrEqualTo(1),
          reason: 'Should sync at least analytics consent');
    });

    test('skips already-synced consent types (signature match)', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {'id': 'server-consent-id'},
          ));
        },
      ));

      await ConsentLedger().recordConsent(
        purpose: ConsentPurpose.analytics,
        version: '1.0',
        granted: true,
      );

      final first = await ConsentSyncService(dio: dio).syncAll();
      expect(first, greaterThanOrEqualTo(1));

      var serverCalls = 0;
      final dio2 = Dio();
      dio2.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          serverCalls++;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {'id': 'server-consent-id'},
          ));
        },
      ));

      final second = await ConsentSyncService(dio: dio2).syncAll();

      expect(second, equals(0),
          reason: 'Should not re-sync already cached signatures');
      expect(serverCalls, equals(0),
          reason: 'Should not make any server calls');
    });

    test('retries failed consent records on next call', () async {
      final dio = Dio();
      var callCount = 0;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          callCount++;
          handler.reject(DioException(
            requestOptions: options,
            error: 'Timeout',
            type: DioExceptionType.connectionTimeout,
          ));
        },
      ));

      await ConsentLedger().recordConsent(
        purpose: ConsentPurpose.analytics,
        version: '1.0',
        granted: true,
      );

      await ConsentSyncService(dio: dio).syncAll();
      expect(callCount, greaterThanOrEqualTo(1));

      final dio2 = Dio();
      var callCount2 = 0;
      dio2.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          callCount2++;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {'id': 'server-consent-id'},
          ));
        },
      ));

      final synced = await ConsentSyncService(dio: dio2).syncAll();
      expect(synced, greaterThanOrEqualTo(1),
          reason: 'Should retry and succeed');
      expect(callCount2, greaterThanOrEqualTo(1));
    });

    test('deduplicates concurrent syncAll calls', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 201,
            data: {'id': 'server-consent-id'},
          ));
        },
      ));

      await ConsentLedger().recordConsent(
        purpose: ConsentPurpose.analytics,
        version: '1.0',
        granted: true,
      );
      await ConsentLedger().recordConsent(
        purpose: ConsentPurpose.documentProcessing,
        version: '1.0',
        granted: true,
      );

      final service = ConsentSyncService(dio: dio);
      final f1 = service.syncAll();
      final f2 = service.syncAll();

      expect(identical(f1, f2), isTrue,
          reason: 'Concurrent calls should share the same future');
    });
  });

  group('DocumentService retryPendingUploads', () {
    /// Creates a pending document with an actual file on disk at the path
    /// set by [LocalStorageService.saveDocument].
    Future<String> savePendingDocument({
      required String filename,
      required Uint8List bytes,
      String? remoteId,
    }) async {
      final tmpFile = File('${Directory.systemTemp.path}/$filename');
      await tmpFile.writeAsBytes(bytes);

      final storage = LocalStorageService();
      final doc = await storage.saveDocument(
        tmpFile,
        remoteId: remoteId,
        syncState: remoteId != null ? 'synced' : 'pending_upload',
        processingState: 'pending',
        status: 'pending',
      );
      await tmpFile.delete();
      return doc.localFilePath!;
    }

    test('classifies HTTP 200 as synced', () async {
      await savePendingDocument(
        filename: 'synced.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'documents': [
                {'id': 'remote-200', 'status': 'completed'}
              ]
            },
          ));
        },
      ));

      final result =
          await DocumentService(dio).retryPendingUploads();

      expect(result['synced'], equals(1));
      expect(result['failed'], equals(0));
      expect(result['pending'], equals(0));
    });

    test('classifies HTTP 429 as pending', () async {
      await savePendingDocument(
        filename: 'rate-limited.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 429,
            data: {'detail': 'Too many requests'},
          ));
        },
      ));

      final result =
          await DocumentService(dio).retryPendingUploads();
      expect(result['pending'], equals(1));
    });

    test('classifies HTTP 500 as pending', () async {
      await savePendingDocument(
        filename: 'server-error.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 500,
            data: {'detail': 'Internal server error'},
          ));
        },
      ));

      final result =
          await DocumentService(dio).retryPendingUploads();
      expect(result['pending'], equals(1));
    });

    test('classifies HTTP 422 as failed', () async {
      await savePendingDocument(
        filename: 'bad-request.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 422,
            data: {'detail': 'Unprocessable'},
          ));
        },
      ));

      final result =
          await DocumentService(dio).retryPendingUploads();
      expect(result['failed'], equals(1));
    });

    test('classifies 409+upload_in_progress as pending', () async {
      await savePendingDocument(
        filename: 'conflict.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 409,
            data: {
              'detail': {'code': 'upload_in_progress'}
            },
          ));
        },
      ));

      final result =
          await DocumentService(dio).retryPendingUploads();
      expect(result['pending'], equals(1));
    });

    test('classifies transport error as pending', () async {
      await savePendingDocument(
        filename: 'transport-error.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'Connection refused',
          ));
        },
      ));

      final result =
          await DocumentService(dio).retryPendingUploads();
      expect(result['pending'], equals(1));
    });

    test('missing local file marks as failed', () async {
      final storage = LocalStorageService();
      // Manually write a document with a nonexistent localFilePath
      final doc = await storage.saveWebDocument(
        'missing.pdf',
        Uint8List.fromList([1, 2, 3]),
        syncState: 'pending_upload',
        processingState: 'pending',
        status: 'pending',
      );
      // Override localFilePath to a path that does not exist
      final fixed = doc.copyWith(
        localFilePath: '/nonexistent/missing.pdf',
      );
      await storage.updateDocument(fixed);

      final dio = Dio();
      final result =
          await DocumentService(dio).retryPendingUploads();
      expect(result['failed'], equals(1));
    });

    test('deduplicates concurrent retryPendingUploads calls', () async {
      final dio = Dio();
      var serverCalls = 0;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          serverCalls++;
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'documents': [
                {'id': 'remote-dedup', 'status': 'completed'}
              ]
            },
          ));
        },
      ));

      final service = DocumentService(dio);
      await savePendingDocument(
        filename: 'dedup1.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      final f1 = service.retryPendingUploads();
      final f2 = service.retryPendingUploads();

      await Future.wait([f1, f2]);

      expect(serverCalls, equals(1),
          reason: 'Deduplicated calls should make only one server request');
    });
  });
}
