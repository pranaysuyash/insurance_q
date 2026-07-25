import 'package:flutter/material.dart';
import '../../models/claim_record.dart';

/// A vertical timeline displaying a user's recorded claim-status history.
///
/// Shows each status transition as a decorated node with a date label
/// and the status name. The most recent node is visually highlighted.
/// Unreached statuses (future steps in the lifecycle) are shown in a
/// muted state as dotted pathways.
class ClaimStatusTimeline extends StatelessWidget {
  final List<StatusUpdate> statusHistory;

  const ClaimStatusTimeline({super.key, required this.statusHistory});

  /// Returns which lifecycle nodes to display based on the claim's path.
  ///
  /// If the claim has been rejected, stop at "Rejected" (don't show "Paid"
  /// as a future state). Otherwise show the full lifecycle through "Paid".
  List<ClaimStatus> _lifecycle() {
    final wasRejected =
        statusHistory.any((u) => u.status == ClaimStatus.rejected);
    if (wasRejected) {
      return [
        ClaimStatus.filed,
        ClaimStatus.inReview,
        ClaimStatus.rejected,
      ];
    }
    return [
      ClaimStatus.filed,
      ClaimStatus.inReview,
      ClaimStatus.approved,
      ClaimStatus.paid,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentStatus = statusHistory.isNotEmpty
        ? statusHistory.last.status
        : ClaimStatus.filed;
    final lifecycle = _lifecycle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Your recorded status history',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...lifecycle.map((status) {
          final isReached = statusHistory.any((u) => u.status == status);
          final isCurrent = status == recentStatus;
          final eventsForStatus =
              statusHistory.where((u) => u.status == status).toList();

          return _TimelineNode(
            status: status,
            isReached: isReached,
            isCurrent: isCurrent,
            events: eventsForStatus,
            isLast: status == lifecycle.last,
          );
        }),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final ClaimStatus status;
  final bool isReached;
  final bool isCurrent;
  final List<StatusUpdate> events;
  final bool isLast;

  const _TimelineNode({
    required this.status,
    required this.isReached,
    required this.isCurrent,
    required this.events,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(theme);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail: node + connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Node circle
                Container(
                  width: isCurrent ? 16.0 : 12.0,
                  height: isCurrent ? 16.0 : 12.0,
                  margin: EdgeInsets.only(top: isCurrent ? 4.0 : 6.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isReached ? color : Colors.transparent,
                    border: Border.all(
                      color:
                          isReached ? color : theme.colorScheme.outlineVariant,
                      width: isCurrent ? 3.0 : 2.0,
                    ),
                  ),
                ),
                // Connector line (skip for last node)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: isCurrent ? 2.0 : 1.0,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isReached
                            ? color.withValues(alpha: 0.4)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _statusIcon(status),
                        size: 16,
                        color: isReached
                            ? color
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isCurrent ? FontWeight.w800 : FontWeight.w500,
                          color: isReached
                              ? color
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                      if (isCurrent)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Current record',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Show date for first occurrence of this status
                  if (events.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 2),
                      child: Text(
                        _formatDate(events.first.timestamp),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  // Show additional occurrences (e.g., re-filed)
                  if (events.length > 1)
                    ...events.sublist(1).map((event) => Padding(
                          padding: const EdgeInsets.only(left: 22, top: 1),
                          child: Text(
                            'Updated ${_formatDate(event.timestamp)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ThemeData theme) {
    // Use the same hex colors as the claim card's status chip for consistency.
    switch (status) {
      case ClaimStatus.filed:
        return const Color(0xFF1A56DB);
      case ClaimStatus.inReview:
        return const Color(0xFFD97706);
      case ClaimStatus.approved:
        return const Color(0xFF16825D);
      case ClaimStatus.rejected:
        return const Color(0xFFCC3B54);
      case ClaimStatus.paid:
        return const Color(0xFF087F75);
    }
  }

  IconData _statusIcon(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.filed:
        return Icons.upload_file_rounded;
      case ClaimStatus.inReview:
        return Icons.manage_search_rounded;
      case ClaimStatus.approved:
        return Icons.check_circle_rounded;
      case ClaimStatus.rejected:
        return Icons.cancel_rounded;
      case ClaimStatus.paid:
        return Icons.payments_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
