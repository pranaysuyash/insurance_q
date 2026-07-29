import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/utils/deep_link_policy.dart';

void main() {
  group('DeepLinkPolicy.validate', () {
    group('custom-scheme links (io.coverwise://)', () {
      test('allows valid emergency deep link', () {
        final uri = Uri.parse('io.coverwise://emergency');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isTrue);
        expect(result.path, '/emergency');
      });

      test('allows valid coverage-gaps with documentId', () {
        final uri = Uri.parse(
          'io.coverwise://coverage-gaps?documentId=abc-123',
        );
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isTrue);
        expect(result.path, '/coverage-gaps');
      });

      test('rejects unknown custom-scheme host', () {
        final uri = Uri.parse('io.coverwise://unknown-feature');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
        expect(result.error, contains('Unknown custom-scheme host'));
      });

      test('rejects documentId with invalid characters', () {
        final uri = Uri.parse(
          'io.coverwise://coverage-gaps?documentId=../../../etc/passwd',
        );
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
        expect(result.error, contains('Invalid documentId'));
      });

      test('rejects documentId exceeding max length', () {
        final longId = 'a' * 200;
        final uri = Uri.parse(
          'io.coverwise://coverage-gaps?documentId=$longId',
        );
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
        expect(result.error, contains('Invalid documentId'));
      });

      test('allows valid documentId with alphanumeric and hyphens', () {
        final uri = Uri.parse(
          'io.coverwise://coverage-gaps?documentId=doc-123_abc',
        );
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isTrue);
      });

      test('rejects citations query parameter at policy level', () {
        final uri = Uri.parse(
          'io.coverwise://coverage-gaps?documentId=doc-1'
          '&citations=%5B%7B%22text%22%3A%22fake%22%7D%5D',
        );
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
        expect(result.error, contains('Forbidden query parameter'));
      });
    });

    group('universal links (https://)', () {
      test('allows valid coverwise.app link', () {
        final uri = Uri.parse('https://coverwise.app/emergency');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isTrue);
        expect(result.path, '/emergency');
      });

      test('allows www subdomain', () {
        final uri = Uri.parse('https://www.coverwise.app/claims');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isTrue);
      });

      test('rejects unknown universal-link host', () {
        final uri = Uri.parse('https://evil.example.com/emergency');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
        expect(result.error, contains('Unknown universal-link host'));
      });

      test('rejects universal link with no path', () {
        final uri = Uri.parse('https://coverwise.app');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
      });
    });

    group('unsupported schemes', () {
      test('rejects http scheme', () {
        final uri = Uri.parse('http://coverwise.app/emergency');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
        expect(result.error, contains('Unsupported scheme'));
      });

      test('rejects tel scheme', () {
        final uri = Uri.parse('tel:+1234567890');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
      });

      test('rejects sms scheme', () {
        final uri = Uri.parse('sms:+1234567890');
        final result = DeepLinkPolicy.validate(uri);
        expect(result.isValid, isFalse);
      });
    });
  });

  group('DeepLinkPolicy identifier validation', () {
    test('accepts UUID-like identifiers', () {
      final uri = Uri.parse(
        'io.coverwise://coverage-gaps?documentId=550e8400-e29b-41d4-a716-446655440000',
      );
      final result = DeepLinkPolicy.validate(uri);
      expect(result.isValid, isTrue);
    });

    test('rejects identifiers with path traversal', () {
      final uri = Uri.parse(
        'io.coverwise://coverage-gaps?documentId=..%2F..%2Fetc%2Fpasswd',
      );
      final result = DeepLinkPolicy.validate(uri);
      expect(result.isValid, isFalse);
    });

    test('rejects identifiers with SQL injection patterns', () {
      final uri = Uri.parse(
        "io.coverwise://coverage-gaps?documentId=' OR 1=1 --",
      );
      final result = DeepLinkPolicy.validate(uri);
      expect(result.isValid, isFalse);
    });
  });

  group('DeepLinkPolicy forbidden parameters', () {
    test('rejects extractedText parameter', () {
      final uri = Uri.parse(
        'io.coverwise://qa?extractedText=fake',
      );
      final result = DeepLinkPolicy.validate(uri);
      expect(result.isValid, isFalse);
      expect(result.error, contains('Forbidden query parameter'));
    });

    test('rejects confidence parameter', () {
      final uri = Uri.parse(
        'io.coverwise://qa?confidence=0.95',
      );
      final result = DeepLinkPolicy.validate(uri);
      expect(result.isValid, isFalse);
    });

    test('rejects evidence parameter', () {
      final uri = Uri.parse(
        'io.coverwise://qa?evidence=fake',
      );
      final result = DeepLinkPolicy.validate(uri);
      expect(result.isValid, isFalse);
    });
  });
}
