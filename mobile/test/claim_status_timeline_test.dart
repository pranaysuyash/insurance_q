import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/claim_record.dart';
import 'package:coverwise/widgets/claims/claim_status_timeline.dart';
import 'package:coverwise/theme/coverwise_theme.dart';
import 'package:coverwise/l10n/app_localizations_gen.dart';

/// Helper to build the widget with test data inside a MaterialApp.
Widget _buildTimeline(List<StatusUpdate> statusHistory) {
  return MaterialApp(
    localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
    theme: CoverWiseTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ClaimStatusTimeline(
          key: const ValueKey('timeline'),
          statusHistory: statusHistory,
        ),
      ),
    ),
  );
}

/// Fixed timestamp so tests are deterministic.
final _baseDate = DateTime(2026, 7, 23, 14, 30);

void main() {
  group('ClaimStatusTimeline — header', () {
    testWidgets('renders the user-recorded status section label',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
      ]));

      expect(find.text('Your recorded status history'), findsOneWidget);
    });
  });

  group('ClaimStatusTimeline — lifecycle branch (filed → paid path)', () {
    testWidgets('filed-only claim shows its recorded status with badge',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
      ]));

      expect(find.text('Self-recorded: filed'), findsOneWidget);
      expect(find.text('Current record'), findsOneWidget);
      expect(find.text('Self-recorded: in review'), findsOneWidget);
      expect(find.text('Self-recorded: approved'), findsOneWidget);
      expect(find.text('Self-recorded: paid'), findsOneWidget);
    });

    testWidgets('claim in review shows the recorded review status as current',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 3))),
      ]));

      // The current-record badge appears only on the recorded review state.
      expect(find.text('Self-recorded: filed'), findsOneWidget);
      expect(find.text('Self-recorded: in review'), findsOneWidget);
      expect(find.text('Self-recorded: approved'), findsOneWidget);
      expect(find.text('Self-recorded: paid'), findsOneWidget);

      expect(find.text('Current record'), findsOneWidget);
    });

    testWidgets('fully progressed claim shows recorded paid status as current',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 3))),
        StatusUpdate(
            status: ClaimStatus.approved,
            timestamp: _baseDate.add(const Duration(days: 10))),
        StatusUpdate(
            status: ClaimStatus.paid,
            timestamp: _baseDate.add(const Duration(days: 15))),
      ]));

      expect(find.text('Self-recorded: paid'), findsOneWidget);
      expect(find.text('Current record'), findsOneWidget);
      // All status labels still appear
      expect(find.text('Self-recorded: filed'), findsOneWidget);
      expect(find.text('Self-recorded: in review'), findsOneWidget);
      expect(find.text('Self-recorded: approved'), findsOneWidget);
    });
  });

  group('ClaimStatusTimeline — lifecycle branch (rejected path)', () {
    testWidgets('rejected claim hides recorded paid status from timeline',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 3))),
        StatusUpdate(
            status: ClaimStatus.rejected,
            timestamp: _baseDate.add(const Duration(days: 7))),
      ]));

      expect(find.text('Self-recorded: filed'), findsOneWidget);
      expect(find.text('Self-recorded: in review'), findsOneWidget);
      expect(find.text('Self-recorded: rejected'), findsOneWidget);
      expect(find.text('Current record'), findsOneWidget);

      expect(find.text('Self-recorded: paid'), findsNothing);
      expect(find.text('Self-recorded: approved'), findsNothing);
    });
  });

  group('ClaimStatusTimeline — current badge', () {
    testWidgets('only one current-record badge regardless of history length',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 2))),
        StatusUpdate(
            status: ClaimStatus.approved,
            timestamp: _baseDate.add(const Duration(days: 5))),
      ]));

      expect(find.text('Current record'), findsOneWidget);
    });
  });

  group('ClaimStatusTimeline — multiple events at same status', () {
    testWidgets('shows additional "Updated" date for duplicate status entries',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 3))),
        // Second review update
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 5))),
      ]));

      // Both recorded review entries should produce content.
      // First one shows the date, second one shows "Updated {date}"
      expect(find.textContaining('Updated'), findsOneWidget);
    });
  });

  group('ClaimStatusTimeline — date formatting', () {
    testWidgets('renders date in correct format', (tester) async {
      final specificDate = DateTime(2026, 12, 25, 9, 5);
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: specificDate),
      ]));

      // Format: "25 Dec 2026, 09:05"
      expect(find.textContaining('25 Dec 2026'), findsOneWidget);
      expect(find.textContaining('09:05'), findsOneWidget);
    });

    testWidgets('pads single-digit hours and minutes', (tester) async {
      final specificDate = DateTime(2026, 1, 5, 8, 3);
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: specificDate),
      ]));

      // Format: "5 Jan 2026, 08:03" — zero-padded
      expect(find.textContaining('5 Jan 2026'), findsOneWidget);
      expect(find.textContaining('08:03'), findsOneWidget);
    });
  });

  group('ClaimStatusTimeline — status labels', () {
    testWidgets('each node shows the correct ClaimStatus label',
        (tester) async {
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 2))),
        StatusUpdate(
            status: ClaimStatus.approved,
            timestamp: _baseDate.add(const Duration(days: 7))),
        StatusUpdate(
            status: ClaimStatus.paid,
            timestamp: _baseDate.add(const Duration(days: 12))),
      ]));

      // All four status labels should render
      expect(find.text('Self-recorded: filed'), findsOneWidget);
      expect(find.text('Self-recorded: in review'), findsOneWidget);
      expect(find.text('Self-recorded: approved'), findsOneWidget);
      expect(find.text('Self-recorded: paid'), findsOneWidget);
      expect(find.text('Self-recorded: rejected'), findsNothing);
    });
  });

  group('ClaimStatusTimeline — edge cases', () {
    testWidgets('handles empty history gracefully', (tester) async {
      await tester.pumpWidget(_buildTimeline([]));

      expect(find.text('Your recorded status history'), findsOneWidget);
      expect(find.text('Self-recorded: filed'), findsOneWidget);
      expect(find.text('Current record'), findsOneWidget);
    });

    testWidgets('paid claim (no approved in between) shows paid as current',
        (tester) async {
      // Some workflows may jump directly from inReview to paid
      await tester.pumpWidget(_buildTimeline([
        StatusUpdate(status: ClaimStatus.filed, timestamp: _baseDate),
        StatusUpdate(
            status: ClaimStatus.inReview,
            timestamp: _baseDate.add(const Duration(days: 3))),
        StatusUpdate(
            status: ClaimStatus.paid,
            timestamp: _baseDate.add(const Duration(days: 10))),
      ]));

      expect(find.text('Self-recorded: paid'), findsOneWidget);
      expect(find.text('Current record'), findsOneWidget);
      expect(find.text('Self-recorded: approved'), findsOneWidget);
    });
  });
}
