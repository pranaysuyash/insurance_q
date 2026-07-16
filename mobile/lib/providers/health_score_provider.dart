import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_state_repository.dart';
import 'policy_providers.dart';

/// Insurance Health Score — at-a-glance "are we covered?" for the whole family.
///
/// The score (0–100) is derived from:
/// - Policy count and active status (25 pts)
/// - Coverage gap resolution (25 pts)
/// - Family member coverage breadth (25 pts)
/// - Policy diversity across types (25 pts)
class InsuranceHealthScore {
  final int score;
  final String label;
  final String summary;
  final List<HealthScoreFactor> factors;

  const InsuranceHealthScore({
    required this.score,
    required this.label,
    required this.summary,
    required this.factors,
  });
}

class HealthScoreFactor {
  final String title;
  final int points;
  final int maxPoints;
  final String detail;
  final bool isPositive;

  const HealthScoreFactor({
    required this.title,
    required this.points,
    required this.maxPoints,
    required this.detail,
    required this.isPositive,
  });
}

/// Computes the Insurance Health Score from policy summaries and coverage gaps.
final healthScoreProvider = Provider<InsuranceHealthScore>((ref) {
  final summaries = ref.watch(policySummariesProvider);
  final gaps = ref.watch(coverageGapsProvider);
  final resolvedGapIds = AppStateRepository.getResolvedGaps().keys;
  final resolvedCount = gaps.where((g) => resolvedGapIds.contains(g.gapId)).length;
  final totalGaps = gaps.length;

  // Factor 1: Policy coverage (25 pts)
  final activeCount = summaries.where((s) => s.isActive).length;
  final policyScore = summaries.isEmpty
      ? 0
      : (activeCount / summaries.length * 25).round().clamp(0, 25);

  // Factor 2: Gap resolution (25 pts)
  final gapScore = totalGaps == 0
      ? 25
      : (resolvedCount / totalGaps * 25).round().clamp(0, 25);

  // Factor 3: Coverage breadth — how many policy types are covered (25 pts)
  final types = summaries.map((s) => s.documentType.toLowerCase()).toSet();
  final idealTypes = {'health', 'motor', 'life'}; // Minimum for a family
  final coveredIdeal = idealTypes.intersection(types).length;
  final breadthScore = (coveredIdeal / idealTypes.length * 25).round().clamp(0, 25);

  // Factor 4: Expiry health — no expired policies (25 pts)
  final expiredCount = summaries.where((s) => s.isExpired).length;
  final expiringCount = summaries.where((s) => s.isExpiringSoon).length;
  final expiryScore = summaries.isEmpty
      ? 0
      : ((summaries.length - expiredCount - expiringCount) /
              summaries.length *
              25)
          .round()
          .clamp(0, 25);

  final total = policyScore + gapScore + breadthScore + expiryScore;

  // Build factors
  final factors = <HealthScoreFactor>[
    HealthScoreFactor(
      title: 'Active Policies',
      points: policyScore,
      maxPoints: 25,
      detail: summaries.isEmpty
          ? 'No policies uploaded yet'
          : '$activeCount of ${summaries.length} policies active',
      isPositive: activeCount == summaries.length,
    ),
    HealthScoreFactor(
      title: 'Coverage Gaps',
      points: gapScore,
      maxPoints: 25,
      detail: totalGaps == 0
          ? 'No gaps detected'
          : '$resolvedCount of $totalGaps gaps addressed',
      isPositive: resolvedCount == totalGaps,
    ),
    HealthScoreFactor(
      title: 'Coverage Breadth',
      points: breadthScore,
      maxPoints: 25,
      detail: types.isEmpty
          ? 'No policy types'
          : '${coveredIdeal} of 3 essential types covered (${types.join(", ")})',
      isPositive: coveredIdeal >= 3,
    ),
    HealthScoreFactor(
      title: 'Renewal Health',
      points: expiryScore,
      maxPoints: 25,
      detail: summaries.isEmpty
          ? 'No policies to check'
          : expiredCount > 0
              ? '$expiredCount expired, $expiringCount expiring soon'
              : expiringCount > 0
                  ? '$expiringCount expiring soon'
                  : 'All policies up to date',
      isPositive: expiredCount == 0 && expiringCount == 0,
    ),
  ];

  // Label
  final label = total >= 80
      ? 'Excellent'
      : total >= 60
          ? 'Good'
          : total >= 40
              ? 'Needs Attention'
              : 'At Risk';

  // Summary
  final summary = summaries.isEmpty
      ? 'Upload your first policy to see your insurance health score.'
      : total >= 80
          ? 'Your insurance coverage is strong across the board.'
          : total >= 60
              ? 'Good coverage overall. ${expiredCount > 0 ? "Renew expired policies." : expiringCount > 0 ? "Some policies expiring soon." : "Consider adding more policy types."}'
              : 'Your coverage needs attention.'
                  '${expiredCount > 0 ? ' $expiredCount policies expired.' : ''}'
                  '${totalGaps - resolvedCount > 0 ? ' ${totalGaps - resolvedCount} coverage gaps open.' : ''}';

  return InsuranceHealthScore(
    score: total,
    label: label,
    summary: summary,
    factors: factors,
  );
});
