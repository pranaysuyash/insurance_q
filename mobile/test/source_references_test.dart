import 'dart:io';

import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/models/qa_models.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/entitlement_provider.dart';
import 'package:coverwise/models/entitlement.dart';
import 'package:coverwise/providers/questions_provider.dart';
import 'package:coverwise/utils/ref_state.dart';
import 'package:coverwise/screens/qa_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _SourceReferenceEntitlementNotifier extends EntitlementNotifier {
  @override
  Entitlement build() => Entitlement(
        planTier: PlanTier.plus,
        questionsUsedThisMonth: 0,
        packs: const [],
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
}

/// Builds QaScreen with [currentAnswerProvider] pre-seeded so the
/// answer card renders immediately without going through the streaming
/// submit path (which does not preserve sources/citations from mocks).
Widget _buildQaScreen({
  required QaAnswer answer,
  List<InsuranceDocument> documents = const [],
}) {
  return ProviderScope(
    overrides: [
      documentsProvider.overrideWith((ref) async => documents),
      selectedDocumentProvider.overrideWith(() => RefState<String?>(null)),
      isLoadingProvider.overrideWith(() => RefState<bool>(false)),
      currentAnswerProvider.overrideWith(() => RefState<QaAnswer?>(answer)),
      entitlementProvider
          .overrideWith(_SourceReferenceEntitlementNotifier.new),
      // Override categories/questions with empty lists so the answer card
      // is the only item in the Suggested tab (index 0, immediately visible)
      questionCategoriesProvider.overrideWith((ref) => const <QuestionCategory>[]),
      standardQuestionsProvider.overrideWith((ref) => const <StandardQuestion>[]),
    ],
    child: const MaterialApp(
      home: QaScreen(),
    ),
  );
}

/// Minimal InsuranceDocument for testing document-name resolution in source cards.
InsuranceDocument _doc({
  required String id,
  String? remoteId,
  String? localFilePath,
  String filename = 'policy.pdf',
}) {
  return InsuranceDocument(
    id: id,
    remoteId: remoteId,
    filename: filename,
    uploadedOn: DateTime(2026, 1, 15),
    localFilePath: localFilePath,
    processingState: 'completed',
    status: 'completed',
  );
}

QaAnswer _answer({
  String text = 'Answer text.',
  String question = 'Test question',
  String documentId = 'doc-1',
  List<QaSource> sources = const [],
  List<Map<String, dynamic>> citations = const [],
  double? confidence,
}) =>
    QaAnswer(
      text: text,
      sources: sources,
      citations: citations,
      timestamp: DateTime(2026, 1, 15, 10, 30),
      documentId: documentId,
      question: question,
      confidence: confidence,
    );

QaSource _source({
  String text = 'Source text',
  double score = 1.0,
  int? pageNumber,
  String documentId = 'doc-1',
}) =>
    QaSource(
      documentId: documentId,
      text: text,
      score: score,
      pageNumber: pageNumber,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '/tmp/coverwise-source-refs-tests';
    });
    final dir = Directory('/tmp/coverwise-source-refs-tests');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    await dir.create(recursive: true);
    await Hive.initFlutter(dir.path);
    if (!Hive.isBoxOpen(LocalStorageService.documentsBoxName)) {
      await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    }
    if (!Hive.isBoxOpen(AppStateStore.boxName)) {
      await Hive.openBox(AppStateStore.boxName);
    }
    if (!Hive.isBoxOpen('resolved_gaps')) {
      await Hive.openBox('resolved_gaps');
    }
    if (!Hive.isBoxOpen('analytics_events')) {
      await Hive.openBox('analytics_events');
    }
    if (!Hive.isBoxOpen('consent_ledger')) {
      await Hive.openBox('consent_ledger');
    }
    if (!Hive.isBoxOpen('qa_history')) {
      await Hive.openBox('qa_history');
    }
    if (!Hive.isBoxOpen('entitlements')) {
      await Hive.openBox('entitlements');
    }
  });

  group('Source references — citations with page numbers', () {
    testWidgets('renders citation with page number and View source button',
        (tester) async {
      final answer = _answer(
        text: 'Your policy number is ABC123.',
        question: 'What is my policy number?',
        citations: [
          {
            'quote': 'Policy Number: ABC123',
            'page_number': 3,
            'status': 'verified',
          },
        ],
      );

      final doc = _doc(
        id: 'doc-1',
        filename: 'health_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Should show the evidence section
      expect(find.text('Evidence'), findsOneWidget);

      // Should show citation with page reference
      expect(find.textContaining('Source 1 • page 3'), findsOneWidget);

      // Should show "View source" for citation with page number
      expect(find.text('View source'), findsOneWidget);
    });

    testWidgets(
        'citation without page number does not show View source',
        (tester) async {
      final answer = _answer(
        text: 'Emergency care is covered.',
        question: 'What is covered?',
        citations: [
          {
            'quote': 'Emergency care coverage details',
            'status': 'verified',
          },
        ],
      );

      final doc = _doc(
        id: 'doc-1',
        filename: 'auto_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Should show citation without page reference
      expect(find.textContaining('Source 1'), findsOneWidget);

      // Should NOT show "View source" (no page number)
      expect(find.text('View source'), findsNothing);
    });
  });

  group('Source references — source cards with relevance scores', () {
    testWidgets('renders source card with high relevance score (≥80%)',
        (tester) async {
      final answer = _answer(
        text: 'The deductible is \$5,000.',
        question: 'What is my deductible?',
        sources: [
          _source(
            text: 'Deductible amount in policy schedule',
            score: 0.95,
            documentId: 'doc-1',
          ),
        ],
      );

      final doc = _doc(
        id: 'doc-1',
        filename: 'health_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Should show sources section
      expect(find.textContaining('Sources (1)'), findsOneWidget);

      // Should show the source text
      expect(find.text('Deductible amount in policy schedule'), findsOneWidget);

      // Should show 95% relevance badge
      expect(find.text('95%'), findsOneWidget);

      // Should show document name
      expect(find.textContaining('health_policy.pdf'), findsOneWidget);
    });

    testWidgets('renders source card with low relevance score (<50%)',
        (tester) async {
      final answer = _answer(
        text: 'Waiting periods apply.',
        question: 'What are waiting periods?',
        sources: [
          _source(
            text: 'Weak match from another section',
            score: 0.25,
            documentId: 'doc-1',
          ),
        ],
      );

      final doc = _doc(
        id: 'doc-1',
        filename: 'life_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Should show 25% relevance badge
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('renders source card with page number and navigable icon',
        (tester) async {
      final answer = _answer(
        text: 'Premium is \$12,000 annually.',
        question: 'What is my premium?',
        sources: [
          _source(
            text: 'Premium schedule on page 2',
            score: 0.92,
            pageNumber: 2,
            documentId: 'doc-1',
          ),
        ],
      );

      final doc = _doc(
        id: 'doc-1',
        filename: 'motor_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Should show source with page number
      expect(find.textContaining('Page 2'), findsOneWidget);

      // Should show 92% badge
      expect(find.text('92%'), findsOneWidget);

      // Should show open_in_new icon (navigable)
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    });

    testWidgets('renders multiple sources with different scores',
        (tester) async {
      final answer = _answer(
        text: 'Coverage includes hospitalization.',
        question: 'What is covered?',
        sources: [
          _source(
            text: 'Strong match from main policy',
            score: 0.98,
            documentId: 'doc-1',
          ),
          _source(
            text: 'Medium match from schedule',
            score: 0.65,
            documentId: 'doc-1',
          ),
          _source(
            text: 'Weak match from appendix',
            score: 0.30,
            documentId: 'doc-1',
          ),
        ],
      );

      final doc = _doc(
        id: 'doc-1',
        filename: 'health_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Should show all three sources
      expect(find.textContaining('Sources (3)'), findsOneWidget);

      // Should show all three relevance badges
      expect(find.text('98%'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);

      // Should show all three source texts
      expect(find.text('Strong match from main policy'), findsOneWidget);
      expect(find.text('Medium match from schedule'), findsOneWidget);
      expect(find.text('Weak match from appendix'), findsOneWidget);
    });
  });

  group('Source references — tooltip', () {
    testWidgets('relevance badge has tooltip explaining its meaning',
        (tester) async {
      final answer = _answer(
        text: 'Answer text',
        question: 'Test question',
        sources: [
          _source(text: 'Source text', score: 0.85, documentId: 'doc-1'),
        ],
      );

      final doc = _doc(id: 'doc-1', localFilePath: '/tmp/test.pdf');

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Find the Tooltip wrapping the 85% badge
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.text('85%'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message,
          'How closely this source matches your question');
    });
  });

  group('ConfidenceBadge — rendering', () {
    testWidgets('hidden when AppConfig.confidenceCalibrated is false',
        (tester) async {
      final answer = _answer(
        text: 'Answer with confidence',
        question: 'Test question',
        confidence: 0.9,
      );

      final doc = _doc(id: 'doc-1', localFilePath: '/tmp/test.pdf');

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], answer: answer),
      );
      await tester.pumpAndSettle();

      // Confidence badge should be hidden (confidenceCalibrated = false by default)
      expect(find.text('High confidence'), findsNothing);
      expect(find.text('Medium confidence'), findsNothing);
      expect(find.text('Low confidence'), findsNothing);
    });
  });
}
