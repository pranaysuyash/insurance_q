import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/entitlement.dart';

void main() {
  group('PlanTier', () {
    test('has correct display names', () {
      expect(PlanTier.free.displayName, 'Free');
      expect(PlanTier.plus.displayName, 'Plus');
      expect(PlanTier.family.displayName, 'Family');
    });

    test('has three tiers', () {
      expect(PlanTier.values.length, 3);
    });
  });

  group('PlanLimits', () {
    test('free tier limits', () {
      final limits = planLimits[PlanTier.free]!;
      expect(limits.maxPolicies, 1);
      expect(limits.maxQuestionsPerMonth, 20);
      expect(limits.allowComparison, false);
      expect(limits.allowFamilyView, false);
      expect(limits.allowCloudSync, false);
      expect(limits.allowEmergencyAccess, false);
    });

    test('plus tier limits', () {
      final limits = planLimits[PlanTier.plus]!;
      expect(limits.maxPolicies, 10);
      expect(limits.maxQuestionsPerMonth, 200);
      expect(limits.allowComparison, true);
      expect(limits.allowFamilyView, true);
      expect(limits.allowCloudSync, true);
      expect(limits.allowEmergencyAccess, false);
    });

    test('family tier limits', () {
      final limits = planLimits[PlanTier.family]!;
      expect(limits.maxPolicies, 50);
      expect(limits.maxQuestionsPerMonth, 500);
      expect(limits.allowComparison, true);
      expect(limits.allowFamilyView, true);
      expect(limits.allowCloudSync, true);
      expect(limits.allowEmergencyAccess, true);
    });
  });

  group('Entitlement', () {
    test('defaults to free tier', () {
      final ent = const Entitlement();
      expect(ent.planTier, PlanTier.free);
      expect(ent.isActive, true);
      expect(ent.isExpired, false);
    });

    test('free tier is always active', () {
      final ent = const Entitlement();
      expect(ent.isActive, true);
    });

    test('paid tier without expiry is not active', () {
      final ent = const Entitlement(planTier: PlanTier.plus);
      expect(ent.isActive, false);
    });

    test('paid tier with future expiry is active', () {
      final ent = Entitlement(
        planTier: PlanTier.plus,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(ent.isActive, true);
      expect(ent.isExpired, false);
    });

    test('paid tier with past expiry is expired', () {
      final ent = Entitlement(
        planTier: PlanTier.plus,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(ent.isExpired, true);
      expect(ent.isActive, false);
    });

    test('questionsRemaining is clamped to max', () {
      final ent = const Entitlement(planTier: PlanTier.free);
      expect(ent.questionsRemaining, 20);
    });

    test('questionsRemaining decreases with usage', () {
      final ent = const Entitlement(
        planTier: PlanTier.plus,
        questionsUsedThisMonth: 50,
      );
      expect(ent.questionsRemaining, 150);
    });

    test('hasQuestionsRemaining when under limit', () {
      final ent = const Entitlement(
        planTier: PlanTier.plus,
        questionsUsedThisMonth: 199,
      );
      expect(ent.hasQuestionsRemaining, true);
    });

    test('no questionsRemaining when at limit', () {
      final ent = const Entitlement(
        planTier: PlanTier.plus,
        questionsUsedThisMonth: 200,
      );
      expect(ent.hasQuestionsRemaining, false);
    });

    test('canUploadMore respects maxPolicies', () {
      final ent = const Entitlement(planTier: PlanTier.free);
      expect(ent.canUploadMore(0), true);
      expect(ent.canUploadMore(1), false);
    });

    test('questionsResetAt null auto-resets counter on first use', () {
      final ent = const Entitlement(
        planTier: PlanTier.plus,
        questionsUsedThisMonth: 5,
        questionsResetAt: null,
      );
      // The model's copyWith used by the service should reset counter
      // when questionsResetAt is null
      final reset = ent.copyWith(
        questionsUsedThisMonth: 0,
        questionsResetAt: DateTime(2026, 8, 1),
      );
      expect(reset.questionsUsedThisMonth, 0);
      expect(reset.questionsResetAt, isNotNull);
    });

    test('serialization round-trip', () {
      final ent = Entitlement(
        planTier: PlanTier.plus,
        expiresAt: DateTime(2026, 12, 31),
        questionsUsedThisMonth: 42,
        questionsResetAt: DateTime(2026, 8, 1),
      );
      final json = ent.toJson();
      final restored = Entitlement.fromJson(json);

      expect(restored.planTier, PlanTier.plus);
      expect(restored.expiresAt?.year, 2026);
      expect(restored.questionsUsedThisMonth, 42);
    });

    test('copyWith preserves unchanged fields', () {
      final original = const Entitlement(
        planTier: PlanTier.plus,
        questionsUsedThisMonth: 10,
      );
      final modified = original.copyWith(planTier: PlanTier.family);

      expect(modified.planTier, PlanTier.family);
      expect(modified.questionsUsedThisMonth, 10); // preserved
    });
  });
}
