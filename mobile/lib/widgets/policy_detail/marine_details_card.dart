import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../shared/coverwise_components.dart';
import '../../theme/coverwise_theme.dart';

class MarineDetailsCard extends StatelessWidget {
  final MarinePolicyFields fields;

  const MarineDetailsCard({super.key, required this.fields});

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
                  icon: Icons.directions_boat_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Voyage & Cargo Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (fields.policyTypeMarine != null)
              _MarineDetailRow(
                icon: Icons.category_rounded,
                label: 'Policy Type',
                value: fields.policyTypeMarine!,
              ),
            if (fields.vesselName != null)
              _MarineDetailRow(
                icon: Icons.directions_boat_rounded,
                label: 'Vessel',
                value: fields.vesselName!,
              ),
            if (fields.conveyance != null)
              _MarineDetailRow(
                icon: Icons.local_shipping_rounded,
                label: 'Conveyance',
                value: fields.conveyance!,
              ),
            if (fields.voyageDetails != null)
              _MarineDetailRow(
                icon: Icons.route_rounded,
                label: 'Voyage',
                value: fields.voyageDetails!,
              ),
            if (fields.voyageFrom != null || fields.voyageTo != null)
              _MarineDetailRow(
                icon: Icons.map_rounded,
                label: 'Route',
                value: [
                  if (fields.voyageFrom != null) 'From: ${fields.voyageFrom}',
                  if (fields.voyageTo != null) 'To: ${fields.voyageTo}',
                ].join('  \u2022  '),
              ),
            if (fields.transitStartDate != null || fields.transitEndDate != null)
              _MarineDetailRow(
                icon: Icons.date_range_rounded,
                label: 'Transit Period',
                value: [
                  if (fields.transitStartDate != null) fields.transitStartDate!,
                  if (fields.transitStartDate != null &&
                      fields.transitEndDate != null)
                    ' — ',
                  if (fields.transitEndDate != null) fields.transitEndDate!,
                ].join(),
              ),
            if (fields.cargoDescription != null)
              _MarineDetailRow(
                icon: Icons.inventory_2_rounded,
                label: 'Cargo',
                value: fields.cargoDescription!,
              ),
            if (fields.cargoValue != null)
              _MarineDetailRow(
                icon: Icons.attach_money_rounded,
                label: 'Cargo Value',
                value: fields.cargoValue!,
                valueColor: cs.primary,
              ),
            if (fields.incoterms != null)
              _MarineDetailRow(
                icon: Icons.gavel_rounded,
                label: 'INCO Terms',
                value: fields.incoterms!,
              ),
            if (fields.instituteClauses != null)
              _MarineDetailRow(
                icon: Icons.description_rounded,
                label: 'Institute Clauses',
                value: fields.instituteClauses!,
              ),
            if (fields.marineInsuranceCertificateNo != null)
              _MarineDetailRow(
                icon: Icons.badge_rounded,
                label: 'Certificate No.',
                value: fields.marineInsuranceCertificateNo!,
              ),
            const SizedBox(height: 8),
            Text(
              'Key Clauses',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            if (fields.generalAverageClause != null)
              _MarineDetailRow(
                icon: Icons.balance_rounded,
                label: 'General Average',
                value: fields.generalAverageClause!,
              ),
            if (fields.warehouseToWarehouse != null)
              _MarineDetailRow(
                icon: Icons.warehouse_rounded,
                label: 'Whse-to-Whse',
                value: fields.warehouseToWarehouse!,
              ),
            if (fields.warRiskClause != null)
              _MarineDetailRow(
                icon: Icons.gpp_maybe_rounded,
                label: 'War Risk',
                value: fields.warRiskClause!,
              ),
            if (fields.strikesRiotsClause != null)
              _MarineDetailRow(
                icon: Icons.people_outline_rounded,
                label: 'Strikes / Riots',
                value: fields.strikesRiotsClause!,
              ),
          ],
        ),
      ),
    );
  }
}

class _MarineDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MarineDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CoverWiseColors.blueDeep.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: CoverWiseColors.blueDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: valueColor ?? cs.onSurface,
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
