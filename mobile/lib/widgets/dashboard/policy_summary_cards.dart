import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../../utils/policy_type.dart';
import '../shared/policy_type_icon.dart';
import '../shared/coverwise_components.dart';
import '../../services/analytics_service.dart';

class PolicySummaryCards extends StatelessWidget {
  final List<PolicySummary> summaries;
  
  const PolicySummaryCards({super.key, required this.summaries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoverWiseSectionLabel('Your Policies'),
        const SizedBox(height: 12),
        ...summaries.map((s) => _PolicyCard(summary: s)),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final PolicySummary summary;
  
  const _PolicyCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View details for ${summary.documentType}',
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            AnalyticsService.track('dashboard_policy_tapped', {
              'policy_type': summary.documentType,
              'status': summary.isExpired 
                  ? 'expired' 
                  : summary.isExpiringSoon ? 'expiring' : 'active',
            });
            Navigator.pushNamed(context, '/policy-detail', arguments: summary.documentId);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PolicyTypeIcon(
                      type: classifyPolicyType(summary.documentType),
                      size: 52,
                      selected: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.documentType,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (summary.insurer != null)
                            Text(
                              summary.insurer!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    _StatusBadge(summary: summary),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (summary.formattedCoverageAmount != 'Unknown') ...[
                      _MetricChip(Icons.shield, 'Coverage',
                          summary.formattedCoverageAmount),
                      const SizedBox(width: 12),
                    ],
                    if (summary.formattedPremium != 'Unknown') ...[
                      _MetricChip(
                          Icons.payments, 'Premium', summary.formattedPremium),
                      const SizedBox(width: 12),
                    ],
                    if (summary.formattedExpiryDate != 'Unknown')
                      _MetricChip(
                          Icons.event, 'Expires', summary.formattedExpiryDate),
                  ],
                ),
                if (summary.policyNumber != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Policy: ${summary.policyNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PolicySummary summary;
  const _StatusBadge({required this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = summary.isExpired
        ? ('EXPIRED', scheme.error)
        : summary.isExpiringSoon
            ? ('${summary.daysUntilExpiry}d LEFT', scheme.tertiary)
            : ('ACTIVE', scheme.primary);

    return CoverWiseStatusChip(
      icon: summary.isExpired
          ? Icons.error_rounded
          : summary.isExpiringSoon
              ? Icons.schedule_rounded
              : Icons.check_circle_rounded,
      label: label,
      color: color,
      compact: true,
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetricChip(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ],
        ),
        Text(value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }
}
