import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active onboarding and upload copy do not call CoverWise a broker', () {
    final sources = [
      File('lib/screens/onboarding_screen.dart').readAsStringSync(),
      File('lib/widgets/dashboard/first_upload_cta.dart').readAsStringSync(),
    ];

    for (final source in sources) {
      expect(source, contains('policy information assistant'));
      expect(source, contains('not an insurer'));
      expect(source, contains('agent, or broker'));
      expect(source, isNot(contains('information broker')));
    }
  });
}
