import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/widgets/answer_verification_badge.dart';

/// Helper that wraps the widget-under-test in a MaterialApp so theme
/// inherited widgets (Theme, MediaQuery) and the CoverWiseStatusChip
/// tree are available.
Widget _wrapApp(Widget widget) {
  return MaterialApp(
    home: Scaffold(
      body: widget,
    ),
  );
}

void main() {
  group('AnswerVerificationBadge', () {
    testWidgets('renders fully_backed status with verified icon',
        (tester) async {
      await tester.pumpWidget(_wrapApp(
        const AnswerVerificationBadge(
          status: AnswerVerificationStatus.fullyBacked,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Evidence-backed'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('renders partially_backed status with warning icon',
        (tester) async {
      await tester.pumpWidget(_wrapApp(
        const AnswerVerificationBadge(
          status: AnswerVerificationStatus.partiallyBacked,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Partially backed'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('renders abstained status with help icon',
        (tester) async {
      await tester.pumpWidget(_wrapApp(
        const AnswerVerificationBadge(
          status: AnswerVerificationStatus.abstained,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Could not verify'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('renders unverified status with info icon',
        (tester) async {
      await tester.pumpWidget(_wrapApp(
        const AnswerVerificationBadge(
          status: AnswerVerificationStatus.unverified,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not verified'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('fromString parses backend values correctly',
        (tester) async {
      expect(
        AnswerVerificationStatus.fromString('fully_backed'),
        AnswerVerificationStatus.fullyBacked,
      );
      expect(
        AnswerVerificationStatus.fromString('partially_backed'),
        AnswerVerificationStatus.partiallyBacked,
      );
      expect(
        AnswerVerificationStatus.fromString('abstained'),
        AnswerVerificationStatus.abstained,
      );
      expect(
        AnswerVerificationStatus.fromString('unverified'),
        AnswerVerificationStatus.unverified,
      );
      // Unknown values default to unverified
      expect(
        AnswerVerificationStatus.fromString('unknown'),
        AnswerVerificationStatus.unverified,
      );
      expect(
        AnswerVerificationStatus.fromString(null),
        AnswerVerificationStatus.unverified,
      );
    });

    testWidgets('renders a tooltip with explanation',
        (tester) async {
      await tester.pumpWidget(_wrapApp(
        const AnswerVerificationBadge(
          status: AnswerVerificationStatus.fullyBacked,
        ),
      ));
      await tester.pumpAndSettle();

      // The Tooltip widget should exist as an ancestor of the chip
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('all four display labels are non-empty',
        (tester) async {
      for (final status in AnswerVerificationStatus.values) {
        expect(status.displayLabel.isNotEmpty, isTrue,
            reason: 'Status $status should have a non-empty display label');
      }
    });

    testWidgets('all four tooltips are non-empty',
        (tester) async {
      for (final status in AnswerVerificationStatus.values) {
        expect(status.tooltip.isNotEmpty, isTrue,
            reason: 'Status $status should have a non-empty tooltip');
      }
    });
  });

  group('AnswerVerificationStatus.fromString', () {
    test('parses all valid values case-insensitively', () {
      expect(
        AnswerVerificationStatus.fromString('FULLY_BACKED'),
        AnswerVerificationStatus.fullyBacked,
      );
      expect(
        AnswerVerificationStatus.fromString('Fully_Backed'),
        AnswerVerificationStatus.fullyBacked,
      );
    });

    test('returns unverified for null input', () {
      expect(
        AnswerVerificationStatus.fromString(null),
        AnswerVerificationStatus.unverified,
      );
    });

    test('returns unverified for empty string', () {
      expect(
        AnswerVerificationStatus.fromString(''),
        AnswerVerificationStatus.unverified,
      );
    });
  });
}
