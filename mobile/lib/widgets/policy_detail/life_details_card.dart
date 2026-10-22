import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../../utils/policy_type.dart';
import '../shared/coverwise_components.dart';
import 'provision_row.dart';

class LifeDetailsCard extends StatelessWidget {
  final LifePolicyFields fields;

  const LifeDetailsCard({super.key, required this.fields});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = <_LifeDetailItem>[
      if (fields.lifeAssuredName != null)
        _LifeDetailItem(
          icon: Icons.person_rounded,
          label: 'Life Assured',
          value: fields.lifeAssuredName!,
        ),
      if (fields.sumAssured != null)
        _LifeDetailItem(
          icon: Icons.account_balance_rounded,
          label: 'Sum Assured',
          value: '₹${_formatLifeAmount(fields.sumAssured!)}',
          valueColor: cs.primary,
          tooltip:
              'The amount the insurer will pay to the nominee upon the death of the life assured or at policy maturity.',
        ),
      if (fields.policyTermYears != null)
        _LifeDetailItem(
          icon: Icons.timeline_rounded,
          label: 'Policy Term',
          value: '${fields.policyTermYears} years',
        ),
      if (fields.premiumPayingTermYears != null)
        _LifeDetailItem(
          icon: Icons.payments_rounded,
          label: 'Premium Paying Term',
          value: '${fields.premiumPayingTermYears} years',
        ),
      if (fields.nomineeName != null)
        _LifeDetailItem(
          icon: Icons.favorite_rounded,
          label: 'Nominee',
          value: fields.nomineeName! +
              (fields.nomineeShare != null ? ' (${fields.nomineeShare})' : ''),
          valueColor: cs.error,
        ),
      if (fields.maturityDate != null)
        _LifeDetailItem(
          icon: Icons.event_rounded,
          label: 'Maturity Date',
          value: fields.maturityDate!,
        ),
      if (fields.maturityAmount != null)
        _LifeDetailItem(
          icon: Icons.savings_rounded,
          label: 'Maturity Amount',
          value: '₹${_formatLifeAmount(fields.maturityAmount!)}',
        ),
      if (fields.accidentalDeathBenefit != null)
        _LifeDetailItem(
          icon: Icons.shield_rounded,
          label: 'Accidental Death Benefit',
          value: '₹${_formatLifeAmount(fields.accidentalDeathBenefit!)}',
          valueColor: cs.primary,
          tooltip:
              'An additional payout over and above the basic sum assured if death is caused by an accident.',
        ),
      if (fields.terminalIllnessBenefit != null)
        _LifeDetailItem(
          icon: Icons.medical_services_rounded,
          label: 'Terminal Illness Benefit',
          value: fields.terminalIllnessBenefit!,
        ),
      if (fields.deathBenefitType != null)
        _LifeDetailItem(
          icon: Icons.category_rounded,
          label: 'Death Benefit Type',
          value: fields.deathBenefitType!,
        ),
      if (fields.policyTypeDetail != null)
        _LifeDetailItem(
          icon: Icons.account_tree_rounded,
          label: 'Policy Sub-type',
          value: fields.policyTypeDetail!,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

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
                  icon: Icons.person_rounded,
                  color: colorForPolicyType(PolicyType.life,
                      brightness: theme.brightness),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Life Insurance Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _LifeDetailRow(item: item)),
            if (fields.riderDetails.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Riders & Add-ons',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: fields.riderDetails
                    .map((rider) => Chip(
                          label:
                              Text(rider, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                          backgroundColor: cs.primary.withValues(alpha: 0.1),
                          labelStyle: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (fields.suicideExclusion != null ||
                fields.freeLookPeriod != null ||
                fields.gracePeriod != null ||
                fields.surrenderValue != null) ...[
              const Divider(height: 24),
              Text(
                'Policy Provisions',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (fields.suicideExclusion != null)
                ProvisionRow(
                  icon: Icons.block_rounded,
                  label: 'Suicide Exclusion',
                  value: fields.suicideExclusion!,
                ),
              if (fields.freeLookPeriod != null)
                ProvisionRow(
                  icon: Icons.remove_red_eye_rounded,
                  label: 'Free Look Period',
                  value: fields.freeLookPeriod!,
                ),
              if (fields.gracePeriod != null)
                ProvisionRow(
                  icon: Icons.schedule_rounded,
                  label: 'Grace Period',
                  value: fields.gracePeriod!,
                ),
              if (fields.surrenderValue != null)
                ProvisionRow(
                  icon: Icons.monetization_on_rounded,
                  label: 'Surrender Value',
                  value: fields.surrenderValue!,
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatLifeAmount(double amount) {
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

class _LifeDetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? tooltip;

  const _LifeDetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.tooltip,
  });
}

class _LifeDetailRow extends StatelessWidget {
  final _LifeDetailItem item;
  const _LifeDetailRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelWidget = Text(
      item.label,
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
              color: colorForPolicyType(PolicyType.life,
                      brightness: Theme.of(context).brightness)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: colorForPolicyType(PolicyType.life,
                  brightness: Theme.of(context).brightness),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item.tooltip != null
                    ? Tooltip(
                        message: item.tooltip!,
                        triggerMode: TooltipTriggerMode.longPress,
                        child: labelWidget,
                      )
                    : labelWidget,
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.valueColor ?? theme.colorScheme.onSurface,
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
