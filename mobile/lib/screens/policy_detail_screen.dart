import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/field_citation.dart';
import '../models/policy_summary.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
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
import 'claim_assistance_screen.dart';
import 'coverage_gap_screen.dart';
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
    final summary = summaries
        .where((s) => s.documentId == backendDocumentId)
        .firstOrNull;

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
        reason: summary.missingEvidenceReason ??
            'This summary is missing critical fields and cannot be safely displayed yet.',
      );
    }

    final policyType = classifyPolicyType(summary.documentType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Policy details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'View source document',
            onPressed: () => _openDocumentPreview(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Ask a Question',
            onPressed: () =>
                Navigator.pushNamed(context, '/qa', arguments: backendDocumentId),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share Policy Summary',
            onPressed: () => _shareSummary(summary),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          CoverWisePageHeader(
            title: canonicalTypeName(policyType),
            subtitle: summary.insurer == null
                ? 'Your policy, translated into the details that matter.'
                : '${summary.insurer} • Your policy at a glance',
          ),
          if (_overrides.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
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

  void _openDocumentPreview(BuildContext context, WidgetRef ref, {int initialPage = 1}) {
    final documents = ref.read(documentsProvider).asData?.value;
    if (documents == null || documents.isEmpty) {
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
      if (!context.mounted) return;
      CoverWiseSnackBar.error(
        context,
        'Document not found on this device. Try refreshing or re-uploading.',
      );
      return;
    }

    if (doc.localFilePath == null || doc.localFilePath!.isEmpty) {
      if (!context.mounted) return;
      CoverWiseSnackBar.info(
        context,
        'Source document is only available on the device where it was uploaded.',
      );
      return;
    }

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
                          value: overrides['insurer']?.value ?? summary.insurer!,
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
                  value: overrides['policy_number']?.value ?? summary.policyNumber!,
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
    final coverageDisplay = resolveFieldOverride(overrides, 'coverage_amount', summary.formattedCoverageAmount);
    final premiumDisplay = resolveFieldOverride(overrides, 'premium_amount', summary.formattedPremium);
    
    final items = <_MoneyItem>[
      if (summary.coverageAmount != null || overrides.containsKey('coverage_amount'))
        _MoneyItem(
          label: 'Sum Insured',
          labelTooltip: 'The maximum amount your insurer will pay for a covered claim',
          value: coverageDisplay,
          icon: Icons.shield,
          color: scheme.primary,
          field: 'coverage_amount',
          originalValue: summary.formattedCoverageAmount,
          hasOverride: overrides.containsKey('coverage_amount'),
          onEditField: onEditField,
          onRevertField: onRevertField,
        ),
      if (summary.premiumAmount != null || overrides.containsKey('premium_amount'))
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
                                      onSave: (v) => item.onEditField!(item.field!, v),
                                      onRevert: item.hasOverride && item.onRevertField != null
                                          ? () => item.onRevertField!(item.field!)
                                          : null,
                                      hintText: 'Enter ${item.label.toLowerCase()}',
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        item.value,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w800),
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
    final startDisplay = resolveFieldOverride(overrides, 'start_date', summary.formattedStartDate);
    final endDisplay = resolveFieldOverride(overrides, 'end_date', summary.formattedExpiryDate);

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
  buffer.writeln('Shared via CoverWise — Your Insurance Companion');
  return buffer.toString();
}

void _shareSummary(PolicySummary summary) {
  SharePlus.instance.share(ShareParams(text: buildShareSummaryText(summary)));
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
  required String reason,
}) {
  // Theme-derived warning color. The previous build used
  // CoverWiseIconBadge with a `tone` parameter that doesn't exist on
  // the current widget (it takes `icon` + `color`). Using a
  // theme-derived warning color keeps this consistent with the
  // existing policy detail screen and works in dark mode.
  final warningColor = Theme.of(context).colorScheme.tertiary;
  return Scaffold(
    appBar: AppBar(title: const Text('Policy details')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
          'without evidence could mislead you, so CoverWise blocks the summary view until the '
          'extraction is complete or the document is re-uploaded with clearer scans.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text('View source document'),
              onPressed: () =>
                  Navigator.pushNamed(context, '/policy-detail', arguments: documentId),
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
