import 'package:coverwise/utils/date_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidDate — valid dates', () {
    test('accepts DD/MM/YYYY', () {
      expect(isValidDate('15/06/2026'), isTrue);
    });

    test('accepts DD-MM-YYYY', () {
      expect(isValidDate('15-06-2026'), isTrue);
    });

    test('accepts DD.MM.YYYY', () {
      expect(isValidDate('15.06.2026'), isTrue);
    });

    test('accepts single-digit day and month', () {
      expect(isValidDate('5/6/2026'), isTrue);
    });

    test('accepts 2-digit year', () {
      expect(isValidDate('15/06/26'), isTrue);
    });

    test('accepts January 1', () {
      expect(isValidDate('01/01/2026'), isTrue);
    });

    test('accepts December 31', () {
      expect(isValidDate('31/12/2026'), isTrue);
    });

    test('accepts leap day on leap year', () {
      expect(isValidDate('29/02/2028'), isTrue);
    });
  });

  group('isValidDate — invalid dates', () {
    test('rejects empty string', () {
      expect(isValidDate(''), isFalse);
    });

    test('rejects plain text', () {
      expect(isValidDate('foo'), isFalse);
    });

    test('rejects day 32', () {
      expect(isValidDate('32/01/2026'), isFalse);
    });

    test('rejects month 13 (when unambiguous)', () {
      // 14/13/2026: first part > 12 means it must be day, second > 12 invalid
      expect(isValidDate('14/13/2026'), isFalse);
    });

    test('rejects day 0', () {
      expect(isValidDate('0/01/2026'), isFalse);
    });

    test('rejects month 0', () {
      expect(isValidDate('01/0/2026'), isFalse);
    });

    test('rejects February 30', () {
      expect(isValidDate('30/02/2026'), isFalse);
    });

    test('rejects February 29 on non-leap year', () {
      expect(isValidDate('29/02/2026'), isFalse);
    });

    test('rejects April 31 (30-day month)', () {
      expect(isValidDate('31/04/2026'), isFalse);
    });

    test('rejects incomplete date', () {
      expect(isValidDate('15/06'), isFalse);
    });

    test('rejects date with extra parts', () {
      expect(isValidDate('15/06/2026/extra'), isFalse);
    });

    test('rejects alphanumeric mix', () {
      expect(isValidDate('15ab/06/2026'), isFalse);
    });
  });

  group('isValidDate — edge cases', () {
    test('trims whitespace', () {
      expect(isValidDate('  15/06/2026  '), isTrue);
    });

    test('rejects just slashes', () {
      expect(isValidDate('///'), isFalse);
    });

    test('rejects YYYY/MM/DD format (year first)', () {
      expect(isValidDate('2026/06/15'), isFalse);
    });
  });
}
