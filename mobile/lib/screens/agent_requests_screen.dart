import 'package:flutter/material.dart';
import '../services/agent_connection_service.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../widgets/shared/coverwise_components.dart';

/// Screen showing all submitted advisor connection requests.
///
/// Displays each request with its status (contacted/pending), preferred
/// callback time, policy context, and the user's message. The user can
/// clear all requests or mark individual ones as contacted.
class AgentRequestsScreen extends StatefulWidget {
  const AgentRequestsScreen({super.key});

  @override
  State<AgentRequestsScreen> createState() => _AgentRequestsScreenState();
}

class _AgentRequestsScreenState extends State<AgentRequestsScreen> {
  final _service = AgentConnectionService();
  List<AgentRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    setState(() {
      _requests = _service.getRequests();
      _isLoading = false;
    });
  }

  Future<void> _markContacted(AgentRequest request) async {
    await _service.markContacted(request.id);
    _loadRequests();
    if (mounted) {
      CoverWiseSnackBar.info(
        context,
        'Marked as contacted',
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all requests?'),
        content: const Text(
          'This removes all advisor requests from this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.clear();
      _loadRequests();
      if (mounted) {
        CoverWiseSnackBar.info(
          context,
          'All requests cleared',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advisor requests'),
        actions: [
          if (_requests.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? _buildEmptyState(theme, scheme)
              : _buildList(theme, scheme),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              'No advisor requests yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'When you submit a request to talk to an advisor, it will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Ask CoverWise instead'),
              onPressed: () => Navigator.pushNamed(context, '/qa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme, ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '${_requests.length} request${_requests.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        ..._requests.map((request) => _RequestCard(
              request: request,
              theme: theme,
              scheme: scheme,
              onMarkContacted: () => _markContacted(request),
            )),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AgentRequest request;
  final ThemeData theme;
  final ColorScheme scheme;
  final VoidCallback onMarkContacted;

  const _RequestCard({
    required this.request,
    required this.theme,
    required this.scheme,
    required this.onMarkContacted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + status badge
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF087F75).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF087F75),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        request.phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                CoverWiseStatusChip(
                  icon: request.contacted
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  label: request.contacted ? 'Contacted' : 'Pending',
                  color: request.contacted
                      ? const Color(0xFF087F75)
                      : scheme.tertiary,
                  compact: true,
                ),
              ],
            ),
            // Description
            if (request.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  request.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
                ),
              ),
            ],
            // Policy context
            if (request.insurer != null || request.documentType != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    [
                      if (request.insurer != null) request.insurer,
                      if (request.documentType != null) request.documentType,
                    ].join(' — '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            // Scheduled callback time
            if (request.preferredDate != null || request.preferredTime != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        if (request.preferredDate != null)
                          '${request.preferredDate!.day}/${request.preferredDate!.month}/${request.preferredDate!.year}',
                        if (request.preferredTime != null)
                          request.preferredTime!,
                      ].join(' — '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Submitted date
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Submitted ${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            // Mark contacted button (only for pending requests)
            if (!request.contacted) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Mark as contacted'),
                  onPressed: onMarkContacted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
