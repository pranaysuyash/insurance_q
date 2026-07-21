import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/shared/coverwise_components.dart';
import '../utils/document_icons.dart';
import 'documents_screen.dart';

class PolicyComparisonScreen extends ConsumerStatefulWidget {
  const PolicyComparisonScreen({super.key});

  @override
  ConsumerState<PolicyComparisonScreen> createState() =>
      _PolicyComparisonScreenState();
}

class _PolicyComparisonScreenState
    extends ConsumerState<PolicyComparisonScreen> {
  /// Selected policy documentIds (target 2-3). Pre-selects the first two so the
  /// existing default behavior is preserved.
  final Set<String> _selected = {};
  List<PolicySummary>? _summariesCache;

  /// Whether the comparison table is currently shown. Resets when the
  /// selection count drops below the minimum (2) so stale tables never linger.
  bool _showComparison = false;

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(policySummariesProvider);

    if (summaries.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compare Policies')),
        body: EmptyStateWidget(
          icon: Icons.balance_outlined,
          title: 'Need at least 2 policies',
          subtitle: summaries.isEmpty
              ? 'Choose your first policy file to start comparing.'
              : 'Choose another policy file to compare.',
          actionLabel: 'Choose policy file',
          actionIcon: Icons.upload_file_rounded,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DocumentsScreen(startWithFilePicker: true),
            ),
          ),
          color: const Color(0xFF6A4BA8),
        ),
      );
    }

    // Initialize the default selection once (first two policies) so the first
    // view matches the old behavior of taking the first two.
    if (_summariesCache == null) {
      _summariesCache = summaries;
      _selected.addAll(summaries.take(2).map((s) => s.documentId));
    } else if (!_listEquals(_summariesCache!, summaries)) {
      // Source list changed (e.g. document added/removed). Refresh the cache
      // and prune any selection that no longer exists.
      _summariesCache = summaries;
      _selected
        ..removeWhere((id) => !summaries.any((s) => s.documentId == id))
        ..addAll(summaries
            .take(2)
            .map((s) => s.documentId)
            .where((id) => _selected.length < 2));
    }

    final selectedPolicies =
        summaries.where((s) => _selected.contains(s.documentId)).toList();

    final canCompare = _selected.length >= 2;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Policies')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const CoverWisePageHeader(
            title: 'Compare your cover',
            subtitle:
                'Select two or three policies to review their recorded details side by side.',
          ),
          const CoverWiseSectionLabel('Select policies'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Pick 2 or 3 policies.'),
          ),
          const SizedBox(height: 12),
          CoverWiseSurface(
            child: Column(
              children: summaries
                  .map((s) => _PolicySelectionTile(
                        summary: s,
                        selected: _selected.contains(s.documentId),
                        // Lock once the user has picked 3, unless they're deselecting.
                        enabled: _selected.length < 3 ||
                            _selected.contains(s.documentId),
                        onChanged: (checked) => setState(() {
                          final add = checked ?? false;
                          if (add) {
                            if (_selected.length < 3) {
                              _selected.add(s.documentId);
                            }
                          } else {
                            _selected.remove(s.documentId);
                          }
                          // Hide the comparison if the selection drops below the minimum.
                          if (_selected.length < 2) _showComparison = false;
                        }),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              icon: Icon(_showComparison
                  ? Icons.visibility_off_outlined
                  : Icons.balance_outlined),
              label: Text(canCompare
                  ? (_showComparison
                      ? 'Hide comparison'
                      : 'Compare ${_selected.length} policies')
                  : 'Select at least 2 policies'),
              onPressed: canCompare
                  ? () => setState(() => _showComparison = !_showComparison)
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (canCompare && _showComparison) ...[
            const CoverWiseSectionLabel('Recorded details'),
            const SizedBox(height: 8),
            // Horizontal scroll so 3 policy columns still fit on narrow phones.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _ComparisonTable(policies: selectedPolicies),
            ),
          ],
        ],
      ),
    );
  }

  bool _listEquals(List<PolicySummary> a, List<PolicySummary> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].documentId != b[i].documentId) return false;
    }
    return true;
  }
}

class _PolicySelectionTile extends StatelessWidget {
  final PolicySummary summary;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool?> onChanged;
  const _PolicySelectionTile({
    required this.summary,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorForDocumentType(summary.documentType);
    return CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      secondary: CoverWiseIconBadge(
        icon: iconForDocumentType(summary.documentType),
        color: color,
        size: 42,
      ),
      value: selected,
      onChanged: enabled ? onChanged : null,
      title: Text(summary.documentType,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${summary.insurer ?? "Unknown"}'
          '${summary.policyNumber != null ? " • ${summary.policyNumber}" : ""}'),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<PolicySummary> policies;
  const _ComparisonTable({required this.policies});

  @override
  Widget build(BuildContext context) {
    final rows = <_ComparisonRow>[
      _ComparisonRow('Type', (s) => s.documentType),
      _ComparisonRow('Insurer', (s) => s.insurer ?? 'Unknown'),
      _ComparisonRow('Policy Number', (s) => s.policyNumber ?? 'Unknown'),
      _ComparisonRow('Coverage', (s) => s.formattedCoverageAmount),
      _ComparisonRow('Premium', (s) => s.formattedPremium),
      _ComparisonRow('Deductible',
          (s) => s.deductible != null ? '₹${s.deductible}' : 'Not listed'),
      _ComparisonRow('Start Date', (s) => s.formattedStartDate),
      _ComparisonRow('End Date', (s) => s.formattedExpiryDate),
      _ComparisonRow(
          'Status',
          (s) => s.isExpired
              ? 'Expired'
              : s.isExpiringSoon
                  ? 'Expiring Soon'
                  : 'Active'),
      _ComparisonRow('Helpline', (s) => s.insurerHelpline ?? 'Not listed'),
    ];

    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: DataTable(
        columnSpacing: 24,
        headingRowColor: WidgetStatePropertyAll(
          theme.colorScheme.surfaceContainerHighest,
        ),
        columns: [
          const DataColumn(
              label:
                  Text('Field', style: TextStyle(fontWeight: FontWeight.bold))),
          ...policies.map((p) => DataColumn(
                label: Text(p.documentType,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
        ],
        rows: rows
            .map((row) => DataRow(cells: [
                  DataCell(Text(row.label,
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant))),
                  ...policies.map((p) => DataCell(Text(row.getValue(p)))),
                ]))
            .toList(),
      ),
    );
  }
}

class _ComparisonRow {
  final String label;
  final String Function(PolicySummary) getter;
  _ComparisonRow(this.label, this.getter);
  String getValue(PolicySummary s) => getter(s);
}
