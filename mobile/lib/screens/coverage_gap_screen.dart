import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../services/app_state_repository.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../theme/coverwise_motion.dart';
import '../widgets/shared/coverwise_components.dart';

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

  bool _isResolved(CoverageGap gap) => _resolvedGaps.containsKey(gap.gapId);

  Future<void> _toggleResolved(CoverageGap gap, Color color) async {
    final id = gap.gapId;
    if (_isResolved(gap)) {
      await AppStateRepository.unresolveGap(id);
    } else {
      // Show notes dialog
      final notes = await _showNotesDialog(gap, color);
      if (notes == null) return; // user cancelled
      await AppStateRepository.markGapResolved(id,
          notes: notes.isEmpty ? null : notes);
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
            Text(
              gap.description,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
          icon: Icons.verified_user_outlined,
          title: 'No coverage gaps detected',
          subtitle:
              'Add more policy documents to make this review more complete.',
          color: Color(0xFF16866B),
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

    final hasAnyGaps =
        highGaps.isNotEmpty || mediumGaps.isNotEmpty || lowGaps.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Coverage Gaps')),
      body: Column(
        children: [
          const CoverWisePageHeader(
            title: 'Review potential gaps',
            subtitle:
                'Track areas that may need a closer look. Addressed items stay available for reference.',
          ),
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
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
              ]),
            ),
          ),
          Semantics(
            liveRegion: true,
            label:
                '${filtered.length} ${filtered.length == 1 ? 'coverage item' : 'coverage items'} shown',
            child: const SizedBox.shrink(),
          ),
          // Gap list
          Expanded(
            child: CoverWiseStateTransition(
              child: hasAnyGaps
                  ? ListView(
                      key: ValueKey(
                          'gap-list-${_filter.name}-${filtered.length}'),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (highGaps.isNotEmpty) ...[
                          _GapSection(
                              'High Priority',
                              Icons.priority_high_rounded,
                              Theme.of(context).colorScheme.error,
                              highGaps,
                              this),
                          const SizedBox(height: 20),
                        ],
                        if (mediumGaps.isNotEmpty) ...[
                          _GapSection(
                              'Medium Priority',
                              Icons.warning_amber_rounded,
                              Theme.of(context).colorScheme.tertiary,
                              mediumGaps,
                              this),
                          const SizedBox(height: 20),
                        ],
                        if (lowGaps.isNotEmpty) ...[
                          _GapSection(
                              'Low Priority',
                              Icons.info_outline_rounded,
                              Theme.of(context).colorScheme.primary,
                              lowGaps,
                              this),
                        ],
                      ],
                    )
                  : EmptyStateWidget(
                      key: ValueKey('gap-empty-${_filter.name}'),
                      icon: _filter == _GapFilter.resolved
                          ? Icons.task_alt_rounded
                          : Icons.filter_list_off_rounded,
                      title: _filter == _GapFilter.resolved
                          ? 'No addressed gaps yet'
                          : _filter == _GapFilter.unresolved
                              ? 'All gaps are addressed'
                              : 'No coverage gaps detected',
                      subtitle: _filter == _GapFilter.unresolved
                          ? 'You can review addressed items from the filter above.'
                          : null,
                      color: _filter == _GapFilter.resolved
                          ? const Color(0xFF16866B)
                          : const Color(0xFF6A4BA8),
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
  const _FilterChip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: effectiveColor.withValues(alpha: 0.15),
        side: BorderSide(
          color: selected
              ? effectiveColor
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? effectiveColor
              : Theme.of(context).colorScheme.onSurfaceVariant,
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
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            CoverWiseStatusChip(
              icon: icon,
              label: '${gaps.length}',
              color: color,
              compact: true,
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
    final resolvedInfo = state._resolvedGaps[gap.gapId];
    final notes = resolvedInfo?['notes'] as String?;

    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: resolved ? scheme.surfaceContainerLow : null,
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
                      color: resolved ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
                if (resolved)
                  const CoverWiseStatusChip(
                    icon: Icons.check_circle_rounded,
                    label: 'Addressed',
                    color: Color(0xFF16866B),
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              gap.description,
              style: TextStyle(
                color: resolved ? scheme.onSurfaceVariant : scheme.onSurface,
                decoration: resolved ? TextDecoration.lineThrough : null,
              ),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              CoverWiseInfoPanel(
                icon: Icons.note_outlined,
                title: 'Your note',
                body: notes,
                color: const Color(0xFF16866B),
              ),
            ],
            if (gap.recommendation != null) ...[
              const SizedBox(height: 10),
              CoverWiseInfoPanel(
                icon: Icons.lightbulb_outline_rounded,
                title: 'What to review',
                body: gap.recommendation!,
                color: color,
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
