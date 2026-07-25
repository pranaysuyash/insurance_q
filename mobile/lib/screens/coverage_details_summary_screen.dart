import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/policy_summary.dart';
import '../theme/coverwise_theme.dart';
import '../utils/policy_type.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../localization/app_localizations.dart';

class CoverageDetailsSummaryScreen extends StatelessWidget {
  final PolicySummary summary;

  const CoverageDetailsSummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policyType = classifyPolicyType(summary.documentType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coverage Details Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: S.coverageShareSummary,
            onPressed: () => _shareSummary(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverWisePageHeader(
              title: 'Everything Extracted',
              subtitle:
                  '${canonicalTypeName(policyType)} — ${summary.insurer ?? 'Unknown insurer'}',
            ),
            _sectionTile(
              theme: theme,
              icon: Icons.fact_check_rounded,
              title: 'Policy Basics',
              initiallyExpanded: true,
              child: _buildBasicsContent(context, summary, policyType),
            ),
            _sectionTile(
              theme: theme,
              icon: Icons.payments_rounded,
              title: 'Coverage & Premium',
              child: _buildCoverageContent(context, summary),
            ),
            _sectionTile(
              theme: theme,
              icon: Icons.calendar_month_rounded,
              title: 'Dates & Status',
              child: _buildDatesContent(context, summary),
            ),
            if (summary.keyBenefits.isNotEmpty || summary.exclusions.isNotEmpty || summary.waitingPeriods.isNotEmpty || summary.coverageItems.isNotEmpty)
              _sectionTile(
                theme: theme,
                icon: Icons.shield_rounded,
                title: 'Benefits & Coverage',
                child: _buildBenefitsContent(context, summary),
              ),
            if (summary.motorFields?.hasAnyFields == true ||
                summary.lifeFields?.hasAnyFields == true ||
                summary.homeFields?.hasAnyFields == true ||
                summary.travelFields?.hasAnyFields == true ||
                summary.healthFields?.hasAnyFields == true ||
                summary.marineFields?.hasAnyFields == true)
              _sectionTile(
                theme: theme,
                icon: Icons.manage_search_rounded,
                title: 'Type-Specific Details',
                child: _buildTypeSpecificContent(context, summary),
              ),
            if (summary.executiveSummary.isNotEmpty)
              _sectionTile(
                theme: theme,
                icon: Icons.summarize_rounded,
                title: 'Executive Summary',
                child: _buildExecSummaryContent(context, summary),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Extracted on ${summary.extractedAt.day}/${summary.extractedAt.month}/${summary.extractedAt.year} '
                      'from your uploaded policy document. Always verify important details against the source document.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    bool initiallyExpanded = false,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CoverWiseSurface(
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          shape: const Border(),
          collapsedShape: const Border(),
          collapsedBackgroundColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          leading: CoverWiseIconBadge(icon: icon, color: CoverWiseColors.blueDeep, size: 36),
          title: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildBasicsContent(BuildContext context, PolicySummary s, PolicyType policyType) {
    return _FieldGroup(items: [
      _FieldItem(icon: Icons.description_rounded, label: 'Policy Number', value: s.policyNumber ?? '—'),
      _FieldItem(icon: Icons.business_rounded, label: 'Insurer', value: s.insurer ?? '—'),
      if (s.insurerHelpline != null) _FieldItem(icon: Icons.phone_rounded, label: 'Helpline', value: s.insurerHelpline!),
      if (s.insurerEmail != null) _FieldItem(icon: Icons.email_rounded, label: 'Email', value: s.insurerEmail!),
      _FieldItem(icon: Icons.category_rounded, label: 'Document Type', value: canonicalTypeName(policyType)),
    ]);
  }

  Widget _buildCoverageContent(BuildContext context, PolicySummary s) {
    final theme = Theme.of(context);
    return _FieldGroup(items: [
      if (s.coverageAmount != null) _FieldItem(icon: Icons.shield_rounded, label: 'Sum Insured', value: s.formattedCoverageAmount, valueColor: theme.colorScheme.primary),
      if (s.premiumAmount != null) _FieldItem(icon: Icons.payments_rounded, label: 'Premium', value: s.formattedPremium),
      if (s.premiumFrequency != null) _FieldItem(icon: Icons.schedule_rounded, label: 'Frequency', value: s.premiumFrequency!),
      if (s.deductible != null) _FieldItem(icon: Icons.money_off_rounded, label: 'Deductible', value: '₹${s.deductible!.toStringAsFixed(0)}'),
    ]);
  }

  Widget _buildDatesContent(BuildContext context, PolicySummary s) {
    return _FieldGroup(items: [
      if (s.startDate != null) _FieldItem(icon: Icons.today_rounded, label: 'Start Date', value: s.formattedStartDate),
      if (s.endDate != null) _FieldItem(icon: Icons.event_rounded, label: 'End Date', value: s.formattedExpiryDate),
      _FieldItem(icon: Icons.access_time_rounded, label: 'Days Remaining', value: s.endDate != null ? '${s.daysUntilExpiry} days' : '—'),
      _FieldItem(icon: Icons.info_outline_rounded, label: 'Status', value: s.isExpired ? 'Expired' : s.isExpiringSoon ? 'Expiring Soon' : s.isActive ? 'Active' : 'Unknown'),
    ]);
  }

  Widget _buildBenefitsContent(BuildContext context, PolicySummary s) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.keyBenefits.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Covered Benefits', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary))),
          ...s.keyBenefits.map((b) => _BulletItem(text: b, color: cs.primary)),
          const SizedBox(height: 12),
        ],
        if (s.exclusions.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Exclusions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.error))),
          ...s.exclusions.map((e) => _BulletItem(text: e, color: cs.error)),
          const SizedBox(height: 12),
        ],
        if (s.waitingPeriods.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Waiting Periods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.tertiary))),
          ...s.waitingPeriods.map((w) => _BulletItem(text: w, color: cs.tertiary)),
        ],
        if (s.coverageItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Coverage Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary))),
          ...s.coverageItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.covered ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: item.covered ? cs.primary : cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (item.limitText != null) Text(item.limitText!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      if (item.limit != null && item.limitText == null) Text('Limit: ₹${item.limit!.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildTypeSpecificContent(BuildContext context, PolicySummary s) {
    final theme = Theme.of(context);
    final sections = <Widget>[];

    if (s.motorFields?.hasAnyFields == true) {
      sections.add(_buildMotorSection(s.motorFields!, theme));
    }
    if (s.lifeFields?.hasAnyFields == true) {
      sections.add(_buildLifeSection(s.lifeFields!, theme));
    }
    if (s.homeFields?.hasAnyFields == true) {
      sections.add(_buildHomeSection(s.homeFields!, theme));
    }
    if (s.travelFields?.hasAnyFields == true) {
      sections.add(_buildTravelSection(s.travelFields!, theme));
    }
    if (s.healthFields?.hasAnyFields == true) {
      sections.add(_buildHealthSection(s.healthFields!, theme));
    }
    if (s.marineFields?.hasAnyFields == true) {
      sections.add(_buildMarineSection(s.marineFields!, theme));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _buildMotorSection(MotorPolicyFields f, ThemeData theme) {
    final items = <_FieldItem>[
      if (f.vehicleRegistrationNumber != null) _FieldItem(icon: Icons.directions_car_rounded, label: 'Registration', value: f.vehicleRegistrationNumber!),
      if (f.vin != null) _FieldItem(icon: Icons.qr_code_rounded, label: 'VIN / Chassis', value: f.vin!),
      if (f.engineNumber != null) _FieldItem(icon: Icons.precision_manufacturing_rounded, label: 'Engine No.', value: f.engineNumber!),
      if (f.vehicleMakeModel != null) _FieldItem(icon: Icons.badge_rounded, label: 'Make / Model', value: f.vehicleMakeModel!),
      if (f.vehicleYear != null) _FieldItem(icon: Icons.calendar_today_rounded, label: 'Year', value: '${f.vehicleYear}'),
      if (f.fuelType != null) _FieldItem(icon: Icons.local_gas_station_rounded, label: 'Fuel', value: f.fuelType!),
      if (f.seatingCapacity != null) _FieldItem(icon: Icons.event_seat_rounded, label: 'Seating', value: '${f.seatingCapacity}'),
      if (f.cubicCapacity != null) _FieldItem(icon: Icons.speed_rounded, label: 'CC', value: f.cubicCapacity!),
      if (f.garagingPincode != null) _FieldItem(icon: Icons.location_on_rounded, label: 'Garaging', value: f.garagingPincode!),
      if (f.hypothecation != null) _FieldItem(icon: Icons.account_balance_rounded, label: 'Hypothecation', value: f.hypothecation!),
      if (f.ncbPercent != null) _FieldItem(icon: Icons.discount_rounded, label: 'NCB', value: '${f.ncbPercent!.toStringAsFixed(0)}%'),
      if (f.idv != null) _FieldItem(icon: Icons.monetization_on_rounded, label: 'IDV', value: _fmt(f.idv!), valueColor: theme.colorScheme.primary),
      if (f.ownDamagePremium != null) _FieldItem(icon: Icons.payments_rounded, label: 'OD Premium', value: _fmt(f.ownDamagePremium!)),
      if (f.thirdPartyPremium != null) _FieldItem(icon: Icons.payments_rounded, label: 'TP Premium', value: _fmt(f.thirdPartyPremium!)),
      if (f.voluntaryDeductible != null) _FieldItem(icon: Icons.money_off_rounded, label: 'Vol. Deductible', value: f.voluntaryDeductible!),
      if (f.personalAccidentCoverOwner != null) _FieldItem(icon: Icons.person_rounded, label: 'PA Cover', value: _fmt(f.personalAccidentCoverOwner!)),
      if (f.policyTypeDetail != null) _FieldItem(icon: Icons.category_rounded, label: 'Policy Type', value: f.policyTypeDetail!),
      if (f.geographicalLimit != null) _FieldItem(icon: Icons.public_rounded, label: 'Geo. Limit', value: f.geographicalLimit!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TypeSubSection(label: 'Motor / Auto', color: Color(0xFFE65100)),
        _FieldGroup(items: items),
        if (f.addOnCovers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Add-on Covers', items: f.addOnCovers, color: theme.colorScheme.tertiary),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLifeSection(LifePolicyFields f, ThemeData theme) {
    final items = <_FieldItem>[
      if (f.lifeAssuredName != null) _FieldItem(icon: Icons.person_rounded, label: 'Life Assured', value: f.lifeAssuredName!),
      if (f.sumAssured != null) _FieldItem(icon: Icons.shield_rounded, label: 'Sum Assured', value: _fmt(f.sumAssured!), valueColor: theme.colorScheme.primary),
      if (f.policyTermYears != null) _FieldItem(icon: Icons.timer_rounded, label: 'Policy Term', value: '${f.policyTermYears} years'),
      if (f.premiumPayingTermYears != null) _FieldItem(icon: Icons.payments_rounded, label: 'Premium Term', value: '${f.premiumPayingTermYears} years'),
      if (f.nomineeName != null) _FieldItem(icon: Icons.people_rounded, label: 'Nominee', value: f.nomineeName!),
      if (f.nomineeShare != null) _FieldItem(icon: Icons.pie_chart_rounded, label: 'Nominee Share', value: f.nomineeShare!),
      if (f.maturityDate != null) _FieldItem(icon: Icons.event_rounded, label: 'Maturity', value: f.maturityDate!),
      if (f.maturityAmount != null) _FieldItem(icon: Icons.savings_rounded, label: 'Maturity Amount', value: _fmt(f.maturityAmount!)),
      if (f.accidentalDeathBenefit != null) _FieldItem(icon: Icons.warning_rounded, label: 'AD Benefit', value: _fmt(f.accidentalDeathBenefit!)),
      if (f.terminalIllnessBenefit != null) _FieldItem(icon: Icons.health_and_safety_rounded, label: 'TI Benefit', value: f.terminalIllnessBenefit!),
      if (f.deathBenefitType != null) _FieldItem(icon: Icons.info_rounded, label: 'Death Benefit', value: f.deathBenefitType!),
      if (f.policyTypeDetail != null) _FieldItem(icon: Icons.category_rounded, label: 'Policy Type', value: f.policyTypeDetail!),
      if (f.suicideExclusion != null) _FieldItem(icon: Icons.block_rounded, label: 'Suicide Exclusion', value: f.suicideExclusion!),
      if (f.freeLookPeriod != null) _FieldItem(icon: Icons.visibility_rounded, label: 'Free Look', value: f.freeLookPeriod!),
      if (f.gracePeriod != null) _FieldItem(icon: Icons.schedule_rounded, label: 'Grace Period', value: f.gracePeriod!),
      if (f.surrenderValue != null) _FieldItem(icon: Icons.money_rounded, label: 'Surrender Value', value: f.surrenderValue!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TypeSubSection(label: 'Life Insurance', color: Color(0xFF1565C0)),
        _FieldGroup(items: items),
        if (f.riderDetails.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Riders', items: f.riderDetails, color: theme.colorScheme.tertiary),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHomeSection(HomePolicyFields f, ThemeData theme) {
    final items = <_FieldItem>[
      if (f.propertyAddress != null) _FieldItem(icon: Icons.home_rounded, label: 'Property', value: f.propertyAddress!),
      if (f.buildingSumInsured != null) _FieldItem(icon: Icons.shield_rounded, label: 'Building SI', value: _fmt(f.buildingSumInsured!), valueColor: theme.colorScheme.primary),
      if (f.contentsSumInsured != null) _FieldItem(icon: Icons.inventory_rounded, label: 'Contents SI', value: _fmt(f.contentsSumInsured!)),
      if (f.rebuildCost != null) _FieldItem(icon: Icons.construction_rounded, label: 'Rebuild Cost', value: _fmt(f.rebuildCost!)),
      if (f.deductible != null) _FieldItem(icon: Icons.money_off_rounded, label: 'Deductible', value: _fmt(f.deductible!)),
      if (f.structureType != null) _FieldItem(icon: Icons.architecture_rounded, label: 'Structure', value: f.structureType!),
      if (f.occupancyType != null) _FieldItem(icon: Icons.people_rounded, label: 'Occupancy', value: f.occupancyType!),
      if (f.constructionType != null) _FieldItem(icon: Icons.handyman_rounded, label: 'Construction', value: f.constructionType!),
      if (f.policyType != null) _FieldItem(icon: Icons.category_rounded, label: 'Policy Type', value: f.policyType!),
      if (f.yearBuilt != null) _FieldItem(icon: Icons.calendar_today_rounded, label: 'Year Built', value: '${f.yearBuilt}'),
      if (f.underinsuranceClause != null) _FieldItem(icon: Icons.warning_rounded, label: 'Underinsurance Clause', value: f.underinsuranceClause!),
      if (f.escalationClause != null) _FieldItem(icon: Icons.trending_up_rounded, label: 'Escalation Clause', value: f.escalationClause!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TypeSubSection(label: 'Home / Property', color: Color(0xFF6A1B9A)),
        _FieldGroup(items: items),
        if (f.perilsCovered.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Perils Covered', items: f.perilsCovered, color: const Color(0xFF2E7D32)),
        ],
        if (f.perilsExcluded.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Perils Excluded', items: f.perilsExcluded, color: theme.colorScheme.error),
        ],
        if (f.addOnCovers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Add-on Covers', items: f.addOnCovers, color: theme.colorScheme.tertiary),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTravelSection(TravelPolicyFields f, ThemeData theme) {
    final items = <_FieldItem>[
      if (f.travellerName != null) _FieldItem(icon: Icons.person_rounded, label: 'Traveller', value: f.travellerName!),
      if (f.destination != null) _FieldItem(icon: Icons.flight_rounded, label: 'Destination', value: f.destination!),
      if (f.tripType != null) _FieldItem(icon: Icons.category_rounded, label: 'Trip Type', value: f.tripType!),
      if (f.tripDurationDays != null) _FieldItem(icon: Icons.timer_rounded, label: 'Duration', value: '${f.tripDurationDays} days'),
      if (f.tripStartDate != null) _FieldItem(icon: Icons.today_rounded, label: 'Trip Start', value: f.tripStartDate!),
      if (f.tripEndDate != null) _FieldItem(icon: Icons.event_rounded, label: 'Trip End', value: f.tripEndDate!),
      if (f.tripCostCovered != null) _FieldItem(icon: Icons.monetization_on_rounded, label: 'Trip Cost', value: _fmt(f.tripCostCovered!)),
      if (f.medicalExpensesCover != null) _FieldItem(icon: Icons.local_hospital_rounded, label: 'Medical Expenses', value: _fmt(f.medicalExpensesCover!), valueColor: theme.colorScheme.primary),
      if (f.medicalEvacuationCover != null) _FieldItem(icon: Icons.emergency_rounded, label: 'Medical Evacuation', value: _fmt(f.medicalEvacuationCover!)),
      if (f.personalAccidentCover != null) _FieldItem(icon: Icons.person_rounded, label: 'PA Cover', value: _fmt(f.personalAccidentCover!)),
      if (f.baggageLossCover != null) _FieldItem(icon: Icons.luggage_rounded, label: 'Baggage Loss', value: _fmt(f.baggageLossCover!)),
      if (f.baggageDelayCover != null) _FieldItem(icon: Icons.schedule_rounded, label: 'Baggage Delay', value: _fmt(f.baggageDelayCover!)),
      if (f.tripCancellationCover != null) _FieldItem(icon: Icons.cancel_rounded, label: 'Trip Cancellation', value: _fmt(f.tripCancellationCover!)),
      if (f.flightDelayCover != null) _FieldItem(icon: Icons.flight_rounded, label: 'Flight Delay', value: _fmt(f.flightDelayCover!)),
      if (f.deductiblePerClaimTravel != null) _FieldItem(icon: Icons.money_off_rounded, label: 'Deductible', value: _fmt(f.deductiblePerClaimTravel!)),
      if (f.emergencyAssistancePhone != null) _FieldItem(icon: Icons.phone_rounded, label: 'Emergency', value: f.emergencyAssistancePhone!),
      if (f.geographicalZone != null) _FieldItem(icon: Icons.public_rounded, label: 'Geo. Zone', value: f.geographicalZone!),
      if (f.preexistingConditionWaiver != null) _FieldItem(icon: Icons.health_and_safety_rounded, label: 'Pre-existing Waiver', value: f.preexistingConditionWaiver!),
      if (f.adventureSportsCover != null) _FieldItem(icon: Icons.downhill_skiing_rounded, label: 'Adventure Sports', value: f.adventureSportsCover!),
      if (f.hijackCover != null) _FieldItem(icon: Icons.airplanemode_active_rounded, label: 'Hijack Cover', value: f.hijackCover!),
      if (f.passportLossCover != null) _FieldItem(icon: Icons.lock_rounded, label: 'Passport Loss', value: f.passportLossCover!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TypeSubSection(label: 'Travel', color: Color(0xFF00695C)),
        _FieldGroup(items: items),
        if (f.addOnCovers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Add-on Covers', items: f.addOnCovers, color: theme.colorScheme.tertiary),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHealthSection(HealthPolicyFields f, ThemeData theme) {
    final items = <_FieldItem>[
      if (f.roomRentCap != null) _FieldItem(icon: Icons.hotel_rounded, label: 'Room Rent Cap', value: f.roomRentCap!),
      if (f.coPayPercent != null) _FieldItem(icon: Icons.pie_chart_rounded, label: 'Co-pay', value: '${f.coPayPercent!.toStringAsFixed(0)}%'),
      if (f.deductiblePerClaim != null) _FieldItem(icon: Icons.money_off_rounded, label: 'Deductible', value: _fmt(f.deductiblePerClaim!)),
      if (f.ambulanceCover != null) _FieldItem(icon: Icons.local_hospital_rounded, label: 'Ambulance', value: _fmt(f.ambulanceCover!), valueColor: theme.colorScheme.primary),
      if (f.networkHospitals != null) _FieldItem(icon: Icons.business_rounded, label: 'Network Hospitals', value: f.networkHospitals!),
      if (f.maternityCover != null) _FieldItem(icon: Icons.child_care_rounded, label: 'Maternity', value: f.maternityCover!),
      if (f.dayCareProcedures != null) _FieldItem(icon: Icons.access_time_rounded, label: 'Day Care', value: f.dayCareProcedures!),
      if (f.consumablesCover != null) _FieldItem(icon: Icons.medication_rounded, label: 'Consumables', value: f.consumablesCover!),
      if (f.healthCheckupCover != null) _FieldItem(icon: Icons.favorite_rounded, label: 'Health Checkup', value: f.healthCheckupCover!),
      if (f.prePostHospitalizationDays != null) _FieldItem(icon: Icons.date_range_rounded, label: 'Pre/Post Hospitalization', value: f.prePostHospitalizationDays!),
      if (f.restorationBenefit != null) _FieldItem(icon: Icons.restart_alt_rounded, label: 'Restoration Benefit', value: f.restorationBenefit!),
      if (f.cumulativeBonus != null) _FieldItem(icon: Icons.trending_up_rounded, label: 'Cumulative Bonus', value: f.cumulativeBonus!),
      if (f.noClaimBonusPercent != null) _FieldItem(icon: Icons.discount_rounded, label: 'NCB', value: '${f.noClaimBonusPercent!.toStringAsFixed(0)}%'),
      if (f.modernTreatmentCover != null) _FieldItem(icon: Icons.biotech_rounded, label: 'Modern Treatment', value: f.modernTreatmentCover!),
      if (f.moratoriumPeriod != null) _FieldItem(icon: Icons.schedule_rounded, label: 'Moratorium', value: f.moratoriumPeriod!),
      if (f.preAuthTimeLimit != null) _FieldItem(icon: Icons.alarm_rounded, label: 'Pre-auth Time', value: f.preAuthTimeLimit!),
      if (f.domiciliaryHospitalization != null) _FieldItem(icon: Icons.home_rounded, label: 'Domiciliary', value: f.domiciliaryHospitalization!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TypeSubSection(label: 'Health Insurance', color: Color(0xFFC62828)),
        _FieldGroup(items: items),
        if (f.preExistingDiseases.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Pre-existing Diseases', items: f.preExistingDiseases, color: theme.colorScheme.error),
        ],
        if (f.criticalIllnessList.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Critical Illnesses', items: f.criticalIllnessList, color: const Color(0xFFE65100)),
        ],
        if (f.subLimits.isNotEmpty) ...[
          const SizedBox(height: 8),
          _BulletSection(label: 'Sub-limits', items: f.subLimits, color: theme.colorScheme.tertiary),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMarineSection(MarinePolicyFields f, ThemeData theme) {
    final items = <_FieldItem>[
      if (f.policyTypeMarine != null) _FieldItem(icon: Icons.category_rounded, label: 'Policy Type', value: f.policyTypeMarine!),
      if (f.vesselName != null) _FieldItem(icon: Icons.directions_boat_rounded, label: 'Vessel', value: f.vesselName!),
      if (f.voyageDetails != null) _FieldItem(icon: Icons.route_rounded, label: 'Voyage', value: f.voyageDetails!),
      if (f.voyageFrom != null) _FieldItem(icon: Icons.trip_origin_rounded, label: 'From', value: f.voyageFrom!),
      if (f.voyageTo != null) _FieldItem(icon: Icons.trip_origin_rounded, label: 'To', value: f.voyageTo!),
      if (f.cargoDescription != null) _FieldItem(icon: Icons.inventory_rounded, label: 'Cargo', value: f.cargoDescription!),
      if (f.cargoValue != null) _FieldItem(icon: Icons.monetization_on_rounded, label: 'Cargo Value', value: f.cargoValue!),
      if (f.incoterms != null) _FieldItem(icon: Icons.handshake_rounded, label: 'Incoterms', value: f.incoterms!),
      if (f.instituteClauses != null) _FieldItem(icon: Icons.article_rounded, label: 'Institute Clauses', value: f.instituteClauses!),
      if (f.conveyance != null) _FieldItem(icon: Icons.local_shipping_rounded, label: 'Conveyance', value: f.conveyance!),
      if (f.transitStartDate != null) _FieldItem(icon: Icons.today_rounded, label: 'Transit Start', value: f.transitStartDate!),
      if (f.transitEndDate != null) _FieldItem(icon: Icons.event_rounded, label: 'Transit End', value: f.transitEndDate!),
      if (f.generalAverageClause != null) _FieldItem(icon: Icons.percent_rounded, label: 'GA Clause', value: f.generalAverageClause!),
      if (f.warRiskClause != null) _FieldItem(icon: Icons.gavel_rounded, label: 'War Risk', value: f.warRiskClause!),
      if (f.strikesRiotsClause != null) _FieldItem(icon: Icons.warning_rounded, label: 'Strikes/Riots', value: f.strikesRiotsClause!),
      if (f.warehouseToWarehouse != null) _FieldItem(icon: Icons.warehouse_rounded, label: 'W/W Clause', value: f.warehouseToWarehouse!),
      if (f.marineInsuranceCertificateNo != null) _FieldItem(icon: Icons.description_rounded, label: 'Certificate No.', value: f.marineInsuranceCertificateNo!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TypeSubSection(label: 'Marine / Cargo', color: Color(0xFF0D47A1)),
        _FieldGroup(items: items),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Formats a numeric amount into a human-readable currency string.
  static String _fmt(double amount) {
    if (amount >= 10000000) return '₹${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(0)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  Widget _buildExecSummaryContent(BuildContext context, PolicySummary s) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: s.executiveSummary.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: CoverWiseColors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Center(child: Text('${e.key + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CoverWiseColors.blue))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value, style: TextStyle(fontSize: 13, height: 1.4, color: theme.colorScheme.onSurface))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _shareSummary(BuildContext context) {
    try {
      final text = _buildShareText();
      SharePlus.instance.share(ShareParams(
        text: text,
        subject: S.coverageShareSubject,
      ));
    } catch (_) {
      if (context.mounted) {
        CoverWiseSnackBar.error(context, S.coverageShareError);
      }
    }
  }

  /// Builds a formatted plain-text summary of all policy fields for sharing.
  String _buildShareText() {
    final s = summary;
    final buffer = StringBuffer();

    buffer.writeln('📋 ${canonicalTypeName(classifyPolicyType(s.documentType))}');
    if (s.insurer != null) buffer.writeln('🏢 ${s.insurer}');
    if (s.policyNumber != null) buffer.writeln('🔢 Policy: ${s.policyNumber}');
    buffer.writeln('');

    // Coverage & Premium
    if (s.coverageAmount != null) {
      buffer.writeln('🛡️ Coverage: ${s.formattedCoverageAmount}');
    }
    if (s.premiumAmount != null) {
      buffer.writeln('💰 Premium: ${s.formattedPremium}');
    }
    if (s.deductible != null) {
      buffer.writeln('📉 Deductible: ₹${s.deductible!.toStringAsFixed(0)}');
    }
    buffer.writeln('');

    // Dates
    if (s.startDate != null) {
      buffer.writeln('📅 From: ${s.formattedStartDate}');
    }
    if (s.endDate != null) {
      buffer.writeln('📅 Until: ${s.formattedExpiryDate}');
    }
    if (s.isActive || s.isExpiringSoon) {
      buffer.writeln('⏰ ${s.daysUntilExpiry} days remaining');
    }

    // Key Benefits
    if (s.keyBenefits.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('✅ Benefits:');
      for (final b in s.keyBenefits) {
        buffer.writeln('  • $b');
      }
    }

    // Exclusions
    if (s.exclusions.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('❌ Exclusions:');
      for (final e in s.exclusions) {
        buffer.writeln('  • $e');
      }
    }

    // Coverage Items
    if (s.coverageItems.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📋 Coverage Items:');
      for (final item in s.coverageItems) {
        final icon = item.covered ? '✅' : '❌';
        final limitStr = item.limitText != null
            ? ' (${item.limitText})'
            : (item.limit != null ? ' (${_fmt(item.limit!)})' : '');
        buffer.writeln('  $icon ${item.name}$limitStr');
      }
    }

    // Executive Summary
    if (s.executiveSummary.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📝 Summary:');
      for (final es in s.executiveSummary) {
        buffer.writeln('  • $es');
      }
    }

    // ── Type-Specific Details ──
    if (s.motorFields?.hasAnyFields == true) {
      final m = s.motorFields!;
      buffer.writeln('');
      buffer.writeln('🚗 Motor / Auto:');
      if (m.vehicleRegistrationNumber != null) buffer.writeln('  Registration: ${m.vehicleRegistrationNumber}');
      if (m.vehicleMakeModel != null) buffer.writeln('  Make/Model: ${m.vehicleMakeModel}');
      if (m.vehicleYear != null) buffer.writeln('  Year: ${m.vehicleYear}');
      if (m.vin != null) buffer.writeln('  VIN: ${m.vin}');
      if (m.engineNumber != null) buffer.writeln('  Engine: ${m.engineNumber}');
      if (m.fuelType != null) buffer.writeln('  Fuel: ${m.fuelType}');
      if (m.cubicCapacity != null) buffer.writeln('  CC: ${m.cubicCapacity}');
      if (m.seatingCapacity != null) buffer.writeln('  Seating: ${m.seatingCapacity}');
      if (m.ncbPercent != null) buffer.writeln('  NCB: ${m.ncbPercent!.toStringAsFixed(0)}%');
      if (m.idv != null) buffer.writeln('  IDV: ${_fmt(m.idv!)}');
      if (m.ownDamagePremium != null) buffer.writeln('  OD Premium: ${_fmt(m.ownDamagePremium!)}');
      if (m.thirdPartyPremium != null) buffer.writeln('  TP Premium: ${_fmt(m.thirdPartyPremium!)}');
      if (m.voluntaryDeductible != null) buffer.writeln('  Vol. Deductible: ${m.voluntaryDeductible}');
      if (m.personalAccidentCoverOwner != null) buffer.writeln('  PA Cover: ${_fmt(m.personalAccidentCoverOwner!)}');
      if (m.policyTypeDetail != null) buffer.writeln('  Policy Type: ${m.policyTypeDetail}');
      if (m.geographicalLimit != null) buffer.writeln('  Geo. Limit: ${m.geographicalLimit}');
      if (m.garagingPincode != null) buffer.writeln('  Garaging: ${m.garagingPincode}');
      if (m.hypothecation != null) buffer.writeln('  Hypothecation: ${m.hypothecation}');
      if (m.addOnCovers.isNotEmpty) {
        buffer.writeln('  Add-on Covers:');
        for (final c in m.addOnCovers) {
          buffer.writeln('    • $c');
        }
      }
    }

    if (s.lifeFields?.hasAnyFields == true) {
      final l = s.lifeFields!;
      buffer.writeln('');
      buffer.writeln('👤 Life Insurance:');
      if (l.lifeAssuredName != null) buffer.writeln('  Life Assured: ${l.lifeAssuredName}');
      if (l.sumAssured != null) buffer.writeln('  Sum Assured: ${_fmt(l.sumAssured!)}');
      if (l.policyTermYears != null) buffer.writeln('  Policy Term: ${l.policyTermYears} years');
      if (l.premiumPayingTermYears != null) buffer.writeln('  Premium Term: ${l.premiumPayingTermYears} years');
      if (l.nomineeName != null) buffer.writeln('  Nominee: ${l.nomineeName}');
      if (l.nomineeShare != null) buffer.writeln('  Nominee Share: ${l.nomineeShare}');
      if (l.maturityDate != null) buffer.writeln('  Maturity: ${l.maturityDate}');
      if (l.maturityAmount != null) buffer.writeln('  Maturity Amount: ${_fmt(l.maturityAmount!)}');
      if (l.accidentalDeathBenefit != null) buffer.writeln('  AD Benefit: ${_fmt(l.accidentalDeathBenefit!)}');
      if (l.terminalIllnessBenefit != null) buffer.writeln('  TI Benefit: ${l.terminalIllnessBenefit}');
      if (l.deathBenefitType != null) buffer.writeln('  Death Benefit: ${l.deathBenefitType}');
      if (l.policyTypeDetail != null) buffer.writeln('  Policy Type: ${l.policyTypeDetail}');
      if (l.suicideExclusion != null) buffer.writeln('  Suicide Exclusion: ${l.suicideExclusion}');
      if (l.freeLookPeriod != null) buffer.writeln('  Free Look: ${l.freeLookPeriod}');
      if (l.gracePeriod != null) buffer.writeln('  Grace Period: ${l.gracePeriod}');
      if (l.surrenderValue != null) buffer.writeln('  Surrender Value: ${l.surrenderValue}');
      if (l.riderDetails.isNotEmpty) {
        buffer.writeln('  Riders:');
        for (final r in l.riderDetails) {
          buffer.writeln('    • $r');
        }
      }
    }

    if (s.homeFields?.hasAnyFields == true) {
      final h = s.homeFields!;
      buffer.writeln('');
      buffer.writeln('🏠 Home / Property:');
      if (h.propertyAddress != null) buffer.writeln('  Property: ${h.propertyAddress}');
      if (h.buildingSumInsured != null) buffer.writeln('  Building SI: ${_fmt(h.buildingSumInsured!)}');
      if (h.contentsSumInsured != null) buffer.writeln('  Contents SI: ${_fmt(h.contentsSumInsured!)}');
      if (h.rebuildCost != null) buffer.writeln('  Rebuild Cost: ${_fmt(h.rebuildCost!)}');
      if (h.deductible != null) buffer.writeln('  Deductible: ${_fmt(h.deductible!)}');
      if (h.structureType != null) buffer.writeln('  Structure: ${h.structureType}');
      if (h.occupancyType != null) buffer.writeln('  Occupancy: ${h.occupancyType}');
      if (h.constructionType != null) buffer.writeln('  Construction: ${h.constructionType}');
      if (h.policyType != null) buffer.writeln('  Policy Type: ${h.policyType}');
      if (h.yearBuilt != null) buffer.writeln('  Year Built: ${h.yearBuilt}');
      if (h.underinsuranceClause != null) buffer.writeln('  Underinsurance Clause: ${h.underinsuranceClause}');
      if (h.escalationClause != null) buffer.writeln('  Escalation Clause: ${h.escalationClause}');
      if (h.perilsCovered.isNotEmpty) {
        buffer.writeln('  Perils Covered:');
        for (final p in h.perilsCovered) {
          buffer.writeln('    • $p');
        }
      }
      if (h.perilsExcluded.isNotEmpty) {
        buffer.writeln('  Perils Excluded:');
        for (final p in h.perilsExcluded) {
          buffer.writeln('    • $p');
        }
      }
      if (h.addOnCovers.isNotEmpty) {
        buffer.writeln('  Add-on Covers:');
        for (final c in h.addOnCovers) {
          buffer.writeln('    • $c');
        }
      }
    }

    if (s.travelFields?.hasAnyFields == true) {
      final t = s.travelFields!;
      buffer.writeln('');
      buffer.writeln('✈️ Travel:');
      if (t.travellerName != null) buffer.writeln('  Traveller: ${t.travellerName}');
      if (t.destination != null) buffer.writeln('  Destination: ${t.destination}');
      if (t.tripType != null) buffer.writeln('  Trip Type: ${t.tripType}');
      if (t.tripDurationDays != null) buffer.writeln('  Duration: ${t.tripDurationDays} days');
      if (t.tripStartDate != null) buffer.writeln('  Trip Start: ${t.tripStartDate}');
      if (t.tripEndDate != null) buffer.writeln('  Trip End: ${t.tripEndDate}');
      if (t.tripCostCovered != null) buffer.writeln('  Trip Cost: ${_fmt(t.tripCostCovered!)}');
      if (t.medicalExpensesCover != null) buffer.writeln('  Medical Expenses: ${_fmt(t.medicalExpensesCover!)}');
      if (t.medicalEvacuationCover != null) buffer.writeln('  Medical Evacuation: ${_fmt(t.medicalEvacuationCover!)}');
      if (t.personalAccidentCover != null) buffer.writeln('  PA Cover: ${_fmt(t.personalAccidentCover!)}');
      if (t.baggageLossCover != null) buffer.writeln('  Baggage Loss: ${_fmt(t.baggageLossCover!)}');
      if (t.baggageDelayCover != null) buffer.writeln('  Baggage Delay: ${_fmt(t.baggageDelayCover!)}');
      if (t.tripCancellationCover != null) buffer.writeln('  Trip Cancellation: ${_fmt(t.tripCancellationCover!)}');
      if (t.flightDelayCover != null) buffer.writeln('  Flight Delay: ${_fmt(t.flightDelayCover!)}');
      if (t.deductiblePerClaimTravel != null) buffer.writeln('  Deductible: ${_fmt(t.deductiblePerClaimTravel!)}');
      if (t.emergencyAssistancePhone != null) buffer.writeln('  Emergency: ${t.emergencyAssistancePhone}');
      if (t.geographicalZone != null) buffer.writeln('  Geo. Zone: ${t.geographicalZone}');
      if (t.preexistingConditionWaiver != null) buffer.writeln('  Pre-existing Waiver: ${t.preexistingConditionWaiver}');
      if (t.adventureSportsCover != null) buffer.writeln('  Adventure Sports: ${t.adventureSportsCover}');
      if (t.hijackCover != null) buffer.writeln('  Hijack Cover: ${t.hijackCover}');
      if (t.passportLossCover != null) buffer.writeln('  Passport Loss: ${t.passportLossCover}');
      if (t.addOnCovers.isNotEmpty) {
        buffer.writeln('  Add-on Covers:');
        for (final c in t.addOnCovers) {
          buffer.writeln('    • $c');
        }
      }
    }

    if (s.healthFields?.hasAnyFields == true) {
      final h = s.healthFields!;
      buffer.writeln('');
      buffer.writeln('🏥 Health Insurance:');
      if (h.roomRentCap != null) buffer.writeln('  Room Rent Cap: ${h.roomRentCap}');
      if (h.coPayPercent != null) buffer.writeln('  Co-pay: ${h.coPayPercent!.toStringAsFixed(0)}%');
      if (h.deductiblePerClaim != null) buffer.writeln('  Deductible: ${_fmt(h.deductiblePerClaim!)}');
      if (h.ambulanceCover != null) buffer.writeln('  Ambulance: ${_fmt(h.ambulanceCover!)}');
      if (h.networkHospitals != null) buffer.writeln('  Network Hospitals: ${h.networkHospitals}');
      if (h.maternityCover != null) buffer.writeln('  Maternity: ${h.maternityCover}');
      if (h.dayCareProcedures != null) buffer.writeln('  Day Care: ${h.dayCareProcedures}');
      if (h.consumablesCover != null) buffer.writeln('  Consumables: ${h.consumablesCover}');
      if (h.healthCheckupCover != null) buffer.writeln('  Health Checkup: ${h.healthCheckupCover}');
      if (h.prePostHospitalizationDays != null) buffer.writeln('  Pre/Post Hospitalization: ${h.prePostHospitalizationDays}');
      if (h.restorationBenefit != null) buffer.writeln('  Restoration Benefit: ${h.restorationBenefit}');
      if (h.cumulativeBonus != null) buffer.writeln('  Cumulative Bonus: ${h.cumulativeBonus}');
      if (h.noClaimBonusPercent != null) buffer.writeln('  NCB: ${h.noClaimBonusPercent!.toStringAsFixed(0)}%');
      if (h.modernTreatmentCover != null) buffer.writeln('  Modern Treatment: ${h.modernTreatmentCover}');
      if (h.moratoriumPeriod != null) buffer.writeln('  Moratorium: ${h.moratoriumPeriod}');
      if (h.preAuthTimeLimit != null) buffer.writeln('  Pre-auth Time: ${h.preAuthTimeLimit}');
      if (h.domiciliaryHospitalization != null) buffer.writeln('  Domiciliary: ${h.domiciliaryHospitalization}');
      if (h.preExistingDiseases.isNotEmpty) {
        buffer.writeln('  Pre-existing Diseases:');
        for (final d in h.preExistingDiseases) {
          buffer.writeln('    • $d');
        }
      }
      if (h.criticalIllnessList.isNotEmpty) {
        buffer.writeln('  Critical Illnesses:');
        for (final ci in h.criticalIllnessList) {
          buffer.writeln('    • $ci');
        }
      }
      if (h.subLimits.isNotEmpty) {
        buffer.writeln('  Sub-limits:');
        for (final sl in h.subLimits) {
          buffer.writeln('    • $sl');
        }
      }
    }

    if (s.marineFields?.hasAnyFields == true) {
      final m = s.marineFields!;
      buffer.writeln('');
      buffer.writeln('🚢 Marine / Cargo:');
      if (m.policyTypeMarine != null) buffer.writeln('  Policy Type: ${m.policyTypeMarine}');
      if (m.vesselName != null) buffer.writeln('  Vessel: ${m.vesselName}');
      if (m.voyageDetails != null) buffer.writeln('  Voyage: ${m.voyageDetails}');
      if (m.voyageFrom != null) buffer.writeln('  From: ${m.voyageFrom}');
      if (m.voyageTo != null) buffer.writeln('  To: ${m.voyageTo}');
      if (m.cargoDescription != null) buffer.writeln('  Cargo: ${m.cargoDescription}');
      if (m.cargoValue != null) buffer.writeln('  Cargo Value: ${m.cargoValue}');
      if (m.incoterms != null) buffer.writeln('  Incoterms: ${m.incoterms}');
      if (m.instituteClauses != null) buffer.writeln('  Institute Clauses: ${m.instituteClauses}');
      if (m.conveyance != null) buffer.writeln('  Conveyance: ${m.conveyance}');
      if (m.transitStartDate != null) buffer.writeln('  Transit Start: ${m.transitStartDate}');
      if (m.transitEndDate != null) buffer.writeln('  Transit End: ${m.transitEndDate}');
      if (m.generalAverageClause != null) buffer.writeln('  GA Clause: ${m.generalAverageClause}');
      if (m.warRiskClause != null) buffer.writeln('  War Risk: ${m.warRiskClause}');
      if (m.strikesRiotsClause != null) buffer.writeln('  Strikes/Riots: ${m.strikesRiotsClause}');
      if (m.warehouseToWarehouse != null) buffer.writeln('  W/W Clause: ${m.warehouseToWarehouse}');
      if (m.marineInsuranceCertificateNo != null) buffer.writeln('  Certificate No.: ${m.marineInsuranceCertificateNo}');
    }

    // Footer
    buffer.writeln('');
    buffer.writeln('—');
    buffer.writeln('Extracted on ${s.extractedAt.day}/${s.extractedAt.month}/${s.extractedAt.year}');
    buffer.writeln('Always verify important details against the source policy document.');

    return buffer.toString();
  }
}

// ── Reusable helpers ──

class _FieldGroup extends StatelessWidget {
  final List<_FieldItem> items;
  const _FieldGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 28, height: 28,
                decoration: BoxDecoration(color: CoverWiseColors.blueDeep.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                child: Icon(item.icon, size: 16, color: CoverWiseColors.blueDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Text(item.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: item.valueColor ?? Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _FieldItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _FieldItem({required this.icon, required this.label, required this.value, this.valueColor});
}

class _TypeSubSection extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeSubSection({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  const _BulletSection({required this.label, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
          ),
          ...items.map((item) => _BulletItem(text: item, color: color)),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;
  const _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }
}
