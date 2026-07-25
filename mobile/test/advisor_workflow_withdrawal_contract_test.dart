import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unsupported advisor workflow is not reachable from active navigation',
      () {
    final main = File('lib/main.dart').readAsStringSync();
    final more = File('lib/screens/more_screen.dart').readAsStringSync();

    expect(main, isNot(contains("'/agent-requests'")));
    expect(more, isNot(contains('Advisor requests')));
    expect(more, isNot(contains('advisor callback')));
  });

  test('claims navigation stays within the personal-record boundary', () {
    final more = File('lib/screens/more_screen.dart').readAsStringSync();

    expect(more, contains("'/claims'"));
    expect(more, contains("'/claim-tracker'"));
    expect(more, contains('CoverWise does not file or manage a claim'));
    expect(more, contains('statuses are not verified by CoverWise'));
  });
}
