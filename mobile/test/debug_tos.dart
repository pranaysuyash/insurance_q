// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:coverwise/screens/terms_of_service_screen.dart';
import 'package:coverwise/services/legal_content_loader.dart';

void main() {
  setUp(() {
    LegalContentLoader.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message != null) {
        final key = utf8.decode(message.buffer.asUint8List());
        print('MOCK HANDLER CALLED FOR: \$key');
        if (key.endsWith('.md')) {
          print('RETURNING MARKDOWN FOR: \$key');
          return ByteData.view(Uint8List.fromList(
                  utf8.encode('# Test\n\n## Section One\n\nContent'))
              .buffer);
        }
      }
      return ByteData.view(Uint8List(0).buffer);
    });
  });

  testWidgets('Test 1', (tester) async {
    print('Starting Test 1');
    await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));
    await tester.pumpAndSettle();
    print('Finished Test 1');
  });

  testWidgets('Test 2', (tester) async {
    print('Starting Test 2');
    await tester.pumpWidget(const MaterialApp(home: TermsOfServiceScreen()));
    await tester.pumpAndSettle();
    print('Finished Test 2');
  });
}
