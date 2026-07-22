import 'dart:io';

import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/entitlement_provider.dart';
import 'package:coverwise/models/entitlement.dart';
import 'package:coverwise/providers/questions_provider.dart';
import 'package:coverwise/utils/ref_state.dart';
import 'package:coverwise/screens/qa_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/query_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coverwise/models/qa_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coverwise/providers/service_providers.dart';

/// A mock QueryService that returns a pre-defined response with sources
/// and citations for testing source reference rendering.
class _MockQueryService extends QueryService {
  final Map<String, dynamic> _response;
  int callCount = 0;

  _MockQueryService(this._response) : super(Dio());

  @override
  Future<Map<String, dynamic>> queryDocument(String query,
      {String? documentId}) async {
    callCount++;
    return _response;
  }
}

class _SourceReferenceEntitlementNotifier extends EntitlementNotifier {
  @override
  Entitlement build() => Entitlement(
        planTier: PlanTier.plus,
        questionsUsedThisMonth: 0,
        packs: const [],
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
}

/// Builds QaScreen with mocked providers for source reference tests.
Widget _buildQaScreen({
  List<InsuranceDocument> documents = const [],
  required Map<String, dynamic> queryResponse,
}) {
  return ProviderScope(
    overrides: [
      documentsProvider.overrideWith((ref) async => documents),
      selectedDocumentProvider.overrideWith(() => RefState<String?>(null)),
      isLoadingProvider.overrideWith(() => RefState<bool>(false)),
      currentAnswerProvider.overrideWith(() => RefState<QaAnswer?>(null)),
      entitlementProvider
          .overrideWith(_SourceReferenceEntitlementNotifier.new),
      queryServiceProvider
          .overrideWithValue(_MockQueryService(queryResponse)),
    ],
    child: MaterialApp(
      home: QaScreen(),
    ),
  );
}

/// Minimal InsuranceDocument for testing.
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
      final response = {
        'answer': 'Your policy number is ABC123.',
        'sources': <String>[],
        'document_id': 'doc-1',
        'citations': [
          {
            'quote': 'Policy Number: ABC123',
            'page_number': 3,
            'status': 'verified',
          },
        ],
        'follow_up_questions': <String>[],
      };

      final doc = _doc(
        id: 'doc-1',
        filename: 'health_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      // Switch to "Your question" tab
      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      // Enter a question and submit
      await tester.enterText(find.byType(TextField), 'What is my policy number?');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

      // Should show the answer
      expect(find.textContaining('ABC123'), findsWidgets);

      // Should show evidence section
      expect(find.text('Evidence'), findsOneWidget);

      // Should show citation with page reference
      expect(find.textContaining('Source 1 • page 3'), findsOneWidget);

      // Should show "View source" for citation with page number
      expect(find.text('View source'), findsOneWidget);

      // Should show open_in_new icon for navigable citation
      expect(find.byIcon(Icons.open_in_new), findsWidgets);
    });

    testWidgets(
        'citation without page number does not show View source',
        (tester) async {
      final response = {
        'answer': 'Emergency care is covered.',
        'sources': <String>[],
        'document_id': 'doc-1',
        'citations': [
          {
            'quote': 'Emergency care coverage details',
            // No page_number
            'status': 'verified',
          },
        ],
        'follow_up_questions': <String>[],
      };

      final doc = _doc(
        id: 'doc-1',
        filename: 'auto_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What is covered?');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

      // Should show citation without page reference
      expect(find.textContaining('Source 1'), findsOneWidget);

      // Should NOT show "View source" (no page number)
      expect(find.text('View source'), findsNothing);

      // Should NOT show open_in_new icon
      expect(find.byIcon(Icons.open_in_new), findsNothing);
    });
  });

  group('Source references — source cards with relevance scores', () {
    testWidgets('renders source card with high relevance score (≥80%)',
        (tester) async {
      final response = {
        'answer': 'The deductible is ₹5,000.',
        'sources': [
          {'text': 'Deductible amount in policy schedule', 'score': 0.95},
        ],
        'document_id': 'doc-1',
        'citations': <Map<String, dynamic>>[],
        'follow_up_questions': <String>[],
      };
      final doc = _doc(
        id: 'doc-1',
        filename: 'health_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What is my deductible?');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

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
      final response = {
        'answer': 'Waiting periods apply.',
        'sources': [
          {'text': 'Weak match from another section', 'score': 0.25},
        ],
        'document_id': 'doc-1',
        'citations': <Map<String, dynamic>>[],
        'follow_up_questions': <String>[],
      };

      final doc = _doc(
        id: 'doc-1',
        filename: 'life_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What are waiting periods?');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

      // Should show 25% relevance badge
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('renders source card with page number and navigable icon',
        (tester) async {
      final response = {
        'answer': 'Premium is ₹12,000 annually.',
        'sources': [
          {
            'text': 'Premium schedule on page 2',
            'page_number': 2,
            'score': 0.92,
          },
        ],
        'document_id': 'doc-1',
        'citations': <Map<String, dynamic>>[],
        'follow_up_questions': <String>[],
      };

      final doc = _doc(
        id: 'doc-1',
        filename: 'motor_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What is my premium?');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

      // Should show source with page number
      expect(find.textContaining('Page 2'), findsOneWidget);

      // Should show 92% badge
      expect(find.text('92%'), findsOneWidget);

      // Should show open_in_new icon (navigable)
      expect(find.byIcon(Icons.open_in_new), findsWidgets);
    });

    testWidgets('renders multiple sources with different scores',
        (tester) async {
      final response = {
        'answer': 'Coverage includes hospitalization.',
        'sources': [
          {'text': 'Strong match from main policy', 'score': 0.98},
          {'text': 'Medium match from schedule', 'score': 0.65},
          {'text': 'Weak match from appendix', 'score': 0.30},
        ],
        'document_id': 'doc-1',
        'citations': <Map<String, dynamic>>[],
        'follow_up_questions': <String>[],
      };

      final doc = _doc(
        id: 'doc-1',
        filename: 'health_policy.pdf',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What is covered?');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

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
      final response = {
        'answer': 'Answer text',
        'sources': [
          {'text': 'Source text', 'score': 0.85},
        ],
        'document_id': 'doc-1',
        'citations': <Map<String, dynamic>>[],
        'follow_up_questions': <String>[],
      };

      final doc = _doc(
        id: 'doc-1',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test question');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

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
      final response = {
        'answer': 'Answer with confidence',
        'sources': <String>[],
        'document_id': 'doc-1',
        'citations': <Map<String, dynamic>>[],
        'follow_up_questions': <String>[],
        'confidence': 0.9,
      };

      final doc = _doc(
        id: 'doc-1',
        localFilePath: '/tmp/test.pdf',
      );

      await tester.pumpWidget(
        _buildQaScreen(documents: [doc], queryResponse: response),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test question');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));

      // Confidence badge should be hidden (confidenceCalibrated = false by default)
      expect(find.text('High confidence'), findsNothing);
      expect(find.text('Medium confidence'), findsNothing);
      expect(find.text('Low confidence'), findsNothing);
    });
  });
}
