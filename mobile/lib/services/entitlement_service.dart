import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/entitlement.dart';
import 'app_state_store.dart';

/// Canonical service for managing the user's subscription entitlement.
///
/// Reads and writes the current plan tier, usage counters, and expiry to Hive.
/// This is the single source of truth for "what can this user do?" on the
/// client side. Backend verification is a separate concern (billing adapter).
class EntitlementService {
  static const _entitlementKey = 'entitlement_v1';
  static Box get _box => Hive.box(AppStateStore.boxName);

  /// Load the current entitlement from local storage.
  ///
  /// Returns the stored entitlement, or a free-tier default if nothing
  /// has been persisted yet.
  Entitlement current() {
    try {
      final raw = _box.get(_entitlementKey);
      if (raw is Map) {
        return Entitlement.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('EntitlementService: failed to read entitlement: $e');
    }
    return const Entitlement();
  }

  /// Persist the entitlement to local storage.
  Future<void> save(Entitlement entitlement) async {
    try {
      await _box.put(_entitlementKey, entitlement.toJson());
    } catch (e) {
      debugPrint('EntitlementService: failed to save entitlement: $e');
    }
  }

  /// Upgrade (or downgrade) the user's plan.
  ///
  /// [expiresAt] should be set for paid tiers. Pass null to reset to free.
  /// This does NOT process payment — that's the billing adapter's job.
  Future<void> setPlan(PlanTier tier, {DateTime? expiresAt}) async {
    final current = this.current();
    final updated = current.copyWith(
      planTier: tier,
      expiresAt: expiresAt,
      questionsUsedThisMonth: tier == PlanTier.free ? 0 : current.questionsUsedThisMonth,
    );
    await save(updated);
    debugPrint('EntitlementService: plan set to ${tier.name}, expires: $expiresAt');
  }

  /// Record a Q&A usage event. Resets counter monthly.
  Future<void> recordQuestionUsed() async {
    var ent = current();

    // Reset monthly counter if we've crossed a month boundary
    // or if this is the first question ever (questionsResetAt is null)
    final shouldReset = ent.questionsResetAt == null ||
        DateTime.now().isAfter(ent.questionsResetAt!);
    if (shouldReset) {
      ent = ent.copyWith(
        questionsUsedThisMonth: 0,
        questionsResetAt: _nextMonthStart(),
      );
    }

    final updated = ent.copyWith(
      questionsUsedThisMonth: ent.questionsUsedThisMonth + 1,
      questionsResetAt: ent.questionsResetAt ?? _nextMonthStart(),
    );
    await save(updated);
  }



  /// Reset entitlement to free tier (e.g., for testing or account reset).
  Future<void> resetToFree() async {
    await save(const Entitlement());
    debugPrint('EntitlementService: reset to free tier');
  }

  DateTime _nextMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }
}
