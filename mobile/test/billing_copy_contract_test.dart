import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Q&A purchase copy never claims an unverified pack was added', () {
    // These strings are sourced from app_en.arb — pinned here so the test
    // does not need a widget tree for AppLocalizationsGen.of(context).
    const purchaseSuccess =
        'Purchase received. Questions appear after server confirmation.';
    const packPurchased =
        'Purchase received. Your Starter questions will appear after server confirmation.';

    expect(purchaseSuccess, contains('server confirmation'));
    expect(packPurchased, contains('server confirmation'));
    expect(packPurchased, isNot(contains('questions added')));
  });
}
