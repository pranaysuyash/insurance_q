import 'package:flutter/material.dart';
import '../../models/entitlement.dart';
import '../../models/operation_cost.dart';

/// A card showing how the user's Q&A budget was spent, broken down
/// by operation type (M18: Cost Attribution).
///
/// Displays each operation that consumed budget alongside the total
/// remaining. Shows a "no usage yet" state when [operationUsage] is empty.
class OperationUsageCard extends StatelessWidget {
  final Entitlement entitlement;

  const OperationUsageCard({super.key, required this.entitlement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Only show operations that have non-zero usage or are budget-consuming.
    final trackedOps = OperationCost.allOperations
        .where((op) =>
            OperationCost.consumesBudget(op) ||
            (entitlement.operationUsage[op] ?? 0) > 0)
        .toList();

    if (trackedOps.isEmpty && !entitlement.hasOperationUsage) {
      return _buildEmptyState(theme, scheme);
    }

    final totalRemaining = entitlement.subscriptionQuestionsRemaining;
    final totalUsed = entitlement.questionsUsedThisMonth;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Usage breakdown',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                'How your Q&A budget was used this period',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Summary bar
            if (totalUsed > 0 || totalRemaining > 0) ...[
              _SummaryBar(
                used: totalUsed,
                remaining: totalRemaining,
                total: totalUsed + totalRemaining,
                theme: theme,
                scheme: scheme,
              ),
              const SizedBox(height: 12),
            ],
            // Per-operation breakdown
            ...trackedOps.map((op) {
              final count = entitlement.operationCount(op);
              final label = OperationCost.displayLabel(op);
              final cost = OperationCost.questionCost(op);
              return _UsageRow(
                label: label,
                count: count,
                costPerUse: cost,
                theme: theme,
                scheme: scheme,
              );
            }),
            // Footer note
            const SizedBox(height: 8),
            Text(
              'Each question you ask costs 1 Q&A unit from your monthly or pack budget.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 20,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Usage stats will appear here after you ask a question.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int used;
  final int remaining;
  final int total;
  final ThemeData theme;
  final ColorScheme scheme;

  const _SummaryBar({
    required this.used,
    required this.remaining,
    required this.total,
    required this.theme,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final usedFraction = total > 0 ? used / total : 0.0;
    final remainingFraction = total > 0 ? remaining / total : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            width: double.infinity,
            child: Row(
              children: [
                if (usedFraction > 0)
                  Flexible(
                    flex: (usedFraction * 100).round().clamp(1, 100),
                    child: Container(
                      color: scheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                if (remainingFraction > 0)
                  Flexible(
                    flex: (remainingFraction * 100).round().clamp(1, 100),
                    child: Container(
                      color: scheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$used used',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$remaining remaining',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageRow extends StatelessWidget {
  final String label;
  final int count;
  final int costPerUse;
  final ThemeData theme;
  final ColorScheme scheme;

  const _UsageRow({
    required this.label,
    required this.count,
    required this.costPerUse,
    required this.theme,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            costPerUse > 0 ? Icons.chat_bubble_outline_rounded : Icons.lock_outline_rounded,
            size: 16,
            color: costPerUse > 0 ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (costPerUse > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count used',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: count > 0 ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              count > 0 ? '$count' : '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
