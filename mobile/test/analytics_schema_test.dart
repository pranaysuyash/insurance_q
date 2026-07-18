import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/services/analytics_schema.dart';

void main() {
  group('validateAnalyticsEvent', () {
    test('returns empty list for valid payload', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
      });
      expect(errors, isEmpty);
    });

    test('returns empty list for unknown event names (forward-compat)', () {
      final errors = validateAnalyticsEvent('future_event_v2', {
        'any_key': 'any_value',
      });
      expect(errors, isEmpty);
    });

    test('returns error for missing required property', () {
      final errors = validateAnalyticsEvent('question_submitted', {});
      expect(errors.length, 1);
      expect(errors[0], contains('Missing required property "question_length_bucket"'));
    });

    test('returns error for multiple missing required properties', () {
      final errors = validateAnalyticsEvent('answer_rendered', {});
      expect(errors.length, 2);
      expect(errors[0], contains('confidence_bucket'));
      expect(errors[1], contains('answer_source_count_bucket'));
    });

    test('allows null values for required properties', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': null,
      });
      expect(errors, isEmpty);
    });

    test('returns error for wrong type — string expected, got int', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 42,
      });
      expect(errors.length, 1);
      expect(errors[0], contains('must be String'));
      expect(errors[0], contains('got int'));
    });

    test('returns error for wrong type — string expected, got bool', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': true,
      });
      expect(errors.length, 1);
      expect(errors[0], contains('must be String'));
    });

    test('returns error for wrong type — bool expected, got string', () {
      final errors = validateAnalyticsEvent('document_uploaded', {
        'document_type': 'Health Insurance',
        'file_size_bucket': 'small',
        'ocr_used': 'yes',
      });
      expect(errors.length, 1);
      expect(errors[0], contains('must be bool'));
      expect(errors[0], contains('got String'));
    });

    test('returns error for wrong type — bool expected, got int', () {
      final errors = validateAnalyticsEvent('document_uploaded', {
        'document_type': 'Health Insurance',
        'file_size_bucket': 'small',
        'ocr_used': 1,
      });
      expect(errors.length, 1);
      expect(errors[0], contains('must be bool'));
    });

    test('detects PII — email property', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
        'user_email': 'test@example.com',
      });
      expect(errors.length, 1);
      expect(errors[0], contains('PII'));
      expect(errors[0], contains('user_email'));
    });

    test('detects PII — phone property', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
        'contact_phone': '+1234567890',
      });
      expect(errors.length, 1);
      expect(errors[0], contains('PII'));
      expect(errors[0], contains('contact_phone'));
    });

    test('detects PII — name property', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
        'user_name': 'John Doe',
      });
      expect(errors.length, 1);
      expect(errors[0], contains('PII'));
      expect(errors[0], contains('user_name'));
    });

    test('detects PII — address property', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
        'home_address': '123 Main St',
      });
      expect(errors.length, 1);
      expect(errors[0], contains('PII'));
    });

    test('detects PII — aadhaar property', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
        'aadhaar_number': '1234-5678-9012',
      });
      expect(errors.length, 1);
      expect(errors[0], contains('PII'));
    });

    test('detects PII — ssn property', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
        'ssn': '123-45-6789',
      });
      expect(errors.length, 1);
      expect(errors[0], contains('PII'));
    });

    test('does not flag non-PII properties', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
        'category': 'coverage',
        'retry_count': 3,
      });
      expect(errors, isEmpty);
    });

    test('does not flag PII-like property names that are in schema', () {
      // 'document_type' contains 'name' substring but is in the schema.
      final errors = validateAnalyticsEvent('document_uploaded', {
        'document_type': 'Health Insurance',
        'file_size_bucket': 'small',
        'ocr_used': true,
      });
      expect(errors, isEmpty);
    });

    test('returns multiple errors for multiple violations', () {
      final errors = validateAnalyticsEvent('document_uploaded', {
        'document_type': 123, // wrong type
        'user_email': 'test@example.com', // PII
      });
      // Should have at least 2 errors: wrong type for document_type, PII for user_email,
      // and missing file_size_bucket and ocr_used.
      expect(errors.length, greaterThanOrEqualTo(2));
      expect(errors.any((e) => e.contains('PII')), isTrue);
      expect(errors.any((e) => e.contains('must be')), isTrue);
    });

    test('all registered events have valid schemas', () {
      for (final entry in kEventSchemas.entries) {
        final eventName = entry.key;
        final schema = entry.value;
        expect(schema.isNotEmpty, isTrue,
            reason: 'Event "$eventName" has empty schema');
        for (final prop in schema.entries) {
          expect(prop.key.isNotEmpty, isTrue,
              reason: 'Event "$eventName" has empty property key');
        }
      }
    });

    test('answer_rendered validates both string properties', () {
      final errors = validateAnalyticsEvent('answer_rendered', {
        'confidence_bucket': 'high',
        'answer_source_count_bucket': 'few',
      });
      expect(errors, isEmpty);
    });

    test('consent_changed validates purpose and granted', () {
      final errors = validateAnalyticsEvent('consent_changed', {
        'purpose': 'document_processing',
        'granted': true,
      });
      expect(errors, isEmpty);
    });

    test('plan_upgraded validates both string properties', () {
      final errors = validateAnalyticsEvent('plan_upgraded', {
        'from_plan': 'free',
        'to_plan': 'plus',
      });
      expect(errors, isEmpty);
    });

    test('global_error validates all string properties', () {
      final errors = validateAnalyticsEvent('global_error', {
        'error_type': 'FlutterError',
        'error_summary': 'Null check operator used on a null value',
        'error_code': 'abc123',
      });
      expect(errors, isEmpty);
    });
  });
}
