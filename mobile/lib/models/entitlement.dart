/// Subscription plan tiers for CoverWise monetization.
///
/// Free tier reaches the real "aha" moment — one policy, useful summary,
/// limited Q&A. Plus and Family add household management, higher limits,
/// and premium features. The plan determines what the user can do in the app.
enum PlanTier {
  free('Free', 'Understand one policy'),
  plus('Plus', 'Household policy companion'),
  family('Family', 'Ongoing household management');

  final String displayName;
  final String tagline;

  const PlanTier(this.displayName, this.tagline);
}

/// Defines the limits and features available for each plan tier.
///
/// Limits are test hypotheses from the exploration map, not forecasts.
/// They should be tuned based on real usage data and conversion metrics.
class PlanLimits {
  final int maxPolicies;
  final int maxQuestionsPerMonth;
  final bool allowComparison;
  final bool allowFamilyView;
  final bool allowCloudSync;
  final bool allowEmergencyAccess;
  final bool allowAnnualReview;
  final bool allowAdvancedSearch;
  final String priceMonthly;
  final String priceYearly;

  const PlanLimits({
    required this.maxPolicies,
    required this.maxQuestionsPerMonth,
    required this.allowComparison,
    required this.allowFamilyView,
    required this.allowCloudSync,
    required this.allowEmergencyAccess,
    required this.allowAnnualReview,
    required this.allowAdvancedSearch,
    required this.priceMonthly,
    required this.priceYearly,
  });
}

/// Central registry of plan limits. Add new tiers or adjust limits here.
const Map<PlanTier, PlanLimits> planLimits = {
  PlanTier.free: PlanLimits(
    maxPolicies: 1,
    maxQuestionsPerMonth: 20,
    allowComparison: false,
    allowFamilyView: false,
    allowCloudSync: false,
    allowEmergencyAccess: false,
    allowAnnualReview: false,
    allowAdvancedSearch: false,
    priceMonthly: 'Free',
    priceYearly: 'Free',
  ),
  PlanTier.plus: PlanLimits(
    maxPolicies: 10,
    maxQuestionsPerMonth: 200,
    allowComparison: true,
    allowFamilyView: true,
    allowCloudSync: true,
    allowEmergencyAccess: false,
    allowAnnualReview: false,
    allowAdvancedSearch: true,
    priceMonthly: '₹149/mo',
    priceYearly: '₹999/yr',
  ),
  PlanTier.family: PlanLimits(
    maxPolicies: 50,
    maxQuestionsPerMonth: 500,
    allowComparison: true,
    allowFamilyView: true,
    allowCloudSync: true,
    allowEmergencyAccess: true,
    allowAnnualReview: true,
    allowAdvancedSearch: true,
    priceMonthly: '₹249/mo',
    priceYearly: '₹1,799/yr',
  ),
};

/// Represents the user's current entitlement state.
///
/// Stored locally in Hive and synced from the backend when available.
/// The entitlement determines what features and limits the user has access to.
class Entitlement {
  final PlanTier planTier;
  final DateTime? expiresAt;
  final int questionsUsedThisMonth;
  final DateTime? questionsResetAt;

  const Entitlement({
    this.planTier = PlanTier.free,
    this.expiresAt,
    this.questionsUsedThisMonth = 0,
    this.questionsResetAt,
  });

  PlanLimits get limits => planLimits[planTier]!;

  bool get isActive {
    if (planTier == PlanTier.free) return true;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  bool get isExpired =>
      planTier != PlanTier.free && expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Whether the user has remaining Q&A capacity this month.
  bool get hasQuestionsRemaining =>
      questionsUsedThisMonth < limits.maxQuestionsPerMonth;

  int get questionsRemaining =>
      (limits.maxQuestionsPerMonth - questionsUsedThisMonth).clamp(0, limits.maxQuestionsPerMonth);

  /// Whether the user can upload more policies.
  bool canUploadMore(int currentPolicyCount) =>
      currentPolicyCount < limits.maxPolicies;

  int get policiesRemaining => limits.maxPolicies; // actual remaining depends on current count

  Map<String, dynamic> toJson() => {
        'plan_tier': planTier.name,
        'expires_at': expiresAt?.toIso8601String(),
        'questions_used_this_month': questionsUsedThisMonth,
        'questions_reset_at': questionsResetAt?.toIso8601String(),
      };

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
        planTier: PlanTier.values.firstWhere(
          (t) => t.name == json['plan_tier'],
          orElse: () => PlanTier.free,
        ),
        expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
        questionsUsedThisMonth: json['questions_used_this_month'] ?? 0,
        questionsResetAt: json['questions_reset_at'] != null
            ? DateTime.parse(json['questions_reset_at'])
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entitlement &&
          runtimeType == other.runtimeType &&
          planTier == other.planTier &&
          expiresAt == other.expiresAt &&
          questionsUsedThisMonth == other.questionsUsedThisMonth &&
          questionsResetAt == other.questionsResetAt;

  @override
  int get hashCode => Object.hash(
        planTier,
        expiresAt,
        questionsUsedThisMonth,
        questionsResetAt,
      );

  Entitlement copyWith({
    PlanTier? planTier,
    DateTime? expiresAt,
    int? questionsUsedThisMonth,
    DateTime? questionsResetAt,
  }) =>
      Entitlement(
        planTier: planTier ?? this.planTier,
        expiresAt: expiresAt ?? this.expiresAt,
        questionsUsedThisMonth: questionsUsedThisMonth ?? this.questionsUsedThisMonth,
        questionsResetAt: questionsResetAt ?? this.questionsResetAt,
      );
}
