import 'package:flutter/material.dart';

/// The honest "not yet extracted" section.
///
/// The trust audit's NO-GO is about claim-shaped UI that the
/// system cannot verify. The fix is to refuse to show what the
/// system does not know, not to add a disclaimer.
///
/// This widget renders the list of substrate fields the
/// pipeline does NOT yet extract, with the specific reason
/// (deferred to a follow-up session). It is the same pattern
/// as the Phase 0 P0-0.4 "Not yet verified" scaffold, applied
/// to a new surface (coverage gaps and claim inputs the
/// substrate does not currently cover).
///
/// Per motto v3 §0.7 (AI output boundary) and §0.4 (acceptance
/// contract), the widget's job is to make the substrate's
/// limits visible at the UI layer. The user knows what the
/// system does not know; the operator knows what to ship next.
class NotYetExtractedSection extends StatelessWidget {
  /// Human-readable list of fields the substrate does not
  /// currently extract. Each entry is a one-line reason.
  final List<String> fieldNames;

  /// The title of the section. Defaults to
  /// "Not yet extracted from your policy".
  final String title;

  /// A short subtitle / explanation. Defaults to
  /// "These items are not in the system yet. They will be
  /// added in a future update; for now, check your policy
  /// document or contact your insurer."
  final String subtitle;

  const NotYetExtractedSection({
    super.key,
    required this.fieldNames,
    this.title = 'Not yet extracted from your policy',
    this.subtitle =
        'These items are not in the system yet. They will be '
        'added in a future update; for now, check your policy '
        'document or contact your insurer.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (fieldNames.isEmpty) {
      // No gaps. The substrate covers everything the user
      // asked about. The widget renders nothing.
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final field in fieldNames)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle_outlined,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        field,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
