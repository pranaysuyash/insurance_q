import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../services/app_state_repository.dart';
import '../widgets/shared/empty_state_widget.dart';

/// Generates a stable ID for a coverage gap based on its content.
String gapId(CoverageGap gap) {
  final raw = '${gap.category}|${gap.description}|${gap.severity}';
  // Simple hash for a stable short ID — not cryptographic.
  var hash = 0;
  for (var i = 0; i < raw.length; i++) {
    hash = ((hash << 5) - hash + raw.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return 'gap_${hash.toRadixString(16)}';
}

/// Filter mode for the gap list.
enum _GapFilter { all, unresolved, resolved }

class CoverageGapScreen extends ConsumerStatefulWidget {
  const CoverageGapScreen({super.key});

  @override
  ConsumerState<CoverageGapScreen> createState() => _CoverageGapScreenState();
}

class _CoverageGapScreenState extends ConsumerState<CoverageGapScreen> {
  _GapFilter _filter = _GapFilter.all;
  Map<String, Map<String, dynamic>> _resolvedGaps = {};

  @override
  void initState() {
    super.initState();
    _resolvedGaps = AppStateRepository.getResolvedGaps();
  }

  void _refreshResolved() {
    setState(() {
      _resolvedGaps = AppStateRepository.getResolvedGaps();
    });
  }

  bool _isResolved(CoverageGap gap) => _resolvedGaps.containsKey(gapId(gap));

  Future<void> _toggleResolved(CoverageGap gap, Color color) async {
    final id = gapId(gap);
    if (_isResolved(gap)) {
      await AppStateRepository.unresolveGap(id);
    } else {
      // Show notes dialog
      final notes = await _showNotesDialog(gap, color);
      if (notes == null) return; // user cancelled
      await AppStateRepository.markGapResolved(id, notes: notes.isEmpty ? null : notes);
    }
    _refreshResolved();
  }

  Future<String?> _showNotesDialog(CoverageGap gap, Color color) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Addressed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gap.description, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'How did you address this gap?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Mark Addressed'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    // Apply filter
    final filtered = gaps.where((g) {
      switch (_filter) {
        case _GapFilter.all:
          return true;
        case _GapFilter.unresolved:
          return !_isResolved(g);
        case _GapFilter.resolved:
          return _isResolved(g);
      }
    }).toList();

    final resolvedCount = gaps.where((g) => _isResolved(g)).length;
    final unresolvedCount = gaps.length - resolvedCount;

    final highGaps = filtered.where((g) => g.severity == 'high').toList();
    final mediumGaps = filtered.where((g) => g.severity == 'medium').toList();
    final lowGaps = filtered.where((g) => g.severity == 'low').toList();

    final hasAnyGaps = highGaps.isNotEmpty || mediumGaps.isNotEmpty || lowGaps.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Coverage Gaps')),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All (${gaps.length})',
                  selected: _filter == _GapFilter.all,
                  onTap: () => setState(() => _filter = _GapFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Open ($unresolvedCount)',
                  selected: _filter == _GapFilter.unresolved,
                  color: Colors.orange,
                  onTap: () => setState(() => _filter = _GapFilter.unresolved),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Addressed ($resolvedCount)',
                  selected: _filter == _GapFilter.resolved,
                  color: Colors.green,
                  onTap: () => setState(() => _filter = _GapFilter.resolved),
                ),
              ],
            ),
          ),
          // Gap list
          Expanded(
            child: hasAnyGaps
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (highGaps.isNotEmpty) ...[
                        _GapSection('High Priority', Icons.priority_high, Colors.red, highGaps, this),
                        const SizedBox(height: 20),
                      ],
                      if (mediumGaps.isNotEmpty) ...[
                        _GapSection('Medium Priority', Icons.warning_amber, Colors.orange, mediumGaps, this),
                        const SizedBox(height: 20),
                      ],
                      if (lowGaps.isNotEmpty) ...[
                        _GapSection('Low Priority', Icons.info_outline, Colors.blue, lowGaps, this),
                      ],
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filter == _GapFilter.resolved ? Icons.check_circle_outline : Icons.filter_list_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter == _GapFilter.resolved
                              ? 'No addressed gaps yet'
                              : _filter == _GapFilter.unresolved
                                  ? 'All gaps have been addressed! 🎉'
                                  : 'No coverage gaps detected',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? effectiveColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? effectiveColor : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? effectiveColor : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

class _GapSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<CoverageGap> gaps;
  final _CoverageGapScreenState state;
  const _GapSection(this.title, this.icon, this.color, this.gaps, this.state);

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
        ...gaps.map((gap) => _GapCard(gap: gap, color: color, state: state)),
      ],
    );
  }
}

class _GapCard extends StatelessWidget {
  final CoverageGap gap;
  final Color color;
  final _CoverageGapScreenState state;
  const _GapCard({required this.gap, required this.color, required this.state});

  @override
  Widget build(BuildContext context) {
    final resolved = state._isResolved(gap);
    final resolvedInfo = state._resolvedGaps[gapId(gap)];
    final notes = resolvedInfo?['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: resolved ? Colors.grey.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gap.category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: resolved ? TextDecoration.lineThrough : null,
                      color: resolved ? Colors.grey : null,
                    ),
                  ),
                ),
                if (resolved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Addressed', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              gap.description,
              style: TextStyle(
                color: resolved ? Colors.grey : Colors.black87,
                decoration: resolved ? TextDecoration.lineThrough : null,
              ),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(notes, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                  ],
                ),
              ),
            ],
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
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: resolved
                  ? TextButton.icon(
                      onPressed: () => state._toggleResolved(gap, color),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Reopen'),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () => state._toggleResolved(gap, color),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark Addressed'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}