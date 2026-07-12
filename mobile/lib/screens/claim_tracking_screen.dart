import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/claim_record.dart';
import '../models/policy_summary.dart';
import '../providers/policy_providers.dart';
import '../services/app_state_repository.dart';
import '../utils/policy_type.dart';

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
      appBar: AppBar(title: const Text('Claim Tracker')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClaim,
        child: const Icon(Icons.add),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _claims.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_outlined,
                            size: 56, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No claims tracked yet',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Log an insurance claim to track its status, '
                          'reference number, and notes — all stored on your device.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _claims.length,
                  itemBuilder: (context, index) =>
                      _ClaimCard(
                        claim: _claims[index],
                        onStatusChanged: _updateStatus,
                        onDelete: _deleteClaim,
                      ),
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
        return Colors.blue;
      case ClaimStatus.inReview:
        return Colors.orange;
      case ClaimStatus.approved:
        return Colors.green;
      case ClaimStatus.rejected:
        return Colors.red;
      case ClaimStatus.paid:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(claim.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconForPolicyType(classifyPolicyType(claim.policyType)),
                    size: 20, color: colorForPolicyType(classifyPolicyType(claim.policyType))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(claim.incidentType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                PopupMenuButton<ClaimStatus>(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(claim.status.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor)),
                        const Icon(Icons.arrow_drop_down, size: 16),
                      ],
                    ),
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
            Text(claim.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _chip(Icons.business, claim.insurer),
                _chip(Icons.event, '${claim.filedDate.day}/${claim.filedDate.month}/${claim.filedDate.year}'),
                if (claim.referenceNumber != null)
                  _chip(Icons.tag, 'Ref: ${claim.referenceNumber}'),
              ],
            ),
            if (claim.notes != null && claim.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(claim.notes!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => onDelete(claim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
      referenceNumber:
          _refController.text.trim().isEmpty ? null : _refController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.of(context).pop(claim);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log a Claim'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _incidentType,
              decoration: const InputDecoration(
                labelText: 'Incident type',
                border: OutlineInputBorder(),
              ),
              items: _incidents
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) => setState(() => _incidentType = v ?? 'Other'),
            ),
            const SizedBox(height: 12),
            if (widget.summaries.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedDocId,
                decoration: const InputDecoration(
                  labelText: 'Related policy (optional)',
                  border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _refController,
              decoration: const InputDecoration(
                labelText: 'Reference number (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
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
          child: const Text('Log Claim'),
        ),
      ],
    );
  }
}
