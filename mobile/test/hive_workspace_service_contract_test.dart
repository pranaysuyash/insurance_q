import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('claim workspace contract excludes session, analytics, and entitlements', () {
    final source = File('lib/services/hive_workspace_service.dart')
        .readAsStringSync();

    expect(source, contains('_claimPreservedBoxNames'));
    expect(source, contains("'consent_ledger'"));
    expect(source, contains("'qa_history'"));
    expect(source, contains("'field_overrides_box'"));
    expect(source, contains('_sessionKeys'));
    expect(source, contains("'analytics_events'"));
    expect(source, contains("'entitlements'"));
    expect(source, contains('await Hive.deleteBoxFromDisk(boxName);'));
    expect(source, isNot(contains('catch (_)')));
  });
}
