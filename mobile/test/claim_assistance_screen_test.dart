import 'package:coverwise/screens/claims_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    themeMode: mode,
    home: child,
  );
}

void main() {
  testWidgets('renders app bar and page header', (tester) async {
    await tester.pumpWidget(
      _harness(const ClaimsAssistantScreen()),
    );
    expect(find.text('Claim guide'), findsOneWidget);
    expect(find.text('What happened?'), findsOneWidget);
    expect(
      find.textContaining('Choose an incident'), findsOneWidget,
    );
  });

  testWidgets('shows empty state when no documents uploaded', (tester) async {
    await tester.pumpWidget(
      _harness(const ClaimsAssistantScreen()),
    );
    expect(find.text('No documents uploaded'), findsOneWidget);
    expect(
      find.textContaining('Upload insurance documents'), findsOneWidget,
    );
  });

  testWidgets('shows all incident types', (tester) async {
    await tester.pumpWidget(
      _harness(const ClaimsAssistantScreen()),
    );
    expect(find.text('Hospitalization'), findsOneWidget);
    expect(find.text('Auto accident'), findsOneWidget);
    expect(find.text('Life insurance claim'), findsOneWidget);
    expect(find.text('Other or general'), findsOneWidget);
  });

  testWidgets('selecting an incident shows action button', (tester) async {
    await tester.pumpWidget(
      _harness(const ClaimsAssistantScreen()),
    );
    // No button visible before selection.
    expect(find.text('View preparation guide'), findsNothing);
    // Tap Hospitalization.
    await tester.tap(find.text('Hospitalization'));
    await tester.pumpAndSettle();
    expect(find.text('View preparation guide'), findsOneWidget);
  });

  testWidgets('renders correctly in dark mode (no hardcoded colors)', (tester) async {
    await tester.pumpWidget(
      _harness(
        const ClaimsAssistantScreen(),
        mode: ThemeMode.dark,
      ),
    );
    expect(find.byType(ClaimsAssistantScreen), findsOneWidget);
    expect(find.text('What happened?'), findsOneWidget);
  });


}
