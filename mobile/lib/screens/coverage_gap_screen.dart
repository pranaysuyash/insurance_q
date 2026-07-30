import 'package:flutter/material.dart';

import '../models/field_citation.dart';
import '../widgets/not_yet_extracted_section.dart';

/// The coverage review (Trust audit ADR-09 thin slice).
///
/// Per docs/decisions/ADR-2026-07-19-04-...md, the thin slice
/// shows the substrate's existing `room_rent_cap` field (the
/// commonly reviewed policy detail) and the `insurer_name` (for
/// context). Other coverage questions (maternity, dental, OPD,
/// pre-existing disease waiting period) are NOT in the
/// substrate yet; the `NotYetExtractedSection` makes the
/// limits visible at the UI layer.
///
/// This screen is reached from a button in the policy detail
/// screen's action area. It is a read-only consumer of the
/// substrate; it does not call extractors, does not write
/// to the substrate, and does not invent citation text.
class CoverageGapScreen extends StatelessWidget {
  final String documentId;
  final List<FieldCitation> citations;

  const CoverageGapScreen({
    super.key,
    required this.documentId,
    this.citations = const [],
  });

  /// The list of fields the substrate does NOT yet extract.
  /// Per ADR-2026-07-19-04, the deferred work is:
  /// - maternity_covered
  /// - dental_covered
  /// - opd_covered
  /// - pre_existing_disease_waiting_period
  /// - mental_health_covered
  /// - cosmetic_covered
  static const List<String> _deferredFields = [
    'Maternity coverage',
    'Dental coverage',
    'Outpatient (OPD) coverage',
    'Pre-existing disease waiting period',
    'Mental health coverage',
    'Cosmetic procedure coverage',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final roomRent = _findCitation(citations, 'room_rent_cap');
    final insurer = _findCitation(citations, 'insurer_name');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coverage review'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'What your policy text shows',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Each item below shows its evidence tier — how reliable the information is. '
              '"Cross-checked" items are extracted and cross-checked against your policy text '
              '(Tier 2). "Lower confidence" items are extracted but need manual '
              'verification (Tier 1). "Pending extraction" items are not yet in the '
              'system (Tier 0). Missing items do not mean your policy lacks that coverage.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (roomRent != null)
            _CoverageGapRow(
              label: 'Room rent cap',
              displayValue: roomRent.value.display,
              citeString: roomRent.citeString,
              pageNumber: roomRent.pageNumber,
              fieldConfidence: roomRent.fieldConfidence,
            ),
          if (insurer != null)
            _CoverageGapRow(
              label: 'Insurer',
              displayValue: insurer.value.display,
              citeString: insurer.citeString,
              pageNumber: insurer.pageNumber,
              fieldConfidence: insurer.fieldConfidence,
            ),
          if (roomRent == null && insurer == null)
            // Neither of the two fields the thin slice relies
            // on is in the substrate yet. This is the expected
            // state for documents uploaded before the substrate
            // pipeline ran, or for documents the pipeline
            // could not extract from. The screen is honest.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Text(
                "We don't have this information for your policy yet. "
                'For now, check your policy document or contact your insurer.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          NotYetExtractedSection(fieldNames: _deferredFields),
        ],
      ),
    );
  }

  static FieldCitation? _findCitation(
    List<FieldCitation> citations,
    String fieldName,
  ) {
    for (final c in citations) {
      if (c.fieldName == fieldName) return c;
    }
    return null;
  }
}

class _CoverageGapRow extends StatelessWidget {
  final String label;
  final String displayValue;
  final String citeString;
  final int pageNumber;
  final double fieldConfidence;

  const _CoverageGapRow({
    required this.label,
    required this.displayValue,
    required this.citeString,
    required this.pageNumber,
    required this.fieldConfidence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lowConfidence = fieldConfidence < 0.7;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Evidence-tier badge + label
            Row(
              children: [
                _EvidenceTierBadge(
                  tier: lowConfidence ? 'Lower confidence' : 'Cross-checked',
                  color: lowConfidence
                      ? colorScheme.tertiary
                      : const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              displayValue,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (lowConfidence) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'This field was extracted but could not be fully verified '
                      'against your policy text. Please verify against the source document.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 14,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    citeString,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
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
}

/// Evidence-tier badge showing the reliability level of an extracted field.
class _EvidenceTierBadge extends StatelessWidget {
  final String tier;
  final Color color;

  const _EvidenceTierBadge({
    required this.tier,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            tier,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
