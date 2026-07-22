// Pure helper functions for policy extraction, extracted from
// PolicyExtractionService so they can be unit-tested without
// a Dio or Hive dependency.
//
// Each function is stateless and idempotent — given the same input
// it always returns the same output.

// ---------------------------------------------------------------------------
// Policy-number validation
// ---------------------------------------------------------------------------

/// Result of validating an extracted policy number.
class PolicyNumberValidation {
  /// Whether the value passes all validity checks.
  final bool isValid;

  /// Confidence score 0.0–1.0 for the parsed value.
  final double confidence;

  /// The normalised policy number (stripped of common LLM prefixes).
  final String? normalizedValue;

  /// Human-readable message describing what looks wrong, if invalid.
  final String? validationMessage;

  const PolicyNumberValidation({
    required this.isValid,
    required this.confidence,
    this.normalizedValue,
    this.validationMessage,
  });
}

/// Validates and normalises an extracted policy number.
///
/// Returns a [PolicyNumberValidation] with:
/// - `isValid`      — whether the value looks like a real policy number
/// - `confidence`   — 0.0–1.0 how confident we are in the value
/// - `normalizedValue` — cleaned version, or `null` if clearly junk
/// - `validationMessage` — explanation when invalid
PolicyNumberValidation validatePolicyNumber(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const PolicyNumberValidation(
      isValid: false,
      confidence: 0.0,
      validationMessage: 'No policy number extracted.',
    );
  }

  final cleaned = raw.trim();

  // Reject obvious LLM hallucinations
  if (_isObviousJunk(cleaned)) {
    return PolicyNumberValidation(
      isValid: false,
      confidence: 0.0,
      normalizedValue: null,
      validationMessage: 'Extracted value "$cleaned" does not look like '
          'a real policy number.',
    );
  }

  // Heuristic scoring
  double score = 0.5; // Start at neutral

  // Length: most Indian policy numbers are 8–30 characters
  if (cleaned.length >= 8 && cleaned.length <= 30) {
    score += 0.25;
  } else if (cleaned.length < 6) {
    score -= 0.25;
  }

  // Contains digits (all policy numbers do)
  final digitCount = cleaned.codeUnits.where((c) => c >= 48 && c <= 57).length;
  if (digitCount >= 4) {
    score += 0.15;
  } else if (digitCount < 1) {
    score -= 0.3; // No digits at all = suspicious
  }

  // Contains at least some non-digit characters
  final alphaCount = cleaned.codeUnits
      .where((c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122))
      .length;
  if (alphaCount >= 2) {
    score += 0.1; // Mixed alpha-numeric is more realistic
  }

  // Common Indian insurer prefixes boost confidence
  const prefixes = [
    'POL',
    'POLICY',
    '41',
    '4214',
    'HC',
    'HLT',
    'MOT',
    'AUT',
    'LIF',
    'TRV',
    'HOM',
  ];
  if (prefixes.any((p) => cleaned.toUpperCase().startsWith(p))) {
    score += 0.15;
  }

  // Normalise: strip common "Policy No:" / "#" prefixes that survive _clean
  var normalised = cleaned;
  final prefixRegex = RegExp(
    r'^(policy\s+(no|number)\s*[:\-#]?\s*'
        r'|policy\s*[#]\s*'
        r'|#)',
    caseSensitive: false,
  );
  normalised = normalised.replaceFirst(prefixRegex, '').trim();

  // If normalisation changed the value, re-check length
  if (normalised != cleaned && normalised.length < 6) {
    score -= 0.15;
  }

  return PolicyNumberValidation(
    isValid: score >= 0.5,
    confidence: score.clamp(0.0, 1.0),
    normalizedValue: normalised.isNotEmpty ? normalised : null,
    validationMessage:
        score < 0.5 ? 'Policy number "$cleaned" looks suspicious.' : null,
  );
}

bool _isObviousJunk(String value) {
  final lower = value.toLowerCase();
  // LLMs sometimes emit these instead of the actual number
  if (lower.contains('not found') ||
      lower.contains('not listed') ||
      lower.contains('n/a') ||
      lower.contains('unknown') ||
      lower.contains('not available') ||
      lower.contains('none')) {
    return true;
  }
  // Single word that is all letters and very short
  if (RegExp(r'^[a-zA-Z]{1,5}$').hasMatch(value)) {
    return true;
  }
  // Clearly not a policy number
  if (RegExp(r'^\d{1,4}$').hasMatch(value)) {
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Text cleaning
// ---------------------------------------------------------------------------

/// Cleans a raw answer string from the LLM: trims whitespace, strips
/// common conversational prefixes ("Answer: the …"), and removes a
/// trailing period.
String cleanText(String? text) {
  if (text == null) return '';
  var cleaned = text.trim();
  // Strip common LLM conversational prefixes like "Answer:" or "The policy number is"
  cleaned = cleaned.replaceAll(
    RegExp(r'^(answer|the policy|the document|it is|it.s)\s*[:\-]?\s+',
        caseSensitive: false),
    '',
  );
  // Also strip bare "the " or "this " that don't have a colon
  cleaned = cleaned.replaceAll(
    RegExp(r'^(the|this|it is|it.s)\s+', caseSensitive: false), '',
  );
  cleaned = cleaned.replaceAll(RegExp(r'\.$'), '');
  return cleaned.trim();
}

/// Extracts the first email address found in [text], or returns `null`
/// when the text says "not listed" / "not available" or contains no email.
String? extractEmail(String? text) {
  if (text == null) return null;
  final cleaned = text.trim().toLowerCase();
  if (cleaned.contains('not listed') ||
      cleaned.contains('not available') ||
      cleaned.isEmpty) {
    return null;
  }
  final emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  final match = emailRegex.firstMatch(cleaned);
  return match?.group(0);
}

// ---------------------------------------------------------------------------
// Amount parsing (Indian units)
// ---------------------------------------------------------------------------

/// Parses an amount string that may contain Indian number units
/// (lakh / L, crore / Cr, thousand / K) and returns the numeric value.
///
/// Examples:
/// - `"5 lakh"` → `500000.0`
/// - `"₹25,00,000"` → `2500000.0`
/// - `"1 Cr"` → `10000000.0`
/// - `"500K"` → `500000.0`
double? parseAmount(String? text) {
  if (text == null || text.isEmpty) return null;
  final lower = text.toLowerCase();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9.]'), '');

  // Extract the numeric part
  final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
  if (numberMatch == null) return null;

  final amount = double.tryParse(numberMatch.group(1)!);
  if (amount == null) return null;

  if (lower.contains('lakh') || lower.contains('lac') || lower.contains('l')) {
    return amount * 100000;
  }
  if (lower.contains('crore') || lower.contains('cr')) {
    return amount * 10000000;
  }
  if (lower.contains('thousand') || lower.contains('k')) {
    return amount * 1000;
  }
  return amount;
}

// ---------------------------------------------------------------------------
// Date parsing
// ---------------------------------------------------------------------------

/// Attempts to parse a date string into a [DateTime] using several common
/// formats.  Returns `null` when parsing fails.
DateTime? parseDate(String? text) {
  if (text == null || text.isEmpty) return null;
  final cleaned = text.trim();

  // Pattern 1: ISO 8601 "2026-03-01" — check this first because the
  // dash/slash pattern below would match "26-03-01" and misinterpret the
  // values (day=26, month=3, year=2001). ISO is unambiguous: YYYY-MM-DD.
  final isoPattern = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
  var match = isoPattern.firstMatch(cleaned);
  if (match != null) {
    try {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    } catch (_) {}
  }

  // Pattern 2: DD-MM-YYYY or DD/MM/YYYY
  final dashSlashPattern = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})');
  match = dashSlashPattern.firstMatch(cleaned);
  if (match != null) {
    try {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    } catch (_) {}
  }

  // Pattern 3: "1 Jan 2026" or "1st January 2026"
  final textMonthPattern = RegExp(
    r'(\d{1,2})(?:st|nd|rd|th)?\s+'
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
    r'jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)'
    r'\s+(\d{4})',
    caseSensitive: false,
  );
  match = textMonthPattern.firstMatch(cleaned);
  if (match != null) {
    try {
      final day = int.parse(match.group(1)!);
      const monthMap = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final month = monthMap[match.group(2)!.toLowerCase().substring(0, 3)] ?? 1;
      final year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    } catch (_) {}
  }

  return null;
}

// ---------------------------------------------------------------------------
// Line splitting
// ---------------------------------------------------------------------------

/// Splits a multi-line or bullet-delimited string into a list of trimmed,
/// non-empty lines, capped at 10 entries.
List<String> splitLines(String? text) {
  if (text == null || text.isEmpty) return [];
  return text
      .split(RegExp(r'[\n•\-]\s*'))
      .map((s) => s.trim())
      .where((s) => s.length > 3)
      .take(10)
      .toList();
}

// ---------------------------------------------------------------------------
// Field confidence
// ---------------------------------------------------------------------------

/// Returns a confidence score (0.0–1.0) for a given extraction field based
/// on the presence and quality of the extracted value.
///
/// Known field names: `policyNumber`, `insurer`, `coverageAmount`,
/// `premiumAmount`, `deductible`, `startDate`, `endDate`, `helpline`,
/// `email`, `benefits`, `exclusions`, `waitingPeriods`.
double fieldConfidence(String field, String? value) {
  if (value == null || value.isEmpty) return 0.0;

  switch (field) {
    case 'policyNumber':
      return validatePolicyNumber(value).confidence;
    case 'insurer':
      // Most Indian insurer names are 10+ characters
      if (value.length >= 10) return 0.9;
      if (value.length >= 5) return 0.6;
      return 0.3;
    case 'coverageAmount':
    case 'premiumAmount':
    case 'deductible':
      final parsed = parseAmount(value);
      if (parsed == null) return 0.0;
      if (parsed > 0) return 0.9;
      return 0.4;
    case 'startDate':
    case 'endDate':
      final parsed = parseDate(value);
      if (parsed == null) return 0.0;
      // A date in a reasonable range (2000–2100) is high confidence
      if (parsed.year >= 2000 && parsed.year <= 2100) return 0.95;
      return 0.6;
    case 'helpline':
      // Phone number validation: at least 8 digits
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8) return 0.9;
      if (digits.length >= 5) return 0.5;
      return 0.2;
    case 'email':
      final email = extractEmail(value);
      if (email != null) return 0.95;
      return 0.1;
    case 'benefits':
    case 'exclusions':
    case 'waitingPeriods':
      final lines = splitLines(value);
      if (lines.length >= 3) return 0.85;
      if (lines.isNotEmpty) return 0.6;
      return 0.3;
    default:
      return 0.5;
  }
}

/// Returns an overall extraction confidence (0.0–1.0) across all fields.
double overallExtractionConfidence(Map<String, String?> extractedFields) {
  if (extractedFields.isEmpty) return 0.0;
  double total = 0.0;
  for (final entry in extractedFields.entries) {
    total += fieldConfidence(entry.key, entry.value);
  }
  return total / extractedFields.length;
}
