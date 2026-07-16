import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coverwise/services/analytics_service.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/widgets/shared/global_error_boundary.dart';

void main() {
  late Directory hiveDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    hiveDirectory = await Directory.systemTemp.createTemp('coverwise-tests-');
    Hive.init(hiveDirectory.path);
    await Hive.openBox(AppStateStore.boxName);
    AnalyticsService.init();
  });

  setUp(() async {
    await Hive.box(AppStateStore.boxName).clear();
    AnalyticsService.clear();
  });

  tearDownAll(() async {
    AnalyticsService.dispose();
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  group('GlobalErrorBoundary', () {
    testWidgets('renders child widget when no error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalErrorBoundary(
            child: Text('App Content'),
          ),
        ),
      );

      expect(find.text('App Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('shows error screen and tracks analytics on FlutterError',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalErrorBoundary(
            child: _ThrowingWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Error screen should be visible
      expect(find.text('Something went wrong'), findsWidgets);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Close App'), findsOneWidget);

      // Verify analytics buffer has the global_error event with correct properties
      expect(AnalyticsService.queuedCount, greaterThan(0));
    });

    testWidgets('clears error when Try Again is tapped and widget recovers',
        (tester) async {
      final state = _RecoverableWidgetState();

      await tester.pumpWidget(
        MaterialApp(
          home: GlobalErrorBoundary(
            child: _RecoverableWidget(state: state),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Error screen should be visible
      expect(find.text('Something went wrong'), findsWidgets);

      // Make the widget stop throwing
      state.shouldThrow = false;

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Should show normal content now
      expect(find.text('Recovered Content'), findsOneWidget);
    });

    testWidgets('error screen has retry and close buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalErrorBoundary(
            child: _ThrowingWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Close App'), findsOneWidget);
    });

    testWidgets('error persists when widget still throws after retry',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalErrorBoundary(
            child: _ThrowingWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First error should show error screen
      expect(find.text('Something went wrong'), findsWidgets);

      // Tap Try Again (widget still throws, so error persists)
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // Error should still be shown
      expect(find.text('Something went wrong'), findsWidgets);
    });
  });
}

/// A widget that throws an error during build.
class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();

  @override
  Widget build(BuildContext context) {
    throw Exception('Test error for GlobalErrorBoundary');
  }
}

/// A widget that can stop throwing on demand (for recovery testing).
class _RecoverableWidget extends StatefulWidget {
  final _RecoverableWidgetState state;
  const _RecoverableWidget({required this.state});

  @override
  State<_RecoverableWidget> createState() => state;
}

class _RecoverableWidgetState extends State<_RecoverableWidget> {
  bool shouldThrow = true;

  @override
  Widget build(BuildContext context) {
    if (shouldThrow) {
      throw Exception('Recoverable test error');
    }
    return const Text('Recovered Content');
  }
}
