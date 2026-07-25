import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/services/analytics_schema.dart';

void main() {
  group('validateAnalyticsEvent', () {
    const eventNamesWithNoRequiredPayload = <String>{
      'analytics_consent_re_enabled',
      'dashboard_emergency_shortcut_tapped',
      'dashboard_first_upload_cta_tapped',
      'dashboard_preventive_tips_dismiss_all',
      'phone_capture_dismissed',
    };

    const runtimeEmittedEventNames = <String>{
      'account_created',
      'analytics_consent_re_enabled',
      'answer_feedback_submitted',
      'answer_rendered',
      'app_session_started',
      'batch_upload_completed',
      'batch_upload_started',
      'claim_failed',
      'claim_initiated',
      'claim_succeeded',
      'cta_clicked',
      'cta_dismissed',
      'dashboard_activity_item_tapped',
      'dashboard_coverage_type_tapped',
      'dashboard_emergency_shortcut_tapped',
      'dashboard_family_member_tapped',
      'dashboard_first_upload_cta_tapped',
      'dashboard_health_score_expanded',
      'dashboard_policy_tapped',
      'dashboard_preventive_tip_dismissed',
      'dashboard_preventive_tips_dismiss_all',
      'dashboard_quick_action_tapped',
      'dashboard_recent_claim_tapped',
      'dashboard_recent_claims_tapped',
      'document_processing_failed',
      'document_processing_succeeded',
      'first_upload_started',
      'first_value_delivered',
      'free_tier_limit_hit',
      'global_error',
      'global_error_recovered',
      'identity_created',
      'paywall_viewed',
      'phone_capture_dismissed',
      'phone_capture_shown',
      'phone_otp_requested',
      'phone_otp_verified',
      'plan_purchase_completed',
      'plan_purchase_failed',
      'plan_purchase_started',
      'qa_pack_balance_reconciled',
      'qa_pack_purchase_completed',
      'qa_pack_purchase_failed',
      'qa_pack_purchase_started',
      'qa_question_blocked_no_budget',
      'question_submitted',
      'subscription_state_synced',
      'support_intent',
    };

    test('returns empty list for valid payload', () {
      final errors = validateAnalyticsEvent('question_submitted', {
        'question_length_bucket': 'short',
      });
      expect(errors, isEmpty);
    });

    test('returns error for unknown event names', () {
      final errors = validateAnalyticsEvent('future_event_v2', {
        'any_key': 'any_value',
      });
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Unknown analytics event'));
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
        final allowEmptySchema = eventNamesWithNoRequiredPayload.contains(eventName);
        expect(
            schema.isNotEmpty || allowEmptySchema, isTrue,
            reason: 'Event "$eventName" has empty schema');
        for (final prop in schema.entries) {
          expect(prop.key.isNotEmpty, isTrue,
              reason: 'Event "$eventName" has empty property key');
        }
      }
    });

    test('all runtime emitted events are registered in schema', () {
      for (final eventName in runtimeEmittedEventNames) {
        expect(
          kEventSchemas.keys,
          contains(eventName),
          reason: 'Runtime event "$eventName" is missing from kEventSchemas',
        );
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
        'library': 'Flutter',
        'error_code': 'abc123',
      });
      expect(errors, isEmpty);
    });

    test('global_error_recovered validates library and hash properties', () {
      final errors = validateAnalyticsEvent('global_error_recovered', {
        'error_type': 'FlutterError',
        'library': 'Flutter',
        'error_code': 'abc123',
      });
      expect(errors, isEmpty);
    });

    test('phone events avoid phone number property names', () {
      final requestErrors = validateAnalyticsEvent('phone_otp_requested', {
        'otp_channel': 'sms',
      });
      final verifyErrors = validateAnalyticsEvent('phone_otp_verified', {
        'otp_channel': 'sms',
      });
      expect(requestErrors, isEmpty);
      expect(verifyErrors, isEmpty);
    });
  });
}
