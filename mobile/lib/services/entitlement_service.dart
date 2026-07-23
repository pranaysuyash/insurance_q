import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/entitlement.dart';
import '../models/operation_cost.dart';
import '../models/qa_pack.dart';
import 'app_state_store.dart';

/// Canonical service for managing the user's subscription entitlement
/// and pay-per-Q&A packs.
///
/// Reads and writes the current plan tier, usage counters, packs, and expiry
/// to Hive. This is a local mirror for responsive UI and offline continuity.
/// The backend remains authoritative for protected Q&A usage and pack grants.
class EntitlementService {
  static const _entitlementKey = 'entitlement_v1';
  static Box get _box => Hive.box(AppStateStore.boxName);

  // ── Core CRUD ────────────────────────────────────────────────────

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

  // ── Plan management ──────────────────────────────────────────────

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

  // ── Q&A consumption ──────────────────────────────────────────────

  /// Record a usage event and track the operation that consumed it.
  ///
  /// [operation] identifies which feature triggered the consumption
  /// (e.g. [OperationCost.askQuestion]). This enables per-operation
  /// cost attribution in the UI.
  ///
  /// Consumption strategy:
  /// 1. If the user has remaining *subscription* questions this month, deduct there.
  /// 2. Otherwise, consume from the earliest-expiring *pack* (FIFO).
  /// 3. If neither is available, no-op (caller should gate before calling).
  Future<void> recordQuestionUsed({String operation = OperationCost.askQuestion}) async {
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

    // Track per-operation usage for cost attribution.
    final updatedUsage = Map<String, int>.from(ent.operationUsage);
    updatedUsage[operation] = (updatedUsage[operation] ?? 0) + 1;

    // Step 1: try subscription questions first
    if (ent.hasSubscriptionQuestionsRemaining) {
      final updated = ent.copyWith(
        questionsUsedThisMonth: ent.questionsUsedThisMonth + 1,
        questionsResetAt: ent.questionsResetAt ?? _nextMonthStart(),
        operationUsage: updatedUsage,
      );
      await save(updated);
      return;
    }

    // Step 2: consume from earliest-expiring pack (FIFO)
    final activePacks = ent.activePacks;
    if (activePacks.isNotEmpty) {
      final packToConsume = activePacks.first;
      final newPacks = List<QaPack>.from(ent.packs);
      final idx = newPacks.indexWhere(
        (p) => p.purchasedAt == packToConsume.purchasedAt &&
               p.type == packToConsume.type,
      );
      if (idx != -1) {
        newPacks[idx] = packToConsume.copyWith(
          questionsRemaining: packToConsume.questionsRemaining - 1,
        );
      }
      final updated = ent.copyWith(
        packs: newPacks,
        questionsResetAt: ent.questionsResetAt ?? _nextMonthStart(),
        operationUsage: updatedUsage,
      );
      await save(updated);
      debugPrint(
        'EntitlementService: consumed pack question (${packToConsume.type.name}), '
        '${newPacks[idx].questionsRemaining} remaining',
      );
    }
  }

  // ── Pack management ──────────────────────────────────────────────

  /// Add a purchased pack to the entitlement.
  ///
  /// Called by the BillingAdapter after a successful consumable purchase.
  /// Packs are stored unsorted; [activePacks] on Entitlement sorts them
  /// by expiry at read time.
  Future<void> addPack(QaPackType type) async {
    final now = DateTime.now();
    final pack = QaPack(
      type: type,
      questionsRemaining: type.questionCount,
      purchasedAt: now,
      expiresAt: now.add(Duration(days: type.validityDays)),
    );

    final ent = current();
    final updated = ent.copyWith(
      packs: [...ent.packs, pack],
    );
    await save(updated);
    debugPrint(
      'EntitlementService: added ${type.name} pack '
      '(${type.questionCount}Q, expires ${pack.expiresAt.toIso8601String()})',
    );
  }

  /// Replace the local pack mirror with a successful server readback.
  ///
  /// This is intentionally separate from [addPack]: a store purchase is not
  /// a server grant until the verified RevenueCat webhook is processed.
  Future<void> replacePacks(List<QaPack> packs) async {
    final ent = current();
    await save(ent.copyWith(packs: List<QaPack>.unmodifiable(packs)));
    debugPrint('EntitlementService: reconciled ${packs.length} server pack(s)');
  }

  /// Remove expired packs from the entitlement.
  ///
  /// Called lazily on every [current()] read and explicitly after purchases.
  /// Expired pack questions are lost (no refund — standard consumable behavior).
  Future<void> pruneExpiredPacks() async {
    final ent = current();
    final before = ent.packs.length;
    final active = ent.activePacks;
    if (active.length == before) return; // nothing to prune

    final updated = ent.copyWith(packs: active);
    await save(updated);
    debugPrint(
      'EntitlementService: pruned ${before - active.length} expired pack(s), '
      '${active.length} active remaining',
    );
  }

  /// Total questions remaining across all active packs.
  int get packQuestionsRemaining => current().packQuestionsRemaining;

  /// List of active packs with their remaining questions.
  List<QaPack> get activePacks => current().activePacks;

  /// Whether the user can ask a question (subscription or packs).
  bool get canAskQuestion => current().hasQuestionsRemaining;

  // ── Reset ────────────────────────────────────────────────────────

  /// Reset entitlement to free tier (e.g., for testing or account reset).
  Future<void> resetToFree() async {
    await save(const Entitlement());
    debugPrint('EntitlementService: reset to free tier');
  }

  // ── Helpers ──────────────────────────────────────────────────────

  DateTime _nextMonthStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }
}
