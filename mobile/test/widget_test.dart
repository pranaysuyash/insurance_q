import 'dart:io';

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:coverwise/main.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coverwise/services/local_storage_service.dart';
import 'package:coverwise/services/app_state_store.dart';

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
        home: ProviderScope(
          child: InsuranceApp(),
        ),
      ),
    );

    // Verify that our app loads with the navigation bar
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('QA'), findsOneWidget);
  });
}
