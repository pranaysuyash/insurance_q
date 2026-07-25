import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/screens/processing_status_screen.dart';
import 'package:coverwise/services/document_service.dart';
import 'package:coverwise/services/app_state_store.dart';

class _TestInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('test-doc')) {
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'status': 'received'},
      ));
    } else {
      handler.next(options);
    }
  }
}

void main() {
  late String hivePath;
  late _TestInterceptor interceptor;

  setUp(() async {
    hivePath = '${Directory.systemTemp.path}/hive_test2_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
    await Hive.openBox(AppStateStore.boxName);

    interceptor = _TestInterceptor();
    DocumentService.authenticatedDio.interceptors.insert(0, interceptor);
    print('SETUP DONE');
  });

  tearDown(() async {
    DocumentService.authenticatedDio.interceptors.remove(interceptor);
    await Hive.close();
    try { await Directory(hivePath).delete(recursive: true); } catch (_) {}
    print('TEARDOWN DONE');
  });

  testWidgets('renders with mock', (tester) async {
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
