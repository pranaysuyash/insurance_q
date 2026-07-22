import 'package:coverwise/services/policy_extraction_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cleanText', () {
    test('trims leading and trailing whitespace', () {
      expect(cleanText('  ICICI Lombard  '), 'ICICI Lombard');
    });

    test('strips "Answer:" prefix with colon', () {
      expect(cleanText('Answer: ICICI Lombard'), 'ICICI Lombard');
    });

    test('strips "Answer" prefix without colon', () {
      expect(cleanText('Answer ICICI Lombard'), 'ICICI Lombard');
    });

    test('strips "the policy" prefix', () {
      expect(cleanText('the policy number is 12345'), 'number is 12345');
    });

    test('strips "it is" prefix', () {
      expect(cleanText('it is ICICI Lombard'), 'ICICI Lombard');
    });

    test('strips "it.s" (LLM contraction)', () {
      expect(cleanText("it.s HDFC Ergo"), 'HDFC Ergo');
    });

    test('removes trailing period', () {
      expect(cleanText('ICICI Lombard.'), 'ICICI Lombard');
    });

    test('handles null input', () {
      expect(cleanText(null), '');
    });

    test('handles empty string', () {
      expect(cleanText(''), '');
    });

    test('preserves internal punctuation but strips trailing period', () {
      expect(cleanText('HDFC ERGO General Insurance Co.'), 'HDFC ERGO General Insurance Co');
    });

    test('strips "the document" prefix', () {
      expect(cleanText('the document shows HDFC Ergo'), 'shows HDFC Ergo');
    });

    test('strips "this" prefix', () {
      expect(cleanText('this is ICICI Lombard'), 'is ICICI Lombard');
    });
  });

  group('extractEmail', () {
    test('extracts email from plain text', () {
      expect(extractEmail('Send to help@icicilombard.com'), 'help@icicilombard.com');
    });

    test('extracts email from label-colon format', () {
      expect(
        extractEmail('Email: customer.support@icicilombard.com'),
        'customer.support@icicilombard.com',
      );
    });

    test('returns null when "not listed"', () {
      expect(extractEmail('Not listed'), isNull);
    });

    test('returns null when "not available"', () {
      expect(extractEmail('Not available'), isNull);
    });

    test('returns null when empty', () {
      expect(extractEmail(''), isNull);
    });

    test('returns null when null', () {
      expect(extractEmail(null), isNull);
    });

    test('returns null when no email found', () {
      expect(extractEmail('Call the helpline instead'), isNull);
    });

    test('extracts email with subdomain', () {
      expect(extractEmail('claims@support.hdfcergo.com'), 'claims@support.hdfcergo.com');
    });

    test('handles case insensitive', () {
      expect(extractEmail('EMAIL IS HELP@ICICI.COM'), 'help@icici.com');
    });
  });

  group('parseAmount', () {
    test('parses plain number', () {
      expect(parseAmount('500000'), 500000.0);
    });

    test('parses number with commas', () {
      expect(parseAmount('25,00,000'), 2500000.0);
    });

    test('parses "5 lakh"', () {
      expect(parseAmount('5 lakh'), 500000.0);
    });

    test('parses "5 lac"', () {
      expect(parseAmount('5 lac'), 500000.0);
    });

    test('parses "1 crore"', () {
      expect(parseAmount('1 crore'), 10000000.0);
    });

    test('parses "1 Cr"', () {
      expect(parseAmount('1 Cr'), 10000000.0);
    });

    test('parses "500 thousand"', () {
      expect(parseAmount('500 thousand'), 500000.0);
    });

    test('parses "₹5L" as 5 Lakh', () {
      expect(parseAmount('₹5L'), 500000.0);
    });

    test('parses "₹5,00,000" (with rupee symbol)', () {
      expect(parseAmount('₹5,00,000'), 500000.0);
    });

    test('parses "2.5 lakh" (decimal)', () {
      expect(parseAmount('2.5 lakh'), 250000.0);
    });

    test('returns null for null', () {
      expect(parseAmount(null), isNull);
    });

    test('returns null for empty string', () {
      expect(parseAmount(''), isNull);
    });

    test('returns null for non-numeric text', () {
      expect(parseAmount('not applicable'), isNull);
    });
  });

  group('parseDate', () {
    test('parses DD-MM-YYYY', () {
      final d = parseDate('27-08-2025');
      expect(d, isNotNull);
      expect(d!.year, 2025);
      expect(d.month, 8);
      expect(d.day, 27);
    });

    test('parses DD/MM/YYYY', () {
      final d = parseDate('27/08/2025');
      expect(d, isNotNull);
      expect(d!.year, 2025);
      expect(d.month, 8);
      expect(d.day, 27);
    });

    test('parses DD/MM/YY (2-digit year)', () {
      final d = parseDate('27/08/25');
      expect(d, isNotNull);
      expect(d!.year, 2025);
    });

    test('parses "1 Jan 2026" (text month with space)', () {
      final d = parseDate('1 Jan 2026');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 1);
      expect(d.day, 1);
    });

    test('parses "1st January 2026" (with ordinal)', () {
      final d = parseDate('1st January 2026');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 1);
      expect(d.day, 1);
    });

    test('parses ISO 8601 "2026-03-01"', () {
      final d = parseDate('2026-03-01');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 3);
      expect(d.day, 1);
    });

    test('returns null for null', () {
      expect(parseDate(null), isNull);
    });

    test('returns null for empty string', () {
      expect(parseDate(''), isNull);
    });

    test('returns null for unparseable text', () {
      expect(parseDate('not a date'), isNull);
    });

    test('returns null for dash-separated text month format (DD-Mon-YYYY)', () {
      // This format (like "15-Aug-2026") is not currently supported
      expect(parseDate('15-Aug-2026'), isNull);
    });
  });

  group('splitLines', () {
    test('splits newline-delimited text', () {
      final result = splitLines('Benefit A\nBenefit B\nBenefit C');
      expect(result, ['Benefit A', 'Benefit B', 'Benefit C']);
    });

    test('splits bullet-delimited text', () {
      final result = splitLines('• Benefit A\n• Benefit B');
      expect(result, ['Benefit A', 'Benefit B']);
    });

    test('splits dash-delimited text', () {
      final result = splitLines('- Benefit A\n- Benefit B');
      expect(result, ['Benefit A', 'Benefit B']);
    });

    test('filters empty lines', () {
      final result = splitLines('Benefit A\n\n\nBenefit B');
      expect(result, ['Benefit A', 'Benefit B']);
    });

    test('filters lines shorter than 4 characters', () {
      final result = splitLines('Benefit A\nNo');
      expect(result, ['Benefit A']);
    });

    test('caps at 10 items', () {
      final input = List.generate(15, (i) => 'Benefit $i').join('\n');
      final result = splitLines(input);
      expect(result.length, 10);
    });

    test('returns empty list for null', () {
      expect(splitLines(null), isEmpty);
    });

    test('returns empty list for empty string', () {
      expect(splitLines(''), isEmpty);
    });
  });

  group('validatePolicyNumber', () {
    test('accepts valid ICICI Lombard style policy number', () {
      final v = validatePolicyNumber('4214i/CPHSR/407834350/00/000');
      expect(v.isValid, isTrue);
      expect(v.confidence, greaterThanOrEqualTo(0.5));
      expect(v.normalizedValue, '4214i/CPHSR/407834350/00/000');
    });

    test('accepts short alphanumeric policy number with POL- prefix', () {
      final v = validatePolicyNumber('POL-12345');
      expect(v.isValid, isTrue);
      expect(v.confidence, greaterThanOrEqualTo(0.5));
      // "POL-" is not a strip-able prefix; it remains in the normalised value
      expect(v.normalizedValue, 'POL-12345');
    });

    test('accepts policy number with leading POLICY', () {
      final v = validatePolicyNumber('POLICY987654321');
      expect(v.isValid, isTrue);
      expect(v.normalizedValue, 'POLICY987654321');
    });

    test('rejects "not found"', () {
      final v = validatePolicyNumber('Not found');
      expect(v.isValid, isFalse);
      expect(v.confidence, 0.0);
    });

    test('rejects "n/a"', () {
      final v = validatePolicyNumber('n/a');
      expect(v.isValid, isFalse);
    });

    test('rejects very short all-letter value', () {
      final v = validatePolicyNumber('ABCDE');
      expect(v.isValid, isFalse);
    });

    test('rejects null', () {
      final v = validatePolicyNumber(null);
      expect(v.isValid, isFalse);
      expect(v.confidence, 0.0);
    });

    test('rejects empty string', () {
      final v = validatePolicyNumber('');
      expect(v.isValid, isFalse);
    });

    test('rejects 3-digit number', () {
      final v = validatePolicyNumber('123');
      expect(v.isValid, isFalse);
    });

    test('normalises "Policy No: 12345"', () {
      final v = validatePolicyNumber('Policy No: 12345');
      expect(v.isValid, isTrue);
      expect(v.normalizedValue, '12345');
    });

    test('normalises "Policy Number: ABC123"', () {
      final v = validatePolicyNumber('Policy Number: ABC123');
      expect(v.isValid, isTrue);
      expect(v.normalizedValue, 'ABC123');
    });

    test('strips leading hash', () {
      final v = validatePolicyNumber('#12345678');
      expect(v.isValid, isTrue);
      expect(v.normalizedValue, '12345678');
    });

    test('high confidence for 10-digit all-digits (typical Indian format)', () {
      final v = validatePolicyNumber('1234567890');
      expect(v.isValid, isTrue);
      expect(v.confidence, greaterThanOrEqualTo(0.8));
    });

    test('confidence for mixed alphanumeric with insurer prefix', () {
      final v = validatePolicyNumber('HC123456789');
      expect(v.isValid, isTrue);
      // Starts with HC (common health prefix) + 10+ chars + mixed = high
      expect(v.confidence, greaterThanOrEqualTo(0.8));
    });
  });

  group('fieldConfidence', () {
    test('policyNumber high for valid format', () {
      final c = fieldConfidence('policyNumber', 'POL-12345678');
      expect(c, greaterThanOrEqualTo(0.5));
    });

    test('policyNumber zero for null', () {
      expect(fieldConfidence('policyNumber', null), 0.0);
    });

    test('policyNumber zero for not found', () {
      expect(fieldConfidence('policyNumber', 'not found'), 0.0);
    });

    test('insurer high for long company names', () {
      final c = fieldConfidence('insurer', 'ICICI Lombard General Insurance');
      expect(c, greaterThanOrEqualTo(0.8));
    });

    test('insurer medium for shorter names', () {
      final c = fieldConfidence('insurer', 'ICICI');
      expect(c, greaterThanOrEqualTo(0.5));
    });

    test('coverageAmount high for positive value', () {
      final c = fieldConfidence('coverageAmount', '5,00,000');
      expect(c, greaterThanOrEqualTo(0.8));
    });

    test('coverageAmount zero for null', () {
      expect(fieldConfidence('coverageAmount', null), 0.0);
    });

    test('startDate high for valid date', () {
      final c = fieldConfidence('startDate', '01-01-2026');
      expect(c, greaterThanOrEqualTo(0.9));
    });

    test('startDate zero for unparseable', () {
      expect(fieldConfidence('startDate', 'not a date'), 0.0);
    });

    test('helpline high for valid phone', () {
      final c = fieldConfidence('helpline', '1800 2666');
      expect(c, greaterThanOrEqualTo(0.8));
    });

    test('email high for valid email', () {
      final c = fieldConfidence('email', 'help@icicilombard.com');
      expect(c, greaterThanOrEqualTo(0.9));
    });

    test('email low when not found', () {
      final c = fieldConfidence('email', 'not listed');
      expect(c, lessThanOrEqualTo(0.2));
    });

    test('benefits high for 3+ items', () {
      final c = fieldConfidence('benefits', 'Item A\nItem B\nItem C\nItem D');
      expect(c, greaterThanOrEqualTo(0.8));
    });

    test('unknown field defaults to 0.5', () {
      expect(fieldConfidence('unknown_field', 'anything'), 0.5);
    });
  });

  group('overallExtractionConfidence', () {
    test('high for complete extraction', () {
      final fields = {
        'policyNumber': 'POL-12345678',
        'insurer': 'ICICI Lombard General Insurance',
        'coverageAmount': '5,00,000',
        'startDate': '01-01-2026',
        'endDate': '31-12-2026',
        'helpline': '1800 2666',
        'email': 'help@icicilombard.com',
        'benefits': 'Room charges\nICU coverage\nDaycare',
        'exclusions': 'Cosmetic\nPre-existing',
        'premiumAmount': '12,000',
      };
      final c = overallExtractionConfidence(fields);
      expect(c, greaterThanOrEqualTo(0.5));
    });

    test('low for sparse extraction', () {
      final fields = <String, String?>{
        'policyNumber': 'not found',
        'insurer': '?',
        'coverageAmount': null,
      };
      final c = overallExtractionConfidence(fields);
      expect(c, lessThan(0.5));
    });

    test('zero for empty map', () {
      expect(overallExtractionConfidence(<String, String?>{}), 0.0);
    });
  });
}
