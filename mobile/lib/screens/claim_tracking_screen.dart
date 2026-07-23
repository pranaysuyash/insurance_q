import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/claim_record.dart';
import '../services/app_state_repository.dart';
import '../theme/coverwise_theme.dart';
import '../utils/policy_type.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/claims/claim_status_timeline.dart';
import '../widgets/claims_workflow_sheet.dart';

/// Claim tracking: a personal log of insurance claims the user has filed.
///
/// This is NOT connected to any insurer system — it's a local record the user
/// keeps to track what they filed, with whom, and the current status.
class ClaimTrackingScreen extends ConsumerStatefulWidget {
  const ClaimTrackingScreen({super.key});

  @override
  ConsumerState<ClaimTrackingScreen> createState() =>
      _ClaimTrackingScreenState();
}

class _ClaimTrackingScreenState extends ConsumerState<ClaimTrackingScreen> {
  List<ClaimRecord> _claims = [];
  bool _loaded = false;

  /// Tracks which claim cards have their timeline expanded.
  /// Keyed by claim ID so multiple cards can be open independently.
  final Set<String> _expandedTimelines = {};

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    final claims = AppStateRepository.getClaimRecords();
    if (mounted) {
      setState(() {
        _claims = claims;
        _loaded = true;
      });
    }
  }

  Future<void> _addClaim() async {
    await ClaimWizardSheet.show(context);
    _loadClaims();
  }

  Future<void> _updateStatus(ClaimRecord claim, ClaimStatus newStatus) async {
    // Append a status update and create the updated record.
    final updated = claim.withStatusUpdate(newStatus);
    await AppStateRepository.updateClaimRecord(updated);
    _loadClaims();
  }

  Future<void> _editReferenceNumber(ClaimRecord claim) async {
    final controller =
        TextEditingController(text: claim.referenceNumber ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim reference number'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. CLM-2026-00421',
            prefixIcon: Icon(Icons.tag_rounded),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final updated = claim.copyWith(referenceNumber: result);
      await AppStateRepository.updateClaimRecord(updated);
      _loadClaims();
    }
  }

  Future<void> _deleteClaim(ClaimRecord claim) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete claim record?'),
        content: Text('Delete the claim "${claim.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AppStateRepository.deleteClaimRecord(claim.id);
      _expandedTimelines.remove(claim.id);
      _loadClaims();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim log')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClaim,
        tooltip: 'Log a claim',
        child: const Icon(Icons.add_rounded),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _claims.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.fact_check_outlined,
                  title: 'No claims logged yet',
                  subtitle:
                      'Keep a private, on-device record of claims you filed with an insurer. CoverWise does not submit claims or receive insurer updates.',
                  actionLabel: 'Log a claim',
                  actionIcon: Icons.edit_note_rounded,
                  color: const Color(0xFFD97706),
                  onAction: _addClaim,
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    const CoverWisePageHeader(
                      title: 'Your claim notes',
                      subtitle:
                          'A personal record stored on this device. Update statuses yourself after checking with the insurer.',
                    ),
                    const CoverWiseSectionLabel('Logged claims'),
                    ..._claims.map(
                      (claim) => _ClaimCard(
                        claim: claim,
                        isTimelineExpanded:
                            _expandedTimelines.contains(claim.id),
                        onToggleTimeline: () {
                          setState(() {
                            if (_expandedTimelines.contains(claim.id)) {
                              _expandedTimelines.remove(claim.id);
                            } else {
                              _expandedTimelines.add(claim.id);
                            }
                          });
                        },
                        onStatusChanged: _updateStatus,
                        onEditReference: _editReferenceNumber,
                        onDelete: _deleteClaim,
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Show a photo in a full-screen dialog with a close button.
void _showPhotoFullscreen(BuildContext context, String path) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black87,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 48, color: Colors.white54),
                      SizedBox(height: 8),
                      Text('Image not available',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClaimCard extends StatelessWidget {
  final ClaimRecord claim;
  final bool isTimelineExpanded;
  final VoidCallback onToggleTimeline;
  final Function(ClaimRecord, ClaimStatus) onStatusChanged;
  final Function(ClaimRecord) onEditReference;
  final Function(ClaimRecord) onDelete;

  const _ClaimCard({
    required this.claim,
    required this.isTimelineExpanded,
    required this.onToggleTimeline,
    required this.onStatusChanged,
    required this.onEditReference,
    required this.onDelete,
  });

  Color _statusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.filed:
        return CoverWiseColors.blueDeep;
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

  IconData _statusIcon(ClaimStatus status) => switch (status) {
        ClaimStatus.filed => Icons.upload_file_rounded,
        ClaimStatus.inReview => Icons.manage_search_rounded,
        ClaimStatus.approved => Icons.check_circle_rounded,
        ClaimStatus.rejected => Icons.cancel_rounded,
        ClaimStatus.paid => Icons.payments_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(claim.status);
    final theme = Theme.of(context);
    final policyType = classifyPolicyType(claim.policyType);

    return CoverWiseSurface(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + incident type + status + menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverWiseIconBadge(
                  icon: iconForPolicyType(policyType),
                  color: colorForPolicyType(
                    policyType,
                    brightness: theme.brightness,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    claim.incidentType,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                PopupMenuButton<ClaimStatus>(
                  tooltip: 'Update claim status',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CoverWiseStatusChip(
                        icon: _statusIcon(claim.status),
                        label: claim.status.label,
                        color: statusColor,
                        compact: true,
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: statusColor,
                      ),
                    ],
                  ),
                  onSelected: (s) => onStatusChanged(claim, s),
                  itemBuilder: (_) => ClaimStatus.values
                      .map((s) => PopupMenuItem(
                            value: s,
                            child: Text(s.label),
                          ))
                      .toList(),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(claim.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),

            // Metadata chips: insurer, date, reference number
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _chip(context, Icons.business_outlined, claim.insurer),
                _chip(context, Icons.calendar_today_outlined,
                    '${claim.filedDate.day}/${claim.filedDate.month}/${claim.filedDate.year}'),
                // Reference number chip — tappable to edit
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onEditReference(claim),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded,
                              size: 15,
                              color: claim.referenceNumber != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            claim.referenceNumber != null
                                ? 'Ref: ${claim.referenceNumber}'
                                : 'Add ref. no.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: claim.referenceNumber != null
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: claim.referenceNumber != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.edit_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Photo evidence thumbnails
            if (claim.photoPaths.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: claim.photoPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final path = claim.photoPaths[i];
                    return GestureDetector(
                      onTap: () => _showPhotoFullscreen(context, path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(path),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Notes section
            if (claim.notes != null && claim.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  claim.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],

            // ── Status timeline toggle ──
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: onToggleTimeline,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timeline_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isTimelineExpanded
                            ? 'Hide status timeline'
                            : 'View status timeline',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isTimelineExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Status timeline content (expandable) ──
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: ClaimStatusTimeline(
                  statusHistory: claim.statusHistory,
                ),
              ),
              crossFadeState: isTimelineExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),

            // Bottom action row
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Delete ${claim.incidentType} claim record',
                    onPressed: () => onDelete(claim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(text,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
