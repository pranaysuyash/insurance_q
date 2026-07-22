import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/widgets/shared/coverwise_snackbar.dart';

/// Helper that wraps [child] in a MaterialApp with the snackbar infrastructure
/// wired up (scaffoldMessengerKey + observer).
Widget _buildApp({
  required Widget child,
  NavigatorObserver? observer,
  Map<String, WidgetBuilder>? routes,
}) {
  return MaterialApp(
    scaffoldMessengerKey: CoverWiseSnackBar.scaffoldMessengerKey,
    navigatorObservers: [observer ?? CoverWiseSnackBarObserver()],
    home: Scaffold(body: child),
    routes: routes ?? {},
  );
}

void main() {
  // ── Operation Parameter Formatting ─────────────────────────────────

  group('error() operation parameter', () {
    testWidgets('prepends operation name when provided', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.error(
              context,
              'File too large',
              operation: 'policy upload',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(
        find.text('policy upload failed: File too large'),
        findsOneWidget,
      );
    });

    testWidgets('shows raw message when operation is null', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.error(
              context,
              'Something went wrong',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      // Should NOT contain "failed:" prefix
      expect(find.textContaining('failed:'), findsNothing);
    });

    testWidgets('shows Retry action when onAction is provided', (tester) async {
      var retryTapped = false;

      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.error(
              context,
              'Network error',
              operation: 'fetch policy',
              onAction: () => retryTapped = true,
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('fetch policy failed: Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryTapped, isTrue);
    });

    testWidgets('uses custom actionLabel when both provided', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.error(
              context,
              'No budget',
              operation: 'ask question',
              actionLabel: 'Buy packs',
              onAction: () {},
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Buy packs'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  // ── All Snackbar Types ─────────────────────────────────────────────

  group('snackbar types', () {
    testWidgets('success shows green check icon', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.success(
              context,
              'Policy saved',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Policy saved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('info shows info icon', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.info(
              context,
              'Processing in background',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Processing in background'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('warning shows warning icon', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.warning(
              context,
              'Almost out of questions',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Almost out of questions'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('error shows error icon', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.error(
              context,
              'Upload failed',
            ),
            child: const Text('Trigger'),
          ),
        ),
      ));

      await tester.tap(find.text('Trigger'));
      await tester.pump();

      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('clears previous snackbar before showing new one',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () =>
                    CoverWiseSnackBar.info(context, 'First message'),
                child: const Text('First'),
              ),
              ElevatedButton(
                onPressed: () =>
                    CoverWiseSnackBar.success(context, 'Second message'),
                child: const Text('Second'),
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('First'));
      await tester.pump();
      expect(find.text('First message'), findsOneWidget);

      await tester.tap(find.text('Second'));
      await tester.pump();
      expect(find.text('Second message'), findsOneWidget);
      expect(find.text('First message'), findsNothing);
    });
  });

  // ── dismissAll ─────────────────────────────────────────────────────

  group('dismissAll', () {
    testWidgets('dismissAll removes any visible snackbar', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => Column(
            children: [
              ElevatedButton(
                onPressed: () =>
                    CoverWiseSnackBar.info(context, 'Persistent toast'),
                child: const Text('Show'),
              ),
              ElevatedButton(
                onPressed: () => CoverWiseSnackBar.dismissAll(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Persistent toast'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      expect(find.text('Persistent toast'), findsNothing);
    });
  });

  // ── CoverWiseSnackBarObserver Route-Aware Dismissal ────────────────

  group('CoverWiseSnackBarObserver', () {
    testWidgets('dismisses snackbar on push', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                CoverWiseSnackBar.info(context, 'Will be dismissed'),
            child: const Text('Show'),
          ),
        ),
        routes: {
          '/next': (_) => const Scaffold(body: Text('Next screen')),
        },
      ));

      // Show snackbar
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Will be dismissed'), findsOneWidget);

      // Navigate to next screen — observer should dismiss
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/next');
      await tester.pumpAndSettle();

      expect(find.text('Next screen'), findsOneWidget);
      expect(find.text('Will be dismissed'), findsNothing);
    });

    testWidgets('dismisses snackbar on pop', (tester) async {
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: CoverWiseSnackBar.scaffoldMessengerKey,
        navigatorObservers: [CoverWiseSnackBarObserver()],
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  CoverWiseSnackBar.info(context, 'Will be dismissed on pop'),
              child: const Text('Show'),
            ),
          ),
        ),
      ));

      // Show snackbar
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Will be dismissed on pop'), findsOneWidget);

      // Pop — observer should dismiss
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('Will be dismissed on pop'), findsNothing);
    });

    testWidgets('dismisses snackbar on replace', (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CoverWiseSnackBar.info(
              context,
              'Old screen toast',
            ),
            child: const Text('Show'),
          ),
        ),
      ));

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Old screen toast'), findsOneWidget);

      // Replace current route
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Replaced screen')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Replaced screen'), findsOneWidget);
      expect(find.text('Old screen toast'), findsNothing);
    });

    testWidgets('handles null navigator gracefully during tests',
        (tester) async {
      // The observer's navigator is null when not attached to a Navigator.
      // Calling _dismissIfNeeded should not throw.
      final observer = CoverWiseSnackBarObserver();
      expect(() => observer.didPush(
          MaterialPageRoute(builder: (_) => const SizedBox()),
          null), returnsNormally);
      expect(() => observer.didPop(
          MaterialPageRoute(builder: (_) => const SizedBox()),
          MaterialPageRoute(builder: (_) => const SizedBox())), returnsNormally);
      expect(() => observer.didReplace(
          newRoute: MaterialPageRoute(builder: (_) => const SizedBox()),
          oldRoute: MaterialPageRoute(builder: (_) => const SizedBox())),
          returnsNormally);
    });

    testWidgets('new snackbar after navigation is not affected by observer',
        (tester) async {
      await tester.pumpWidget(_buildApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                CoverWiseSnackBar.info(context, 'Old screen toast'),
            child: const Text('Show old'),
          ),
        ),
        routes: {
          '/next': (_) => Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const Text('Next screen'),
                  ElevatedButton(
                    onPressed: () =>
                        CoverWiseSnackBar.success(context, 'New screen toast'),
                    child: const Text('Show new'),
                  ),
                ],
              ),
            ),
          ),
        },
      ));

      // Show toast on first screen
      await tester.tap(find.text('Show old'));
      await tester.pump();
      expect(find.text('Old screen toast'), findsOneWidget);

      // Navigate — old toast dismissed
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/next');
      await tester.pumpAndSettle();
      expect(find.text('Old screen toast'), findsNothing);

      // Show new toast on second screen — should work fine
      await tester.tap(find.text('Show new'));
      await tester.pump();
      expect(find.text('New screen toast'), findsOneWidget);
    });
  });
}
