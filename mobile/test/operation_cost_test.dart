import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/operation_cost.dart';

void main() {
  group('OperationCost.questionCost', () {
    test('returns 1 for ask_question', () {
      expect(OperationCost.questionCost(OperationCost.askQuestion), equals(1));
    });

    test('returns 0 for upload_policy', () {
      expect(OperationCost.questionCost(OperationCost.uploadPolicy), equals(0));
    });

    test('returns 0 for compare_policies', () {
      expect(
        OperationCost.questionCost(OperationCost.comparePolicies),
        equals(0),
      );
    });

    test('returns 0 for family_view', () {
      expect(OperationCost.questionCost(OperationCost.familyView), equals(0));
    });

    test('returns 0 for cloud_sync', () {
      expect(OperationCost.questionCost(OperationCost.cloudSync), equals(0));
    });

    test('returns 0 for emergency_access', () {
      expect(
        OperationCost.questionCost(OperationCost.emergencyAccess),
        equals(0),
      );
    });

    test('returns 0 for annual_review', () {
      expect(OperationCost.questionCost(OperationCost.annualReview), equals(0));
    });

    test('returns 0 for advanced_search', () {
      expect(
        OperationCost.questionCost(OperationCost.advancedSearch),
        equals(0),
      );
    });

    test('returns 0 for an unknown operation', () {
      expect(OperationCost.questionCost('unknown_operation'), equals(0));
    });

    test('returns 0 for empty string', () {
      expect(OperationCost.questionCost(''), equals(0));
    });

    test('returns 0 for all known non-question operations', () {
      final nonQuestion = OperationCost.allOperations
          .where((op) => op != OperationCost.askQuestion);
      for (final op in nonQuestion) {
        expect(
          OperationCost.questionCost(op),
          equals(0),
          reason: '$op should cost 0 questions',
        );
      }
    });
  });

  group('OperationCost.consumesBudget', () {
    test('returns true for ask_question', () {
      expect(
        OperationCost.consumesBudget(OperationCost.askQuestion),
        isTrue,
      );
    });

    test('returns false for upload_policy', () {
      expect(
        OperationCost.consumesBudget(OperationCost.uploadPolicy),
        isFalse,
      );
    });

    test('returns false for compare_policies', () {
      expect(
        OperationCost.consumesBudget(OperationCost.comparePolicies),
        isFalse,
      );
    });

    test('returns false for family_view', () {
      expect(
        OperationCost.consumesBudget(OperationCost.familyView),
        isFalse,
      );
    });

    test('returns false for cloud_sync', () {
      expect(OperationCost.consumesBudget(OperationCost.cloudSync), isFalse);
    });

    test('returns false for emergency_access', () {
      expect(
        OperationCost.consumesBudget(OperationCost.emergencyAccess),
        isFalse,
      );
    });

    test('returns false for annual_review', () {
      expect(
        OperationCost.consumesBudget(OperationCost.annualReview),
        isFalse,
      );
    });

    test('returns false for advanced_search', () {
      expect(
        OperationCost.consumesBudget(OperationCost.advancedSearch),
        isFalse,
      );
    });

    test('returns false for an unknown operation', () {
      expect(OperationCost.consumesBudget('unknown'), isFalse);
    });

    test('questionCost and consumesBudget agree on all operations', () {
      for (final op in OperationCost.allOperations) {
        expect(
          OperationCost.consumesBudget(op),
          equals(OperationCost.questionCost(op) > 0),
          reason: 'consumesBudget should be true iff questionCost > 0 for $op',
        );
      }
    });

    test('only ask_question consumes budget across all known operations', () {
      final budgetConsumingOps = OperationCost.allOperations
          .where(OperationCost.consumesBudget)
          .toList();
      expect(budgetConsumingOps, equals([OperationCost.askQuestion]));
    });
  });

  group('OperationCost.displayLabel', () {
    test('returns non-empty label for ask_question', () {
      final label = OperationCost.displayLabel(OperationCost.askQuestion);
      expect(label, isNotEmpty);
      expect(label, equals('Questions asked'));
    });

    test('returns non-empty label for upload_policy', () {
      final label = OperationCost.displayLabel(OperationCost.uploadPolicy);
      expect(label, isNotEmpty);
      expect(label, equals('Policy uploads'));
    });

    test('returns non-empty label for compare_policies', () {
      final label = OperationCost.displayLabel(OperationCost.comparePolicies);
      expect(label, isNotEmpty);
      expect(label, equals('Policy comparisons'));
    });

    test('returns non-empty label for family_view', () {
      final label = OperationCost.displayLabel(OperationCost.familyView);
      expect(label, isNotEmpty);
      expect(label, equals('Family view'));
    });

    test('returns non-empty label for cloud_sync', () {
      final label = OperationCost.displayLabel(OperationCost.cloudSync);
      expect(label, isNotEmpty);
      expect(label, equals('Cloud sync'));
    });

    test('returns non-empty label for emergency_access', () {
      final label = OperationCost.displayLabel(OperationCost.emergencyAccess);
      expect(label, isNotEmpty);
      expect(label, equals('Emergency access'));
    });

    test('returns non-empty label for annual_review', () {
      final label = OperationCost.displayLabel(OperationCost.annualReview);
      expect(label, isNotEmpty);
      expect(label, equals('Annual review'));
    });

    test('returns non-empty label for advanced_search', () {
      final label = OperationCost.displayLabel(OperationCost.advancedSearch);
      expect(label, isNotEmpty);
      expect(label, equals('Advanced search'));
    });

    test('returns non-empty labels for all known operations', () {
      for (final op in OperationCost.allOperations) {
        final label = OperationCost.displayLabel(op);
        expect(
          label,
          isNotEmpty,
          reason: '$op should have a non-empty display label',
        );
      }
    });

    test('all known labels are distinct', () {
      final labels =
          OperationCost.allOperations.map(OperationCost.displayLabel).toList();
      final uniqueLabels = labels.toSet();
      expect(uniqueLabels.length, equals(labels.length),
          reason: 'All display labels should be unique');
    });

    test('returns the operation name for unknown operations', () {
      expect(OperationCost.displayLabel('unknown_op'), equals('unknown_op'));
    });

    test('returns empty string for empty input', () {
      expect(OperationCost.displayLabel(''), equals(''));
    });
  });

  group('OperationCost.allOperations', () {
    test('contains all 8 known operations', () {
      expect(OperationCost.allOperations, hasLength(8));
    });

    test('includes ask_question', () {
      expect(OperationCost.allOperations, contains(OperationCost.askQuestion));
    });

    test('includes upload_policy', () {
      expect(OperationCost.allOperations, contains(OperationCost.uploadPolicy));
    });

    test('includes compare_policies', () {
      expect(
        OperationCost.allOperations,
        contains(OperationCost.comparePolicies),
      );
    });

    test('includes family_view', () {
      expect(OperationCost.allOperations, contains(OperationCost.familyView));
    });

    test('includes cloud_sync', () {
      expect(OperationCost.allOperations, contains(OperationCost.cloudSync));
    });

    test('includes emergency_access', () {
      expect(
        OperationCost.allOperations,
        contains(OperationCost.emergencyAccess),
      );
    });

    test('includes annual_review', () {
      expect(OperationCost.allOperations, contains(OperationCost.annualReview));
    });

    test('includes advanced_search', () {
      expect(
        OperationCost.allOperations,
        contains(OperationCost.advancedSearch),
      );
    });

    test('order is stable', () {
      // The order should be deterministic since it's a literal list.
      final ordered = OperationCost.allOperations.toList();
      expect(ordered[0], equals(OperationCost.askQuestion));
      expect(ordered[1], equals(OperationCost.uploadPolicy));
      expect(ordered[2], equals(OperationCost.comparePolicies));
      expect(ordered[3], equals(OperationCost.familyView));
      expect(ordered[4], equals(OperationCost.cloudSync));
      expect(ordered[5], equals(OperationCost.emergencyAccess));
      expect(ordered[6], equals(OperationCost.annualReview));
      expect(ordered[7], equals(OperationCost.advancedSearch));
    });
  });
}
