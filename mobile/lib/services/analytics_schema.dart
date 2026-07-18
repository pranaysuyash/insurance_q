/// Schema-enforced analytics event definitions for CoverWise.
///
/// Every event that the client tracks must be registered here with typed
/// property schemas. This prevents accidental PII leakage and ensures
/// event payloads are consistent across app versions.
library;

/// Allowed analytics event names and their property schemas.
const Map<String, Map<String, AnalyticsPropertyType>> kEventSchemas = {
  'question_submitted': {
    'question_length_bucket': AnalyticsPropertyType.string,
  },
  'answer_rendered': {
    'confidence_bucket': AnalyticsPropertyType.string,
    'answer_source_count_bucket': AnalyticsPropertyType.string,
  },
  'answer_feedback_submitted': {
    'sentiment': AnalyticsPropertyType.string,
  },
  'document_uploaded': {
    'document_type': AnalyticsPropertyType.string,
    'file_size_bucket': AnalyticsPropertyType.string,
    'ocr_used': AnalyticsPropertyType.boolean,
  },
  'document_deleted': {
    'document_type': AnalyticsPropertyType.string,
  },
  'screen_viewed': {
    'screen_name': AnalyticsPropertyType.string,
  },
  'feature_used': {
    'feature_name': AnalyticsPropertyType.string,
    'source': AnalyticsPropertyType.string,
  },
  'global_error': {
    'error_type': AnalyticsPropertyType.string,
    // Security audit P0-12: allowlisted short error code. The full
    // exception message and stack trace are NOT sent (they can leak
    // PII per the audit). error_code is a stable hash of the
    // exception type, used for deduplication on the operator side.
    'error_code': AnalyticsPropertyType.string,
  },
  'plan_upgraded': {
    'from_plan': AnalyticsPropertyType.string,
    'to_plan': AnalyticsPropertyType.string,
  },
  'consent_changed': {
    'purpose': AnalyticsPropertyType.string,
    'granted': AnalyticsPropertyType.boolean,
  },

  // ── RevOps v1 events (Phase R1.5, 2026-07-18) ────────────────────────
  // Per docs/planning/coverwise_revops_system_2026-07-18.md §10.
  // All properties are bucketed to enforce no-PII. T0 verification pending.

  // Emitted on every app launch (cold start) from mobile/lib/main.dart.
  // install_id is generated once per install and stored in SharedPreferences.
  // install_referrer_* are only present when the Play Store INSTALL_REFERRER
  // broadcast was received (i.e. install came from a campaign-tracked link).
  // The schema validator skips null values (see line 81), so organic installs
  // with no referrer pass validation as long as the keys are explicitly
  // emitted with null.
  'app_session_started': {
    'install_id': AnalyticsPropertyType.string,    // UUID stringified
    'session_id': AnalyticsPropertyType.string,    // UUID stringified, per-launch
    'platform': AnalyticsPropertyType.string,      // 'android' | 'ios' | ...
    'app_version': AnalyticsPropertyType.string,   // e.g. '0.1.2'
    'days_since_install': AnalyticsPropertyType.number,
    'is_reinstall': AnalyticsPropertyType.boolean,
    'install_referrer_source': AnalyticsPropertyType.string,   // null if no referrer
    'install_referrer_medium': AnalyticsPropertyType.string,   // null if no referrer
    'install_referrer_campaign': AnalyticsPropertyType.string, // null if no referrer
  },

  // Emitted once per install on first identity bootstrap
  // (anonymous token issue or Supabase Auth sign-up).
  'identity_created': {
    'identity_type': AnalyticsPropertyType.string, // 'anonymous' | 'account'
    'install_id': AnalyticsPropertyType.string,
  },

  // Emitted on Supabase Auth sign-up success.
  'account_created': {
    'install_id': AnalyticsPropertyType.string,
    'auth_method': AnalyticsPropertyType.string,   // 'email' | 'google' | 'apple' | ...
  },

  // Emitted when user hits a free-tier cap and the paywall is shown.
  'paywall_viewed': {
    'cap_type': AnalyticsPropertyType.string,       // 'questions' | 'documents' | 'family_members' | ...
    'cap_value': AnalyticsPropertyType.number,
    'user_actions_remaining': AnalyticsPropertyType.number,
  },

  // Emitted on successful billing event (webhook confirmed server-side).
  'subscription_started': {
    'plan_id': AnalyticsPropertyType.string,
    'plan_amount_paise': AnalyticsPropertyType.number,
    'billing_provider': AnalyticsPropertyType.string, // 'dodo' | 'razorpay'
  },

  // Emitted on successful subscription renewal.
  'subscription_renewed': {
    'plan_id': AnalyticsPropertyType.string,
    'period_number': AnalyticsPropertyType.number,
    'billing_provider': AnalyticsPropertyType.string,
  },

  // Emitted when user cancels (or auto-cancelled for non-payment).
  'subscription_cancelled': {
    'reason_bucket': AnalyticsPropertyType.string,  // 'too_expensive' | 'no_value' | 'switched_apps' | 'privacy' | 'other'
    'days_since_start': AnalyticsPropertyType.number,
    'billing_provider': AnalyticsPropertyType.string,
  },

  // Emitted when subscription lapses without renewal.
  'subscription_expired': {
    'grace_period_used': AnalyticsPropertyType.boolean,
    'billing_provider': AnalyticsPropertyType.string,
  },

  // Emitted when user triggers claim-anonymous flow.
  'claim_initiated': {
    'anonymous_token_age_hours_bucket': AnalyticsPropertyType.string, // '0-1' | '1-24' | '24-168' | '168+'
  },

  // Emitted when claim-anonymous completes successfully.
  'claim_succeeded': {
    'transferred_count': AnalyticsPropertyType.number,
  },

  // Emitted when claim-anonymous fails. CRITICAL: if transferred_count > 0, this
  // is silent document loss. Operator alert fires.
  'claim_failed': {
    'error_class': AnalyticsPropertyType.string,
    'transferred_count': AnalyticsPropertyType.number,
  },

  // Emitted when user clicks delete account (before the four-step deletion).
  'account_deletion_initiated': {
    'reason_bucket': AnalyticsPropertyType.string,  // 'too_expensive' | 'no_value' | 'switched_apps' | 'privacy' | 'other'
  },

  // Emitted after all four deletion steps complete (storage, metadata, auth, client).
  'account_deletion_completed': {
    'storage_deleted': AnalyticsPropertyType.number,
    'storage_errors': AnalyticsPropertyType.number,
    'auth_deleted': AnalyticsPropertyType.boolean,
    'reason_bucket': AnalyticsPropertyType.string,
  },

  // Emitted when processing doesn't complete in 5 minutes.
  'processing_stalled': {
    'stalled_after_seconds_bucket': AnalyticsPropertyType.string, // '300-360' | '360-600' | '600+'
  },

  // Emitted when user hits a quota (questions, documents, family members, etc).
  'entitlement_cap_reached': {
    'cap_type': AnalyticsPropertyType.string,
    'cap_value': AnalyticsPropertyType.number,
  },

  // Emitted when refund is successfully processed by billing provider.
  'refund_issued': {
    'provider': AnalyticsPropertyType.string,        // 'dodo' | 'razorpay'
    'refund_id': AnalyticsPropertyType.string,      // provider's refund ID
    'amount_paise': AnalyticsPropertyType.number,
    'reason_bucket': AnalyticsPropertyType.string,
  },
};

/// Property types for analytics events.
enum AnalyticsPropertyType {
  string,
  number,
  boolean,
}

/// Validate an event payload against the registered schema.
///
/// Returns a list of validation errors, or an empty list if valid.
/// Unknown event names are allowed (forward-compat) but warned.
List<String> validateAnalyticsEvent(
    String eventName, Map<String, dynamic> properties) {
  final errors = <String>[];
  final schema = kEventSchemas[eventName];

  if (schema == null) {
    // Unknown event — allow but warn in debug.
    return [];
  }

  // Check that every registered property is present and correctly typed.
  for (final entry in schema.entries) {
    final key = entry.key;
    final expectedType = entry.value;

    if (!properties.containsKey(key)) {
      errors.add('Missing required property "$key" for event "$eventName".');
      continue;
    }

    final value = properties[key];
    if (value == null) continue; // null is acceptable (optional).

    switch (expectedType) {
      case AnalyticsPropertyType.string:
        if (value is! String) {
          errors.add(
              'Property "$key" for "$eventName" must be String, got ${value.runtimeType}.');
        }
      case AnalyticsPropertyType.number:
        if (value is! num) {
          errors.add(
              'Property "$key" for "$eventName" must be num, got ${value.runtimeType}.');
        }
      case AnalyticsPropertyType.boolean:
        if (value is! bool) {
          errors.add(
              'Property "$key" for "$eventName" must be bool, got ${value.runtimeType}.');
        }
    }
  }

  // Check for unexpected properties that might be PII.
  for (final key in properties.keys) {
    if (!schema.containsKey(key)) {
      // Allow extra properties but flag potential PII patterns.
      final lower = key.toLowerCase();
      if (lower.contains('email') ||
          lower.contains('phone') ||
          lower.contains('name') ||
          lower.contains('address') ||
          lower.contains('ssn') ||
          lower.contains('aadhaar')) {
        errors.add(
            'Property "$key" for "$eventName" looks like PII — remove or anonymize.');
      }
    }
  }

  return errors;
}
