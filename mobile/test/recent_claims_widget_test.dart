import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'package:coverwise/models/claim_record.dart';
import 'package:coverwise/widgets/dashboard/recent_claims.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: build a test [ClaimRecord] with sensible defaults.
ClaimRecord _claim({
  required String id,
  String insurer = 'Test Insurer',
  String incidentType = 'Accident',
  ClaimStatus status = ClaimStatus.filed,
  DateTime? filedDate,
}) =>
    ClaimRecord(
      id: id,
      documentId: 'doc-$id',
      policyType: 'Health Insurance',
      insurer: insurer,
      incidentType: incidentType,
      description: 'Test description',
      filedDate: filedDate ?? DateTime(2026, 7, 20),
      status: status,
    );

Widget buildTestApp({List<ClaimRecord>? claims}) => MaterialApp(
      localizationsDelegates:
          AppLocalizationsGen.localizationsDelegates,
      supportedLocales: AppLocalizationsGen.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Scaffold(body: RecentClaims(claims: claims)),
    );

void main() {
  group('RecentClaims — empty state', () {
    testWidgets('renders nothing when empty list provided', (tester) async {
      await tester.pumpWidget(buildTestApp(claims: []));
      await tester.pump();

      expect(find.text('RECENT CLAIMS'), findsNothing);
      expect(find.byType(RecentClaims), findsOneWidget);
    });
  });

  group('RecentClaims — with claims', () {
    testWidgets('renders section label and claim cards when claims exist',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        claims: [_claim(id: '1')],
      ));
      await tester.pump();

      expect(find.text('Recent Claims'), findsOneWidget);
      expect(find.text('Test Insurer'), findsOneWidget);
      expect(find.textContaining('Accident'), findsOneWidget);
    });

    testWidgets('shows up to 3 most recent claims', (tester) async {
      await tester.pumpWidget(buildTestApp(claims: [
        _claim(id: '1', insurer: 'Insurer A', filedDate: DateTime(2026, 7, 22)),
        _claim(id: '2', insurer: 'Insurer B', filedDate: DateTime(2026, 7, 21)),
        _claim(id: '3', insurer: 'Insurer C', filedDate: DateTime(2026, 7, 20)),
        _claim(id: '4', insurer: 'Insurer D', filedDate: DateTime(2026, 7, 19)),
      ]));
      await tester.pump();

      expect(find.text('Insurer A'), findsOneWidget);
      expect(find.text('Insurer B'), findsOneWidget);
      expect(find.text('Insurer C'), findsOneWidget);
      expect(find.text('Insurer D'), findsNothing);
    });

    testWidgets('shows View all link when more than 3 claims exist',
        (tester) async {
      await tester.pumpWidget(buildTestApp(claims: [
        _claim(id: '1', filedDate: DateTime(2026, 7, 24)),
        _claim(id: '2', filedDate: DateTime(2026, 7, 23)),
        _claim(id: '3', filedDate: DateTime(2026, 7, 22)),
        _claim(id: '4', filedDate: DateTime(2026, 7, 21)),
      ]));
      await tester.pump();

      expect(find.text('View all 4 claims'), findsOneWidget);
    });

    testWidgets('hides View all link when 3 or fewer claims exist',
        (tester) async {
      await tester.pumpWidget(buildTestApp(claims: [
        _claim(id: '1'),
        _claim(id: '2'),
        _claim(id: '3'),
      ]));
      await tester.pump();

      expect(find.textContaining('View all'), findsNothing);
    });
  });

  group('RecentClaims — status chip rendering', () {
    for (final entry in [
      (status: ClaimStatus.filed, label: 'Self-recorded: filed'),
      (status: ClaimStatus.inReview, label: 'Self-recorded: in review'),
      (status: ClaimStatus.approved, label: 'Self-recorded: approved'),
      (status: ClaimStatus.rejected, label: 'Self-recorded: rejected'),
      (status: ClaimStatus.paid, label: 'Self-recorded: paid'),
    ]) {
      testWidgets('${entry.label} status renders correct chip label',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          claims: [_claim(id: '1', status: entry.status)],
        ));
        await tester.pump();

        expect(find.text(entry.label), findsOneWidget);
      });
    }
  });

  group('RecentClaims — incident type icons', () {
    testWidgets('accident incident shows car crash icon', (tester) async {
      await tester.pumpWidget(buildTestApp(
        claims: [_claim(id: '1', incidentType: 'Accident')],
      ));
      await tester.pump();

      expect(find.byIcon(Icons.car_crash_outlined), findsOneWidget);
    });

    testWidgets('theft incident shows lock icon', (tester) async {
      await tester.pumpWidget(buildTestApp(
        claims: [_claim(id: '1', incidentType: 'Theft')],
      ));
      await tester.pump();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('medical incident shows medical icon', (tester) async {
      await tester.pumpWidget(buildTestApp(
        claims: [_claim(id: '1', incidentType: 'Hospitalization')],
      ));
      await tester.pump();

      expect(find.byIcon(Icons.medical_services_outlined), findsOneWidget);
    });

    testWidgets('default incident type shows description icon', (tester) async {
      await tester.pumpWidget(buildTestApp(
        claims: [_claim(id: '1', incidentType: 'Other')],
      ));
      await tester.pump();

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });
  });

  group('RecentClaims — dark mode', () {
    testWidgets('renders without hardcoded color issues in dark mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates:
            AppLocalizationsGen.localizationsDelegates,
        supportedLocales: AppLocalizationsGen.supportedLocales,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: Scaffold(
          body: RecentClaims(claims: [
            _claim(id: '1', status: ClaimStatus.filed),
            _claim(id: '2', status: ClaimStatus.approved),
          ]),
        ),
      ));
      await tester.pump();

      expect(find.text('Self-recorded: filed'), findsOneWidget);
      expect(find.text('Self-recorded: approved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
