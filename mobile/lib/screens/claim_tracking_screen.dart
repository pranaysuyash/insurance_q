import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/claim_record.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../services/app_state_repository.dart';
import '../theme/coverwise_theme.dart';
import '../utils/policy_type.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/empty_state_widget.dart';

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
    final summaries = ref.read(policySummariesProvider);
    final result = await showDialog<ClaimRecord>(
      context: context,
      builder: (context) => _AddClaimDialog(summaries: summaries),
    );
    if (result != null) {
      await AppStateRepository.addClaimRecord(result);
      _loadClaims();
    }
  }

  Future<void> _updateStatus(ClaimRecord claim, ClaimStatus newStatus) async {
    final updated = claim.copyWith(status: newStatus);
    await AppStateRepository.updateClaimRecord(updated);
    _loadClaims();
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
                          onStatusChanged: _updateStatus,
                          onDelete: _deleteClaim),
                    ),
                  ],
                ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final ClaimRecord claim;
  final Function(ClaimRecord, ClaimStatus) onStatusChanged;
  final Function(ClaimRecord) onDelete;

  const _ClaimCard({
    required this.claim,
    required this.onStatusChanged,
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
            Row(
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _chip(context, Icons.business_outlined, claim.insurer),
                _chip(context, Icons.calendar_today_outlined,
                    '${claim.filedDate.day}/${claim.filedDate.month}/${claim.filedDate.year}'),
                if (claim.referenceNumber != null)
                  _chip(context, Icons.tag_rounded,
                      'Ref: ${claim.referenceNumber}'),
              ],
            ),
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
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Delete ${claim.incidentType} claim record',
                onPressed: () => onDelete(claim),
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

class _AddClaimDialog extends StatefulWidget {
  final List<PolicySummary> summaries;

  const _AddClaimDialog({required this.summaries});

  @override
  State<_AddClaimDialog> createState() => _AddClaimDialogState();
}

class _AddClaimDialogState extends State<_AddClaimDialog> {
  final _descController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  String _incidentType = 'Hospitalization';
  String? _selectedDocId;

  static const _incidents = [
    'Hospitalization',
    'Auto Accident',
    'Life Claim',
    'Property Damage',
    'Theft',
    'Other',
  ];

  @override
  void dispose() {
    _descController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_descController.text.trim().isEmpty) return;

    PolicySummary? selectedSummary;
    if (_selectedDocId != null) {
      selectedSummary = widget.summaries
          .where((s) => s.documentId == _selectedDocId)
          .firstOrNull;
    }

    final claim = ClaimRecord(
      id: const Uuid().v4(),
      documentId: _selectedDocId ?? '',
      policyType: selectedSummary?.documentType ?? 'Unknown',
      insurer: selectedSummary?.insurer ?? 'Unknown',
      incidentType: _incidentType,
      description: _descController.text.trim(),
      filedDate: DateTime.now(),
      referenceNumber: _refController.text.trim().isEmpty
          ? null
          : _refController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.of(context).pop(claim);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const CoverWiseIconBadge(
        icon: Icons.fact_check_outlined,
        color: CoverWiseColors.blueDeep,
        size: 48,
      ),
      title: const Text('Log a claim'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _incidentType,
              decoration: const InputDecoration(
                labelText: 'Incident type',
                prefixIcon: Icon(Icons.warning_amber_rounded),
              ),
              items: _incidents
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) => setState(() => _incidentType = v ?? 'Other'),
            ),
            const SizedBox(height: 12),
            if (widget.summaries.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedDocId,
                decoration: const InputDecoration(
                  labelText: 'Related policy (optional)',
                  prefixIcon: Icon(Icons.policy_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...widget.summaries.map((s) => DropdownMenuItem(
                        value: s.documentId,
                        child: Text(
                            '${s.documentType} — ${s.insurer ?? 'Unknown'}'),
                      )),
                ],
                onChanged: (v) => setState(() => _selectedDocId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _refController,
              decoration: const InputDecoration(
                labelText: 'Reference number (optional)',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _descController.text.trim().isEmpty ? null : _submit,
          child: const Text('Save to claim log'),
        ),
      ],
    );
  }
}
