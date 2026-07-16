import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/document_preview_screen.dart';

/// Tests for DocumentPreviewScreen widget structure and constructor.
///
/// File I/O tests (error states for missing files, corrupted PDFs) are
/// excluded because File.exists() is a platform channel operation that
/// doesn't resolve in the Flutter test environment without mocking.
/// Those edge cases are better tested in integration tests or with
/// a mocked file system.
///
/// The _openDocumentPreview edge cases (null path, missing doc, empty list)
/// are tested at the PolicyDetailScreen level, not here, because
/// _openDocumentPreview checks documentsProvider state before navigating
/// to DocumentPreviewScreen.
void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('DocumentPreviewScreen', () {
    group('Widget structure', () {
      testWidgets('renders Scaffold with AppBar showing filename', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const DocumentPreviewScreen(
              filePath: '/tmp/test.pdf',
              filename: 'My Policy.pdf',
            ),
          ),
        );

        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('My Policy.pdf'), findsOneWidget);
      });

      testWidgets('shows CircularProgressIndicator in initial loading state', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const DocumentPreviewScreen(
              filePath: '/tmp/test.pdf',
              filename: 'test.pdf',
            ),
          ),
        );

        // Initial state should be loading
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('filename is displayed with overflow handling', (tester) async {
        const longFilename = 'This is a very long policy document filename that should be truncated.pdf';
        await tester.pumpWidget(
          buildTestApp(
            const DocumentPreviewScreen(
              filePath: '/tmp/test.pdf',
              filename: longFilename,
            ),
          ),
        );

        expect(find.text(longFilename), findsOneWidget);
        // AppBar title should handle overflow
        final textWidget = tester.widget<Text>(find.text(longFilename));
        expect(textWidget.overflow, TextOverflow.ellipsis);
      });
    });

    group('AppBar actions', () {
      testWidgets('shows View extracted summary button when documentId is provided', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const DocumentPreviewScreen(
              filePath: '/tmp/test.pdf',
              filename: 'test.pdf',
              documentId: 'doc-123',
            ),
          ),
        );

        expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
        expect(find.byTooltip('View extracted summary'), findsOneWidget);
      });

      testWidgets('hides View extracted summary button when documentId is null', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const DocumentPreviewScreen(
              filePath: '/tmp/test.pdf',
              filename: 'test.pdf',
            ),
          ),
        );

        expect(find.byIcon(Icons.analytics_outlined), findsNothing);
      });

      testWidgets('does not show page counter in initial loading state', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            const DocumentPreviewScreen(
              filePath: '/tmp/test.pdf',
              filename: 'test.pdf',
              documentId: 'doc-123',
            ),
          ),
        );

        // Page counter (e.g., "1 / 5") should not be visible during loading
        expect(find.textContaining('/'), findsNothing);
      });
    });

    group('Constructor parameters', () {
      test('filePath and filename are required', () {
        expect(
          () => DocumentPreviewScreen(
            filePath: '/tmp/test.pdf',
            filename: 'test.pdf',
          ),
          returnsNormally,
        );
      });

      test('documentId defaults to null', () {
        final screen = DocumentPreviewScreen(
          filePath: '/tmp/test.pdf',
          filename: 'test.pdf',
        );
        expect(screen.documentId, isNull);
      });

      test('documentId can be provided', () {
        final screen = DocumentPreviewScreen(
          filePath: '/tmp/test.pdf',
          filename: 'test.pdf',
          documentId: 'doc-123',
        );
        expect(screen.documentId, 'doc-123');
      });

      test('handles various file extensions', () {
        final pdf = DocumentPreviewScreen(
          filePath: '/tmp/policy.pdf',
          filename: 'policy.pdf',
        );
        expect(pdf.filePath, endsWith('.pdf'));

        final jpg = DocumentPreviewScreen(
          filePath: '/tmp/photo.jpg',
          filename: 'photo.jpg',
        );
        expect(jpg.filePath, endsWith('.jpg'));

        final upperPdf = DocumentPreviewScreen(
          filePath: '/tmp/policy.PDF',
          filename: 'policy.PDF',
        );
        expect(upperPdf.filePath.toLowerCase(), endsWith('.pdf'));
      });
    });
  });
}
