import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/entitlement.dart';
import '../models/qa_pack.dart';
import '../services/billing_adapter.dart';
import '../services/entitlement_service.dart';

/// Provides the EntitlementService singleton.
/// Both the UI and the BillingAdapter share this same instance,
/// so billing syncs are immediately visible to the UI.
final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  return EntitlementService();
});

/// Provides the BillingAdapter backed by RevenueCat.
/// Uses the same EntitlementService instance as the UI provider.
final billingAdapterProvider = Provider<BillingAdapter>((ref) {
  final entitlementService = ref.watch(entitlementServiceProvider);
  return BillingAdapter(entitlementService);
});

/// Initializes RevenueCat billing at app startup.
///
/// This provider auto-runs when first read (e.g. by InsuranceApp's build).
/// It configures the RevenueCat SDK and syncs the customer's entitlement
/// to the shared EntitlementService so the UI reflects the correct plan.
///
/// Exposes [AsyncValue] so the UI can degrade gracefully:
/// - [AsyncData] = billing initialized and synced
/// - [AsyncError] = billing init failed (UI shows "billing unavailable")
/// - [AsyncLoading] = init in progress (UI can show spinner or proceed)
final billingInitProvider = FutureProvider<void>((ref) async {
  if (!AppConfig.hasRevenueCatConfig) return;
  final billing = ref.watch(billingAdapterProvider);
  await billing.initialize(apiKey: AppConfig.revenuecatApiKey);
  await billing.syncEntitlement();
  // Refresh the Riverpod notifier so the UI picks up the synced state.
  ref.read(entitlementProvider.notifier).refresh();
  // If initialize() or syncEntitlement() throws, FutureProvider captures
  // it as AsyncError. The UI can check billingInitProvider.value for null
  // to show "billing unavailable" in settings instead of failing silently.
});

/// Exposes the current entitlement state, rebuilds when [EntitlementNotifier]
/// updates it.
final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, Entitlement>((ref) {
  return EntitlementNotifier(ref.watch(entitlementServiceProvider));
});

/// Derived provider for pack-specific state, rebuilds when entitlement changes.
final qaPackStateProvider = Provider<QaPackState>((ref) {
  final ent = ref.watch(entitlementProvider);
  return QaPackState(
    activePacks: ent.activePacks,
    packQuestionsRemaining: ent.packQuestionsRemaining,
    subscriptionQuestionsRemaining: ent.subscriptionQuestionsRemaining,
    totalQuestionsRemaining: ent.totalQuestionsRemaining,
    hasAnyQuestionsRemaining: ent.hasQuestionsRemaining,
    hasPackQuestions: ent.hasPackQuestionsRemaining,
    hasSubscriptionQuestions: ent.hasSubscriptionQuestionsRemaining,
  );
});

/// Immutable snapshot of pack-related entitlement state for UI consumption.
class QaPackState {
  final List<QaPack> activePacks;
  final int packQuestionsRemaining;
  final int subscriptionQuestionsRemaining;
  final int totalQuestionsRemaining;
  final bool hasAnyQuestionsRemaining;
  final bool hasPackQuestions;
  final bool hasSubscriptionQuestions;

  const QaPackState({
    required this.activePacks,
    required this.packQuestionsRemaining,
    required this.subscriptionQuestionsRemaining,
    required this.totalQuestionsRemaining,
    required this.hasAnyQuestionsRemaining,
    required this.hasPackQuestions,
    required this.hasSubscriptionQuestions,
  });
}

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

  /// Record a Q&A usage event — consumes subscription first, then packs (FIFO).
  Future<void> recordQuestionUsed() async {
    await _service.recordQuestionUsed();
    state = _service.current();
  }

  /// Add a purchased pack to the entitlement.
  Future<void> addPack(QaPackType type) async {
    await _service.addPack(type);
    state = _service.current();
  }

  /// Prune expired packs from the entitlement.
  Future<void> pruneExpiredPacks() async {
    await _service.pruneExpiredPacks();
    state = _service.current();
  }

  /// Check if a feature is available, returning null if allowed or a reason string.
  /// Reads from provider state (not directly from Hive) for consistency.
  String? checkAction(String action, {int? currentPolicyCount}) {
    final ent = state;
    // Purchased Q&A packs remain usable after a subscription expires. Other
    // paid-plan capabilities still require an active subscription.
    if (ent.isExpired && action != 'ask_question') {
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
          if (ent.hasSubscriptionQuestionsRemaining) {
            return 'You\'ve used all ${ent.limits.maxQuestionsPerMonth} questions this month on ${ent.planTier.displayName}. Upgrade for more.';
          } else if (ent.hasPackQuestionsRemaining) {
            return 'You\'ve used all your pack questions. Buy more packs to continue asking.';
          } else {
            return 'No questions remaining. Buy a Q&A pack or upgrade your plan.';
          }
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
