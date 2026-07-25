import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/screens/processing_status_screen.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/app_state_store.dart';

void main() {
  late String hivePath;

  setUp(() async {
    hivePath = '${Directory.systemTemp.path}/hive_test_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
    await Hive.openBox(AppStateStore.boxName);
    print('HIVE SETUP DONE');
  });

  tearDown(() async {
    await Hive.close();
    try { await Directory(hivePath).delete(recursive: true); } catch (_) {}
    print('HIVE TEARDOWN DONE');
  });

  testWidgets('minimal rendering', (tester) async {
    print('TEST START');
    await tester.pumpWidget(
      const MaterialApp(
        home: ProcessingStatusScreen(documentId: 'test-doc', filename: 'test.pdf'),
      ),
    );
    print('PUMPWIDGET DONE');
    await tester.pump(const Duration(seconds: 3));
    print('PUMP DONE');
    expect(find.text('Received'), findsWidgets);
    print('ASSERTION DONE');
  });
}
