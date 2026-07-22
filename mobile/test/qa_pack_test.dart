import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:coverwise/models/qa_pack.dart';
import 'package:coverwise/models/entitlement.dart';
import 'package:coverwise/services/entitlement_service.dart';
import 'package:coverwise/services/app_state_store.dart';

void main() {
  setUpAll(() async {
    Hive.init('test_qa_pack_hive');
    await Hive.openBox(AppStateStore.boxName);
  });

  tearDownAll(() async {
  });

  group('QaPackType', () {
    test('has correct question counts', () {
      expect(QaPackType.starter.questionCount, 5);
      expect(QaPackType.value.questionCount, 15);
      expect(QaPackType.pro.questionCount, 30);
    });

    test('has correct prices', () {
      expect(QaPackType.starter.price, '₹49');
      expect(QaPackType.value.price, '₹119');
      expect(QaPackType.pro.price, '₹199');
    });

    test('has 90-day validity', () {
      expect(QaPackType.starter.validityDays, 90);
      expect(QaPackType.value.validityDays, 90);
      expect(QaPackType.pro.validityDays, 90);
    });

    test('all three pack types exist', () {
      expect(QaPackType.values.length, 3);
    });
  });

  group('QaPack', () {
    test('serialization round-trip', () {
      final now = DateTime(2026, 7, 17, 12, 0);
      final expiresAt = DateTime(2026, 10, 15, 12, 0);
      final pack = QaPack(
        type: QaPackType.value,
        questionsRemaining: 12,
        purchasedAt: now,
        expiresAt: expiresAt,
      );

      final json = pack.toJson();
      final restored = QaPack.fromJson(json);

      expect(restored.type, QaPackType.value);
      expect(restored.questionsRemaining, 12);
      expect(restored.purchasedAt, now);
      expect(restored.expiresAt, expiresAt);
    });

    test('isExpired returns true when past expiry', () {
      final pack = QaPack(
        type: QaPackType.starter,
        questionsRemaining: 3,
        purchasedAt: DateTime.now().subtract(const Duration(days: 100)),
        expiresAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(pack.isExpired, true);
    });

    test('isExpired returns false when before expiry', () {
      final pack = QaPack(
        type: QaPackType.starter,
        questionsRemaining: 3,
        purchasedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 90)),
      );
      expect(pack.isExpired, false);
    });

    test('usagePercent is 0 when no questions used', () {
      final pack = QaPack(
        type: QaPackType.value,
        questionsRemaining: 15,
        purchasedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 90)),
      );
      expect(pack.usagePercent, 0.0);
    });

    test('usagePercent is correct after partial use', () {
      final pack = QaPack(
        type: QaPackType.value,
        questionsRemaining: 10,
        purchasedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 90)),
      );
      expect(pack.usagePercent, closeTo(0.333, 0.01));
    });

    test('usagePercent is 1.0 when all questions used', () {
      final pack = QaPack(
        type: QaPackType.value,
        questionsRemaining: 0,
        purchasedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 90)),
      );
      expect(pack.usagePercent, 1.0);
    });

    test('copyWith creates new instance with overrides', () {
      final pack = QaPack(
        type: QaPackType.starter,
        questionsRemaining: 5,
        purchasedAt: DateTime(2026, 1, 1),
        expiresAt: DateTime(2026, 4, 1),
      );
      final updated = pack.copyWith(questionsRemaining: 3);
      expect(updated.questionsRemaining, 3);
      expect(updated.type, QaPackType.starter); // unchanged
    });

    test('fromJson defaults to starter for unknown type', () {
      final json = {
        'type': 'unknown_type',
        'questions_remaining': 5,
        'purchased_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
      };
      final pack = QaPack.fromJson(json);
      expect(pack.type, QaPackType.starter);
    });
  });

  group('Entitlement — pack-aware state', () {
    test('activePacks filters expired packs', () {
      final now = DateTime.now();
      final ent = Entitlement(
        packs: [
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 3,
            purchasedAt: now.subtract(const Duration(days: 100)),
            expiresAt: now.subtract(const Duration(days: 10)), // expired
          ),
          QaPack(
            type: QaPackType.value,
            questionsRemaining: 10,
            purchasedAt: now,
            expiresAt: now.add(const Duration(days: 90)), // active
          ),
        ],
      );
      expect(ent.activePacks.length, 1);
      expect(ent.activePacks.first.type, QaPackType.value);
    });

    test('activePacks sorts by expiry (earliest first)', () {
      final now = DateTime.now();
      final ent = Entitlement(
        packs: [
          QaPack(
            type: QaPackType.pro,
            questionsRemaining: 20,
            purchasedAt: now,
            expiresAt: now.add(const Duration(days: 60)), // expires sooner
          ),
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 3,
            purchasedAt: now.subtract(const Duration(days: 10)),
            expiresAt: now.add(const Duration(days: 80)), // expires later
          ),
        ],
      );
      expect(ent.activePacks.first.type, QaPackType.pro); // expires first
      expect(ent.activePacks.last.type, QaPackType.starter);
    });

    test('packQuestionsRemaining sums active packs', () {
      final now = DateTime.now();
      final ent = Entitlement(
        packs: [
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 3,
            purchasedAt: now,
            expiresAt: now.add(const Duration(days: 90)),
          ),
          QaPack(
            type: QaPackType.value,
            questionsRemaining: 10,
            purchasedAt: now,
            expiresAt: now.add(const Duration(days: 90)),
          ),
        ],
      );
      expect(ent.packQuestionsRemaining, 13);
    });

    test('hasPackQuestionsRemaining is false when no active packs', () {
      final ent = const Entitlement(packs: []);
      expect(ent.hasPackQuestionsRemaining, false);
    });

    test('hasPackQuestionsRemaining is true when packs have questions', () {
      final now = DateTime.now();
      final ent = Entitlement(
        packs: [
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 1,
            purchasedAt: now,
            expiresAt: now.add(const Duration(days: 90)),
          ),
        ],
      );
      expect(ent.hasPackQuestionsRemaining, true);
    });

    test('totalQuestionsRemaining combines subscription and packs', () {
      final ent = Entitlement(
        planTier: PlanTier.free,
        questionsUsedThisMonth: 15, // 5 subscription left
        packs: [
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 3, // 3 pack questions
            purchasedAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(days: 90)),
          ),
        ],
      );
      expect(ent.totalQuestionsRemaining, 8); // 5 + 3
    });

    test('hasQuestionsRemaining is true when either source has questions', () {
      // Subscription exhausted, but packs available
      final ent1 = Entitlement(
        planTier: PlanTier.free,
        questionsUsedThisMonth: 20, // all used
        packs: [
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 2,
            purchasedAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(days: 90)),
          ),
        ],
      );
      expect(ent1.hasQuestionsRemaining, true);

      // Packs exhausted, but subscription available
      final ent2 = Entitlement(
        planTier: PlanTier.free,
        questionsUsedThisMonth: 10, // 10 left
        packs: [
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 0,
            purchasedAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(days: 90)),
          ),
        ],
      );
      expect(ent2.hasQuestionsRemaining, true);
    });

    test('hasQuestionsRemaining is false when both exhausted', () {
      final ent = Entitlement(
        planTier: PlanTier.free,
        questionsUsedThisMonth: 20, // all subscription used
        packs: [
          QaPack(
            type: QaPackType.starter,
            questionsRemaining: 0, // all pack used
            purchasedAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(days: 90)),
          ),
        ],
      );
      expect(ent.hasQuestionsRemaining, false);
    });

    test('serialization round-trip with packs', () {
      final now = DateTime(2026, 7, 17, 12, 0);
      final ent = Entitlement(
        planTier: PlanTier.free,
        questionsUsedThisMonth: 10,
        packs: [
          QaPack(
            type: QaPackType.value,
            questionsRemaining: 12,
            purchasedAt: now,
            expiresAt: now.add(const Duration(days: 90)),
          ),
        ],
      );

      final json = ent.toJson();
      final restored = Entitlement.fromJson(json);

      expect(restored.packs.length, 1);
      expect(restored.packs.first.type, QaPackType.value);
      expect(restored.packs.first.questionsRemaining, 12);
    });

    test('copyWith preserves packs when not overridden', () {
      final now = DateTime.now();
      final packs = [
        QaPack(
          type: QaPackType.starter,
          questionsRemaining: 3,
          purchasedAt: now,
          expiresAt: now.add(const Duration(days: 90)),
        ),
      ];
      final ent = Entitlement(packs: packs);
      final updated = ent.copyWith(questionsUsedThisMonth: 5);
      expect(updated.packs.length, 1);
    });
  });

  group('EntitlementService — pack management', () {
    late EntitlementService service;

    setUp(() async {
      service = EntitlementService();
      await service.resetToFree();
    });

    test('addPack adds a new pack to entitlement', () async {
      await service.addPack(QaPackType.starter);
      final ent = service.current();

      expect(ent.packs.length, 1);
      expect(ent.packs.first.type, QaPackType.starter);
      expect(ent.packs.first.questionsRemaining, 5);
    });

    test('addPack adds multiple packs', () async {
      await service.addPack(QaPackType.starter);
      await service.addPack(QaPackType.value);
      final ent = service.current();

      expect(ent.packs.length, 2);
      expect(ent.packs[0].type, QaPackType.starter);
      expect(ent.packs[1].type, QaPackType.value);
    });

    test('replacePacks reconciles the local mirror without changing plan usage', () async {
      await service.setPlan(PlanTier.plus, expiresAt: DateTime.now().add(const Duration(days: 30)));
      await service.recordQuestionUsed();
      await service.addPack(QaPackType.starter);

      final purchasedAt = DateTime.now().subtract(const Duration(days: 1));
      final expiresAt = DateTime.now().add(const Duration(days: 89));
      await service.replacePacks([
        QaPack(
          type: QaPackType.value,
          questionsRemaining: 7,
          purchasedAt: purchasedAt,
          expiresAt: expiresAt,
        ),
      ]);

      final ent = service.current();
      expect(ent.planTier, PlanTier.plus);
      expect(ent.questionsUsedThisMonth, 1);
      expect(ent.packs.single.questionsRemaining, 7);
      expect(ent.packs.single.type, QaPackType.value);
    });

    test('recordQuestionUsed deducts from subscription first', () async {
      // Free tier: 20 questions/month, start with 0 used
      await service.recordQuestionUsed();
      final ent = service.current();

      expect(ent.questionsUsedThisMonth, 1);
      expect(ent.packs.length, 0); // no pack consumed
    });

    test('recordQuestionUsed falls back to pack when subscription exhausted', () async {
      // Exhaust subscription
      for (var i = 0; i < 20; i++) {
        await service.recordQuestionUsed();
      }

      // Add a pack
      await service.addPack(QaPackType.starter);

      // Next question should consume from pack
      await service.recordQuestionUsed();
      final ent = service.current();

      expect(ent.questionsUsedThisMonth, 20); // subscription still maxed
      expect(ent.packs.first.questionsRemaining, 4); // 5 - 1
    });

    test('recordQuestionUsed consumes FIFO from earliest-expiring pack', () async {
      // Exhaust subscription
      for (var i = 0; i < 20; i++) {
        await service.recordQuestionUsed();
      }

      // Add two packs — starter first (expires first), then value
      await service.addPack(QaPackType.starter);
      await service.addPack(QaPackType.value);

      // Use one question — should come from starter (earlier expiry)
      await service.recordQuestionUsed();
      final ent = service.current();

      expect(ent.packs[0].questionsRemaining, 4); // starter: 5 - 1
      expect(ent.packs[1].questionsRemaining, 15); // value: unchanged
    });

    test('pruneExpiredPacks removes expired packs', () async {
      // Manually add an expired pack by manipulating Hive directly
      await service.addPack(QaPackType.starter);

      // Simulate expiry by overwriting the pack's expiry to past
      var ent = service.current();
      final expiredPack = ent.packs.first.copyWith(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      await service.save(ent.copyWith(packs: [expiredPack]));

      // Prune should remove it
      await service.pruneExpiredPacks();
      ent = service.current();

      expect(ent.packs.length, 0);
    });

    test('pruneExpiredPacks keeps active packs', () async {
      await service.addPack(QaPackType.value);
      await service.pruneExpiredPacks();
      final ent = service.current();

      expect(ent.packs.length, 1);
      expect(ent.packs.first.type, QaPackType.value);
    });

    test('packQuestionsRemaining reflects current state', () async {
      await service.addPack(QaPackType.starter);
      expect(service.packQuestionsRemaining, 5);

      // Exhaust subscription, then consume one pack question
      for (var i = 0; i < 20; i++) {
        await service.recordQuestionUsed();
      }
      await service.recordQuestionUsed();
      expect(service.packQuestionsRemaining, 4);
    });

    test('canAskQuestion is true when packs available', () async {
      // Exhaust subscription
      for (var i = 0; i < 20; i++) {
        await service.recordQuestionUsed();
      }
      // Add pack
      await service.addPack(QaPackType.starter);
      expect(service.canAskQuestion, true);
    });

    test('canAskQuestion is false when both exhausted', () async {
      // Exhaust subscription
      for (var i = 0; i < 20; i++) {
        await service.recordQuestionUsed();
      }
      // Add and exhaust pack
      await service.addPack(QaPackType.starter);
      for (var i = 0; i < 5; i++) {
        await service.recordQuestionUsed();
      }
      expect(service.canAskQuestion, false);
    });

    test('resetToFree clears packs', () async {
      await service.addPack(QaPackType.starter);
      await service.addPack(QaPackType.value);
      await service.resetToFree();
      final ent = service.current();

      expect(ent.packs.length, 0);
      expect(ent.planTier, PlanTier.free);
    });
  });
}
