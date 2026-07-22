import 'package:flutter/material.dart';
import '../models/policy_summary.dart';
import 'shared/coverwise_components.dart';

/// Grounded Policy Readiness Card for CoverWise.
///
/// Replaces ungrounded health scores and coverage gap heuristics with
/// grounded indicators derived from actual extracted policy metadata and citations.
class PolicyReadinessCard extends StatelessWidget {
  final List<PolicySummary> summaries;
  final VoidCallback? onTapViewPolicies;

  const PolicyReadinessCard({
    super.key,
    required this.summaries,
    this.onTapViewPolicies,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPolicies = summaries.length;
    final activeCount = summaries.where((s) => s.isActive).length;
    final expiringCount = summaries.where((s) => s.isExpiringSoon).length;
    final expiredCount = summaries.where((s) => s.isExpired).length;

    // Check how many summaries have all core fields identified
    final completeReadinessCount = summaries.where((s) {
      return s.insurer != null &&
          s.insurer!.isNotEmpty &&
          s.policyNumber != null &&
          s.policyNumber!.isNotEmpty &&
          s.startDate != null &&
          s.endDate != null;
    }).length;

    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Policy Readiness',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$completeReadinessCount of $totalPolicies policies fully verified from source',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Readiness Breakdown Rows
            _ReadinessRow(
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
              title: 'Identified Policies',
              value: '$activeCount Active',
            ),
            const SizedBox(height: 8),
            _ReadinessRow(
              icon: expiringCount > 0 ? Icons.access_time_filled : Icons.event_available,
              iconColor: expiringCount > 0 ? Colors.orange : Colors.blue,
              title: 'Renewal Status',
              value: expiringCount > 0
                  ? '$expiringCount Expiring Soon'
                  : expiredCount > 0
                      ? '$expiredCount Expired'
                      : 'All Up to Date',
            ),
            const SizedBox(height: 8),
            _ReadinessRow(
              icon: Icons.description_outlined,
              iconColor: theme.colorScheme.primary,
              title: 'Source Documents',
              value: '$totalPolicies Linked PDF / Images',
            ),

            if (onTapViewPolicies != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTapViewPolicies,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View Policy Readiness Details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _ReadinessRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
