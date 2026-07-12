import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/empty_state_widget.dart';

class CoverageGapScreen extends ConsumerWidget {
  const CoverageGapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaps = ref.watch(coverageGapsProvider);

    if (gaps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coverage Gaps')),
        body: const EmptyStateWidget(
          icon: Icons.shield,
          title: 'No coverage gaps detected',
          subtitle: 'Upload more documents for a complete analysis',
        ),
      );
    }

    final highGaps = gaps.where((g) => g.severity == 'high').toList();
    final mediumGaps = gaps.where((g) => g.severity == 'medium').toList();
    final lowGaps = gaps.where((g) => g.severity == 'low').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Coverage Gaps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (highGaps.isNotEmpty) ...[
            _GapSection('High Priority', Icons.priority_high, Colors.red, highGaps),
            const SizedBox(height: 20),
          ],
          if (mediumGaps.isNotEmpty) ...[
            _GapSection('Medium Priority', Icons.warning_amber, Colors.orange, mediumGaps),
            const SizedBox(height: 20),
          ],
          if (lowGaps.isNotEmpty) ...[
            _GapSection('Low Priority', Icons.info_outline, Colors.blue, lowGaps),
          ],
        ],
      ),
    );
  }
}

class _GapSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<CoverageGap> gaps;
  const _GapSection(this.title, this.icon, this.color, this.gaps);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${gaps.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...gaps.map((gap) => _GapCard(gap: gap, color: color)),
      ],
    );
  }
}

class _GapCard extends StatelessWidget {
  final CoverageGap gap;
  final Color color;
  const _GapCard({required this.gap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gap.category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(gap.description, style: const TextStyle(color: Colors.black87)),
            if (gap.recommendation != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(gap.recommendation!, style: const TextStyle(fontSize: 13))),
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