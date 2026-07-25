import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../providers/document_providers.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/error_widget.dart';
import '../screens/coverage_details_summary_screen.dart';
import '../screens/documents_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);
    final policySummaries = ref.watch(policySummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh policy overview',
            onPressed: () {
              ref.invalidate(documentsProvider);
              ref.invalidate(policySummariesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(documentsProvider);
          ref.invalidate(policySummariesProvider);
        },
        child: documentsAsync.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading policy overview',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => AppErrorView(
            message: 'We could not load your policy overview.',
            onRetry: () {
              ref.invalidate(documentsProvider);
              ref.invalidate(policySummariesProvider);
            },
          ),
          data: (documents) {
            if (documents.isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyDashboard(
                        onUpload: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentsScreen(
                              startWithFilePicker: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final primaryAction = _computePrimaryAction(policySummaries);
            final contextualActions = _computeContextualActions(policySummaries, documents);

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CoverWisePageHeader(
                          title: 'Your cover, at a glance',
                          subtitle: 'Next action, what needs attention, and quick tools.',
                        ),
                        const SizedBox(height: 16),
                        _PrimaryActionCard(action: primaryAction),
                        const SizedBox(height: 16),
                        if (contextualActions.isNotEmpty) ...[
                          _ContextualActionsRow(actions: contextualActions),
                          const SizedBox(height: 16),
                        ],
                        _QuickToolsRow(
                          documents: documents,
                          policySummaries: policySummaries,
                        ),
                        const SizedBox(height: 24),
                        _PolicyStatusSummary(summaries: policySummaries),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Computes the single most important next action for the user.
_PrimaryAction _computePrimaryAction(List<PolicySummary> summaries) {
  if (summaries.isEmpty) {
    return const _PrimaryAction.review(
      title: 'Review your policy files',
      subtitle: 'Your uploaded documents are ready to review',
      icon: Icons.description_outlined,
      color: Color(0xFF079A86),
    );
  }

  // Priority 1: Expired policies — immediate action
  final expired = summaries.where((s) => s.isExpired).toList();
  if (expired.isNotEmpty) {
    return _PrimaryAction.renewal(
      title: expired.length == 1 ? 'Renew expired policy' : 'Renew ${expired.length} expired policies',
      subtitle: 'Expired ${expired.first.daysUntilExpiry.abs()} days ago',
      icon: Icons.error_rounded,
      color: const Color(0xFFE53935),
    );
  }

  // Priority 2: Expiring soon (within 30 days)
  final expiringSoon = summaries.where((s) => s.isExpiringSoon).toList();
  if (expiringSoon.isNotEmpty) {
    final nearest = expiringSoon.reduce((a, b) => a.daysUntilExpiry < b.daysUntilExpiry ? a : b);
    return _PrimaryAction.renewal(
      title: expiringSoon.length == 1 ? 'Renew expiring policy' : 'Renew ${expiringSoon.length} expiring policies',
      subtitle: 'Expires in ${nearest.daysUntilExpiry} days',
      icon: Icons.schedule_rounded,
      color: const Color(0xFFEF8C1A),
    );
  }

  // Priority 3: no urgent renewal. Keep the action at the document-review
  // boundary; coverage conclusions require cited policy evidence.
  return _PrimaryAction.review(
    title: 'Review your coverage',
    subtitle: '${summaries.length} polic${summaries.length == 1 ? 'y' : 'ies'} ready to review',
    icon: Icons.shield_outlined,
    color: const Color(0xFF079A86),
  );
}

/// Computes up to 3 contextual actions based on user state.
List<_ContextualAction> _computeContextualActions(
    List<PolicySummary> summaries,
    List<dynamic> documents) {
  final actions = <_ContextualAction>[];

  // Action 1: cited coverage details (if any policies exist).
  if (summaries.isNotEmpty) {
    actions.add(_ContextualAction(
      title: 'Coverage details',
      subtitle: 'Review cited policy fields',
      icon: Icons.shield_outlined,
      color: const Color(0xFF7C5CE7),
      route: '/coverage-gaps',
      args: {'documentId': summaries.first.documentId},
    ));
  }

  // Action 2: Renewal calendar (if any policies exist)
  if (summaries.isNotEmpty) {
    actions.add(_ContextualAction(
      title: 'Renewal calendar',
      subtitle: 'Track all expiry dates',
      icon: Icons.event_available_outlined,
      color: const Color(0xFF0B8F7D),
      route: '/renewals',
    ));
  }

  // Action 3: Compare policies (if 2+ policies)
  if (summaries.length >= 2) {
    actions.add(_ContextualAction(
      title: 'Compare policies',
      subtitle: 'Side-by-side view',
      icon: Icons.compare_arrows_rounded,
      color: const Color(0xFF2686A3),
      route: '/compare',
    ));
  }

  // Action 4: What-if calculator (if policies exist)
  if (summaries.isNotEmpty && actions.length < 3) {
    actions.add(_ContextualAction(
      title: 'What-if calculator',
      subtitle: 'Explore cover changes',
      icon: Icons.tune_rounded,
      color: const Color(0xFFB66A16),
      route: '/what-if',
    ));
  }

  // Action 5: Ask a question (always available)
  if (actions.length < 3) {
    actions.add(_ContextualAction(
      title: 'Ask a question',
      subtitle: 'Get answers from your policy',
      icon: Icons.chat_bubble_outline_rounded,
      color: const Color(0xFF7C5CE7),
      route: '/qa',
    ));
  }

  return actions.take(3).toList();
}

/// Primary action card — the single most important thing.
class _PrimaryActionCard extends StatelessWidget {
  final _PrimaryAction action;

  const _PrimaryActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon, color: action.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        action.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pushNamed(context, action.route);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: action.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(action.ctaLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAction {
  final _PrimaryActionType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String ctaLabel;
  final String route;

  const _PrimaryAction.renewal({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  }) : route = '/renewals',
       type = _PrimaryActionType.renewal,
       ctaLabel = 'View renewals';

  const _PrimaryAction.review({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  }) : route = '/documents',
       type = _PrimaryActionType.review,
       ctaLabel = 'View policies';
}

enum _PrimaryActionType { renewal, review }

/// Contextual actions row — up to 3 personalized actions.
class _ContextualActionsRow extends StatelessWidget {
  final List<_ContextualAction> actions;

  const _ContextualActionsRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What you can do next',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: actions.map((action) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: action != actions.last ? 8 : 0),
                  child: _ContextualActionButton(action: action),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextualAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final dynamic args;

  const _ContextualAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.args,
  });
}

class _ContextualActionButton extends StatelessWidget {
  final _ContextualAction action;

  const _ContextualActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, action.route, arguments: action.args),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: action.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: action.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              action.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              action.subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick tools row — cross-cutting actions always available.
class _QuickToolsRow extends StatelessWidget {
  final List<dynamic> documents;
  final List<PolicySummary> policySummaries;

  const _QuickToolsRow({
    required this.documents,
    required this.policySummaries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick tools',
              style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            // Row 1: Coverage Summary + Search
            Row(
              children: [
                Expanded(
                  child: _QuickToolButton(
                    icon: Icons.fact_check_rounded,
                    label: 'Coverage summary',
                    color: const Color(0xFF7C5CE7),
                    onTap: () {
                      if (policySummaries.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CoverageDetailsSummaryScreen(
                              summary: policySummaries.first,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickToolButton(
                    icon: Icons.search_rounded,
                    label: 'Search policies',
                    color: cs.primary,
                    onTap: () => Navigator.pushNamed(context, '/search'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Ask a question + Add policy
            Row(
              children: [
                Expanded(
                  child: _QuickToolButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Ask a question',
                    color: const Color(0xFF079A86),
                    onTap: () => Navigator.pushNamed(context, '/qa'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickToolButton(
                    icon: Icons.upload_file_rounded,
                    label: 'Add policy',
                    color: const Color(0xFFEF8C1A),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DocumentsScreen(startWithFilePicker: true),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Policy status summary — compact overview replacing WelcomeCard + PolicySummaryCards + DocumentSummary
class _PolicyStatusSummary extends StatelessWidget {
  final List<PolicySummary> summaries;

  const _PolicyStatusSummary({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final activeCount = summaries.where((s) => s.isActive).length;
    final expiringCount = summaries.where((s) => s.isExpiringSoon).length;
    final expiredCount = summaries.where((s) => s.isExpired).length;
    final totalCount = summaries.length;

    return CoverWiseSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Policy status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _StatusTile(label: 'Total', value: totalCount.toString(), icon: Icons.description_outlined, color: cs.primary)),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                Expanded(child: _StatusTile(label: 'Active', value: activeCount.toString(), icon: Icons.check_circle_rounded, color: const Color(0xFF2E7D32))),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                Expanded(child: _StatusTile(label: 'Expiring', value: expiringCount.toString(), icon: Icons.schedule_rounded, color: const Color(0xFFEF8C1A))),
                Container(width: 1, height: 40, color: cs.outlineVariant),
                Expanded(child: _StatusTile(label: 'Expired', value: expiredCount.toString(), icon: Icons.error_rounded, color: const Color(0xFFE53935))),
              ],
            ),
            if (summaries.isNotEmpty) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pushNamed(context, '/documents'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('View all policies'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatusTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Empty state for when no documents exist.
class _EmptyDashboard extends StatelessWidget {
  final VoidCallback onUpload;

  const _EmptyDashboard({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.description_outlined, size: 48, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No policies yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first policy to see renewals, coverage details, and quick tools.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Add policy'),
              onPressed: onUpload,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
