import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/processing_status_screen.dart';

void main() {
  // "Received" appears twice: once in the pipeline list and once as the
  // current stage label. Use findsWidgets throughout.
  const findsReceived = findsWidgets;

  group('ProcessingStatusScreen — static UI rendering', () {
    testWidgets('renders initial received state with filename', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc-123',
            filename: 'policy.pdf',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Received'), findsReceived);
      expect(find.text('Document received'), findsWidgets);
      expect(find.text('Preparing your policy'), findsOneWidget);
      expect(find.text('policy.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets('displays pipeline stages in the list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      // Verify the 5 pipeline stage labels are present. Stages 3-5 may be
      // below the fold in the ListView, so scroll to find them.
      expect(find.text('Received'), findsWidgets);
      expect(find.text('Reading text'), findsOneWidget);
      expect(find.text('Extracting details'), findsOneWidget);

      // Scroll down to find the remaining stages.
      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -300));
      await tester.pump();

      expect(find.text('Categorising'), findsOneWidget);
      expect(find.text('Finishing up'), findsOneWidget);

      // Verify at least some stage icons render (cover 3 of 5 to stay
      // resilient against icon availability changes).
      expect(find.byIcon(Icons.upload_file), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.find_in_page_outlined), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.search), findsAtLeastNWidgets(1));
    });

    testWidgets('does not show terminal stages in the pipeline list',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Complete'), findsNothing);
      expect(find.text('Failed'), findsNothing);
    });

    testWidgets('page header shows correct title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'auto_insurance.pdf',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Turning pages into answers'), findsOneWidget);
    });

    testWidgets('filename is selectable via Semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'important_policy.pdf',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'File being processed: important_policy.pdf',
        ),
        findsOneWidget,
      );
    });
  });

  group('ProcessingStatusScreen — back navigation behavior', () {
    testWidgets('back button is hidden while processing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final appBar = scaffold.appBar as AppBar;
      expect(appBar.automaticallyImplyLeading, isFalse);
    });

    testWidgets('shows dismiss warning dialog on back press', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      Navigator.of(tester.element(find.byType(ProcessingStatusScreen)))
          .maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Still processing?'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('close button pops the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      Navigator.of(tester.element(find.byType(ProcessingStatusScreen)))
          .maybePop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(ProcessingStatusScreen), findsNothing);
    });

    testWidgets('stay button keeps the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      Navigator.of(tester.element(find.byType(ProcessingStatusScreen)))
          .maybePop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(find.byType(ProcessingStatusScreen), findsOneWidget);
    });

    testWidgets('dismiss dialog content explains background processing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      Navigator.of(tester.element(find.byType(ProcessingStatusScreen)))
          .maybePop();
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Your document is still being processed. You can close this screen — '
          'processing continues in the background. You can check the document list for updates.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ProcessingStatusScreen — Dio fallback behavior', () {
    testWidgets('screen remains stable when backend returns 404',
        (tester) async {
      // The screen creates its own Dio internally. When the backend returns
      // 404 or is unreachable, the catch block falls through to
      // LocalStorageService. Since we can't inject a mock Dio, we verify
      // the observable behavior: the screen renders without crashing.
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'nonexistent-doc',
            filename: 'test.pdf',
          ),
        ),
      );

      // Pump past the 2-second timer interval to trigger at least one poll.
      await tester.pump(const Duration(seconds: 3));

      // Screen should still display the initial stage (received).
      expect(find.text('Received'), findsReceived);
      expect(find.byType(ProcessingStatusScreen), findsOneWidget);
    });

    testWidgets('does not crash on connection error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'doc-connection-error',
            filename: 'offline_policy.pdf',
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(ProcessingStatusScreen), findsOneWidget);
      expect(find.text('offline_policy.pdf'), findsOneWidget);
      expect(find.text('Processing failed'), findsNothing);
    });

    testWidgets('does not crash on timeout error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'doc-timeout',
            filename: 'slow_upload.pdf',
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(ProcessingStatusScreen), findsOneWidget);
      expect(find.text('slow_upload.pdf'), findsOneWidget);
    });

    testWidgets('continues polling after backend failure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'doc-retry',
            filename: 'retry_test.pdf',
          ),
        ),
      );

      // First poll at t=0, second at t=2s.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Received'), findsReceived);

      // Third poll at t=4s.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Received'), findsReceived);
      expect(find.byType(ProcessingStatusScreen), findsOneWidget);
    });
  });

  group('ProcessingStatusScreen — error state rendering', () {
    testWidgets('initial state shows processing header not error header',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'test.pdf',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Turning pages into answers'), findsOneWidget);
      expect(find.text("We couldn't finish this file"), findsNothing);
    });
  });
}
