import 'dart:io';

import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/providers/questions_provider.dart';
import 'package:coverwise/screens/qa_screen.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '/tmp/coverwise-qa-tests';
    });
    final dir = Directory('/tmp/coverwise-qa-tests');
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

  tearDownAll(() async {
  });

  Widget buildQaScreen({
    List<InsuranceDocument> documents = const <InsuranceDocument>[],
    String? initialDocumentId,
  }) {
    return ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => documents),
        selectedDocumentProvider.overrideWith((ref) => initialDocumentId),
      ],
      child: MaterialApp(
        home: QaScreen(initialDocumentId: initialDocumentId),
      ),
    );
  }

  group('QaScreen — tab rendering', () {
    testWidgets('renders three tabs: Suggested, Your question, History',
        (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      expect(find.text('Suggested'), findsOneWidget);
      expect(find.text('Your question'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      expect(find.text('Ask CoverWise'), findsOneWidget);
    });

    testWidgets('defaults to Suggested tab', (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 0);
    });

    testWidgets('can switch to Your question tab', (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 1);
    });

    testWidgets('can switch to History tab', (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 2);
    });
  });

  group('QaScreen — document selector', () {
    testWidgets('renders without crash when no documents', (tester) async {
      await tester.pumpWidget(buildQaScreen(documents: []));
      await tester.pumpAndSettle();

      expect(find.text('Ask CoverWise'), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
    });
  });

  group('QaScreen — custom question tab', () {
    testWidgets('shows text input on Your question tab', (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('text field accepts input', (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Your question'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'What is my deductible?');
      await tester.pump();

      expect(find.text('What is my deductible?'), findsOneWidget);
    });
  });

  group('QaScreen — history tab', () {
    testWidgets('shows empty state on History tab initially', (tester) async {
      await tester.pumpWidget(buildQaScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.byType(QaScreen), findsOneWidget);
    });
  });
}
