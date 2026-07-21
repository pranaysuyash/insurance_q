import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:coverwise/services/legal_content_loader.dart';

void main() {
  setUp(() {
    debugPrint('setUp start');
    LegalContentLoader.clearCache();
    debugPrint('clearCache done');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      debugPrint('Mock handler called with message!');
      return ByteData.view(Uint8List.fromList(utf8.encode('# Test\n\n## Section One\n\nContent')).buffer);
    });
    debugPrint('setUp done');
  });

  testWidgets('Test 1', (tester) async {
    debugPrint('Starting Test 1');
    debugPrint('Calling loadTermsOfService');
    final doc = await LegalContentLoader.loadTermsOfService();
    debugPrint('Test 1 doc: ${doc.title}');
  });

  testWidgets('Test 2', (tester) async {
    debugPrint('Starting Test 2');
    debugPrint('Calling loadTermsOfService');
    final doc = await LegalContentLoader.loadTermsOfService();
    debugPrint('Test 2 doc: ${doc.title}');
  });
}
