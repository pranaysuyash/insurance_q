import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/services/app_state_repository.dart';
import 'package:coverwise/services/app_state_store.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(HiveTestHelper.setUp);
  tearDownAll(HiveTestHelper.tearDown);

  setUp(() async {
    await HiveTestHelper.setUp();
    // The helper intentionally keeps the shared box open across tests.
    // Clear only the navigation pointers under test.
    final box = Hive.box(AppStateStore.boxName);
    await box.delete(AppStateStore.selectedDocumentIdKey);
    await box.delete(AppStateStore.lastUploadedDocumentIdKey);
    await box.delete(AppStateStore.lastViewedDocumentIdKey);
  });

  test('clears local and server-ID navigation references after deletion', () async {
    await AppStateRepository.setSelectedDocumentId('remote-doc-7');
    await AppStateRepository.setLastUploadedDocumentId('local-doc-7');
    await AppStateRepository.setLastViewedDocumentId('remote-doc-7');

    await AppStateRepository.clearDocumentReferences(
        {'local-doc-7', 'remote-doc-7'});

    expect(AppStateRepository.getSelectedDocumentId(), isNull);
    expect(AppStateRepository.getLastUploadedDocumentId(), isNull);
    expect(AppStateRepository.getLastViewedDocumentId(), isNull);
  });
}
