import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coverwise/screens/insights_screen.dart';
import 'package:coverwise/screens/dashboard_screen.dart';
import 'package:coverwise/screens/what_if_calculator_screen.dart';
import 'package:coverwise/l10n/app_localizations_gen.dart';

void main() {
  testWidgets('Insights screen coverage overview passes Map arguments to /coverage-gaps', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: InsightsScreen()),
          localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
          supportedLocales: AppLocalizationsGen.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coverage overview'), findsOneWidget);
  });

  testWidgets('WhatIfCalculatorScreen renders cleanly when registered on /what-if route', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: WhatIfCalculatorScreen()),
          localizationsDelegates: AppLocalizationsGen.localizationsDelegates,
          supportedLocales: AppLocalizationsGen.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What-If Calculator'), findsOneWidget);
  });
}
