import 'dart:io';

import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/policy_providers.dart';
import 'package:coverwise/screens/dashboard_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/policy_extraction_service.dart';
import 'package:coverwise/services/query_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _FakeExtractionService extends PolicyExtractionService {
  final List<PolicySummary> _summaries;
  _FakeExtractionService(this._summaries) : super(QueryService(Dio()));
  @override
  List<PolicySummary> getAllSummaries() => _summaries;
}

class _FakeSummariesNotifier extends PolicySummariesNotifier {
  _FakeSummariesNotifier(List<PolicySummary> summaries)
      : super(_FakeExtractionService(summaries));
}

List<InsuranceDocument> _testDocuments() => [
      InsuranceDocument(
        id: 'doc-1',
        filename: 'health_policy.pdf',
        uploadedOn: DateTime(2026, 7, 10),
        status: 'completed',
        documentType: 'Health Insurance',
      ),
      InsuranceDocument(
        id: 'doc-2',
        filename: 'auto_policy.pdf',
        uploadedOn: DateTime(2026, 7, 5),
        status: 'completed',
        documentType: 'Auto Insurance',
      ),
    ];

List<PolicySummary> _testSummaries() => [
      PolicySummary(
        documentId: 'doc-1',
        documentType: 'Health Insurance',
        insurer: 'ICICI Lombard',
        policyNumber: 'POL-12345',
        coverageAmount: 500000,
        premiumAmount: 12000,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
        extractedAt: DateTime(2026, 7, 10),
      ),
      PolicySummary(
        documentId: 'doc-2',
        documentType: 'Auto Insurance',
        insurer: 'HDFC Ergo',
        policyNumber: 'POL-67890',
        coverageAmount: 300000,
        premiumAmount: 8000,
        extractedAt: DateTime(2026, 7, 5),
      ),
    ];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '/tmp/coverwise-dashboard-tests';
    });
    await Directory('/tmp/coverwise-dashboard-tests').create(recursive: true);
    await Hive.initFlutter('/tmp/coverwise-dashboard-tests');
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
  });

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
  });

  Widget buildDashboard({
    List<InsuranceDocument>? documents,
    List<PolicySummary>? summaries,
    List<String> recentQuestions = const [],
  }) {
    return ProviderScope(
      overrides: [
        documentsProvider.overrideWith(
            (ref) async => documents ?? _testDocuments()),
        policySummariesProvider.overrideWith(
          (ref) => _FakeSummariesNotifier(summaries ?? _testSummaries()),
        ),
        recentQuestionsProvider.overrideWithValue(recentQuestions),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    );
  }

  group('DashboardScreen — populated state', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders page header', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      expect(find.text('Your cover, at a glance'), findsOneWidget);
    });

    testWidgets('renders welcome card', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      // Text is capitalized by CoverWiseSectionLabel
      expect(find.text('YOUR POLICY HUB'), findsOneWidget);
    });

    testWidgets('renders policy cards', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Your Policies'), 200);
      expect(find.text('Your Policies'), findsOneWidget);
      expect(find.text('Health Insurance'), findsOneWidget);
      expect(find.text('Auto Insurance'), findsOneWidget);
    });

    testWidgets('renders policy numbers', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Policy: POL-12345'), 200);
      expect(find.text('Policy: POL-12345'), findsOneWidget);
      expect(find.text('Policy: POL-67890'), findsOneWidget);
    });

    testWidgets('renders active status badge', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      // Scroll to policy cards section to build them, then check ACTIVE badges
      await tester.scrollUntilVisible(find.text('Your Policies'), 200);
      expect(find.text('ACTIVE'), findsWidgets);
    });

    testWidgets('renders expiring soon badge', (tester) async {
      final summaries = [
        PolicySummary(
          documentId: 'doc-1',
          documentType: 'Health Insurance',
          insurer: 'Test Insurer',
          coverageAmount: 100000,
          endDate: DateTime.now().add(const Duration(days: 15)),
          extractedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildDashboard(summaries: summaries));
      await tester.pumpAndSettle();

      // Badge is in _PolicyCard which may be below fold in SliverList
      await tester.scrollUntilVisible(find.textContaining('LEFT'), 200);
      expect(find.textContaining('LEFT'), findsOneWidget);
    });

    testWidgets('renders coverage amount', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('₹5.0 L'), 200);
      expect(find.text('₹5.0 L'), findsOneWidget);
    });

    testWidgets('renders premium amount', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('₹12.0K'), 200);
      expect(find.text('₹12.0K'), findsOneWidget);
    });

    testWidgets('renders quick actions', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      // Text is capitalized by CoverWiseSectionLabel
      expect(find.text('QUICK ACTIONS'), findsOneWidget);
      expect(find.text('Upload Document'), findsOneWidget);
      expect(find.text('Ask a Question'), findsOneWidget);
    });

    testWidgets('renders emergency shortcut', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      expect(find.text('Emergency Card'), findsOneWidget);
      expect(find.byIcon(Icons.emergency_outlined), findsOneWidget);
    });

    testWidgets('renders search shortcut', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Search Across All Policies'), 200);
      expect(find.text('Search Across All Policies'), findsOneWidget);
    });

    testWidgets('renders documents by type', (tester) async {
      await tester.pumpWidget(buildDashboard());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Documents by Type'), 200);
      expect(find.text('Documents by Type'), findsOneWidget);
    });
  });

  group('DashboardScreen — empty state', () {
    testWidgets('shows first upload CTA when no documents', (tester) async {
      await tester.pumpWidget(buildDashboard(
        documents: [],
        summaries: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Turn your first policy into clear answers'),
          findsOneWidget);
      expect(find.text('Choose policy file'), findsOneWidget);
    });

    testWidgets('hides populated sections when empty', (tester) async {
      await tester.pumpWidget(buildDashboard(
        documents: [],
        summaries: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('YOUR POLICY HUB'), findsNothing);
      expect(find.text('QUICK ACTIONS'), findsNothing);
    });
  });

  group('DashboardScreen — error state', () {
    testWidgets('shows error view when documents fail to load',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) async {
            throw Exception('Network error');
          }),
          policySummariesProvider.overrideWith(
            (ref) => _FakeSummariesNotifier([]),
          ),
          recentQuestionsProvider.overrideWithValue(const []),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not load'), findsOneWidget);
    });
  });
}
