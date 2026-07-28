import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/field_citation.dart';
import '../models/policy_summary.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../services/analytics_service.dart';
import '../services/evidence_service.dart';
import '../theme/coverwise_theme.dart';
import '../utils/policy_type.dart';
import '../widgets/field_citations_card.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/editable_field.dart';
import '../services/field_overrides_store.dart';
import '../utils/date_validation.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/contextual_cta_card.dart';
import '../services/lead_generation_service.dart';
import 'claim_assistance_screen.dart';
import 'coverage_gap_screen.dart';
import 'coverage_details_summary_screen.dart';
import 'document_preview_screen.dart';

/// Resolve the display value for an editable field, preferring the
/// user override when present.
String resolveFieldOverride(
  Map<String, OverrideRecord> overrides,
  String field,
  String? extracted,
) {
  final override = overrides[field];
  if (override != null) return override.value;
  return extracted ?? '';
}

/// The core value screen: turns a 40-page policy PDF into one page the user
/// can actually understand.
///
/// Displays everything the system extracted: coverage, premium, deductible,
/// key benefits, exclusions, waiting periods, coverage items, and dates.
/// Provides quick actions: ask a question, view claim guide, call/email insurer.
class PolicyDetailScreen extends ConsumerStatefulWidget {
  final String documentId;

  const PolicyDetailScreen({super.key, required this.documentId});

  @override
  ConsumerState<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends ConsumerState<PolicyDetailScreen> {
  final _overridesStore = FieldOverridesStore();
  Map<String, OverrideRecord> _overrides = {};
  bool _trackedOpened = false;

  @override
  void initState() {
    super.initState();
    _loadOverrides();
  }

  Future<void> _loadOverrides() async {
    final overrides = await _overridesStore.getOverrides(widget.documentId);
    if (mounted) {
      setState(() {
        _overrides = overrides;
      });
    }
  }

  /// Backend-facing identity for this screen.
  ///
  /// Library/dashboard entry points may pass the local Hive ID, while
  /// summaries, evidence, processing status, and source APIs use the server
  /// document ID. Keep the widget ID for local overrides/file lookup, but
  /// resolve the remote ID before calling any backend-owned surface.
  String _backendDocumentId(WidgetRef ref) {
    final documents = ref.read(documentsProvider).asData?.value ?? const [];
    final document = documents
        .where((candidate) =>
            candidate.id == widget.documentId ||
            candidate.remoteId == widget.documentId)
        .firstOrNull;
    return document?.remoteId ?? widget.documentId;
  }

  Future<void> _saveField(String field, String value) async {
    // Validate date fields before saving.
    if (field == 'start_date' || field == 'end_date') {
      if (!isValidDate(value)) {
        if (!mounted) return;
        CoverWiseSnackBar.warning(
          context,
          'Please enter a valid date (DD/MM/YYYY, MM/DD/YYYY, or DD-MM-YYYY)',
        );
        return;
      }
    }
    final extracted = _extractedValue(field);
    await _overridesStore.setOverride(
      documentId: widget.documentId,
      field: field,
      value: value,
      originalValue: extracted,
    );
    await _loadOverrides();
  }

  Future<void> _revertField(String field) async {
    await _overridesStore.removeOverride(widget.documentId, field);
    await _loadOverrides();
  }

  String _extractedValue(String field) {
    final summaries = ref.read(policySummariesProvider);
    final summary = summaries
        .where((s) => s.documentId == _backendDocumentId(ref))
        .firstOrNull;
    if (summary == null) return '';
    return switch (field) {
      'insurer' => summary.insurer ?? '',
      'policy_number' => summary.policyNumber ?? '',
      // Return formatted strings so revert shows the same display
      // the user saw originally (e.g. '₹5,00,000' not '500000').
      'coverage_amount' => summary.formattedCoverageAmount,
      'premium_amount' => summary.formattedPremium,
      'start_date' => summary.formattedStartDate,
      'end_date' => summary.formattedExpiryDate,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(policySummariesProvider);
    // Rebuild when the local-to-server identity map finishes loading. A
    // library entry can arrive with the local Hive ID before this provider's
    // async document list is ready.
    ref.watch(documentsProvider);
    final backendDocumentId = _backendDocumentId(ref);
    final summary =
        summaries.where((s) => s.documentId == backendDocumentId).firstOrNull;

    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Policy Details')),
        body: EmptyStateWidget(
          icon: Icons.manage_search_rounded,
          title: 'Policy summary not available',
          subtitle:
              'Extraction may still be in progress. You can ask about the source document while the summary is prepared.',
          actionLabel: 'Ask about this policy',
          actionIcon: Icons.chat_bubble_outline_rounded,
          onAction: () => Navigator.pushNamed(
            context,
            '/qa',
            arguments: backendDocumentId,
          ),
        ),
      );
    }

    // Phase 0 P0-0.4 (trust audit, 2026-07-18): do NOT display the
    // summary if it fails the minimum-viable-evidence check. The
    // trust audit's NO-GO verdict says a partial summary over an
    // incomplete extraction is a lying product. Show the user
    // "not yet verified" with the specific reason instead.
    if (!summary.hasMinimumViableEvidence) {
      return _buildUnverifiedSummaryScaffold(
        context: context,
        documentId: backendDocumentId,
        summary: summary,
        reason: summary.missingEvidenceReason ??
            'This summary is missing critical fields and cannot be safely displayed yet.',
      );
    }

    final policyType = classifyPolicyType(summary.documentType);

    // Track policy_detail_opened once per mount when summary is available.
    if (!_trackedOpened) {
      _trackedOpened = true;
      AnalyticsService.track('policy_detail_opened', {
        'policy_type': canonicalTypeName(policyType),
        'is_expired': summary.isExpired,
        'has_evidence': summary.hasMinimumViableEvidence,
      });
      // Fire section tracking once, identifying which sections are present.
      final sections = <String>[
        'executive_summary',
        'policy_actions',
        'cited_fields',
        if (summary.motorFields?.hasAnyFields == true) 'vehicle_details',
        if (summary.lifeFields?.hasAnyFields == true) 'life_details',
        if (summary.homeFields?.hasAnyFields == true) 'home_details',
        if (summary.travelFields?.hasAnyFields == true) 'travel_details',
        if (summary.healthFields?.hasAnyFields == true) 'health_details',
        if (summary.marineFields?.hasAnyFields == true) 'marine_details',
        if (summary.keyBenefits.isNotEmpty) 'benefits',
        if (summary.exclusions.isNotEmpty) 'exclusions',
        if (summary.waitingPeriods.isNotEmpty) 'waiting_periods',
        if (summary.coverageItems.isNotEmpty) 'coverage_items',
        'quick_actions',
      ];
      AnalyticsService.track('policy_detail_section_opened', {
        'section_count': sections.length,
        'sections': sections.join(','),
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Policy details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'Full Coverage Summary',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CoverageDetailsSummaryScreen(
                  summary: summary,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'View source document',
            onPressed: () => _openDocumentPreview(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Ask a Question',
            onPressed: () => Navigator.pushNamed(context, '/qa',
                arguments: backendDocumentId),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share Policy Summary',
            onPressed: () => _shareSummary(summary),
          ),
        ],
      ),
      body: ListView(
        key: const ValueKey('policy_detail_body'),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: canonicalTypeName(policyType),
            subtitle: summary.insurer == null
                ? 'Your policy, translated into the details that matter.'
                : '${summary.insurer} \u2022 Your policy at a glance',
          ),
          if (summary.executiveSummary.isNotEmpty) ...[
            _ExecutiveSummaryCard(summary: summary),
            const SizedBox(height: 12),
          ],
          if (_overrides.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _overrides.length == 1
                          ? '1 field corrected'
                          : '${_overrides.length} fields corrected',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          // Trust Phase 1 / Bucket 5 #21 thin slice: navigation
          // to the coverage-gap + claim-assistance screens. The
          // two screens are read-only consumers of the
          // substrate; they re-fetch citations on entry so the
          // navigation is decoupled from the existing
          // _CitedFieldsSection state.
          _PolicyActionsRow(documentId: backendDocumentId),
          // Trust Phase 1: cited fields from the evidence substrate.
          // Renders nothing when the substrate has no verified data
          // (the Phase 0 P0-0.4 path handles that case above this
          // build method via _buildUnverifiedSummaryScaffold).
          _CitedFieldsSection(
            documentId: backendDocumentId,
            onPageTap: (pageNumber) {
              // v1 of the page-level navigation: surface the
              // cited page in a SnackBar and open the source
              // document preview at the cited page. v2 of the
              // highlight overlay (Trust Phase 2 follow-up) will
              // draw the cited span directly on the page image.
              CoverWiseSnackBar.info(
                context,
                'Opening page $pageNumber from the source document…',
              );
              _openDocumentPreview(context, ref, initialPage: pageNumber);
            },
          ),
          _HeaderCard(
            summary: summary,
            policyType: policyType,
            overrides: _overrides,
            onEditField: _saveField,
            onRevertField: _revertField,
          ),
          const SizedBox(height: 12),
          _MoneyRow(
            summary: summary,
            overrides: _overrides,
            onEditField: _saveField,
            onRevertField: _revertField,
          ),
          const SizedBox(height: 12),
          _DatesCard(
            summary: summary,
            overrides: _overrides,
            onEditField: _saveField,
            onRevertField: _revertField,
          ),
          const SizedBox(height: 6),
          // Vehicle details (only for auto/motor policies with extracted data)
          if (summary.motorFields?.hasAnyFields == true)
            _VehicleDetailsCard(fields: summary.motorFields!),
          if (summary.motorFields?.hasAnyFields == true)
            const SizedBox(height: 6),
          // Life policy details (only for life policies with extracted data)
          if (summary.lifeFields?.hasAnyFields == true)
            _LifeDetailsCard(fields: summary.lifeFields!),
          if (summary.lifeFields?.hasAnyFields == true)
            const SizedBox(height: 6),
          // Home policy details (only for home/property policies with extracted data)
          if (summary.homeFields?.hasAnyFields == true)
            _HomeDetailsCard(fields: summary.homeFields!),
          if (summary.homeFields?.hasAnyFields == true)
            const SizedBox(height: 6),
          // Travel policy details (only for travel policies with extracted data)
          if (summary.travelFields?.hasAnyFields == true)
            _TravelDetailsCard(fields: summary.travelFields!),
          if (summary.travelFields?.hasAnyFields == true)
            const SizedBox(height: 6),
          // Health policy details (only for health policies with extracted data)
          if (summary.healthFields?.hasAnyFields == true)
            _HealthDetailsCard(fields: summary.healthFields!),
          if (summary.healthFields?.hasAnyFields == true)
            const SizedBox(height: 6),
          // Marine / cargo details (only for marine policies with extracted data)
          if (summary.marineFields?.hasAnyFields == true)
            _MarineDetailsCard(fields: summary.marineFields!),
          if (summary.marineFields?.hasAnyFields == true)
            const SizedBox(height: 6),
          if (summary.keyBenefits.isNotEmpty) ...[
            const CoverWiseSectionLabel('What this policy covers'),
            Builder(
              builder: (context) => _SectionList(
                title: 'Included benefits',
                icon: Icons.verified_outlined,
                iconColor: Theme.of(context).colorScheme.primary,
                items: summary.keyBenefits,
                itemIcon: Icons.check_rounded,
                itemColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          if (summary.exclusions.isNotEmpty) ...[
            const CoverWiseSectionLabel('Important exclusions'),
            Builder(
              builder: (context) => _SectionList(
                title: 'Not included',
                icon: Icons.block_outlined,
                iconColor: Theme.of(context).colorScheme.error,
                items: summary.exclusions,
                itemIcon: Icons.close_rounded,
                itemColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          if (summary.waitingPeriods.isNotEmpty) ...[
            const CoverWiseSectionLabel('Waiting periods'),
            Builder(
              builder: (context) => _SectionList(
                title: 'Waiting Periods',
                icon: Icons.hourglass_top_rounded,
                iconColor: Theme.of(context).colorScheme.tertiary,
                items: summary.waitingPeriods,
                itemIcon: Icons.access_time,
                itemColor: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          ],
          if (summary.coverageItems.isNotEmpty) ...[
            const CoverWiseSectionLabel('Coverage details'),
            _CoverageItemsCard(items: summary.coverageItems),
          ],
          const CoverWiseSectionLabel('Next steps'),
          _QuickActions(summary: summary),
          // Contextual CTAs based on policy characteristics.
          _PolicyCtas(summary: summary, documentId: backendDocumentId),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Extracted on ${_formatDate(summary.extractedAt)} from your uploaded policy document. '
                    'Always verify important details against the source document and your insurer.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  /// Validates that a string is a plausible date in common formats:
  /// DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY, or DD.MM.YYYY.
  /// Accepts 1 or 2-digit day/month and 2 or 4-digit year.
  /// Validates that a string is a plausible date in common formats:
  /// DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY, or DD.MM.YYYY.
  /// Accepts 1 or 2-digit day/month and 2 or 4-digit year.

  /// Validates that a string is a plausible date in common formats:
  /// DD/MM/YYYY, MM/DD/YYYY, DD-MM-YYYY, MM-DD-YYYY, or DD.MM.YYYY.
  /// Accepts 1 or 2-digit day/month and 2 or 4-digit year.

  void _openDocumentPreview(BuildContext context, WidgetRef ref,
      {int initialPage = 1}) {
    final documents = ref.read(documentsProvider).asData?.value;
    if (documents == null || documents.isEmpty) {
      AnalyticsService.track('policy_detail_source_preview_opened', {
        'available': false,
      });
      if (!context.mounted) return;
      CoverWiseSnackBar.info(
        context,
        'No policies on this device. Upload one to get started.',
      );
      return;
    }

    final doc = documents
        .where(
          (d) => d.id == widget.documentId || d.remoteId == widget.documentId,
        )
        .firstOrNull;

    if (doc == null) {
      AnalyticsService.track('policy_detail_source_preview_opened', {
        'available': false,
      });
      if (!context.mounted) return;
      CoverWiseSnackBar.error(
        context,
        'Document not found on this device. Try refreshing or re-uploading.',
      );
      return;
    }

    if (doc.localFilePath == null || doc.localFilePath!.isEmpty) {
      AnalyticsService.track('policy_detail_source_preview_opened', {
        'available': false,
      });
      if (!context.mounted) return;
      CoverWiseSnackBar.info(
        context,
        'Source document is only available on the device where it was uploaded.',
      );
      return;
    }

    AnalyticsService.track('policy_detail_source_preview_opened', {
      'available': true,
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          filePath: doc.localFilePath!,
          filename: doc.filename,
          documentId: doc.id,
          initialPage: initialPage,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final PolicySummary summary;
  final PolicyType policyType;
  final Map<String, OverrideRecord> overrides;
  final Future<void> Function(String field, String value) onEditField;
  final Future<void> Function(String field) onRevertField;

  const _HeaderCard({
    required this.summary,
    required this.policyType,
    this.overrides = const {},
    required this.onEditField,
    required this.onRevertField,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverWiseIconBadge(
                  icon: iconForPolicyType(policyType),
                  color: colorForPolicyType(
                    policyType,
                    brightness: Theme.of(context).brightness,
                  ),
                  size: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canonicalTypeName(policyType),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (summary.insurer != null) ...[
                        const SizedBox(height: 3),
                        EditableField(
                          label: 'Insurer',
                          value:
                              overrides['insurer']?.value ?? summary.insurer!,
                          originalValue: summary.insurer,
                          hasOverride: overrides.containsKey('insurer'),
                          onSave: (v) => onEditField('insurer', v),
                          onRevert: () => onRevertField('insurer'),
                          hintText: 'Enter insurer name',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(summary: summary),
              ],
            ),
            if (summary.policyNumber != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: EditableField(
                  label: 'Policy number',
                  value: overrides['policy_number']?.value ??
                      summary.policyNumber!,
                  originalValue: summary.policyNumber,
                  hasOverride: overrides.containsKey('policy_number'),
                  onSave: (v) => onEditField('policy_number', v),
                  onRevert: () => onRevertField('policy_number'),
                  hintText: 'Enter policy number',
                ),
              ),
            ],
          ],
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
    String label;
    Color color;
    final scheme = Theme.of(context).colorScheme;
    if (summary.isExpired) {
      label = 'EXPIRED';
      color = scheme.error;
    } else if (summary.isExpiringSoon) {
      label = '${summary.daysUntilExpiry}d LEFT';
      color = scheme.tertiary;
    } else if (summary.isActive) {
      label = 'ACTIVE';
      color = scheme.primary;
    } else {
      label = 'UNKNOWN';
      color = scheme.outline;
    }

    return CoverWiseStatusChip(
      icon: summary.isExpired
          ? Icons.error_rounded
          : summary.isExpiringSoon
              ? Icons.schedule_rounded
              : summary.isActive
                  ? Icons.check_circle_rounded
                  : Icons.help_outline_rounded,
      label: label,
      color: color,
      compact: true,
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final PolicySummary summary;
  final Map<String, OverrideRecord> overrides;
  final Future<void> Function(String field, String value) onEditField;
  final Future<void> Function(String field) onRevertField;

  const _MoneyRow({
    required this.summary,
    this.overrides = const {},
    required this.onEditField,
    required this.onRevertField,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverageDisplay = resolveFieldOverride(
        overrides, 'coverage_amount', summary.formattedCoverageAmount);
    final premiumDisplay = resolveFieldOverride(
        overrides, 'premium_amount', summary.formattedPremium);

    final items = <_MoneyItem>[
      if (summary.coverageAmount != null ||
          overrides.containsKey('coverage_amount'))
        _MoneyItem(
          label: 'Sum Insured',
          labelTooltip:
              'The maximum amount your insurer will pay for a covered claim',
          value: coverageDisplay,
          icon: Icons.shield,
          color: scheme.primary,
          field: 'coverage_amount',
          originalValue: summary.formattedCoverageAmount,
          hasOverride: overrides.containsKey('coverage_amount'),
          onEditField: onEditField,
          onRevertField: onRevertField,
        ),
      if (summary.premiumAmount != null ||
          overrides.containsKey('premium_amount'))
        _MoneyItem(
          label: 'Premium',
          value: premiumDisplay,
          icon: Icons.payments,
          color: scheme.primary,
          field: 'premium_amount',
          originalValue: summary.formattedPremium,
          hasOverride: overrides.containsKey('premium_amount'),
          onEditField: onEditField,
          onRevertField: onRevertField,
        ),
      if (summary.deductible != null)
        _MoneyItem(
          label: 'Deductible',
          value: '₹${summary.deductible!.toStringAsFixed(0)}',
          icon: Icons.money_off,
          color: scheme.tertiary,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = items.length == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) / items.length;
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: items
                  .map(
                    (item) => Semantics(
                      label: [
                        '${item.label}: ${item.value}',
                        if (item.labelTooltip != null) item.labelTooltip!,
                      ].join('. '),
                      excludeSemantics: true,
                      child: SizedBox(
                        width: itemWidth
                            .clamp(104.0, constraints.maxWidth)
                            .toDouble(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              CoverWiseIconBadge(
                                icon: item.icon,
                                color: item.color,
                                size: 38,
                              ),
                              const SizedBox(height: 8),
                              item.field != null && item.onEditField != null
                                  ? EditableField(
                                      label: item.label,
                                      labelTooltip: item.labelTooltip,
                                      value: item.value,
                                      originalValue: item.originalValue,
                                      hasOverride: item.hasOverride,
                                      onSave: (v) =>
                                          item.onEditField!(item.field!, v),
                                      onRevert: item.hasOverride &&
                                              item.onRevertField != null
                                          ? () =>
                                              item.onRevertField!(item.field!)
                                          : null,
                                      hintText:
                                          'Enter ${item.label.toLowerCase()}',
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        item.value,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800),
                                      ),
                                    ),
                              const SizedBox(height: 3),
                              if (item.field == null)
                                Text(
                                  item.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

class _MoneyItem {
  final String label;
  final String? labelTooltip;
  final String value;
  final IconData icon;
  final Color color;
  final String? field;
  final String? originalValue;
  final bool hasOverride;
  final Future<void> Function(String field, String value)? onEditField;
  final Future<void> Function(String field)? onRevertField;

  _MoneyItem({
    required this.label,
    this.labelTooltip,
    required this.value,
    required this.icon,
    required this.color,
    this.field,
    this.originalValue,
    this.hasOverride = false,
    this.onEditField,
    this.onRevertField,
  });
}

class _DatesCard extends StatelessWidget {
  final PolicySummary summary;
  final Map<String, OverrideRecord> overrides;
  final Future<void> Function(String field, String value) onEditField;
  final Future<void> Function(String field) onRevertField;

  const _DatesCard({
    required this.summary,
    this.overrides = const {},
    required this.onEditField,
    required this.onRevertField,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.startDate == null && summary.endDate == null) {
      return const SizedBox.shrink();
    }

    // Note (v2): if summary.startDate is null but user has an override
    // for 'start_date', this card still hides because of the null check.
    // Acceptable for v1 since you can't correct a field that doesn't exist.
    final startDisplay = resolveFieldOverride(
        overrides, 'start_date', summary.formattedStartDate);
    final endDisplay = resolveFieldOverride(
        overrides, 'end_date', summary.formattedExpiryDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CoverWiseIconBadge(
              icon: Icons.calendar_month_outlined,
              color: CoverWiseColors.blueDeep,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (summary.startDate != null)
                    EditableField(
                      label: 'Start date',
                      value: startDisplay,
                      originalValue: summary.formattedStartDate,
                      hasOverride: overrides.containsKey('start_date'),
                      onSave: (v) => onEditField('start_date', v),
                      onRevert: overrides.containsKey('start_date')
                          ? () => onRevertField('start_date')
                          : null,
                      hintText: 'e.g. 01/01/2025',
                    ),
                  if (summary.endDate != null) ...[
                    const SizedBox(height: 8),
                    EditableField(
                      label: 'End date',
                      value: endDisplay,
                      originalValue: summary.formattedExpiryDate,
                      hasOverride: overrides.containsKey('end_date'),
                      onSave: (v) => onEditField('end_date', v),
                      onRevert: overrides.containsKey('end_date')
                          ? () => onRevertField('end_date')
                          : null,
                      hintText: 'e.g. 31/12/2025',
                    ),
                  ],
                  if (summary.isActive || summary.isExpiringSoon) ...[
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final scheme = Theme.of(context).colorScheme;
                        return Text(
                          '${summary.daysUntilExpiry} days remaining',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: summary.isExpiringSoon
                                ? scheme.tertiary
                                : scheme.primary,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> items;
  final IconData itemIcon;
  final Color itemColor;

  const _SectionList({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.itemIcon,
    required this.itemColor,
  });

  @override
  Widget build(BuildContext context) {
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
                  icon: icon,
                  color: iconColor,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(itemIcon, size: 15, color: itemColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _CoverageItemsCard extends StatelessWidget {
  final List<CoverageItem> items;
  const _CoverageItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
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
                  icon: Icons.fact_check_outlined,
                  color: CoverWiseColors.blueDeep,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'Detailed breakdown',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Builder(
                    builder: (context) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.covered ? Icons.check_circle : Icons.cancel,
                          size: 18,
                          color: item.covered
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (item.limitText != null)
                                Text(
                                  item.limitText!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              if (item.limit != null && item.limitText == null)
                                Text(
                                  'Limit: ₹${item.limit!.toStringAsFixed(0)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              if (item.notes != null)
                                Text(
                                  item.notes!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Life policy details card (shown only for life insurance policies).
///
/// Displays fields like life assured, sum assured, term length, nominee,
/// riders, and policy provisions when LifePolicyFields is populated.
class _LifeDetailsCard extends StatelessWidget {
  final LifePolicyFields fields;

  const _LifeDetailsCard({required this.fields});

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
          tooltip: 'The amount the insurer will pay to the nominee upon the death of the life assured or at policy maturity. This is the core benefit of the life insurance policy.',
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
          tooltip: 'An additional payout over and above the basic sum assured if death is caused by an accident. This is typically equal to the sum assured and provides extra financial protection to the family.',
        ),
      if (fields.terminalIllnessBenefit != null)
        _LifeDetailItem(
          icon: Icons.medical_services_rounded,
          label: 'Terminal Illness Benefit',
          value: fields.terminalIllnessBenefit!,
          tooltip: 'A lump-sum benefit paid if the life assured is diagnosed with a terminal illness with limited life expectancy (usually 12 months or less). This gives you access to the sum assured when you need it most.',
        ),
      if (fields.deathBenefitType != null)
        _LifeDetailItem(
          icon: Icons.category_rounded,
          label: 'Death Benefit Type',
          value: fields.deathBenefitType!,
          tooltip: 'Describes how the death benefit is structured — lump sum (one-time payment), monthly income (salary option paid over several years), or a combination of both.',
        ),
      if (fields.policyTypeDetail != null)
        _LifeDetailItem(
          icon: Icons.account_tree_rounded,
          label: 'Policy Sub-type',
          value: fields.policyTypeDetail!,
          tooltip: 'Further classification of your life insurance policy — term plan (pure protection), endowment (savings + protection), ULIP (market-linked), whole life, money-back, or child plan.',
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
                  color: colorForPolicyType(PolicyType.life, brightness: theme.brightness),
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
                children: fields.riderDetails.map((rider) => Chip(
                  label: Text(rider, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )).toList(),
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
                _ProvisionRow(
                  icon: Icons.block_rounded,
                  label: 'Suicide Exclusion',
                  value: fields.suicideExclusion!,
                  tooltip: 'Most life policies do not pay the death benefit if the insured dies by suicide within the first 12 months of the policy.',
                ),
              if (fields.freeLookPeriod != null)
                _ProvisionRow(
                  icon: Icons.remove_red_eye_rounded,
                  label: 'Free Look Period',
                  value: fields.freeLookPeriod!,
                  tooltip: 'The cooling-off period during which you can review the policy and return it for a full refund if you are not satisfied.',
                ),
              if (fields.gracePeriod != null)
                _ProvisionRow(
                  icon: Icons.schedule_rounded,
                  label: 'Grace Period',
                  value: fields.gracePeriod!,
                  tooltip: 'Extra time after the premium due date during which the policy remains active. If you pay within this period, coverage continues without a break.',
                ),
              if (fields.surrenderValue != null)
                _ProvisionRow(
                  icon: Icons.monetization_on_rounded,
                  label: 'Surrender Value',
                  value: fields.surrenderValue!,
                  tooltip: 'The amount you receive if you cancel the policy before its maturity. This is usually a portion of the premiums paid, and is available only after a minimum number of years.',
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
              color: colorForPolicyType(PolicyType.life, brightness: Theme.of(context).brightness).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              size: 18,
              color: colorForPolicyType(PolicyType.life, brightness: Theme.of(context).brightness),
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

class _ProvisionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? tooltip;

  const _ProvisionRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          tooltip != null
              ? Tooltip(
                  message: tooltip!,
                  triggerMode: TooltipTriggerMode.longPress,
                  child: Text(
                    '$label: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Text(
                  '$label: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Vehicle-specific details card (shown only for auto/motor policies).
///
/// Displays fields like VIN, registration number, NCB, IDV, vehicle
/// make/model, and add-on covers when MotorPolicyFields is populated.
class _VehicleDetailsCard extends StatelessWidget {
  final MotorPolicyFields fields;

  const _VehicleDetailsCard({required this.fields});

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
          tooltip: 'A discount on your premium for every claim-free year. A higher NCB percentage means a lower premium at renewal.',
        ),
      if (fields.idv != null)
        _VehicleDetailItem(
          icon: Icons.account_balance_rounded,
          label: 'IDV (Insured Declared Value)',
          value: '₹${_formatAmount(fields.idv!)}',
          valueColor: cs.primary,
          tooltip: 'The maximum amount your insurer will pay if your vehicle is stolen or completely damaged. It is the current market value of your vehicle, not the purchase price.',
        ),
      if (fields.ownDamagePremium != null)
        _VehicleDetailItem(
          icon: Icons.payments_rounded,
          label: 'Own Damage Premium',
          value: '₹${_formatAmount(fields.ownDamagePremium!)}',
          tooltip: 'The portion of your premium that covers damage to your own vehicle. This part is optional for older vehicles but required for comprehensive policies.',
        ),
      if (fields.thirdPartyPremium != null)
        _VehicleDetailItem(
          icon: Icons.people_rounded,
          label: 'Third Party Premium',
          value: '₹${_formatAmount(fields.thirdPartyPremium!)}',
          tooltip: 'The portion of your premium that covers damage you cause to other people, their vehicles, or property. This is mandatory by law for all motor insurance policies.',
        ),
      if (fields.policyTypeDetail != null)
        _VehicleDetailItem(
          icon: Icons.category_rounded,
          label: 'Policy Type',
          value: fields.policyTypeDetail!,
          tooltip: 'Comprehensive covers both own damage and third-party liability. Third Party Only covers only damage you cause to others — your own vehicle is NOT covered.',
        ),
      if (fields.geographicalLimit != null)
        _VehicleDetailItem(
          icon: Icons.public_rounded,
          label: 'Geographical Limit',
          value: fields.geographicalLimit!,
          tooltip: 'The area within which your vehicle is covered. Some policies limit coverage to certain zones or states within India.',
        ),
      if (fields.personalAccidentCoverOwner != null)
        _VehicleDetailItem(
          icon: Icons.person_rounded,
          label: 'PA Cover (Owner)',
          value: '₹${_formatAmount(fields.personalAccidentCoverOwner!)}',
          valueColor: cs.primary,
          tooltip: 'Personal Accident cover provides a lump-sum payout to you or your family if you die or are permanently disabled in a vehicle accident.',
        ),
      if (fields.cubicCapacity != null)
        _VehicleDetailItem(
          icon: Icons.speed_rounded,
          label: 'Engine CC',
          value: fields.cubicCapacity!,
          tooltip: 'The engine displacement or cubic capacity. This determines your premium bracket — higher CC vehicles generally cost more to insure.',
        ),
      if (fields.seatingCapacity != null)
        _VehicleDetailItem(
          icon: Icons.event_seat_rounded,
          label: 'Seating Capacity',
          value: '${fields.seatingCapacity} seats',
          tooltip: 'The number of seats including the driver. This affects personal accident cover calculations and premium for certain policy types.',
        ),
      if (fields.garagingPincode != null)
        _VehicleDetailItem(
          icon: Icons.location_on_rounded,
          label: 'Garaging Pincode',
          value: fields.garagingPincode!,
          tooltip: 'The pincode where your vehicle is usually parked. Insurers use this to assess the risk of theft or damage based on the location.',
        ),
      if (fields.fuelType != null)
        _VehicleDetailItem(
          icon: Icons.local_gas_station_rounded,
          label: 'Fuel Type',
          value: fields.fuelType!,
          tooltip: 'The type of fuel your vehicle uses — Petrol, Diesel, CNG, or Electric. This affects the premium calculation and coverage eligibility.',
        ),
      if (fields.voluntaryDeductible != null)
        _VehicleDetailItem(
          icon: Icons.money_off_rounded,
          label: 'Voluntary Deductible',
          value: fields.voluntaryDeductible!,
          tooltip: 'An additional excess you voluntarily choose to pay per claim in exchange for a lower premium. A higher voluntary deductible reduces your premium but increases your out-of-pocket cost at claim time.',
        ),
      if (fields.hypothecation != null)
        _VehicleDetailItem(
          icon: Icons.account_balance_rounded,
          label: 'Hypothecation',
          value: fields.hypothecation!,
          tooltip: 'The bank or financial institution that holds a lien on your vehicle. The insurer may need their approval for claim settlements, especially for total loss or theft.',
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
                children: fields.addOnCovers.map((cover) => Chip(
                  label: Text(cover, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )).toList(),
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

/// Home/property policy details card (shown only for home insurance policies).
///
/// Displays fields like property address, building/contents sum insured, rebuild
/// cost, perils covered, exclusions, and add-on covers when HomePolicyFields is populated.
class _HomeDetailsCard extends StatelessWidget {
  final HomePolicyFields fields;

  const _HomeDetailsCard({required this.fields});

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
            // Property address
            if (fields.propertyAddress != null) ...[
              _HomeDetailRow(
                icon: Icons.location_on_rounded,
                label: 'Property Address',
                value: fields.propertyAddress!,
              ),
            ],
            // Structure type + Policy type
            if (fields.structureType != null || fields.policyType != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (fields.structureType != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            ],
            // Sum insured amounts
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
                tooltip: 'The amount you must pay out of pocket before the insurance coverage kicks in for a claim. A higher deductible usually means a lower premium.',
              ),
            // Perils covered
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
                children: fields.perilsCovered.map((peril) => Chip(
                  label: Text(peril, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  avatar: Icon(Icons.check_rounded, size: 14, color: cs.primary),
                  labelStyle: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )).toList(),
              ),
            ],
            // Perils excluded
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
                children: fields.perilsExcluded.map((peril) => Chip(
                  label: Text(peril, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: cs.error.withValues(alpha: 0.1),
                  avatar: Icon(Icons.close_rounded, size: 14, color: cs.error),
                  labelStyle: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )).toList(),
              ),
            ],
            // Occupancy + Construction type chips
            if (fields.occupancyType != null || fields.constructionType != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    if (fields.occupancyType != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            ],
            // Underinsurance clause
            if (fields.underinsuranceClause != null)
              _HomeDetailRow(
                icon: Icons.warning_rounded,
                label: 'Underinsurance Clause',
                value: fields.underinsuranceClause!,
                valueColor: cs.error,
                tooltip: 'If your building or contents are insured for less than their actual value, the insurer will proportionately reduce your claim payout. This is one of the most important clauses to understand.',
              ),
            // Year built
            if (fields.yearBuilt != null)
              _HomeDetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Year Built',
                value: fields.yearBuilt!.toString(),
              ),
            // Escalation clause
            if (fields.escalationClause != null)
              _HomeDetailRow(
                icon: Icons.trending_up_rounded,
                label: 'Escalation Clause',
                value: fields.escalationClause!,
                valueColor: cs.primary,
                tooltip: 'An automatic annual increase in your sum insured to keep pace with inflation. This helps ensure your coverage stays adequate over time without you having to request an increase.',
              ),
            // Add-on covers
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
                children: fields.addOnCovers.map((cover) => Chip(
                  label: Text(cover, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: cs.tertiary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: cs.tertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )).toList(),
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

/// Health insurance details card (shown only for health insurance policies).
///
/// Displays fields like room rent cap, pre-existing diseases, co-pay percentage,
/// network hospitals, maternity cover, and other health-specific details when
/// HealthPolicyFields is populated.
class _HealthDetailsCard extends StatelessWidget {
  final HealthPolicyFields fields;

  const _HealthDetailsCard({required this.fields});

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
            // Room rent cap
            if (fields.roomRentCap != null)
              _HealthDetailRow(
                icon: Icons.bed_rounded,
                label: 'Room Rent Cap',
                value: fields.roomRentCap!,
                tooltip: 'The maximum room rent the insurer will pay for. If you choose a more expensive room, you pay the difference — and some other costs may also be proportionally reduced.',
              ),
            // Co-pay
            if (fields.coPayPercent != null)
              _HealthDetailRow(
                icon: Icons.percent_rounded,
                label: 'Co-pay',
                value: '${fields.coPayPercent!.toStringAsFixed(0)}%',
                valueColor: cs.error,
                tooltip: 'The percentage of the claim amount you must pay from your own pocket. For example, a 10% co-pay means you pay ₹10,000 of a ₹1,00,000 claim.',
              ),
            // Deductible per claim
            if (fields.deductiblePerClaim != null)
            _HealthDetailRow(
              icon: Icons.money_off_rounded,
              label: 'Deductible per claim',
              value: '₹${_formatHealthAmount(fields.deductiblePerClaim!)}',
              tooltip: 'The amount you pay out of pocket before the insurance coverage begins for each hospitalization. For example, with a ₹5,000 deductible, the first ₹5,000 of your hospital bill is your responsibility.',
            ),
            // Ambulance cover
            if (fields.ambulanceCover != null)
            _HealthDetailRow(
              icon: Icons.local_hospital_rounded,
              label: 'Ambulance Cover',
              value: '₹${_formatHealthAmount(fields.ambulanceCover!)}',
              valueColor: cs.primary,
              tooltip: 'Coverage for ambulance charges to transport you to and from the hospital. This includes both emergency and non-emergency transport, up to the specified limit.',
            ),
            // Network hospitals
            if (fields.networkHospitals != null)
            _HealthDetailRow(
              icon: Icons.local_hotel_rounded,
              label: 'Network Hospitals',
              value: fields.networkHospitals!,
              tooltip: 'Hospitals empanelled by your insurer where you can receive cashless treatment — you do not need to pay upfront. Outside these hospitals, you may need to file a reimbursement claim.',
            ),
            // Maternity cover
            if (fields.maternityCover != null)
            _HealthDetailRow(
              icon: Icons.child_friendly_rounded,
              label: 'Maternity Cover',
              value: fields.maternityCover!,
              tooltip: 'Coverage for maternity-related expenses including delivery (normal or C-section), pre-natal and post-natal care. Most policies have a waiting period of 9 to 24 months before maternity benefits apply.',
            ),
            // Cumulative bonus
            if (fields.cumulativeBonus != null)
              _HealthDetailRow(
                icon: Icons.trending_up_rounded,
                label: 'Cumulative Bonus',
                value: fields.cumulativeBonus!,
                tooltip: 'Also called No Claim Bonus. Your sum insured increases by a fixed percentage for every claim-free year, without any additional premium.',
              ),
            // Day care procedures
            if (fields.dayCareProcedures != null)
            _HealthDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Day Care Procedures',
              value: fields.dayCareProcedures!,
              tooltip: 'Procedures that do not require 24-hour hospitalization but are still covered by the policy. IRDAI mandates coverage for over 150 such procedures including dialysis, chemotherapy, and cataract surgery.',
            ),
            // Consumables cover
            if (fields.consumablesCover != null)
            _HealthDetailRow(
              icon: Icons.medical_services_rounded,
              label: 'Consumables Cover',
              value: fields.consumablesCover!,
              tooltip: 'Coverage for medical consumables used during hospitalization like gloves, syringes, PPE kits, sutures, and surgical supplies. Many policies now include these as per IRDAI guidelines.',
            ),
            // Health checkup cover
            if (fields.healthCheckupCover != null)
            _HealthDetailRow(
              icon: Icons.favorite_border_rounded,
              label: 'Health Checkup',
              value: fields.healthCheckupCover!,
              tooltip: 'Free or discounted preventive health checkups included with your policy. These are typically available once a year and may include blood tests, ECG, and other basic screenings.',
            ),
            // Pre/post hospitalization days
            if (fields.prePostHospitalizationDays != null)
            _HealthDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Pre/Post Hospitalization',
              value: fields.prePostHospitalizationDays!,
              tooltip: 'Medical expenses incurred a certain number of days before hospitalization (pre) and after discharge (post) that are covered by the policy. These include doctor consultations, diagnostic tests, and follow-up treatments.',
            ),
            // Restoration benefit
            if (fields.restorationBenefit != null)
              _HealthDetailRow(
                icon: Icons.refresh_rounded,
                label: 'Restoration Benefit',
                value: fields.restorationBenefit!,
                valueColor: cs.primary,
                tooltip: 'Your full sum insured is restored once it is exhausted by a claim. This means you get a second helping of coverage within the same policy year, typically for a different illness or accident.',
              ),
            // Modern treatment cover
            if (fields.modernTreatmentCover != null)
              _HealthDetailRow(
                icon: Icons.biotech_rounded,
                label: 'Modern Treatments',
                value: fields.modernTreatmentCover!,
                tooltip: 'Coverage for advanced medical procedures like robotic surgery, laparoscopic procedures, and other non-invasive treatments that IRDAI mandates all health insurers to cover.',
              ),
            // Moratorium period
            if (fields.moratoriumPeriod != null)
              _HealthDetailRow(
                icon: Icons.verified_user_rounded,
                label: 'Moratorium Period',
                value: fields.moratoriumPeriod!,
                tooltip: 'After this number of continuous years with the policy, the insurer cannot contest any claims except for proven fraud. All pre-existing disease exclusions and waiting periods expire after this period.',
              ),
            // Pre-auth time limit
            if (fields.preAuthTimeLimit != null)
              _HealthDetailRow(
                icon: Icons.flash_on_rounded,
                label: 'Cashless Approval Time',
                value: fields.preAuthTimeLimit!,
                valueColor: cs.primary,
                tooltip: 'The maximum time your insurer has to approve a cashless hospitalization request. IRDAI mandates that insurers must respond within this time frame at a network hospital.',
              ),
            // Domiciliary hospitalization
            if (fields.domiciliaryHospitalization != null)
              _HealthDetailRow(
                icon: Icons.home_rounded,
                label: 'Home Hospitalization',
                value: fields.domiciliaryHospitalization!,
                tooltip: 'Coverage for medical treatment received at home instead of a hospital, for conditions that would normally require hospitalization. Subject to policy limits and doctor certification.',
              ),
            // Sub-limits
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
                children: fields.subLimits.map((limit) => Chip(
                  label: Text(limit, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )).toList(),
              ),
            ],
            // No Claim Bonus percent
            if (fields.noClaimBonusPercent != null)
              _HealthDetailRow(
                icon: Icons.trending_up_rounded,
                label: 'NCB (No Claim Bonus)',
                value: '${fields.noClaimBonusPercent!.toStringAsFixed(0)}% per claim-free year',
                valueColor: cs.primary,
                tooltip: 'The percentage by which your sum insured increases for every claim-free year. For example, a 50% NCB means your coverage increases by half with each year without a claim.',
              ),
            // Critical illness list
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
            // Pre-existing diseases
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
  final String? tooltip;

  const _HealthDetailRow({
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

/// Travel policy details card (shown only for travel insurance policies).
///
/// Displays fields like destination, trip dates, covers (medical, baggage,
/// cancellation, flight delay) and add-on covers when TravelPolicyFields
/// is populated.
class _TravelDetailsCard extends StatelessWidget {
  final TravelPolicyFields fields;

  const _TravelDetailsCard({required this.fields});

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
            // Traveller name
            if (fields.travellerName != null)
              _TravelDetailRow(
                icon: Icons.person_rounded,
                label: 'Traveller',
                value: fields.travellerName!,
              ),
            // Destination
            if (fields.destination != null)
              _TravelDetailRow(
                icon: Icons.explore_rounded,
                label: 'Destination',
                value: fields.destination!,
              ),
            // Trip type
            if (fields.tripType != null)
              _TravelDetailRow(
                icon: Icons.category_rounded,
                label: 'Trip Type',
                value: fields.tripType!,
              ),
            // Trip dates
            if (fields.tripStartDate != null || fields.tripEndDate != null)
              _TravelDetailRow(
                icon: Icons.date_range_rounded,
                label: 'Trip Dates',
                value: [
                  if (fields.tripStartDate != null) fields.tripStartDate!,
                  if (fields.tripStartDate != null && fields.tripEndDate != null) ' — ',
                  if (fields.tripEndDate != null) fields.tripEndDate!,
                ].join(),
              ),
            // Duration
            if (fields.tripDurationDays != null)
              _TravelDetailRow(
                icon: Icons.timer_rounded,
                label: 'Duration',
                value: '${fields.tripDurationDays} days',
              ),
            // Emergency assistance
            if (fields.emergencyAssistancePhone != null)
              _TravelDetailRow(
                icon: Icons.phone_in_talk_rounded,
                label: '24x7 Assistance',
                value: fields.emergencyAssistancePhone!,
                valueColor: cs.primary,
              ),
            // Geographical zone
            if (fields.geographicalZone != null)
              _TravelDetailRow(
                icon: Icons.map_rounded,
                label: 'Geographical Zone',
                value: fields.geographicalZone!,
                tooltip: 'The region or area where your travel insurance coverage applies. Some policies cover worldwide (excluding the US/Canada), while others are limited to specific regions like Asia.',
              ),
            // Pre-existing condition waiver
            if (fields.preexistingConditionWaiver != null)
              _TravelDetailRow(
                icon: Icons.healing_rounded,
                label: 'Pre-existing Conditions',
                value: fields.preexistingConditionWaiver!,
                tooltip: 'Coverage for medical conditions that existed before you bought the travel policy. Most travel plans do not cover these unless a waiver is purchased or the policy specifically includes them.',
              ),
            // Adventure sports cover
            if (fields.adventureSportsCover != null)
              _TravelDetailRow(
                icon: Icons.downhill_skiing_rounded,
                label: 'Adventure Sports',
                value: fields.adventureSportsCover!,
                tooltip: 'Coverage for injuries or accidents during adventure activities such as skiing, scuba diving, bungee jumping, trekking, or parasailing. Standard travel policies usually exclude these activities.',
              ),
            // Financial covers
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
                  value: '₹${_formatTravelAmount(fields.medicalEvacuationCover!)}',
                ),
              if (fields.personalAccidentCover != null)
                _TravelDetailRow(
                  icon: Icons.shield_rounded,
                  label: 'Personal Accident',
                  value: '₹${_formatTravelAmount(fields.personalAccidentCover!)}',
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
                  value: '₹${_formatTravelAmount(fields.tripCancellationCover!)}',
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
                  tooltip: 'A fixed compensation paid to you if your aircraft is hijacked during the trip. The amount is usually paid for each full 24-hour period of the hijack, up to a maximum number of days.',
                ),
              if (fields.passportLossCover != null)
                _TravelDetailRow(
                  icon: Icons.airplane_ticket_rounded,
                  label: 'Passport Loss',
                  value: fields.passportLossCover!,
                  tooltip: 'Coverage for the cost of replacing a lost or stolen passport while travelling abroad. This typically covers the fee for a temporary passport from your embassy.',
                ),
              if (fields.deductiblePerClaimTravel != null)
                _TravelDetailRow(
                  icon: Icons.money_off_rounded,
                  label: 'Deductible per Claim',
                  value: '₹${_formatTravelAmount(fields.deductiblePerClaimTravel!)}',
                  tooltip: 'The amount you must pay out of pocket for each travel claim before the insurance kicks in. For example, if your deductible is ₹2,000 and your claim is ₹15,000, you pay ₹2,000 and the insurer pays ₹13,000.',
                ),
            ],
            // Add-on covers
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
                children: fields.addOnCovers.map((cover) => Chip(
                  label: Text(cover, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: cs.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )).toList(),
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

/// Marine / cargo insurance detail card.
/// Renders only when the policy type is marine and fields are present.
class _MarineDetailsCard extends StatelessWidget {
  final MarinePolicyFields fields;

  const _MarineDetailsCard({required this.fields});

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
                  'Voyage \u0026 Cargo Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Policy sub-type
            if (fields.policyTypeMarine != null)
              _MarineDetailRow(
                icon: Icons.category_rounded,
                label: 'Policy Type',
                value: fields.policyTypeMarine!,
              ),
            // Vessel name
            if (fields.vesselName != null)
              _MarineDetailRow(
                icon: Icons.directions_boat_rounded,
                label: 'Vessel',
                value: fields.vesselName!,
              ),
            // Conveyance
            if (fields.conveyance != null)
              _MarineDetailRow(
                icon: Icons.local_shipping_rounded,
                label: 'Conveyance',
                value: fields.conveyance!,
              ),
            // Voyage details
            if (fields.voyageDetails != null)
              _MarineDetailRow(
                icon: Icons.route_rounded,
                label: 'Voyage',
                value: fields.voyageDetails!,
              ),
            // Voyage from / to
            if (fields.voyageFrom != null || fields.voyageTo != null)
              _MarineDetailRow(
                icon: Icons.map_rounded,
                label: 'Route',
                value: [
                  if (fields.voyageFrom != null) 'From: ${fields.voyageFrom}',
                  if (fields.voyageTo != null) 'To: ${fields.voyageTo}',
                ].join('  \u2022  '),
              ),
            // Transit dates
            if (fields.transitStartDate != null || fields.transitEndDate != null)
              _MarineDetailRow(
                icon: Icons.date_range_rounded,
                label: 'Transit Period',
                value: [
                  if (fields.transitStartDate != null) fields.transitStartDate!,
                  if (fields.transitStartDate != null && fields.transitEndDate != null) ' — ',
                  if (fields.transitEndDate != null) fields.transitEndDate!,
                ].join(),
              ),
            // Cargo description
            if (fields.cargoDescription != null)
              _MarineDetailRow(
                icon: Icons.inventory_2_rounded,
                label: 'Cargo',
                value: fields.cargoDescription!,
              ),
            // Cargo value
            if (fields.cargoValue != null)
              _MarineDetailRow(
                icon: Icons.attach_money_rounded,
                label: 'Cargo Value',
                value: fields.cargoValue!,
                valueColor: cs.primary,
              ),
            // INCO terms
            if (fields.incoterms != null)
              _MarineDetailRow(
                icon: Icons.gavel_rounded,
                label: 'INCO Terms',
                value: fields.incoterms!,
                tooltip: 'International Commercial Terms that define who is responsible for insurance, shipping, and customs. Common terms: CIF (seller arranges insurance), FOB (buyer arranges insurance), CFR, EXW.',
              ),
            // Institute clauses
            if (fields.instituteClauses != null)
              _MarineDetailRow(
                icon: Icons.description_rounded,
                label: 'Institute Clauses',
                value: fields.instituteClauses!,
                tooltip: 'The standard set of marine insurance clauses that determine the scope of coverage. ICC (A) is broadest (all risks), ICC (B) covers named perils, ICC (C) covers major perils only.',
              ),
            // Certificate number
            if (fields.marineInsuranceCertificateNo != null)
              _MarineDetailRow(
                icon: Icons.badge_rounded,
                label: 'Certificate No.',
                value: fields.marineInsuranceCertificateNo!,
              ),
            // Key clauses
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
                tooltip: 'A maritime principle where all cargo owners proportionally share the cost of cargo deliberately sacrificed to save the ship. Whether this is covered or excluded is a critical claim issue.',
              ),
            if (fields.warehouseToWarehouse != null)
              _MarineDetailRow(
                icon: Icons.warehouse_rounded,
                label: 'Whse-to-Whse',
                value: fields.warehouseToWarehouse!,
                tooltip: 'Warehouse-to-warehouse clause — whether coverage applies from the seller\'s warehouse to the buyer\'s warehouse, including inland transit. Typically max 60 days at destination.',
              ),
            if (fields.warRiskClause != null)
              _MarineDetailRow(
                icon: Icons.gpp_maybe_rounded,
                label: 'War Risk',
                value: fields.warRiskClause!,
                tooltip: 'Whether war, civil war, revolution, and related risks are covered. Standard Institute Cargo Clauses exclude war risk; a separate Institute War Clauses policy is needed.',
              ),
            if (fields.strikesRiotsClause != null)
              _MarineDetailRow(
                icon: Icons.people_outline_rounded,
                label: 'Strikes / Riots',
                value: fields.strikesRiotsClause!,
                tooltip: 'Whether strikes, lockouts, civil commotion, and malicious acts are covered. Standard ICC clauses exclude these; a separate Institute Strikes Clauses policy is needed.',
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
  final String? tooltip;

  const _MarineDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.tooltip,
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
                tooltip != null
                    ? Tooltip(
                        message: tooltip!,
                        triggerMode: TooltipTriggerMode.longPress,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.info_outline_rounded,
                              size: 12,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      )
                    : Text(
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

class _TravelDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final String? tooltip;

  const _TravelDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.tooltip,
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

class _QuickActions extends StatelessWidget {
  final PolicySummary summary;

  // Policy detail audit P0-2 (2026-07-18): the previous constructor
  // took a `BuildContext context` parameter that shadowed the
  // build method's own context. The field was unused. Removed.
  const _QuickActions({required this.summary});

  @override
  Widget build(BuildContext context) {
    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Ask about this policy'),
              onPressed: () => Navigator.pushNamed(
                context,
                '/qa',
                arguments: summary.documentId,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Record a claim'),
              onPressed: () => Navigator.pushNamed(context, '/claim-tracker'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Share policy summary'),
              onPressed: () => _shareSummary(summary),
            ),
            if (summary.insurerHelpline != null ||
                summary.insurerEmail != null) ...[
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackActions = constraints.maxWidth < 310;
                  final actions = <Widget>[
                    if (summary.insurerHelpline != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('Call insurer'),
                        onPressed: () => _launchUrl(
                          'tel:${summary.insurerHelpline!.replaceAll(RegExp(r'[^0-9+]'), '')}',
                        ),
                      ),
                    if (summary.insurerEmail != null)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Email insurer'),
                        onPressed: () =>
                            _launchUrl('mailto:${summary.insurerEmail}'),
                      ),
                  ];
                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: actions
                          .expand((action) => [
                                action,
                                if (action != actions.last)
                                  const SizedBox(height: 8),
                              ])
                          .toList(),
                    );
                  }
                  return Row(
                    children: actions
                        .expand((action) => [
                              Expanded(child: action),
                              if (action != actions.last)
                                const SizedBox(width: 8),
                            ])
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Builds the shareable text for a policy summary.
/// Extracted as a pure function for testability.
String buildShareSummaryText(PolicySummary summary) {
  final buffer = StringBuffer();
  buffer.writeln('📋 ${summary.documentType}');
  if (summary.insurer != null) buffer.writeln('🏢 ${summary.insurer}');
  if (summary.policyNumber != null) {
    buffer.writeln('🔢 Policy: ${summary.policyNumber}');
  }
  buffer.writeln('');
  if (summary.coverageAmount != null) {
    buffer.writeln('🛡️ Coverage: ${summary.formattedCoverageAmount}');
  }
  if (summary.premiumAmount != null) {
    buffer.writeln('💰 Premium: ${summary.formattedPremium}');
  }
  if (summary.deductible != null) {
    buffer.writeln('📉 Deductible: ₹${summary.deductible!.toStringAsFixed(0)}');
  }
  buffer.writeln('');
  if (summary.startDate != null) {
    buffer.writeln('📅 From: ${summary.formattedStartDate}');
  }
  if (summary.endDate != null) {
    buffer.writeln('📅 Until: ${summary.formattedExpiryDate}');
  }
  if (summary.isActive || summary.isExpiringSoon) {
    buffer.writeln('⏰ ${summary.daysUntilExpiry} days remaining');
  }
  if (summary.keyBenefits.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('✅ Benefits:');
    for (final b in summary.keyBenefits) {
      buffer.writeln('  • $b');
    }
  }
  if (summary.exclusions.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('❌ Exclusions:');
    for (final e in summary.exclusions) {
      buffer.writeln('  • $e');
    }
  }
  buffer.writeln('');
  buffer.writeln('Shared via CoverWise \u2014 Your Insurance Companion');
  return buffer.toString();
}

void _shareSummary(PolicySummary summary) {
  AnalyticsService.track('policy_detail_shared', {
    'policy_type': canonicalTypeName(classifyPolicyType(summary.documentType)),
  });
  SharePlus.instance.share(ShareParams(text: buildShareSummaryText(summary)));
}

class _ExecutiveSummaryCard extends StatelessWidget {
  final PolicySummary summary;
  const _ExecutiveSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bullets = summary.executiveSummary.take(3).toList();

    if (bullets.isEmpty) return const SizedBox.shrink();

    return CoverWiseSurface(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoverWiseIconBadge(
                  icon: Icons.summarize_rounded,
                  color: cs.primary,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'At a glance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...bullets.map((bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bullet,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Phase 0 P0-0.4 (trust audit, 2026-07-18): the unverified-summary
/// scaffold replaces the policy detail body when the summary is missing
/// critical fields. Per the trust audit's NO-GO verdict, the mobile app
/// must NOT display a summary that does not have evidence for the
/// fields it shows. The user is shown a clear "not yet verified" state
/// with the specific missing field, the source document, and a path
/// to ask questions directly against the source text.
Widget _buildUnverifiedSummaryScaffold({
  required BuildContext context,
  required String documentId,
  required PolicySummary summary,
  required String reason,
}) {
  // Theme-derived warning color.
  final warningColor = Theme.of(context).colorScheme.tertiary;
  return Scaffold(
    appBar: AppBar(title: const Text('Policy details')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (summary.executiveSummary.isNotEmpty) ...[
          _ExecutiveSummaryCard(summary: summary),
          const SizedBox(height: 24),
        ],
        CoverWiseIconBadge(
          icon: Icons.gpp_maybe_outlined,
          color: warningColor,
        ),
        const SizedBox(height: 16),
        Text(
          'Not yet verified',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          reason,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Text(
          'Why this happens',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Your policy document is on file, but the extracted summary is missing one or more '
          'critical fields (policy number, insurer, dates, or coverage). Showing those fields '
          'without evidence could mislead you, so CoverWise blocks the detailed summary view until the '
          'extraction is complete or the document is re-uploaded with clearer scans.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text('View source document'),
              onPressed: () => Navigator.pushNamed(context, '/policy-detail',
                  arguments: documentId),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Ask about this policy'),
              onPressed: () =>
                  Navigator.pushNamed(context, '/qa', arguments: documentId),
            ),
          ],
        ),
      ],
    ),
  );
}

// --- Trust Phase 1: cited fields from the evidence substrate ---

class _CitedFieldsSection extends StatefulWidget {
  final String documentId;
  final void Function(int pageNumber) onPageTap;

  const _CitedFieldsSection({
    required this.documentId,
    required this.onPageTap,
  });

  @override
  State<_CitedFieldsSection> createState() => _CitedFieldsSectionState();
}

class _CitedFieldsSectionState extends State<_CitedFieldsSection> {
  final EvidenceService _service = EvidenceService();
  late Future<List<FieldCitation>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getFieldCitations(widget.documentId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FieldCitation>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final citations = snapshot.data ?? const <FieldCitation>[];
        if (citations.isEmpty) {
          // The substrate has no verified data for this document.
          // The Phase 0 P0-0.4 scaffold (rendered at a higher
          // level) handles the user-visible case.
          return const SizedBox.shrink();
        }
        return FieldCitationsCard(
          citations: citations,
          onPageTap: widget.onPageTap,
        );
      },
    );
  }
}

/// Contextual CTAs shown below the quick actions on the policy detail screen.
///
/// Determines the most relevant topic based on the policy's state:
/// - Expiring soon → renewal reminders
/// - Active → general premium/tips
/// - Expired → renewal offers
class _PolicyCtas extends StatelessWidget {
  final PolicySummary summary;
  final String documentId;

  const _PolicyCtas({required this.summary, required this.documentId});

  @override
  Widget build(BuildContext context) {
    // Pick a topic based on policy state
    final topic = summary.isExpired || summary.isExpiringSoon
        ? CtaTopic.renewal
        : CtaTopic.premium;

    final ctas = LeadGenerationService.ctasForTopic(
      topic: topic,
      policy: summary,
      onUpgrade: () {
        Navigator.pushNamed(context, '/qa', arguments: documentId);
      },
    );

    if (ctas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'You might also be interested in:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ...ctas.map((cta) => CtaCard(cta: cta)),
        ],
      ),
    );
  }
}

/// A horizontal row of two action buttons: "Coverage gaps" and
/// "Claim assistance". Each button pushes the respective
/// screen with the citations fetched fresh on entry, so the
/// row's state is independent of the existing
/// _CitedFieldsSection state.
///
/// Per docs/decisions/ADR-2026-07-19-04-...md, the two screens
/// are the thin-slice implementation of the architecture
/// audit's ADR-09. The full coverage-gap + claim-assistance
/// features are deferred to a follow-up session that extends
/// the parser pipeline.
class _PolicyActionsRow extends StatelessWidget {
  final String documentId;

  const _PolicyActionsRow({required this.documentId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openCoverageGaps(context),
              icon: const Icon(Icons.help_outline),
              label: const Text('What your policy covers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openClaimAssistance(context),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('How to file a claim'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCoverageGaps(BuildContext context) async {
    AnalyticsService.track('policy_detail_coverage_gap_tapped', {
      'document_id_hash': documentId.length > 12
          ? documentId.substring(0, 12)
          : documentId,
    });
    final service = EvidenceService();
    final citations = await service.getFieldCitations(documentId);
    if (!context.mounted) return;
    final safe = citations ?? const <FieldCitation>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoverageGapScreen(
          documentId: documentId,
          citations: safe,
        ),
      ),
    );
  }

  Future<void> _openClaimAssistance(BuildContext context) async {
    AnalyticsService.track('policy_detail_claim_assist_tapped', {
      'document_id_hash': documentId.length > 12
          ? documentId.substring(0, 12)
          : documentId,
    });
    final service = EvidenceService();
    final citations = await service.getFieldCitations(documentId);
    if (!context.mounted) return;
    final safe = citations ?? const <FieldCitation>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClaimAssistanceScreen(
          documentId: documentId,
          citations: safe,
        ),
      ),
    );
  }
}
