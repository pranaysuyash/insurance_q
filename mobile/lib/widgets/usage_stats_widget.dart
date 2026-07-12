import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';

final usageStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(queryServiceProvider).getUsageStats();
});

class UsageStatsWidget extends ConsumerWidget {
  const UsageStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(usageStatsProvider);

    return statsAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Loading usage stats...'),
            ],
          ),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Unable to load usage stats', style: TextStyle(color: Colors.grey[600]))),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref.invalidate(usageStatsProvider),
                tooltip: 'Retry',
              ),
            ],
          ),
        ),
      ),
      data: (stats) => _UsageStatsContent(stats: stats, onRefresh: () => ref.invalidate(usageStatsProvider)),
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
    final effectiveRemaining = sessionRemaining < ipRemaining ? sessionRemaining : ipRemaining;

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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(getStatusIcon(), color: getStatusColor(), size: 20),
                const SizedBox(width: 8),
                Text('Upload Quota', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: onRefresh, tooltip: 'Refresh'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Remaining Today', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                      Text('$effectiveRemaining uploads',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: getStatusColor(), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Session Usage', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                      Text('$sessionUploads / $sessionLimit', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: sessionUploads / sessionLimit,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(getStatusColor()),
            ),
            if (effectiveRemaining <= 2) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: getStatusColor().withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(effectiveRemaining <= 0 ? Icons.info : Icons.warning, color: getStatusColor(), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        effectiveRemaining <= 0
                            ? 'Upload limit reached. Try again tomorrow.'
                            : 'You\'re approaching your daily upload limit.',
                        style: TextStyle(fontSize: 12, color: getStatusColor()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
