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
    hivePath = '${Directory.systemTemp.path}/hive_noclose_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(hivePath).create(recursive: true);
    Hive.init(hivePath);
    await Hive.openBox(AppStateStore.boxName);
    interceptor = _TestInterceptor();
    DocumentService.authenticatedDio.interceptors.insert(0, interceptor);
  });

  tearDown(() {
    DocumentService.authenticatedDio.interceptors.remove(interceptor);
    // NO Hive.close()!
    // NO directory delete!
  });

  testWidgets('no hive close', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProcessingStatusScreen(documentId: 'test-doc', filename: 'test.pdf'),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Received'), findsWidgets);
  });
}
