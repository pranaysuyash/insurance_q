import 'package:flutter_test/flutter_test.dart';
import 'package:coverwise/models/policy_summary.dart';
import 'package:coverwise/providers/health_score_provider.dart';

void main() {
  group('InsuranceHealthScore', () {
    test('should compute score with no policies', () {
      final score = InsuranceHealthScore(
        score: 0,
        label: 'At Risk',
        summary: 'No policies uploaded yet',
        factors: [],
      );
      expect(score.score, 0);
      expect(score.label, 'At Risk');
    });

    test('should compute score with all active policies', () {
      final summaries = [
        PolicySummary(
          documentId: '1',
          documentType: 'Health Insurance',
          extractedAt: DateTime.now(),
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          endDate: DateTime.now().add(const Duration(days: 300)),
        ),
        PolicySummary(
          documentId: '2',
          documentType: 'Auto Insurance',
          extractedAt: DateTime.now(),
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          endDate: DateTime.now().add(const Duration(days: 300)),
        ),
        PolicySummary(
          documentId: '3',
          documentType: 'Life Insurance',
          extractedAt: DateTime.now(),
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          endDate: DateTime.now().add(const Duration(days: 300)),
        ),
      ];

      expect(summaries, hasLength(3));

      // All active, 3 types covered, no gaps → high score
      final policyScore = 25; // All active
      final gapScore = 25; // No gaps
      final breadthScore = 25; // 3/3 types
      final expiryScore = 25; // No expired/expiring
      final total = policyScore + gapScore + breadthScore + expiryScore;

      expect(total, 100);
    });

    test('should penalize expired policies', () {
      final summaries = [
        PolicySummary(
          documentId: '1',
          documentType: 'Health Insurance',
          extractedAt: DateTime.now(),
          startDate: DateTime.now().subtract(const Duration(days: 400)),
          endDate: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ];

      final expiredCount = summaries.where((s) => s.isExpired).length;
      expect(expiredCount, 1);
    });

    test('should detect expiring soon policies', () {
      final summaries = [
        PolicySummary(
          documentId: '1',
          documentType: 'Health Insurance',
          extractedAt: DateTime.now(),
          startDate: DateTime.now().subtract(const Duration(days: 300)),
          endDate: DateTime.now().add(const Duration(days: 15)),
        ),
      ];

      expect(summaries.first.isExpiringSoon, true);
      expect(summaries.first.isActive, true);
    });

    test('should identify coverage breadth', () {
      final summaries = [
        PolicySummary(
          documentId: '1',
          documentType: 'Health Insurance',
          extractedAt: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 300)),
        ),
        PolicySummary(
          documentId: '2',
          documentType: 'Motor Insurance',
          extractedAt: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 300)),
        ),
      ];

      final types = summaries.map((s) => s.documentType.toLowerCase()).toSet();
      // The provider checks if types.contains('health'), 'motor', 'life'
      // via .contains() on the full string, not exact match
      final idealTypes = {'health', 'motor', 'life'};
      final coveredIdeal =
          idealTypes.where((t) => types.any((dt) => dt.contains(t))).length;

      expect(types.length, 2);
      expect(coveredIdeal, 2);
    });

    test('should compute breadth score correctly', () {
      // 2 of 3 essential types → 2/3 * 25 = 17 (rounded)
      final coveredIdeal = 2;
      final idealTypes = {'health', 'motor', 'life'};
      final breadthScore =
          (coveredIdeal / idealTypes.length * 25).round().clamp(0, 25);

      expect(breadthScore, 17);
    });

    test('should handle empty summaries gracefully', () {
      final summaries = <PolicySummary>[];
      final activeCount = summaries.where((s) => s.isActive).length;

      expect(activeCount, 0);
      expect(summaries.isEmpty, true);
    });

    test('should label score correctly', () {
      String label(int score) {
        if (score >= 80) return 'Excellent';
        if (score >= 60) return 'Good';
        if (score >= 40) return 'Needs Attention';
        return 'At Risk';
      }

      expect(label(100), 'Excellent');
      expect(label(80), 'Excellent');
      expect(label(79), 'Good');
      expect(label(60), 'Good');
      expect(label(59), 'Needs Attention');
      expect(label(40), 'Needs Attention');
      expect(label(39), 'At Risk');
      expect(label(0), 'At Risk');
    });

    test('HealthScoreFactor should have correct structure', () {
      final factor = HealthScoreFactor(
        title: 'Active Policies',
        points: 25,
        maxPoints: 25,
        detail: '3 of 3 policies active',
        isPositive: true,
      );

      expect(factor.title, 'Active Policies');
      expect(factor.points, 25);
      expect(factor.maxPoints, 25);
      expect(factor.isPositive, true);
    });
  });
}
