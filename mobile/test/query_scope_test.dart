import 'dart:async';
import 'dart:io';

import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/models/query_scope.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/questions_provider.dart';
import 'package:coverwise/providers/connectivity_provider.dart';
import 'package:coverwise/utils/ref_state.dart';
import 'package:coverwise/screens/qa_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/query_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:coverwise/providers/service_providers.dart';
import 'package:coverwise/l10n/app_localizations_gen.dart';

/// Records the documentId passed to the streaming query so tests can assert
/// the exact scope the screen sends to the backend.
class _RecordingQueryService extends QueryService {
  _RecordingQueryService() : super(Dio());

  String? lastDocumentId;
  final StreamController<String> _controller = StreamController<String>();

  @override
  Stream<String> queryDocumentStream(
    String query, {
    String? documentId,
  }) {
    lastDocumentId = documentId;
    _controller.add('Answer from policy corpus.');
    _controller.close();
    return _controller.stream;
  }
}

InsuranceDocument _doc(String id, String filename) => InsuranceDocument(
      id: id,
      remoteId: 'backend-$id',
      filename: filename,
      uploadedOn: DateTime.now(),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '/tmp/coverwise-query-scope-tests';
    });
    final dir = Directory('/tmp/coverwise-query-scope-tests');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    await dir.create(recursive: true);
    await Hive.initFlutter(dir.path);
    for (final box in [
      LocalStorageService.documentsBoxName,
      AppStateStore.boxName,
      'resolved_gaps',
      'analytics_events',
      'consent_ledger',
      'qa_history',
      'entitlements',
    ]) {
      if (!Hive.isBoxOpen(box)) {
        await Hive.openBox(box);
      }
    }
  });

  tearDownAll(() async {});

  Widget buildQaScreen({
    List<InsuranceDocument> documents = const <InsuranceDocument>[],
    String? initialDocumentId,
    required QueryService queryService,
  }) {
    return ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => documents),
        selectedDocumentProvider
            .overrideWith(() => RefState<String?>(initialDocumentId)),
        isOnlineProvider.overrideWith((ref) => true),
        queryServiceProvider.overrideWithValue(queryService),
      ],
      child: MaterialApp(
        localizationsDelegates:
            AppLocalizationsGen.localizationsDelegates,
        supportedLocales: AppLocalizationsGen.supportedLocales,
        home: QaScreen(initialDocumentId: initialDocumentId),
      ),
    );
  }

  Future<void> askQuestionOnCustomTab(WidgetTester tester) async {
    await tester.tap(find.text('Your question'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'What is my deductible?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    // Allow the async stream to run to completion.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('QueryScope model', () {
    test('all scope has null documentId and isAllDocuments true', () {
      expect(QueryScope.all.isAllDocuments, isTrue);
      expect(QueryScope.all.documentId, isNull);
      expect(QueryScope.all.displayLabel, 'All Documents');
    });

    test('single scope carries its documentId', () {
      final scope = QueryScope.single('doc-1');
      expect(scope.isAllDocuments, isFalse);
      expect(scope.documentId, 'doc-1');
      expect(scope.displayLabel, 'Single Policy');
    });

    test('equality and hashCode are consistent', () {
      expect(QueryScope.all, equals(QueryScope.all));
      expect(QueryScope.single('a'), equals(QueryScope.single('a')));
      expect(QueryScope.single('a'), isNot(equals(QueryScope.single('b'))));
      expect(QueryScope.all, isNot(equals(QueryScope.single('a'))));
      expect(QueryScope.single('a').hashCode,
          QueryScope.single('a').hashCode);
    });
  });

  group('QaScreen — All Documents scope (CW-P0-001 / P0-1)', () {
    testWidgets(
        'All Documents (no selection) omits document_id from the query',
        (tester) async {
      final service = _RecordingQueryService();
      await tester.pumpWidget(buildQaScreen(
        documents: [
          _doc('doc-1', 'policy-a.pdf'),
          _doc('doc-2', 'policy-b.pdf'),
        ],
        queryService: service,
      ));
      await tester.pumpAndSettle();

      await askQuestionOnCustomTab(tester);

      // The screen must NOT collapse "All Documents" into the first policy.
      expect(service.lastDocumentId, isNull,
          reason: 'All-Documents queries must omit document_id so the '
              'backend searches every policy');
    });

    testWidgets('initialDocumentId produces a single-document scoped query',
        (tester) async {
      final service = _RecordingQueryService();
      await tester.pumpWidget(buildQaScreen(
        documents: [
          _doc('doc-1', 'policy-a.pdf'),
          _doc('doc-2', 'policy-b.pdf'),
        ],
        initialDocumentId: 'doc-2',
        queryService: service,
      ));
      await tester.pumpAndSettle();

      await askQuestionOnCustomTab(tester);

      expect(service.lastDocumentId, 'doc-2',
          reason: 'opening Q&A from a document context must scope to that '
              'single policy');
    });

    testWidgets('explicit document selection scopes the query to that policy',
        (tester) async {
      final service = _RecordingQueryService();
      await tester.pumpWidget(buildQaScreen(
        documents: [
          _doc('doc-1', 'policy-a.pdf'),
          _doc('doc-2', 'policy-b.pdf'),
        ],
        initialDocumentId: 'doc-1',
        queryService: service,
      ));
      await tester.pumpAndSettle();

      // Switch the selection to doc-2 via the document picker dialog.
      await tester.tap(find.text('policy-a.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('policy-b.pdf').last);
      await tester.pumpAndSettle();

      await askQuestionOnCustomTab(tester);

      expect(service.lastDocumentId, 'doc-2');
    });
  });
}
