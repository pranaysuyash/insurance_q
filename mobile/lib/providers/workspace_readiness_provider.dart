import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_state_repository.dart';
import 'policy_providers.dart';

/// Policy workspace readiness — an at-a-glance view of whether uploaded
/// records are current and ready for review.
///
/// This intentionally does not assess whether a household has enough
/// insurance. The score is derived only from observable workspace facts:
/// - policy dates and active status (25 pts)
/// - review-question resolution (25 pts)
/// - extracted policy identity/details (25 pts)
/// - expiry timing (25 pts)
class WorkspaceReadinessScore {
  final int score;
  final String label;
  final String summary;
  final List<HealthScoreFactor> factors;

  const WorkspaceReadinessScore({
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

/// Computes policy workspace readiness from policy summaries and review
/// questions. Missing evidence is surfaced as a question, never as proof that
/// the user lacks a policy.
final workspaceReadinessProvider = Provider<WorkspaceReadinessScore>((ref) {
  final summaries = ref.watch(policySummariesProvider);
  final gaps = ref.watch(coverageGapsProvider);
  final resolvedGapIds = AppStateRepository.getResolvedGaps().keys;
  final resolvedCount =
      gaps.where((g) => resolvedGapIds.contains(g.gapId)).length;
  final totalGaps = gaps.length;

  // Factor 1: Policy date state (25 pts)
  final activeCount = summaries.where((s) => s.isActive).length;
  final policyScore = summaries.isEmpty
      ? 0
      : (activeCount / summaries.length * 25).round().clamp(0, 25);

  // Factor 2: Review-question resolution (25 pts)
  final gapScore = totalGaps == 0
      ? 25
      : (resolvedCount / totalGaps * 25).round().clamp(0, 25);

  // Factor 3: Extracted details (25 pts). This measures record usefulness,
  // not policy quality or breadth.
  final completeDetails = summaries.where((s) {
    return s.documentType.trim().isNotEmpty &&
        (s.insurer?.trim().isNotEmpty ?? false) &&
        s.startDate != null &&
        s.endDate != null;
  }).length;
  final detailsScore = summaries.isEmpty
      ? 0
      : (completeDetails / summaries.length * 25).round().clamp(0, 25);

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

  final total = policyScore + gapScore + detailsScore + expiryScore;

  // Build factors
  final factors = <HealthScoreFactor>[
    HealthScoreFactor(
      title: 'Policy dates',
      points: policyScore,
      maxPoints: 25,
      detail: summaries.isEmpty
          ? 'No policies uploaded yet'
          : '$activeCount of ${summaries.length} policy records currently active',
      isPositive: activeCount == summaries.length,
    ),
    HealthScoreFactor(
      title: 'Review questions',
      points: gapScore,
      maxPoints: 25,
      detail: totalGaps == 0
          ? 'No review questions currently generated'
          : '$resolvedCount of $totalGaps questions addressed',
      isPositive: resolvedCount == totalGaps,
    ),
    HealthScoreFactor(
      title: 'Extracted policy details',
      points: detailsScore,
      maxPoints: 25,
      detail: summaries.isEmpty
          ? 'No policy records uploaded'
          : '$completeDetails of ${summaries.length} records have key identity and date fields',
      isPositive: completeDetails == summaries.length,
    ),
    HealthScoreFactor(
      title: 'Expiry timing',
      points: expiryScore,
      maxPoints: 25,
      detail: summaries.isEmpty
          ? 'No policies to check'
          : expiredCount > 0
              ? '$expiredCount expired, $expiringCount expiring soon'
              : expiringCount > 0
                  ? '$expiringCount expiring soon'
                  : 'No expiry dates need attention',
      isPositive: expiredCount == 0 && expiringCount == 0,
    ),
  ];

  // Label
  final label = total >= 80
      ? 'Ready to review'
      : total >= 60
          ? 'Mostly ready'
          : total >= 40
              ? 'Some details to review'
              : 'More information needed';

  // Summary
  final summary = summaries.isEmpty
      ? 'Upload a policy to see how ready your workspace is for review.'
      : total >= 80
          ? 'Your uploaded policy records are current and well prepared for review.'
          : total >= 60
              ? 'Some uploaded details need review. ${expiredCount > 0 ? "$expiredCount records have expired dates." : expiringCount > 0 ? "$expiringCount records expire soon." : "Check the open review questions."}'
              : 'Your workspace needs more review.'
                  '${expiredCount > 0 ? ' $expiredCount records have expired dates.' : ''}'
                  '${totalGaps - resolvedCount > 0 ? ' ${totalGaps - resolvedCount} review questions are open.' : ''}';

  return WorkspaceReadinessScore(
    score: total,
    label: label,
    summary: summary,
    factors: factors,
  );
});
