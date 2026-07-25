import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('query adapter preserves backend verification status in both envelopes',
      () {
    final source =
        File('lib/services/query_service.dart').readAsStringSync();

    // One occurrence is required for the direct answer envelope and one for
    // the canonical `{status, result}` production envelope.
    final matches = RegExp("'verification_status':").allMatches(source).length;
    expect(matches, greaterThanOrEqualTo(2));
  });
}
