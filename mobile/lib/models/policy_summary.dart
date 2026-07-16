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
  });

  bool get isActive =>
      endDate != null && endDate!.isAfter(DateTime.now());

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
  /// Uses djb2 hash — must match the standalone gapId() function.
  String get gapId {
    final raw = '$category|$description|$severity';
    var hash = 0;
    for (var i = 0; i < raw.length; i++) {
      hash = ((hash << 5) - hash + raw.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return 'gap_${hash.toRadixString(16)}';
  }

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