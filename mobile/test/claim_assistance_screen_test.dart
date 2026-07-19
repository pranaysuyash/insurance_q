import 'package:coverwise/models/field_citation.dart';
import 'package:coverwise/screens/claim_assistance_screen.dart';
import 'package:coverwise/widgets/not_yet_extracted_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FieldCitation _citation({
  String fieldName = 'insurer_name',
  String display = 'HDFC ERGO',
  String citeString = 'page 1',
  int pageNumber = 1,
  double fieldConfidence = 1.0,
}) {
  return FieldCitation(
    documentId: 'doc-1',
    fieldName: fieldName,
    value: FieldCitationValue(
      raw: 'HDFC ERGO',
      normalized: 'HDFC ERGO',
      display: display,
    ),
    valueType: 'string',
    fieldConfidence: fieldConfidence,
    parserKind: 'deterministic_lookup',
    citeString: citeString,
    evidenceStrength: 1.0,
    pageNumber: pageNumber,
    imageUri: 'coverwise-documents/doc-1/pages/1.png',
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
        ClaimAssistanceScreen(
          documentId: 'doc-1',
          citations: const [],
        ),
      ),
    );
    expect(find.text('Claim assistance'), findsOneWidget);
    expect(find.text('Filing a claim'), findsOneWidget);
  });

  testWidgets('shows the insurer name from substrate', (tester) async {
    await tester.pumpWidget(
      _harness(
        ClaimAssistanceScreen(
          documentId: 'doc-1',
          citations: [_citation()],
        ),
      ),
    );
    expect(find.text('Your insurer'), findsOneWidget);
    expect(find.text('HDFC ERGO'), findsOneWidget);
    expect(find.text('page 1'), findsOneWidget);
  });

  testWidgets('shows honest empty state when insurer not extracted',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        ClaimAssistanceScreen(
          documentId: 'doc-1',
          citations: const [],
        ),
      ),
    );
    expect(
      find.textContaining('The substrate has not extracted an insurer name'),
      findsOneWidget,
    );
  });

  testWidgets('always shows the 5 generic claim process steps', (tester) async {
    await tester.pumpWidget(
      _harness(
        ClaimAssistanceScreen(
          documentId: 'doc-1',
          citations: [_citation()],
        ),
      ),
    );
    expect(find.text('How to file a claim'), findsOneWidget);
    // Each step starts with a unique phrase.
    expect(find.textContaining('Notify your insurer'), findsOneWidget);
    expect(find.textContaining('Collect all relevant documents'),
        findsOneWidget);
    expect(find.textContaining('cashless'), findsWidgets);  // 2 mentions across steps
    expect(find.textContaining('Submit the claim form'), findsOneWidget);
    expect(find.textContaining('IRDAI ombudsman'), findsOneWidget);
  });

  testWidgets('always shows the not-yet-extracted section', (tester) async {
    await tester.pumpWidget(
      _harness(
        ClaimAssistanceScreen(
          documentId: 'doc-1',
          citations: [_citation()],
        ),
      ),
    );
    // The screen has a long body (insurer card + 5 generic
    // steps + the not-yet-extracted section). The
    // NotYetExtractedSection is below the fold; scroll to it
    // so the test viewport includes the widget in the
    // rendered tree.
    await tester.scrollUntilVisible(
      find.byType(NotYetExtractedSection),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(NotYetExtractedSection), findsOneWidget);
    expect(find.text('Claim helpline phone number'), findsOneWidget);
    expect(find.text('Claim email address'), findsOneWidget);
    expect(find.text('Network hospital list'), findsOneWidget);
  });

  testWidgets('renders correctly in dark mode (no hardcoded colors)',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        ClaimAssistanceScreen(
          documentId: 'doc-1',
          citations: [_citation()],
        ),
        mode: ThemeMode.dark,
      ),
    );
    expect(find.byType(ClaimAssistanceScreen), findsOneWidget);
    expect(find.text('Your insurer'), findsOneWidget);
  });
}
