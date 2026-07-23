import 'dart:convert';

class PolicySummary {
  final String documentId;
  final String? policyNumber;
  final String? insurer;
  final String? insurerHelpline;
  final String? insurerEmail;
  final String documentType;
  final double? coverageAmount;
  final double? deductible;
  final double? premiumAmount;
  final String? premiumFrequency;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> keyBenefits;
  final List<String> exclusions;
  final List<String> waitingPeriods;
  final List<CoverageItem> coverageItems;
  final DateTime extractedAt;
  final List<String> executiveSummary;

  PolicySummary({
    required this.documentId,
    this.policyNumber,
    this.insurer,
    this.insurerHelpline,
    this.insurerEmail,
    required this.documentType,
    this.coverageAmount,
    this.deductible,
    this.premiumAmount,
    this.premiumFrequency,
    this.startDate,
    this.endDate,
    this.keyBenefits = const [],
    this.exclusions = const [],
    this.waitingPeriods = const [],
    this.coverageItems = const [],
    required this.extractedAt,
    this.executiveSummary = const [],
  });

  bool get isActive =>
      endDate != null && endDate!.isAfter(DateTime.now());

  /// Phase 0 P0-0.4 (trust audit, 2026-07-18): a policy summary must not be
  /// displayed to the user unless it carries a minimum viable set of
  /// critical fields with evidence. The trust audit's NO-GO verdict
  /// explicitly says "Prevent policy summary display when critical
  /// fields lack evidence." Without this guard, the user sees a
  /// summary that looks complete but is actually a partial projection
  /// over an incomplete extraction.
  ///
  /// Critical fields per the trust audit §10.3 (extraction strategy)
  /// and the canonical plan are:
  ///   - policy number  (without it, the user cannot identify the policy)
  ///   - insurer         (without it, the user cannot call/email)
  ///   - document type   (without it, the extraction scope is unknown)
  ///   - start AND end dates (without either, renewal guidance is unsafe)
  ///   - coverage amount OR a non-empty benefits list
  ///     (without either, the "what does this policy cover?" answer is empty)
  bool get hasMinimumViableEvidence {
    if (policyNumber == null || policyNumber!.isEmpty) return false;
    if (insurer == null || insurer!.isEmpty) return false;
    if (documentType.isEmpty || documentType == 'Unknown') return false;
    if (startDate == null || endDate == null) return false;
    if (coverageAmount == null && keyBenefits.isEmpty) return false;
    return true;
  }

  /// Human-readable reason why the summary failed the evidence check.
  /// Returns null when [hasMinimumViableEvidence] is true. The mobile UI
  /// shows this to the user instead of the partial summary, per the
  /// trust audit's P0-0.4.
  String? get missingEvidenceReason {
    if (policyNumber == null || policyNumber!.isEmpty) {
      return 'Policy number not found in this document. Re-upload a clearer copy or check the source.';
    }
    if (insurer == null || insurer!.isEmpty) {
      return 'Insurer name not found in this document. Check the source document and try again.';
    }
    if (documentType.isEmpty || documentType == 'Unknown') {
      return 'Document type could not be determined. The extraction needs a clearer policy page.';
    }
    if (startDate == null) {
      return 'Policy start date not found. The summary is not safe to display without it.';
    }
    if (endDate == null) {
      return 'Policy end date not found. Renewal reminders are unsafe without it.';
    }
    if (coverageAmount == null && keyBenefits.isEmpty) {
      return 'Coverage amount and benefits are both missing. The summary would be empty.';
    }
    return null;
  }

  int get daysUntilExpiry {
    if (endDate == null) return -1;
    return endDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpiringSoon {
    final days = daysUntilExpiry;
    return days >= 0 && days <= 30;
  }

  bool get isExpired => endDate != null && endDate!.isBefore(DateTime.now());

  String get formattedCoverageAmount {
    if (coverageAmount == null) return 'Unknown';
    if (coverageAmount! >= 10000000) {
      return '₹${(coverageAmount! / 10000000).toStringAsFixed(1)} Cr';
    } else if (coverageAmount! >= 100000) {
      return '₹${(coverageAmount! / 100000).toStringAsFixed(1)} L';
    } else if (coverageAmount! >= 1000) {
      return '₹${(coverageAmount! / 1000).toStringAsFixed(0)}K';
    }
    return '₹${coverageAmount!.toStringAsFixed(0)}';
  }

  String get formattedPremium {
    if (premiumAmount == null) return 'Unknown';
    final freq = premiumFrequency != null ? ' / $premiumFrequency' : '';
    if (premiumAmount! >= 100000) {
      return '₹${(premiumAmount! / 100000).toStringAsFixed(1)} L$freq';
    } else if (premiumAmount! >= 1000) {
      return '₹${(premiumAmount! / 1000).toStringAsFixed(1)}K$freq';
    }
    return '₹${premiumAmount!.toStringAsFixed(0)}$freq';
  }

  String get formattedExpiryDate {
    if (endDate == null) return 'Unknown';
    return '${endDate!.day}/${endDate!.month}/${endDate!.year}';
  }

  String get formattedStartDate {
    if (startDate == null) return 'Unknown';
    return '${startDate!.day}/${startDate!.month}/${startDate!.year}';
  }

  Map<String, dynamic> toJson() => {
        'document_id': documentId,
        'policy_number': policyNumber,
        'insurer': insurer,
        'insurer_helpline': insurerHelpline,
        'insurer_email': insurerEmail,
        'document_type': documentType,
        'coverage_amount': coverageAmount,
        'deductible': deductible,
        'premium_amount': premiumAmount,
        'premium_frequency': premiumFrequency,
        // Emit both key sets for backward compatibility:
        // - start_date/end_date: used by older mobile builds and local Hive cache
        // - effective_date/expiration_date: used by the backend extraction model
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'effective_date': startDate?.toIso8601String(),
        'expiration_date': endDate?.toIso8601String(),
        'key_benefits': keyBenefits,
        'exclusions': exclusions,
        'waiting_periods': waitingPeriods,
        'coverage_items': coverageItems.map((c) => c.toJson()).toList(),
        'executive_summary': executiveSummary,
        'extracted_at': extractedAt.toIso8601String(),
      };

  factory PolicySummary.fromJson(Map<String, dynamic> json) => PolicySummary(
        documentId: json['document_id'] ?? '',
        policyNumber: json['policy_number'],
        insurer: json['insurer'],
        insurerHelpline: json['insurer_helpline'],
        insurerEmail: json['insurer_email'],
        documentType: json['document_type'] ?? 'Unknown',
        coverageAmount: (json['coverage_amount'] as num?)?.toDouble(),
        deductible: (json['deductible'] as num?)?.toDouble(),
        premiumAmount: (json['premium_amount'] as num?)?.toDouble(),
        premiumFrequency: json['premium_frequency'],
        // Read both key sets: backend emits effective_date/expiration_date,
        // local Hive cache and the 13-query fallback emit start_date/end_date.
        startDate: (json['start_date'] ?? json['effective_date']) != null
            ? DateTime.parse(json['start_date'] ?? json['effective_date'])
            : null,
        endDate: (json['end_date'] ?? json['expiration_date']) != null
            ? DateTime.parse(json['end_date'] ?? json['expiration_date'])
            : null,
        keyBenefits: (json['key_benefits'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        exclusions: (json['exclusions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        waitingPeriods: (json['waiting_periods'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        coverageItems: (json['coverage_items'] as List?)
                ?.map((c) => CoverageItem.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        executiveSummary: (json['executive_summary'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        extractedAt: json['extracted_at'] != null
            ? DateTime.parse(json['extracted_at'])
            : DateTime.now(),
      );

  String toJsonString() => jsonEncode(toJson());

  factory PolicySummary.fromJsonString(String s) =>
      PolicySummary.fromJson(jsonDecode(s));

  PolicySummary copyWith({
    String? policyNumber,
    String? insurer,
    String? insurerHelpline,
    String? insurerEmail,
    double? coverageAmount,
    double? deductible,
    double? premiumAmount,
    String? premiumFrequency,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? keyBenefits,
    List<String>? exclusions,
    List<String>? waitingPeriods,
    List<CoverageItem>? coverageItems,
    List<String>? executiveSummary,
  }) {
    return PolicySummary(
      documentId: documentId,
      policyNumber: policyNumber ?? this.policyNumber,
      insurer: insurer ?? this.insurer,
      insurerHelpline: insurerHelpline ?? this.insurerHelpline,
      insurerEmail: insurerEmail ?? this.insurerEmail,
      documentType: documentType,
      coverageAmount: coverageAmount ?? this.coverageAmount,
      deductible: deductible ?? this.deductible,
      premiumAmount: premiumAmount ?? this.premiumAmount,
      premiumFrequency: premiumFrequency ?? this.premiumFrequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      keyBenefits: keyBenefits ?? this.keyBenefits,
      exclusions: exclusions ?? this.exclusions,
      waitingPeriods: waitingPeriods ?? this.waitingPeriods,
      coverageItems: coverageItems ?? this.coverageItems,
      executiveSummary: executiveSummary ?? this.executiveSummary,
      extractedAt: DateTime.now(),
    );
  }
}

class CoverageItem {
  final String name;
  final double? limit;
  final String? limitText;
  final bool covered;
  final String? notes;

  CoverageItem({
    required this.name,
    this.limit,
    this.limitText,
    required this.covered,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'limit': limit,
        'limit_text': limitText,
        'covered': covered,
        'notes': notes,
      };

  factory CoverageItem.fromJson(Map<String, dynamic> json) => CoverageItem(
        name: json['name'] ?? '',
        limit: (json['limit'] as num?)?.toDouble(),
        limitText: json['limit_text'],
        covered: json['covered'] ?? false,
        notes: json['notes'],
      );
}

class CoverageGap {
  final String category;
  final String description;
  final String severity;
  final String? recommendation;

  CoverageGap({
    required this.category,
    required this.description,
    required this.severity,
    this.recommendation,
  });

  /// Stable ID for tracking resolution status across sessions.
  /// Uses djb2 hash — shared with the standalone gapId() function.
  String get gapId => _computeGapId(category, description, severity);

  Map<String, dynamic> toJson() => {
        'category': category,
        'description': description,
        'severity': severity,
        'recommendation': recommendation,
      };

  factory CoverageGap.fromJson(Map<String, dynamic> json) => CoverageGap(
        category: json['category'] ?? '',
        description: json['description'] ?? '',
        severity: json['severity'] ?? 'info',
        recommendation: json['recommendation'],
      );
}

/// Standalone gapId function — computes a stable hash-based ID for a CoverageGap.
/// Delegates to the shared _computeGapId helper (same as CoverageGap.gapId getter).
String gapId(CoverageGap gap) => _computeGapId(gap.category, gap.description, gap.severity);

/// Private shared implementation for gapId computation.
String _computeGapId(String category, String description, String severity) {
  final raw = '$category|$description|$severity';
  var hash = 0;
  for (var i = 0; i < raw.length; i++) {
    hash = ((hash << 5) - hash + raw.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return 'gap_${hash.toRadixString(16)}';
}

class ClaimStep {
  final String title;
  final String description;
  final List<String> documents;
  final String? contactInfo;

  ClaimStep({
    required this.title,
    required this.description,
    this.documents = const [],
    this.contactInfo,
  });
}

class ClaimGuide {
  final String incidentType;
  final String title;
  final List<ClaimStep> steps;
  final List<String> requiredDocuments;
  final String? helpline;
  final String? email;
  final String? notes;

  ClaimGuide({
    required this.incidentType,
    required this.title,
    required this.steps,
    required this.requiredDocuments,
    this.helpline,
    this.email,
    this.notes,
  });
}