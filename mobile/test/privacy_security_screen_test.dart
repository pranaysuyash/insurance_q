import 'package:coverwise/config/app_config.dart';
import 'package:coverwise/screens/privacy_security_screen.dart';
import 'package:coverwise/services/consent_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'helpers/hive_test_helper.dart';

void main() {
  setUpAll(HiveTestHelper.setUp);
  tearDownAll(HiveTestHelper.tearDown);

  setUp(() async {
    await Hive.box<dynamic>('consent_ledger').clear();
    await ConsentLedger().recordPolicyAcceptance(
      version: AppConfig.privacyPolicyVersion,
    );
  });

  testWidgets('keeps the bundled privacy policy reachable without a hosted URL',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacySecurityScreen()),
    );
    await tester.pump();

    expect(find.text('View full privacy policy'), findsOneWidget);
    expect(find.text('View in app'), findsOneWidget);
    expect(find.text('View consent activity'), findsOneWidget);
  });
}
