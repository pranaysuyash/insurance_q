import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/screens/coverage_details_summary_screen.dart';

void main() {
  group('CoverageDetailsSummaryScreen', () {
    PolicySummary basicSummary({
      String type = 'health',
      double? coverage,
      double? premium,
    }) {
      return PolicySummary(
        documentId: 'doc1',
        policyNumber: 'POL-12345',
        insurer: 'Test Insurer',
        insurerHelpline: '1800-123-4567',
        insurerEmail: 'support@test.com',
        documentType: type,
        coverageAmount: coverage ?? 500000,
        deductible: 2500,
        premiumAmount: premium ?? 12500,
        premiumFrequency: 'annually',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        keyBenefits: ['Hospitalization cover', 'Daycare procedures'],
        exclusions: ['Pre-existing conditions (first 2 years)'],
        waitingPeriods: ['Maternity: 9 months'],
        executiveSummary: [
          'This policy covers hospitalization expenses up to the sum insured.',
          'Room rent is subject to sub-limits based on sum insured.',
          'Pre-existing conditions have a 24-month waiting period.',
        ],
        extractedAt: DateTime(2026, 7, 25),
      );
    }

    testWidgets('renders page header with policy type and insurer',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(
          summary: basicSummary(),
        ),
      ));

      expect(find.text('Everything Extracted'), findsOneWidget);
      expect(find.textContaining('Health Insurance'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Test Insurer'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders all collapsible section headers', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(
          summary: basicSummary(),
        ),
      ));

      expect(find.text('Policy Basics'), findsOneWidget);
      expect(find.text('Coverage & Premium'), findsOneWidget);
      expect(find.text('Dates & Status'), findsOneWidget);
      // Benefits & Coverage section should render when keyBenefits, exclusions,
      // or waitingPeriods are non-empty (all are populated in _basicSummary).
      // The section uses a conditional so check the ExpansionTile directly.
      expect(find.text('Benefits & Coverage'), findsWidgets);
      expect(find.text('Executive Summary'), findsOneWidget);
    });

    testWidgets('Policy Basics section is expanded by default', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(
          summary: basicSummary(),
        ),
      ));

      // Policy Basics content should be visible
      expect(find.text('POL-12345'), findsOneWidget);
      expect(find.text('Test Insurer'), findsOneWidget);
      expect(find.text('1800-123-4567'), findsOneWidget);
      expect(find.text('support@test.com'), findsOneWidget);
    });

    testWidgets('tapping section header reveals collapsed content',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(
          summary: basicSummary(),
        ),
      ));

      // Coverage & Premium section starts collapsed, so formatted amount
      // should not be in the widget tree initially.
      expect(find.text('₹5.0 L'), findsNothing);

      // Expand Coverage & Premium to verify its content
      final coverageHeader = find.widgetWithText(ExpansionTile, 'Coverage & Premium');
      await tester.tap(coverageHeader);
      await tester.pumpAndSettle();
      // Now the formatted amount should be visible
      expect(find.text('₹5.0 L'), findsOneWidget);

      // Tap Benefits & Coverage section to expand it
      final benefitsTile = find.widgetWithText(ExpansionTile, 'Benefits & Coverage');
      await tester.ensureVisible(benefitsTile);
      await tester.pump();
      await tester.tap(benefitsTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Benefits content should now be visible
      expect(find.textContaining('Hospitalization'), findsOneWidget);
      expect(find.textContaining('Daycare'), findsOneWidget);
      expect(find.textContaining('Pre-existing'), findsOneWidget);
      expect(find.textContaining('Maternity'), findsOneWidget);
    });

    testWidgets('renders executive summary items when present', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(
          summary: basicSummary(),
        ),
      ));

      // Tap Executive Summary
      final execTile = find.widgetWithText(ExpansionTile, 'Executive Summary');
      await tester.ensureVisible(execTile);
      await tester.pump();
      await tester.tap(execTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('hospitalization'), findsOneWidget);
    });

    testWidgets('hides Type-Specific Details when no type has fields',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(
          summary: basicSummary(type: 'unknown'),
        ),
      ));

      // Type-Specific Details section should not exist
      expect(
          find.widgetWithText(ExpansionTile, 'Type-Specific Details'),
          findsNothing);
    });

    testWidgets('renders Type-Specific Details when motor fields exist',
        (tester) async {
      final summary = basicSummary(type: 'auto').copyWith(
        motorFields: MotorPolicyFields(
          vehicleRegistrationNumber: 'MH-01-AB-1234',
          vehicleMakeModel: 'Maruti Swift',
          ncbPercent: 50,
          idv: 575000,
          fuelType: 'Petrol',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(summary: summary),
      ));

      // Type-Specific Details section should render
      expect(
          find.widgetWithText(ExpansionTile, 'Type-Specific Details'),
          findsOneWidget);

      // Tap to expand
      final tile = find.widgetWithText(ExpansionTile, 'Type-Specific Details');
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Motor / Auto sub-section should appear with fields
      expect(find.text('Motor / Auto'), findsOneWidget);
      expect(find.text('MH-01-AB-1234'), findsOneWidget);
      expect(find.text('Maruti Swift'), findsOneWidget);
      expect(find.textContaining('50%'), findsOneWidget);
    });

    testWidgets('renders Type-Specific Details with health fields',
        (tester) async {
      final summary = basicSummary(type: 'health').copyWith(
        healthFields: HealthPolicyFields(
          roomRentCap: '2% of sum insured',
          coPayPercent: 10,
          preExistingDiseases: ['Diabetes', 'Hypertension'],
          networkHospitals: '5,000+ hospitals',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(summary: summary),
      ));

      expect(
          find.widgetWithText(ExpansionTile, 'Type-Specific Details'),
          findsOneWidget);

      // Tap to expand
      final tile = find.widgetWithText(ExpansionTile, 'Type-Specific Details');
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Health Insurance appears in both header subtitle and sub-section label
      expect(find.text('Health Insurance'), findsAtLeastNWidgets(1));
      expect(find.text('2% of sum insured'), findsOneWidget);
      expect(find.textContaining('10%'), findsOneWidget);
      expect(find.text('5,000+ hospitals'), findsOneWidget);
      // Bullet list items
      expect(find.text('Pre-existing Diseases'), findsOneWidget);
      expect(find.text('Diabetes'), findsOneWidget);
      expect(find.text('Hypertension'), findsOneWidget);
    });

    testWidgets('renders Type-Specific Details with life fields',
        (tester) async {
      final summary = basicSummary(type: 'life').copyWith(
        lifeFields: LifePolicyFields(
          lifeAssuredName: 'Ravi Sharma',
          sumAssured: 10000000,
          policyTermYears: 20,
          nomineeName: 'Anita Sharma',
          riderDetails: ['Accidental death benefit', 'Critical illness rider'],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(summary: summary),
      ));

      expect(
          find.widgetWithText(ExpansionTile, 'Type-Specific Details'),
          findsOneWidget);

      final tile = find.widgetWithText(ExpansionTile, 'Type-Specific Details');
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Life Insurance sub-section should appear with fields
      // Life Insurance appears in both header subtitle and sub-section label
      expect(find.text('Life Insurance'), findsAtLeastNWidgets(1));
      expect(find.text('Ravi Sharma'), findsOneWidget);
      expect(find.text('₹1.0 Cr'), findsOneWidget);
      expect(find.text('20 years'), findsOneWidget);
      expect(find.text('Anita Sharma'), findsOneWidget);
      // Rider bullet list
      expect(find.text('Riders'), findsOneWidget);
      expect(find.text('Accidental death benefit'), findsOneWidget);
      expect(find.text('Critical illness rider'), findsOneWidget);
    });

    testWidgets('renders Type-Specific Details with home fields',
        (tester) async {
      final summary = basicSummary(type: 'home').copyWith(
        homeFields: HomePolicyFields(
          propertyAddress: '42, MG Road, Bangalore',
          buildingSumInsured: 5000000,
          contentsSumInsured: 1000000,
          yearBuilt: 2018,
          perilsCovered: ['Fire', 'Flood', 'Earthquake'],
          perilsExcluded: ['War', 'Nuclear hazard'],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(summary: summary),
      ));

      expect(
          find.widgetWithText(ExpansionTile, 'Type-Specific Details'),
          findsOneWidget);

      final tile = find.widgetWithText(ExpansionTile, 'Type-Specific Details');
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Home / Property sub-section should appear with fields
      expect(find.text('Home / Property'), findsOneWidget);
      expect(find.text('42, MG Road, Bangalore'), findsOneWidget);
      expect(find.text('₹50.0 L'), findsOneWidget);
      expect(find.text('₹10.0 L'), findsOneWidget);
      expect(find.text('2018'), findsOneWidget);
      // Perils bullet lists
      expect(find.text('Perils Covered'), findsOneWidget);
      expect(find.text('Fire'), findsOneWidget);
      expect(find.text('Flood'), findsOneWidget);
      expect(find.text('Earthquake'), findsOneWidget);
      expect(find.text('Perils Excluded'), findsOneWidget);
      expect(find.text('War'), findsOneWidget);
      expect(find.text('Nuclear hazard'), findsOneWidget);
    });

    testWidgets('renders Type-Specific Details with travel fields',
        (tester) async {
      final summary = basicSummary(type: 'travel').copyWith(
        travelFields: TravelPolicyFields(
          travellerName: 'Priya Singh',
          destination: 'Bali, Indonesia',
          tripDurationDays: 14,
          tripType: 'Leisure',
          medicalExpensesCover: 500000,
          addOnCovers: ['Trip cancellation', 'Baggage delay'],
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(summary: summary),
      ));

      expect(
          find.widgetWithText(ExpansionTile, 'Type-Specific Details'),
          findsOneWidget);

      final tile = find.widgetWithText(ExpansionTile, 'Type-Specific Details');
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Travel sub-section should appear with fields
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Priya Singh'), findsOneWidget);
      expect(find.text('Bali, Indonesia'), findsOneWidget);
      expect(find.text('14 days'), findsOneWidget);
      expect(find.text('Leisure'), findsOneWidget);
      expect(find.text('₹5.0 L'), findsOneWidget);
      // Add-on covers bullet list
      expect(find.text('Add-on Covers'), findsAtLeastNWidgets(1));
      expect(find.text('Trip cancellation'), findsOneWidget);
      expect(find.text('Baggage delay'), findsOneWidget);
    });

    testWidgets('renders Type-Specific Details with marine fields',
        (tester) async {
      final summary = PolicySummary(
        documentId: 'doc1',
        policyNumber: 'POL-12345',
        insurer: 'Test Insurer',
        documentType: 'marine',
        coverageAmount: 500000,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        keyBenefits: ['Cargo coverage'],
        extractedAt: DateTime(2026, 7, 25),
        marineFields: MarinePolicyFields(
          vesselName: 'MV Ocean Queen',
          voyageDetails: 'Mumbai to Singapore',
          cargoDescription: 'Electronics and textiles',
          cargoValue: 'USD 1,50,000',
          incoterms: 'CIF',
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(summary: summary),
      ));

      expect(
          find.widgetWithText(ExpansionTile, 'Type-Specific Details'),
          findsOneWidget);

      final tile = find.widgetWithText(ExpansionTile, 'Type-Specific Details');
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Marine / Cargo sub-section should appear with fields
      expect(find.text('Marine / Cargo'), findsOneWidget);
      expect(find.text('MV Ocean Queen'), findsOneWidget);
      expect(find.text('Mumbai to Singapore'), findsOneWidget);
      expect(find.text('Electronics and textiles'), findsOneWidget);
      expect(find.text('USD 1,50,000'), findsOneWidget);
      expect(find.text('CIF'), findsOneWidget);
    });

    testWidgets('renders extraction timestamp footer', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(
          summary: basicSummary(),
        ),
      ));

      expect(find.textContaining('25/7/2026'), findsWidgets);
    });

    testWidgets('renders coverage items when present', (tester) async {
      final summary = basicSummary().copyWith(
        coverageItems: [
          CoverageItem(
            name: 'Room Rent',
            limit: 5000,
            covered: true,
          ),
          CoverageItem(
            name: 'ICU Charges',
            limitText: 'Up to sum insured',
            covered: true,
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: CoverageDetailsSummaryScreen(summary: summary),
      ));

      // Tap Benefits & Coverage to expand
      final covTile = find.widgetWithText(ExpansionTile, 'Benefits & Coverage');
      await tester.ensureVisible(covTile);
      await tester.pump();
      await tester.tap(covTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Room Rent'), findsOneWidget);
      expect(find.text('ICU Charges'), findsOneWidget);
    });
  });
}
