import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/screens/processing_status_screen.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/app_state_store.dart';

/// Mock Dio interceptor that intercepts ALL requests for test document IDs.
///
/// Inserted at index 0 in [DocumentService.authenticatedDio] so it runs
/// *before* the [AuthInterceptor], avoiding the need to mock Hive or
/// FlutterSecureStorage in widget tests.
///
/// For paths containing a test doc ID:
/// - `/status` → returns `{"status": "failed"}` for `retry-*` IDs, or
///   `{"status": "received"}` for other test IDs
/// - `/reprocess` → returns 202 with success data, OR 409 depending on
///   the test's `reprocessStatusCode` setting
///
/// Any path NOT containing a recognized test doc ID passes through via
/// `handler.next()` (not used by these tests).
class _MockRetryInterceptor extends Interceptor {
  /// HTTP status code the reprocess endpoint should return.
  int reprocessStatusCode = 202;

  /// Whether the mock should respond with a network-like error instead of
  /// an HTTP response.
  bool simulateNetworkError = false;

  /// Returns `true` if the given path belongs to one of our test documents.
  /// Tests use document IDs like `test-doc-retry-error`, `test-doc`, or
  /// `test-doc-retry-max` — all starting with `test-doc`.
  static bool _isTestPath(String path) => path.contains('test-doc');

  /// Returns `true` if the path targets a retry-specific document (one that
  /// should simulate a 'failed' status). Plain test documents like `test-doc`
  /// return 'received' to keep the screen in its initial state.
  static bool _isRetryPath(String path) => path.contains('test-doc-retry');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;

    // Only intercept requests for our test documents.
    // All other paths pass through to AuthInterceptor (will fail in tests).
    if (!_isTestPath(path)) {
      handler.next(options);
      return;
    }

    if (simulateNetworkError) {
      // Simulate a transport-level failure (no server response).
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Simulated network error',
        ),
      );
      return;
    }

    if (path.endsWith('/status')) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          // Retry paths simulate a 'failed' status; plain test paths
          // keep the default 'received' so the screen stays initialised.
          data: _isRetryPath(path)
              ? {'status': 'failed'}
              : {'status': 'received'},
        ),
      );
      return;
    }

    if (path.endsWith('/reprocess')) {
      if (reprocessStatusCode == 202) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 202,
            data: {
              'document_id': 'test-doc',
              'message': 'Reprocessing started',
              'attempt': 1,
            },
          ),
        );
      } else if (reprocessStatusCode == 409) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 409,
            data: {'detail': 'Document is not in a retryable state'},
          ),
        );
      } else {
        handler.next(options);
      }
      return;
    }

    // Unknown test-doc path — pass through (shouldn't happen in tests).
    handler.next(options);
  }
}

void main() {
  late _MockRetryInterceptor mockInterceptor;
  late String hivePath;

  setUp(() async {
    // Create a unique temp directory for Hive to avoid stale lock file
    // collisions from previous timed-out test runs.
    hivePath = '${Directory.systemTemp.path}/hive_retry_test_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
    await Hive.openBox(AppStateStore.boxName);

    mockInterceptor = _MockRetryInterceptor();
    // Insert BEFORE AuthInterceptor (index 0) so our mock handles
    // test-doc requests before AuthInterceptor tries FlutterSecureStorage.
    DocumentService.authenticatedDio.interceptors.insert(0, mockInterceptor);
  });

  tearDown(() {
    DocumentService.authenticatedDio.interceptors.remove(mockInterceptor);
    // Intentionally skip Hive.close() — it causes the Flutter test runner
    // to hang during finalization (SIGTERM on timeout). Temp files are
    // cleaned up by the OS temp directory policy.
  });

  group('ProcessingStatusScreen — retry flow', () {
    testWidgets('initial state does not show retry button or error elements',
        (tester) async {
      // Uses `test-doc` (no `-retry` suffix). The mock handles the status
      // request and returns `{"status": "received"}`, so the screen stays
      // in the initial 'received' state — no error or retry elements.
      await tester.pumpWidget(
        const MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc',
            filename: 'policy.pdf',
          ),
        ),
      );
      // Allow one poll cycle (2 seconds) to complete.
      await tester.pump(const Duration(seconds: 3));

      // No error-state elements should be visible initially.
      expect(find.text('Processing failed'), findsNothing);
      expect(find.text('Retry processing'), findsNothing);
      expect(find.text('Back to documents'), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      // The processing header and initial stage should still show.
      expect(find.text('Turning pages into answers'), findsOneWidget);
      expect(find.text('Received'), findsWidgets);
    });

    testWidgets(
        'error state shows retry button with refresh icon '
        'after backend returns failed', (tester) async {
      mockInterceptor.reprocessStatusCode = 202; // default, not called here

      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc-retry-error',
            filename: 'failed_policy.pdf',
          ),
        ),
      );
      // Pump past the 2-second poll interval so _pollStatus receives
      // the mocked 'failed' response.
      await tester.pump(const Duration(seconds: 3));

      // Error-state UI elements should now be visible.
      expect(find.text('Processing failed'), findsOneWidget);
      expect(find.text('Retry processing'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.text('Back to documents'), findsOneWidget);

      // The error message appears in both the CoverWisePageHeader subtitle
      // and the error state body, so use findsWidgets.
      expect(
        find.textContaining('did not complete'),
        findsWidgets,
      );
    });

    testWidgets(
        'retry attempt counter shows after reprocess + new failure',
        (tester) async {
      // 1. Initial poll returns 'failed' → error state with retry button
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc-retry-counter',
            filename: 'retry_test.pdf',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Retry processing'), findsOneWidget,
          reason: 'retry button should be visible in error state');

      // 2. Tap retry → reprocess endpoint returns 202
      await tester.tap(find.text('Retry processing'));
      await tester.pump(); // Process the tap event
      await tester.pump(const Duration(milliseconds: 500)); // Let async Dio call complete

      // After retry, state resets to 'received'. The timer restarts.
      // 3. Pump past 2-second poll to get 'failed' again.
      await tester.pump(const Duration(seconds: 3));

      // After the second failure, the counter should be visible.
      expect(
        find.text('Retry processing (attempt 1 of 3)'),
        findsOneWidget,
        reason: 'retry button should show "attempt 1 of 3" after one retry',
      );
      expect(
        find.text('Attempt 1 of 3'),
        findsOneWidget,
        reason: 'attempt counter should be visible below the error message',
      );
    });

    testWidgets(
        '409 response shows appropriate error message '
        'instead of retrying', (tester) async {
      mockInterceptor.reprocessStatusCode = 409;

      // 1. Initial poll returns 'failed' → error state
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc-retry-409',
            filename: 'conflict.pdf',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Retry processing'), findsOneWidget);

      // 2. Tap retry → reprocess returns 409
      await tester.tap(find.text('Retry processing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The error message appears in both the CoverWisePageHeader subtitle
      // and the error state body, so use findsWidgets.
      expect(
        find.textContaining('cannot be reprocessed'),
        findsWidgets,
        reason:
            '409 should show a message saying the doc cannot be reprocessed',
      );
      // The retry button should still be available (retryCount=0, not consumed)
      expect(
        find.text('Retry processing'),
        findsOneWidget,
        reason: 'retry button should still be visible after 409',
      );
    });

    testWidgets(
        'mock interceptor handles network error on status endpoint',
        (tester) async {
      mockInterceptor.simulateNetworkError = true;

      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc-retry-network',
            filename: 'network_test.pdf',
          ),
        ),
      );
      // Pump past 2-second poll interval.
      await tester.pump(const Duration(seconds: 3));

      // Mock rejects with connectionError → caught by inner try/catch
      // → local storage returns null → method returns early.
      expect(find.text('Turning pages into answers'), findsOneWidget);
      expect(find.text('Received'), findsWidgets);
      expect(find.text('Processing failed'), findsNothing);
    });

    testWidgets(
        'retry button is hidden when max retries reached',
        (tester) async {
      // Cycle through 3 retries:
      //   poll → failed → tap retry → reprocess 202 → reset → poll → failed
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessingStatusScreen(
            documentId: 'test-doc-retry-max',
            filename: 'max_retries.pdf',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      // Retry 1
      expect(find.text('Retry processing'), findsOneWidget);
      await tester.tap(find.text('Retry processing'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3)); // Wait for poll → failed

      expect(find.text('Retry processing (attempt 1 of 3)'), findsOneWidget);

      // Retry 2
      await tester.tap(find.text('Retry processing (attempt 1 of 3)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('Retry processing (attempt 2 of 3)'), findsOneWidget);

      // Retry 3
      await tester.tap(find.text('Retry processing (attempt 2 of 3)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));

      // After 3 retries, _retryCount = 3 = _maxRetries.
      // canRetry = false → retry FilledButton.icon is HIDDEN.
      // Only the counter label "Attempt 3 of 3" should be visible.
      expect(
        find.text('Attempt 3 of 3'),
        findsOneWidget,
        reason: 'attempt counter should show 3 of 3',
      );

      // The retry button text should NOT be visible (button hidden at max).
      expect(
        find.textContaining('Retry processing (attempt'),
        findsNothing,
        reason: 'retry button should be hidden at max retries',
      );

      // The "Back to documents" button should still be visible.
      expect(
        find.text('Back to documents'),
        findsOneWidget,
        reason: 'back to documents button should always be visible',
      );
    });
  });
}
