import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account export stays owner-scoped and requires explicit sharing', () {
    final auth = File('lib/services/auth_service.dart').readAsStringSync();
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(auth, contains("dio.get('/user/account/export')"));
    expect(auth, contains("No account session to export"));
    expect(profile, contains('Export account data?'));
    expect(profile, contains('short-lived links to your private source files'));
    expect(profile, contains('SharePlus.instance.share'));
  });
}
