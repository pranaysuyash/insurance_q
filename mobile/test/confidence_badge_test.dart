import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/qa_screen.dart';

/// Tests for the ConfidenceBadge widget (previously _ConfidenceBadge).
///
/// The ConfidenceBadge is a small color-coded chip displayed next to Q&A
/// answers to indicate backend confidence levels:
///   - Green (≥0.7): "High confidence"
///   - Orange (≥0.4): "Medium confidence"
///   - Red (<0.4): "Low confidence"
void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('ConfidenceBadge', () {
    group('High confidence (≥ 0.7)', () {
      testWidgets('renders green badge for confidence 0.95', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.95)),
        );

        expect(find.text('High confidence'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      });

      testWidgets('renders green badge for confidence exactly 0.7', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.7)),
        );

        expect(find.text('High confidence'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      });

      testWidgets('renders green badge for confidence 1.0', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 1.0)),
        );

        expect(find.text('High confidence'), findsOneWidget);
      });
    });

    group('Medium confidence (0.4 ≤ x < 0.7)', () {
      testWidgets('renders orange badge for confidence 0.5', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.5)),
        );

        expect(find.text('Medium confidence'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('renders orange badge for confidence exactly 0.4', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.4)),
        );

        expect(find.text('Medium confidence'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('renders orange badge for confidence 0.69', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.69)),
        );

        expect(find.text('Medium confidence'), findsOneWidget);
      });
    });

    group('Low confidence (< 0.4)', () {
      testWidgets('renders red badge for confidence 0.2', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.2)),
        );

        expect(find.text('Low confidence'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      });

      testWidgets('renders red badge for confidence 0.0', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.0)),
        );

        expect(find.text('Low confidence'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      });

      testWidgets('renders red badge for confidence 0.39', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.39)),
        );

        expect(find.text('Low confidence'), findsOneWidget);
      });
    });

    group('Widget structure', () {
      testWidgets('is a Container with rounded corners', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.8)),
        );

        final container = tester.widget<Container>(
          find.ancestor(
            of: find.text('High confidence'),
            matching: find.byType(Container),
          ).first,
        );

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(12));
      });

      testWidgets('contains an icon and text in a Row', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.8)),
        );

        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        expect(find.text('High confidence'), findsOneWidget);
      });

      testWidgets('uses correct text style with fontWeight w600', (tester) async {
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.8)),
        );

        final textWidget = tester.widget<Text>(find.text('High confidence'));
        expect(textWidget.style?.fontWeight, FontWeight.w600);
        expect(textWidget.style?.fontSize, 11);
      });
    });

    group('Boundary conditions', () {
      testWidgets('0.69 is Medium, 0.70 is High', (tester) async {
        // Test just below threshold
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.69)),
        );
        expect(find.text('Medium confidence'), findsOneWidget);

        // Rebuild with just above threshold
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.70)),
        );
        expect(find.text('High confidence'), findsOneWidget);
      });

      testWidgets('0.39 is Low, 0.40 is Medium', (tester) async {
        // Test just below threshold
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.39)),
        );
        expect(find.text('Low confidence'), findsOneWidget);

        // Rebuild with just above threshold
        await tester.pumpWidget(
          buildTestApp(const ConfidenceBadge(confidence: 0.40)),
        );
        expect(find.text('Medium confidence'), findsOneWidget);
      });
    });
  });
}
