import 'package:flutter/material.dart';
import '../../models/policy_summary.dart';
import '../shared/coverwise_components.dart';
import '../../theme/coverwise_theme.dart';

class TravelDetailsCard extends StatelessWidget {
  final TravelPolicyFields fields;

  const TravelDetailsCard({super.key, required this.fields});

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
                  icon: Icons.flight_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Trip Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (fields.travellerName != null)
              _TravelDetailRow(
                icon: Icons.person_rounded,
                label: 'Traveller',
                value: fields.travellerName!,
              ),
            if (fields.destination != null)
              _TravelDetailRow(
                icon: Icons.explore_rounded,
                label: 'Destination',
                value: fields.destination!,
              ),
            if (fields.tripType != null)
              _TravelDetailRow(
                icon: Icons.category_rounded,
                label: 'Trip Type',
                value: fields.tripType!,
              ),
            if (fields.tripStartDate != null || fields.tripEndDate != null)
              _TravelDetailRow(
                icon: Icons.date_range_rounded,
                label: 'Trip Dates',
                value: [
                  if (fields.tripStartDate != null) fields.tripStartDate!,
                  if (fields.tripStartDate != null && fields.tripEndDate != null)
                    ' — ',
                  if (fields.tripEndDate != null) fields.tripEndDate!,
                ].join(),
              ),
            if (fields.tripDurationDays != null)
              _TravelDetailRow(
                icon: Icons.timer_rounded,
                label: 'Duration',
                value: '${fields.tripDurationDays} days',
              ),
            if (fields.emergencyAssistancePhone != null)
              _TravelDetailRow(
                icon: Icons.phone_in_talk_rounded,
                label: '24x7 Assistance',
                value: fields.emergencyAssistancePhone!,
                valueColor: cs.primary,
              ),
            if (fields.geographicalZone != null)
              _TravelDetailRow(
                icon: Icons.map_rounded,
                label: 'Geographical Zone',
                value: fields.geographicalZone!,
              ),
            if (fields.preexistingConditionWaiver != null)
              _TravelDetailRow(
                icon: Icons.healing_rounded,
                label: 'Pre-existing Conditions',
                value: fields.preexistingConditionWaiver!,
              ),
            if (fields.adventureSportsCover != null)
              _TravelDetailRow(
                icon: Icons.downhill_skiing_rounded,
                label: 'Adventure Sports',
                value: fields.adventureSportsCover!,
              ),
            if (fields.medicalExpensesCover != null ||
                fields.medicalEvacuationCover != null ||
                fields.personalAccidentCover != null ||
                fields.tripCostCovered != null ||
                fields.baggageLossCover != null ||
                fields.baggageDelayCover != null ||
                fields.tripCancellationCover != null ||
                fields.flightDelayCover != null) ...[
              const Divider(height: 24),
              Text(
                'Coverage limits',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (fields.medicalExpensesCover != null)
                _TravelDetailRow(
                  icon: Icons.medical_services_rounded,
                  label: 'Medical Expenses',
                  value: '₹${_formatTravelAmount(fields.medicalExpensesCover!)}',
                  valueColor: cs.primary,
                ),
              if (fields.medicalEvacuationCover != null)
                _TravelDetailRow(
                  icon: Icons.airport_shuttle_rounded,
                  label: 'Medical Evacuation',
                  value:
                      '₹${_formatTravelAmount(fields.medicalEvacuationCover!)}',
                ),
              if (fields.personalAccidentCover != null)
                _TravelDetailRow(
                  icon: Icons.shield_rounded,
                  label: 'Personal Accident',
                  value:
                      '₹${_formatTravelAmount(fields.personalAccidentCover!)}',
                ),
              if (fields.tripCostCovered != null)
                _TravelDetailRow(
                  icon: Icons.money_off_rounded,
                  label: 'Trip Cost Covered',
                  value: '₹${_formatTravelAmount(fields.tripCostCovered!)}',
                ),
              if (fields.tripCancellationCover != null)
                _TravelDetailRow(
                  icon: Icons.cancel_schedule_send_rounded,
                  label: 'Trip Cancellation',
                  value:
                      '₹${_formatTravelAmount(fields.tripCancellationCover!)}',
                ),
              if (fields.flightDelayCover != null)
                _TravelDetailRow(
                  icon: Icons.timer_off_rounded,
                  label: 'Flight Delay',
                  value: '₹${_formatTravelAmount(fields.flightDelayCover!)}',
                ),
              if (fields.baggageLossCover != null)
                _TravelDetailRow(
                  icon: Icons.luggage_rounded,
                  label: 'Baggage Loss',
                  value: '₹${_formatTravelAmount(fields.baggageLossCover!)}',
                ),
              if (fields.baggageDelayCover != null)
                _TravelDetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Baggage Delay',
                  value: '₹${_formatTravelAmount(fields.baggageDelayCover!)}',
                ),
              if (fields.hijackCover != null)
                _TravelDetailRow(
                  icon: Icons.flight_rounded,
                  label: 'Hijack Cover',
                  value: fields.hijackCover!,
                ),
              if (fields.passportLossCover != null)
                _TravelDetailRow(
                  icon: Icons.airplane_ticket_rounded,
                  label: 'Passport Loss',
                  value: fields.passportLossCover!,
                ),
              if (fields.deductiblePerClaimTravel != null)
                _TravelDetailRow(
                  icon: Icons.money_off_rounded,
                  label: 'Deductible per Claim',
                  value:
                      '₹${_formatTravelAmount(fields.deductiblePerClaimTravel!)}',
                ),
            ],
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
          ],
        ),
      ),
    );
  }

  static String _formatTravelAmount(double amount) {
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

class _TravelDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _TravelDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
