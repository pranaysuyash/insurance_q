import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../utils/document_icons.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/shared/coverwise_scene.dart';
import '../theme/coverwise_motion.dart';
import 'documents_screen.dart';

/// Cross-document search screen — M2 from the audit.
///
/// Allows users to search across all uploaded policy summaries using keyword
/// matching on document type, insurer, policy number, benefits, exclusions,
/// and coverage items. Results are ranked by relevance.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _showClearButton = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _showClearButton) {
      setState(() => _showClearButton = hasText);
    }
    // Debounce search input to avoid excessive recomputation on rapid keystrokes.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.requestFocus();
    // Bypass debounce for explicit clears — update immediately.
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Cancel pending debounce and reset search state when leaving.
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(searchTypeFilterProvider.notifier).state = null;
    ref.read(searchStatusFilterProvider.notifier).state = 'all';
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider);
    final typeFilter = ref.watch(searchTypeFilterProvider);
    final statusFilter = ref.watch(searchStatusFilterProvider);
    final uniqueTypes = ref.watch(uniqueDocumentTypesProvider);
    final allSummaries = ref.watch(policySummariesProvider);
    final hasQuery =
        query.isNotEmpty || typeFilter != null || statusFilter != 'all';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search policies'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Insurer, policy number, benefit…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _showClearButton
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          _FilterBar(
            uniqueTypes: uniqueTypes,
            typeFilter: typeFilter,
            statusFilter: statusFilter,
            onTypeFilterChanged: (type) {
              ref.read(searchTypeFilterProvider.notifier).state = type;
            },
            onStatusFilterChanged: (status) {
              ref.read(searchStatusFilterProvider.notifier).state = status;
            },
          ),
          if (allSummaries.isNotEmpty)
            Semantics(
              liveRegion: true,
              label:
                  '${results.length} ${results.length == 1 ? 'policy' : 'policies'} found',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${results.length} ${results.length == 1 ? 'policy' : 'policies'}',
                      key: ValueKey('search-count-${results.length}'),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          // Results
          Expanded(
            child: CoverWiseStateTransition(
              child: allSummaries.isEmpty
                  ? EmptyStateWidget(
                      key: ValueKey('search-empty-library'),
                      icon: Icons.folder_open_rounded,
                      title: 'No policies uploaded',
                      subtitle:
                          'Choose a policy file to search its cover, exclusions and dates.',
                      actionLabel: 'Choose policy file',
                      actionIcon: Icons.upload_file_rounded,
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DocumentsScreen(
                            startWithFilePicker: true,
                          ),
                        ),
                      ),
                      color: const Color(0xFF2466B8),
                      scene: CoverWiseSceneKind.firstPolicy,
                    )
                  : hasQuery && results.isEmpty
                      ? const EmptyStateWidget(
                          key: ValueKey('search-no-match'),
                          icon: Icons.manage_search_rounded,
                          title: 'Nothing matched',
                          subtitle: 'Try another term or broaden the filters.',
                          color: Color(0xFF6A4BA8),
                        )
                      : _SearchResultsList(
                          key: ValueKey(
                            'search-results-${results.length}-$query-$typeFilter-$statusFilter',
                          ),
                          results: results,
                          query: query,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter bar with type and status chips
class _FilterBar extends StatelessWidget {
  final List<String> uniqueTypes;
  final String? typeFilter;
  final String statusFilter;
  final ValueChanged<String?> onTypeFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;

  const _FilterBar({
    required this.uniqueTypes,
    required this.typeFilter,
    required this.statusFilter,
    required this.onTypeFilterChanged,
    required this.onStatusFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Status filter chips
          _FilterChip(
            label: 'All',
            selected: statusFilter == 'all',
            color: Colors.grey,
            onTap: () => onStatusFilterChanged('all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Active',
            selected: statusFilter == 'active',
            color: Colors.green,
            onTap: () => onStatusFilterChanged('active'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Expiring',
            selected: statusFilter == 'expiring',
            color: Colors.orange,
            onTap: () => onStatusFilterChanged('expiring'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Expired',
            selected: statusFilter == 'expired',
            color: Colors.red,
            onTap: () => onStatusFilterChanged('expired'),
          ),
          if (uniqueTypes.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: Colors.grey.shade300),
            const SizedBox(width: 12),
            // "All Types" chip
            _FilterChip(
              label: 'All Types',
              selected: typeFilter == null,
              color: Colors.blue,
              onTap: () => onTypeFilterChanged(null),
            ),
            const SizedBox(width: 8),
            // Per-type chips
            ...uniqueTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: type,
                    selected: typeFilter == type,
                    color: Colors.blue,
                    onTap: () =>
                        onTypeFilterChanged(typeFilter == type ? null : type),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

/// Individual filter chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: '$label filter',
      excludeSemantics: true,
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        avatar:
            selected ? Icon(Icons.check_rounded, size: 17, color: color) : null,
        selectedColor: color.withValues(alpha: 0.12),
        side: BorderSide(
          color: selected ? color : theme.dividerColor,
          width: selected ? 1.5 : 1,
        ),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: selected ? color : theme.colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// Search results list
class _SearchResultsList extends StatelessWidget {
  final List<PolicySummary> results;
  final String query;

  const _SearchResultsList({
    super.key,
    required this.results,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final summary = results[index];
        return _SearchResultCard(summary: summary, query: query);
      },
    );
  }
}

/// Individual search result card
class _SearchResultCard extends StatelessWidget {
  final PolicySummary summary;
  final String query;

  const _SearchResultCard({required this.summary, required this.query});

  @override
  Widget build(BuildContext context) {
    final icon = iconForDocumentType(summary.documentType);
    final typeColor = colorForDocumentType(summary.documentType);
    final days = summary.daysUntilExpiry;

    // Determine status
    final (statusLabel, statusColor) = summary.isExpired
        ? ('EXPIRED', Colors.red)
        : summary.isExpiringSoon
            ? ('$days days left', Colors.orange)
            : ('Active', Colors.green);

    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/policy-detail',
            arguments: summary.documentId,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CoverWiseIconBadge(icon: icon, color: typeColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedText(
                          text: summary.documentType,
                          query: query,
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (summary.insurer != null)
                          _HighlightedText(
                            text: summary.insurer!,
                            query: query,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                  _ResultStatusBadge(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              // Metrics row
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  if (summary.formattedCoverageAmount != 'Unknown') ...[
                    _ResultMetric(Icons.shield, 'Coverage',
                        summary.formattedCoverageAmount),
                  ],
                  if (summary.formattedPremium != 'Unknown') ...[
                    _ResultMetric(
                        Icons.payments, 'Premium', summary.formattedPremium),
                  ],
                  if (summary.formattedExpiryDate != 'Unknown')
                    _ResultMetric(
                        Icons.event, 'Expires', summary.formattedExpiryDate),
                ],
              ),
              if (summary.policyNumber != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.numbers_rounded,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    _HighlightedText(
                      text: summary.policyNumber!,
                      query: query,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              // Matching benefits/exclusions previews
              if (query.isNotEmpty && summary.keyBenefits.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._matchingItems(summary.keyBenefits, query, 'Benefit',
                    Icons.check_circle, Colors.green),
              ],
              if (query.isNotEmpty && summary.exclusions.isNotEmpty) ...[
                ..._matchingItems(summary.exclusions, query, 'Exclusion',
                    Icons.cancel, Colors.red),
              ],
              if (query.isNotEmpty && summary.coverageItems.isNotEmpty) ...[
                ...summary.coverageItems
                    .where((c) =>
                        c.name.toLowerCase().contains(query.toLowerCase()))
                    .take(2)
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                c.covered
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                size: 14,
                                color: c.covered ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Coverage: ${c.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _matchingItems(
    List<String> items,
    String query,
    String label,
    IconData icon,
    Color color,
  ) {
    final queryLower = query.toLowerCase();
    final matching = items
        .where((item) => item.toLowerCase().contains(queryLower))
        .take(2)
        .toList();
    final totalMatches =
        items.where((item) => item.toLowerCase().contains(queryLower)).length;
    final widgets = matching
        .map<Widget>((item) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _HighlightedText(
                      text: '$label: $item',
                      query: query,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
    if (totalMatches > 2) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '...and ${totalMatches - 2} more ${label.toLowerCase()} match${totalMatches - 2 == 1 ? '' : 'es'}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ));
    }
    return widgets;
  }
}

/// Text widget that highlights matching query terms
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();

    // Find all match positions
    final spans = <TextSpan>[];
    int lastEnd = 0;

    while (lastEnd < text.length) {
      final matchIndex = textLower.indexOf(queryLower, lastEnd);
      if (matchIndex == -1) {
        // No more matches — add remaining text
        spans.add(TextSpan(text: text.substring(lastEnd)));
        break;
      }

      // Add text before match
      if (matchIndex > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, matchIndex)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(matchIndex, matchIndex + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withValues(alpha: 0.4),
          fontWeight: FontWeight.bold,
        ),
      ));

      lastEnd = matchIndex + query.length;
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Result metric chip
class _ResultMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultMetric(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// Status badge for search results
class _ResultStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ResultStatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return CoverWiseStatusChip(
      icon: label.toLowerCase().contains('expired')
          ? Icons.error_rounded
          : label.toLowerCase().contains('left')
              ? Icons.schedule_rounded
              : Icons.check_circle_rounded,
      label: label,
      color: color,
      compact: true,
    );
  }
}
