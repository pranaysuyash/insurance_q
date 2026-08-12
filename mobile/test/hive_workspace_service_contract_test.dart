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
    // P0.5: Boxes are NOT deleted from disk on resetForPrincipal.
    // They remain at their namespaced path so old principal data is
    // recoverable if the user signs back in.
    expect(source, isNot(contains('await Hive.deleteBoxFromDisk(boxName);')));
    // Hive.close() is required because per-box close (box.close()) does
    // NOT fully deregister box names in Hive 2.x, causing HiveError on
    // reopen. Plugin-owned boxes are lightweight and reopen when needed.
    expect(source, contains('await Hive.close();'));
    // _hiveHomePath uses a single catch (_) for dynamic cast safety —
    // the service must not have any other bare catch-all blocks.
    final catches = RegExp(r'catch\s*\(_\)').allMatches(source);
    expect(catches.length, lessThanOrEqualTo(1),
        reason: 'Only one catch-all allowed (_hiveHomePath), found ${catches.length}');
  });
}
