import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../shared/coverwise_components.dart';
import '../../theme/coverwise_theme.dart';

class VehicleDetailsCard extends StatelessWidget {
  final MotorPolicyFields fields;

  const VehicleDetailsCard({super.key, required this.fields});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = <_VehicleDetailItem>[
      if (fields.vehicleRegistrationNumber != null)
        _VehicleDetailItem(
          icon: Icons.numbers_rounded,
          label: 'Registration No.',
          value: fields.vehicleRegistrationNumber!,
        ),
      if (fields.vin != null)
        _VehicleDetailItem(
          icon: Icons.qr_code_rounded,
          label: 'VIN / Chassis No.',
          value: fields.vin!,
          isMonospace: true,
        ),
      if (fields.engineNumber != null)
        _VehicleDetailItem(
          icon: Icons.precision_manufacturing_rounded,
          label: 'Engine No.',
          value: fields.engineNumber!,
          isMonospace: true,
        ),
      if (fields.vehicleMakeModel != null)
        _VehicleDetailItem(
          icon: Icons.directions_car_rounded,
          label: 'Make / Model',
          value: fields.vehicleMakeModel!,
        ),
      if (fields.vehicleYear != null)
        _VehicleDetailItem(
          icon: Icons.calendar_view_week_rounded,
          label: 'Year',
          value: fields.vehicleYear!.toString(),
        ),
      if (fields.ncbPercent != null)
        _VehicleDetailItem(
          icon: Icons.trending_up_rounded,
          label: 'NCB (No Claim Bonus)',
          value: '${fields.ncbPercent!.toStringAsFixed(0)}%',
          valueColor: cs.primary,
          tooltip:
              'A discount on your premium for every claim-free year. A higher NCB percentage means a lower premium at renewal.',
        ),
      if (fields.idv != null)
        _VehicleDetailItem(
          icon: Icons.account_balance_rounded,
          label: 'IDV (Insured Declared Value)',
          value: '₹${_formatAmount(fields.idv!)}',
          valueColor: cs.primary,
          tooltip:
              'The maximum amount your insurer will pay if your vehicle is stolen or completely damaged.',
        ),
      if (fields.ownDamagePremium != null)
        _VehicleDetailItem(
          icon: Icons.payments_rounded,
          label: 'Own Damage Premium',
          value: '₹${_formatAmount(fields.ownDamagePremium!)}',
          tooltip:
              'The portion of your premium that covers damage to your own vehicle.',
        ),
      if (fields.thirdPartyPremium != null)
        _VehicleDetailItem(
          icon: Icons.people_rounded,
          label: 'Third Party Premium',
          value: '₹${_formatAmount(fields.thirdPartyPremium!)}',
          tooltip:
              'The portion of your premium that covers damage you cause to other people, their vehicles, or property.',
        ),
      if (fields.policyTypeDetail != null)
        _VehicleDetailItem(
          icon: Icons.category_rounded,
          label: 'Policy Type',
          value: fields.policyTypeDetail!,
          tooltip:
              'Comprehensive covers both own damage and third-party liability.',
        ),
      if (fields.geographicalLimit != null)
        _VehicleDetailItem(
          icon: Icons.public_rounded,
          label: 'Geographical Limit',
          value: fields.geographicalLimit!,
        ),
      if (fields.personalAccidentCoverOwner != null)
        _VehicleDetailItem(
          icon: Icons.person_rounded,
          label: 'PA Cover (Owner)',
          value: '₹${_formatAmount(fields.personalAccidentCoverOwner!)}',
          valueColor: cs.primary,
        ),
      if (fields.cubicCapacity != null)
        _VehicleDetailItem(
          icon: Icons.speed_rounded,
          label: 'Engine CC',
          value: fields.cubicCapacity!,
        ),
      if (fields.seatingCapacity != null)
        _VehicleDetailItem(
          icon: Icons.event_seat_rounded,
          label: 'Seating Capacity',
          value: '${fields.seatingCapacity} seats',
        ),
      if (fields.garagingPincode != null)
        _VehicleDetailItem(
          icon: Icons.location_on_rounded,
          label: 'Garaging Pincode',
          value: fields.garagingPincode!,
        ),
      if (fields.fuelType != null)
        _VehicleDetailItem(
          icon: Icons.local_gas_station_rounded,
          label: 'Fuel Type',
          value: fields.fuelType!,
        ),
      if (fields.voluntaryDeductible != null)
        _VehicleDetailItem(
          icon: Icons.money_off_rounded,
          label: 'Voluntary Deductible',
          value: fields.voluntaryDeductible!,
        ),
      if (fields.hypothecation != null)
        _VehicleDetailItem(
          icon: Icons.account_balance_rounded,
          label: 'Hypothecation',
          value: fields.hypothecation!,
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
                  icon: Icons.directions_car_filled_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Vehicle Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _VehicleDetailRow(item: item)),
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
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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

  static String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)} L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

class _VehicleDetailItem {
  final IconData icon;
  final String label;
  final String value;
  final bool isMonospace;
  final Color? valueColor;
  final String? tooltip;

  const _VehicleDetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.valueColor,
    this.tooltip,
  });
}

class _VehicleDetailRow extends StatelessWidget {
  final _VehicleDetailItem item;
  const _VehicleDetailRow({required this.item});

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
              color: CoverWiseColors.blueDeep.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: CoverWiseColors.blueDeep,
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
                    fontFamily: item.isMonospace ? 'monospace' : null,
                    letterSpacing: item.isMonospace ? 0.5 : null,
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
