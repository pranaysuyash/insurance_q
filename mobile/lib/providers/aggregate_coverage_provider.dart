import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/policy_type.dart';
import 'policy_providers.dart';

/// Aggregated portfolio coverage metrics across all processed policies.
class AggregateCoverageState {
  final double totalSumInsured;
  final int totalPolicies;
  final Map<String, double> coverageByType;
  final List<String> coordinationNotes;

  const AggregateCoverageState({
    required this.totalSumInsured,
    required this.totalPolicies,
    required this.coverageByType,
    required this.coordinationNotes,
  });

  String formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)} L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  String get formattedTotal => formatCurrency(totalSumInsured);
}

final aggregateCoverageProvider = Provider<AggregateCoverageState>((ref) {
  final summaries = ref.watch(policySummariesProvider);
  double total = 0.0;
  final byType = <String, double>{};
  final notes = <String>[];

  int healthCount = 0;
  for (final summary in summaries) {
    final amount = summary.coverageAmount ?? 0.0;
    total += amount;

    final type = canonicalTypeName(classifyPolicyType(summary.documentType));
    byType[type] = (byType[type] ?? 0.0) + amount;

    if (classifyPolicyType(summary.documentType) == PolicyType.health) {
      healthCount++;
    }
  }

  if (healthCount > 1) {
    notes.add(
      'You have $healthCount active health policies. Ensure cashless claims coordinate primary and super top-up limits.',
    );
  }

  return AggregateCoverageState(
    totalSumInsured: total,
    totalPolicies: summaries.length,
    coverageByType: byType,
    coordinationNotes: notes,
  );
});
