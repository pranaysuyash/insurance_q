import 'package:flutter/material.dart';
import '../shared/coverwise_components.dart';

class WelcomeCard extends StatelessWidget {
  final int docCount;
  final int activePolicies;
  final int expiringCount;
  final VoidCallback? onTap;

  const WelcomeCard({
    super.key,
    required this.docCount,
    this.activePolicies = 0,
    this.expiringCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'View all documents',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CoverWiseSurface(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your policy hub',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$docCount document${docCount == 1 ? "" : "s"} • $activePolicies active ${activePolicies == 1 ? "policy" : "policies"}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (expiringCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined,
                          color: theme.colorScheme.tertiary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$expiringCount ${expiringCount == 1 ? "policy" : "policies"} expiring soon',
                        style: TextStyle(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                if (docCount == 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Add a policy PDF to see coverage, exclusions and renewal dates in one place.',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
