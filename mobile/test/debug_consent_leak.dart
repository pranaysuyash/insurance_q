import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:coverwise/services/consent_ledger.dart';
import 'helpers/hive_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('First test file simulator', () {
    setUpAll(() async {
      await HiveTestHelper.setUp();
    });

    test('dummy', () async {
      final box = Hive.box('consent_ledger');
      await box.put('key1',
          '{"purpose": "analytics", "version": "v1", "granted": true, "timestamp": "2024-01-01T00:00:00Z"}');
    });

    tearDownAll(() async {
      await HiveTestHelper.tearDown();
    });
  });

  group('Consent ledger test simulator', () {
    late Box consentBox;
    late ConsentLedger ledger;

    setUpAll(() async {
      await HiveTestHelper.setUp();
    });

    setUp(() async {
      consentBox = Hive.box('consent_ledger');
      await consentBox.clear();
      ledger = ConsentLedger();
    });

    test('getLatestRecord returns null when no records exist', () {
      final latest = ledger.getLatestRecord(ConsentPurpose.documentProcessing);
      expect(latest, isNull);
    });

    tearDownAll(() async {
      await HiveTestHelper.tearDown();
    });
  });
}
