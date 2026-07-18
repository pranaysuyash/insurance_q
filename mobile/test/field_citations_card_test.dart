import 'package:coverwise/models/field_citation.dart';
import 'package:coverwise/widgets/field_citations_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FieldCitation _citation({
  String fieldName = 'sum_insured',
  String display = '₹5,00,000',
  String raw = '5,00,000',
  dynamic normalized = 50000000,
  String valueType = 'currency',
  String citeString = 'page 4',
  int pageNumber = 4,
  double fieldConfidence = 0.95,
  double evidenceStrength = 1.0,
  String parserKind = 'deterministic_regex',
}) {
  return FieldCitation(
    documentId: 'doc-1',
    fieldName: fieldName,
    value: FieldCitationValue(
      raw: raw,
      normalized: normalized,
      display: display,
    ),
    valueType: valueType,
    fieldConfidence: fieldConfidence,
    parserKind: parserKind,
    citeString: citeString,
    evidenceStrength: evidenceStrength,
    pageNumber: pageNumber,
    imageUri: 'coverwise-documents/doc-1/pages/4.png',
  );
}

Widget _harness(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    themeMode: mode,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders nothing when citations list is empty', (tester) async {
    await tester.pumpWidget(
      _harness(
        const FieldCitationsCard(citations: []),
      ),
    );
    expect(find.byType(FieldCitationsCard), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('renders header and one row per citation', (tester) async {
    final citations = [
      _citation(fieldName: 'sum_insured', display: '₹5,00,000'),
      _citation(
        fieldName: 'policy_number',
        display: 'ABC1234567',
        valueType: 'string',
        citeString: 'page 1',
        pageNumber: 1,
      ),
      _citation(
        fieldName: 'insurer_name',
        display: 'HDFC ERGO',
        valueType: 'string',
        parserKind: 'deterministic_lookup',
        citeString: 'page 1',
        pageNumber: 1,
      ),
    ];
    await tester.pumpWidget(
      _harness(FieldCitationsCard(citations: citations)),
    );
    expect(find.text('Verified from your policy'), findsOneWidget);
    expect(find.text('Sum insured'), findsOneWidget);
    expect(find.text('₹5,00,000'), findsOneWidget);
    expect(find.text('Policy number'), findsOneWidget);
    expect(find.text('ABC1234567'), findsOneWidget);
    expect(find.text('Insurer'), findsOneWidget);
    expect(find.text('HDFC ERGO'), findsOneWidget);
  });

  testWidgets('shows low-confidence indicator when confidence < 0.7',
      (tester) async {
    final citations = [
      _citation(fieldName: 'room_rent_cap', fieldConfidence: 0.6),
    ];
    await tester.pumpWidget(
      _harness(FieldCitationsCard(citations: citations)),
    );
    expect(find.textContaining('Lower confidence'), findsOneWidget);
  });

  testWidgets('does not show low-confidence indicator at >= 0.7',
      (tester) async {
    final citations = [
      _citation(fieldConfidence: 0.7),
    ];
    await tester.pumpWidget(
      _harness(FieldCitationsCard(citations: citations)),
    );
    expect(find.textContaining('Lower confidence'), findsNothing);
  });

  testWidgets('tap on row invokes onPageTap with the page number',
      (tester) async {
    int? tappedPage;
    final citations = [
      _citation(pageNumber: 7, citeString: 'page 7'),
    ];
    await tester.pumpWidget(
      _harness(
        FieldCitationsCard(
          citations: citations,
          onPageTap: (page) => tappedPage = page,
        ),
      ),
    );
    await tester.tap(find.text('page 7'));
    expect(tappedPage, 7);
  });

  testWidgets('renders correctly in dark mode (no hardcoded colors)',
      (tester) async {
    final citations = [
      _citation(),
    ];
    await tester.pumpWidget(
      _harness(
        FieldCitationsCard(citations: citations),
        mode: ThemeMode.dark,
      ),
    );
    // The card must render in dark mode without color exceptions.
    expect(find.byType(FieldCitationsCard), findsOneWidget);
    expect(find.text('Sum insured'), findsOneWidget);
    expect(find.text('₹5,00,000'), findsOneWidget);
  });

  testWidgets('human label maps known field names to Title Case',
      (tester) async {
    final cases = {
      'policy_number': 'Policy number',
      'policy_holder_name': 'Policy holder',
      'sum_insured': 'Sum insured',
      'policy_start_date': 'Policy start date',
      'premium_amount': 'Premium',
      'insurer_name': 'Insurer',
      'room_rent_cap': 'Room rent cap',
      'custom_field_name': 'Custom Field Name',
    };
    for (final entry in cases.entries) {
      final citations = [_citation(fieldName: entry.key)];
      await tester.pumpWidget(
        _harness(FieldCitationsCard(citations: citations)),
      );
      expect(find.text(entry.value), findsOneWidget,
          reason: 'field ${entry.key} should display as "${entry.value}"');
    }
  });
}
