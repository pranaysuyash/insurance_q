// ignore_for_file: avoid_print, unused_local_variable

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:coverwise/services/legal_content_loader.dart';

void main() {
  testWidgets('debug', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      print('REQUESTED ASSET: \$key');
      if (key.endsWith('.md')) {
        return ByteData.view(
            Uint8List.fromList(utf8.encode('# Markdown')).buffer);
      }
      return ByteData.view(Uint8List(0).buffer);
    });

    final doc1 = await LegalContentLoader.loadPrivacyPolicy();
    print('Privacy Policy Loaded: \${doc1.title}');
    final doc2 = await LegalContentLoader.loadTermsOfService();
    print('Terms of Service Loaded: \${doc2.title}');
  });
}
