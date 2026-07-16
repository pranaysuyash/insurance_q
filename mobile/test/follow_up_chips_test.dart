import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coverwise/screens/qa_screen.dart';
import 'package:coverwise/providers/questions_provider.dart';

/// Tests for the FollowUpChips widget.
///
/// The FollowUpChips widget displays a list of follow-up question chips.
/// When isLoadingProvider is true, chips should be disabled (onPressed: null)
/// and show a CircularProgressIndicator avatar. When loading is false,
/// chips should be enabled and show an arrow icon avatar.
void main() {
  Widget buildTestApp({
    required List<String> questions,
    required void Function(String) onAskQuestion,
    bool isLoading = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ProviderScope(
          overrides: [
            isLoadingProvider.overrideWith((ref) => isLoading),
          ],
          child: FollowUpChips(
            questions: questions,
            onAskQuestion: onAskQuestion,
          ),
        ),
      ),
    );
  }

  group('FollowUpChips', () {
    group('Rendering', () {
      testWidgets('renders all question chips', (tester) async {
        final questions = ['What is my deductible?', 'When does my policy expire?'];

        await tester.pumpWidget(buildTestApp(
          questions: questions,
          onAskQuestion: (_) {},
        ));

        expect(find.text('What is my deductible?'), findsOneWidget);
        expect(find.text('When does my policy expire?'), findsOneWidget);
        expect(find.byType(ActionChip), findsNWidgets(2));
      });

      testWidgets('renders empty Wrap for empty questions list', (tester) async {
        await tester.pumpWidget(buildTestApp(
          questions: [],
          onAskQuestion: (_) {},
        ));

        expect(find.byType(ActionChip), findsNothing);
        expect(find.byType(Wrap), findsOneWidget);
      });

      testWidgets('renders Wrap widget with correct spacing', (tester) async {
        await tester.pumpWidget(buildTestApp(
          questions: ['Question 1'],
          onAskQuestion: (_) {},
        ));

        final wrap = tester.widget<Wrap>(find.byType(Wrap));
        expect(wrap.spacing, 8);
        expect(wrap.runSpacing, 8);
      });
    });

    group('Not loading (isLoading = false)', () {
      testWidgets('chips are enabled when not loading', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(buildTestApp(
          questions: ['What is covered?'],
          onAskQuestion: (_) => tapped = true,
          isLoading: false,
        ));

        final chip = tester.widget<ActionChip>(find.byType(ActionChip));
        expect(chip.onPressed, isNotNull);

        await tester.tap(find.byType(ActionChip));
        expect(tapped, true);
      });

      testWidgets('chips show arrow icon when not loading', (tester) async {
        await tester.pumpWidget(buildTestApp(
          questions: ['What is covered?'],
          onAskQuestion: (_) {},
          isLoading: false,
        ));

        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Loading (isLoading = true)', () {
      testWidgets('chips are disabled when loading', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(buildTestApp(
          questions: ['What is covered?'],
          onAskQuestion: (_) => tapped = true,
          isLoading: true,
        ));

        final chip = tester.widget<ActionChip>(find.byType(ActionChip));
        expect(chip.onPressed, isNull);

        await tester.tap(find.byType(ActionChip), warnIfMissed: false);
        expect(tapped, false);
      });

      testWidgets('chips show CircularProgressIndicator when loading', (tester) async {
        await tester.pumpWidget(buildTestApp(
          questions: ['What is covered?'],
          onAskQuestion: (_) {},
          isLoading: true,
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsNothing);
      });

      testWidgets('multiple chips all disabled when loading', (tester) async {
        await tester.pumpWidget(buildTestApp(
          questions: ['Q1', 'Q2', 'Q3'],
          onAskQuestion: (_) {},
          isLoading: true,
        ));

        final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
        for (final chip in chips) {
          expect(chip.onPressed, isNull);
        }
        expect(find.byType(ActionChip), findsNWidgets(3));
      });
    });

    group('Callback behavior', () {
      testWidgets('onAskQuestion called with correct question text', (tester) async {
        String? receivedQuestion;

        await tester.pumpWidget(buildTestApp(
          questions: ['What is my premium?'],
          onAskQuestion: (q) => receivedQuestion = q,
        ));

        await tester.tap(find.byType(ActionChip));
        expect(receivedQuestion, 'What is my premium?');
      });

      testWidgets('tapping different chips calls callback with correct text', (tester) async {
        final tappedQuestions = <String>[];

        await tester.pumpWidget(buildTestApp(
          questions: ['Question A', 'Question B'],
          onAskQuestion: (q) => tappedQuestions.add(q),
        ));

        await tester.tap(find.text('Question A'));
        await tester.tap(find.text('Question B'));

        expect(tappedQuestions, ['Question A', 'Question B']);
      });
    });

    group('Edge cases', () {
      testWidgets('single question renders correctly', (tester) async {
        await tester.pumpWidget(buildTestApp(
          questions: ['Only question'],
          onAskQuestion: (_) {},
        ));

        expect(find.byType(ActionChip), findsOneWidget);
        expect(find.text('Only question'), findsOneWidget);
      });

      testWidgets('long question text renders without overflow', (tester) async {
        final longQuestion = 'This is a very long follow-up question that might wrap to multiple lines in the UI';

        await tester.pumpWidget(buildTestApp(
          questions: [longQuestion],
          onAskQuestion: (_) {},
        ));

        expect(find.text(longQuestion), findsOneWidget);
      });
    });
  });
}
