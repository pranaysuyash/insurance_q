import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/entitlement.dart';
import '../services/entitlement_service.dart';

/// Provides the EntitlementService singleton.
final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  return EntitlementService();
});

/// Exposes the current entitlement state, rebuilds when [EntitlementNotifier]
/// updates it.
final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, Entitlement>((ref) {
  return EntitlementNotifier(ref.watch(entitlementServiceProvider));
});

class EntitlementNotifier extends StateNotifier<Entitlement> {
  final EntitlementService _service;

  EntitlementNotifier(this._service) : super(_service.current());

  /// Refresh from local storage (e.g., after app resume or billing event).
  void refresh() {
    state = _service.current();
  }

  /// Upgrade or downgrade the plan.
  Future<void> setPlan(PlanTier tier, {DateTime? expiresAt}) async {
    await _service.setPlan(tier, expiresAt: expiresAt);
    state = _service.current();
  }

  /// Record a Q&A usage event.
  Future<void> recordQuestionUsed() async {
    await _service.recordQuestionUsed();
    state = _service.current();
  }

  /// Check if a feature is available, returning null if allowed or a reason string.
  /// Reads from provider state (not directly from Hive) for consistency.
  String? checkAction(String action, {int? currentPolicyCount}) {
    final ent = state;
    if (ent.isExpired) {
      return 'Your ${ent.planTier.displayName} plan has expired. Renew to continue.';
    }
    switch (action) {
      case 'upload_policy':
        if (!ent.canUploadMore(currentPolicyCount ?? 0)) {
          return 'You\'ve reached the ${ent.planTier.displayName} policy limit (${ent.limits.maxPolicies}). Upgrade for more storage.';
        }
        return null;
      case 'ask_question':
        if (!ent.hasQuestionsRemaining) {
          return 'You\'ve used all ${ent.limits.maxQuestionsPerMonth} questions this month on ${ent.planTier.displayName}. Upgrade for more.';
        }
        return null;
      case 'compare_policies':
        return ent.limits.allowComparison ? null : 'Policy comparison is available on Plus and Family plans.';
      case 'family_view':
        return ent.limits.allowFamilyView ? null : 'Family coverage view is available on Plus and Family plans.';
      case 'cloud_sync':
        return ent.limits.allowCloudSync ? null : 'Cloud sync is available on Plus and Family plans.';
      case 'emergency_access':
        return ent.limits.allowEmergencyAccess ? null : 'Emergency access is available on the Family plan.';
      case 'annual_review':
        return ent.limits.allowAnnualReview ? null : 'Annual coverage review is available on the Family plan.';
      case 'advanced_search':
        return ent.limits.allowAdvancedSearch ? null : 'Advanced search is available on Plus and Family plans.';
      default:
        return null;
    }
  }

  /// Convenience: is the feature unlocked for the current plan?
  bool isFeatureAvailable(String action, {int? currentPolicyCount}) {
    return checkAction(action, currentPolicyCount: currentPolicyCount) == null;
  }

  /// Reset to free tier.
  Future<void> resetToFree() async {
    await _service.resetToFree();
    state = _service.current();
  }
}
