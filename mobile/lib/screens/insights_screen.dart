import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(policySummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: summaries.isEmpty
          ? EmptyStateWidget(
              icon: Icons.insights_outlined,
              title: 'Add policies to unlock insights',
              subtitle:
                  'Renewals, policy observations and comparisons appear here once you have policies.',
              actionLabel: 'Add policy',
              actionIcon: Icons.upload_file_rounded,
              onAction: () => Navigator.pushNamed(context, '/documents'),
              color: const Color(0xFF7C5CE7),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CoverWisePageHeader(
                          title: 'Review and understand your policies',
                          subtitle:
                              'Tools to review recorded dates, document observations and policy details.',
                        ),
                        const SizedBox(height: 16),
                        _InsightActionCard(
                          icon: Icons.event_available_outlined,
                          color: const Color(0xFF0B8F7D),
                          title: 'Renewal calendar',
                          subtitle: 'Track expiry dates and get reminders',
                          onTap: () =>
                              Navigator.pushNamed(context, '/renewals'),
                        ),
                        const SizedBox(height: 12),
                        _InsightActionCard(
                          icon: Icons.shield_outlined,
                          color: const Color(0xFF7C5CE7),
                          title: 'Coverage overview',
                          subtitle:
                              'Review what your uploaded policy does and does not verify',
                          onTap: () {
                            if (summaries.isNotEmpty) {
                              Navigator.pushNamed(
                                context,
                                '/coverage-gaps',
                                arguments: {'documentId': summaries.first.documentId},
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        if (summaries.length > 1) ...[
                          _InsightActionCard(
                            icon: Icons.compare_arrows_rounded,
                            color: const Color(0xFF2686A3),
                            title: 'Compare policies',
                            subtitle: 'See policy details side by side',
                            onTap: () =>
                                Navigator.pushNamed(context, '/compare'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _InsightActionCard(
                          icon: Icons.route_outlined,
                          color: const Color(0xFFE07A28),
                          title: 'Claims info guide',
                          subtitle:
                              'Understand the usual steps after an incident',
                          onTap: () => Navigator.pushNamed(context, '/claims'),
                        ),
                        const SizedBox(height: 12),
                        _InsightActionCard(
                          icon: Icons.menu_book_outlined,
                          color: const Color(0xFF079A86),
                          title: 'Insurance basics',
                          subtitle: 'Learn useful terms without the jargon',
                          onTap: () =>
                              Navigator.pushNamed(context, '/literacy'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InsightActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _InsightActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CoverWiseSurface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CoverWiseIconBadge(icon: icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
