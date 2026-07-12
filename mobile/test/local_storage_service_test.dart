import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coverwise/services/local_storage_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('coverwise-storage-test');
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getLibraryDirectory':
        case 'getTemporaryDirectory':
        case 'getExternalStorageDirectory':
          return tempDir.path;
        case 'getExternalStorageDirectories':
        case 'getExternalCacheDirectories':
          return <String>[tempDir.path];
        case 'getDownloadsDirectory':
          return tempDir.path;
      }
      return null;
    });
    await Hive.initFlutter(tempDir.path);
    await Hive.openBox<String>(LocalStorageService.documentsBoxName);
  });

  setUp(() async {
    await Hive.box<String>(LocalStorageService.documentsBoxName).clear();
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await Hive.box<String>(LocalStorageService.documentsBoxName).close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves document with a separate remote id and resolves it later',
      () async {
    final service = LocalStorageService();
    final file = File('${tempDir.path}/policy.pdf');
    await file.writeAsBytes([1, 2, 3, 4]);

    final saved = await service.saveDocument(
      file,
      remoteId: 'remote-123',
      additionalMetadata: {
        'document_type': 'Health Insurance',
        'insurer': 'ICICI Lombard',
      },
    );

    expect(saved.id, isNotEmpty);
    expect(saved.remoteId, 'remote-123');
    expect(saved.backendId, 'remote-123');

    final backendId = await service.getBackendDocumentId(saved.id);
    expect(backendId, 'remote-123');

    final roundTripped = await service.getDocumentById(saved.id);
    expect(roundTripped, isNotNull);
    expect(roundTripped!.remoteId, 'remote-123');
    expect(roundTripped.documentType, 'Health Insurance');
  });

  test('preserves the stored document list without auto deleting', () async {
    final service = LocalStorageService();
    final file = File('${tempDir.path}/policy-two.pdf');
    await file.writeAsBytes([9, 8, 7, 6]);

    final saved = await service.saveDocument(file);

    final documents = await service.getDocuments();
    expect(documents, hasLength(1));
    expect(documents.first.id, saved.id);

    final deleted = await service.deleteDocument(saved.id);
    expect(deleted, isTrue);
    expect(await service.getDocuments(), isEmpty);
  });
}
