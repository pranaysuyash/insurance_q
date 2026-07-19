import 'package:coverwise/models/field_citation.dart';
import 'package:coverwise/screens/coverage_gap_screen.dart';
import 'package:coverwise/widgets/not_yet_extracted_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FieldCitation _citation({
  String fieldName = 'room_rent_cap',
  String display = '1% of sum insured, max ₹5,000/day',
  String citeString = 'page 4',
  int pageNumber = 4,
  double fieldConfidence = 0.85,
}) {
  return FieldCitation(
    documentId: 'doc-1',
    fieldName: fieldName,
    value: FieldCitationValue(
      raw: '1% of sum insured, max ₹5,000/day',
      normalized: '1% of sum insured, max ₹5,000/day',
      display: display,
    ),
    valueType: 'clause_text',
    fieldConfidence: fieldConfidence,
    parserKind: 'llm_extract',
    citeString: citeString,
    evidenceStrength: 1.0,
    pageNumber: pageNumber,
    imageUri: 'coverwise-documents/doc-1/pages/4.png',
  );
}

Widget _harness(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    themeMode: mode,
    home: child,
  );
}

void main() {
  testWidgets('renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      _harness(
        CoverageGapScreen(
          documentId: 'doc-1',
          citations: const [],
        ),
      ),
    );
    expect(find.text('Coverage gaps'), findsOneWidget);
    expect(find.text('What your policy says'), findsOneWidget);
  });

  testWidgets('shows the room rent cap when present', (tester) async {
    await tester.pumpWidget(
      _harness(
        CoverageGapScreen(
          documentId: 'doc-1',
          citations: [_citation()],
        ),
      ),
    );
    expect(find.text('Room rent cap'), findsOneWidget);
    expect(find.text('1% of sum insured, max ₹5,000/day'), findsOneWidget);
    expect(find.text('page 4'), findsOneWidget);
  });

  testWidgets('shows the insurer name when present', (tester) async {
    await tester.pumpWidget(
      _harness(
        CoverageGapScreen(
          documentId: 'doc-1',
          citations: [_citation(
            fieldName: 'insurer_name',
            display: 'HDFC ERGO',
            citeString: 'page 1',
            pageNumber: 1,
          )],
        ),
      ),
    );
    expect(find.text('Insurer'), findsOneWidget);
    expect(find.text('HDFC ERGO'), findsOneWidget);
  });

  testWidgets('shows honest empty state when no fields present',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        CoverageGapScreen(
          documentId: 'doc-1',
          citations: const [],
        ),
      ),
    );
    expect(
      find.textContaining('The substrate has not extracted any coverage-gap fields'),
      findsOneWidget,
    );
  });

  testWidgets('always shows the not-yet-extracted section', (tester) async {
    await tester.pumpWidget(
      _harness(
        CoverageGapScreen(
          documentId: 'doc-1',
          citations: [_citation()],
        ),
      ),
    );
    expect(find.byType(NotYetExtractedSection), findsOneWidget);
    expect(find.text('Maternity coverage'), findsOneWidget);
    expect(find.text('Dental coverage'), findsOneWidget);
    expect(find.text('Outpatient (OPD) coverage'), findsOneWidget);
  });

  testWidgets('renders correctly in dark mode (no hardcoded colors)',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        CoverageGapScreen(
          documentId: 'doc-1',
          citations: [_citation()],
        ),
        mode: ThemeMode.dark,
      ),
    );
    expect(find.byType(CoverageGapScreen), findsOneWidget);
    expect(find.text('Room rent cap'), findsOneWidget);
  });
}
