import 'dart:async';

import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/screens/documents_screen.dart';
import 'package:coverwise/widgets/usage_stats_widget.dart';
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
      child: MaterialApp(
        localizationsDelegates:
            AppLocalizationsGen.localizationsDelegates,
        supportedLocales: AppLocalizationsGen.supportedLocales,
        home: const DocumentsScreen(),
      ),
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
      expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
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

      expect(find.text('SAVED POLICIES'), findsOneWidget);
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

    testWidgets('uses compact add-new CTA when policies already exist',
        (tester) async {
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
      ];

      await tester.pumpWidget(buildDocumentsScreen(documents: documents));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Add new policy'), findsOneWidget);
      expect(find.text('Add policy file'), findsNothing);
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

    testWidgets('does not overflow when the document viewport is short',
        (tester) async {
      tester.view.physicalSize = const Size(402, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDocumentsScreen(documents: []));
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(find.text('No saved policies yet'), findsOneWidget);
    });

    testWidgets('shows the selected-file upload panel after automatic picking',
        (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) async => const []),
            usageStatsProvider.overrideWith((ref) async => const {
                  'session_uploads': 0,
                  'session_limit': 5,
                  'ip_uploads': 0,
                  'ip_limit': 10,
                }),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizationsGen.localizationsDelegates,
            supportedLocales: AppLocalizationsGen.supportedLocales,
            home: const DocumentsScreen(
                initialFileName: 'policy_demo.pdf'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a policy file'), findsOneWidget);
      expect(find.text('policy_demo.pdf'), findsOneWidget);
      expect(find.text('Upload Selected File'), findsOneWidget);
    });

    testWidgets('announces the saved-policy loading state', (tester) async {
      final loading = Completer<List<InsuranceDocument>>();

      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => loading.future),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizationsGen.localizationsDelegates,
            supportedLocales: AppLocalizationsGen.supportedLocales,
            home: const DocumentsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Loading saved policies'), findsOneWidget);

      loading.complete(const []);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No saved policies yet'), findsOneWidget);
    });
  });
}
