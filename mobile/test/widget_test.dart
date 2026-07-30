import 'dart:io';

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:coverwise/l10n/app_localizations_gen.dart';
import 'package:coverwise/app.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/app_state_store.dart';
import 'package:coverwise/widgets/usage_stats_widget.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getLibraryDirectory':
        case 'getTemporaryDirectory':
        case 'getExternalStorageDirectory':
          return '/tmp/coverwise-tests';
        case 'getExternalStorageDirectories':
        case 'getExternalCacheDirectories':
          return <String>['/tmp/coverwise-tests'];
        case 'getDownloadsDirectory':
          return '/tmp/coverwise-tests';
      }
      return null;
    });
    await Directory('/tmp/coverwise-tests').create(recursive: true);
    await Hive.initFlutter();
    await Hive.openBox<String>(LocalStorageService.documentsBoxName);
    await Hive.openBox(AppStateStore.boxName);
  });

  testWidgets('Insurance app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrap in MaterialApp to provide Directionality required by Material widgets.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            AppLocalizationsGen.localizationsDelegates,
        supportedLocales: AppLocalizationsGen.supportedLocales,
        home: ProviderScope(
          overrides: [
            // Prevent the dashboard's UsageStatsWidget from making a real
            // HTTP call via QueryService.getUsageStats during the test
            // pump. The test framework returns 400 for all HTTP requests,
            // but Dio creates a zero-duration timer that stays pending
            // after the widget tree is disposed, causing an assertion
            // failure. Return mock fallback data instead.
            usageStatsProvider.overrideWith((ref) async {
              return {
                'session_uploads': 0,
                'session_limit': 5,
                'ip_uploads': 0,
                'ip_limit': 10,
              };
            }),
          ],
          child: InsuranceApp(),
        ),
      ),
    );

    // SplashScreen uses a 1500ms Timer + 800ms AnimationController.
    // Advance the fake clock past the splash minimum duration so onComplete fires.
    // Note: we use pump() instead of pumpAndSettle() because the splash's
    // CircularProgressIndicator and NavigationBar are infinite animations
    // that never settle.
    await tester.pump(const Duration(seconds: 3));

    // Verify that our app loads with the navigation bar
    // Home appears in both the page header and navigation destination.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Policies'), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);
  });
}
