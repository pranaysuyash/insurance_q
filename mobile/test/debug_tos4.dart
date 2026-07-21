// ignore_for_file: avoid_print, unused_local_variable

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:coverwise/services/legal_content_loader.dart';

void main() {
  setUp(() {
    LegalContentLoader.clearCache();
    rootBundle.clear(); // CLEAR ROOT BUNDLE CACHE!
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      return ByteData.view(
          Uint8List.fromList(utf8.encode('# Test\n\n## Section One\n\nContent'))
              .buffer);
    });
  });

  testWidgets('Test 1', (tester) async {
    print('Starting Test 1');
    final doc = await LegalContentLoader.loadTermsOfService();
    print('Test 1 doc: \${doc.title}');
    print('Finished Test 1');
  });

  testWidgets('Test 2', (tester) async {
    print('Starting Test 2');
    final doc = await LegalContentLoader.loadTermsOfService();
    print('Test 2 doc: \${doc.title}');
    print('Finished Test 2');
  });
}
