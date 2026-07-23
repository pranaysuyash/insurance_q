/// Cost attribution for every gated operation.
///
/// Defines which operations consume entitlement budget and how many
/// units each operation costs. This enables:
/// 1. Per-operation usage tracking (not just a raw counter)
/// 2. Transparent UI showing what the user's budget went toward
/// 3. Future cost-based feature tuning (e.g., expensive operations
///    could cost more on free tier)
abstract final class OperationCost {
  OperationCost._();

  /// Known operation identifiers used by [Entitlement.operationUsage].
  static const String askQuestion = 'ask_question';
  static const String uploadPolicy = 'upload_policy';
  static const String comparePolicies = 'compare_policies';
  static const String familyView = 'family_view';
  static const String cloudSync = 'cloud_sync';
  static const String emergencyAccess = 'emergency_access';
  static const String annualReview = 'annual_review';
  static const String advancedSearch = 'advanced_search';

  /// All known operations for iteration in UI breakdowns.
  static Iterable<String> get allOperations => [
        askQuestion,
        uploadPolicy,
        comparePolicies,
        familyView,
        cloudSync,
        emergencyAccess,
        annualReview,
        advancedSearch,
      ];

  /// How many Q&A budget units this operation consumes.
  ///
  /// Most operations cost 0 because they are gated by feature flags
  /// (allowComparison, allowEmergencyAccess, etc.) rather than by a
  /// consumable budget. Only `ask_question` currently consumes from
  /// the Q&A budget.
  static int questionCost(String operation) => switch (operation) {
        askQuestion => 1,
        _ => 0,
      };

  /// Whether this operation consumes Q&A budget.
  static bool consumesBudget(String operation) => questionCost(operation) > 0;

  /// A human-readable label for display in usage breakdowns.
  static String displayLabel(String operation) => switch (operation) {
        askQuestion => 'Questions asked',
        uploadPolicy => 'Policy uploads',
        comparePolicies => 'Policy comparisons',
        familyView => 'Family view',
        cloudSync => 'Cloud sync',
        emergencyAccess => 'Emergency access',
        annualReview => 'Annual review',
        advancedSearch => 'Advanced search',
        _ => operation,
      };
}
