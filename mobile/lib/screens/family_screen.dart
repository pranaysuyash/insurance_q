import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../providers/family_providers.dart';
import '../providers/document_providers.dart';
import '../widgets/shared/empty_state_widget.dart';
import 'add_family_member_dialog.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Members')),
      body: const FamilyMembersContent(),
    );
  }
}

class FamilyMembersContent extends ConsumerWidget {
  const FamilyMembersContent({super.key});

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final member = await showDialog<PolicyHolder>(
      context: context,
      builder: (_) => const AddFamilyMemberDialog(),
    );
    if (member != null) {
      await addManualFamilyMember(ref, member);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${member.name}.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return documentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (documents) {
        if (documents.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.family_restroom,
            title: 'No family members yet',
            subtitle:
                'Upload insurance documents to auto-detect family members, or '
                'add one manually.',
            actionLabel: 'Add Family Member',
            onAction: () => _addMember(context, ref),
          );
        }

        return _FamilyList(documents: documents, onAdd: () => _addMember(context, ref));
      },
    );
  }
}

class _FamilyList extends ConsumerWidget {
  final List<InsuranceDocument> documents;
  final VoidCallback onAdd;
  const _FamilyList({required this.documents, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(mergedFamilyMembersProvider(documents));

    return familyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyStateWidget(
        icon: Icons.family_restroom,
        title: 'No family members found',
        subtitle:
            'Upload insurance documents to auto-detect family members, or '
            'add one manually.',
        actionLabel: 'Add Family Member',
        onAction: onAdd,
      ),
      data: (policyHolders) {
        if (policyHolders.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.family_restroom,
            title: 'No family members found',
            subtitle:
                'Upload insurance documents to auto-detect family members, or '
                'add one manually.',
            actionLabel: 'Add Family Member',
            onAction: onAdd,
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(mergedFamilyMembersProvider(documents)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Family Members & Insured',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Auto-detected from your policies, plus anyone you add manually.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ...policyHolders.values.map((holder) => _FamilyMemberCard(
                    holder: holder,
                    onDelete: holder.isManual
                        ? () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove family member?'),
                                content: Text(
                                    'Remove ${holder.name} from your family list? '
                                    'This does not affect your policy documents.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await removeManualFamilyMember(ref, holder);
                            }
                          }
                        : null,
                  )),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Family Member'),
                onPressed: onAdd,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  final PolicyHolder holder;
  final VoidCallback? onDelete;
  const _FamilyMemberCard({required this.holder, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    holder.relationship == 'Primary Insured'
                        ? Icons.person
                        : Icons.people_alt,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(holder.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Flexible(
                            child: Text(holder.relationship,
                                style:
                                    TextStyle(color: Colors.grey.shade700)),
                          ),
                          const SizedBox(width: 8),
                          _SourceBadge(isManual: holder.isManual),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Remove',
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (holder.dob != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.cake, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Date of Birth: ${holder.dob}',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final bool isManual;
  const _SourceBadge({required this.isManual});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isManual ? Colors.teal.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isManual ? 'Manual' : 'From document',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isManual ? Colors.teal.shade700 : Colors.blue.shade700,
        ),
      ),
    );
  }
}
