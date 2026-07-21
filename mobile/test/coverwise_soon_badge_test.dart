import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/widgets/shared/coverwise_components.dart';

/// Helper that wraps a widget in a MaterialApp with a theme so Theme.of(context)
/// works inside the widget under test.
Widget buildTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('CoverWiseSoonBadge', () {
    testWidgets('renders the text "Soon"', (tester) async {
      await tester.pumpWidget(buildTestApp(const CoverWiseSoonBadge()));
      expect(find.text('Soon'), findsOneWidget);
    });

    testWidgets('has compact size and rounded corners', (tester) async {
      await tester.pumpWidget(buildTestApp(const CoverWiseSoonBadge()));

      // Find the Container that wraps the badge
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Soon'),
          matching: find.byType(Container),
        ),
      );

      // Verify it has a rounded border
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(4));
    });

    testWidgets('uses theme surfaceContainerHighest for background',
        (tester) async {
      await tester.pumpWidget(buildTestApp(const CoverWiseSoonBadge()));

      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Soon'),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      // The background color should match the theme's surfaceContainerHighest
      final theme = Theme.of(tester.element(find.text('Soon')));
      expect(decoration.color, theme.colorScheme.surfaceContainerHighest);
    });

    testWidgets('uses theme onSurfaceVariant for text color', (tester) async {
      await tester.pumpWidget(buildTestApp(const CoverWiseSoonBadge()));

      final textWidget = tester.widget<Text>(find.text('Soon'));
      final style = textWidget.style!;

      final theme = Theme.of(tester.element(find.text('Soon')));
      expect(style.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('has small font size and semibold weight', (tester) async {
      await tester.pumpWidget(buildTestApp(const CoverWiseSoonBadge()));

      final textWidget = tester.widget<Text>(find.text('Soon'));
      final style = textWidget.style!;

      expect(style.fontSize, 10);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('works in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: CoverWiseSoonBadge()),
        ),
      );

      // Should still render "Soon" text without errors
      expect(find.text('Soon'), findsOneWidget);

      // Should use dark theme colors
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.text('Soon'),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      final theme = Theme.of(tester.element(find.text('Soon')));
      expect(decoration.color, theme.colorScheme.surfaceContainerHighest);
    });
  });
}
