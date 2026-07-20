import 'package:flutter/material.dart';
import 'coverwise_components.dart';

/// Shared section widget for legal content (Privacy Policy, Terms of Service).
///
/// Displays a titled section with content text inside a [CoverWiseSurface].
/// Used by both [PrivacyPolicyScreen] and [TermsOfServiceScreen] to avoid
/// duplicating identical section widgets.
class LegalContentSection extends StatelessWidget {
  final String title;
  final String content;

  const LegalContentSection({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CoverWiseSurface(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
