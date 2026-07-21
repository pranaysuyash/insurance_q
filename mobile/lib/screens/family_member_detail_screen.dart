import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../providers/family_providers.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/coverwise_snackbar.dart';
import '../services/app_state_repository.dart';
import '../utils/document_icons.dart';
import '../utils/policy_type.dart';
import 'policy_detail_screen.dart';

/// Shows a single family member's details plus the policies that cover them.
///
/// When [documents] is provided, the screen matches the member name against
/// each document's policyHolders list to find associated policies.
/// For manual members, the user can edit name, relationship, and DOB.
class FamilyMemberDetailScreen extends ConsumerStatefulWidget {
  final PolicyHolder member;
  final List<InsuranceDocument> documents;

  const FamilyMemberDetailScreen({
    super.key,
    required this.member,
    this.documents = const [],
  });

  @override
  ConsumerState<FamilyMemberDetailScreen> createState() =>
      _FamilyMemberDetailScreenState();
}

class _FamilyMemberDetailScreenState
    extends ConsumerState<FamilyMemberDetailScreen> {
  late PolicyHolder _member;
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  String? _editingRelationship;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _nameController = TextEditingController(text: _member.name);
    _dobController = TextEditingController(text: _member.dob ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  /// Find policies that list this member by name.
  /// Computed in build() — the documents list is small enough that
  /// recomputing on every build is negligible, and this avoids stale
  /// cached results after member name edits.
  List<InsuranceDocument> get _associatedPolicies {
    return widget.documents.where((doc) {
      if (doc.policyHolders == null) return false;
      return doc.policyHolders!.any((h) => h.name == _member.name);
    }).toList();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editingRelationship = _member.relationship;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = _member.name;
      _dobController.text = _member.dob ?? '';
      _editingRelationship = null;
    });
  }

  Future<void> _saveEdits() async {
    final updated = PolicyHolder(
      name: _nameController.text.trim(),
      dob: _dobController.text.trim().isNotEmpty
          ? _dobController.text.trim()
          : null,
      relationship: _editingRelationship ?? _member.relationship,
      source: _member.source,
    );
    try {
      // Atomic-ish: remove old, add new. If the app crashes between these
      // two calls the member is lost, but for local-only Hive storage this
      // is acceptable for v1.
      await AppStateRepository.removeManualFamilyMember(
        _member.name,
        relationship: _member.relationship,
      );
      await AppStateRepository.addManualFamilyMember(updated);
      refreshManualFamilyMembers(ref);
      setState(() {
        _member = updated;
        _isEditing = false;
      });
      if (!mounted) return;
      CoverWiseSnackBar.success(context, 'Member updated');
    } catch (e) {
      if (!mounted) return;
      CoverWiseSnackBar.error(context, 'Could not update member: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policies = _associatedPolicies;

    return Scaffold(
      appBar: AppBar(
        title: Text(_member.name),
        actions: [
          if (_member.isManual && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit member',
              onPressed: _startEditing,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      _member.relationship == 'Primary Insured'
                          ? Icons.person
                          : Icons.people_alt,
                      size: 40,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isEditing)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: 'Full name',
                        ),
                      ),
                    )
                  else
                    Text(
                      _member.name,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 4),
                  if (_isEditing)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: DropdownButton<String>(
                        value: _editingRelationship,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'Dependent', child: Text('Dependent')),
                          DropdownMenuItem(
                              value: 'Spouse', child: Text('Spouse')),
                          DropdownMenuItem(
                              value: 'Child', child: Text('Child')),
                          DropdownMenuItem(
                              value: 'Parent', child: Text('Parent')),
                          DropdownMenuItem(
                              value: 'Sibling', child: Text('Sibling')),
                          DropdownMenuItem(
                              value: 'Primary Insured',
                              child: Text('Primary Insured')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) =>
                            setState(() => _editingRelationship = v),
                      ),
                    )
                  else
                    Text(
                      _member.relationship,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _cancelEditing,
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: _saveEdits,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Member Details
            const CoverWiseSectionLabel('Member Details'),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CoverWiseMetadataRow(
                      icon: Icons.cake_outlined,
                      label: 'Date of Birth',
                      value: _member.dob ?? 'Not specified',
                    ),
                    const Divider(),
                    CoverWiseMetadataRow(
                      icon: Icons.source_outlined,
                      label: 'Source',
                      value: _member.isManual
                          ? 'Added manually'
                          : 'Detected from policy',
                    ),
                    const Divider(),
                    CoverWiseMetadataRow(
                      icon: Icons.shield_outlined,
                      label: 'Covering policies',
                      value: '${policies.length}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Associated Policies
            const CoverWiseSectionLabel('Associated Policies'),
            const SizedBox(height: 12),
            if (policies.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 48,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No policies listing ${_member.name} were found. '
                          'Upload a policy that includes them, or add them manually.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...policies.map((doc) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CoverWiseIconBadge(
                        icon: iconForDocumentType(doc.documentType),
                        color: colorForDocumentType(doc.documentType),
                        size: 40,
                      ),
                      title: Text(
                        doc.filename,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        doc.documentType ?? 'Insurance Policy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PolicyDetailScreen(documentId: doc.id),
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
