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
    hiveDirectory = await Directory.systemTemp.createTemp('coverwise-library-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    await Hive.openBox(AppStateStore.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('library loading does not issue a hidden Q&A metadata query', () async {
    final storage = LocalStorageService();
    await Hive.box<String>(LocalStorageService.documentsBoxName).clear();
    await storage.saveWebDocument(
      'unknown-policy.pdf',
      Uint8List.fromList([1, 2, 3]),
      additionalMetadata: {'document_type': 'Unknown'},
    );

    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            error: 'No network call is expected while loading local library',
          ),
        );
      },
    ));

    final documents = await DocumentService(dio).getDocuments();

    expect(documents, hasLength(1));
    expect(documents.single.documentType, 'Unknown');
  });
}
