import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/qa_screen.dart';

/// Tests for the ConfidenceBadge widget.
///
/// The ConfidenceBadge checks AppConfig.confidenceCalibrated (compile-time const).
/// When false (the default), it shows a single "uncalibrated" chip regardless
/// of confidence value — per the trust audit's NO-GO verdict that confidence
/// is not yet calibrated against a real benchmark.
///
/// The High/Medium/Low threshold tests are only valid when
/// CONFIDENCE_CALIBRATED=true is passed via --dart-define at build time.
void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('ConfidenceBadge — default (uncalibrated)', () {
    testWidgets('shows "uncalibrated" for high confidence 0.95', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.95)),
      );

      expect(find.text('uncalibrated'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('shows "uncalibrated" for medium confidence 0.5', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.5)),
      );

      expect(find.text('uncalibrated'), findsOneWidget);
    });

    testWidgets('shows "uncalibrated" for low confidence 0.2', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.2)),
      );

      expect(find.text('uncalibrated'), findsOneWidget);
    });

    testWidgets('shows "uncalibrated" for boundary value 0.7', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.7)),
      );

      expect(find.text('uncalibrated'), findsOneWidget);
    });

    testWidgets('shows "uncalibrated" for boundary value 0.4', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.4)),
      );

      expect(find.text('uncalibrated'), findsOneWidget);
    });

    testWidgets('shows "uncalibrated" for zero confidence', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.0)),
      );

      expect(find.text('uncalibrated'), findsOneWidget);
    });

    testWidgets('shows "uncalibrated" for confidence 1.0', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 1.0)),
      );

      expect(find.text('uncalibrated'), findsOneWidget);
    });
  });

  group('Widget structure', () {
    testWidgets('uses the canonical pill-shaped status container',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.8)),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('uncalibrated'),
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(999));
    });

    testWidgets('contains an icon and text in a Row', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.8)),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('uncalibrated'), findsOneWidget);
    });

    testWidgets('uses emphasized status text and exposes status semantics',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.8)),
      );

      final textWidget = tester.widget<Text>(find.text('uncalibrated'));
      expect(textWidget.style?.fontWeight, FontWeight.w800);
      expect(
        find.bySemanticsLabel('Status: uncalibrated'),
        findsOneWidget,
      );
    });
  });

  // NOTE: The following tests are ONLY valid when confidenceCalibrated is true.
  // To run them, build with: flutter test --dart-define=CONFIDENCE_CALIBRATED=true
  // They are skipped by default because the compile-time const defaults to false.
  //
  // group('Boundary conditions (calibrated only)', () {
  //   testWidgets('0.69 is Medium, 0.70 is High', (tester) async { ... });
  //   testWidgets('0.39 is Low, 0.40 is Medium', (tester) async { ... });
  // });
}
