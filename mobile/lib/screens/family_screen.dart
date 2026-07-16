import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../providers/family_providers.dart';
import '../providers/document_providers.dart';
import '../widgets/shared/empty_state_widget.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/error_widget.dart';
import '../theme/coverwise_theme.dart';
import 'add_family_member_dialog.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
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
      error: (e, _) => AppErrorView(
        message: 'Your policy library could not be loaded.',
        icon: Icons.family_restroom_rounded,
        onRetry: () => ref.invalidate(documentsProvider),
      ),
      data: (documents) {
        if (documents.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.family_restroom,
            title: 'No family members yet',
            subtitle:
                'Upload insurance documents to auto-detect family members, or '
                'add one manually.',
            actionLabel: 'Add Family Member',
            actionIcon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF16866B),
            onAction: () => _addMember(context, ref),
          );
        }

        return _FamilyList(
            documents: documents, onAdd: () => _addMember(context, ref));
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
      error: (e, _) => AppErrorView(
        message: 'Covered family members could not be read from your policies.',
        icon: Icons.family_restroom_rounded,
        onRetry: () => ref.invalidate(mergedFamilyMembersProvider(documents)),
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
            actionIcon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF16866B),
            onAction: onAdd,
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(mergedFamilyMembersProvider(documents)),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              CoverWisePageHeader(
                title: 'People covered',
                subtitle:
                    'A clear view of the people found in your policies, plus anyone you add yourself.',
                trailing: CoverWiseIconBadge(
                  icon: Icons.family_restroom_rounded,
                  color: CoverWiseColors.blueDeep,
                  size: 48,
                ),
              ),
              const CoverWiseSectionLabel('Family and insured members'),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add family member'),
                    onPressed: onAdd,
                  ),
                ),
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
    final theme = Theme.of(context);
    final isPrimary = holder.relationship == 'Primary Insured';

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
                  icon: isPrimary
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  color: isPrimary
                      ? CoverWiseColors.blueDeep
                      : theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holder.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            holder.relationship,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          _SourceBadge(isManual: holder.isManual),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    tooltip: 'Remove ${holder.name}',
                    onPressed: onDelete,
                  ),
              ],
            ),
            if (holder.dob != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(Icons.cake_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Date of birth: ${holder.dob}',
                    style: theme.textTheme.bodyMedium,
                  ),
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
    final theme = Theme.of(context);
    final color =
        isManual ? theme.colorScheme.tertiary : CoverWiseColors.blueDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        isManual ? 'Manual' : 'From document',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
