import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../shared/coverwise_components.dart';
import '../../theme/coverwise_theme.dart';

class HomeDetailsCard extends StatelessWidget {
  final HomePolicyFields fields;

  const HomeDetailsCard({super.key, required this.fields});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoverWiseIconBadge(
                  icon: Icons.home_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Home Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (fields.propertyAddress != null)
              _HomeDetailRow(
                icon: Icons.location_on_rounded,
                label: 'Property Address',
                value: fields.propertyAddress!,
              ),
            if (fields.structureType != null || fields.policyType != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (fields.structureType != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          fields.structureType!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (fields.policyType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          fields.policyType!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.tertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (fields.buildingSumInsured != null)
              _HomeDetailRow(
                icon: Icons.business_rounded,
                label: 'Building',
                value: '₹${_formatHomeAmount(fields.buildingSumInsured!)}',
                valueColor: cs.primary,
              ),
            if (fields.contentsSumInsured != null)
              _HomeDetailRow(
                icon: Icons.inventory_2_rounded,
                label: 'Contents',
                value: '₹${_formatHomeAmount(fields.contentsSumInsured!)}',
                valueColor: cs.primary,
              ),
            if (fields.rebuildCost != null)
              _HomeDetailRow(
                icon: Icons.construction_rounded,
                label: 'Rebuild Cost',
                value: '₹${_formatHomeAmount(fields.rebuildCost!)}',
                valueColor: cs.primary,
              ),
            if (fields.deductible != null)
              _HomeDetailRow(
                icon: Icons.money_off_rounded,
                label: 'Deductible',
                value: '₹${_formatHomeAmount(fields.deductible!)}',
                tooltip:
                    'The amount you must pay out of pocket before coverage kicks in.',
              ),
            if (fields.perilsCovered.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Perils Covered',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: fields.perilsCovered
                    .map((peril) => Chip(
                          label:
                              Text(peril, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                          backgroundColor: cs.primary.withValues(alpha: 0.1),
                          avatar: Icon(Icons.check_rounded,
                              size: 14, color: cs.primary),
                          labelStyle: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (fields.perilsExcluded.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Excluded perils',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.error,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: fields.perilsExcluded
                    .map((peril) => Chip(
                          label:
                              Text(peril, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                          backgroundColor: cs.error.withValues(alpha: 0.1),
                          avatar: Icon(Icons.close_rounded,
                              size: 14, color: cs.error),
                          labelStyle: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (fields.occupancyType != null || fields.constructionType != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (fields.occupancyType != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          fields.occupancyType!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (fields.constructionType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          fields.constructionType!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (fields.underinsuranceClause != null)
              _HomeDetailRow(
                icon: Icons.warning_rounded,
                label: 'Underinsurance Clause',
                value: fields.underinsuranceClause!,
                valueColor: cs.error,
              ),
            if (fields.yearBuilt != null)
              _HomeDetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Year Built',
                value: fields.yearBuilt!.toString(),
              ),
            if (fields.escalationClause != null)
              _HomeDetailRow(
                icon: Icons.trending_up_rounded,
                label: 'Escalation Clause',
                value: fields.escalationClause!,
                valueColor: cs.primary,
              ),
            if (fields.addOnCovers.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Add-on covers',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: fields.addOnCovers
                    .map((cover) => Chip(
                          label:
                              Text(cover, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                          backgroundColor: cs.tertiary.withValues(alpha: 0.1),
                          labelStyle: TextStyle(
                            color: cs.tertiary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatHomeAmount(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)} L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _HomeDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? tooltip;

  const _HomeDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelWidget = Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CoverWiseColors.blueDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: CoverWiseColors.blueDeep,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tooltip != null
                    ? Tooltip(
                        message: tooltip!,
                        triggerMode: TooltipTriggerMode.longPress,
                        child: labelWidget,
                      )
                    : labelWidget,
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
