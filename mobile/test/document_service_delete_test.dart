import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDirectory;

  setUpAll(() async {
    testDirectory =
        await Directory.systemTemp.createTemp('coverwise-delete-test-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => testDirectory.path);
    await Hive.initFlutter(testDirectory.path);
    await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    await Hive.openBox(AppStateStore.boxName);
  });

  tearDownAll(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('remote-first deletion addresses the stored backend document id',
      () async {
    final storage = LocalStorageService();
    final file = File(
      '${Directory.systemTemp.path}/coverwise-delete-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(<int>[1, 2, 3]);

    final saved = await storage.saveDocument(file, remoteId: 'remote-doc-42');
    String? requestedPath;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        requestedPath = options.path;
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 204,
            data: <String, dynamic>{},
          ),
        );
      },
    );
    final dio = DocumentService.authenticatedDio;
    // Resolve before the production auth interceptor so this unit test does
    // not depend on a platform token channel.
    dio.interceptors.insert(0, interceptor);

    try {
      final deleted = await DocumentService(Dio()).deleteDocument(saved.id);

      expect(deleted, isTrue);
      expect(requestedPath, '/documents/remote-doc-42');
      expect(await storage.getDocumentById(saved.id), isNull);
    } finally {
      dio.interceptors.remove(interceptor);
      if (await file.exists()) await file.delete();
    }
  });

  test('remote deletion failure propagates and preserves the local record',
      () async {
    final storage = LocalStorageService();
    final file = File(
      '${Directory.systemTemp.path}/coverwise-delete-failure-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(<int>[4, 5, 6]);

    final saved = await storage.saveDocument(file, remoteId: 'remote-doc-503');
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 503,
            data: <String, dynamic>{'detail': 'temporarily unavailable'},
          ),
        );
      },
    );
    final dio = DocumentService.authenticatedDio;
    dio.interceptors.insert(0, interceptor);

    try {
      await expectLater(
        DocumentService(Dio()).deleteDocument(saved.id),
        throwsA(isA<Exception>()),
      );
      expect(await storage.getDocumentById(saved.id), isNotNull);
    } finally {
      dio.interceptors.remove(interceptor);
      if (await file.exists()) await file.delete();
      await storage.deleteDocument(saved.id);
    }
  });

  test('pending upload with a missing local artifact becomes explicit failure',
      () async {
    final storage = LocalStorageService();
    final source = File(
      '${testDirectory.path}/coverwise-missing-queued-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await source.writeAsBytes(<int>[7, 8, 9]);
    final saved = await storage.saveDocument(
      source,
      syncState: 'pending_upload',
      processingState: 'pending',
      processingConsentVersion: 'processing-v7',
      status: 'pending',
    );
    final localCopy = File(saved.localFilePath!);
    await localCopy.delete();

    final result = await DocumentService(Dio()).retryPendingUploads();

    expect(result['failed'], 1);
    final failed = await storage.getDocumentById(saved.id);
    expect(failed?.syncState, 'failed');
    expect(failed?.processingState, 'failed');
    await storage.deleteDocument(saved.id);
  });

  test('pending upload retry binds the server id to the existing local record',
      () async {
    final storage = LocalStorageService();
    final source = File(
      '${testDirectory.path}/coverwise-retry-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await source.writeAsBytes(<int>[10, 11, 12]);
    final saved = await storage.saveDocument(
      source,
      syncState: 'pending_upload',
      processingState: 'pending',
      processingConsentVersion: 'processing-v8',
      status: 'pending',
    );
    final dio = Dio();
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 202,
            data: <String, dynamic>{
              'documents': [
                <String, dynamic>{
                  'id': 'remote-retried-1',
                  'status': 'received',
                  'document_type': 'Health Insurance',
                },
              ],
            },
          ),
        );
      },
    );
    dio.interceptors.add(interceptor);

    try {
      final result = await DocumentService(dio).retryPendingUploads();
      expect(result['synced'], 1);
      final reconciled = await storage.getDocumentById(saved.id);
      expect(reconciled?.remoteId, 'remote-retried-1');
      expect(reconciled?.syncState, 'synced');
      expect(await storage.getDocuments(), hasLength(1));
    } finally {
      if (await source.exists()) await source.delete();
      await storage.deleteDocument(saved.id);
    }
  });

  test('pending upload keeps retryable server conflicts pending', () async {
    final storage = LocalStorageService();
    final source = File(
      '${testDirectory.path}/coverwise-retry-conflict-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await source.writeAsBytes(<int>[12, 13, 14]);
    final saved = await storage.saveDocument(
      source,
      syncState: 'pending_upload',
      processingState: 'pending',
      processingConsentVersion: 'processing-v9',
      status: 'pending',
    );
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 409,
          data: {
            'detail': {
              'code': 'upload_in_progress',
              'message': 'already processing',
            },
          },
        ));
      },
    ));

    try {
      final result = await DocumentService(dio).retryPendingUploads();
      expect(result['pending'], 1);
      final pending = await storage.getDocumentById(saved.id);
      expect(pending?.syncState, 'pending_upload');
      expect(pending?.processingState, 'pending');
    } finally {
      if (await source.exists()) await source.delete();
      await storage.deleteDocument(saved.id);
    }
  });

  test('pending upload keeps transient server failures pending', () async {
    final storage = LocalStorageService();
    final source = File(
      '${testDirectory.path}/coverwise-retry-503-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await source.writeAsBytes(<int>[15, 16, 17]);
    final saved = await storage.saveDocument(
      source,
      syncState: 'pending_upload',
      processingState: 'pending',
      processingConsentVersion: 'processing-v10',
      status: 'pending',
    );
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 503,
          data: {'detail': 'temporarily unavailable'},
        ));
      },
    ));

    try {
      final result = await DocumentService(dio).retryPendingUploads();
      expect(result['pending'], 1);
      final pending = await storage.getDocumentById(saved.id);
      expect(pending?.syncState, 'pending_upload');
    } finally {
      if (await source.exists()) await source.delete();
      await storage.deleteDocument(saved.id);
    }
  });

  test('retry coalesces callers created from different service instances',
      () async {
    final storage = LocalStorageService();
    final source = File(
      '${testDirectory.path}/coverwise-retry-coalesce-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await source.writeAsBytes(<int>[16, 17, 18]);
    final saved = await storage.saveDocument(
      source,
      syncState: 'pending_upload',
      processingState: 'pending',
      processingConsentVersion: 'processing-v11',
      status: 'pending',
    );
    final gate = Completer<void>();
    var requestCount = 0;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        requestCount++;
        await gate.future;
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 202,
          data: {
            'documents': [
              {'id': 'remote-coalesced-1', 'status': 'received'},
            ],
          },
        ));
      },
    ));

    try {
      final first = DocumentService(dio).retryPendingUploads();
      final second = DocumentService(dio).retryPendingUploads();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requestCount, 1);
      gate.complete();
      final results = await Future.wait([first, second]);
      expect(results[0]['synced'], 1);
      expect(results[1]['synced'], 1);
      expect(await storage.getDocumentById(saved.id), isNotNull);
    } finally {
      if (!gate.isCompleted) gate.complete();
      if (await source.exists()) await source.delete();
      await storage.deleteDocument(saved.id);
    }
  });
}
