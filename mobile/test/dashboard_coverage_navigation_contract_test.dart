import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard coverage action stays evidence-bound and passes route arguments', () {
    final source = File('lib/screens/dashboard_screen.dart').readAsStringSync();

    expect(source, contains("title: 'Coverage details'"));
    expect(source, contains("subtitle: 'Review cited policy fields'"));
    expect(source, contains("args: {'documentId': summaries.first.documentId}"));
    expect(source, isNot(contains("title: 'Coverage gaps'")));
    expect(source, isNot(contains("subtitle: 'Check what's missing'")));
  });
}
