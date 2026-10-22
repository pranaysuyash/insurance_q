import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/data/insurer_directory.dart';

void main() {
  group('InsurerDirectory', () {
    test('matches exact canonical insurer name', () {
      final contact = findInsurerContact('Star Health and Allied Insurance');
      expect(contact, isNotNull);
      expect(contact!.tollFreeNumber, '1800 425 2255');
      expect(contact.claimsEmail, 'support@starhealth.in');
    });

    test('matches insurer by common alias', () {
      final hdfc = findInsurerContact('HDFC ERGO');
      expect(hdfc, isNotNull);
      expect(hdfc!.tollFreeNumber, '1800 2666 400');

      final icici = findInsurerContact('ICICI Lombard');
      expect(icici, isNotNull);
      expect(icici!.tollFreeNumber, '1800 2666');

      final care = findInsurerContact('Religare Health');
      expect(care, isNotNull);
      expect(care!.canonicalName, 'Care Health Insurance');
    });

    test('returns null for unknown insurer or empty string', () {
      expect(findInsurerContact(null), isNull);
      expect(findInsurerContact(''), isNull);
      expect(findInsurerContact('Unknown Random Insurer 123'), isNull);
    });
  });
}
