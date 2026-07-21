import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/screens/documents_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await HiveTestHelper.setUp();
  });

  tearDownAll(() async {
    await HiveTestHelper.tearDown();
  });

  Widget buildDocumentsScreen({
    List<InsuranceDocument> documents = const <InsuranceDocument>[],
  }) {
    return ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => documents),
      ],
      child: const MaterialApp(home: DocumentsScreen()),
    );
  }

  group('DocumentsScreen — rendering', () {
    testWidgets('renders app bar with title', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDocumentsScreen());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Documents'), findsOneWidget);
    });

    testWidgets('renders page header', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDocumentsScreen());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Your policy library'), findsOneWidget);
    });

    testWidgets('shows add policy file button', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDocumentsScreen());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Add policy file'), findsOneWidget);
      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    });

    testWidgets('renders saved policies section', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDocumentsScreen());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Saved policies'), findsOneWidget);
    });
  });

  group('DocumentsScreen — with documents', () {
    testWidgets('shows document filename', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final documents = [
        InsuranceDocument(
          id: 'doc-1',
          filename: 'health_policy.pdf',
          uploadedOn: DateTime(2026, 7, 10),
          status: 'completed',
          documentType: 'Health Insurance',
        ),
      ];

      await tester.pumpWidget(buildDocumentsScreen(documents: documents));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('health_policy.pdf'), findsOneWidget);
    });

    testWidgets('shows multiple documents', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final documents = [
        InsuranceDocument(
          id: 'doc-1',
          filename: 'health_policy.pdf',
          uploadedOn: DateTime(2026, 7, 10),
          status: 'completed',
        ),
        InsuranceDocument(
          id: 'doc-2',
          filename: 'auto_policy.pdf',
          uploadedOn: DateTime(2026, 7, 5),
          status: 'completed',
        ),
      ];

      await tester.pumpWidget(buildDocumentsScreen(documents: documents));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('health_policy.pdf'), findsOneWidget);
      expect(find.text('auto_policy.pdf'), findsOneWidget);
    });
  });

  group('DocumentsScreen — empty state', () {
    testWidgets('shows empty state gracefully', (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDocumentsScreen(documents: []));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Add policy file'), findsOneWidget);
    });
  });
}
