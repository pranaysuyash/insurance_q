// ignore_for_file: avoid_print, use_key_in_widget_constructors,
// library_private_types_in_public_api

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:coverwise/services/legal_content_loader.dart';

class MyTestScreen extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _MyTestScreenState createState() => _MyTestScreenState();
}

class _MyTestScreenState extends State<MyTestScreen> {
  Future<LegalDocument>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= LegalContentLoader.loadTermsOfService(
        bundle: DefaultAssetBundle.of(context));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          print('ConnectionState: \${snapshot.connectionState}');
          if (snapshot.connectionState != ConnectionState.done) {
            return CircularProgressIndicator();
          }
          return Text('Done');
        });
  }
}

void main() {
  setUp(() {
    LegalContentLoader.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      return ByteData.view(
          Uint8List.fromList(utf8.encode('# Test\n\n## Section One\n\nContent'))
              .buffer);
    });
  });

  testWidgets('Test 1', (tester) async {
    print('Starting Test 1');
    await tester.pumpWidget(MaterialApp(home: MyTestScreen()));
    await tester.pumpAndSettle();
    print('Finished Test 1');
  });

  testWidgets('Test 2', (tester) async {
    print('Starting Test 2');
    await tester.pumpWidget(MaterialApp(home: MyTestScreen()));
    await tester.pumpAndSettle();
    print('Finished Test 2');
  });
}
