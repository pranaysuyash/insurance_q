import 'package:flutter/material.dart';

import '../models/field_citation.dart';

/// Renders the cited fields from the evidence substrate.
///
/// Shown on the policy detail screen ONLY when the substrate has
/// at least one cited field. The Phase 0 P0-0.4 "Not yet verified"
/// scaffold stays in place for documents that lack substrate data.
///
/// The card is a list of rows, one per field, each showing the
/// human label, the display value, and a tap target that opens
/// the source page. The page-number tap target is the citation
/// contract: the user can verify every field by going to the
/// cited page.
///
/// No hardcoded colors (per Trust audit P0-2.7 and Phase 0
/// policy detail fix): every color comes from
/// `Theme.of(context).colorScheme.*`.
class FieldCitationsCard extends StatelessWidget {
  final List<FieldCitation> citations;
  final void Function(int pageNumber)? onPageTap;

  const FieldCitationsCard({
    super.key,
    required this.citations,
    this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) {
      // Honest empty state: the substrate has no verified fields
      // for this document. The Phase 0 scaffold (separate widget)
      // handles the "summary is partial" case at a higher level.
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Verified from your policy',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'Each item below is taken from a specific page of the source document. Tap to open the source document.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final citation in citations)
              _FieldCitationRow(
                citation: citation,
                onPageTap: onPageTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldCitationRow extends StatelessWidget {
  final FieldCitation citation;
  final void Function(int pageNumber)? onPageTap;

  const _FieldCitationRow({
    required this.citation,
    this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lowConfidence = citation.fieldConfidence < 0.7;

    return InkWell(
      onTap: onPageTap == null
          ? null
          : () => onPageTap!(citation.pageNumber),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    citation.displayLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    citation.value.display,
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
                        Text(
                          'Less reliable — verify against your policy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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
                    citation.citeString,
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
