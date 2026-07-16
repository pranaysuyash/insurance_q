import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../theme/coverwise_theme.dart';
import 'shared/coverwise_components.dart';

final usageStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(queryServiceProvider).getUsageStats();
});

class UsageStatsWidget extends ConsumerWidget {
  const UsageStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(usageStatsProvider);

    return statsAsync.when(
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CoverWiseIconBadge(
                icon: Icons.cloud_upload_outlined,
                color: CoverWiseColors.blueDeep,
                size: 40,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Checking upload allowance…')),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CoverWiseIconBadge(
                icon: Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Upload allowance unavailable',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: () => ref.invalidate(usageStatsProvider),
                tooltip: 'Retry',
              ),
            ],
          ),
        ),
      ),
      data: (stats) => _UsageStatsContent(
        stats: stats,
        onRefresh: () => ref.invalidate(usageStatsProvider),
      ),
    );
  }
}

class _UsageStatsContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  final VoidCallback onRefresh;

  const _UsageStatsContent({required this.stats, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final sessionUploads = stats['session_uploads'] ?? 0;
    final sessionLimit = stats['session_limit'] ?? 5;
    final ipUploads = stats['ip_uploads'] ?? 0;
    final ipLimit = stats['ip_limit'] ?? 10;

    final sessionRemaining = sessionLimit - sessionUploads;
    final ipRemaining = ipLimit - ipUploads;
    final effectiveRemaining =
        sessionRemaining < ipRemaining ? sessionRemaining : ipRemaining;
    final displayRemaining = effectiveRemaining < 0 ? 0 : effectiveRemaining;
    final progress = sessionLimit > 0
        ? (sessionUploads / sessionLimit).clamp(0.0, 1.0).toDouble()
        : 1.0;

    Color getStatusColor() {
      if (effectiveRemaining <= 0) return Colors.red;
      if (effectiveRemaining <= 2) return Colors.orange;
      return Colors.green;
    }

    IconData getStatusIcon() {
      if (effectiveRemaining <= 0) return Icons.block;
      if (effectiveRemaining <= 2) return Icons.warning;
      return Icons.check_circle;
    }

    return Card(
      child: Semantics(
        container: true,
        label:
            'Upload allowance. $displayRemaining uploads remaining today. $sessionUploads of $sessionLimit used this session.',
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CoverWiseIconBadge(
                    icon: getStatusIcon(),
                    color: getStatusColor(),
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload allowance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: onRefresh,
                    tooltip: 'Refresh upload allowance',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 28,
                runSpacing: 12,
                children: [
                  _UsageMetric(
                    label: 'Remaining today',
                    value: '$displayRemaining uploads',
                    valueColor: getStatusColor(),
                  ),
                  _UsageMetric(
                    label: 'Used this session',
                    value: '$sessionUploads of $sessionLimit',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(getStatusColor()),
              ),
              if (effectiveRemaining <= 2) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getStatusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: getStatusColor().withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        effectiveRemaining <= 0
                            ? Icons.info_outline_rounded
                            : Icons.warning_amber_rounded,
                        color: getStatusColor(),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          effectiveRemaining <= 0
                              ? 'Upload limit reached. Try again tomorrow.'
                              : 'You\'re approaching your daily upload limit.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: getStatusColor(),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _UsageMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
