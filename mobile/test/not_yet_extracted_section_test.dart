import 'package:coverwise/widgets/not_yet_extracted_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    themeMode: mode,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders nothing when fieldNames is empty', (tester) async {
    await tester.pumpWidget(
      _harness(
        const NotYetExtractedSection(fieldNames: []),
      ),
    );
    expect(find.byType(NotYetExtractedSection), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('renders default title and subtitle when not specified',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        const NotYetExtractedSection(
          fieldNames: ['Maternity coverage'],
        ),
      ),
    );
    expect(find.text('Not yet extracted from your policy'), findsOneWidget);
    expect(find.textContaining('not in the system yet'), findsOneWidget);
  });

  testWidgets('renders custom title and subtitle when specified',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        const NotYetExtractedSection(
          fieldNames: ['Claim helpline'],
          title: 'Not yet extracted for your claim',
          subtitle: 'Contact your insurer directly for these items.',
        ),
      ),
    );
    expect(find.text('Not yet extracted for your claim'), findsOneWidget);
    expect(find.text('Contact your insurer directly for these items.'),
        findsOneWidget);
  });

  testWidgets('renders all field names', (tester) async {
    await tester.pumpWidget(
      _harness(
        const NotYetExtractedSection(
          fieldNames: [
            'Maternity coverage',
            'Dental coverage',
            'OPD coverage',
          ],
        ),
      ),
    );
    expect(find.text('Maternity coverage'), findsOneWidget);
    expect(find.text('Dental coverage'), findsOneWidget);
    expect(find.text('OPD coverage'), findsOneWidget);
  });

  testWidgets('renders correctly in dark mode (no hardcoded colors)',
      (tester) async {
    await tester.pumpWidget(
      _harness(
        const NotYetExtractedSection(
          fieldNames: ['Maternity coverage'],
        ),
        mode: ThemeMode.dark,
      ),
    );
    expect(find.byType(NotYetExtractedSection), findsOneWidget);
    expect(find.text('Maternity coverage'), findsOneWidget);
  });
}
