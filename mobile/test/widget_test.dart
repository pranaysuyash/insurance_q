// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:coverwise/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Insurance app smoke test', (WidgetTester tester) async {
    // Initialize shared preferences for testing
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override the shared preferences provider with the test instance
        ],
        child: const InsuranceApp(),
      ),
    );

    // Verify that our app loads with the navigation bar
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('QA'), findsOneWidget);
  });
}
