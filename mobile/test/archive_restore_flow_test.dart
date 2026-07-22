import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/screens/documents_list.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/service_providers.dart';
import 'package:coverwise/services/app_state_store.dart';

// ── Fake DocumentService for widget tests ─────────────────────────

/// A [DocumentService] that does not need a real backend.
/// Only archive/restore are overridden — other methods throw if called.
class FakeDocumentService extends DocumentService {
  bool _archiveSucceeds = true;
  bool _restoreSucceeds = true;

  /// Track which document IDs have been archived or restored.
  final archivedIds = <String>{};
  final restoredIds = <String>{};

  FakeDocumentService()
      : super(Dio(BaseOptions(baseUrl: 'http://localhost:9999')));

  void setArchiveSucceeds(bool value) => _archiveSucceeds = value;
  void setRestoreSucceeds(bool value) => _restoreSucceeds = value;

  @override
  Future<bool> archiveDocument(String documentId) async {
    if (_archiveSucceeds) {
      archivedIds.add(documentId);
      return true;
    }
    return false;
  }

  @override
  Future<bool> restoreDocument(String documentId) async {
    if (_restoreSucceeds) {
      restoredIds.add(documentId);
      return true;
    }
    return false;
  }

  @override
  Future<int> archivedDocumentCount() async => archivedIds.length;

  @override
  Future<int> activeDocumentCount() async => 0;
}

void main() {
  late Directory tempDir;
  late LocalStorageService storageService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('coverwise-archive-test');
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
    await Hive.openBox(AppStateStore.boxName);
  });

  setUp(() async {
    await Hive.box<String>(LocalStorageService.documentsBoxName).clear();
    await Hive.box(AppStateStore.boxName).clear();
    storageService = LocalStorageService();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  // ── Helpers ──────────────────────────────────────────────────────

  InsuranceDocument makeDoc(String id, {bool archived = false}) {
    return InsuranceDocument(
      id: id,
      filename: 'policy_$id.pdf',
      uploadedOn: DateTime(2026, 7, 20),
      documentType: 'Health Insurance',
      insurer: 'ICICI Lombard',
      status: 'completed',
      syncState: 'synced',
      processingState: 'ready',
      localFilePath: '${tempDir.path}/$id.pdf',
      remoteId: 'remote-$id',
      isArchived: archived,
      archivedAt: archived ? DateTime(2026, 7, 21) : null,
    );
  }

  Future<InsuranceDocument> saveDoc(String id, {bool archived = false}) async {
    final file = File('${tempDir.path}/$id.pdf');
    await file.writeAsBytes([1, 2, 3, 4]);
    final saved = await storageService.saveDocument(file);
    if (archived) {
      await storageService.archiveDocument(saved.id);
    }
    final doc = await storageService.getDocumentById(saved.id);
    return doc!;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. LocalStorageService — archive / restore
  // ═══════════════════════════════════════════════════════════════════

  group('LocalStorageService — archive/restore', () {
    test('archiveDocument marks document as archived with timestamp', () async {
      final doc = await saveDoc('arch-test-1');
      expect(doc.isArchived, false);
      expect(doc.archivedAt, isNull);

      final success = await storageService.archiveDocument(doc.id);
      expect(success, isTrue);

      final archived = await storageService.getDocumentById(doc.id);
      expect(archived, isNotNull);
      expect(archived!.isArchived, isTrue);
      expect(archived.archivedAt, isNotNull);
      // archivedAt should be close to now
      final age = DateTime.now().difference(archived.archivedAt!);
      expect(age.inSeconds, lessThan(5));
    });

    test('archiveDocument returns false for non-existent document', () async {
      final success = await storageService.archiveDocument('non-existent-id');
      expect(success, isFalse);
    });

    test('restoreDocument clears archived flag and timestamp', () async {
      final doc = await saveDoc('rest-test-1', archived: true);
      expect(doc.isArchived, isTrue);
      expect(doc.archivedAt, isNotNull);

      final success = await storageService.restoreDocument(doc.id);
      expect(success, isTrue);

      final restored = await storageService.getDocumentById(doc.id);
      expect(restored, isNotNull);
      expect(restored!.isArchived, isFalse);
      expect(restored.archivedAt, isNull);
    });

    test('restoreDocument returns false for non-existent document', () async {
      final success =
          await storageService.restoreDocument('non-existent-id');
      expect(success, isFalse);
    });

    test('archive -> restore round-trip preserves all other fields',
        () async {
      final doc = await saveDoc('roundtrip-1');
      final original = await storageService.getDocumentById(doc.id);

      await storageService.archiveDocument(doc.id);
      await storageService.restoreDocument(doc.id);

      final restored = await storageService.getDocumentById(doc.id);
      expect(restored!.filename, original!.filename);
      expect(restored.documentType, original.documentType);
      expect(restored.insurer, original.insurer);
      expect(restored.status, original.status);
      expect(restored.localFilePath, original.localFilePath);
    });

    test('archivedDocumentCount returns correct count', () async {
      await saveDoc('count-1', archived: true);
      await saveDoc('count-2', archived: true);
      await saveDoc('count-3'); // active

      final count = await storageService.archivedDocumentCount();
      expect(count, 2);
    });

    test('activeDocumentCount excludes archived documents', () async {
      await saveDoc('active-1');
      await saveDoc('active-2');
      await saveDoc('active-3', archived: true); // archived

      final count = await storageService.activeDocumentCount();
      expect(count, 2);
    });

    test('getDocuments returns both active and archived documents',
        () async {
      await saveDoc('list-1');
      await saveDoc('list-2', archived: true);

      final allDocs = await storageService.getDocuments();
      final activeDocs = allDocs.where((d) => !d.isArchived).toList();
      final archivedDocs = allDocs.where((d) => d.isArchived).toList();

      expect(activeDocs.length, 1);
      expect(archivedDocs.length, 1);
    });

    test('archiving a document preserves the local file on disk', () async {
      final doc = await saveDoc('file-preserve');
      final filePath = doc.localFilePath!;

      expect(await File(filePath).exists(), isTrue);

      await storageService.archiveDocument(doc.id);

      // File should still exist after archiving
      expect(await File(filePath).exists(), isTrue);
    });

    test('restore changes archived/active counts correctly', () async {
      await saveDoc('multi-1');
      await saveDoc('multi-2', archived: true);
      await saveDoc('multi-3', archived: true);
      await saveDoc('multi-4');

      expect(await storageService.archivedDocumentCount(), 2);
      expect(await storageService.activeDocumentCount(), 2);

      // Find the first archived doc and restore it
      final all = await storageService.getDocuments();
      final archived = all.where((d) => d.isArchived).first;
      await storageService.restoreDocument(archived.id);

      expect(await storageService.archivedDocumentCount(), 1);
      expect(await storageService.activeDocumentCount(), 3);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. DocumentService — archive / restore delegation
  // ═══════════════════════════════════════════════════════════════════

  group('DocumentService — archive/restore delegation', () {
    late DocumentService documentService;

    setUp(() {
      documentService = DocumentService(
        Dio(BaseOptions(baseUrl: 'http://localhost:9999')),
      );
    });

    test('archiveDocument delegates to LocalStorageService and succeeds',
        () async {
      final doc = await saveDoc('svc-arch-1');

      final success = await documentService.archiveDocument(doc.id);
      expect(success, isTrue);

      final archived = await storageService.getDocumentById(doc.id);
      expect(archived!.isArchived, isTrue);
    });

    test('restoreDocument delegates and clears archived flag', () async {
      final doc = await saveDoc('svc-rest-1', archived: true);

      final success = await documentService.restoreDocument(doc.id);
      expect(success, isTrue);

      final restored = await storageService.getDocumentById(doc.id);
      expect(restored!.isArchived, isFalse);
    });

    test('archivedDocumentCount delegates correctly', () async {
      await saveDoc('svc-cnt-1', archived: true);
      await saveDoc('svc-cnt-2', archived: true);
      await saveDoc('svc-cnt-3');

      final count = await documentService.archivedDocumentCount();
      expect(count, 2);
    });

    test('activeDocumentCount delegates correctly', () async {
      await saveDoc('svc-act-1');
      await saveDoc('svc-act-2', archived: true);

      final count = await documentService.activeDocumentCount();
      expect(count, 1);
    });

    test('multiple archive/restore cycles are idempotent', () async {
      final doc = await saveDoc('svc-cycle-1');

      // First archive
      expect(await documentService.archiveDocument(doc.id), isTrue);
      expect(await storageService.archivedDocumentCount(), 1);

      // Archiving again is a no-op (sets archivedAt to a new timestamp)
      expect(await documentService.archiveDocument(doc.id), isTrue);
      expect(await storageService.archivedDocumentCount(), 1);

      // Restore
      expect(await documentService.restoreDocument(doc.id), isTrue);
      expect(await storageService.archivedDocumentCount(), 0);

      // Restoring again is a no-op
      expect(await documentService.restoreDocument(doc.id), isTrue);
      expect(await storageService.archivedDocumentCount(), 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. Widget-level: DocumentsList interactive archive/restore flow
  // ═══════════════════════════════════════════════════════════════════

  group('DocumentsList — interactive archive flow', () {
    /// Build a DocumentsList widget wrapped with providers.
    /// Uses [fakeDocService] so archive/restore calls don't hit a real backend.
    Widget buildTestApp(
      List<InsuranceDocument> documents, {
      FakeDocumentService? fakeDocService,
    }) {
      final service = fakeDocService ?? FakeDocumentService();
      return MaterialApp(
        home: ProviderScope(
          overrides: [
            documentsProvider.overrideWith((_) async => documents),
            documentServiceProvider.overrideWith((_) => service),
          ],
          child: const Scaffold(
            body: DocumentsList(),
          ),
        ),
      );
    }

    testWidgets('renders active documents and shows ExpansionTile',
        (tester) async {
      final docs = [makeDoc('ui-1')];
      await tester.pumpWidget(buildTestApp(docs));
      await tester.pumpAndSettle();

      expect(find.text('policy_ui-1.pdf'), findsOneWidget);

      // Archive button should NOT be visible before expanding the tile
      expect(find.text('Archive'), findsNothing);
    });

    testWidgets('tapping ExpansionTile reveals Archive button',
        (tester) async {
      final docs = [makeDoc('ui-expand-1')];
      await tester.pumpWidget(buildTestApp(docs));
      await tester.pumpAndSettle();

      // Tap the ExpansionTile title to expand
      await tester.tap(find.text('policy_ui-expand-1.pdf'));
      await tester.pumpAndSettle();

      // Now the Archive button should be visible inside the expanded tile
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('tapping Archive opens confirmation dialog',
        (tester) async {
      final docs = [makeDoc('ui-dialog-1')];
      await tester.pumpWidget(buildTestApp(docs));
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.text('policy_ui-dialog-1.pdf'));
      await tester.pumpAndSettle();

      // Tap the Archive button
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Archive policy?'), findsOneWidget);
      expect(
        find.textContaining('will be hidden from your active policy list'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling archive dialog leaves document unarchived',
        (tester) async {
      final fakeService = FakeDocumentService();
      final docs = [makeDoc('ui-cancel-1')];

      await tester.pumpWidget(buildTestApp(docs, fakeDocService: fakeService));
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.text('policy_ui-cancel-1.pdf'));
      await tester.pumpAndSettle();

      // Tap Archive
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      // Dialog should show Cancel and Archive buttons
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Archive policy?'), findsNothing);

      // archiveDocument should NOT have been called
      expect(fakeService.archivedIds, isEmpty);
    });

    testWidgets('confirming archive calls archiveDocument and shows snackbar',
        (tester) async {
      final fakeService = FakeDocumentService();
      final docs = [makeDoc('ui-confirm-1')];

      await tester.pumpWidget(buildTestApp(docs, fakeDocService: fakeService));
      await tester.pumpAndSettle();

      // Expand the tile
      await tester.tap(find.text('policy_ui-confirm-1.pdf'));
      await tester.pumpAndSettle();

      // Tap Archive
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      // Tap the Archive button in the confirmation dialog
      // There are two "Archive" texts: the tile button and the dialog button.
      // The dialog has a FilledButton.tonal child with Text('Archive').
      // Tap the second one (the dialog button, which is the last one).
      final archiveButtons = find.text('Archive');
      expect(archiveButtons, findsNWidgets(2));

      await tester.tap(archiveButtons.last);
      await tester.pumpAndSettle();

      // archiveDocument should have been called
      expect(fakeService.archivedIds, contains(docs.first.id));

      // Snackbar should show success
      expect(find.text('Policy archived'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. Pure-function tests: applySort / applyFilter / canAskQuestions
  // ═══════════════════════════════════════════════════════════════════

  group('applySort / applyFilter with archived documents', () {
    test('applySort handles archived and active docs together', () {
      final docs = [
        makeDoc('a', archived: false),
        makeDoc('b', archived: true),
        makeDoc('c', archived: false),
      ];
      final sorted = applySort(docs, DocsSortMode.nameAsc);
      expect(sorted.length, 3);
      // Archived docs should be sorted alongside active ones by name
      expect(sorted[0].id, 'a');
      expect(sorted[1].id, 'b');
      expect(sorted[2].id, 'c');
    });

    test('applyFilter filters by type regardless of archive status', () {
      final docs = [
        makeDoc('a', archived: false),
        makeDoc('b', archived: true),
      ];
      final filtered = applyFilter(docs, 'health insurance');
      expect(filtered.length, 2);
    });

    test('distinctTypes collects from all documents', () {
      final docs = [
        makeDoc('a', archived: false),
        makeDoc('b', archived: true),
      ];
      final types = distinctTypes(docs);
      expect(types, contains('Health Insurance'));
    });

    test('canAskQuestions works for archived documents', () {
      final archivedReady = makeDoc('ready', archived: true);
      expect(
        canAskQuestions(archivedReady, isReady: true),
        isTrue,
      );

      // No localFilePath and no remoteId -> not eligible
      final noPath = InsuranceDocument(
        id: 'nopath',
        filename: 'no_path.pdf',
        uploadedOn: DateTime(2026, 7, 20),
        localFilePath: null,
        isArchived: true,
      );
      expect(
        canAskQuestions(noPath, isReady: true),
        isFalse,
      );
    });
  });
}
