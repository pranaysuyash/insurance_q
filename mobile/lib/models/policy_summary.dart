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
  // Type-specific fields — populated only when documentType matches
  final MotorPolicyFields? motorFields;
  final TravelPolicyFields? travelFields;
  final LifePolicyFields? lifeFields;
  final HomePolicyFields? homeFields;
  final HealthPolicyFields? healthFields;
  final MarinePolicyFields? marineFields;
  final CyberPolicyFields? cyberFields;
  final LiabilityPolicyFields? liabilityFields;
  final PetPolicyFields? petFields;

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
    this.motorFields,
    this.travelFields,
    this.lifeFields,
    this.homeFields,
    this.healthFields,
    this.marineFields,
    this.cyberFields,
    this.liabilityFields,
    this.petFields,
  });

  bool get isActive => endDate != null && endDate!.isAfter(DateTime.now());

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
        'motor_fields': motorFields?.toJson(),
        'travel_fields': travelFields?.toJson(),
        'life_fields': lifeFields?.toJson(),
        'home_fields': homeFields?.toJson(),
        'health_fields': healthFields?.toJson(),
        'marine_fields': marineFields?.toJson(),
        'cyber_fields': cyberFields?.toJson(),
        'liability_fields': liabilityFields?.toJson(),
        'pet_fields': petFields?.toJson(),
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
        exclusions:
            (json['exclusions'] as List?)?.map((e) => e.toString()).toList() ??
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
        motorFields: json['motor_fields'] != null
            ? MotorPolicyFields.fromJson(
                json['motor_fields'] as Map<String, dynamic>)
            : null,
        travelFields: json['travel_fields'] != null
            ? TravelPolicyFields.fromJson(
                json['travel_fields'] as Map<String, dynamic>)
            : null,
        lifeFields: json['life_fields'] != null
            ? LifePolicyFields.fromJson(
                json['life_fields'] as Map<String, dynamic>)
            : null,
        homeFields: json['home_fields'] != null
            ? HomePolicyFields.fromJson(
                json['home_fields'] as Map<String, dynamic>)
            : null,
        healthFields: json['health_fields'] != null
            ? HealthPolicyFields.fromJson(
                json['health_fields'] as Map<String, dynamic>)
            : null,
        marineFields: json['marine_fields'] != null
            ? MarinePolicyFields.fromJson(
                json['marine_fields'] as Map<String, dynamic>)
            : null,
        cyberFields: json['cyber_fields'] != null
            ? CyberPolicyFields.fromJson(
                json['cyber_fields'] as Map<String, dynamic>)
            : null,
        liabilityFields: json['liability_fields'] != null
            ? LiabilityPolicyFields.fromJson(
                json['liability_fields'] as Map<String, dynamic>)
            : null,
        petFields: json['pet_fields'] != null
            ? PetPolicyFields.fromJson(
                json['pet_fields'] as Map<String, dynamic>)
            : null,
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
    MotorPolicyFields? motorFields,
    TravelPolicyFields? travelFields,
    LifePolicyFields? lifeFields,
    HomePolicyFields? homeFields,
    HealthPolicyFields? healthFields,
    MarinePolicyFields? marineFields,
    CyberPolicyFields? cyberFields,
    LiabilityPolicyFields? liabilityFields,
    PetPolicyFields? petFields,
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
      motorFields: motorFields ?? this.motorFields,
      travelFields: travelFields ?? this.travelFields,
      lifeFields: lifeFields ?? this.lifeFields,
      homeFields: homeFields ?? this.homeFields,
      healthFields: healthFields ?? this.healthFields,
      marineFields: marineFields ?? this.marineFields,
      cyberFields: cyberFields ?? this.cyberFields,
      liabilityFields: liabilityFields ?? this.liabilityFields,
      petFields: petFields ?? this.petFields,
      extractedAt: DateTime.now(),
    );
  }
}

/// Type-specific fields for life insurance policies.
///
/// Populated only when documentType classifies as PolicyType.life.
class LifePolicyFields {
  final String? lifeAssuredName;
  final double? sumAssured;
  final int? policyTermYears;
  final int? premiumPayingTermYears;
  final String? nomineeName;
  final String? nomineeShare;
  final String? maturityDate;
  final double? maturityAmount;
  final double? accidentalDeathBenefit;
  final String? terminalIllnessBenefit;
  final List<String> riderDetails;
  final String? suicideExclusion;
  final String? freeLookPeriod;
  final String? gracePeriod;
  final String? surrenderValue;
  final String? deathBenefitType;
  final String? policyTypeDetail;

  const LifePolicyFields({
    this.lifeAssuredName,
    this.sumAssured,
    this.policyTermYears,
    this.premiumPayingTermYears,
    this.nomineeName,
    this.nomineeShare,
    this.maturityDate,
    this.maturityAmount,
    this.accidentalDeathBenefit,
    this.terminalIllnessBenefit,
    this.riderDetails = const [],
    this.suicideExclusion,
    this.freeLookPeriod,
    this.gracePeriod,
    this.surrenderValue,
    this.deathBenefitType,
    this.policyTypeDetail,
  });

  Map<String, dynamic> toJson() => {
        'life_assured_name': lifeAssuredName,
        'sum_assured': sumAssured,
        'policy_term_years': policyTermYears,
        'premium_paying_term_years': premiumPayingTermYears,
        'nominee_name': nomineeName,
        'nominee_share': nomineeShare,
        'maturity_date': maturityDate,
        'maturity_amount': maturityAmount,
        'accidental_death_benefit': accidentalDeathBenefit,
        'terminal_illness_benefit': terminalIllnessBenefit,
        'rider_details': riderDetails,
        'suicide_exclusion': suicideExclusion,
        'free_look_period': freeLookPeriod,
        'grace_period': gracePeriod,
        'surrender_value': surrenderValue,
        'death_benefit_type': deathBenefitType,
        'policy_type_detail': policyTypeDetail,
      };

  factory LifePolicyFields.fromJson(Map<String, dynamic> json) =>
      LifePolicyFields(
        lifeAssuredName: json['life_assured_name']?.toString(),
        sumAssured: (json['sum_assured'] as num?)?.toDouble(),
        policyTermYears: (json['policy_term_years'] as num?)?.toInt(),
        premiumPayingTermYears:
            (json['premium_paying_term_years'] as num?)?.toInt(),
        nomineeName: json['nominee_name']?.toString(),
        nomineeShare: json['nominee_share']?.toString(),
        maturityDate: json['maturity_date']?.toString(),
        maturityAmount: (json['maturity_amount'] as num?)?.toDouble(),
        accidentalDeathBenefit:
            (json['accidental_death_benefit'] as num?)?.toDouble(),
        terminalIllnessBenefit: json['terminal_illness_benefit']?.toString(),
        riderDetails: (json['rider_details'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        suicideExclusion: json['suicide_exclusion']?.toString(),
        freeLookPeriod: json['free_look_period']?.toString(),
        gracePeriod: json['grace_period']?.toString(),
        surrenderValue: json['surrender_value']?.toString(),
        deathBenefitType: json['death_benefit_type']?.toString(),
        policyTypeDetail: json['policy_type_detail']?.toString(),
      );

  bool get hasAnyFields =>
      lifeAssuredName != null ||
      sumAssured != null ||
      policyTermYears != null ||
      premiumPayingTermYears != null ||
      nomineeName != null ||
      nomineeShare != null ||
      maturityDate != null ||
      maturityAmount != null ||
      accidentalDeathBenefit != null ||
      terminalIllnessBenefit != null ||
      riderDetails.isNotEmpty ||
      suicideExclusion != null ||
      freeLookPeriod != null ||
      gracePeriod != null ||
      surrenderValue != null ||
      deathBenefitType != null ||
      policyTypeDetail != null;
}

/// Type-specific fields for travel insurance policies.
///
/// Populated only when documentType classifies as PolicyType.travel.
class TravelPolicyFields {
  final String? travellerName;
  final String? destination;
  final int? tripDurationDays;
  final String? tripStartDate;
  final String? tripEndDate;
  final String? tripType;
  final double? tripCostCovered;
  final double? medicalExpensesCover;
  final double? medicalEvacuationCover;
  final double? personalAccidentCover;
  final double? baggageLossCover;
  final double? baggageDelayCover;
  final double? tripCancellationCover;
  final double? flightDelayCover;
  final List<String> addOnCovers;
  final String? emergencyAssistancePhone;
  final String? geographicalZone;
  final String? preexistingConditionWaiver;
  final String? adventureSportsCover;
  final String? hijackCover;
  final String? passportLossCover;
  final double? deductiblePerClaimTravel;

  const TravelPolicyFields({
    this.travellerName,
    this.destination,
    this.tripDurationDays,
    this.tripStartDate,
    this.tripEndDate,
    this.tripType,
    this.tripCostCovered,
    this.medicalExpensesCover,
    this.medicalEvacuationCover,
    this.personalAccidentCover,
    this.baggageLossCover,
    this.baggageDelayCover,
    this.tripCancellationCover,
    this.flightDelayCover,
    this.addOnCovers = const [],
    this.emergencyAssistancePhone,
    this.geographicalZone,
    this.preexistingConditionWaiver,
    this.adventureSportsCover,
    this.hijackCover,
    this.passportLossCover,
    this.deductiblePerClaimTravel,
  });

  Map<String, dynamic> toJson() => {
        'traveller_name': travellerName,
        'destination': destination,
        'trip_duration_days': tripDurationDays,
        'trip_start_date': tripStartDate,
        'trip_end_date': tripEndDate,
        'trip_type': tripType,
        'trip_cost_covered': tripCostCovered,
        'medical_expenses_cover': medicalExpensesCover,
        'medical_evacuation_cover': medicalEvacuationCover,
        'personal_accident_cover': personalAccidentCover,
        'baggage_loss_cover': baggageLossCover,
        'baggage_delay_cover': baggageDelayCover,
        'trip_cancellation_cover': tripCancellationCover,
        'flight_delay_cover': flightDelayCover,
        'add_on_covers': addOnCovers,
        'emergency_assistance_phone': emergencyAssistancePhone,
        'geographical_zone': geographicalZone,
        'preexisting_condition_waiver': preexistingConditionWaiver,
        'adventure_sports_cover': adventureSportsCover,
        'hijack_cover': hijackCover,
        'passport_loss_cover': passportLossCover,
        'deductible_per_claim_travel': deductiblePerClaimTravel,
      };

  factory TravelPolicyFields.fromJson(Map<String, dynamic> json) =>
      TravelPolicyFields(
        travellerName: json['traveller_name']?.toString(),
        destination: json['destination']?.toString(),
        tripDurationDays: (json['trip_duration_days'] as num?)?.toInt(),
        tripStartDate: json['trip_start_date']?.toString(),
        tripEndDate: json['trip_end_date']?.toString(),
        tripType: json['trip_type']?.toString(),
        tripCostCovered: (json['trip_cost_covered'] as num?)?.toDouble(),
        medicalExpensesCover: (json['medical_expenses_cover'] as num?)?.toDouble(),
        medicalEvacuationCover: (json['medical_evacuation_cover'] as num?)?.toDouble(),
        personalAccidentCover: (json['personal_accident_cover'] as num?)?.toDouble(),
        baggageLossCover: (json['baggage_loss_cover'] as num?)?.toDouble(),
        baggageDelayCover: (json['baggage_delay_cover'] as num?)?.toDouble(),
        tripCancellationCover: (json['trip_cancellation_cover'] as num?)?.toDouble(),
        flightDelayCover: (json['flight_delay_cover'] as num?)?.toDouble(),
        addOnCovers: (json['add_on_covers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        emergencyAssistancePhone: json['emergency_assistance_phone']?.toString(),
        geographicalZone: json['geographical_zone']?.toString(),
        preexistingConditionWaiver: json['preexisting_condition_waiver']?.toString(),
        adventureSportsCover: json['adventure_sports_cover']?.toString(),
        hijackCover: json['hijack_cover']?.toString(),
        passportLossCover: json['passport_loss_cover']?.toString(),
        deductiblePerClaimTravel: (json['deductible_per_claim_travel'] as num?)?.toDouble(),
      );

  bool get hasAnyFields =>
      travellerName != null ||
      destination != null ||
      tripDurationDays != null ||
      tripType != null ||
      tripCostCovered != null ||
      medicalExpensesCover != null ||
      medicalEvacuationCover != null ||
      personalAccidentCover != null ||
      baggageLossCover != null ||
      baggageDelayCover != null ||
      tripCancellationCover != null ||
      flightDelayCover != null ||
      addOnCovers.isNotEmpty ||
      emergencyAssistancePhone != null ||
      geographicalZone != null ||
      preexistingConditionWaiver != null ||
      adventureSportsCover != null ||
      hijackCover != null ||
      passportLossCover != null ||
      deductiblePerClaimTravel != null;
}

/// Type-specific fields for home / property insurance policies.
///
/// Populated only when documentType classifies as PolicyType.home.
class HomePolicyFields {
  final String? propertyAddress;
  final double? buildingSumInsured;
  final double? contentsSumInsured;
  final double? rebuildCost;
  final List<String> perilsCovered;
  final List<String> perilsExcluded;
  final List<String> addOnCovers;
  final double? deductible;
  final String? structureType;
  final String? policyType;
  final String? occupancyType;
  final String? constructionType;
  final String? underinsuranceClause;
  final int? yearBuilt;
  final String? escalationClause;

  const HomePolicyFields({
    this.propertyAddress,
    this.buildingSumInsured,
    this.contentsSumInsured,
    this.rebuildCost,
    this.perilsCovered = const [],
    this.perilsExcluded = const [],
    this.addOnCovers = const [],
    this.deductible,
    this.structureType,
    this.policyType,
    this.occupancyType,
    this.constructionType,
    this.underinsuranceClause,
    this.yearBuilt,
    this.escalationClause,
  });

  Map<String, dynamic> toJson() => {
        'property_address': propertyAddress,
        'building_sum_insured': buildingSumInsured,
        'contents_sum_insured': contentsSumInsured,
        'rebuild_cost': rebuildCost,
        'perils_covered': perilsCovered,
        'perils_excluded': perilsExcluded,
        'add_on_covers': addOnCovers,
        'deductible': deductible,
        'structure_type': structureType,
        'policy_type': policyType,
        'occupancy_type': occupancyType,
        'construction_type': constructionType,
        'underinsurance_clause': underinsuranceClause,
        'year_built': yearBuilt,
        'escalation_clause': escalationClause,
      };

  factory HomePolicyFields.fromJson(Map<String, dynamic> json) =>
      HomePolicyFields(
        propertyAddress: json['property_address']?.toString(),
        buildingSumInsured: (json['building_sum_insured'] as num?)?.toDouble(),
        contentsSumInsured: (json['contents_sum_insured'] as num?)?.toDouble(),
        rebuildCost: (json['rebuild_cost'] as num?)?.toDouble(),
        perilsCovered: (json['perils_covered'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        perilsExcluded: (json['perils_excluded'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        addOnCovers: (json['add_on_covers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        deductible: (json['deductible'] as num?)?.toDouble(),
        structureType: json['structure_type']?.toString(),
        policyType: json['policy_type']?.toString(),
        occupancyType: json['occupancy_type']?.toString(),
        constructionType: json['construction_type']?.toString(),
        underinsuranceClause: json['underinsurance_clause']?.toString(),
        yearBuilt: (json['year_built'] as num?)?.toInt(),
        escalationClause: json['escalation_clause']?.toString(),
      );

  bool get hasAnyFields =>
      propertyAddress != null ||
      buildingSumInsured != null ||
      contentsSumInsured != null ||
      rebuildCost != null ||
      perilsCovered.isNotEmpty ||
      perilsExcluded.isNotEmpty ||
      addOnCovers.isNotEmpty ||
      deductible != null ||
      structureType != null ||
      policyType != null ||
      occupancyType != null ||
      constructionType != null ||
      underinsuranceClause != null ||
      yearBuilt != null ||
      escalationClause != null;
}

/// Type-specific fields for health insurance policies.
///
/// Populated only when documentType classifies as PolicyType.health.
class HealthPolicyFields {
  final String? roomRentCap;
  final List<String> preExistingDiseases;
  final double? coPayPercent;
  final String? networkHospitals;
  final String? maternityCover;
  final double? deductiblePerClaim;
  final String? cumulativeBonus;
  final String? dayCareProcedures;
  final String? consumablesCover;
  final double? ambulanceCover;
  final String? healthCheckupCover;
  final String? prePostHospitalizationDays;
  final String? restorationBenefit;
  final List<String> criticalIllnessList;
  final String? modernTreatmentCover;
  final String? moratoriumPeriod;
  final String? preAuthTimeLimit;
  final String? domiciliaryHospitalization;
  final List<String> subLimits;
  final double? noClaimBonusPercent;

  const HealthPolicyFields({
    this.roomRentCap,
    this.preExistingDiseases = const [],
    this.coPayPercent,
    this.networkHospitals,
    this.maternityCover,
    this.deductiblePerClaim,
    this.cumulativeBonus,
    this.dayCareProcedures,
    this.consumablesCover,
    this.ambulanceCover,
    this.healthCheckupCover,
    this.prePostHospitalizationDays,
    this.restorationBenefit,
    this.criticalIllnessList = const [],
    this.modernTreatmentCover,
    this.moratoriumPeriod,
    this.preAuthTimeLimit,
    this.domiciliaryHospitalization,
    this.subLimits = const [],
    this.noClaimBonusPercent,
  });

  Map<String, dynamic> toJson() => {
        'room_rent_cap': roomRentCap,
        'pre_existing_diseases': preExistingDiseases,
        'co_pay_percent': coPayPercent,
        'network_hospitals': networkHospitals,
        'maternity_cover': maternityCover,
        'deductible_per_claim': deductiblePerClaim,
        'cumulative_bonus': cumulativeBonus,
        'day_care_procedures': dayCareProcedures,
        'consumables_cover': consumablesCover,
        'ambulance_cover': ambulanceCover,
        'health_checkup_cover': healthCheckupCover,
        'pre_post_hospitalization_days': prePostHospitalizationDays,
        'restoration_benefit': restorationBenefit,
        'critical_illness_list': criticalIllnessList,
        'modern_treatment_cover': modernTreatmentCover,
        'moratorium_period': moratoriumPeriod,
        'pre_auth_time_limit': preAuthTimeLimit,
        'domiciliary_hospitalization': domiciliaryHospitalization,
        'sub_limits': subLimits,
        'no_claim_bonus_percent': noClaimBonusPercent,
      };

  factory HealthPolicyFields.fromJson(Map<String, dynamic> json) =>
      HealthPolicyFields(
        roomRentCap: json['room_rent_cap']?.toString(),
        preExistingDiseases: (json['pre_existing_diseases'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        coPayPercent: (json['co_pay_percent'] as num?)?.toDouble(),
        networkHospitals: json['network_hospitals']?.toString(),
        maternityCover: json['maternity_cover']?.toString(),
        deductiblePerClaim: (json['deductible_per_claim'] as num?)?.toDouble(),
        cumulativeBonus: json['cumulative_bonus']?.toString(),
        dayCareProcedures: json['day_care_procedures']?.toString(),
        consumablesCover: json['consumables_cover']?.toString(),
        ambulanceCover: (json['ambulance_cover'] as num?)?.toDouble(),
        healthCheckupCover: json['health_checkup_cover']?.toString(),
        prePostHospitalizationDays:
            json['pre_post_hospitalization_days']?.toString(),
        restorationBenefit: json['restoration_benefit']?.toString(),
        criticalIllnessList: (json['critical_illness_list'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        modernTreatmentCover: json['modern_treatment_cover']?.toString(),
        moratoriumPeriod: json['moratorium_period']?.toString(),
        preAuthTimeLimit: json['pre_auth_time_limit']?.toString(),
        domiciliaryHospitalization:
            json['domiciliary_hospitalization']?.toString(),
        subLimits: (json['sub_limits'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        noClaimBonusPercent:
            (json['no_claim_bonus_percent'] as num?)?.toDouble(),
      );

  bool get hasAnyFields =>
      roomRentCap != null ||
      preExistingDiseases.isNotEmpty ||
      coPayPercent != null ||
      networkHospitals != null ||
      maternityCover != null ||
      deductiblePerClaim != null ||
      cumulativeBonus != null ||
      dayCareProcedures != null ||
      consumablesCover != null ||
      ambulanceCover != null ||
      healthCheckupCover != null ||
      prePostHospitalizationDays != null ||
      restorationBenefit != null ||
      criticalIllnessList.isNotEmpty ||
      modernTreatmentCover != null ||
      moratoriumPeriod != null ||
      preAuthTimeLimit != null ||
      domiciliaryHospitalization != null ||
      subLimits.isNotEmpty ||
      noClaimBonusPercent != null;
}

/// Type-specific fields for motor/auto insurance policies.
///
/// Populated only when documentType classifies as PolicyType.auto.
/// All fields are optional since extraction completeness varies.
class MotorPolicyFields {
  final String? vehicleRegistrationNumber;
  final String? vin;
  final String? engineNumber;
  final double? ncbPercent;
  final double? idv;
  final String? vehicleMakeModel;
  final int? vehicleYear;
  final List<String> addOnCovers;
  final double? ownDamagePremium;
  final double? thirdPartyPremium;
  final String? policyTypeDetail;
  final String? geographicalLimit;
  final double? personalAccidentCoverOwner;
  final String? cubicCapacity;
  final int? seatingCapacity;
  final String? garagingPincode;
  final String? fuelType;
  final String? voluntaryDeductible;
  final String? hypothecation;

  const MotorPolicyFields({
    this.vehicleRegistrationNumber,
    this.vin,
    this.engineNumber,
    this.ncbPercent,
    this.idv,
    this.vehicleMakeModel,
    this.vehicleYear,
    this.addOnCovers = const [],
    this.ownDamagePremium,
    this.thirdPartyPremium,
    this.policyTypeDetail,
    this.geographicalLimit,
    this.personalAccidentCoverOwner,
    this.cubicCapacity,
    this.seatingCapacity,
    this.garagingPincode,
    this.fuelType,
    this.voluntaryDeductible,
    this.hypothecation,
  });

  Map<String, dynamic> toJson() => {
        'vehicle_registration_number': vehicleRegistrationNumber,
        'vin': vin,
        'engine_number': engineNumber,
        'ncb_percent': ncbPercent,
        'idv': idv,
        'vehicle_make_model': vehicleMakeModel,
        'vehicle_year': vehicleYear,
        'add_on_covers': addOnCovers,
        'own_damage_premium': ownDamagePremium,
        'third_party_premium': thirdPartyPremium,
        'policy_type_detail': policyTypeDetail,
        'geographical_limit': geographicalLimit,
        'personal_accident_cover_owner': personalAccidentCoverOwner,
        'cubic_capacity': cubicCapacity,
        'seating_capacity': seatingCapacity,
        'garaging_pincode': garagingPincode,
        'fuel_type': fuelType,
        'voluntary_deductible': voluntaryDeductible,
        'hypothecation': hypothecation,
      };

  factory MotorPolicyFields.fromJson(Map<String, dynamic> json) =>
      MotorPolicyFields(
        vehicleRegistrationNumber: json['vehicle_registration_number']?.toString(),
        vin: json['vin']?.toString(),
        engineNumber: json['engine_number']?.toString(),
        ncbPercent: (json['ncb_percent'] as num?)?.toDouble(),
        idv: (json['idv'] as num?)?.toDouble(),
        vehicleMakeModel: json['vehicle_make_model']?.toString(),
        vehicleYear: (json['vehicle_year'] as num?)?.toInt(),
        addOnCovers: (json['add_on_covers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        ownDamagePremium: (json['own_damage_premium'] as num?)?.toDouble(),
        thirdPartyPremium: (json['third_party_premium'] as num?)?.toDouble(),
        policyTypeDetail: json['policy_type_detail']?.toString(),
        geographicalLimit: json['geographical_limit']?.toString(),
        personalAccidentCoverOwner: (json['personal_accident_cover_owner'] as num?)?.toDouble(),
        cubicCapacity: json['cubic_capacity']?.toString(),
        seatingCapacity: (json['seating_capacity'] as num?)?.toInt(),
        garagingPincode: json['garaging_pincode']?.toString(),
        fuelType: json['fuel_type']?.toString(),
        voluntaryDeductible: json['voluntary_deductible']?.toString(),
        hypothecation: json['hypothecation']?.toString(),
      );

  bool get hasAnyFields =>
      vehicleRegistrationNumber != null ||
      vin != null ||
      engineNumber != null ||
      ncbPercent != null ||
      idv != null ||
      vehicleMakeModel != null ||
      vehicleYear != null ||
      addOnCovers.isNotEmpty ||
      ownDamagePremium != null ||
      thirdPartyPremium != null ||
      policyTypeDetail != null ||
      geographicalLimit != null ||
      personalAccidentCoverOwner != null ||
      cubicCapacity != null ||
      seatingCapacity != null ||
      garagingPincode != null ||
      fuelType != null ||
      voluntaryDeductible != null ||
      hypothecation != null;
}

/// Type-specific fields for marine / cargo insurance policies.
///
/// Populated only when documentType classifies as PolicyType.marine.
class MarinePolicyFields {
  final String? policyTypeMarine;
  final String? vesselName;
  final String? voyageDetails;
  final String? cargoDescription;
  final String? cargoValue;
  final String? incoterms;
  final String? instituteClauses;
  final String? voyageFrom;
  final String? voyageTo;
  final String? transitStartDate;
  final String? transitEndDate;
  final String? conveyance;
  final String? generalAverageClause;
  final String? warRiskClause;
  final String? strikesRiotsClause;
  final String? warehouseToWarehouse;
  final String? marineInsuranceCertificateNo;

  const MarinePolicyFields({
    this.policyTypeMarine,
    this.vesselName,
    this.voyageDetails,
    this.cargoDescription,
    this.cargoValue,
    this.incoterms,
    this.instituteClauses,
    this.voyageFrom,
    this.voyageTo,
    this.transitStartDate,
    this.transitEndDate,
    this.conveyance,
    this.generalAverageClause,
    this.warRiskClause,
    this.strikesRiotsClause,
    this.warehouseToWarehouse,
    this.marineInsuranceCertificateNo,
  });

  Map<String, dynamic> toJson() => {
        'policy_type_marine': policyTypeMarine,
        'vessel_name': vesselName,
        'voyage_details': voyageDetails,
        'cargo_description': cargoDescription,
        'cargo_value': cargoValue,
        'incoterms': incoterms,
        'institute_clauses': instituteClauses,
        'voyage_from': voyageFrom,
        'voyage_to': voyageTo,
        'transit_start_date': transitStartDate,
        'transit_end_date': transitEndDate,
        'conveyance': conveyance,
        'general_average_clause': generalAverageClause,
        'war_risk_clause': warRiskClause,
        'strikes_riots_clause': strikesRiotsClause,
        'warehouse_to_warehouse': warehouseToWarehouse,
        'marine_insurance_certificate_no': marineInsuranceCertificateNo,
      };

  factory MarinePolicyFields.fromJson(Map<String, dynamic> json) =>
      MarinePolicyFields(
        policyTypeMarine: json['policy_type_marine']?.toString(),
        vesselName: json['vessel_name']?.toString(),
        voyageDetails: json['voyage_details']?.toString(),
        cargoDescription: json['cargo_description']?.toString(),
        cargoValue: json['cargo_value']?.toString(),
        incoterms: json['incoterms']?.toString(),
        instituteClauses: json['institute_clauses']?.toString(),
        voyageFrom: json['voyage_from']?.toString(),
        voyageTo: json['voyage_to']?.toString(),
        transitStartDate: json['transit_start_date']?.toString(),
        transitEndDate: json['transit_end_date']?.toString(),
        conveyance: json['conveyance']?.toString(),
        generalAverageClause: json['general_average_clause']?.toString(),
        warRiskClause: json['war_risk_clause']?.toString(),
        strikesRiotsClause: json['strikes_riots_clause']?.toString(),
        warehouseToWarehouse: json['warehouse_to_warehouse']?.toString(),
        marineInsuranceCertificateNo:
            json['marine_insurance_certificate_no']?.toString(),
      );

  bool get hasAnyFields =>
      policyTypeMarine != null ||
      vesselName != null ||
      voyageDetails != null ||
      cargoDescription != null ||
      cargoValue != null ||
      incoterms != null ||
      instituteClauses != null ||
      voyageFrom != null ||
      voyageTo != null ||
      transitStartDate != null ||
      transitEndDate != null ||
      conveyance != null ||
      generalAverageClause != null ||
      warRiskClause != null ||
      strikesRiotsClause != null ||
      warehouseToWarehouse != null ||
      marineInsuranceCertificateNo != null;
}

/// Type-specific fields for cyber insurance policies.
///
/// Populated only when documentType classifies as PolicyType.cyber.
class CyberPolicyFields {
  final String? policyTypeCyber;
  final String? coverageType;
  final double? dataBreachResponseCover;
  final double? businessInterruptionCover;
  final double? regulatoryDefenseCover;
  final double? cyberExtortionCover;
  final double? networkSecurityLiability;
  final double? privacyLiability;
  final double? mediaLiability;
  final double? notificationCostCover;
  final double? creditMonitoringCover;
  final double? forensicInvestigationCover;
  final double? annualAggregateLimitCyber;
  final List<String> subLimitsCyber;
  final String? waitingPeriodCyber;
  final String? retroactiveDateCyber;
  final double? deductibleCyber;
  final List<String> insuredEntities;
  final List<String> excludedSystems;
  final String? regulatoryFinesExcluded;

  const CyberPolicyFields({
    this.policyTypeCyber,
    this.coverageType,
    this.dataBreachResponseCover,
    this.businessInterruptionCover,
    this.regulatoryDefenseCover,
    this.cyberExtortionCover,
    this.networkSecurityLiability,
    this.privacyLiability,
    this.mediaLiability,
    this.notificationCostCover,
    this.creditMonitoringCover,
    this.forensicInvestigationCover,
    this.annualAggregateLimitCyber,
    this.subLimitsCyber = const [],
    this.waitingPeriodCyber,
    this.retroactiveDateCyber,
    this.deductibleCyber,
    this.insuredEntities = const [],
    this.excludedSystems = const [],
    this.regulatoryFinesExcluded,
  });

  Map<String, dynamic> toJson() => {
        'policy_type_cyber': policyTypeCyber,
        'coverage_type': coverageType,
        'data_breach_response_cover': dataBreachResponseCover,
        'business_interruption_cover': businessInterruptionCover,
        'regulatory_defense_cover': regulatoryDefenseCover,
        'cyber_extortion_cover': cyberExtortionCover,
        'network_security_liability': networkSecurityLiability,
        'privacy_liability': privacyLiability,
        'media_liability': mediaLiability,
        'notification_cost_cover': notificationCostCover,
        'credit_monitoring_cover': creditMonitoringCover,
        'forensic_investigation_cover': forensicInvestigationCover,
        'annual_aggregate_limit_cyber': annualAggregateLimitCyber,
        'sub_limits_cyber': subLimitsCyber,
        'waiting_period_cyber': waitingPeriodCyber,
        'retroactive_date_cyber': retroactiveDateCyber,
        'deductible_cyber': deductibleCyber,
        'insured_entities': insuredEntities,
        'excluded_systems': excludedSystems,
        'regulatory_fines_excluded': regulatoryFinesExcluded,
      };

  factory CyberPolicyFields.fromJson(Map<String, dynamic> json) =>
      CyberPolicyFields(
        policyTypeCyber: json['policy_type_cyber']?.toString(),
        coverageType: json['coverage_type']?.toString(),
        dataBreachResponseCover:
            (json['data_breach_response_cover'] as num?)?.toDouble(),
        businessInterruptionCover:
            (json['business_interruption_cover'] as num?)?.toDouble(),
        regulatoryDefenseCover:
            (json['regulatory_defense_cover'] as num?)?.toDouble(),
        cyberExtortionCover:
            (json['cyber_extortion_cover'] as num?)?.toDouble(),
        networkSecurityLiability:
            (json['network_security_liability'] as num?)?.toDouble(),
        privacyLiability: (json['privacy_liability'] as num?)?.toDouble(),
        mediaLiability: (json['media_liability'] as num?)?.toDouble(),
        notificationCostCover:
            (json['notification_cost_cover'] as num?)?.toDouble(),
        creditMonitoringCover:
            (json['credit_monitoring_cover'] as num?)?.toDouble(),
        forensicInvestigationCover:
            (json['forensic_investigation_cover'] as num?)?.toDouble(),
        annualAggregateLimitCyber:
            (json['annual_aggregate_limit_cyber'] as num?)?.toDouble(),
        subLimitsCyber: (json['sub_limits_cyber'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        waitingPeriodCyber: json['waiting_period_cyber']?.toString(),
        retroactiveDateCyber: json['retroactive_date_cyber']?.toString(),
        deductibleCyber: (json['deductible_cyber'] as num?)?.toDouble(),
        insuredEntities: (json['insured_entities'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        excludedSystems: (json['excluded_systems'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        regulatoryFinesExcluded: json['regulatory_fines_excluded']?.toString(),
      );

  bool get hasAnyFields =>
      policyTypeCyber != null ||
      coverageType != null ||
      dataBreachResponseCover != null ||
      businessInterruptionCover != null ||
      regulatoryDefenseCover != null ||
      cyberExtortionCover != null ||
      networkSecurityLiability != null ||
      privacyLiability != null ||
      mediaLiability != null ||
      notificationCostCover != null ||
      creditMonitoringCover != null ||
      forensicInvestigationCover != null ||
      annualAggregateLimitCyber != null ||
      subLimitsCyber.isNotEmpty ||
      waitingPeriodCyber != null ||
      retroactiveDateCyber != null ||
      deductibleCyber != null ||
      insuredEntities.isNotEmpty ||
      excludedSystems.isNotEmpty ||
      regulatoryFinesExcluded != null;
}

/// Type-specific fields for liability insurance policies.
///
/// Populated only when documentType classifies as PolicyType.liability.
class LiabilityPolicyFields {
  final String? policyTypeLiability;
  final double? limitPerOccurrence;
  final double? aggregateLimit;
  final double? deductibleLiability;
  final String? defenseCost;
  final String? coverageTerritory;
  final String? retroactiveDateLiability;
  final String? extendedReportingPeriod;
  final String? insuredProfession;
  final String? priorActsCover;
  final String? pollutionExclusion;
  final String? cyberExclusion;
  final double? contractualLiabilityLimit;
  final bool? defenseOutsideLimits;
  final int? numberOfEmployeesCovered;
  final double? annualRevenue;
  final String? wrongfulActsDefinition;
  final String? sanctionsExclusion;

  const LiabilityPolicyFields({
    this.policyTypeLiability,
    this.limitPerOccurrence,
    this.aggregateLimit,
    this.deductibleLiability,
    this.defenseCost,
    this.coverageTerritory,
    this.retroactiveDateLiability,
    this.extendedReportingPeriod,
    this.insuredProfession,
    this.priorActsCover,
    this.pollutionExclusion,
    this.cyberExclusion,
    this.contractualLiabilityLimit,
    this.defenseOutsideLimits,
    this.numberOfEmployeesCovered,
    this.annualRevenue,
    this.wrongfulActsDefinition,
    this.sanctionsExclusion,
  });

  Map<String, dynamic> toJson() => {
        'policy_type_liability': policyTypeLiability,
        'limit_per_occurrence': limitPerOccurrence,
        'aggregate_limit': aggregateLimit,
        'deductible_liability': deductibleLiability,
        'defense_cost': defenseCost,
        'coverage_territory': coverageTerritory,
        'retroactive_date_liability': retroactiveDateLiability,
        'extended_reporting_period': extendedReportingPeriod,
        'insured_profession': insuredProfession,
        'prior_acts_cover': priorActsCover,
        'pollution_exclusion': pollutionExclusion,
        'cyber_exclusion': cyberExclusion,
        'contractual_liability_limit': contractualLiabilityLimit,
        'defense_outside_limits': defenseOutsideLimits,
        'number_of_employees_covered': numberOfEmployeesCovered,
        'annual_revenue': annualRevenue,
        'wrongful_acts_definition': wrongfulActsDefinition,
        'sanctions_exclusion': sanctionsExclusion,
      };

  factory LiabilityPolicyFields.fromJson(Map<String, dynamic> json) =>
      LiabilityPolicyFields(
        policyTypeLiability: json['policy_type_liability']?.toString(),
        limitPerOccurrence: (json['limit_per_occurrence'] as num?)?.toDouble(),
        aggregateLimit: (json['aggregate_limit'] as num?)?.toDouble(),
        deductibleLiability: (json['deductible_liability'] as num?)?.toDouble(),
        defenseCost: json['defense_cost']?.toString(),
        coverageTerritory: json['coverage_territory']?.toString(),
        retroactiveDateLiability:
            json['retroactive_date_liability']?.toString(),
        extendedReportingPeriod:
            json['extended_reporting_period']?.toString(),
        insuredProfession: json['insured_profession']?.toString(),
        priorActsCover: json['prior_acts_cover']?.toString(),
        pollutionExclusion: json['pollution_exclusion']?.toString(),
        cyberExclusion: json['cyber_exclusion']?.toString(),
        contractualLiabilityLimit:
            (json['contractual_liability_limit'] as num?)?.toDouble(),
        defenseOutsideLimits: json['defense_outside_limits'],
        numberOfEmployeesCovered:
            (json['number_of_employees_covered'] as num?)?.toInt(),
        annualRevenue: (json['annual_revenue'] as num?)?.toDouble(),
        wrongfulActsDefinition: json['wrongful_acts_definition']?.toString(),
        sanctionsExclusion: json['sanctions_exclusion']?.toString(),
      );

  bool get hasAnyFields =>
      policyTypeLiability != null ||
      limitPerOccurrence != null ||
      aggregateLimit != null ||
      deductibleLiability != null ||
      defenseCost != null ||
      coverageTerritory != null ||
      retroactiveDateLiability != null ||
      extendedReportingPeriod != null ||
      insuredProfession != null ||
      priorActsCover != null ||
      pollutionExclusion != null ||
      cyberExclusion != null ||
      contractualLiabilityLimit != null ||
      defenseOutsideLimits != null ||
      numberOfEmployeesCovered != null ||
      annualRevenue != null ||
      wrongfulActsDefinition != null ||
      sanctionsExclusion != null;
}

/// Type-specific fields for pet insurance policies.
///
/// Populated only when documentType classifies as PolicyType.pet.
class PetPolicyFields {
  final String? policyTypePet;
  final String? petName;
  final String? petSpecies;
  final String? petBreed;
  final int? petAgeYears;
  final String? microchipNumber;
  final double? veterinaryFeesCover;
  final double? annualVetFeesLimit;
  final String? consultationFeesCover;
  final String? dentalTreatmentCover;
  final String? hospitalizationCover;
  final String? surgeryCover;
  final String? medicationCover;
  final String? hereditaryConditionsCover;
  final String? chronicConditionsCover;
  final double? thirdPartyLiabilityPet;
  final String? boardingFeesCover;
  final String? advertisingRewardCover;
  final String? theftStrayingCover;
  final String? deathByInjuryCover;
  final String? euthanasiaCover;
  final String? cremationBurialCover;
  final String? waitingPeriodPet;
  final String? ageLimit;
  final double? excessPerClaimPet;
  final String? preExistingConditionsPet;
  final String? annualMultiPetDiscount;
  final String? microchippingRequirement;
  final String? vaccinationRequirement;

  const PetPolicyFields({
    this.policyTypePet,
    this.petName,
    this.petSpecies,
    this.petBreed,
    this.petAgeYears,
    this.microchipNumber,
    this.veterinaryFeesCover,
    this.annualVetFeesLimit,
    this.consultationFeesCover,
    this.dentalTreatmentCover,
    this.hospitalizationCover,
    this.surgeryCover,
    this.medicationCover,
    this.hereditaryConditionsCover,
    this.chronicConditionsCover,
    this.thirdPartyLiabilityPet,
    this.boardingFeesCover,
    this.advertisingRewardCover,
    this.theftStrayingCover,
    this.deathByInjuryCover,
    this.euthanasiaCover,
    this.cremationBurialCover,
    this.waitingPeriodPet,
    this.ageLimit,
    this.excessPerClaimPet,
    this.preExistingConditionsPet,
    this.annualMultiPetDiscount,
    this.microchippingRequirement,
    this.vaccinationRequirement,
  });

  Map<String, dynamic> toJson() => {
        'policy_type_pet': policyTypePet,
        'pet_name': petName,
        'pet_species': petSpecies,
        'pet_breed': petBreed,
        'pet_age_years': petAgeYears,
        'microchip_number': microchipNumber,
        'veterinary_fees_cover': veterinaryFeesCover,
        'annual_vet_fees_limit': annualVetFeesLimit,
        'consultation_fees_cover': consultationFeesCover,
        'dental_treatment_cover': dentalTreatmentCover,
        'hospitalization_cover': hospitalizationCover,
        'surgery_cover': surgeryCover,
        'medication_cover': medicationCover,
        'hereditary_conditions_cover': hereditaryConditionsCover,
        'chronic_conditions_cover': chronicConditionsCover,
        'third_party_liability_pet': thirdPartyLiabilityPet,
        'boarding_fees_cover': boardingFeesCover,
        'advertising_reward_cover': advertisingRewardCover,
        'theft_straying_cover': theftStrayingCover,
        'death_by_injury_cover': deathByInjuryCover,
        'euthanasia_cover': euthanasiaCover,
        'cremation_burial_cover': cremationBurialCover,
        'waiting_period_pet': waitingPeriodPet,
        'age_limit': ageLimit,
        'excess_per_claim_pet': excessPerClaimPet,
        'pre_existing_conditions_pet': preExistingConditionsPet,
        'annual_multi_pet_discount': annualMultiPetDiscount,
        'microchipping_requirement': microchippingRequirement,
        'vaccination_requirement': vaccinationRequirement,
      };

  factory PetPolicyFields.fromJson(Map<String, dynamic> json) =>
      PetPolicyFields(
        policyTypePet: json['policy_type_pet']?.toString(),
        petName: json['pet_name']?.toString(),
        petSpecies: json['pet_species']?.toString(),
        petBreed: json['pet_breed']?.toString(),
        petAgeYears: (json['pet_age_years'] as num?)?.toInt(),
        microchipNumber: json['microchip_number']?.toString(),
        veterinaryFeesCover:
            (json['veterinary_fees_cover'] as num?)?.toDouble(),
        annualVetFeesLimit:
            (json['annual_vet_fees_limit'] as num?)?.toDouble(),
        consultationFeesCover: json['consultation_fees_cover']?.toString(),
        dentalTreatmentCover: json['dental_treatment_cover']?.toString(),
        hospitalizationCover: json['hospitalization_cover']?.toString(),
        surgeryCover: json['surgery_cover']?.toString(),
        medicationCover: json['medication_cover']?.toString(),
        hereditaryConditionsCover:
            json['hereditary_conditions_cover']?.toString(),
        chronicConditionsCover: json['chronic_conditions_cover']?.toString(),
        thirdPartyLiabilityPet:
            (json['third_party_liability_pet'] as num?)?.toDouble(),
        boardingFeesCover: json['boarding_fees_cover']?.toString(),
        advertisingRewardCover: json['advertising_reward_cover']?.toString(),
        theftStrayingCover: json['theft_straying_cover']?.toString(),
        deathByInjuryCover: json['death_by_injury_cover']?.toString(),
        euthanasiaCover: json['euthanasia_cover']?.toString(),
        cremationBurialCover: json['cremation_burial_cover']?.toString(),
        waitingPeriodPet: json['waiting_period_pet']?.toString(),
        ageLimit: json['age_limit']?.toString(),
        excessPerClaimPet: (json['excess_per_claim_pet'] as num?)?.toDouble(),
        preExistingConditionsPet:
            json['pre_existing_conditions_pet']?.toString(),
        annualMultiPetDiscount: json['annual_multi_pet_discount']?.toString(),
        microchippingRequirement:
            json['microchipping_requirement']?.toString(),
        vaccinationRequirement: json['vaccination_requirement']?.toString(),
      );

  bool get hasAnyFields =>
      policyTypePet != null ||
      petName != null ||
      petSpecies != null ||
      petBreed != null ||
      petAgeYears != null ||
      microchipNumber != null ||
      veterinaryFeesCover != null ||
      annualVetFeesLimit != null ||
      consultationFeesCover != null ||
      dentalTreatmentCover != null ||
      hospitalizationCover != null ||
      surgeryCover != null ||
      medicationCover != null ||
      hereditaryConditionsCover != null ||
      chronicConditionsCover != null ||
      thirdPartyLiabilityPet != null ||
      boardingFeesCover != null ||
      advertisingRewardCover != null ||
      theftStrayingCover != null ||
      deathByInjuryCover != null ||
      euthanasiaCover != null ||
      cremationBurialCover != null ||
      waitingPeriodPet != null ||
      ageLimit != null ||
      excessPerClaimPet != null ||
      preExistingConditionsPet != null ||
      annualMultiPetDiscount != null ||
      microchippingRequirement != null ||
      vaccinationRequirement != null;
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

/// Provenance state for a coverage insight.
///
/// `notFoundInWorkspace` deliberately does not mean the user lacks coverage;
/// it only describes what is currently observable in uploaded documents.
abstract final class CoverageEvidenceStatus {
  static const present = 'present';
  static const notFoundInWorkspace = 'not_found_in_workspace';
  static const notVerified = 'not_verified';
  static const conflicting = 'conflicting';
  static const expiring = 'expiring';
  static const expired = 'expired';
}

class CoverageGap {
  final String category;
  final String description;
  final String severity;
  final String evidenceStatus;
  final List<String> sourceDocumentIds;
  final List<String> sourceFieldNames;
  final double? confidence;

  /// Kept for serialized compatibility. New producers should use neutral
  /// review language rather than purchase, rider, or adequacy advice.
  final String? recommendation;

  CoverageGap({
    required this.category,
    required this.description,
    required this.severity,
    this.evidenceStatus = CoverageEvidenceStatus.notVerified,
    this.sourceDocumentIds = const [],
    this.sourceFieldNames = const [],
    this.confidence,
    this.recommendation,
  });

  /// Stable ID for tracking resolution status across sessions.
  /// Uses djb2 hash — shared with the standalone gapId() function.
  String get gapId => _computeGapId(category, description, severity);

  Map<String, dynamic> toJson() => {
        'category': category,
        'description': description,
        'severity': severity,
        'evidence_status': evidenceStatus,
        'source_document_ids': sourceDocumentIds,
        'source_field_names': sourceFieldNames,
        'confidence': confidence,
        'recommendation': recommendation,
      };

  factory CoverageGap.fromJson(Map<String, dynamic> json) => CoverageGap(
        category: json['category'] ?? '',
        description: json['description'] ?? '',
        severity: json['severity'] ?? 'info',
        evidenceStatus:
            json['evidence_status'] ?? CoverageEvidenceStatus.notVerified,
        sourceDocumentIds: (json['source_document_ids'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
        sourceFieldNames: (json['source_field_names'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const [],
        confidence: (json['confidence'] as num?)?.toDouble(),
        recommendation: json['recommendation'],
      );
}

/// Standalone gapId function — computes a stable hash-based ID for a CoverageGap.
/// Delegates to the shared _computeGapId helper (same as CoverageGap.gapId getter).
String gapId(CoverageGap gap) =>
    _computeGapId(gap.category, gap.description, gap.severity);

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
