import 'package:coverwise/config/app_config.dart';
import 'package:coverwise/models/document_model.dart';
import 'package:coverwise/providers/document_providers.dart';
import 'package:coverwise/screens/documents_screen.dart';
import 'package:coverwise/services/ml_ocr_service.dart';
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

  Widget buildApp({
    List<InsuranceDocument> documents = const <InsuranceDocument>[],
    String? initialFileName,
  }) {
    return ProviderScope(
      overrides: [
        documentsProvider.overrideWith((ref) async => documents),
      ],
      child: MaterialApp(
        home: DocumentsScreen(
          initialFileName: initialFileName,
        ),
      ),
    );
  }

  /// Sets a fixed physical size so layout tests don't depend on the host.
  void setTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('_FileTypeHint — empty state rendering', () {
    testWidgets('shows all four hint chips when no documents exist',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(documents: []));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('JPEG'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);
      expect(find.text('Max 20 MB'), findsOneWidget);
    });

    testWidgets('shows the Add policy file CTA in empty state',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(documents: []));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Add policy file'), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
    });

    testWidgets('hint chips use theme-derived colors', (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(documents: []));
      await tester.pump(const Duration(seconds: 2));

      // Verify the chips are wrapped in a Container with surfaceContainerHighest
      final containers = tester.widgetList<Container>(
        find.ancestor(
          of: find.text('PDF'),
          matching: find.byType(Container),
        ),
      );

      // At least one container should have a BoxDecoration
      final chipContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration,
        orElse: () => Container(),
      );

      expect(chipContainer, isNotNull);

      // Verify the Row structure inside each chip (icon + text)
      final pdfRow = tester.widget<Row>(
        find.ancestor(
          of: find.text('PDF'),
          matching: find.byType(Row),
        ),
      );
      expect(pdfRow.mainAxisSize, MainAxisSize.min);
    });

    testWidgets('each chip has an icon and label', (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(documents: []));
      await tester.pump(const Duration(seconds: 2));

      // PDF chip: picture_as_pdf icon + "PDF" text
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);

      // JPEG and PNG chips: image icon
      expect(find.byIcon(Icons.image_outlined), findsWidgets);

      // Size chip: sd_card icon + "Max 20 MB" text
      expect(find.byIcon(Icons.sd_card_outlined), findsOneWidget);
    });

    testWidgets('hint chips are wrapped in a centered Wrap layout',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(documents: []));
      await tester.pump(const Duration(seconds: 2));

      final wrap = tester.widget<Wrap>(
        find.ancestor(
          of: find.text('PDF'),
          matching: find.byType(Wrap),
        ),
      );

      expect(wrap.alignment, WrapAlignment.center);
      expect(wrap.spacing, 8);
      expect(wrap.runSpacing, 4);
    });
  });

  group('_FileTypeHint — compact state (documents exist)', () {
    testWidgets('does NOT show hint chips when documents exist',
        (tester) async {
      setTestViewport(tester);

      final documents = [
        InsuranceDocument(
          id: 'doc-1',
          filename: 'health_policy.pdf',
          uploadedOn: DateTime(2026, 7, 10),
          status: 'completed',
          documentType: 'Health Insurance',
        ),
      ];

      await tester.pumpWidget(buildApp(documents: documents));
      await tester.pump(const Duration(seconds: 2));

      // Hint chips should NOT be visible in compact mode
      expect(find.text('PDF'), findsNothing);
      expect(find.text('JPEG'), findsNothing);
      expect(find.text('PNG'), findsNothing);
      expect(find.text('Max 20 MB'), findsNothing);
    });

    testWidgets('shows compact Add new policy button instead', (tester) async {
      setTestViewport(tester);

      final documents = [
        InsuranceDocument(
          id: 'doc-1',
          filename: 'health_policy.pdf',
          uploadedOn: DateTime(2026, 7, 10),
          status: 'completed',
        ),
      ];

      await tester.pumpWidget(buildApp(documents: documents));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Add new policy'), findsOneWidget);
      expect(find.text('Add policy file'), findsNothing);
    });
  });

  group('DocumentsScreen — initialFileName selection', () {
    testWidgets('shows selected file panel when initialFileName is provided',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'my_policy.pdf',
      ));
      // UsageStatsWidget intentionally contains an indeterminate network
      // loading indicator, so pump the deterministic post-frame selection
      // and transition instead of waiting for all animations to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Add a policy file'), findsOneWidget);
      expect(find.text('my_policy.pdf'), findsOneWidget);
      expect(find.text('Upload Selected File'), findsOneWidget);
    });

    testWidgets('shows close button to clear selection', (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'my_policy.pdf',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // After clearing, back to empty state
      expect(find.text('Add policy file'), findsOneWidget);
      expect(find.text('my_policy.pdf'), findsNothing);
    });

    testWidgets('does not show hint chips when a file is selected',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'my_policy.pdf',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // In expanded upload mode, the hint chips are not shown
      expect(find.text('PDF'), findsNothing);
      expect(find.text('JPEG'), findsNothing);
      expect(find.text('PNG'), findsNothing);
      expect(find.text('Max 20 MB'), findsNothing);
    });
  });

  group('AppConfig.maxUploadFileSizeBytes — constant', () {
    test('is exactly 20 MB in bytes', () {
      expect(AppConfig.maxUploadFileSizeBytes, 20 * 1024 * 1024);
    });

    test('maxUploadFileSizeMB matches bytes constant', () {
      expect(
        AppConfig.maxUploadFileSizeMB,
        AppConfig.maxUploadFileSizeBytes ~/ (1024 * 1024),
      );
    });
  });

  group('DocumentsScreen — expanded upload panel (file selected)', () {
    testWidgets('shows file name in the expanded panel',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'health_policy.pdf',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // File name should be displayed
      expect(find.text('health_policy.pdf'), findsOneWidget);
      // Upload button should be visible
      expect(find.text('Upload Selected File'), findsOneWidget);
      // Close button to clear selection
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('on-device OCR toggle is visible on non-web platforms',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'scanned_page.png',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The OCR toggle should be visible (kIsWeb is false in tests)
      expect(find.text('Read scanned pages on this device'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('on-device OCR toggle defaults to off', (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'policy.pdf',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, isFalse);
    });

    testWidgets('toggling OCR switch updates the switch state',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'policy.pdf',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Toggle the switch on
      final switchFinder = find.byType(SwitchListTile);
      await tester.ensureVisible(switchFinder);
      await tester.pump();
      await tester.tap(switchFinder);
      await tester.pump();

      final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(switchTile.value, isTrue);
    });

    testWidgets('shows the document language dropdown when OCR is enabled',
        (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(
        documents: [],
        initialFileName: 'policy.pdf',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Initially, no dropdown visible
      expect(find.byType(DropdownButtonFormField), findsNothing);

      // Toggle OCR on
      final switchFinder = find.byType(SwitchListTile);
      await tester.ensureVisible(switchFinder);
      await tester.pump();
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
      // Now the language dropdown should appear
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<OnDeviceOcrScript>,
        ),
        findsOneWidget,
      );
      expect(find.text('Document language'), findsOneWidget);
    });
  });

  group('DocumentsScreen — empty state structure', () {
    testWidgets('empty state has correct widget hierarchy', (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(documents: []));
      await tester.pump(const Duration(seconds: 2));

      // Verify the CoverWisePageHeader is present
      expect(find.text('Your policy library'), findsOneWidget);
      expect(
        find.text(
          'Keep policy files together, then open one to review or ask a question.',
        ),
        findsOneWidget,
      );

      // Verify the saved policies section label
      expect(find.text('SAVED POLICIES'), findsOneWidget);

      // Verify the "No saved policies yet" message
      expect(find.text('No saved policies yet'), findsOneWidget);
    });

    testWidgets('does not show upload error in initial state', (tester) async {
      setTestViewport(tester);

      await tester.pumpWidget(buildApp(documents: []));
      await tester.pump(const Duration(seconds: 2));

      // No error text should be visible
      expect(find.textContaining('too large'), findsNothing);
      expect(find.textContaining('not supported'), findsNothing);
    });
  });
}
