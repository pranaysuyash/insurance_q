import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/local_storage_service.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  setUpAll(HiveTestHelper.setUp);
  tearDownAll(HiveTestHelper.tearDown);

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
    dio.interceptors.add(interceptor);

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
}
