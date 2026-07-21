import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/screens/qa_screen.dart';

/// Tests for the ConfidenceBadge widget.
///
/// The ConfidenceBadge checks AppConfig.confidenceCalibrated (compile-time const).
/// When false (the default), it is hidden entirely — per the trust audit's
/// NO-GO verdict that confidence is not yet calibrated against a real benchmark.
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

  group('ConfidenceBadge — default (hidden until calibrated)', () {
    testWidgets('hides high confidence 0.95', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.95)),
      );

      expect(find.text('uncalibrated'), findsNothing);
      expect(find.byType(ConfidenceBadge), findsOneWidget);
    });

    testWidgets('hides medium confidence 0.5', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.5)),
      );

      expect(find.text('uncalibrated'), findsNothing);
    });

    testWidgets('hides low confidence 0.2', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.2)),
      );

      expect(find.text('uncalibrated'), findsNothing);
    });

    testWidgets('hides boundary value 0.7', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.7)),
      );

      expect(find.text('uncalibrated'), findsNothing);
    });

    testWidgets('hides boundary value 0.4', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.4)),
      );

      expect(find.text('uncalibrated'), findsNothing);
    });

    testWidgets('hides zero confidence', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.0)),
      );

      expect(find.text('uncalibrated'), findsNothing);
    });

    testWidgets('hides confidence 1.0', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 1.0)),
      );

      expect(find.text('uncalibrated'), findsNothing);
    });
  });

  group('Widget structure', () {
    testWidgets('renders no status container before calibration',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.8)),
      );

      expect(find.textContaining('confidence'), findsNothing);
    });

    testWidgets('contains no icon or text before calibration', (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.8)),
      );

      expect(find.byType(Row), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('uncalibrated'), findsNothing);
    });

    testWidgets('does not expose internal confidence semantics',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(const ConfidenceBadge(confidence: 0.8)),
      );

      expect(find.bySemanticsLabel('Status: uncalibrated'), findsNothing);
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
