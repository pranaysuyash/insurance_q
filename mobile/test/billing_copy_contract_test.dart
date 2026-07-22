import 'package:coverwise/localization/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Q&A purchase copy never claims an unverified pack was added', () {
    expect(S.qaPacksPurchasedSuccess, contains('server confirmation'));
    expect(
      S.qaPacksPackPurchased('Starter', 5),
      contains('server confirmation'),
    );
    expect(S.qaPacksPackPurchased('Starter', 5),
        isNot(contains('questions added')));
  });
}
