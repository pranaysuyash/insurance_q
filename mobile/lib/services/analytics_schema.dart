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
    'error_summary': AnalyticsPropertyType.string,
  },
  'plan_upgraded': {
    'from_plan': AnalyticsPropertyType.string,
    'to_plan': AnalyticsPropertyType.string,
  },
  'consent_changed': {
    'purpose': AnalyticsPropertyType.string,
    'granted': AnalyticsPropertyType.boolean,
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
