import 'package:flutter/foundation.dart';

/// Mirrors the server-side `FieldCitation` shape
/// (src/services/evidence_substrate_service.py).
/// Keep these in sync; the API route returns this exact shape.
@immutable
class FieldCitationValue {
  final String raw;
  final dynamic normalized;
  final String display;

  const FieldCitationValue({
    required this.raw,
    required this.normalized,
    required this.display,
  });

  factory FieldCitationValue.fromJson(Map<String, dynamic> json) {
    return FieldCitationValue(
      raw: json['raw'] as String,
      normalized: json['normalized'],
      display: json['display'] as String,
    );
  }
}

@immutable
class FieldCitation {
  final String documentId;
  final String fieldName;
  final FieldCitationValue value;
  final String valueType;
  final double fieldConfidence;
  final String parserKind;
  final String citeString;
  final double evidenceStrength;
  final int pageNumber;
  final String imageUri;

  const FieldCitation({
    required this.documentId,
    required this.fieldName,
    required this.value,
    required this.valueType,
    required this.fieldConfidence,
    required this.parserKind,
    required this.citeString,
    required this.evidenceStrength,
    required this.pageNumber,
    required this.imageUri,
  });

  /// Human-readable label for the field. The API returns
  /// snake_case field names; the UI uses Title Case.
  String get displayLabel {
    switch (fieldName) {
      case 'policy_number':
        return 'Policy number';
      case 'policy_holder_name':
        return 'Policy holder';
      case 'sum_insured':
        return 'Sum insured';
      case 'policy_start_date':
        return 'Policy start date';
      case 'policy_end_date':
        return 'Policy end date';
      case 'premium_amount':
        return 'Premium';
      case 'insurer_name':
        return 'Insurer';
      case 'room_rent_cap':
        return 'Room rent cap';
      default:
        // Title-case the snake_case fallback. .split(' ')
        // .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        // .join(' ') avoids a Title Case edge case (e.g. "of" still
        // gets capitalized, which is what we want for short field
        // labels).
        return fieldName
            .split('_')
            .where((p) => p.isNotEmpty)
            .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
            .join(' ');
    }
  }

  /// Whether this field is shown in the UI.
  /// evidence_strength < 0.5 means the parser could not
  /// verify the citation; hide it. This mirrors the
  /// v_field_citations view's strongest-evidence filter
  /// on the server side.
  bool get isVisible => evidenceStrength >= 0.5;

  factory FieldCitation.fromJson(Map<String, dynamic> json) {
    return FieldCitation(
      documentId: json['document_id'] as String,
      fieldName: json['field_name'] as String,
      value: FieldCitationValue.fromJson(
        (json['value'] as Map).cast<String, dynamic>(),
      ),
      valueType: json['value_type'] as String,
      fieldConfidence: (json['field_confidence'] as num).toDouble(),
      parserKind: json['parser_kind'] as String,
      citeString: json['cite_string'] as String,
      evidenceStrength: (json['evidence_strength'] as num).toDouble(),
      pageNumber: json['page_number'] as int,
      imageUri: json['image_uri'] as String,
    );
  }
}
