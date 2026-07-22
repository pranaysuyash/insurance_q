import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/local_storage_service.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    hiveDirectory =
        await Directory.systemTemp.createTemp('coverwise-reconcile-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    await Hive.openBox(AppStateStore.boxName);
  });

  setUp(() async {
    await Hive.box<String>(LocalStorageService.documentsBoxName).clear();
    final storage = LocalStorageService();
    await storage.saveWebDocument(
      'pending.pdf',
      Uint8List.fromList([1, 2, 3]),
      syncState: 'pending_upload',
      processingState: 'pending',
      status: 'pending',
    );
    await storage.saveWebDocument(
      'deleted-on-server.pdf',
      Uint8List.fromList([1]),
      remoteId: 'remote-deleted',
      syncState: 'synced',
      processingState: 'completed',
      status: 'completed',
    );
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('hydrates remote-only account documents and preserves pending uploads',
      () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'documents': [
              {
                'id': 'remote-account-doc',
                'filename': 'account-policy.pdf',
                'size': 4096,
                'upload_date': '2026-07-21T10:00:00Z',
                'status': 'completed',
                'document_type': 'Health Insurance',
                'insurer': 'Example Insurer',
              },
            ],
            'total_pages': 1,
          },
        ));
      },
    ));

    final documents = await DocumentService(dio).syncAccountDocuments();

    expect(documents.map((document) => document.remoteId),
        contains('remote-account-doc'));
    expect(documents.any((document) => document.filename == 'pending.pdf'),
        isTrue);
    expect(
      documents.any((document) => document.remoteId == 'remote-deleted'),
      isFalse,
    );
    final remote = documents
        .firstWhere((document) => document.remoteId == 'remote-account-doc');
    expect(remote.localFilePath, isNull);
    expect(remote.syncState, 'synced');
  });

  test('does not mutate local state when a later page is malformed', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final page = options.queryParameters['page'];
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: page == 1
              ? {
                  'documents': [
                    {
                      'id': 'remote-page-one',
                      'filename': 'page-one.pdf',
                      'size': 1,
                      'upload_date': '2026-07-21T10:00:00Z',
                      'status': 'completed',
                    },
                  ],
                  'total_pages': 2,
                }
              : {'unexpected': true},
        ));
      },
    ));

    await expectLater(
      DocumentService(dio).syncAccountDocuments(),
      throwsA(isA<StateError>()),
    );
    final localDocuments = await LocalStorageService().getDocuments();
    expect(localDocuments.map((document) => document.filename),
        contains('deleted-on-server.pdf'));
    expect(localDocuments.map((document) => document.filename),
        isNot(contains('page-one.pdf')));
  });
}
