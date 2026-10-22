import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../shared/coverwise_components.dart';
import '../../theme/coverwise_theme.dart';

class HealthDetailsCard extends StatelessWidget {
  final HealthPolicyFields fields;

  const HealthDetailsCard({super.key, required this.fields});

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
                const CoverWiseIconBadge(
                  icon: Icons.monitor_heart_outlined,
                  color: CoverWiseColors.blueDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Health Insurance Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (fields.roomRentCap != null)
              _HealthDetailRow(
                icon: Icons.bed_rounded,
                label: 'Room Rent Cap',
                value: fields.roomRentCap!,
              ),
            if (fields.coPayPercent != null)
              _HealthDetailRow(
                icon: Icons.percent_rounded,
                label: 'Co-pay',
                value: '${fields.coPayPercent!.toStringAsFixed(0)}%',
                valueColor: cs.error,
              ),
            if (fields.deductiblePerClaim != null)
              _HealthDetailRow(
                icon: Icons.money_off_rounded,
                label: 'Deductible per claim',
                value: '₹${_formatHealthAmount(fields.deductiblePerClaim!)}',
              ),
            if (fields.ambulanceCover != null)
              _HealthDetailRow(
                icon: Icons.local_hospital_rounded,
                label: 'Ambulance Cover',
                value: '₹${_formatHealthAmount(fields.ambulanceCover!)}',
                valueColor: cs.primary,
              ),
            if (fields.networkHospitals != null)
              _HealthDetailRow(
                icon: Icons.local_hotel_rounded,
                label: 'Network Hospitals',
                value: fields.networkHospitals!,
              ),
            if (fields.maternityCover != null)
              _HealthDetailRow(
                icon: Icons.child_friendly_rounded,
                label: 'Maternity Cover',
                value: fields.maternityCover!,
              ),
            if (fields.cumulativeBonus != null)
              _HealthDetailRow(
                icon: Icons.trending_up_rounded,
                label: 'Cumulative Bonus',
                value: fields.cumulativeBonus!,
              ),
            if (fields.dayCareProcedures != null)
              _HealthDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Day Care Procedures',
                value: fields.dayCareProcedures!,
              ),
            if (fields.consumablesCover != null)
              _HealthDetailRow(
                icon: Icons.medical_services_rounded,
                label: 'Consumables Cover',
                value: fields.consumablesCover!,
              ),
            if (fields.healthCheckupCover != null)
              _HealthDetailRow(
                icon: Icons.favorite_border_rounded,
                label: 'Health Checkup',
                value: fields.healthCheckupCover!,
              ),
            if (fields.prePostHospitalizationDays != null)
              _HealthDetailRow(
                icon: Icons.access_time_rounded,
                label: 'Pre/Post Hospitalization',
                value: fields.prePostHospitalizationDays!,
              ),
            if (fields.restorationBenefit != null)
              _HealthDetailRow(
                icon: Icons.refresh_rounded,
                label: 'Restoration Benefit',
                value: fields.restorationBenefit!,
                valueColor: cs.primary,
              ),
            if (fields.modernTreatmentCover != null)
              _HealthDetailRow(
                icon: Icons.biotech_rounded,
                label: 'Modern Treatments',
                value: fields.modernTreatmentCover!,
              ),
            if (fields.moratoriumPeriod != null)
              _HealthDetailRow(
                icon: Icons.verified_user_rounded,
                label: 'Moratorium Period',
                value: fields.moratoriumPeriod!,
              ),
            if (fields.preAuthTimeLimit != null)
              _HealthDetailRow(
                icon: Icons.flash_on_rounded,
                label: 'Cashless Approval Time',
                value: fields.preAuthTimeLimit!,
                valueColor: cs.primary,
              ),
            if (fields.domiciliaryHospitalization != null)
              _HealthDetailRow(
                icon: Icons.home_rounded,
                label: 'Home Hospitalization',
                value: fields.domiciliaryHospitalization!,
              ),
            if (fields.subLimits.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Coverage Sub-limits',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: fields.subLimits
                    .map((limit) => Chip(
                          label:
                              Text(limit, style: const TextStyle(fontSize: 12)),
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
            if (fields.noClaimBonusPercent != null)
              _HealthDetailRow(
                icon: Icons.trending_up_rounded,
                label: 'NCB (No Claim Bonus)',
                value:
                    '${fields.noClaimBonusPercent!.toStringAsFixed(0)}% per claim-free year',
                valueColor: cs.primary,
              ),
            if (fields.criticalIllnessList.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Covered Critical Illnesses',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...fields.criticalIllnessList.map((ci) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ci,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (fields.preExistingDiseases.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Pre-existing Disease Waiting Periods',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...fields.preExistingDiseases.map((disease) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            disease,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatHealthAmount(double amount) {
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

class _HealthDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _HealthDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
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
      padding: const EdgeInsets.only(bottom: 10),
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
                labelWidget,
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
