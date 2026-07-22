import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/widgets/shared/screen_error_boundary.dart';
import 'package:coverwise/widgets/shared/global_error_boundary.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    // Verify no boundary leaks between tests
    expect(
      ErrorBoundaryRegistry.instance.dispatch(
        FlutterErrorDetails(exception: Exception('probe')),
      ),
      false,
      reason: 'Registry should be empty after each test',
    );
  });

  group('ScreenErrorBoundary', () {
    testWidgets('renders child widget when no error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenErrorBoundary(
            screenName: 'test',
            child: Text('Screen Content'),
          ),
        ),
      );

      expect(find.text('Screen Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('shows error fallback when error dispatched via registry',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenErrorBoundary(
            screenName: 'test',
            child: Text('Screen Content'),
          ),
        ),
      );

      // Dispatch an error through the registry
      ErrorBoundaryRegistry.instance.dispatch(
        FlutterErrorDetails(
          exception: Exception('Test error'),
          stack: StackTrace.current,
        ),
      );

      await tester.pump();

      expect(find.text('Screen Content'), findsNothing);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry clears error and restores child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ScreenErrorBoundary(
            screenName: 'test-retry',
            child: Text('Screen Content'),
          ),
        ),
      );

      ErrorBoundaryRegistry.instance.dispatch(
        FlutterErrorDetails(
          exception: Exception('Test error'),
          stack: StackTrace.current,
        ),
      );
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text('Screen Content'), findsOneWidget);
    });

    testWidgets('displays custom error builder when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ScreenErrorBoundary(
            screenName: 'test-custom',
            child: const Text('Screen Content'),
            errorBuilder: (details) =>
                const Text('Custom Error UI'),
          ),
        ),
      );

      ErrorBoundaryRegistry.instance.dispatch(
        FlutterErrorDetails(
          exception: Exception('Test error'),
          stack: StackTrace.current,
        ),
      );
      await tester.pump();

      expect(find.text('Custom Error UI'), findsOneWidget);
    });
  });

  group('ErrorBoundaryRegistry', () {
    testWidgets('routes to most recently registered boundary',
        (tester) async {
      String? handledBy;

      ErrorBoundaryRegistry.instance.register('screen1', (_) {
        handledBy = 'screen1';
      });
      ErrorBoundaryRegistry.instance.register('screen2', (_) {
        handledBy = 'screen2';
      });

      ErrorBoundaryRegistry.instance.dispatch(
        FlutterErrorDetails(exception: Exception('test')),
      );

      expect(handledBy, equals('screen2'),
          reason: 'Should route to last registered boundary');

      ErrorBoundaryRegistry.instance.unregister('screen1');
      ErrorBoundaryRegistry.instance.unregister('screen2');
    });

    test('returns false when no boundaries registered', () {
      expect(
        ErrorBoundaryRegistry.instance.dispatch(
          FlutterErrorDetails(exception: Exception('test')),
        ),
        false,
      );
    });
  });

  group('GlobalErrorBoundary delegates to ScreenErrorBoundary', () {
    testWidgets('screen boundary catches error before global boundary',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalErrorBoundary(
            child: ScreenErrorBoundary(
              screenName: 'inner',
              child: const Text('Screen Content'),
            ),
          ),
        ),
      );

      // Trigger a widget build error inside the ScreenErrorBoundary
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalErrorBoundary(
            child: ScreenErrorBoundary(
              screenName: 'inner',
              child: const _ThrowingWidget(),
            ),
          ),
        ),
      );

      // Frame 1: ErrorWidget.builder fires
      await tester.pump();
      // Frame 2: FlutterError.onError fires, dispatches via registry
      await tester.pump();

      // Screen-level error UI should be visible instead of global error screen
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing,
          reason:
              'Global "Try Again" should not appear; screen boundary caught it');
    });

    testWidgets('global boundary catches error when no screen boundary',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalErrorBoundary(
            child: const _ThrowingWidget(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      // Global error screen includes "Try Again"
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}

class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();

  @override
  Widget build(BuildContext context) {
    throw Exception('Test error for ScreenErrorBoundary');
  }
}
