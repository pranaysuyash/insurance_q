import 'package:flutter/foundation.dart';
import 'operation_cost.dart';
import 'qa_pack.dart';

/// Subscription plan tiers for CoverWise monetization.
///
/// Free tier reaches the real "aha" moment — one policy, useful summary,
/// limited Q&A. Plus and Family add household management, higher limits,
/// and premium features. The plan determines what the user can do in the app.
///
/// For occasional users who don't need a subscription, pay-per-Q&A packs
/// provide an alternative: buy 5, 15, or 30 questions at a time, valid for 90 days.
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
  final bool allowExport;
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
    required this.allowExport,
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
    allowExport: false,
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
    allowExport: true,
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
    allowExport: true,
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

  /// Purchased Q&A packs, ordered by expiry (earliest first for FIFO consumption).
  final List<QaPack> packs;

  /// Per-operation usage counters for the current billing period.
  ///
  /// Keys are [OperationCost] constants (e.g. `'ask_question'`).
  /// Values are the number of times the operation was performed
  /// this month/billing period. This enables transparent cost
  /// attribution in the UI — users can see exactly what their
  /// budget went toward.
  final Map<String, int> operationUsage;

  const Entitlement({
    this.planTier = PlanTier.free,
    this.expiresAt,
    this.questionsUsedThisMonth = 0,
    this.questionsResetAt,
    this.packs = const [],
    this.operationUsage = const {},  });

  PlanLimits get limits => planLimits[planTier]!;

  bool get isActive {
    if (planTier == PlanTier.free) return true;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  bool get isExpired =>
      planTier != PlanTier.free && expiresAt != null && DateTime.now().isAfter(expiresAt!);

  // ── Subscription-based Q&A ──────────────────────────────────────

  /// Whether the user has remaining Q&A capacity this month (subscription only).
  bool get hasSubscriptionQuestionsRemaining =>
      isActive && questionsUsedThisMonth < limits.maxQuestionsPerMonth;

  int get subscriptionQuestionsRemaining =>
      !isActive
          ? 0
          : (limits.maxQuestionsPerMonth - questionsUsedThisMonth)
              .clamp(0, limits.maxQuestionsPerMonth);

  // ── Pack-based Q&A ──────────────────────────────────────────────

  /// Non-expired packs, sorted by expiry (earliest first for FIFO consumption).
  List<QaPack> get activePacks =>
      packs.where((p) => !p.isExpired).toList()..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

  /// Total questions remaining across all active packs.
  int get packQuestionsRemaining =>
      activePacks.fold(0, (sum, p) => sum + p.questionsRemaining);

  /// Whether the user has any pack questions available.
  bool get hasPackQuestionsRemaining => packQuestionsRemaining > 0;

  // ── Combined Q&A budget ─────────────────────────────────────────

  /// Total questions remaining (subscription + packs combined).
  int get totalQuestionsRemaining =>
      subscriptionQuestionsRemaining + packQuestionsRemaining;

  /// Whether the user can ask a question (subscription or packs).
  bool get hasQuestionsRemaining =>
      hasSubscriptionQuestionsRemaining || hasPackQuestionsRemaining;

  /// Whether the user can upload more policies.
  bool canUploadMore(int currentPolicyCount) =>
      currentPolicyCount < limits.maxPolicies;

  int get policiesRemaining => limits.maxPolicies; // actual remaining depends on current count

  /// Get the usage count for a specific operation.
  int operationCount(String operation) => operationUsage[operation] ?? 0;

  /// Combined usage across all operations that cost budget.
  int get totalOperationUsage =>
      operationUsage.values.fold(0, (sum, v) => sum + v);

  /// Whether operation usage was reset this period.
  bool get hasOperationUsage => operationUsage.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'plan_tier': planTier.name,
        'expires_at': expiresAt?.toIso8601String(),
        'questions_used_this_month': questionsUsedThisMonth,
        'questions_reset_at': questionsResetAt?.toIso8601String(),
        'packs': packs.map((p) => p.toJson()).toList(),
        'operation_usage': operationUsage,
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
        packs: json['packs'] != null
            ? (json['packs'] as List<dynamic>)
                .map((p) => QaPack.fromJson(p as Map<String, dynamic>))
                .toList()
            : const [],
        operationUsage: json['operation_usage'] != null
            ? Map<String, int>.from(json['operation_usage'] as Map)
            : const {},
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entitlement &&
          runtimeType == other.runtimeType &&
          planTier == other.planTier &&
          expiresAt == other.expiresAt &&
          questionsUsedThisMonth == other.questionsUsedThisMonth &&
          questionsResetAt == other.questionsResetAt &&
          packs.length == other.packs.length &&
          mapEquals(operationUsage, other.operationUsage);

  @override
  int get hashCode => Object.hash(
        planTier,
        expiresAt,
        questionsUsedThisMonth,
        questionsResetAt,
        packs.length,
        Object.hashAll(operationUsage.entries.map((e) => MapEntry(e.key, e.value))),
      );

  Entitlement copyWith({
    PlanTier? planTier,
    DateTime? expiresAt,
    int? questionsUsedThisMonth,
    DateTime? questionsResetAt,
    List<QaPack>? packs,
    Map<String, int>? operationUsage,
  }) =>
      Entitlement(
        planTier: planTier ?? this.planTier,
        expiresAt: expiresAt ?? this.expiresAt,
        questionsUsedThisMonth: questionsUsedThisMonth ?? this.questionsUsedThisMonth,
        questionsResetAt: questionsResetAt ?? this.questionsResetAt,
        packs: packs ?? this.packs,
        operationUsage: operationUsage ?? this.operationUsage,
      );
}
